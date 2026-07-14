<?php
declare(strict_types=1);

function flow_admin_normalize_path(string $path): string
{
    return str_replace('\\', '/', $path);
}

function flow_admin_bootstrap_candidates(): array
{
    $envPath = trim((string)(getenv('FLOW_ADMIN_CHAT_BOOTSTRAP') ?: ''));
    $roots = array_values(array_unique(array_filter([
        __DIR__,
        dirname(__DIR__),
        dirname(__DIR__, 2),
        dirname(__DIR__, 3),
        (string)($_SERVER['DOCUMENT_ROOT'] ?? ''),
        dirname((string)($_SERVER['DOCUMENT_ROOT'] ?? '')),
        '/home',
        '/var/www',
        '/var/www/html',
        '/usr/local/apache/htdocs',
        '/opt/lampp/htdocs',
        'C:/xampp/htdocs',
    ], static fn(string $root): bool => $root !== '' && is_dir($root))));

    $candidates = [];
    if ($envPath !== '') $candidates[] = $envPath;
    foreach ($roots as $root) {
        $root = rtrim(flow_admin_normalize_path($root), '/');
        $candidates[] = $root . '/chat/bootstrap.php';
        $candidates[] = $root . '/router_login/chat/bootstrap.php';
        $candidates[] = $root . '/public_html/chat/bootstrap.php';
        $candidates[] = $root . '/public_html/router_login/chat/bootstrap.php';
        $candidates[] = $root . '/www/chat/bootstrap.php';
        $candidates[] = $root . '/www/router_login/chat/bootstrap.php';
    }

    foreach ([$_SERVER['DOCUMENT_ROOT'] ?? '', dirname(__DIR__), dirname(__DIR__, 2)] as $root) {
        $root = (string)$root;
        if ($root === '' || !is_dir($root)) continue;
        foreach (['bootstrap.php'] as $file) {
            foreach (@glob(rtrim(flow_admin_normalize_path($root), '/') . '/*/chat/' . $file) ?: [] as $match) {
                $candidates[] = $match;
            }
            foreach (@glob(rtrim(flow_admin_normalize_path($root), '/') . '/*/*/chat/' . $file) ?: [] as $match) {
                $candidates[] = $match;
            }
        }
    }

    return array_values(array_unique(array_map('flow_admin_normalize_path', $candidates)));
}

$chatBootstrapCandidates = flow_admin_bootstrap_candidates();
$chatBootstrap = '';
foreach ($chatBootstrapCandidates as $candidate) {
    if (is_file($candidate)) {
        $chatBootstrap = $candidate;
        break;
    }
}
$FLOW_ADMIN_BOOTSTRAP_ERROR = '';
if ($chatBootstrap !== '') {
    require_once $chatBootstrap;
} else {
    $FLOW_ADMIN_BOOTSTRAP_ERROR = 'Chat backend bootstrap.php was not found. Set FLOW_ADMIN_CHAT_BOOTSTRAP or upload admin/ on the same server as router_login/chat/.';
}

const FLOW_ADMIN_ALLOWED_EMP_IDS = [302, 116];

function flow_admin_start(): void
{
    global $FLOW_ADMIN_BOOTSTRAP_ERROR;
    if ($FLOW_ADMIN_BOOTSTRAP_ERROR !== '') {
        throw new RuntimeException($FLOW_ADMIN_BOOTSTRAP_ERROR);
    }
    chat_start();
}

function flow_admin_is_allowed(int $empId): bool
{
    return in_array($empId, FLOW_ADMIN_ALLOWED_EMP_IDS, true);
}

function flow_admin_current_emp_id(): int
{
    flow_admin_start();
    $empId = (int)($_SESSION['flow_admin_emp_id'] ?? $_SESSION['employee_id'] ?? 0);
    return flow_admin_is_allowed($empId) ? $empId : 0;
}

function flow_admin_require(): array
{
    $empId = flow_admin_current_emp_id();
    if ($empId <= 0) {
        if (str_starts_with((string)($_SERVER['HTTP_ACCEPT'] ?? ''), 'application/json')) {
            flow_admin_json(['status' => false, 'error' => 'Admin login required.'], 401);
        }
        header('Location: index.php');
        exit;
    }
    try {
        return chat_user_payload(getEmployeeDB(), $empId, chat_jid($empId), true);
    } catch (Throwable) {
        return ['emp_id' => (string)$empId, 'name' => 'Admin ' . $empId, 'designation' => 'Master Admin', 'jid' => chat_jid($empId)];
    }
}

function flow_admin_login(string $username, string $password): array
{
    global $FLOW_ADMIN_BOOTSTRAP_ERROR;
    if ($FLOW_ADMIN_BOOTSTRAP_ERROR !== '') {
        throw new RuntimeException($FLOW_ADMIN_BOOTSTRAP_ERROR);
    }
    $username = strtolower(trim($username));
    $username = preg_replace('/@chat\.skylinkonline\.net$/i', '', $username) ?: '';
    $username = preg_replace('/^sky-/i', '', $username) ?: '';
    if ($username === '' || $password === '' || !ctype_digit($username)) {
        throw new RuntimeException('Employee ID and password are required.');
    }
    $empId = (int)$username;
    if (!flow_admin_is_allowed($empId)) {
        throw new RuntimeException('Master admin access is restricted.');
    }
    if (!chat_ejabberd_client()->authenticate((string)$empId, $password)) {
        throw new RuntimeException('Invalid username or password.');
    }
    flow_admin_start();
    session_regenerate_id(true);
    $_SESSION['flow_admin_emp_id'] = $empId;
    $_SESSION['username'] = 'sky-' . $empId;
    $_SESSION['employee_id'] = $empId;
    $_SESSION['auth_source'] = 'flow_admin';
    $pdo = chat_db();
    chat_ensure_schema($pdo);
    return chat_user_payload(getEmployeeDB(), $empId, chat_jid($empId), true);
}

function flow_admin_db(): PDO
{
    global $FLOW_ADMIN_BOOTSTRAP_ERROR;
    if ($FLOW_ADMIN_BOOTSTRAP_ERROR !== '') {
        throw new RuntimeException($FLOW_ADMIN_BOOTSTRAP_ERROR);
    }
    $pdo = chat_db();
    chat_ensure_schema($pdo);
    return $pdo;
}

function flow_admin_table_exists(PDO $pdo, string $table): bool
{
    try {
        $stmt = $pdo->prepare('SHOW TABLES LIKE :table_name');
        $stmt->execute([':table_name' => $table]);
        return (bool)$stmt->fetchColumn();
    } catch (Throwable) {
        return false;
    }
}

function flow_admin_count(PDO $pdo, string $table, string $where = '1=1', array $params = []): int
{
    if (!flow_admin_table_exists($pdo, $table)) return 0;
    try {
        $stmt = $pdo->prepare("SELECT COUNT(*) FROM {$table} WHERE {$where}");
        $stmt->execute($params);
        return (int)$stmt->fetchColumn();
    } catch (Throwable) {
        return 0;
    }
}

function flow_admin_rows(PDO $pdo, string $sql, array $params = []): array
{
    try {
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
    } catch (Throwable $e) {
        error_log('flow admin query failed: ' . $e->getMessage());
        return [];
    }
}

function flow_admin_json(array $payload, int $status = 200): never
{
    if (function_exists('chat_json')) {
        chat_json($payload, $status);
    }
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

