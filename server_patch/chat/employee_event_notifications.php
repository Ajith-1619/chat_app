<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/SystemNotification.php';

function chat_employee_event_columns(PDO $pdo): array
{
    $stmt = $pdo->prepare(
        'SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :table_name'
    );
    $stmt->execute([':table_name' => 'employee']);
    $columns = [];
    foreach ($stmt->fetchAll(PDO::FETCH_COLUMN) ?: [] as $column) {
        $columns[strtolower((string)$column)] = (string)$column;
    }
    return $columns;
}

function chat_employee_event_column(array $columns, array $candidates, string $fallback): string
{
    foreach ($candidates as $candidate) {
        $key = strtolower($candidate);
        if (isset($columns[$key])) return $columns[$key];
    }
    return $fallback;
}

function chat_employee_event_ensure_schema(PDO $pdo): void
{
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS xmpp_employee_event_notifications (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            event_date DATE NOT NULL,
            event_type VARCHAR(40) NOT NULL,
            employee_emp_id INT NOT NULL,
            recipient_emp_id INT NOT NULL,
            message_id BIGINT NULL,
            status VARCHAR(24) NOT NULL DEFAULT \'sent\',
            error TEXT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY uniq_employee_event_recipient (event_date, event_type, employee_emp_id, recipient_emp_id),
            INDEX idx_employee_event_date (event_date, event_type)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
}

function chat_employee_event_authorized(array $input): bool
{
    if (PHP_SAPI === 'cli') return true;
    $defaultKey = 'skylink-notification-api-key-2026';
    $configuredKey = trim((string)(getenv('SKYLINK_NOTIFICATION_API_KEY') ?: ''));
    $validKeys = array_values(array_unique(array_filter([$defaultKey, $configuredKey])));
    $authorization = trim((string)($_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? ''));
    if ($authorization === '' && function_exists('getallheaders')) {
        foreach (getallheaders() ?: [] as $name => $value) {
            if (strtolower((string)$name) === 'authorization') {
                $authorization = trim((string)$value);
                break;
            }
        }
    }
    $provided = str_starts_with(strtolower($authorization), 'bearer ')
        ? trim(substr($authorization, 7))
        : trim((string)($_SERVER['HTTP_X_SKYLINK_NOTIFICATION_KEY'] ?? $input['api_key'] ?? $_GET['api_key'] ?? ''));
    foreach ($validKeys as $key) {
        if ($provided !== '' && hash_equals((string)$key, $provided)) return true;
    }
    return false;
}

function chat_employee_event_date_value(mixed $value): ?DateTimeImmutable
{
    $text = trim((string)$value);
    if ($text === '' || $text === '0000-00-00' || $text === '0000-00-00 00:00:00') return null;
    try {
        return new DateTimeImmutable($text);
    } catch (Throwable) {
        return null;
    }
}

$raw = file_get_contents('php://input') ?: '{}';
$input = json_decode($raw, true);
if (!is_array($input)) $input = [];

if (!chat_employee_event_authorized($input)) {
    chat_json(['status' => false, 'error' => 'Unauthorized'], 401);
}

$targetDateText = trim((string)($input['date'] ?? $_GET['date'] ?? date('Y-m-d')));
try {
    $targetDate = new DateTimeImmutable($targetDateText);
} catch (Throwable) {
    chat_json(['status' => false, 'error' => 'Invalid date'], 422);
}
$eventDate = $targetDate->format('Y-m-d');
$monthDay = $targetDate->format('m-d');

$chatPdo = chat_db();
$employeePdo = getEmployeeDB();
chat_ensure_schema($chatPdo);
chat_employee_event_ensure_schema($chatPdo);
$columns = chat_employee_event_columns($employeePdo);
if (!isset($columns['emp_id']) || !isset($columns['dob']) || !isset($columns['doj'])) {
    chat_json(['status' => false, 'error' => 'employee table must contain emp_id, dob and doj columns.'], 500);
}
$nameColumn = chat_employee_event_column($columns, ['name', 'emp_name', 'employee_name', 'full_name'], 'emp_id');
$designationColumn = chat_employee_event_column($columns, ['designation', 'desig_name', 'role'], 'emp_id');
$statusFilter = isset($columns['status']) ? 'WHERE status = 1' : '';

$employeeSql = "SELECT emp_id, `{$nameColumn}` AS employee_name, `{$designationColumn}` AS designation, dob, doj FROM employee {$statusFilter} ORDER BY employee_name ASC";
$stmt = $employeePdo->query($employeeSql);
$employees = $stmt ? ($stmt->fetchAll(PDO::FETCH_ASSOC) ?: []) : [];
$activeRecipients = array_values(array_unique(array_filter(array_map(static fn(array $row): int => (int)($row['emp_id'] ?? 0), $employees), static fn(int $id): bool => $id > 0)));

$celebrations = [];
foreach ($employees as $employee) {
    $empId = (int)($employee['emp_id'] ?? 0);
    if ($empId <= 0) continue;
    $name = trim((string)($employee['employee_name'] ?? '')) ?: ('Employee ' . $empId);
    $designation = trim((string)($employee['designation'] ?? ''));
    $dob = chat_employee_event_date_value($employee['dob'] ?? null);
    if ($dob && $dob->format('m-d') === $monthDay) {
        $celebrations[] = [
            'type' => 'birthday',
            'emp_id' => $empId,
            'name' => $name,
            'message' => 'Birthday reminder: Today is ' . $name . ($designation !== '' ? ' (' . $designation . ')' : '') . "'s birthday.",
        ];
    }
    $doj = chat_employee_event_date_value($employee['doj'] ?? null);
    if ($doj && $doj->format('m-d') === $monthDay && $doj < $targetDate) {
        $years = max(1, (int)$doj->diff($targetDate)->y);
        $celebrations[] = [
            'type' => 'work_anniversary',
            'emp_id' => $empId,
            'name' => $name,
            'message' => 'Work anniversary reminder: Today is ' . $name . ($designation !== '' ? ' (' . $designation . ')' : '') . "'s " . $years . '-year work anniversary with Skylink.',
        ];
    }
}

$sent = 0;
$duplicates = 0;
$failed = 0;
$errors = [];
$logCheck = $chatPdo->prepare('SELECT message_id FROM xmpp_employee_event_notifications WHERE event_date = :event_date AND event_type = :event_type AND employee_emp_id = :employee_emp_id AND recipient_emp_id = :recipient_emp_id LIMIT 1');
$logInsert = $chatPdo->prepare('INSERT INTO xmpp_employee_event_notifications (event_date, event_type, employee_emp_id, recipient_emp_id, message_id, status, error) VALUES (:event_date, :event_type, :employee_emp_id, :recipient_emp_id, :message_id, :status, :error) ON DUPLICATE KEY UPDATE message_id = COALESCE(message_id, VALUES(message_id)), status = VALUES(status), error = VALUES(error)');
foreach ($celebrations as $event) {
    foreach ($activeRecipients as $recipientEmpId) {
        $logCheck->execute([
            ':event_date' => $eventDate,
            ':event_type' => $event['type'],
            ':employee_emp_id' => (int)$event['emp_id'],
            ':recipient_emp_id' => $recipientEmpId,
        ]);
        if ($logCheck->fetchColumn()) {
            $duplicates++;
            continue;
        }
        try {
            $reference = 'employee_event:' . $eventDate . ':' . $event['type'] . ':' . (int)$event['emp_id'] . ':to:' . $recipientEmpId;
            $result = chat_send_system_notification($recipientEmpId, (string)$event['message'], (string)$event['type'], $reference);
            $messageId = (int)($result['message_id'] ?? 0);
            $logInsert->execute([
                ':event_date' => $eventDate,
                ':event_type' => $event['type'],
                ':employee_emp_id' => (int)$event['emp_id'],
                ':recipient_emp_id' => $recipientEmpId,
                ':message_id' => $messageId > 0 ? $messageId : null,
                ':status' => 'sent',
                ':error' => null,
            ]);
            if (!empty($result['duplicate'])) $duplicates++; else $sent++;
        } catch (Throwable $e) {
            $failed++;
            $errors[] = ['event' => $event['type'], 'employee_emp_id' => (int)$event['emp_id'], 'recipient_emp_id' => $recipientEmpId, 'error' => $e->getMessage()];
            $logInsert->execute([
                ':event_date' => $eventDate,
                ':event_type' => $event['type'],
                ':employee_emp_id' => (int)$event['emp_id'],
                ':recipient_emp_id' => $recipientEmpId,
                ':message_id' => null,
                ':status' => 'failed',
                ':error' => mb_substr($e->getMessage(), 0, 1000),
            ]);
        }
    }
}

chat_json([
    'status' => true,
    'date' => $eventDate,
    'events' => count($celebrations),
    'recipients' => count($activeRecipients),
    'sent' => $sent,
    'duplicates' => $duplicates,
    'failed' => $failed,
    'errors' => array_slice($errors, 0, 20),
]);
