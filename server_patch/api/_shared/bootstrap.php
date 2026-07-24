<?php
declare(strict_types=1);

require_once __DIR__ . '/../../chat/bootstrap.php';
if (is_file(__DIR__ . '/../../chat/SystemNotification.php')) {
    require_once __DIR__ . '/../../chat/SystemNotification.php';
}

function flow_api_cors(): void
{
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, PATCH, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Authorization, Content-Type, Idempotency-Key, X-Flow-Actor-Emp-Id, X-Flow-Api-Key');
    header('Access-Control-Max-Age: 86400');
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}

function flow_api_request_id(): string
{
    static $id = null;
    if ($id === null) $id = bin2hex(random_bytes(8));
    return $id;
}

function flow_api_json(array $payload, int $status = 200): never
{
    if (!headers_sent()) {
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        header('X-Flow-Request-Id: ' . flow_api_request_id());
    }
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

function flow_api_error(string $message, int $status = 400, string $code = 'FLOW_API_ERROR', array $extra = []): never
{
    flow_api_json(array_merge([
        'status' => false,
        'error' => $message,
        'code' => $code,
        'request_id' => flow_api_request_id(),
    ], $extra), $status);
}

function flow_api_input(): array
{
    $raw = file_get_contents('php://input') ?: '';
    if ($raw === '') return [];
    $data = json_decode($raw, true);
    if (!is_array($data)) flow_api_error('Invalid JSON body.', 400, 'INVALID_JSON');
    return $data;
}

function flow_api_header(string $name): ?string
{
    $key = 'HTTP_' . strtoupper(str_replace('-', '_', $name));
    if (isset($_SERVER[$key]) && trim((string)$_SERVER[$key]) !== '') return trim((string)$_SERVER[$key]);
    if (function_exists('getallheaders')) {
        foreach (getallheaders() as $header => $value) {
            if (strcasecmp((string)$header, $name) === 0) return trim((string)$value);
        }
    }
    return null;
}

function flow_api_segments(): array
{
    $path = $_SERVER['PATH_INFO'] ?? '';
    if ($path === '') {
        $uri = parse_url($_SERVER['REQUEST_URI'] ?? '', PHP_URL_PATH) ?: '';
        $marker = '/v1/';
        $pos = strpos($uri, $marker);
        $path = $pos === false ? '' : substr($uri, $pos + strlen($marker));
    }
    return array_values(array_filter(explode('/', trim($path, '/')), static fn($v) => $v !== ''));
}

function flow_api_columns(PDO $pdo, string $table, ?string $schema = null): array
{
    try {
        $schema = $schema ?: (string)$pdo->query('SELECT DATABASE()')->fetchColumn();
        $stmt = $pdo->prepare('SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = :schema AND TABLE_NAME = :table');
        $stmt->execute([':schema' => $schema, ':table' => $table]);
        return array_map('strval', $stmt->fetchAll(PDO::FETCH_COLUMN));
    } catch (Throwable $e) {
        return [];
    }
}

function flow_api_pick(array $columns, array $candidates): ?string
{
    foreach ($candidates as $candidate) {
        if (in_array($candidate, $columns, true)) return $candidate;
    }
    return null;
}

function flow_api_chat_db(): PDO
{
    $pdo = chat_db();
    chat_ensure_schema($pdo);
    flow_api_ensure_schema($pdo);
    return $pdo;
}

function flow_api_task_db(): PDO
{
    if (function_exists('getTaskDB')) {
        try { return getTaskDB(); } catch (Throwable $e) {}
    }
    return flow_api_chat_db();
}

function flow_api_employee_db(): PDO
{
    if (function_exists('getEmployeeDB')) {
        try { return getEmployeeDB(); } catch (Throwable $e) {}
    }
    return flow_api_chat_db();
}

function flow_api_ensure_schema(PDO $pdo): void
{
    $pdo->exec("CREATE TABLE IF NOT EXISTS flow_api_clients (
        id INT AUTO_INCREMENT PRIMARY KEY,
        client_name VARCHAR(120) NOT NULL,
        api_key_hash VARCHAR(128) NOT NULL UNIQUE,
        owner_emp_id INT NOT NULL DEFAULT 302,
        scopes_json TEXT NOT NULL,
        allowed_ips TEXT NULL,
        status TINYINT NOT NULL DEFAULT 1,
        expires_at DATETIME NULL,
        last_used_at DATETIME NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    $pdo->exec("CREATE TABLE IF NOT EXISTS flow_api_audit_logs (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        client_id INT NULL,
        actor_emp_id INT NULL,
        scope VARCHAR(80) NOT NULL,
        method VARCHAR(12) NOT NULL,
        path VARCHAR(500) NOT NULL,
        target_type VARCHAR(80) NULL,
        target_id VARCHAR(120) NULL,
        status_code INT NOT NULL,
        result VARCHAR(30) NOT NULL,
        error_text TEXT NULL,
        request_id VARCHAR(40) NOT NULL,
        ip_address VARCHAR(80) NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_flow_api_audit_created (created_at),
        INDEX idx_flow_api_audit_client (client_id, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    $pdo->exec("CREATE TABLE IF NOT EXISTS flow_api_idempotency_keys (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        client_id INT NOT NULL,
        idempotency_key VARCHAR(160) NOT NULL,
        request_hash VARCHAR(128) NOT NULL,
        response_json MEDIUMTEXT NOT NULL,
        status_code INT NOT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_flow_api_idempotency (client_id, idempotency_key)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
}

function flow_api_auth(array $requiredScopes = []): array
{
    $pdo = flow_api_chat_db();
    $auth = flow_api_header('Authorization') ?? '';
    $apiKey = '';
    if (preg_match('/^Bearer\s+(.+)$/i', $auth, $m)) $apiKey = trim($m[1]);
    if ($apiKey === '') $apiKey = flow_api_header('X-Flow-Api-Key') ?? '';
    if ($apiKey === '') flow_api_error('Unauthorized', 401, 'UNAUTHORIZED');

    $client = null;
    $hash = hash('sha256', $apiKey);
    $stmt = $pdo->prepare('SELECT * FROM flow_api_clients WHERE api_key_hash = :hash AND status = 1 LIMIT 1');
    $stmt->execute([':hash' => $hash]);
    $client = $stmt->fetch(PDO::FETCH_ASSOC) ?: null;

    $devKey = getenv('FLOW_EXTERNAL_API_DEV_KEY') ?: '';
    if (!$client && $devKey !== '' && hash_equals($devKey, $apiKey)) {
        $client = [
            'id' => 0,
            'client_name' => 'Environment API Key',
            'owner_emp_id' => (int)(getenv('FLOW_EXTERNAL_API_DEV_EMP_ID') ?: 302),
            'scopes_json' => '["*"]',
            'allowed_ips' => null,
            'expires_at' => null,
        ];
    }
    if (!$client) flow_api_error('Unauthorized', 401, 'UNAUTHORIZED');
    if (!empty($client['expires_at']) && strtotime((string)$client['expires_at']) < time()) {
        flow_api_error('API key expired.', 401, 'API_KEY_EXPIRED');
    }

    $scopes = json_decode((string)$client['scopes_json'], true);
    if (!is_array($scopes)) $scopes = [];
    foreach ($requiredScopes as $scope) {
        if (!in_array('*', $scopes, true) && !in_array($scope, $scopes, true)) {
            flow_api_error('Forbidden for scope ' . $scope, 403, 'FORBIDDEN');
        }
    }
    $actor = (int)(flow_api_header('X-Flow-Actor-Emp-Id') ?: ($_GET['actor_emp_id'] ?? $client['owner_emp_id'] ?? 0));
    if ((int)$client['id'] > 0) {
        $upd = $pdo->prepare('UPDATE flow_api_clients SET last_used_at = NOW() WHERE id = :id');
        $upd->execute([':id' => (int)$client['id']]);
    }
    return [
        'client_id' => (int)$client['id'],
        'client_name' => (string)$client['client_name'],
        'owner_emp_id' => (int)$client['owner_emp_id'],
        'actor_emp_id' => $actor > 0 ? $actor : (int)$client['owner_emp_id'],
        'scopes' => $scopes,
    ];
}

function flow_api_audit(array $auth, string $scope, int $statusCode, string $result, ?string $error = null, ?string $targetType = null, ?string $targetId = null): void
{
    try {
        $pdo = flow_api_chat_db();
        $stmt = $pdo->prepare('INSERT INTO flow_api_audit_logs (client_id, actor_emp_id, scope, method, path, target_type, target_id, status_code, result, error_text, request_id, ip_address) VALUES (:client_id, :actor_emp_id, :scope, :method, :path, :target_type, :target_id, :status_code, :result, :error_text, :request_id, :ip)');
        $stmt->execute([
            ':client_id' => $auth['client_id'] ?? null,
            ':actor_emp_id' => $auth['actor_emp_id'] ?? null,
            ':scope' => $scope,
            ':method' => $_SERVER['REQUEST_METHOD'] ?? 'GET',
            ':path' => $_SERVER['REQUEST_URI'] ?? '',
            ':target_type' => $targetType,
            ':target_id' => $targetId,
            ':status_code' => $statusCode,
            ':result' => $result,
            ':error_text' => $error,
            ':request_id' => flow_api_request_id(),
            ':ip' => $_SERVER['REMOTE_ADDR'] ?? null,
        ]);
    } catch (Throwable $e) {}
}

function flow_api_success(array $auth, string $scope, array $data = [], int $status = 200, ?string $targetType = null, ?string $targetId = null): never
{
    flow_api_audit($auth, $scope, $status, 'success', null, $targetType, $targetId);
    flow_api_json(array_merge(['status' => true, 'request_id' => flow_api_request_id()], $data), $status);
}

function flow_api_jid_for_emp(PDO $pdo, int $empId): string
{
    $stmt = $pdo->prepare('SELECT jid FROM xmpp_users WHERE emp_id = :emp_id LIMIT 1');
    $stmt->execute([':emp_id' => $empId]);
    $jid = (string)($stmt->fetchColumn() ?: '');
    return $jid !== '' ? $jid : $empId . '@chat.skylinkonline.net';
}

function flow_api_list_users(int $limit): array
{
    $pdo = flow_api_chat_db();
    $stmt = $pdo->prepare('SELECT emp_id, jid, avatar_url, status, created_at, updated_at FROM xmpp_users ORDER BY emp_id LIMIT :limit');
    $stmt->bindValue(':limit', max(1, min(500, $limit)), PDO::PARAM_INT);
    $stmt->execute();
    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}

function flow_api_group_query(string $type, int $limit): array
{
    $pdo = flow_api_chat_db();
    $stmt = $pdo->prepare('SELECT id, room_name, room_jid, group_type, channel_kind, description, status, priority, target_date, next_action_text, next_action_persons, next_action_date, wakeup_enabled, wakeup_interval_minutes, is_archived, created_by_emp_id, created_at FROM xmpp_groups WHERE group_type = :type ORDER BY created_at DESC LIMIT :limit');
    $stmt->bindValue(':type', $type);
    $stmt->bindValue(':limit', max(1, min(500, $limit)), PDO::PARAM_INT);
    $stmt->execute();
    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}

function flow_api_group_detail(int $id): array
{
    $pdo = flow_api_chat_db();
    $stmt = $pdo->prepare('SELECT * FROM xmpp_groups WHERE id = :id LIMIT 1');
    $stmt->execute([':id' => $id]);
    $group = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$group) flow_api_error('Group/channel not found.', 404, 'NOT_FOUND');
    $members = $pdo->prepare('SELECT gm.emp_id, gm.role, gm.joined_at, gm.history_visible_from, u.jid FROM xmpp_group_members gm LEFT JOIN xmpp_users u ON u.emp_id = gm.emp_id WHERE gm.group_id = :id ORDER BY gm.role DESC, gm.joined_at ASC');
    $members->execute([':id' => $id]);
    $group['members'] = $members->fetchAll(PDO::FETCH_ASSOC);
    return $group;
}

function flow_api_create_group_like(array $auth, string $type, array $input): array
{
    $pdo = flow_api_chat_db();
    $name = trim((string)($input['name'] ?? $input['room_name'] ?? ''));
    if ($name === '') flow_api_error('name is required.', 422, 'VALIDATION_ERROR');
    $slug = strtolower(preg_replace('/[^a-z0-9]+/i', '-', $name));
    $slug = trim($slug ?: ('room-' . bin2hex(random_bytes(3))), '-');
    $prefix = $type === 'channel' ? 'channel' : 'group';
    $jid = (string)($input['room_jid'] ?? ($prefix . '-' . $slug . '-' . bin2hex(random_bytes(3)) . '@conference.chat.skylinkonline.net'));
    $kind = (string)($input['channel_kind'] ?? $input['kind'] ?? ($type === 'channel' ? 'operational' : 'group'));
    $members = array_values(array_unique(array_map('intval', $input['member_emp_ids'] ?? [])));
    $owner = (int)($input['owner_emp_id'] ?? $auth['actor_emp_id']);
    if (!in_array($owner, $members, true)) $members[] = $owner;

    $stmt = $pdo->prepare('INSERT INTO xmpp_groups (room_name, room_jid, group_type, channel_kind, description, status, priority, owner_emp_id, created_by_emp_id) VALUES (:name, :jid, :type, :kind, :description, :status, :priority, :owner, :creator)');
    $stmt->execute([
        ':name' => $name,
        ':jid' => $jid,
        ':type' => $type,
        ':kind' => $kind,
        ':description' => (string)($input['description'] ?? ''),
        ':status' => (string)($input['status'] ?? 'Open'),
        ':priority' => (string)($input['priority'] ?? 'Normal'),
        ':owner' => $owner,
        ':creator' => (int)$auth['actor_emp_id'],
    ]);
    $groupId = (int)$pdo->lastInsertId();
    $ins = $pdo->prepare('INSERT INTO xmpp_group_members (group_id, emp_id, role, history_visible_from) VALUES (:group_id, :emp_id, :role, NULL) ON DUPLICATE KEY UPDATE role = VALUES(role)');
    foreach ($members as $empId) {
        if ($empId > 0) $ins->execute([':group_id' => $groupId, ':emp_id' => $empId, ':role' => $empId === $owner ? 'owner' : 'member']);
    }
    return flow_api_group_detail($groupId);
}

function flow_api_handle_chat(array $auth, array $segments): never
{
    $pdo = flow_api_chat_db();
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'GET' && (($segments[0] ?? '') === 'messages' || $segments === [])) {
        $jid = (string)($_GET['jid'] ?? '');
        if ($jid === '') flow_api_error('jid query parameter is required.', 422, 'VALIDATION_ERROR');
        $limit = max(1, min(200, (int)($_GET['limit'] ?? 50)));
        $actorJid = flow_api_jid_for_emp($pdo, (int)$auth['actor_emp_id']);
        $stmt = $pdo->prepare('SELECT * FROM xmpp_messages WHERE deleted_at IS NULL AND ((from_jid = :actor AND to_jid = :jid) OR (from_jid = :jid AND to_jid = :actor) OR to_jid = :jid) ORDER BY id DESC LIMIT :limit');
        $stmt->bindValue(':actor', $actorJid);
        $stmt->bindValue(':jid', $jid);
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->execute();
        $rows = array_reverse($stmt->fetchAll(PDO::FETCH_ASSOC));
        flow_api_success($auth, 'chat:read', ['messages' => $rows]);
    }
    if ($method === 'POST' && (($segments[0] ?? '') === 'messages' || $segments === [])) {
        $input = flow_api_input();
        $to = trim((string)($input['to_jid'] ?? ''));
        $body = trim((string)($input['body'] ?? ''));
        if ($to === '' || $body === '') flow_api_error('to_jid and body are required.', 422, 'VALIDATION_ERROR');
        $from = flow_api_jid_for_emp($pdo, (int)$auth['actor_emp_id']);
        $stmt = $pdo->prepare('INSERT INTO xmpp_messages (from_jid, to_jid, body, message_type, source_device, source_name, client_message_id, status) VALUES (:from_jid, :to_jid, :body, :type, :source_device, :source_name, :client_message_id, :status)');
        $stmt->execute([
            ':from_jid' => $from,
            ':to_jid' => $to,
            ':body' => $body,
            ':type' => (string)($input['message_type'] ?? 'chat'),
            ':source_device' => 'api',
            ':source_name' => (string)($input['source_name'] ?? $auth['client_name']),
            ':client_message_id' => (string)($input['client_message_id'] ?? ('api-' . flow_api_request_id())),
            ':status' => 'sent',
        ]);
        $id = (int)$pdo->lastInsertId();
        try { chat_ejabberd_send_message($from, $to, $body); } catch (Throwable $e) {}
        flow_api_success($auth, 'chat:write', ['message' => ['id' => $id, 'from_jid' => $from, 'to_jid' => $to]], 201, 'message', (string)$id);
    }
    flow_api_error('Unknown chat endpoint.', 404, 'NOT_FOUND');
}

function flow_api_handle_users(array $auth, array $segments): never
{
    $pdo = flow_api_chat_db();
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method !== 'GET') flow_api_error('Method not allowed.', 405, 'METHOD_NOT_ALLOWED');
    if (isset($segments[0]) && ctype_digit($segments[0])) {
        $empId = (int)$segments[0];
        $stmt = $pdo->prepare('SELECT emp_id, jid, avatar_url, status, created_at, updated_at FROM xmpp_users WHERE emp_id = :emp_id LIMIT 1');
        $stmt->execute([':emp_id' => $empId]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$user) flow_api_error('User not found.', 404, 'NOT_FOUND');
        $presence = $pdo->prepare('SELECT * FROM xmpp_user_presence WHERE emp_id = :emp_id ORDER BY last_seen_at DESC LIMIT 5');
        $presence->execute([':emp_id' => $empId]);
        $user['presence'] = $presence->fetchAll(PDO::FETCH_ASSOC);
        flow_api_success($auth, 'users:read', ['user' => $user], 200, 'user', (string)$empId);
    }
    flow_api_success($auth, 'users:read', ['users' => flow_api_list_users((int)($_GET['limit'] ?? 100))]);
}

function flow_api_handle_groups_channels(array $auth, array $segments, string $type): never
{
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'GET') {
        if (isset($segments[0]) && ctype_digit($segments[0])) flow_api_success($auth, $type . 's:read', [$type => flow_api_group_detail((int)$segments[0])]);
        flow_api_success($auth, $type . 's:read', [$type . 's' => flow_api_group_query($type, (int)($_GET['limit'] ?? 100))]);
    }
    if ($method === 'POST') {
        $created = flow_api_create_group_like($auth, $type, flow_api_input());
        flow_api_success($auth, $type . 's:write', [$type => $created], 201, $type, (string)$created['id']);
    }
    if (($method === 'PATCH' || $method === 'POST') && isset($segments[0]) && ctype_digit($segments[0])) {
        $input = flow_api_input();
        $allowed = ['room_name', 'description', 'channel_kind', 'status', 'priority', 'target_date', 'next_action_text', 'next_action_persons', 'next_action_date', 'wakeup_enabled', 'wakeup_interval_minutes', 'is_archived'];
        $sets = [];$params = [':id' => (int)$segments[0]];
        foreach ($allowed as $field) if (array_key_exists($field, $input)) { $sets[] = "$field = :$field"; $params[":$field"] = $input[$field]; }
        if (!$sets) flow_api_error('No editable fields supplied.', 422, 'VALIDATION_ERROR');
        $pdo = flow_api_chat_db();
        $stmt = $pdo->prepare('UPDATE xmpp_groups SET ' . implode(', ', $sets) . ' WHERE id = :id AND group_type = :type');
        $params[':type'] = $type;
        $stmt->execute($params);
        flow_api_success($auth, $type . 's:write', [$type => flow_api_group_detail((int)$segments[0])], 200, $type, (string)$segments[0]);
    }
    flow_api_error('Method not allowed.', 405, 'METHOD_NOT_ALLOWED');
}

function flow_api_handle_tasks(array $auth, array $segments): never
{
    $pdo = flow_api_task_db();
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'GET') {
        $limit = max(1, min(500, (int)($_GET['limit'] ?? 100)));
        if (isset($segments[0]) && ctype_digit($segments[0])) {
            $stmt = $pdo->prepare('SELECT * FROM task_master WHERE id = :id LIMIT 1');
            $stmt->execute([':id' => (int)$segments[0]]);
            $task = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!$task) flow_api_error('Task not found.', 404, 'NOT_FOUND');
            flow_api_success($auth, 'tasks:read', ['task' => $task]);
        }
        $stmt = $pdo->prepare('SELECT * FROM task_master ORDER BY id DESC LIMIT :limit');
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->execute();
        flow_api_success($auth, 'tasks:read', ['tasks' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }
    if ($method === 'POST' && isset($segments[1]) && $segments[1] === 'updates' && ctype_digit($segments[0])) {
        $input = flow_api_input();
        $comments = trim((string)($input['comments'] ?? $input['comment'] ?? ''));
        if ($comments === '') flow_api_error('comments is required.', 422, 'VALIDATION_ERROR');
        $cols = flow_api_columns($pdo, 'task_explained');
        if (!$cols) flow_api_error('task_explained table not found.', 500, 'TASK_SCHEMA_MISSING');
        $fields = [];$values = [];$params = [];
        foreach ([flow_api_pick($cols, ['task_id','task_master_id']) => (int)$segments[0], flow_api_pick($cols, ['comments','comment','description']) => $comments, flow_api_pick($cols, ['updated_by','created_by','emp_id']) => (int)$auth['actor_emp_id'], flow_api_pick($cols, ['comment_type','type']) => 'External API'] as $col => $val) {
            if ($col) { $fields[] = $col; $values[] = ':' . $col; $params[':' . $col] = $val; }
        }
        $stmt = $pdo->prepare('INSERT INTO task_explained (' . implode(',', $fields) . ') VALUES (' . implode(',', $values) . ')');
        $stmt->execute($params);
        flow_api_success($auth, 'tasks:write', ['task_update' => ['id' => (int)$pdo->lastInsertId(), 'task_id' => (int)$segments[0]]], 201);
    }
    if ($method === 'POST') {
        $input = flow_api_input();
        $title = trim((string)($input['title'] ?? ''));
        if ($title === '') flow_api_error('title is required.', 422, 'VALIDATION_ERROR');
        $cols = flow_api_columns($pdo, 'task_master');
        $data = [
            'title' => $title,
            'description' => (string)($input['description'] ?? ''),
            'priority' => (string)($input['priority'] ?? 'medium'),
            'emp_id' => implode(',', array_map('intval', $input['assignees'] ?? [$auth['actor_emp_id']])),
            'task_followers' => implode(',', array_map('intval', $input['followers'] ?? [$auth['actor_emp_id']])),
            'task_groups' => (string)($input['task_groups'] ?? $input['group_id'] ?? '99'),
            'task_type' => (string)($input['task_type'] ?? 'general'),
            'deadline' => (string)($input['deadline'] ?? date('Y-m-d 00:00:00')),
            'created_by' => (int)$auth['actor_emp_id'],
            'meet_type' => (string)($input['meet_type'] ?? '1'),
            'status' => (int)($input['status'] ?? 2),
            'next_followup_date' => (string)($input['next_followup_date'] ?? ''),
            'vertical' => (string)($input['vertical'] ?? 'general'),
        ];
        $fields=[];$values=[];$params=[];
        foreach ($data as $field=>$value) if (in_array($field, $cols, true)) { $fields[]=$field; $values[]=':'.$field; $params[':'.$field]=$value; }
        if (!$fields) flow_api_error('task_master schema not mapped.', 500, 'TASK_SCHEMA_MISSING');
        $stmt = $pdo->prepare('INSERT INTO task_master (' . implode(',', $fields) . ') VALUES (' . implode(',', $values) . ')');
        $stmt->execute($params);
        $id = (int)$pdo->lastInsertId();
        flow_api_success($auth, 'tasks:write', ['task' => ['id' => $id, 'title' => $title]], 201, 'task', (string)$id);
    }
    flow_api_error('Method not allowed.', 405, 'METHOD_NOT_ALLOWED');
}

function flow_api_handle_reminders(array $auth, array $segments): never
{
    $pdo = flow_api_chat_db();
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'GET') {
        $stmt = $pdo->prepare('SELECT * FROM xmpp_reminders WHERE created_by_emp_id = :emp_id OR JSON_CONTAINS(assignee_ids_json, :emp_json) ORDER BY starts_at DESC LIMIT 200');
        $stmt->execute([':emp_id' => (int)$auth['actor_emp_id'], ':emp_json' => json_encode((int)$auth['actor_emp_id'])]);
        flow_api_success($auth, 'reminders:read', ['reminders' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }
    if ($method === 'POST') {
        $input = flow_api_input();
        $title = trim((string)($input['title'] ?? ''));
        $starts = trim((string)($input['starts_at'] ?? $input['due_at'] ?? ''));
        if ($title === '' || $starts === '') flow_api_error('title and starts_at are required.', 422, 'VALIDATION_ERROR');
        $assignees = array_values(array_unique(array_map('intval', $input['assignee_emp_ids'] ?? [$auth['actor_emp_id']])));
        $stmt = $pdo->prepare('INSERT INTO xmpp_reminders (kind, title, notes, created_by_emp_id, assignee_ids_json, starts_at, next_due_at, recurrence_type, active) VALUES (:kind, :title, :notes, :created_by, :assignees, :starts_at, :next_due_at, :recurrence, 1)');
        $stmt->execute([':kind' => (string)($input['kind'] ?? 'reminder'), ':title' => $title, ':notes' => (string)($input['notes'] ?? ''), ':created_by' => (int)$auth['actor_emp_id'], ':assignees' => json_encode($assignees), ':starts_at' => $starts, ':next_due_at' => $starts, ':recurrence' => (string)($input['recurrence_type'] ?? 'once')]);
        flow_api_success($auth, 'reminders:write', ['reminder' => ['id' => (int)$pdo->lastInsertId(), 'title' => $title]], 201);
    }
    flow_api_error('Method not allowed.', 405, 'METHOD_NOT_ALLOWED');
}

function flow_api_handle_notifications(array $auth, array $segments): never
{
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') flow_api_error('Method not allowed.', 405, 'METHOD_NOT_ALLOWED');
    $input = flow_api_input();
    $empId = (int)($input['recipient_emp_id'] ?? $input['emp_id'] ?? 0);
    $title = trim((string)($input['title'] ?? 'Flow Notification'));
    $body = trim((string)($input['body'] ?? ''));
    if ($empId <= 0 || $body === '') flow_api_error('recipient_emp_id and body are required.', 422, 'VALIDATION_ERROR');
    if (function_exists('chat_send_system_notification')) {
        chat_send_system_notification($empId, (string)($input['event_type'] ?? 'external_api'), (string)($input['reference_id'] ?? flow_api_request_id()), $title, $body);
    }
    flow_api_success($auth, 'notifications:write', ['notification' => ['recipient_emp_id' => $empId, 'title' => $title]], 201);
}

function flow_api_handle_simple_table(array $auth, string $scope, string $table, string $key): never
{
    $pdo = flow_api_chat_db();
    $limit = max(1, min(300, (int)($_GET['limit'] ?? 100)));
    $stmt = $pdo->prepare('SELECT * FROM ' . $table . ' ORDER BY id DESC LIMIT :limit');
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->execute();
    flow_api_success($auth, $scope, [$key => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function flow_api_dispatch(string $module): never
{
    flow_api_cors();
    $scopeMap = [
        'chat' => ['GET' => 'chat:read', 'POST' => 'chat:write', 'DELETE' => 'chat:write'],
        'users' => ['GET' => 'users:read'],
        'groups' => ['GET' => 'groups:read', 'POST' => 'groups:write', 'PATCH' => 'groups:write', 'DELETE' => 'groups:write'],
        'channels' => ['GET' => 'channels:read', 'POST' => 'channels:write', 'PATCH' => 'channels:write', 'DELETE' => 'channels:write'],
        'tasks' => ['GET' => 'tasks:read', 'POST' => 'tasks:write'],
        'reminders' => ['GET' => 'reminders:read', 'POST' => 'reminders:write'],
        'notifications' => ['POST' => 'notifications:write'],
        'files' => ['GET' => 'files:read', 'POST' => 'files:write'],
        'attendance' => ['GET' => 'attendance:read', 'POST' => 'attendance:write'],
        'location' => ['GET' => 'location:read', 'POST' => 'location:write'],
        'releases' => ['GET' => 'releases:read', 'POST' => 'releases:write'],
        'diagnostics' => ['GET' => 'diagnostics:read'],
        'search' => ['GET' => 'search:read'],
        'saved' => ['GET' => 'saved:read', 'POST' => 'saved:write'],
        'ai' => ['GET' => 'ai:read', 'POST' => 'ai:write'],
        'external-users' => ['GET' => 'external-users:read', 'POST' => 'external-users:write'],
        'storage' => ['GET' => 'storage:read', 'POST' => 'storage:write', 'PATCH' => 'storage:write'],
        'polls' => ['POST' => 'chat:write'],
        'checklists' => ['POST' => 'chat:write'],
    ];
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    $required = $scopeMap[$module][$method] ?? ($scopeMap[$module]['GET'] ?? $module . ':read');
    $auth = flow_api_auth([$required]);
    $segments = flow_api_segments();
    try {
        match ($module) {
            'chat' => flow_api_ext_chat($auth, $segments),
            'users' => flow_api_handle_users($auth, $segments),
            'groups' => flow_api_ext_groups_channels($auth, $segments, 'group'),
            'channels' => flow_api_ext_groups_channels($auth, $segments, 'channel'),
            'tasks' => flow_api_handle_tasks($auth, $segments),
            'reminders' => flow_api_handle_reminders($auth, $segments),
            'notifications' => flow_api_handle_notifications($auth, $segments),
            'files' => flow_api_ext_files($auth, $segments),
            'location' => flow_api_ext_location($auth, $segments),
            'attendance' => flow_api_ext_attendance($auth, $segments),
            'releases' => flow_api_ext_releases($auth, $segments),
            'diagnostics' => flow_api_handle_simple_table($auth, 'diagnostics:read', 'xmpp_api_diagnostics', 'diagnostics'),
            'search' => flow_api_ext_chat($auth, ['search']),
            'saved' => flow_api_ext_saved($auth, $segments),
            'ai' => flow_api_ext_ai($auth, $segments),
            'external-users' => flow_api_ext_external_users($auth, $segments),
            'storage' => flow_api_ext_storage($auth, $segments),
            'polls' => flow_api_ext_json_message($auth, 'SKYLINK_POLL:'),
            'checklists' => flow_api_ext_json_message($auth, 'SKYLINKCHECKLIST:'),
            default => flow_api_error('Unknown module.', 404, 'NOT_FOUND'),
        };
    } catch (PDOException $e) {
        flow_api_audit($auth, $required, 500, 'error', $e->getMessage());
        flow_api_error('Database error: ' . $e->getMessage(), 500, 'DATABASE_ERROR');
    } catch (Throwable $e) {
        flow_api_audit($auth, $required, 500, 'error', $e->getMessage());
        flow_api_error('Server error: ' . $e->getMessage(), 500, 'SERVER_ERROR');
    }
}

require_once __DIR__ . '/extended.php';
