<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/notification_helpers.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    chat_json(['status' => false, 'error' => 'POST required.'], 405);
}

$rawBody = file_get_contents('php://input') ?: '{}';
$input = json_decode($rawBody, true);
if (!is_array($input)) {
    chat_json(['status' => false, 'error' => 'Invalid JSON body.'], 400);
}

function flow_external_work_api_authorized(array $input): bool
{
    $defaultApiKey = 'skylink-flow-work-api-key-2026';
    $conversationApiKey = 'skylink-flow-conversation-api-key-2026';
    $configuredApiKey = trim((string)(getenv('SKYLINK_WORK_API_KEY') ?: getenv('SKYLINK_CONVERSATION_API_KEY') ?: ''));
    if (defined('SKYLINK_WORK_API_KEY')) {
        $configuredApiKey = trim((string)SKYLINK_WORK_API_KEY) ?: $configuredApiKey;
    }
    $validKeys = array_values(array_unique(array_filter([
        $defaultApiKey,
        $conversationApiKey,
        $configuredApiKey,
    ], static fn(string $key): bool => $key !== '')));
    $authorization = trim((string)($_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? ''));
    if ($authorization === '' && function_exists('getallheaders')) {
        foreach (getallheaders() ?: [] as $headerName => $headerValue) {
            if (strtolower((string)$headerName) === 'authorization') {
                $authorization = trim((string)$headerValue);
                break;
            }
        }
    }
    $providedKey = str_starts_with(strtolower($authorization), 'bearer ')
        ? trim(substr($authorization, 7))
        : trim((string)($_SERVER['HTTP_X_SKYLINK_WORK_KEY'] ?? $_SERVER['HTTP_X_SKYLINK_API_KEY'] ?? $input['api_key'] ?? $_GET['api_key'] ?? ''));
    foreach ($validKeys as $validKey) {
        if ($providedKey !== '' && hash_equals($validKey, $providedKey)) return true;
    }
    return false;
}

function flow_external_ids(mixed $value): array
{
    return array_values(array_unique(array_filter(
        array_map('intval', is_array($value) ? $value : []),
        static fn(int $id): bool => $id > 0
    )));
}

function flow_external_active_employee_ids(PDO $employeePdo, array $ids): array
{
    if (!$ids) return [];
    $ph = implode(',', array_fill(0, count($ids), '?'));
    $stmt = $employeePdo->prepare("SELECT emp_id FROM employee WHERE status = 1 AND emp_id IN ({$ph})");
    $stmt->execute($ids);
    return array_values(array_unique(array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN) ?: [])));
}

if (!flow_external_work_api_authorized($input)) {
    chat_json(['status' => false, 'error' => 'Work API authorization failed.'], 401);
}

$creatorEmpId = max(0, (int)($input['created_by_emp_id'] ?? $input['creator_emp_id'] ?? 0));
if ($creatorEmpId <= 0) {
    chat_json(['status' => false, 'error' => 'created_by_emp_id is required.'], 422);
}
$kind = strtolower(trim((string)($input['kind'] ?? $input['type'] ?? 'reminder')));
if ($kind === 'follow_up') $kind = 'followup';
if (!in_array($kind, ['reminder', 'followup'], true)) $kind = 'reminder';
$title = trim((string)($input['title'] ?? ''));
$notes = trim((string)($input['notes'] ?? $input['description'] ?? ''));
$startsInput = trim((string)($input['starts_at'] ?? $input['due_at'] ?? $input['remind_at'] ?? ''));
$recurrence = strtolower(trim((string)($input['recurrence'] ?? $input['recurrence_type'] ?? 'once')));
$customUnit = strtolower(trim((string)($input['custom_unit'] ?? 'week')));
$customInterval = max(1, min(365, (int)($input['custom_interval'] ?? 1)));
$assignees = flow_external_ids($input['assignee_ids'] ?? $input['assignees'] ?? []);
$weekdays = array_values(array_filter(flow_external_ids($input['weekdays'] ?? []), static fn(int $v): bool => $v >= 1 && $v <= 7));
$monthDays = array_values(array_filter(flow_external_ids($input['month_days'] ?? []), static fn(int $v): bool => $v >= 1 && $v <= 31));
if (!in_array($recurrence, ['once', 'daily', 'weekly', 'monthly', 'custom'], true)) $recurrence = 'once';
if (!in_array($customUnit, ['day', 'week', 'month'], true)) $customUnit = 'week';
if ($title === '') chat_json(['status' => false, 'error' => 'title is required.'], 422);
$startsTs = strtotime(str_replace('T', ' ', $startsInput));
if ($startsTs === false) chat_json(['status' => false, 'error' => 'Valid starts_at/due_at date time is required.'], 422);

try {
    $pdo = chat_db();
    $employeePdo = getEmployeeDB();
    chat_ensure_schema($pdo);
    $activeCreator = flow_external_active_employee_ids($employeePdo, [$creatorEmpId]);
    if (!$activeCreator) chat_json(['status' => false, 'error' => 'Creator employee is not active.'], 422);
    if (!$assignees) $assignees = [$creatorEmpId];
    $assignees = flow_external_active_employee_ids($employeePdo, $assignees);
    if (!$assignees) $assignees = [$creatorEmpId];
    if (!in_array($creatorEmpId, $assignees, true) && !empty($input['include_creator'])) $assignees[] = $creatorEmpId;
    $stmt = $pdo->prepare('INSERT INTO xmpp_reminders (kind, title, notes, created_by_emp_id, assignee_ids_json, source_conversation_jid, source_conversation_name, source_message_id, source_message_text, starts_at, next_due_at, recurrence_type, custom_interval, custom_unit, weekdays_json, month_days_json) VALUES (:kind, :title, :notes, :creator, :assignees, :source_jid, :source_name, :message_id, :message_text, :starts_at, :next_due_at, :recurrence, :custom_interval, :custom_unit, :weekdays, :month_days)');
    $stmt->execute([
        ':kind' => $kind,
        ':title' => mb_substr($title, 0, 255),
        ':notes' => $notes,
        ':creator' => $creatorEmpId,
        ':assignees' => json_encode(array_values(array_unique($assignees))),
        ':source_jid' => mb_substr(trim((string)($input['source_conversation_jid'] ?? '')), 0, 255),
        ':source_name' => mb_substr(trim((string)($input['source_conversation_name'] ?? $input['source'] ?? 'external_api')), 0, 160),
        ':message_id' => max(0, (int)($input['source_message_id'] ?? 0)) ?: null,
        ':message_text' => trim((string)($input['source_message_text'] ?? $input['reference_text'] ?? '')),
        ':starts_at' => date('Y-m-d H:i:s', $startsTs),
        ':next_due_at' => date('Y-m-d H:i:s', $startsTs),
        ':recurrence' => $recurrence,
        ':custom_interval' => $customInterval,
        ':custom_unit' => $customUnit,
        ':weekdays' => json_encode($weekdays),
        ':month_days' => json_encode($monthDays),
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
        'external-created:' . $id,
        $kindLabel . ' created: ' . $title . ' - ' . date('d M Y, h:i A', $startsTs)
    );
    chat_json([
        'status' => true,
        'id' => $id,
        'kind' => $kind,
        'title' => $title,
        'created_by_emp_id' => $creatorEmpId,
        'assignee_ids' => array_values(array_unique($assignees)),
        'starts_at' => date('Y-m-d H:i:s', $startsTs),
        'next_due_at' => date('Y-m-d H:i:s', $startsTs),
        'recurrence' => $recurrence,
    ]);
} catch (Throwable $e) {
    error_log('external create reminder failed: ' . $e->getMessage());
    chat_json(['status' => false, 'error' => 'Unable to create reminder/follow-up through external API.'], 500);
}
