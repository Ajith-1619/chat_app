<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$empId = (int)$session['emp_id'];
if (!chat_diagnostics_allowed($empId)) {
    chat_json(['status' => false, 'error' => 'Diagnostics access denied'], 403);
}

$pdo = chat_db();
chat_diagnostic_trace($empId, 'schema-' . $empId, 'system', 'diagnostics_schema', 0);

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input') ?: '{}', true);
    if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid request'], 422);
    $events = isset($input['events']) && is_array($input['events']) ? $input['events'] : [$input];
    $accepted = 0;
    foreach (array_slice($events, 0, 100) as $event) {
        if (!is_array($event)) continue;
        $metadata = is_array($event['metadata'] ?? null) ? $event['metadata'] : [];
        unset($metadata['password'], $metadata['body'], $metadata['message'], $metadata['token']);
        chat_diagnostic_trace(
            $empId,
            (string)($event['trace_id'] ?? ''),
            (string)($event['category'] ?? 'android'),
            (string)($event['operation'] ?? 'unknown'),
            (float)($event['duration_ms'] ?? 0),
            (string)($event['event_status'] ?? 'ok'),
            $metadata
        );
        $accepted++;
    }
    chat_json(['status' => true, 'accepted' => $accepted]);
}

$hours = max(1, min(168, (int)($_GET['hours'] ?? 24)));
$limit = max(20, min(500, (int)($_GET['limit'] ?? 200)));
$stmt = $pdo->prepare(
    "SELECT id, trace_id, category, operation, duration_ms, status, metadata_json, created_at
     FROM xmpp_diagnostic_traces
     WHERE emp_id = :emp_id AND created_at >= DATE_SUB(NOW(), INTERVAL {$hours} HOUR)
     ORDER BY id DESC LIMIT {$limit}"
);
$stmt->execute([':emp_id' => $empId]);
$traces = array_map(static function (array $row): array {
    $row['duration_ms'] = (float)$row['duration_ms'];
    $row['metadata'] = json_decode((string)($row['metadata_json'] ?? '{}'), true) ?: [];
    unset($row['metadata_json']);
    return $row;
}, $stmt->fetchAll(PDO::FETCH_ASSOC) ?: []);

$groups = [];
foreach ($traces as $trace) {
    $key = $trace['category'] . '|' . $trace['operation'];
    $groups[$key] ??= [
        'category' => $trace['category'],
        'operation' => $trace['operation'],
        'count' => 0,
        'total_ms' => 0.0,
        'max_ms' => 0.0,
        'errors' => 0,
    ];
    $groups[$key]['count']++;
    $groups[$key]['total_ms'] += $trace['duration_ms'];
    $groups[$key]['max_ms'] = max($groups[$key]['max_ms'], $trace['duration_ms']);
    if ($trace['status'] !== 'ok' && $trace['status'] !== 'success') $groups[$key]['errors']++;
}
$summary = array_values(array_map(static function (array $group): array {
    $group['avg_ms'] = round($group['total_ms'] / max(1, $group['count']), 2);
    $group['max_ms'] = round($group['max_ms'], 2);
    unset($group['total_ms']);
    $group['severity'] = $group['errors'] > 0
        ? 'error'
        : ($group['avg_ms'] >= 3000 ? 'critical' : ($group['avg_ms'] >= 1000 ? 'slow' : 'healthy'));
    return $group;
}, $groups));
usort($summary, static fn(array $a, array $b): int => $b['avg_ms'] <=> $a['avg_ms']);

$bottlenecks = array_values(array_filter(
    $summary,
    static fn(array $item): bool => $item['severity'] !== 'healthy'
));
$reportId = 'SKY-' . $empId . '-' . gmdate('Ymd-His');
chat_json([
    'status' => true,
    'report_id' => $reportId,
    'generated_at' => gmdate(DATE_ATOM),
    'window_hours' => $hours,
    'summary' => $summary,
    'bottlenecks' => $bottlenecks,
    'traces' => $traces,
]);
