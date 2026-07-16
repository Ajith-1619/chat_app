<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);

$messageId = (int)($input['message_id'] ?? 0);
$itemIndex = (int)($input['item_index'] ?? -1);
if ($messageId <= 0 || $itemIndex < 0) {
    chat_json(['status' => false, 'error' => 'Valid checklist item is required'], 422);
}

try {
    $pdo = chat_db();
    chat_ensure_schema($pdo);
    $pdo->beginTransaction();

    $stmt = $pdo->prepare(
        'SELECT id, from_jid, to_jid, body, message_type
         FROM xmpp_messages
         WHERE id = :id AND deleted_at IS NULL
         FOR UPDATE'
    );
    $stmt->execute([':id' => $messageId]);
    $message = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$message) {
        $pdo->rollBack();
        chat_json(['status' => false, 'error' => 'Checklist not found'], 404);
    }

    $myJid = chat_jid((int)$session['emp_id']);
    $fromJid = strtolower((string)$message['from_jid']);
    $toJid = strtolower((string)$message['to_jid']);
    $type = strtolower((string)$message['message_type']);
    $allowed = false;
    if ($type === 'groupchat') {
        try {
            chat_group_for_member($pdo, $toJid, (int)$session['emp_id']);
            $allowed = true;
        } catch (Throwable $ignored) {
            $allowed = false;
        }
    } else {
        $allowed = ($fromJid === strtolower($myJid) || $toJid === strtolower($myJid));
    }
    if (!$allowed) {
        $pdo->rollBack();
        chat_json(['status' => false, 'error' => 'You are not a participant in this checklist'], 403);
    }

    $prefix = 'SKYLINK_CHECKLIST:';
    $body = (string)$message['body'];
    if (!str_starts_with($body, $prefix)) {
        $pdo->rollBack();
        chat_json(['status' => false, 'error' => 'Message is not a checklist'], 422);
    }
    $checklist = json_decode(substr($body, strlen($prefix)), true);
    if (!is_array($checklist) || !isset($checklist['items']) || !is_array($checklist['items']) || !isset($checklist['items'][$itemIndex])) {
        $pdo->rollBack();
        chat_json(['status' => false, 'error' => 'Checklist item not found'], 404);
    }

    $item = &$checklist['items'][$itemIndex];
    $checkedBy = isset($item['checked_by']) && is_array($item['checked_by'])
        ? array_values(array_unique(array_filter(array_map('intval', $item['checked_by']), static fn(int $id): bool => $id > 0)))
        : [];
    $me = (int)$session['emp_id'];
    $wasDone = (bool)($item['done'] ?? false);
    if ($wasDone) {
        $item['done'] = false;
        $checkedBy = array_values(array_filter($checkedBy, static fn(int $id): bool => $id !== $me));
    } else {
        $item['done'] = true;
        if (!in_array($me, $checkedBy, true)) $checkedBy[] = $me;
    }
    $item['checked_by'] = $checkedBy;
    $item['updated_by'] = $me;
    $item['updated_at'] = date(DATE_ATOM);
    unset($item);
    $updatedBody = $prefix . json_encode($checklist, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

    $update = $pdo->prepare('UPDATE xmpp_messages SET body = :body, edited_at = NOW() WHERE id = :id');
    $update->execute([':body' => $updatedBody, ':id' => $messageId]);
    $pdo->commit();

    chat_json([
        'status' => true,
        'message_id' => $messageId,
        'item_index' => $itemIndex,
        'body' => $updatedBody,
    ]);
} catch (Throwable $e) {
    if (isset($pdo) && $pdo->inTransaction()) $pdo->rollBack();
    error_log('chat/checklist_toggle failed: ' . $e->getMessage());
    chat_json(['status' => false, 'error' => 'Unable to update checklist'], 500);
}