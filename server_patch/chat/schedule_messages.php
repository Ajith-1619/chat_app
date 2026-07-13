<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$empId = (int)$session['emp_id'];
$pdo = chat_db();

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $stmt = $pdo->prepare(
        "SELECT s.id, s.body, s.scheduled_at, s.status, s.created_at,
                COUNT(t.id) AS target_count,
                SUM(t.status = 'sent') AS sent_count,
                SUM(t.status = 'failed') AS failed_count
         FROM xmpp_scheduled_messages s
         LEFT JOIN xmpp_scheduled_message_targets t ON t.schedule_id = s.id
         WHERE s.created_by_emp_id = :emp
         GROUP BY s.id ORDER BY s.scheduled_at DESC LIMIT 200"
    );
    $stmt->execute([':emp' => $empId]);
    chat_json(['status' => true, 'items' => $stmt->fetchAll(PDO::FETCH_ASSOC) ?: []]);
}

$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid request body.'], 400);
$body = trim((string)($input['message'] ?? ''));
$scheduledInput = trim((string)($input['scheduled_at'] ?? ''));
$targets = array_values(array_unique(array_filter(array_map(
    static fn(mixed $value): string => strtolower(trim((string)$value)),
    (array)($input['targets'] ?? [])
))));
if ($body === '' || mb_strlen($body) > 4000) {
    chat_json(['status' => false, 'error' => 'Enter a message up to 4000 characters.'], 422);
}
$scheduledTs = strtotime(str_replace('T', ' ', $scheduledInput));
if ($scheduledTs === false || $scheduledTs <= time()) {
    chat_json(['status' => false, 'error' => 'Select a future date and time.'], 422);
}
if (!$targets || count($targets) > 100) {
    chat_json(['status' => false, 'error' => 'Select between 1 and 100 recipients.'], 422);
}
foreach ($targets as $target) {
    if (!chat_is_user_jid($target) && !chat_is_room_jid($target)) {
        chat_json(['status' => false, 'error' => 'One or more recipients are invalid.'], 422);
    }
    if (chat_is_room_jid($target) && !chat_group_for_member($pdo, $target, $empId)) {
        chat_json(['status' => false, 'error' => 'You are not a member of one selected group/channel.'], 403);
    }
}

$pdo->beginTransaction();
try {
    $stmt = $pdo->prepare(
        'INSERT INTO xmpp_scheduled_messages
         (created_by_emp_id, body, scheduled_at, silent, status)
         VALUES (:creator, :body, :scheduled_at, :silent, :status)'
    );
    $stmt->execute([
        ':creator' => $empId,
        ':body' => $body,
        ':scheduled_at' => date('Y-m-d H:i:s', $scheduledTs),
        ':silent' => !empty($input['silent']) ? 1 : 0,
        ':status' => 'scheduled',
    ]);
    $scheduleId = (int)$pdo->lastInsertId();
    $targetStmt = $pdo->prepare(
        'INSERT INTO xmpp_scheduled_message_targets
         (schedule_id, target_jid, status) VALUES (:schedule_id, :target, :status)'
    );
    foreach ($targets as $target) {
        $targetStmt->execute([
            ':schedule_id' => $scheduleId,
            ':target' => $target,
            ':status' => 'pending',
        ]);
    }
    $pdo->commit();
    chat_json([
        'status' => true,
        'schedule_id' => $scheduleId,
        'target_count' => count($targets),
    ]);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    error_log('schedule message failed: ' . $e->getMessage());
    chat_json(['status' => false, 'error' => 'Unable to schedule the message.'], 500);
}