<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$empId = (int)$session['emp_id'];
$employeePdo = getEmployeeDB();

function attendance_payload(PDO $pdo, int $empId): array
{
    $stmt = $pdo->prepare(
        'SELECT id, shift_id, punch_in, punch_out, date_created, out_time
         FROM punch
         WHERE emp_id = :emp_id AND DATE(date_created) = CURDATE()
         ORDER BY id DESC LIMIT 1'
    );
    $stmt->execute([':emp_id' => $empId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC) ?: [];
    $punchIn = (int)($row['punch_in'] ?? 0);
    $punchOut = (int)($row['punch_out'] ?? 0);
    $payload = [
        'has_punched_in' => $punchIn > 1 || !empty($row['date_created']),
        'has_punched_out' => $punchOut > 1 || !empty($row['out_time']),
        'punch_in' => $punchIn > 1 ? date(DATE_ATOM, $punchIn) : (string)($row['date_created'] ?? ''),
        'punch_out' => $punchOut > 1 ? date(DATE_ATOM, $punchOut) : (string)($row['out_time'] ?? ''),
        'shift_id' => (string)($row['shift_id'] ?? ''),
    ];
    $payload['last_7_days'] = attendance_rows($pdo, $empId, date('Y-m-d', strtotime('-6 days')), date('Y-m-d'));
    $payload['month_days'] = attendance_rows($pdo, $empId, date('Y-m-01'), date('Y-m-t'), true);
    return $payload;
}

function attendance_rows(PDO $pdo, int $empId, string $fromDate, string $toDate, bool $includeMissing = false): array
{
    $stmt = $pdo->prepare(
        "SELECT id, shift_id, punch_in, punch_out, date_created, out_time, DATE(date_created) AS punch_date
         FROM punch
         WHERE emp_id = :emp_id
           AND DATE(date_created) BETWEEN :from_date AND :to_date
         ORDER BY date_created DESC, id DESC"
    );
    $stmt->execute([
        ':emp_id' => $empId,
        ':from_date' => $fromDate,
        ':to_date' => $toDate,
    ]);
    $seen = [];
    $rowsByDate = [];
    foreach (($stmt->fetchAll(PDO::FETCH_ASSOC) ?: []) as $row) {
        $date = (string)($row['punch_date'] ?? '');
        if ($date === '' || isset($seen[$date])) continue;
        $seen[$date] = true;
        $inEpoch = (int)($row['punch_in'] ?? 0);
        $outEpoch = (int)($row['punch_out'] ?? 0);
        $inRaw = $inEpoch > 1 ? date(DATE_ATOM, $inEpoch) : (string)($row['date_created'] ?? '');
        $outRaw = $outEpoch > 1 ? date(DATE_ATOM, $outEpoch) : (string)($row['out_time'] ?? '');
        $inTs = $inEpoch > 1 ? $inEpoch : (strtotime($inRaw) ?: 0);
        $outTs = $outEpoch > 1 ? $outEpoch : (strtotime($outRaw) ?: 0);
        $workingSeconds = ($inTs > 0 && $outTs > $inTs) ? ($outTs - $inTs) : 0;
        $rowsByDate[$date] = [
            'date' => $date,
            'day_name' => date('D', strtotime($date) ?: time()),
            'is_weekoff' => (date('N', strtotime($date) ?: time()) >= 7),
            'is_holiday' => false,
            'punch_in' => $inRaw,
            'punch_out' => $outRaw,
            'working_seconds' => $workingSeconds,
            'working_hours' => attendance_duration($workingSeconds),
            'shift_id' => (string)($row['shift_id'] ?? ''),
            'shift_time' => (string)($row['shift_id'] ?? ''),
            'status' => $outRaw !== '' ? 'Present' : 'Punched in',
        ];
    }
    if ($includeMissing) {
        $cursor = strtotime($fromDate) ?: time();
        $end = strtotime($toDate) ?: $cursor;
        while ($cursor <= $end) {
            $date = date('Y-m-d', $cursor);
            if (!isset($rowsByDate[$date])) {
                $isWeekoff = date('N', $cursor) >= 7;
                $rowsByDate[$date] = [
                    'date' => $date,
                    'day_name' => date('D', $cursor),
                    'is_weekoff' => $isWeekoff,
                    'is_holiday' => false,
                    'punch_in' => '',
                    'punch_out' => '',
                    'working_seconds' => 0,
                    'working_hours' => '--',
                    'shift_id' => '',
                    'shift_time' => '',
                    'status' => $isWeekoff ? 'Week Off' : 'Absent',
                ];
            }
            $cursor = strtotime('+1 day', $cursor) ?: ($cursor + 86400);
        }
    }
    ksort($rowsByDate);
    return array_values(array_reverse($rowsByDate));
}

function attendance_first_table(PDO $pdo, array $candidates): string
{
    foreach ($candidates as $table) {
        $stmt = $pdo->prepare("SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :table_name");
        $stmt->execute([':table_name' => $table]);
        if ((int)$stmt->fetchColumn() > 0) return $table;
    }
    return '';
}

function attendance_columns(PDO $pdo, string $table): array
{
    $stmt = $pdo->prepare(
        "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :table_name"
    );
    $stmt->execute([':table_name' => $table]);
    return array_map('strval', $stmt->fetchAll(PDO::FETCH_COLUMN) ?: []);
}

function attendance_first_column(array $columns, array $candidates): string
{
    foreach ($candidates as $column) {
        if (in_array($column, $columns, true)) return $column;
    }
    return '';
}

function attendance_shift_catalog(PDO $employeePdo): array
{
    $table = attendance_first_table($employeePdo, ['shift_master', 'tbl_shift', 'shifts', 'shift', 'employee_shift_master']);
    if ($table === '') return [];
    $columns = attendance_columns($employeePdo, $table);
    $idCol = attendance_first_column($columns, ['shift_id', 'id']);
    $nameCol = attendance_first_column($columns, ['shift_name', 'name', 'title']);
    $timeCol = attendance_first_column($columns, ['shift_time', 'time', 'timing', 'time_range']);
    $hoursCol = attendance_first_column($columns, ['shift_hours', 'hours', 'working_hours']);
    if ($idCol === '') return [];
    $select = ["`$idCol` AS shift_id"];
    $select[] = $nameCol !== '' ? "`$nameCol` AS name" : "'' AS name";
    $select[] = $timeCol !== '' ? "`$timeCol` AS time" : "'' AS time";
    $select[] = $hoursCol !== '' ? "`$hoursCol` AS hours" : "'' AS hours";
    $sql = 'SELECT ' . implode(', ', $select) . " FROM `$table` ORDER BY `$idCol` ASC LIMIT 100";
    $stmt = $employeePdo->query($sql);
    $result = [];
    foreach (($stmt?->fetchAll(PDO::FETCH_ASSOC) ?: []) as $row) {
        $shiftId = trim((string)($row['shift_id'] ?? ''));
        if ($shiftId === '') continue;
        $result[] = [
            'shift_id' => $shiftId,
            'name' => trim((string)($row['name'] ?? $shiftId)),
            'time' => trim((string)($row['time'] ?? '')),
            'hours' => trim((string)($row['hours'] ?? '')),
        ];
    }
    return $result;
}

function attendance_shift_options(PDO $employeePdo, string $credentials): array
{
    $result = [];
    if ($credentials !== '') {
        try {
            $ch = curl_init('https://skylinkonline.net/servicev2/get_shift.php');
            if ($ch !== false) {
                curl_setopt_array($ch, [
                    CURLOPT_POST => true,
                    CURLOPT_RETURNTRANSFER => true,
                    CURLOPT_TIMEOUT => 30,
                    CURLOPT_CONNECTTIMEOUT => 10,
                    CURLOPT_HTTPHEADER => [
                        'Accept: application/json',
                        'Content-Type: application/x-www-form-urlencoded',
                    ],
                    CURLOPT_POSTFIELDS => http_build_query(['key' => $credentials]),
                ]);
                $response = curl_exec($ch);
                $status = (int)curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
                curl_close($ch);
                if ($response !== false && $status >= 200 && $status < 300) {
                    $decoded = json_decode((string)$response, true);
                    $server = is_array($decoded) ? ($decoded['server'] ?? null) : null;
                    $first = is_array($server) && !empty($server) ? ($server[0] ?? null) : null;
                    $data = is_array($first) ? ($first['DATA'] ?? null) : null;
                    if (is_array($data)) {
                        foreach ($data as $row) {
                            if (!is_array($row)) continue;
                            $shiftId = trim((string)($row['shift_id'] ?? ''));
                            if ($shiftId === '') continue;
                            $result[] = [
                                'shift_id' => $shiftId,
                                'name' => trim((string)($row['name'] ?? $row['shift_name'] ?? $shiftId)),
                                'time' => trim((string)($row['shift_time'] ?? $row['time'] ?? $shiftId)),
                                'hours' => trim((string)($row['shift_hours'] ?? $row['hours'] ?? '')),
                            ];
                        }
                    }
                }
            }
        } catch (Throwable $ignored) {
        }
    }
    if (!$result) {
        $result = attendance_shift_catalog($employeePdo);
    }
    $seen = [];
    $normalized = [];
    foreach ($result as $row) {
        $shiftId = trim((string)($row['shift_id'] ?? ''));
        if ($shiftId === '' || isset($seen[$shiftId])) continue;
        $seen[$shiftId] = true;
        $normalized[] = [
            'shift_id' => $shiftId,
            'name' => trim((string)($row['name'] ?? $shiftId)),
            'time' => trim((string)($row['time'] ?? '')),
            'hours' => trim((string)($row['hours'] ?? '')),
        ];
    }
    return $normalized;
}


function attendance_duration(int $seconds): string
{
    if ($seconds <= 0) return '--';
    $hours = intdiv($seconds, 3600);
    $minutes = intdiv($seconds % 3600, 60);
    return sprintf('%02dh %02dm', $hours, $minutes);
}

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    chat_json(['status' => true, 'attendance' => attendance_payload($employeePdo, $empId)]);
}

$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
$action = strtolower(trim((string)($input['action'] ?? '')));
if (!in_array($action, ['get_shifts', 'start_tracking', 'stop_tracking'], true)) {
    chat_json(['status' => false, 'error' => 'Invalid attendance action'], 422);
}

try {
    if ($action === 'get_shifts') {
        $credentials = trim((string)($input['credentials'] ?? ''));
        chat_json([
            'status' => true,
            'shifts' => attendance_shift_options($employeePdo, $credentials),
        ]);
    }

    $chatPdo = chat_db();
    chat_ensure_schema($chatPdo);
    if ($action === 'start_tracking') {
        $attendance = attendance_payload($employeePdo, $empId);
        if (!$attendance['has_punched_in'] || $attendance['has_punched_out']) {
            throw new RuntimeException('A currently active punch-in is required.');
        }
        $token = bin2hex(random_bytes(32));
        $stmt = $chatPdo->prepare(
            'INSERT INTO xmpp_location_tracking
             (emp_id, token_hash, shift_id, active, started_at, stopped_at)
             VALUES (:emp_id, :token_hash, :shift_id, 1, NOW(), NULL)
             ON DUPLICATE KEY UPDATE token_hash = VALUES(token_hash),
               shift_id = VALUES(shift_id), active = 1, started_at = NOW(), stopped_at = NULL'
        );
        $stmt->execute([
            ':emp_id' => $empId,
            ':token_hash' => hash('sha256', $token),
            ':shift_id' => max(0, (int)($input['shift_id'] ?? 0)) ?: null,
        ]);
        try {
            $taskPdo = getTaskDB();
            $status = $taskPdo->prepare(
                "UPDATE tbl_location_track_inch
                 SET current_status = 'Punched in', updated_at = NOW()
                 WHERE emp_id = :emp_id ORDER BY id DESC LIMIT 1"
            );
            $status->execute([':emp_id' => $empId]);
        } catch (Throwable $statusError) {
            error_log('attendance tracking status start failed: ' . $statusError->getMessage());
        }
        chat_json([
            'status' => true,
            'tracking_token' => $token,
            'attendance' => $attendance,
        ]);
    }
    $stmt = $chatPdo->prepare(
        'UPDATE xmpp_location_tracking
         SET active = 0, stopped_at = NOW() WHERE emp_id = :emp_id'
    );
    $stmt->execute([':emp_id' => $empId]);
    try {
        $taskPdo = getTaskDB();
        $status = $taskPdo->prepare(
            "UPDATE tbl_location_track_inch
             SET current_status = 'Location Off', updated_at = NOW()
             WHERE emp_id = :emp_id ORDER BY id DESC LIMIT 1"
        );
        $status->execute([':emp_id' => $empId]);
    } catch (Throwable $statusError) {
        error_log('attendance tracking status stop failed: ' . $statusError->getMessage());
    }
    chat_json([
        'status' => true,
        'attendance' => attendance_payload($employeePdo, $empId),
    ]);
} catch (Throwable $e) {
    chat_json(['status' => false, 'error' => $e->getMessage()], 422);
}
