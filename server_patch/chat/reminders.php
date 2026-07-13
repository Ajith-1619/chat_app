<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/notification_helpers.php';

$session = chat_require_user();
$empId = (int)$session['emp_id'];
$pdo = chat_db();

function reminder_ids(mixed $value): array {
    return array_values(array_unique(array_filter(array_map('intval', is_array($value) ? $value : []), static fn(int $id): bool => $id > 0)));
}
function reminder_row(array $row): array {
    $row['id'] = (int)$row['id'];
    $row['created_by_emp_id'] = (int)$row['created_by_emp_id'];
    $row['source_message_id'] = (int)($row['source_message_id'] ?? 0);
    $row['custom_interval'] = max(1, (int)($row['custom_interval'] ?? 1));
    $row['active'] = (int)($row['active'] ?? 0) === 1;
    $row['assignee_ids'] = reminder_ids(json_decode((string)($row['assignee_ids_json'] ?? '[]'), true));
    $row['weekdays'] = reminder_ids(json_decode((string)($row['weekdays_json'] ?? '[]'), true));
    $row['month_days'] = reminder_ids(json_decode((string)($row['month_days_json'] ?? '[]'), true));
    unset($row['assignee_ids_json'], $row['weekdays_json'], $row['month_days_json']);
    return $row;
}

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $stmt = $pdo->prepare("SELECT * FROM xmpp_reminders WHERE created_by_emp_id = :creator OR JSON_CONTAINS(assignee_ids_json, JSON_ARRAY(:assigned)) ORDER BY active DESC, starts_at ASC, id DESC LIMIT 500");
    $stmt->execute([':creator' => $empId, ':assigned' => $empId]);
    chat_json(['status' => true, 'items' => array_map('reminder_row', $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [])]);
}

$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid request body.'], 400);
$action = strtolower(trim((string)($input['action'] ?? 'create')));
if ($action === 'stop') {
    $id = max(0, (int)($input['id'] ?? 0));
    $find = $pdo->prepare(
        "SELECT * FROM xmpp_reminders WHERE id = :id AND active = 1
         AND (created_by_emp_id = :creator OR JSON_CONTAINS(assignee_ids_json, JSON_ARRAY(:assigned)))"
    );
    $find->execute([':id' => $id, ':creator' => $empId, ':assigned' => $empId]);
    $reminder = $find->fetch(PDO::FETCH_ASSOC);
    if (!$reminder) chat_json(['status' => false, 'error' => 'Active item not found.'], 404);
    $stmt = $pdo->prepare(
        "UPDATE xmpp_reminders SET active = 0, next_due_at = NULL,
         stopped_at = NOW(), stopped_by_emp_id = :emp WHERE id = :id AND active = 1"
    );
    $stmt->execute([':emp' => $empId, ':id' => $id]);
    $kindLabel = ($reminder['kind'] ?? 'reminder') === 'followup' ? 'Follow-up' : 'Reminder';
    notification_emit_to_recipients(
        $pdo,
        $reminder,
        'closed',
        'closed:' . $id . ':' . date('YmdHis'),
        $kindLabel . ' closed: ' . (string)$reminder['title']
    );
    chat_json(['status' => true]);
}
$kind = strtolower(trim((string)($input['kind'] ?? 'reminder')));
$title = trim((string)($input['title'] ?? ''));
$notes = trim((string)($input['notes'] ?? ''));
$startsInput = trim((string)($input['starts_at'] ?? ''));
$recurrence = strtolower(trim((string)($input['recurrence'] ?? 'once')));
$customUnit = strtolower(trim((string)($input['custom_unit'] ?? 'week')));
$customInterval = max(1, min(365, (int)($input['custom_interval'] ?? 1)));
$assignees = reminder_ids($input['assignee_ids'] ?? []);
$weekdays = array_values(array_filter(reminder_ids($input['weekdays'] ?? []), static fn(int $v): bool => $v >= 1 && $v <= 7));
$monthDays = array_values(array_filter(reminder_ids($input['month_days'] ?? []), static fn(int $v): bool => $v >= 1 && $v <= 31));
if (!in_array($kind, ['reminder', 'followup'], true)) $kind = 'reminder';
if (!in_array($recurrence, ['once', 'daily', 'weekly', 'monthly', 'custom'], true)) $recurrence = 'once';
if (!in_array($customUnit, ['day', 'week', 'month'], true)) $customUnit = 'week';
if ($title === '') chat_json(['status' => false, 'error' => 'Please enter a title.'], 422);
if (!$assignees) $assignees = [$empId];
$startsTs = strtotime(str_replace('T', ' ', $startsInput));
if ($startsTs === false) chat_json(['status' => false, 'error' => 'Select a valid date and time.'], 422);

$stmt = $pdo->prepare('INSERT INTO xmpp_reminders (kind, title, notes, created_by_emp_id, assignee_ids_json, source_conversation_jid, source_conversation_name, source_message_id, source_message_text, starts_at, next_due_at, recurrence_type, custom_interval, custom_unit, weekdays_json, month_days_json) VALUES (:kind, :title, :notes, :creator, :assignees, :source_jid, :source_name, :message_id, :message_text, :starts_at, :next_due_at, :recurrence, :custom_interval, :custom_unit, :weekdays, :month_days)');
$stmt->execute([
    ':kind' => $kind, ':title' => $title, ':notes' => $notes, ':creator' => $empId,
    ':assignees' => json_encode($assignees),
    ':source_jid' => substr(trim((string)($input['source_conversation_jid'] ?? '')), 0, 255),
    ':source_name' => substr(trim((string)($input['source_conversation_name'] ?? '')), 0, 160),
    ':message_id' => max(0, (int)($input['source_message_id'] ?? 0)) ?: null,
    ':message_text' => trim((string)($input['source_message_text'] ?? '')),
    ':starts_at' => date('Y-m-d H:i:s', $startsTs), ':next_due_at' => date('Y-m-d H:i:s', $startsTs),
    ':recurrence' => $recurrence,
    ':custom_interval' => $customInterval, ':custom_unit' => $customUnit,
    ':weekdays' => json_encode($weekdays), ':month_days' => json_encode($monthDays),
]);
$id = (int)$pdo->lastInsertId();
$find = $pdo->prepare('SELECT * FROM xmpp_reminders WHERE id = :id');
$find->execute([':id' => $id]);
$reminder = $find->fetch(PDO::FETCH_ASSOC) ?: [];
$kindLabel = $kind === 'followup' ? 'Follow-up' : 'Reminder';
notification_emit_to_recipients(
    $pdo,
    $reminder,
    'created',
    'created:' . $id,
    $kindLabel . ' created: ' . $title . ' · ' . date('d M Y, h:i A', $startsTs)
);
chat_json(['status' => true, 'id' => $id]);