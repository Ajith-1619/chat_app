<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$groups = [];
try {
    $pdo = chat_db();
    chat_ensure_schema($pdo);
    chat_ensure_column($pdo, 'xmpp_group_members', 'history_visible_from', 'DATETIME NULL AFTER joined_at');
    chat_ensure_column($pdo, 'xmpp_messages', 'visibility_mode', 'VARCHAR(16) NOT NULL DEFAULT \'all\' AFTER source_name');
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_message_recipients (
            message_id BIGINT NOT NULL,
            emp_id INT NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (message_id, emp_id),
            INDEX idx_xmpp_message_recipients_emp (emp_id, message_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $employeePdo = getEmployeeDB();
    $me = chat_jid((int)$session['emp_id']);
    $onlineJids = [];
    $onlineStmt = $pdo->query(
        'SELECT emp_id FROM xmpp_user_presence
         WHERE last_seen_at >= DATE_SUB(NOW(), INTERVAL 45 SECOND)'
    );
    foreach (($onlineStmt->fetchAll(PDO::FETCH_COLUMN) ?: []) as $onlineEmpId) {
        $onlineJids[chat_jid((int)$onlineEmpId)] = true;
    }
    $msgStmt = $pdo->prepare(
        'SELECT latest.peer_jid, m.body AS last_body, m.file_name AS last_file_name, m.created_at AS last_time,
                COALESCE(pref.is_pinned, 0) AS is_pinned,
                COALESCE(pref.is_starred, 0) AS is_starred,
                (
                  SELECT COUNT(*)
                  FROM xmpp_messages unread
                  WHERE unread.from_jid = latest.peer_jid
                    AND unread.to_jid = :me_unread
                    AND unread.read_at IS NULL
                    AND (unread.deleted_at IS NULL OR unread.deleted_at = \'0000-00-00 00:00:00\')
                ) AS unread_count
         FROM xmpp_messages m
         INNER JOIN (
            SELECT
                CASE WHEN from_jid = :me_peer_from THEN to_jid ELSE from_jid END AS peer_jid,
                MAX(id) AS max_id
            FROM xmpp_messages
            WHERE (from_jid = :me_where_from OR to_jid = :me_where_to)
              AND (deleted_at IS NULL OR deleted_at = \'0000-00-00 00:00:00\')
            GROUP BY peer_jid
         ) latest ON latest.max_id = m.id
         LEFT JOIN xmpp_conversation_preferences pref
           ON pref.emp_id = :pref_emp AND pref.target_jid = latest.peer_jid
         ORDER BY is_pinned DESC, m.created_at DESC
         LIMIT 75'
    );
    $msgStmt->execute([
        ':me_peer_from' => $me,
        ':me_where_from' => $me,
        ':me_where_to' => $me,
        ':me_unread' => $me,
        ':pref_emp' => (int)$session['emp_id'],
    ]);
    foreach (($msgStmt->fetchAll(PDO::FETCH_ASSOC) ?: []) as $row) {
        $peerJid = (string)$row['peer_jid'];
        if (chat_is_system_notification_jid($peerJid)) {
            $groups[] = [
                'type' => 'notification',
                'id' => 'notification',
                'name' => 'System Notifications',
                'designation' => 'Receive-only system messages',
                'jid' => SKYCHAT_SYSTEM_NOTIFICATION_JID,
                'online' => true,
                'avatar_url' => '',
                'last' => chat_push_preview(
                    (string)($row['last_body'] ?? 'System notification'),
                    (string)($row['last_file_name'] ?? '')
                ),
                'time' => (string)$row['last_time'],
                'unread_count' => (int)($row['unread_count'] ?? 0),
                'mentioned' => false,
                'pinned' => true,
                'starred' => false,
            ];
            continue;
        }
        if (!preg_match('/^(\d+)@chat\.skylinkonline\.net$/i', $peerJid, $m)) continue;
        $peer = chat_user_payload(
            $employeePdo,
            (int)$m[1],
            $peerJid,
            isset($onlineJids[strtolower($peerJid)])
        );
        $groups[] = [
            'type' => 'chat',
            'id' => $peer['emp_id'],
            'name' => $peer['name'],
            'designation' => $peer['designation'],
            'jid' => $peerJid,
            'online' => $peer['online'] ?? false,
            'avatar_url' => (string)($peer['avatar_url'] ?? ''),
            'last' => chat_push_preview(
                (string)($row['last_body'] ?? 'Message'),
                (string)($row['last_file_name'] ?? '')
            ),
            'time' => (string)$row['last_time'],
            'unread_count' => (int)($row['unread_count'] ?? 0),
            'mentioned' => false,
            'pinned' => (int)($row['is_pinned'] ?? 0) === 1,
            'starred' => (int)($row['is_starred'] ?? 0) === 1,
        ];
    }
    $stmt = $pdo->prepare(
        'SELECT g.id, g.room_name, g.room_jid, g.avatar_url, g.group_type, g.channel_kind, g.created_at,
                COALESCE(pref.is_pinned, 0) AS is_pinned,
                COALESCE(pref.is_starred, 0) AS is_starred,
                COALESCE(gr.last_read_message_id, 0) AS last_read_message_id,
                last_msg.id AS last_message_id,
                last_msg.body AS last_body,
                last_msg.file_name AS last_file_name,
                last_msg.created_at AS last_time,
                (
                  SELECT COUNT(*)
                  FROM xmpp_messages unread
                  WHERE unread.to_jid = g.room_jid
                    AND unread.from_jid <> :me_unread_group
                    AND unread.id > COALESCE(gr.last_read_message_id, 0)
                    AND (unread.deleted_at IS NULL OR unread.deleted_at = \'0000-00-00 00:00:00\')
                ) AS unread_count,
                0 AS mentioned
         FROM xmpp_groups g
         INNER JOIN xmpp_group_members gm ON gm.group_id = g.id
         LEFT JOIN xmpp_group_reads gr
           ON gr.group_id = g.id AND gr.emp_id = gm.emp_id
         LEFT JOIN xmpp_conversation_preferences pref
           ON pref.emp_id = gm.emp_id AND pref.target_jid = g.room_jid
         LEFT JOIN xmpp_messages last_msg
           ON last_msg.id = (
             SELECT m2.id
             FROM xmpp_messages m2
             WHERE m2.to_jid = g.room_jid
               AND (m2.deleted_at IS NULL OR m2.deleted_at = \'0000-00-00 00:00:00\')
             ORDER BY m2.id DESC
             LIMIT 1
           )
         WHERE gm.emp_id = :emp_id AND g.is_archived = 0
         ORDER BY is_pinned DESC, COALESCE(last_msg.created_at, g.created_at) DESC, g.created_at DESC
         LIMIT 100'
    );
    $stmt->execute([
        ':emp_id' => (int)$session['emp_id'],
        ':me_unread_group' => $me,
    ]);
    foreach (($stmt->fetchAll(PDO::FETCH_ASSOC) ?: []) as $row) {
        $groups[] = [
            'type' => (string)($row['group_type'] ?? 'group'),
            'id' => (int)$row['id'],
            'name' => (($row['group_type'] ?? 'group') === 'channel' ? '#' : '') . (string)$row['room_name'],
            'jid' => (string)$row['room_jid'],
            'avatar_url' => chat_public_upload_url((string)($row['avatar_url'] ?? '')),
            'designation' => (($row['group_type'] ?? 'group') === 'channel') ? ucfirst(str_replace('_', ' ', (string)($row['channel_kind'] ?? 'operational'))) . ' channel' : 'Group conversation',
            'channel_kind' => (string)($row['channel_kind'] ?? ''),
            'last' => chat_push_preview(
                (string)($row['last_body'] ?? 'Group chat'),
                (string)($row['last_file_name'] ?? '')
            ),
            'time' => (string)($row['last_time'] ?? $row['created_at']),
            'unread_count' => max(0, (int)($row['unread_count'] ?? 0)),
            'mentioned' => (int)($row['mentioned'] ?? 0) === 1,
            'pinned' => (int)($row['is_pinned'] ?? 0) === 1,
            'starred' => (int)($row['is_starred'] ?? 0) === 1,
        ];
    }
} catch (Throwable $e) {
    error_log('chat/recent_chats skipped: ' . $e->getMessage());
}
usort($groups, static function(array $a, array $b): int {
    $pinOrder = ((int)($b['pinned'] ?? 0)) <=> ((int)($a['pinned'] ?? 0));
    if ($pinOrder !== 0) return $pinOrder;
    return strtotime((string)($b['time'] ?? '')) <=> strtotime((string)($a['time'] ?? ''));
});
chat_json(['status' => true, 'chats' => $groups]);


