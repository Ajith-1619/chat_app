<?php
declare(strict_types=1);
require_once __DIR__ . '/_bootstrap.php';

try {
    $admin = flow_admin_require();
    $pdo = flow_admin_db();
} catch (Throwable $e) {
    flow_admin_json(['status' => false, 'error' => $e->getMessage()], 500);
}
$action = strtolower(trim((string)($_GET['action'] ?? 'overview')));
$search = trim((string)($_GET['q'] ?? ''));

function admin_overview(PDO $pdo): array
{
    return [
        'status' => true,
        'metrics' => [
            'users' => flow_admin_count($pdo, 'xmpp_users', 'status = 1'),
            'online' => flow_admin_count($pdo, 'xmpp_user_presence', 'last_seen_at >= DATE_SUB(NOW(), INTERVAL 60 SECOND)'),
            'groups' => flow_admin_count($pdo, 'xmpp_groups', "group_type <> 'channel' AND is_archived = 0"),
            'channels' => flow_admin_count($pdo, 'xmpp_groups', "group_type = 'channel' AND is_archived = 0"),
            'messages_today' => flow_admin_count($pdo, 'xmpp_messages', 'created_at >= CURDATE() AND deleted_at IS NULL'),
            'files_today' => flow_admin_count($pdo, 'xmpp_messages', "created_at >= CURDATE() AND file_url IS NOT NULL AND file_url <> '' AND deleted_at IS NULL"),
            'failed_push' => flow_admin_count($pdo, 'xmpp_push_queue', "status = 'failed'"),
            'draft_releases' => flow_admin_count($pdo, 'xmpp_release_builds', "status = 'draft'"),
        ],
        'recent_messages' => flow_admin_rows($pdo,
            "SELECT id, from_jid, to_jid, LEFT(body, 180) AS body, file_name, status, created_at
             FROM xmpp_messages WHERE deleted_at IS NULL ORDER BY id DESC LIMIT 12"),
        'diagnostics' => flow_admin_rows($pdo,
            "SELECT category, operation, status, ROUND(AVG(duration_ms), 2) AS avg_ms, MAX(duration_ms) AS max_ms, COUNT(*) AS samples
             FROM xmpp_diagnostics
             WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
             GROUP BY category, operation, status
             ORDER BY avg_ms DESC LIMIT 12"),
    ];
}

function admin_users(PDO $pdo, string $search): array
{
    $employeePdo = getEmployeeDB();
    $where = 'status = 1';
    $params = [];
    if ($search !== '') {
        $where .= ' AND (CAST(emp_id AS CHAR) LIKE :q OR name LIKE :q OR designation LIKE :q)';
        $params[':q'] = '%' . $search . '%';
    }
    $rows = flow_admin_rows($employeePdo,
        "SELECT emp_id, name, designation, department, emp_type
         FROM employee WHERE {$where} ORDER BY name ASC LIMIT 80", $params);
    $presence = [];
    foreach (flow_admin_rows($pdo, 'SELECT emp_id, last_seen_at FROM xmpp_user_presence') as $row) {
        $presence[(int)$row['emp_id']] = (string)$row['last_seen_at'];
    }
    foreach ($rows as &$row) {
        $empId = (int)$row['emp_id'];
        $row['jid'] = chat_jid($empId);
        $row['last_seen_at'] = $presence[$empId] ?? '';
    }
    unset($row);
    return ['status' => true, 'rows' => $rows];
}

function admin_channels(PDO $pdo, string $search): array
{
    $where = 'g.is_archived = 0';
    $params = [];
    if ($search !== '') {
        $where .= ' AND (g.room_name LIKE :q OR g.room_jid LIKE :q)';
        $params[':q'] = '%' . $search . '%';
    }
    return ['status' => true, 'rows' => flow_admin_rows($pdo,
        "SELECT g.id, g.room_name, g.room_jid, g.group_type, g.channel_kind, g.priority,
                g.created_at, COUNT(gm.emp_id) AS members
         FROM xmpp_groups g
         LEFT JOIN xmpp_group_members gm ON gm.group_id = g.id
         WHERE {$where}
         GROUP BY g.id
         ORDER BY g.created_at DESC LIMIT 100", $params)];
}

function admin_messages(PDO $pdo, string $search): array
{
    $where = 'deleted_at IS NULL';
    $params = [];
    if ($search !== '') {
        $where .= ' AND (body LIKE :q OR file_name LIKE :q OR from_jid LIKE :q OR to_jid LIKE :q)';
        $params[':q'] = '%' . $search . '%';
    }
    return ['status' => true, 'rows' => flow_admin_rows($pdo,
        "SELECT id, from_jid, to_jid, LEFT(body, 260) AS body, file_name, file_type, file_size,
                message_type, status, created_at
         FROM xmpp_messages WHERE {$where} ORDER BY id DESC LIMIT 100", $params)];
}

function admin_attachments(PDO $pdo, string $search): array
{
    $where = "deleted_at IS NULL AND file_url IS NOT NULL AND file_url <> ''";
    $params = [];
    if ($search !== '') {
        $where .= ' AND (file_name LIKE :q OR file_type LIKE :q OR from_jid LIKE :q OR to_jid LIKE :q)';
        $params[':q'] = '%' . $search . '%';
    }
    return ['status' => true, 'rows' => flow_admin_rows($pdo,
        "SELECT id, from_jid, to_jid, file_name, file_type, file_size, created_at
         FROM xmpp_messages WHERE {$where} ORDER BY id DESC LIMIT 100", $params)];
}

function admin_location(PDO $pdo): array
{
    return [
        'status' => true,
        'rows' => flow_admin_rows($pdo,
            "SELECT lv.emp_id, lv.enabled, lv.updated_by_emp_id, lv.updated_at, p.last_seen_at
             FROM xmpp_location_visibility lv
             LEFT JOIN xmpp_user_presence p ON p.emp_id = lv.emp_id
             ORDER BY lv.enabled DESC, lv.emp_id ASC LIMIT 200"),
    ];
}


function admin_task_db(): PDO
{
    if (function_exists('getTaskDB')) {
        try {
            return getTaskDB();
        } catch (Throwable $e) {
            error_log('flow admin task DB fallback: ' . $e->getMessage());
        }
    }
    return flow_admin_db();
}

function admin_tasks(string $search): array
{
    $taskPdo = admin_task_db();
    if (!flow_admin_table_exists($taskPdo, 'task_master')) return ['status' => true, 'rows' => []];
    $where = '1=1';
    $params = [];
    if ($search !== '') {
        $where .= ' AND (title LIKE :q OR description LIKE :q OR CAST(emp_id AS CHAR) LIKE :q OR CAST(created_by AS CHAR) LIKE :q)';
        $params[':q'] = '%' . $search . '%';
    }
    return ['status' => true, 'rows' => flow_admin_rows($taskPdo,
        "SELECT id, title, priority, emp_id, task_followers, task_groups, task_type, deadline, status, created_by, created_at
         FROM task_master WHERE {$where} ORDER BY id DESC LIMIT 100", $params)];
}

function admin_simple(PDO $pdo, string $table, string $order = 'id DESC'): array
{
    if (!flow_admin_table_exists($pdo, $table)) return ['status' => true, 'rows' => []];
    return ['status' => true, 'rows' => flow_admin_rows($pdo, "SELECT * FROM {$table} ORDER BY {$order} LIMIT 100")];
}

try {
    $payload = match ($action) {
        'overview' => admin_overview($pdo),
        'users' => admin_users($pdo, $search),
        'channels' => admin_channels($pdo, $search),
        'messages' => admin_messages($pdo, $search),
        'attachments' => admin_attachments($pdo, $search),
        'location' => admin_location($pdo),
        'notifications' => admin_simple($pdo, 'xmpp_push_queue', 'created_at DESC'),
        'releases' => admin_simple($pdo, 'xmpp_release_builds', 'created_at DESC'),
        'diagnostics' => admin_simple($pdo, 'xmpp_diagnostics', 'created_at DESC'),
        'tasks' => admin_tasks($search),
        default => ['status' => false, 'error' => 'Unknown admin action.'],
    };
    $payload['admin'] = $admin;
    flow_admin_json($payload, ($payload['status'] ?? false) ? 200 : 404);
} catch (Throwable $e) {
    error_log('flow admin API failed: ' . $e->getMessage());
    flow_admin_json(['status' => false, 'error' => 'Admin dashboard failed to load.'], 500);
}

