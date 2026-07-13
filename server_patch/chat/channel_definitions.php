<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

chat_require_user();
$pdo = chat_db();
chat_ensure_schema($pdo);

$stmt = $pdo->query(
    "SELECT id, type_key, name, description, ui_schema_json, ai_marshal_json,
            sop_json, sla_json, kpi_json, checklist_json, permissions_json,
            widgets_json, workflows_json, extension_table, active
     FROM xmpp_channel_definitions
     WHERE active = 1
     ORDER BY FIELD(type_key, 'incident', 'action', 'operational', 'project', 'announcement'), name"
);
$definitions = [];
foreach (($stmt ? $stmt->fetchAll(PDO::FETCH_ASSOC) : []) as $row) {
    foreach (['ui_schema', 'ai_marshal', 'sop', 'sla', 'kpi', 'checklist', 'permissions', 'widgets', 'workflows'] as $key) {
        $jsonKey = $key . '_json';
        $row[$key] = json_decode((string)($row[$jsonKey] ?? '{}'), true) ?: [];
        unset($row[$jsonKey]);
    }
    $row['id'] = (int)$row['id'];
    $row['active'] = (bool)$row['active'];
    $definitions[] = $row;
}
chat_json(['status' => true, 'definitions' => $definitions]);
