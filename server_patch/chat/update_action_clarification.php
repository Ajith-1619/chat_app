<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/channel_action_helper.php';
require_once __DIR__ . '/conversation_metadata_helper.php';

$session = chat_require_user();
$pdo = chat_db();
chat_ensure_schema($pdo);
chat_channel_action_ensure_schema($pdo);

$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) $input = $_POST;
$groupId = max(0, (int)($input['group_id'] ?? 0));
$sourceMessageId = max(0, (int)($input['source_message_id'] ?? $input['message_id'] ?? 0));
$persons = trim((string)($input['next_action_persons'] ?? ''));
$date = trim((string)($input['next_action_date'] ?? ''));
$summary = trim((string)($input['next_action_summary'] ?? ''));
$text = trim((string)($input['next_action_text'] ?? ''));

if ($groupId <= 0 || $sourceMessageId <= 0) chat_json(['status' => false, 'error' => 'Group and source message are required'], 422);

$stmt = $pdo->prepare('SELECT g.*, gm.role FROM xmpp_groups g INNER JOIN xmpp_group_members gm ON gm.group_id = g.id WHERE g.id = :group_id AND gm.emp_id = :emp_id LIMIT 1');
$stmt->execute([':group_id' => $groupId, ':emp_id' => (int)$session['emp_id']]);
$group = $stmt->fetch(PDO::FETCH_ASSOC);
if (!$group) chat_json(['status' => false, 'error' => 'Conversation not found'], 404);
if (!chat_channel_action_is_channel($group)) chat_json(['status' => false, 'error' => 'Channel action metadata is only available for channels'], 422);

if ($date !== '') {
    $timestamp = strtotime($date);
    if ($timestamp === false) chat_json(['status' => false, 'error' => 'Invalid next action date'], 422);
    $date = date('Y-m-d H:i:s', $timestamp);
}

$missing = [];
if ($persons === '') $missing[] = 'person';
if ($date === '') $missing[] = 'date';

$update = $pdo->prepare('UPDATE xmpp_groups
    SET next_action_persons = CASE WHEN :persons_blank = 1 THEN next_action_persons ELSE :persons END,
        next_action_date = CASE WHEN :date_blank = 1 THEN next_action_date ELSE :next_date END,
        next_action_summary = CASE WHEN :summary_blank = 1 THEN next_action_summary ELSE :summary END,
        next_action_text = CASE WHEN :text_blank = 1 THEN next_action_text ELSE :action_text END,
        next_action_missing_fields = :missing_fields,
        next_action_updated_at = NOW()
    WHERE id = :group_id');
$update->execute([
    ':persons_blank' => $persons === '' ? 1 : 0,
    ':persons' => mb_substr($persons, 0, 2000),
    ':date_blank' => $date === '' ? 1 : 0,
    ':next_date' => $date,
    ':summary_blank' => $summary === '' ? 1 : 0,
    ':summary' => mb_substr($summary, 0, 1000),
    ':text_blank' => $text === '' ? 1 : 0,
    ':action_text' => mb_substr($text, 0, 4000),
    ':missing_fields' => $missing ? implode(',', $missing) : null,
    ':group_id' => $groupId,
]);

try {
    $timeline = $pdo->prepare('INSERT INTO xmpp_channel_timeline (group_id, event_type, body, actor_emp_id) VALUES (:group_id, :event_type, :body, :actor)');
    $timeline->execute([
        ':group_id' => $groupId,
        ':event_type' => 'next_action_clarified',
        ':body' => json_encode(['source_message_id' => $sourceMessageId, 'summary' => $summary, 'persons' => $persons, 'date' => $date], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
        ':actor' => (int)$session['emp_id'],
    ]);
} catch (Throwable $e) {
    error_log('channel action clarification timeline skipped: ' . $e->getMessage());
}

$refresh = $pdo->prepare('SELECT * FROM xmpp_groups WHERE id = :group_id LIMIT 1');
$refresh->execute([':group_id' => $groupId]);
$updatedGroup = $refresh->fetch(PDO::FETCH_ASSOC) ?: $group;
try {
    chat_metadata_sync_conversation($pdo, $updatedGroup, (int)$session['emp_id'], $sourceMessageId, 'clarification');
} catch (Throwable $e) {
    error_log('channel action clarification metadata skipped: ' . $e->getMessage());
}

chat_json([
    'status' => true,
    'channel' => [
        'next_action_summary' => (string)($updatedGroup['next_action_summary'] ?? ''),
        'next_action_text' => (string)($updatedGroup['next_action_text'] ?? ''),
        'next_action_persons' => (string)($updatedGroup['next_action_persons'] ?? ''),
        'next_action_date' => (string)($updatedGroup['next_action_date'] ?? ''),
        'next_action_missing_fields' => (string)($updatedGroup['next_action_missing_fields'] ?? ''),
        'next_action_updated_at' => (string)($updatedGroup['next_action_updated_at'] ?? ''),
    ],
]);
