<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$empId = (int)$session['emp_id'];
$pdo = chat_db();
chat_ensure_schema($pdo);
chat_ensure_user_storage_limit_table($pdo);
$jid = chat_jid($empId);

function storage_format_bytes(int $bytes): string
{
    if ($bytes < 1024) return $bytes . ' B';
    $units = ['KB', 'MB', 'GB', 'TB'];
    $value = $bytes / 1024;
    foreach ($units as $unit) {
        if ($value < 1024 || $unit === 'TB') {
            return rtrim(rtrim(number_format($value, 2, '.', ''), '0'), '.') . ' ' . $unit;
        }
        $value /= 1024;
    }
    return $bytes . ' B';
}

function storage_peer_label(PDO $pdo, string $jid): array
{
    $jid = strtolower(trim($jid));
    if ($jid === '') return ['jid' => '', 'name' => 'Unknown', 'type' => 'unknown'];
    if (chat_is_room_jid($jid)) {
        $stmt = $pdo->prepare('SELECT room_name, group_type, channel_kind FROM xmpp_groups WHERE room_jid = :jid LIMIT 1');
        $stmt->execute([':jid' => $jid]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC) ?: [];
        $type = strtolower((string)($row['group_type'] ?? 'group')) === 'channel' ? 'channel' : 'group';
        return [
            'jid' => $jid,
            'name' => (string)($row['room_name'] ?? explode('@', $jid)[0]),
            'type' => $type,
            'channel_kind' => (string)($row['channel_kind'] ?? ''),
        ];
    }
    if (chat_is_user_jid($jid)) {
        $otherEmp = (int)explode('@', $jid)[0];
        $name = '';
        try {
            $employee = chat_employee_row(getEmployeeDB(), $otherEmp);
            $name = trim((string)($employee['name'] ?? $employee['emp_name'] ?? $employee['employee_name'] ?? ''));
        } catch (Throwable $e) {
            $name = '';
        }
        return ['jid' => $jid, 'name' => $name !== '' ? $name : (string)$otherEmp, 'type' => 'user'];
    }
    return ['jid' => $jid, 'name' => $jid, 'type' => 'system'];
}

$quota = chat_user_storage_quota($pdo, $empId);
$quota['used_label'] = storage_format_bytes((int)$quota['used_bytes']);
$quota['limit_label'] = storage_format_bytes((int)$quota['limit_bytes']);
$quota['remaining_label'] = storage_format_bytes((int)$quota['remaining_bytes']);

$statsStmt = $pdo->prepare("SELECT
    COUNT(*) AS total_files,
    COALESCE(SUM(CASE WHEN from_jid = :stats_jid1 THEN 1 ELSE 0 END), 0) AS uploaded_files,
    COALESCE(SUM(CASE WHEN from_jid <> :stats_jid2 THEN 1 ELSE 0 END), 0) AS received_files,
    COALESCE(SUM(CAST(file_size AS UNSIGNED)), 0) AS visible_bytes,
    COALESCE(SUM(CASE WHEN from_jid = :stats_jid3 THEN CAST(file_size AS UNSIGNED) ELSE 0 END), 0) AS uploaded_bytes,
    COALESCE(SUM(CASE WHEN from_jid <> :stats_jid4 THEN CAST(file_size AS UNSIGNED) ELSE 0 END), 0) AS received_bytes
    FROM xmpp_messages
    WHERE file_url IS NOT NULL AND file_url <> '' AND deleted_at IS NULL
      AND (from_jid = :stats_jid5 OR to_jid = :stats_jid6 OR to_jid IN (SELECT g.room_jid FROM xmpp_groups g INNER JOIN xmpp_group_members gm ON gm.group_id = g.id WHERE gm.emp_id = :emp_id))");
$statsStmt->execute([':stats_jid1' => $jid, ':stats_jid2' => $jid, ':stats_jid3' => $jid, ':stats_jid4' => $jid, ':stats_jid5' => $jid, ':stats_jid6' => $jid, ':emp_id' => $empId]);
$stats = $statsStmt->fetch(PDO::FETCH_ASSOC) ?: [];

$conversationStmt = $pdo->prepare("SELECT peer_jid,
    SUM(sent_files) AS sent_files,
    SUM(received_files) AS received_files,
    SUM(sent_bytes) AS sent_bytes,
    SUM(received_bytes) AS received_bytes
FROM (
    SELECT CASE WHEN chat_is_room = 1 THEN to_jid ELSE to_jid END AS peer_jid,
           COUNT(*) AS sent_files,
           0 AS received_files,
           COALESCE(SUM(CAST(file_size AS UNSIGNED)), 0) AS sent_bytes,
           0 AS received_bytes
    FROM (
        SELECT m.*, CASE WHEN m.to_jid LIKE '%@conference.chat.skylinkonline.net' THEN 1 ELSE 0 END AS chat_is_room
        FROM xmpp_messages m
        WHERE m.from_jid = :conv_jid1 AND m.file_url IS NOT NULL AND m.file_url <> '' AND m.deleted_at IS NULL
    ) sent
    GROUP BY peer_jid
    UNION ALL
    SELECT CASE WHEN to_jid LIKE '%@conference.chat.skylinkonline.net' THEN to_jid ELSE from_jid END AS peer_jid,
           0 AS sent_files,
           COUNT(*) AS received_files,
           0 AS sent_bytes,
           COALESCE(SUM(CAST(file_size AS UNSIGNED)), 0) AS received_bytes
    FROM xmpp_messages
    WHERE from_jid <> :conv_jid2 AND file_url IS NOT NULL AND file_url <> '' AND deleted_at IS NULL
      AND (to_jid = :conv_jid3 OR to_jid IN (SELECT g.room_jid FROM xmpp_groups g INNER JOIN xmpp_group_members gm ON gm.group_id = g.id WHERE gm.emp_id = :emp_id))
    GROUP BY peer_jid
) usage_rows
WHERE peer_jid IS NOT NULL AND peer_jid <> ''
GROUP BY peer_jid
ORDER BY (SUM(sent_bytes) + SUM(received_bytes)) DESC
LIMIT 100");
$conversationStmt->execute([':conv_jid1' => $jid, ':conv_jid2' => $jid, ':conv_jid3' => $jid, ':emp_id' => $empId]);
$conversations = [];
foreach ($conversationStmt->fetchAll(PDO::FETCH_ASSOC) ?: [] as $row) {
    $sentBytes = (int)($row['sent_bytes'] ?? 0);
    $receivedBytes = (int)($row['received_bytes'] ?? 0);
    $meta = storage_peer_label($pdo, (string)($row['peer_jid'] ?? ''));
    $conversations[] = array_merge($meta, [
        'sent_files' => (int)($row['sent_files'] ?? 0),
        'received_files' => (int)($row['received_files'] ?? 0),
        'total_files' => (int)($row['sent_files'] ?? 0) + (int)($row['received_files'] ?? 0),
        'sent_bytes' => $sentBytes,
        'received_bytes' => $receivedBytes,
        'total_bytes' => $sentBytes + $receivedBytes,
        'sent_label' => storage_format_bytes($sentBytes),
        'received_label' => storage_format_bytes($receivedBytes),
        'total_label' => storage_format_bytes($sentBytes + $receivedBytes),
    ]);
}

chat_json([
    'status' => true,
    'quota' => $quota,
    'summary' => [
        'total_files' => (int)($stats['total_files'] ?? 0),
        'uploaded_files' => (int)($stats['uploaded_files'] ?? 0),
        'received_files' => (int)($stats['received_files'] ?? 0),
        'visible_bytes' => (int)($stats['visible_bytes'] ?? 0),
        'uploaded_bytes' => (int)($stats['uploaded_bytes'] ?? 0),
        'received_bytes' => (int)($stats['received_bytes'] ?? 0),
        'visible_label' => storage_format_bytes((int)($stats['visible_bytes'] ?? 0)),
        'uploaded_label' => storage_format_bytes((int)($stats['uploaded_bytes'] ?? 0)),
        'received_label' => storage_format_bytes((int)($stats['received_bytes'] ?? 0)),
    ],
    'conversations' => $conversations,
]);
