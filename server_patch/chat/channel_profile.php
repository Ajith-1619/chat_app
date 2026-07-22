<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$pdo = chat_db();
chat_ensure_schema($pdo);
$groupId = max(0, (int)($_GET['group_id'] ?? $_POST['group_id'] ?? 0));
$jid = strtolower(trim((string)($_GET['jid'] ?? $_POST['jid'] ?? '')));
if ($groupId <= 0 && $jid === '') chat_json(['status' => false, 'error' => 'Channel is required'], 422);

$stmt = $pdo->prepare(
    'SELECT g.*, gm.role
     FROM xmpp_groups g
     INNER JOIN xmpp_group_members gm ON gm.group_id = g.id
     WHERE (g.id = :group_id OR g.room_jid = :jid)
       AND gm.emp_id = :emp_id
       AND (g.group_type = \'channel\' OR g.room_jid LIKE \'channel-%\' OR g.room_name LIKE \'#%\')
     LIMIT 1'
);
$stmt->execute([
    ':group_id' => $groupId,
    ':jid' => $jid,
    ':emp_id' => (int)$session['emp_id'],
]);
$channel = $stmt->fetch(PDO::FETCH_ASSOC);
if (!$channel) chat_json(['status' => false, 'error' => 'Channel not found'], 404);

$created = strtotime((string)$channel['created_at']) ?: time();
$ageSeconds = max(0, time() - $created);
$slaMinutes = (int)($channel['sla_minutes'] ?? 0);
$usage = $slaMinutes > 0 ? min(999, round(($ageSeconds / 60) / $slaMinutes * 100, 1)) : 0;
$remainingSeconds = $slaMinutes > 0 ? max(0, $slaMinutes * 60 - $ageSeconds) : 0;
$health = 'none';
if ($slaMinutes > 0) {
    $health = $usage >= 100 ? 'black' : ($usage >= 80 ? 'red' : ($usage >= 50 ? 'yellow' : 'green'));
}
$memberCount = $pdo->prepare('SELECT COUNT(*) FROM xmpp_group_members WHERE group_id = :group_id');
$memberCount->execute([':group_id' => (int)$channel['id']]);
$timelineStmt = $pdo->prepare(
    'SELECT * FROM xmpp_channel_timeline
     WHERE group_id = :group_id ORDER BY created_at ASC, id ASC'
);
$timelineStmt->execute([':group_id' => (int)$channel['id']]);

chat_json([
    'status' => true,
    'channel' => [
        'id' => (int)$channel['id'],
        'name' => ($channel['channel_kind'] === 'ticket' ? '' : '#') . (string)$channel['room_name'],
        'jid' => (string)$channel['room_jid'],
        'channel_kind' => (string)$channel['channel_kind'],
        'status_text' => (string)$channel['status'],
        'priority' => (string)$channel['priority'],
        'description' => (string)($channel['description'] ?? ''),
        'owner_emp_id' => (int)($channel['owner_emp_id'] ?? 0),
        'created_at' => (string)$channel['created_at'],
        'target_date' => (string)($channel['target_date'] ?? ''),
        'next_action_date' => (string)($channel['next_action_date'] ?? ''),
        'next_action_text' => (string)($channel['next_action_text'] ?? ''),
        'next_action_persons' => (string)($channel['next_action_persons'] ?? ''),
        'next_action_updated_at' => (string)($channel['next_action_updated_at'] ?? ''),
        'sla_minutes' => $slaMinutes,
        'stale_alert_minutes' => (int)($channel['stale_alert_minutes'] ?? 0),
        'metadata' => json_decode((string)($channel['metadata_json'] ?? '{}'), true) ?: [],
        'member_count' => (int)$memberCount->fetchColumn(),
        'role' => (string)$channel['role'],
        'age_seconds' => $ageSeconds,
        'age_label' => sprintf('%02dh %02dm', intdiv($ageSeconds, 3600), intdiv($ageSeconds % 3600, 60)),
        'sla' => [
            'health' => $health,
            'usage_percent' => $usage,
            'remaining_seconds' => $remainingSeconds,
            'remaining_label' => $slaMinutes > 0 ? sprintf('%02dh %02dm', intdiv($remainingSeconds, 3600), intdiv($remainingSeconds % 3600, 60)) : '',
            'escalation_level' => $usage >= 100 ? 4 : ($usage >= 80 ? 3 : ($usage >= 50 ? 2 : 1)),
        ],
        'timeline' => $timelineStmt->fetchAll(PDO::FETCH_ASSOC) ?: [],
    ],
]);

