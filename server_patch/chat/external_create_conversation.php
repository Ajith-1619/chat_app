<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    chat_json(['status' => false, 'error' => 'POST required.'], 405);
}

$rawBody = file_get_contents('php://input') ?: '{}';
$input = json_decode($rawBody, true);
if (!is_array($input)) {
    chat_json(['status' => false, 'error' => 'Invalid JSON body.'], 400);
}

function flow_conversation_api_authorized(array $input): bool
{
    $defaultApiKey = 'skylink-flow-conversation-api-key-2026';
    $configuredApiKey = trim((string)(getenv('SKYLINK_CONVERSATION_API_KEY') ?: getenv('SKYCHAT_CONVERSATION_API_KEY') ?: ''));
    if (defined('SKYLINK_CONVERSATION_API_KEY')) {
        $configuredApiKey = trim((string)SKYLINK_CONVERSATION_API_KEY) ?: $configuredApiKey;
    }
    $validKeys = array_values(array_unique(array_filter([
        $defaultApiKey,
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
        : trim((string)($_SERVER['HTTP_X_SKYLINK_CONVERSATION_KEY'] ?? $_SERVER['HTTP_X_SKYLINK_API_KEY'] ?? $input['api_key'] ?? $_GET['api_key'] ?? ''));
    foreach ($validKeys as $validKey) {
        if ($providedKey !== '' && hash_equals($validKey, $providedKey)) return true;
    }
    return false;
}

function flow_api_member_ids(array $input, int $creatorEmpId): array
{
    $membersRaw = $input['members'] ?? $input['member_emp_ids'] ?? [];
    $members = array_values(array_unique(array_filter(
        array_map('intval', is_array($membersRaw) ? $membersRaw : []),
        static fn(int $id): bool => $id > 0
    )));
    if (!in_array($creatorEmpId, $members, true)) $members[] = $creatorEmpId;
    return array_values(array_unique($members));
}

function flow_api_valid_employee_ids(PDO $employeePdo, array $members): array
{
    if (!$members) return [];
    $ph = implode(',', array_fill(0, count($members), '?'));
    $check = $employeePdo->prepare("SELECT emp_id FROM employee WHERE status = 1 AND emp_id IN ({$ph})");
    $check->execute($members);
    return array_values(array_unique(array_map('intval', $check->fetchAll(PDO::FETCH_COLUMN) ?: [])));
}

function flow_api_create_group(PDO $chatPdo, PDO $employeePdo, array $input, int $creatorEmpId): array
{
    $groupName = trim((string)($input['group_name'] ?? $input['name'] ?? ''));
    if ($groupName === '' || mb_strlen($groupName) > 150) {
        chat_json(['status' => false, 'error' => 'Valid group name is required.'], 422);
    }
    $members = flow_api_member_ids($input, $creatorEmpId);
    $validMembers = flow_api_valid_employee_ids($employeePdo, $members);
    if (!in_array($creatorEmpId, $validMembers, true)) {
        chat_json(['status' => false, 'error' => 'Creator employee is not active.'], 422);
    }

    $slug = chat_slug($groupName) . '-' . substr(bin2hex(random_bytes(4)), 0, 8);
    $roomJid = $slug . '@' . SKYCHAT_MUC_DOMAIN;
    chat_ejabberd_client()->createRoom($slug, $groupName);
    $chatPdo->beginTransaction();
    try {
        $stmt = $chatPdo->prepare('INSERT INTO xmpp_groups (room_name, room_jid, group_type, created_by_emp_id, owner_emp_id) VALUES (:room_name, :room_jid, \'group\', :created_by, :owner_emp_id)');
        $stmt->execute([
            ':room_name' => $groupName,
            ':room_jid' => $roomJid,
            ':created_by' => $creatorEmpId,
            ':owner_emp_id' => $creatorEmpId,
        ]);
        $groupId = (int)$chatPdo->lastInsertId();
        $memberStmt = $chatPdo->prepare('INSERT INTO xmpp_group_members (group_id, emp_id, role) VALUES (:group_id, :emp_id, :role) ON DUPLICATE KEY UPDATE role = VALUES(role)');
        foreach ($validMembers as $empId) {
            $role = $empId === $creatorEmpId ? 'owner' : 'member';
            $memberStmt->execute([':group_id' => $groupId, ':emp_id' => $empId, ':role' => $role]);
            try {
                chat_ejabberd_client()->setRoomAffiliation($slug, chat_jid($empId), $role === 'owner' ? 'owner' : 'member');
                chat_ejabberd_client()->inviteToRoom($slug, chat_jid($empId), 'Skylink Flow group invite');
            } catch (Throwable $inviteError) {
                error_log('external create group invite skipped for ' . $empId . ': ' . $inviteError->getMessage());
            }
        }
        $chatPdo->commit();
        return [
            'status' => true,
            'type' => 'group',
            'group_id' => $groupId,
            'room_name' => $groupName,
            'room_jid' => $roomJid,
            'members' => $validMembers,
        ];
    } catch (Throwable $e) {
        if ($chatPdo->inTransaction()) $chatPdo->rollBack();
        throw $e;
    }
}

function flow_api_create_channel(PDO $pdo, PDO $employeePdo, array $input, int $creatorEmpId): array
{
    $name = ltrim(trim((string)($input['channel_name'] ?? $input['name'] ?? '')), '#');
    if ($name === '' || mb_strlen($name) > 100) {
        chat_json(['status' => false, 'error' => 'Valid channel name is required.'], 422);
    }
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
    $status = trim((string)($input['status'] ?? 'Open')) ?: 'Open';
    $priority = trim((string)($input['priority'] ?? ($definitionSla['priority'] ?? 'Normal'))) ?: 'Normal';
    $description = trim((string)($input['description'] ?? ''));
    if (mb_strlen($description) > 4000) $description = mb_substr($description, 0, 4000);
    $targetDate = trim((string)($input['target_date'] ?? ''));
    $nextActionDate = trim((string)($input['next_action_date'] ?? ''));
    $slaMinutes = max(0, (int)($input['sla_minutes'] ?? ($definitionSla['default_minutes'] ?? 0)));
    $staleAlertMinutes = max(0, (int)($input['stale_alert_minutes'] ?? 0));
    $metadata = is_array($input['metadata'] ?? null) ? $input['metadata'] : [];
    $metadata['created_from_external_api'] = true;
    $metadata['source'] = (string)($input['source'] ?? 'external_api');
    if (!empty($input['external_reference_id'])) $metadata['external_reference_id'] = (string)$input['external_reference_id'];
    $members = flow_api_member_ids($input, $creatorEmpId);
    $validMembers = flow_api_valid_employee_ids($employeePdo, $members);
    if (!in_array($creatorEmpId, $validMembers, true)) {
        chat_json(['status' => false, 'error' => 'Creator employee is not active.'], 422);
    }
    $prefix = match ($channelKind) {
        'ticket' => 'TKT',
        'incident' => 'INC',
        'project' => 'PRJ',
        'action' => 'ACT',
        'announcement' => 'ANN',
        default => 'OPS',
    };
    $slug = strtolower($prefix) . '-' . chat_slug($name) . '-' . substr(bin2hex(random_bytes(4)), 0, 8);
    $roomJid = $slug . '@' . SKYCHAT_MUC_DOMAIN;
    chat_ejabberd_client()->createRoom($slug, '#' . $name);
    $pdo->beginTransaction();
    try {
        $stmt = $pdo->prepare('INSERT INTO xmpp_groups
            (room_name, room_jid, description, group_type, channel_kind, channel_definition_id, channel_template_key, status, target_date, next_action_date, sla_minutes, priority, owner_emp_id, stale_alert_minutes, metadata_json, created_by_emp_id)
            VALUES (:name, :jid, :description, \'channel\', :kind, :definition_id, :template_key, :status, :target_date, :next_action_date, :sla_minutes, :priority, :owner_emp_id, :stale_alert_minutes, :metadata, :created_by)');
        $stmt->execute([
            ':name' => $name,
            ':jid' => $roomJid,
            ':description' => $description !== '' ? $description : null,
            ':kind' => $channelKind,
            ':definition_id' => $definitionId,
            ':template_key' => $channelKind,
            ':status' => $status,
            ':target_date' => $targetDate !== '' ? date('Y-m-d H:i:s', strtotime($targetDate) ?: time()) : null,
            ':next_action_date' => $nextActionDate !== '' ? date('Y-m-d H:i:s', strtotime($nextActionDate) ?: time()) : null,
            ':sla_minutes' => $slaMinutes > 0 ? $slaMinutes : null,
            ':priority' => $priority,
            ':owner_emp_id' => $creatorEmpId,
            ':stale_alert_minutes' => $staleAlertMinutes > 0 ? $staleAlertMinutes : null,
            ':metadata' => $metadata ? json_encode($metadata, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) : null,
            ':created_by' => $creatorEmpId,
        ]);
        $channelId = (int)$pdo->lastInsertId();
        $memberStmt = $pdo->prepare('INSERT INTO xmpp_group_members (group_id, emp_id, role) VALUES (:group_id, :emp_id, :role) ON DUPLICATE KEY UPDATE role = VALUES(role)');
        foreach ($validMembers as $empId) {
            $role = $empId === $creatorEmpId ? 'owner' : 'member';
            $memberStmt->execute([':group_id' => $channelId, ':emp_id' => $empId, ':role' => $role]);
            try {
                chat_ejabberd_client()->inviteToRoom($slug, chat_jid($empId), 'Added to Skylink channel');
            } catch (Throwable $inviteError) {
                error_log('external create channel invite skipped for ' . $empId . ': ' . $inviteError->getMessage());
            }
        }
        try {
            $timeline = $pdo->prepare('INSERT INTO xmpp_channel_timeline (group_id, event_type, body, actor_emp_id) VALUES (:group_id, :event_type, :body, :actor)');
            $timeline->execute([':group_id' => $channelId, ':event_type' => $definitionName . ' Created', ':body' => $definitionName . ' channel created from external API', ':actor' => $creatorEmpId]);
        } catch (Throwable $timelineError) {
            error_log('external create channel timeline skipped: ' . $timelineError->getMessage());
        }
        $pdo->commit();
        return [
            'status' => true,
            'type' => 'channel',
            'group_id' => $channelId,
            'room_name' => '#' . $name,
            'room_jid' => $roomJid,
            'channel_kind' => $channelKind,
            'channel_definition_id' => $definitionId,
            'channel_definition_name' => $definitionName,
            'members' => $validMembers,
        ];
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $e;
    }
}

if (!flow_conversation_api_authorized($input)) {
    chat_json(['status' => false, 'error' => 'Conversation API authorization failed.'], 401);
}

$creatorEmpId = max(0, (int)($input['created_by_emp_id'] ?? $input['creator_emp_id'] ?? $input['owner_emp_id'] ?? 0));
if ($creatorEmpId <= 0) {
    chat_json(['status' => false, 'error' => 'created_by_emp_id is required.'], 422);
}
$type = strtolower(trim((string)($input['type'] ?? $input['conversation_type'] ?? '')));
if (!in_array($type, ['group', 'channel'], true)) {
    chat_json(['status' => false, 'error' => 'type must be group or channel.'], 422);
}

try {
    $chatPdo = chat_db();
    $employeePdo = getEmployeeDB();
    chat_ensure_schema($chatPdo);
    chat_require_group_channel_creator($chatPdo, $employeePdo, $creatorEmpId);
    $result = $type === 'channel'
        ? flow_api_create_channel($chatPdo, $employeePdo, $input, $creatorEmpId)
        : flow_api_create_group($chatPdo, $employeePdo, $input, $creatorEmpId);
    chat_json($result);
} catch (Throwable $e) {
    error_log('external create conversation failed: ' . $e->getMessage());
    chat_json(['status' => false, 'error' => 'Unable to create ' . $type . ' through external API.'], 500);
}
