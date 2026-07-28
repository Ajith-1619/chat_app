<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/PluginEventBus.php';

function chat_ensure_broadcast_schema(PDO $pdo): void
{
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_broadcast_lists (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            owner_emp_id INT NOT NULL,
            title VARCHAR(160) NOT NULL,
            status VARCHAR(24) NOT NULL DEFAULT \'active\',
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_broadcast_owner_status (owner_emp_id, status, updated_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_broadcast_recipients (
            list_id BIGINT NOT NULL,
            emp_id INT NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (list_id, emp_id),
            INDEX idx_broadcast_recipient_emp (emp_id, list_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_broadcast_sends (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            list_id BIGINT NOT NULL,
            sender_emp_id INT NOT NULL,
            body TEXT NOT NULL,
            recipient_count INT NOT NULL DEFAULT 0,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_broadcast_sends_list_created (list_id, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_broadcast_message_map (
            send_id BIGINT NOT NULL,
            message_id BIGINT NOT NULL,
            recipient_emp_id INT NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (send_id, message_id),
            INDEX idx_broadcast_message_recipient (recipient_emp_id, message_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
}

function chat_require_broadcast_creator(PDO $chatPdo, PDO $employeePdo, int $empId): string
{
    $type = chat_employee_type($chatPdo, $employeePdo, $empId);
    if ($type !== 'A') {
        chat_json([
            'status' => false,
            'error' => 'Only Type A users can create and send broadcasts.',
            'employee_type' => $type,
        ], 403);
    }
    return $type;
}

function chat_broadcast_valid_recipients(PDO $employeePdo, array $ids, int $senderEmpId): array
{
    $ids = array_values(array_unique(array_filter(array_map('intval', $ids), static fn(int $id): bool => $id > 0 && $id !== $senderEmpId)));
    if (!$ids) return [];
    $ph = implode(',', array_fill(0, count($ids), '?'));
    $stmt = $employeePdo->prepare("SELECT emp_id FROM employee WHERE status = 1 AND emp_id IN ({$ph})");
    $stmt->execute($ids);
    return array_values(array_unique(array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN) ?: [])));
}

function chat_broadcast_load_lists(PDO $pdo, int $ownerEmpId): array
{
    $stmt = $pdo->prepare(
        'SELECT l.id, l.title, l.status, l.created_at, l.updated_at,
                COUNT(r.emp_id) AS recipient_count,
                MAX(s.created_at) AS last_sent_at
         FROM xmpp_broadcast_lists l
         LEFT JOIN xmpp_broadcast_recipients r ON r.list_id = l.id
         LEFT JOIN xmpp_broadcast_sends s ON s.list_id = l.id
         WHERE l.owner_emp_id = :owner AND l.status <> \'deleted\'
         GROUP BY l.id, l.title, l.status, l.created_at, l.updated_at
         ORDER BY COALESCE(MAX(s.created_at), l.updated_at) DESC
         LIMIT 100'
    );
    $stmt->execute([':owner' => $ownerEmpId]);
    $lists = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
    if (!$lists) return [];

    $ids = array_map(static fn(array $row): int => (int)$row['id'], $lists);
    $ph = implode(',', array_fill(0, count($ids), '?'));
    $recipientStmt = $pdo->prepare("SELECT list_id, emp_id FROM xmpp_broadcast_recipients WHERE list_id IN ({$ph}) ORDER BY emp_id ASC");
    $recipientStmt->execute($ids);
    $recipientsByList = [];
    foreach ($recipientStmt->fetchAll(PDO::FETCH_ASSOC) ?: [] as $row) {
        $recipientsByList[(int)$row['list_id']][] = (int)$row['emp_id'];
    }
    foreach ($lists as &$list) {
        $listId = (int)$list['id'];
        $list['recipient_emp_ids'] = $recipientsByList[$listId] ?? [];
    }
    unset($list);
    return $lists;
}

function chat_broadcast_owned_active(PDO $pdo, int $listId, int $ownerEmpId): array
{
    $stmt = $pdo->prepare('SELECT id, title FROM xmpp_broadcast_lists WHERE id = :id AND owner_emp_id = :owner AND status = \'active\' LIMIT 1');
    $stmt->execute([':id' => $listId, ':owner' => $ownerEmpId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) chat_json(['status' => false, 'error' => 'Broadcast list not found.'], 404);
    return $row;
}

function chat_broadcast_replace_recipients(PDO $pdo, int $listId, array $recipients): void
{
    $pdo->prepare('DELETE FROM xmpp_broadcast_recipients WHERE list_id = :list_id')->execute([':list_id' => $listId]);
    $memberStmt = $pdo->prepare('INSERT INTO xmpp_broadcast_recipients (list_id, emp_id) VALUES (:list_id, :emp_id)');
    foreach ($recipients as $empId) {
        $memberStmt->execute([':list_id' => $listId, ':emp_id' => $empId]);
    }
}

$session = chat_require_user();
$chatPdo = chat_db();
$employeePdo = getEmployeeDB();
chat_ensure_schema($chatPdo);
chat_ensure_broadcast_schema($chatPdo);
$senderEmpId = (int)$session['emp_id'];
$employeeType = chat_employee_type($chatPdo, $employeePdo, $senderEmpId);

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    chat_json([
        'status' => true,
        'can_create' => $employeeType === 'A',
        'employee_type' => $employeeType,
        'broadcasts' => chat_broadcast_load_lists($chatPdo, $senderEmpId),
    ]);
}

chat_require_broadcast_creator($chatPdo, $employeePdo, $senderEmpId);
$raw = file_get_contents('php://input') ?: '{}';
$in = json_decode($raw, true);
if (!is_array($in)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
$action = strtolower(trim((string)($in['action'] ?? 'send')));
$title = trim((string)($in['title'] ?? ''));
if ($title === '') $title = 'Broadcast';
$title = mb_substr($title, 0, 160);

if ($action === 'create' || $action === 'save' || $action === 'update') {
    $listId = (int)($in['broadcast_id'] ?? $in['id'] ?? 0);
    $recipients = chat_broadcast_valid_recipients($employeePdo, (array)($in['recipient_emp_ids'] ?? $in['recipients'] ?? []), $senderEmpId);
    if (!$recipients) chat_json(['status' => false, 'error' => 'Select at least one valid recipient.'], 422);
    $chatPdo->beginTransaction();
    if ($listId > 0) {
        chat_broadcast_owned_active($chatPdo, $listId, $senderEmpId);
        $stmt = $chatPdo->prepare('UPDATE xmpp_broadcast_lists SET title = :title, updated_at = NOW() WHERE id = :id AND owner_emp_id = :owner');
        $stmt->execute([':title' => $title, ':id' => $listId, ':owner' => $senderEmpId]);
    } else {
        $stmt = $chatPdo->prepare('INSERT INTO xmpp_broadcast_lists (owner_emp_id, title) VALUES (:owner, :title)');
        $stmt->execute([':owner' => $senderEmpId, ':title' => $title]);
        $listId = (int)$chatPdo->lastInsertId();
    }
    chat_broadcast_replace_recipients($chatPdo, $listId, $recipients);
    $chatPdo->commit();
    chat_json(['status' => true, 'broadcast_id' => $listId, 'title' => $title, 'recipient_count' => count($recipients), 'recipient_emp_ids' => $recipients]);
}

if ($action === 'delete') {
    $listId = (int)($in['broadcast_id'] ?? $in['id'] ?? 0);
    if ($listId <= 0) chat_json(['status' => false, 'error' => 'Broadcast list is required.'], 422);
    chat_broadcast_owned_active($chatPdo, $listId, $senderEmpId);
    $stmt = $chatPdo->prepare('UPDATE xmpp_broadcast_lists SET status = \'deleted\', updated_at = NOW() WHERE id = :id AND owner_emp_id = :owner');
    $stmt->execute([':id' => $listId, ':owner' => $senderEmpId]);
    chat_json(['status' => true, 'broadcast_id' => $listId]);
}

if ($action !== 'send') chat_json(['status' => false, 'error' => 'Unknown broadcast action.'], 422);
$body = trim((string)($in['message'] ?? $in['body'] ?? ''));
if ($body === '') chat_json(['status' => false, 'error' => 'Broadcast message cannot be empty.'], 422);
$listId = (int)($in['broadcast_id'] ?? 0);
$inputRecipients = (array)($in['recipient_emp_ids'] ?? $in['recipients'] ?? []);
if ($listId > 0 && !$inputRecipients) {
    chat_broadcast_owned_active($chatPdo, $listId, $senderEmpId);
    $recipientStmt = $chatPdo->prepare('SELECT emp_id FROM xmpp_broadcast_recipients WHERE list_id = :list_id ORDER BY emp_id ASC');
    $recipientStmt->execute([':list_id' => $listId]);
    $recipients = array_values(array_map('intval', $recipientStmt->fetchAll(PDO::FETCH_COLUMN) ?: []));
} else {
    $recipients = chat_broadcast_valid_recipients($employeePdo, $inputRecipients, $senderEmpId);
}
if (!$recipients) chat_json(['status' => false, 'error' => 'Select at least one valid recipient.'], 422);
$sourceName = trim((string)($in['source_name'] ?? 'Broadcast'));
$sourceDevice = trim((string)($in['source_device'] ?? 'api')) ?: 'api';
$fromJid = chat_jid($senderEmpId);
$sender = chat_user_payload($employeePdo, $senderEmpId, $fromJid, false);

$chatPdo->beginTransaction();
if ($listId > 0) {
    chat_broadcast_owned_active($chatPdo, $listId, $senderEmpId);
    $chatPdo->prepare('UPDATE xmpp_broadcast_lists SET title = :title, updated_at = NOW() WHERE id = :id AND owner_emp_id = :owner')
        ->execute([':title' => $title, ':id' => $listId, ':owner' => $senderEmpId]);
} else {
    $stmt = $chatPdo->prepare('INSERT INTO xmpp_broadcast_lists (owner_emp_id, title) VALUES (:owner, :title)');
    $stmt->execute([':owner' => $senderEmpId, ':title' => $title]);
    $listId = (int)$chatPdo->lastInsertId();
}
if ($inputRecipients) {
    chat_broadcast_replace_recipients($chatPdo, $listId, $recipients);
}
$sendStmt = $chatPdo->prepare('INSERT INTO xmpp_broadcast_sends (list_id, sender_emp_id, body, recipient_count) VALUES (:list_id, :sender, :body, :count)');
$sendStmt->execute([':list_id' => $listId, ':sender' => $senderEmpId, ':body' => $body, ':count' => count($recipients)]);
$sendId = (int)$chatPdo->lastInsertId();
$messageStmt = $chatPdo->prepare('INSERT INTO xmpp_messages (from_jid, to_jid, body, message_type, source_device, source_name, status) VALUES (:from_jid, :to_jid, :body, \'chat\', :source_device, :source_name, \'sent\')');
$mapStmt = $chatPdo->prepare('INSERT INTO xmpp_broadcast_message_map (send_id, message_id, recipient_emp_id) VALUES (:send_id, :message_id, :recipient_emp_id)');
$messageIds = [];
foreach ($recipients as $empId) {
    $toJid = chat_jid($empId);
    $messageStmt->execute([
        ':from_jid' => $fromJid,
        ':to_jid' => $toJid,
        ':body' => $body,
        ':source_device' => mb_substr($sourceDevice, 0, 32),
        ':source_name' => mb_substr($sourceName, 0, 120),
    ]);
    $messageId = (int)$chatPdo->lastInsertId();
    $messageIds[] = $messageId;
    $mapStmt->execute([':send_id' => $sendId, ':message_id' => $messageId, ':recipient_emp_id' => $empId]);
}
$chatPdo->commit();

$xmppErrors = 0;
foreach ($recipients as $empId) {
    $toJid = chat_jid($empId);
    try {
        chat_ejabberd_client()->sendMessage($fromJid, $toJid, $body);
    } catch (Throwable $e) {
        $xmppErrors++;
        error_log('chat/broadcast xmpp send skipped for ' . $empId . ': ' . $e->getMessage());
    }
    try {
        chat_enqueue_push_notification($chatPdo, $senderEmpId, (string)$sender['name'], $toJid, $body, '', '', [], [$empId]);
    } catch (Throwable $e) {
        error_log('chat/broadcast push queue skipped for ' . $empId . ': ' . $e->getMessage());
    }
}
chat_spawn_push_worker();
foreach ($messageIds as $messageId) {
    flow_plugin_emit($chatPdo, 'message.sent', [
        'event_id' => 'broadcast-message-sent-' . $messageId,
        'actor_emp_id' => $senderEmpId,
        'broadcast_id' => $listId,
        'broadcast_send_id' => $sendId,
        'message' => ['id' => $messageId, 'from_jid' => $fromJid, 'body' => $body, 'message_type' => 'chat', 'created_at' => date('c')],
    ]);
}
chat_json([
    'status' => true,
    'broadcast_id' => $listId,
    'send_id' => $sendId,
    'recipient_count' => count($recipients),
    'message_ids' => $messageIds,
    'xmpp_error_count' => $xmppErrors,
]);
