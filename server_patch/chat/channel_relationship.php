<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$empId = (int)$session['emp_id'];
$pdo = chat_db();
chat_ensure_schema($pdo);

function channel_member_role(PDO $pdo, int $groupId, int $empId): string
{
    $stmt = $pdo->prepare(
        "SELECT gm.role
         FROM xmpp_groups g
         INNER JOIN xmpp_group_members gm ON gm.group_id = g.id
         WHERE g.id = :group_id AND gm.emp_id = :emp_id AND g.group_type = 'channel'
         LIMIT 1"
    );
    $stmt->execute([':group_id' => $groupId, ':emp_id' => $empId]);
    return (string)($stmt->fetchColumn() ?: '');
}

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $groupId = max(0, (int)($_GET['group_id'] ?? 0));
    if ($groupId <= 0) chat_json(['status' => false, 'error' => 'Channel is required'], 422);
    if (channel_member_role($pdo, $groupId, $empId) === '') {
        chat_json(['status' => false, 'error' => 'Channel not found'], 404);
    }
    $stmt = $pdo->prepare(
        'SELECT r.*, sg.room_name AS source_name, sg.channel_kind AS source_kind,
                tg.room_name AS target_name, tg.channel_kind AS target_kind
         FROM xmpp_channel_relationships r
         INNER JOIN xmpp_groups sg ON sg.id = r.source_group_id
         INNER JOIN xmpp_groups tg ON tg.id = r.target_group_id
         WHERE r.source_group_id = :group_id OR r.target_group_id = :group_id
         ORDER BY r.created_at DESC, r.id DESC'
    );
    $stmt->execute([':group_id' => $groupId]);
    $relationships = [];
    foreach (($stmt->fetchAll(PDO::FETCH_ASSOC) ?: []) as $row) {
        $row['id'] = (int)$row['id'];
        $row['source_group_id'] = (int)$row['source_group_id'];
        $row['target_group_id'] = (int)$row['target_group_id'];
        $row['metadata'] = json_decode((string)($row['metadata_json'] ?? '{}'), true) ?: [];
        unset($row['metadata_json']);
        $relationships[] = $row;
    }
    chat_json(['status' => true, 'relationships' => $relationships]);
}

$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
$sourceId = max(0, (int)($input['source_group_id'] ?? 0));
$targetId = max(0, (int)($input['target_group_id'] ?? 0));
$type = strtolower(trim((string)($input['relationship_type'] ?? 'related')));
$metadata = is_array($input['metadata'] ?? null) ? $input['metadata'] : [];
if ($sourceId <= 0 || $targetId <= 0 || $sourceId === $targetId) {
    chat_json(['status' => false, 'error' => 'Select two different channels'], 422);
}
if (!preg_match('/^[a-z0-9_\-]{2,40}$/', $type)) $type = 'related';
$sourceRole = channel_member_role($pdo, $sourceId, $empId);
$targetRole = channel_member_role($pdo, $targetId, $empId);
if ($sourceRole === '' || $targetRole === '') {
    chat_json(['status' => false, 'error' => 'You must be a member of both channels'], 403);
}
$stmt = $pdo->prepare(
    'INSERT INTO xmpp_channel_relationships
     (source_group_id, target_group_id, relationship_type, metadata_json, created_by_emp_id)
     VALUES (:source, :target, :type, :metadata, :actor)
     ON DUPLICATE KEY UPDATE metadata_json = VALUES(metadata_json), created_by_emp_id = VALUES(created_by_emp_id), created_at = NOW()'
);
$stmt->execute([
    ':source' => $sourceId,
    ':target' => $targetId,
    ':type' => $type,
    ':metadata' => $metadata ? json_encode($metadata, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) : null,
    ':actor' => $empId,
]);
$audit = $pdo->prepare(
    'INSERT INTO xmpp_channel_audit_log (group_id, event_type, actor_emp_id, metadata_json)
     VALUES (:group_id, :event_type, :actor, :metadata)'
);
$auditPayload = ['target_group_id' => $targetId, 'relationship_type' => $type, 'metadata' => $metadata];
$audit->execute([
    ':group_id' => $sourceId,
    ':event_type' => 'channel_linked',
    ':actor' => $empId,
    ':metadata' => json_encode($auditPayload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
]);
chat_json(['status' => true]);
