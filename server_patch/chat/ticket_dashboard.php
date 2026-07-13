<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$pdo = chat_db();
chat_ensure_schema($pdo);
$stmt = $pdo->prepare(
    'SELECT g.*
     FROM xmpp_groups g
     INNER JOIN xmpp_group_members gm ON gm.group_id = g.id
     WHERE gm.emp_id = :emp_id
       AND g.group_type = \'channel\'
       AND g.channel_kind IN (\'ticket\', \'incident\', \'action\', \'project\', \'installation\', \'l2_feasibility\', \'protect\')
       AND g.is_archived = 0
     ORDER BY g.created_at DESC LIMIT 250'
);
$stmt->execute([':emp_id' => (int)$session['emp_id']]);
$rows = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
$tickets = [];
$breached = 0;
$near = 0;
$critical = 0;
$resolvedDurations = [];
foreach ($rows as $row) {
    $created = strtotime((string)$row['created_at']) ?: time();
    $ageSeconds = max(0, time() - $created);
    $slaMinutes = (int)($row['sla_minutes'] ?? 0);
    $usage = $slaMinutes > 0 ? min(999, round(($ageSeconds / 60) / $slaMinutes * 100, 1)) : 0;
    $health = $slaMinutes > 0
        ? ($usage >= 100 ? 'black' : ($usage >= 80 ? 'red' : ($usage >= 50 ? 'yellow' : 'green')))
        : 'none';
    if ($usage >= 100) $breached++;
    if ($usage >= 80 && $usage < 100) $near++;
    if (strtolower((string)$row['priority']) === 'critical') $critical++;
    if (strtolower((string)$row['status']) === 'closed') $resolvedDurations[] = $ageSeconds;
    $tickets[] = [
        'id' => (int)$row['id'],
        'name' => (string)$row['room_name'],
        'jid' => (string)$row['room_jid'],
        'channel_kind' => (string)$row['channel_kind'],
        'status_text' => (string)$row['status'],
        'priority' => (string)$row['priority'],
        'age_seconds' => $ageSeconds,
        'age_label' => sprintf('%02dh %02dm', intdiv($ageSeconds, 3600), intdiv($ageSeconds % 3600, 60)),
        'sla_usage_percent' => $usage,
        'sla_health' => $health,
        'risk_sort' => $usage + (strtolower((string)$row['priority']) === 'critical' ? 25 : 0),
    ];
}
usort($tickets, static fn(array $a, array $b): int => $b['risk_sort'] <=> $a['risk_sort']);
$avg = $resolvedDurations ? array_sum($resolvedDurations) / count($resolvedDurations) : 0;
chat_json([
    'status' => true,
    'summary' => [
        'open_ticket_channels' => count(array_filter($tickets, static fn($t) => strtolower((string)$t['status_text']) !== 'closed')),
        'critical_tickets' => $critical,
        'breached_tickets' => $breached,
        'tickets_near_sla_breach' => $near,
        'average_mttr_seconds' => (int)$avg,
        'average_resolution_seconds' => (int)$avg,
    ],
    'tickets' => $tickets,
]);
