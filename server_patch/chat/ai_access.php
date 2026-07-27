<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/ai_room_helper.php';

$session = chat_require_user();
$pdo = chat_db();
chat_ensure_schema($pdo);
chat_ai_ensure_room_table($pdo);

function flow_ai_user_ensure_schema(PDO $pdo): void
{
    $pdo->exec("CREATE TABLE IF NOT EXISTS flow_admin_ai_user_access (
        emp_id INT NOT NULL PRIMARY KEY,
        employee_type_override VARCHAR(8) NULL,
        provider_ids TEXT NULL,
        daily_token_limit INT NULL,
        daily_search_limit INT NULL,
        enabled TINYINT NOT NULL DEFAULT 1,
        updated_by_emp_id INT NULL,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_flow_ai_user_enabled (enabled, emp_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

function flow_ai_default_provider_id(PDO $pdo): int
{
    $stmt = $pdo->query("SELECT id FROM flow_admin_ai_providers WHERE id = 2 AND status = 1 LIMIT 1");
    $id = (int)($stmt->fetchColumn() ?: 0);
    if ($id > 0) return $id;
    $stmt = $pdo->query("SELECT id FROM flow_admin_ai_providers WHERE status = 1 AND (provider_name LIKE '%Open Router%' OR model_name LIKE '%Open Router%' OR api_type = 'custom') ORDER BY id ASC LIMIT 1");
    $id = (int)($stmt->fetchColumn() ?: 0);
    if ($id > 0) return $id;
    $stmt = $pdo->query('SELECT id FROM flow_admin_ai_providers WHERE status = 1 ORDER BY id ASC LIMIT 1');
    return (int)($stmt->fetchColumn() ?: 0);
}

function flow_ai_user_access(PDO $pdo, int $empId): array
{
    flow_ai_user_ensure_schema($pdo);
    $stmt = $pdo->prepare("SELECT provider_ids, daily_token_limit, daily_search_limit, enabled FROM flow_admin_ai_user_access WHERE emp_id = :emp_id LIMIT 1");
    $stmt->execute([':emp_id' => $empId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC) ?: [];
    $providerIds = trim((string)($row['provider_ids'] ?? ''));
    $enabled = (int)($row['enabled'] ?? 0) === 1;
    return [
        'allowed' => $enabled && $providerIds !== '',
        'provider_ids' => $providerIds,
        'token_limit' => (int)($row['daily_token_limit'] ?? 0),
        'search_limit' => (int)($row['daily_search_limit'] ?? 0),
        'source' => $row ? 'assigned' : 'none',
    ];
}

function flow_ai_room_list(PDO $pdo, int $empId): array
{
    $stmt = $pdo->prepare("SELECT g.id, g.room_name, g.room_jid, g.group_type, g.channel_kind, g.avatar_url,
                COALESCE(a.enabled, 0) AS ai_enabled,
                COALESCE(a.provider_id, 0) AS provider_id,
                COALESCE(a.trigger_token, '@ai') AS trigger_token,
                COALESCE(a.max_context_messages, 50) AS max_context_messages,
                a.updated_at AS ai_updated_at
         FROM xmpp_groups g
         INNER JOIN xmpp_group_members gm ON gm.group_id = g.id AND gm.emp_id = :emp_id
         LEFT JOIN flow_admin_ai_room_access a ON a.group_id = g.id
         WHERE g.is_archived = 0
         ORDER BY g.group_type = 'channel' DESC, g.room_name ASC");
    $stmt->execute([':emp_id' => $empId]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
    return array_map(static function(array $row): array {
        $isChannel = (string)($row['group_type'] ?? 'group') === 'channel';
        return [
            'group_id' => (int)$row['id'],
            'name' => ($isChannel ? '#' : '') . (string)$row['room_name'],
            'jid' => (string)$row['room_jid'],
            'type' => (string)($row['group_type'] ?? 'group'),
            'channel_kind' => (string)($row['channel_kind'] ?? ''),
            'avatar_url' => chat_public_upload_url((string)($row['avatar_url'] ?? '')),
            'ai_enabled' => (int)($row['ai_enabled'] ?? 0) === 1,
            'provider_id' => (int)($row['provider_id'] ?? 0),
            'trigger_token' => (string)($row['trigger_token'] ?? '@ai'),
            'max_context_messages' => (int)($row['max_context_messages'] ?? 50),
            'ai_updated_at' => (string)($row['ai_updated_at'] ?? ''),
        ];
    }, $rows);
}

$empId = (int)$session['emp_id'];
$access = flow_ai_user_access($pdo, $empId);
if (!$access['allowed']) {
    chat_json([
        'status' => true,
        'has_access' => false,
        'is_access_manager' => $empId === 302,
        'rooms' => [],
        'message' => 'AI API access is not enabled for this user.',
    ]);
}

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST') {
    $input = json_decode(file_get_contents('php://input') ?: '{}', true);
    if (!is_array($input)) $input = [];
    $groupId = (int)($input['group_id'] ?? 0);
    $enabled = filter_var($input['enabled'] ?? false, FILTER_VALIDATE_BOOL);
    if ($groupId <= 0) chat_json(['status' => false, 'error' => 'Group/channel id is required.'], 422);
    $member = $pdo->prepare('SELECT role FROM xmpp_group_members WHERE group_id = :group_id AND emp_id = :emp_id LIMIT 1');
    $member->execute([':group_id' => $groupId, ':emp_id' => $empId]);
    if (!$member->fetchColumn()) chat_json(['status' => false, 'error' => 'You are not a member of this group/channel.'], 403);
    $providerId = $enabled ? flow_ai_default_provider_id($pdo) : 0;
    if ($enabled && $providerId <= 0) chat_json(['status' => false, 'error' => 'Default Open Router AI provider is not active.'], 422);
    $stmt = $pdo->prepare("INSERT INTO flow_admin_ai_room_access
        (group_id, provider_id, enabled, trigger_token, max_context_messages, updated_by_emp_id, updated_at)
        VALUES (:group_id, :provider_id, :enabled, '@ai', 50, :emp_id, NOW())
        ON DUPLICATE KEY UPDATE provider_id = VALUES(provider_id), enabled = VALUES(enabled), trigger_token = '@ai', max_context_messages = 50, updated_by_emp_id = VALUES(updated_by_emp_id), updated_at = NOW()");
    $stmt->execute([
        ':group_id' => $groupId,
        ':provider_id' => $providerId > 0 ? $providerId : null,
        ':enabled' => $enabled ? 1 : 0,
        ':emp_id' => $empId,
    ]);
    chat_json(['status' => true, 'group_id' => $groupId, 'enabled' => $enabled, 'provider_id' => $providerId]);
}

$defaultProviderId = flow_ai_default_provider_id($pdo);
$providerStmt = $pdo->prepare('SELECT id, provider_name, api_type, model_name, status FROM flow_admin_ai_providers WHERE id = :id LIMIT 1');
$providerStmt->execute([':id' => $defaultProviderId]);
$provider = $providerStmt->fetch(PDO::FETCH_ASSOC) ?: [];
chat_json([
    'status' => true,
    'has_access' => true,
    'is_access_manager' => $empId === 302,
    'default_provider_id' => $defaultProviderId,
    'default_provider' => $provider,
    'user_access' => $access,
    'rooms' => flow_ai_room_list($pdo, $empId),
]);
