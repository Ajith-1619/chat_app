<?php
declare(strict_types=1);

require_once __DIR__ . '/../../_shared/bootstrap.php';

flow_api_cors();
$auth = flow_api_auth(['channels:write']);

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
if (!in_array($method, ['POST', 'PATCH', 'DELETE'], true)) {
    flow_api_error('Method not allowed.', 405, 'METHOD_NOT_ALLOWED');
}

$pdo = flow_api_chat_db();
$input = $method === 'DELETE' ? [] : flow_api_input();
$action = strtolower(trim((string)($input['action'] ?? 'close')));
if (!in_array($action, ['close', 'archive', 'unarchive', 'delete'], true)) {
    flow_api_error('action must be close, archive, unarchive, or delete.', 422, 'VALIDATION_ERROR');
}

$channelId = (int)($input['channel_id'] ?? $input['id'] ?? 0);
if ($channelId <= 0) {
    $roomJid = trim((string)($input['room_jid'] ?? ''));
    if ($roomJid !== '') {
        $find = $pdo->prepare('SELECT id FROM xmpp_groups WHERE room_jid = :jid AND group_type = "channel" LIMIT 1');
        $find->execute([':jid' => $roomJid]);
        $channelId = (int)($find->fetchColumn() ?: 0);
    }
}
if ($channelId <= 0) {
    flow_api_error('channel_id, id, or room_jid is required.', 422, 'VALIDATION_ERROR');
}

if (in_array($action, ['close', 'archive', 'unarchive'], true)) {
    $status = $action === 'close' ? 'Closed' : ($action === 'archive' ? 'Archived' : 'Open');
    $archived = $action === 'unarchive' ? 0 : 1;
    $archivedSql = $archived ? 'NOW()' : 'NULL';
    $stmt = $pdo->prepare('UPDATE xmpp_groups SET is_archived = :archived, archived_at = ' . $archivedSql . ', status = :status WHERE id = :id AND group_type = "channel"');
    $stmt->execute([':archived' => $archived, ':status' => $status, ':id' => $channelId]);

    if ($action === 'close') {
        try {
            $timeline = $pdo->prepare('INSERT INTO xmpp_channel_timeline (group_id, event_type, event_title, event_body, actor_emp_id) VALUES (:group_id, :event_type, :event_title, :event_body, :actor_emp_id)');
            $timeline->execute([
                ':group_id' => $channelId,
                ':event_type' => 'channel.closed',
                ':event_title' => 'Channel closed',
                ':event_body' => 'Channel closed through external API.',
                ':actor_emp_id' => (int)$auth['actor_emp_id'],
            ]);
        } catch (Throwable $e) {
            error_log('Flow API physical channel close timeline failed: ' . $e->getMessage());
        }
    }

    flow_api_success(
        $auth,
        'channels:write',
        ['channel' => ['id' => $channelId, 'action' => $action, 'is_archived' => $archived, 'status' => $status]],
        200,
        'channel',
        (string)$channelId
    );
}

$pdo->prepare('UPDATE xmpp_groups SET is_archived = 1, archived_at = NOW(), status = "Deleted" WHERE id = :id AND group_type = "channel"')
    ->execute([':id' => $channelId]);

flow_api_success(
    $auth,
    'channels:write',
    ['channel' => ['id' => $channelId, 'action' => 'delete', 'is_archived' => 1, 'status' => 'Deleted']],
    200,
    'channel',
    (string)$channelId
);