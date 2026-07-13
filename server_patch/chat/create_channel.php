<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$pdo = chat_db();
chat_ensure_schema($pdo);
$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);

$name = ltrim(trim((string)($input['channel_name'] ?? '')), '#');
$channelKind = strtolower(trim((string)($input['channel_type'] ?? $input['channel_kind'] ?? 'operational')));
$definitionStmt = $pdo->prepare('SELECT * FROM xmpp_channel_definitions WHERE type_key = :type_key AND active = 1 LIMIT 1');
$definitionStmt->execute([':type_key' => $channelKind]);
$definition = $definitionStmt->fetch(PDO::FETCH_ASSOC) ?: null;
if (!$definition) {
    $channelKind = 'operational';
    $definitionStmt->execute([':type_key' => $channelKind]);
    $definition = $definitionStmt->fetch(PDO::FETCH_ASSOC) ?: null;
}
$definitionId = $definition ? (int)$definition['id'] : null;
$definitionName = $definition ? (string)$definition['name'] : ucfirst($channelKind);
$definitionSla = $definition ? (json_decode((string)($definition['sla_json'] ?? '{}'), true) ?: []) : [];

$ownerEmpId = max(0, (int)($input['owner_emp_id'] ?? $session['emp_id']));
$status = trim((string)($input['status'] ?? 'Open'));
$priority = trim((string)($input['priority'] ?? ($definitionSla['priority'] ?? 'Normal')));
$targetDate = trim((string)($input['target_date'] ?? ''));
$nextActionDate = trim((string)($input['next_action_date'] ?? ''));
$slaMinutes = max(0, (int)($input['sla_minutes'] ?? ($definitionSla['default_minutes'] ?? 0)));
$staleAlertMinutes = max(0, (int)($input['stale_alert_minutes'] ?? 0));
$metadata = is_array($input['metadata'] ?? null) ? $input['metadata'] : [];
$metadata['channel_definition_key'] = $channelKind;
$metadata['channel_definition_name'] = $definitionName;
$members = array_values(array_unique(array_filter(
    array_map('intval', is_array($input['members'] ?? null) ? $input['members'] : []),
    static fn(int $id): bool => $id > 0
)));
if ($name === '' || mb_strlen($name) > 100) {
    chat_json(['status' => false, 'error' => 'Valid channel name is required'], 422);
}
if (!in_array((int)$session['emp_id'], $members, true)) $members[] = (int)$session['emp_id'];
$prefix = match ($channelKind) {
    'ticket' => 'TKT',
    'incident' => 'INC',
    'project' => 'PRJ',
    'action' => 'ACT',
    'announcement' => 'ANN',
    default => 'OPS',
};
if ($channelKind === 'ticket' && !preg_match('/^TKT-\d{4}-\d+/i', $name)) {
    $name = 'TKT-' . date('Y') . '-' . random_int(1000, 9999);
}
$slug = strtolower($prefix) . '-' . chat_slug($name) . '-' . substr(bin2hex(random_bytes(4)), 0, 8);
$roomJid = $slug . '@' . SKYCHAT_MUC_DOMAIN;
try {
    chat_ejabberd_client()->createRoom($slug, '#' . $name);
    $pdo->beginTransaction();
    $stmt = $pdo->prepare(
        'INSERT INTO xmpp_groups
         (room_name, room_jid, group_type, channel_kind, channel_definition_id,
          channel_template_key, status, target_date, next_action_date, sla_minutes,
          priority, owner_emp_id, stale_alert_minutes, metadata_json, created_by_emp_id)
         VALUES
         (:name, :jid, \'channel\', :kind, :definition_id,
          :template_key, :status, :target_date, :next_action_date, :sla_minutes,
          :priority, :owner_emp_id, :stale_alert_minutes, :metadata, :created_by)'
    );
    $stmt->execute([
        ':name' => $name,
        ':jid' => $roomJid,
        ':kind' => $channelKind,
        ':definition_id' => $definitionId,
        ':template_key' => $channelKind,
        ':status' => $status !== '' ? $status : 'Open',
        ':target_date' => $targetDate !== '' ? date('Y-m-d H:i:s', strtotime($targetDate) ?: time()) : null,
        ':next_action_date' => $nextActionDate !== '' ? date('Y-m-d H:i:s', strtotime($nextActionDate) ?: time()) : null,
        ':sla_minutes' => $slaMinutes > 0 ? $slaMinutes : null,
        ':priority' => $priority !== '' ? $priority : 'Normal',
        ':owner_emp_id' => $ownerEmpId > 0 ? $ownerEmpId : (int)$session['emp_id'],
        ':stale_alert_minutes' => $staleAlertMinutes > 0 ? $staleAlertMinutes : null,
        ':metadata' => $metadata ? json_encode($metadata, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) : null,
        ':created_by' => (int)$session['emp_id'],
    ]);
    $channelId = (int)$pdo->lastInsertId();
    $memberStmt = $pdo->prepare(
        'INSERT INTO xmpp_group_members (group_id, emp_id, role)
         VALUES (:group_id, :emp_id, :role)'
    );
    foreach ($members as $memberId) {
        $memberStmt->execute([
            ':group_id' => $channelId,
            ':emp_id' => $memberId,
            ':role' => $memberId === (int)$session['emp_id'] ? 'owner' : 'member',
        ]);
        try {
            chat_ejabberd_client()->inviteToRoom($slug, chat_jid($memberId), 'Added to Skylink channel');
        } catch (Throwable $inviteError) {
            error_log('channel invite skipped: ' . $inviteError->getMessage());
        }
    }
    if ($definition && !empty($definition['extension_table'])) {
        $extensionTable = preg_replace('/[^A-Za-z0-9_]/', '', (string)$definition['extension_table']);
        if ($extensionTable !== '') {
            try {
                $extension = $pdo->prepare('INSERT IGNORE INTO ' . $extensionTable . ' (group_id, metadata_json) VALUES (:group_id, :metadata)');
                $extension->execute([
                    ':group_id' => $channelId,
                    ':metadata' => json_encode(['created_from_definition' => $channelKind], JSON_UNESCAPED_SLASHES),
                ]);
            } catch (Throwable $extensionError) {
                error_log('channel extension init skipped: ' . $extensionError->getMessage());
            }
        }
    }
    $timeline = $pdo->prepare(
        'INSERT INTO xmpp_channel_timeline (group_id, event_type, body, actor_emp_id)
         VALUES (:group_id, :event_type, :body, :actor)'
    );
    $timeline->execute([
        ':group_id' => $channelId,
        ':event_type' => $definitionName . ' Created',
        ':body' => $definitionName . ' channel created',
        ':actor' => (int)$session['emp_id'],
    ]);
    $audit = $pdo->prepare(
        'INSERT INTO xmpp_channel_audit_log (group_id, event_type, actor_emp_id, new_json, metadata_json)
         VALUES (:group_id, :event_type, :actor, :new_json, :metadata)'
    );
    $audit->execute([
        ':group_id' => $channelId,
        ':event_type' => 'channel_created',
        ':actor' => (int)$session['emp_id'],
        ':new_json' => json_encode(['channel_kind' => $channelKind, 'status' => $status, 'priority' => $priority], JSON_UNESCAPED_SLASHES),
        ':metadata' => json_encode(['definition_id' => $definitionId, 'template_key' => $channelKind], JSON_UNESCAPED_SLASHES),
    ]);
    $pdo->commit();
    chat_json([
        'status' => true,
        'group_id' => $channelId,
        'room_name' => '#' . $name,
        'room_jid' => $roomJid,
        'type' => 'channel',
        'channel_kind' => $channelKind,
        'channel_definition_id' => $definitionId,
        'channel_definition_name' => $definitionName,
    ]);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    error_log('create channel failed: ' . $e->getMessage());
    chat_json(['status' => false, 'error' => 'Unable to create channel'], 500);
}
