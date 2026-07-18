<?php
declare(strict_types=1);

const FLOW_ADMIN_ALLOWED_EMP_IDS_DEFAULT = [302, 116];
const FLOW_ADMIN_CHAT_DOMAIN_DEFAULT = 'chat.skylinkonline.net';
const FLOW_ADMIN_MUC_DOMAIN_DEFAULT = 'conference.chat.skylinkonline.net';
const FLOW_ADMIN_EJABBERD_API_DEFAULT = 'https://chat.skylinkonline.net:5443/api';

function flow_admin_load_config(): array
{
    static $config = null;
    if ($config !== null) return $config;

    $config = [
        'allowed_emp_ids' => FLOW_ADMIN_ALLOWED_EMP_IDS_DEFAULT,
        'chat_domain' => FLOW_ADMIN_CHAT_DOMAIN_DEFAULT,
        'muc_domain' => FLOW_ADMIN_MUC_DOMAIN_DEFAULT,
        'ejabberd_api_url' => FLOW_ADMIN_EJABBERD_API_DEFAULT,
        'ejabberd_admin_jid' => '',
        'ejabberd_admin_password' => '',
        'databases' => [
            'chat' => flow_admin_empty_db_config(),
            'task' => flow_admin_empty_db_config(),
            'employee' => flow_admin_empty_db_config(),
        ],
    ];

    $localConfigPath = __DIR__ . '/admin_config.php';
    if (!is_file($localConfigPath)) {
        return $config;
    }

    $local = require $localConfigPath;
    if (is_array($local)) {
        $config = flow_admin_array_replace_recursive($config, $local);
    }

    foreach (['task', 'employee'] as $name) {
        if (empty($config['databases'][$name]['dsn']) && empty($config['databases'][$name]['database'])) {
            $config['databases'][$name] = $config['databases']['chat'];
        }
    }

    return $config;
}

function flow_admin_empty_db_config(): array
{
    return [
        'dsn' => '',
        'host' => 'localhost',
        'port' => '3306',
        'database' => '',
        'username' => '',
        'password' => '',
        'charset' => 'utf8mb4',
    ];
}

function flow_admin_array_replace_recursive(array $base, array $override): array
{
    foreach ($override as $key => $value) {
        if (is_array($value) && isset($base[$key]) && is_array($base[$key])) {
            $base[$key] = flow_admin_array_replace_recursive($base[$key], $value);
        } else {
            $base[$key] = $value;
        }
    }
    return $base;
}

function flow_admin_cookie_path(): string
{
    $scriptDir = rtrim(str_replace('\\', '/', dirname((string)($_SERVER['SCRIPT_NAME'] ?? '/admin/index.php'))), '/');
    if ($scriptDir === '' || $scriptDir === '.') return '/';
    if (str_ends_with($scriptDir, '/public')) {
        $scriptDir = substr($scriptDir, 0, -7) ?: '/';
    }
    return rtrim($scriptDir, '/') . '/';
}
function flow_admin_laravel_session_available(): bool
{
    try {
        return function_exists('app') && app()->bound('session') && app('session')->isStarted();
    } catch (Throwable) {
        return false;
    }
}

function flow_admin_session_get(string $key, mixed $default = null): mixed
{
    if (flow_admin_laravel_session_available()) return session()->get($key, $default);
    flow_admin_start();
    return $_SESSION[$key] ?? $default;
}

function flow_admin_session_set(string $key, mixed $value): void
{
    if (flow_admin_laravel_session_available()) {
        session()->put($key, $value);
        session()->save();
        $_SESSION[$key] = $value;
        return;
    }
    flow_admin_start();
    $_SESSION[$key] = $value;
}

function flow_admin_session_forget(array $keys): void
{
    if (flow_admin_laravel_session_available()) {
        session()->forget($keys);
        session()->save();
    }
    foreach ($keys as $key) unset($_SESSION[$key]);
}

function flow_admin_session_flush(): void
{
    if (flow_admin_laravel_session_available()) {
        session()->forget(['flow_admin_emp_id', 'flow_admin_login_at', 'flow_admin_csrf', 'flow_admin_failed_attempts', 'flow_admin_blocked_until']);
        session()->save();
    }
    $_SESSION = [];
}
function flow_admin_config(string $key, mixed $default = null): mixed
{
    $config = flow_admin_load_config();
    foreach (explode('.', $key) as $part) {
        if (!is_array($config) || !array_key_exists($part, $config)) return $default;
        $config = $config[$part];
    }
    return $config;
}

function flow_admin_config_file_exists(): bool
{
    return is_file(__DIR__ . '/admin_config.php');
}

function flow_admin_start(): void
{
    if (session_status() === PHP_SESSION_ACTIVE) return;
    $secure = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') || (($_SERVER['SERVER_PORT'] ?? '') === '443');
    session_set_cookie_params([
        'lifetime' => 0,
        'path' => flow_admin_cookie_path(),
        'domain' => '',
        'secure' => $secure,
        'httponly' => true,
        'samesite' => 'Lax',
    ]);
    session_name('flow_master_admin');
    session_start();
}

function flow_admin_is_allowed(int $empId): bool
{
    $allowed = array_map('intval', (array)flow_admin_config('allowed_emp_ids', FLOW_ADMIN_ALLOWED_EMP_IDS_DEFAULT));
    return in_array($empId, $allowed, true);
}

function flow_admin_jid(int $empId): string
{
    return $empId . '@' . (string)flow_admin_config('chat_domain', FLOW_ADMIN_CHAT_DOMAIN_DEFAULT);
}

function flow_admin_current_emp_id(): int
{
    $empId = (int)flow_admin_session_get('flow_admin_emp_id', 0);
    return flow_admin_is_allowed($empId) ? $empId : 0;
}

function flow_admin_require(): array
{
    $empId = flow_admin_current_emp_id();
    if ($empId <= 0) {
        if (str_contains((string)($_SERVER['HTTP_ACCEPT'] ?? ''), 'application/json')) {
            flow_admin_json(['status' => false, 'error' => 'Admin login required.'], 401);
        }
        header('Location: index.php');
        exit;
    }
    return flow_admin_user_payload($empId);
}

function flow_admin_check_login_rate_limit(): void
{
    $now = time();
    $blockedUntil = (int)flow_admin_session_get('flow_admin_blocked_until', 0);
    if ($blockedUntil > $now) {
        throw new RuntimeException('Too many failed attempts. Try again in ' . ($blockedUntil - $now) . ' seconds.');
    }
}

function flow_admin_record_login_failure(): void
{
    $attempts = (int)flow_admin_session_get('flow_admin_failed_attempts', 0) + 1;
    flow_admin_session_set('flow_admin_failed_attempts', $attempts);
    if ($attempts >= 5) flow_admin_session_set('flow_admin_blocked_until', time() + 300);
}

function flow_admin_clear_login_failures(): void
{
    flow_admin_session_forget(['flow_admin_failed_attempts', 'flow_admin_blocked_until']);
}

function flow_admin_login(string $username, string $password): array
{
    flow_admin_check_login_rate_limit();
    $username = strtolower(trim($username));
    $domainPattern = '/@' . preg_quote((string)flow_admin_config('chat_domain', FLOW_ADMIN_CHAT_DOMAIN_DEFAULT), '/') . '$/i';
    $username = preg_replace($domainPattern, '', $username) ?: '';
    $username = preg_replace('/^sky-/i', '', $username) ?: '';
    if ($username === '' || $password === '' || !ctype_digit($username)) {
        flow_admin_record_login_failure();
        throw new RuntimeException('Employee ID and password are required.');
    }
    $empId = (int)$username;
    if (!flow_admin_is_allowed($empId)) {
        flow_admin_record_login_failure();
        throw new RuntimeException('Master admin access is restricted.');
    }
    $authErrors = [];
    try {
        $authenticated = flow_admin_ejabberd_authenticate((string)$empId, $password);
        if (!$authenticated) $authErrors[] = 'Ejabberd rejected the password';
    } catch (Throwable $e) {
        $authenticated = false;
        $authErrors[] = $e->getMessage();
    }
    if (!$authenticated) {
        try {
            $authenticated = flow_admin_database_authenticate($empId, $password);
            if (!$authenticated) $authErrors[] = 'chat database password did not match';
        } catch (Throwable $e) {
            $authErrors[] = 'chat database auth failed: ' . $e->getMessage();
        }
    }
    if (!$authenticated) {
        flow_admin_record_login_failure();
        throw new RuntimeException('Admin login could not verify your same chat username/password because service configuration is incomplete or rejected it. Details: ' . implode('; ', array_unique($authErrors)) . '.');
    }

    if (!flow_admin_laravel_session_available()) {
        flow_admin_start();
        session_regenerate_id(true);
    }
    flow_admin_session_set('flow_admin_emp_id', $empId);
    flow_admin_session_set('flow_admin_login_at', date('Y-m-d H:i:s'));
    flow_admin_clear_login_failures();
    flow_admin_db();
    flow_admin_audit($empId, 'login', 'admin_session', (string)$empId, ['result' => 'success']);
    return flow_admin_user_payload($empId);
}

function flow_admin_logout(): void
{
    $empId = (int)flow_admin_session_get('flow_admin_emp_id', 0);
    if ($empId > 0) flow_admin_audit($empId, 'logout', 'admin_session', (string)$empId, []);
    flow_admin_session_flush();
    if (!flow_admin_laravel_session_available() && ini_get('session.use_cookies')) {
        $params = session_get_cookie_params();
        setcookie(session_name(), '', time() - 42000, $params['path'], $params['domain'], (bool)$params['secure'], (bool)$params['httponly']);
        session_destroy();
    }
}

function flow_admin_csrf_token(): string
{
    $token = (string)flow_admin_session_get('flow_admin_csrf', '');
    if ($token === '') {
        $token = bin2hex(random_bytes(32));
        flow_admin_session_set('flow_admin_csrf', $token);
    }
    return $token;
}

function flow_admin_require_csrf(): void
{
    $token = (string)($_POST['csrf'] ?? $_SERVER['HTTP_X_FLOW_ADMIN_CSRF'] ?? '');
    if ($token === '' || !hash_equals(flow_admin_csrf_token(), $token)) {
        flow_admin_json(['status' => false, 'error' => 'Security token expired. Refresh admin and try again.'], 403);
    }
}

function flow_admin_db_name(string $name): PDO
{
    static $connections = [];
    if (isset($connections[$name])) return $connections[$name];
    $db = (array)flow_admin_config('databases.' . $name, []);
    $dsn = trim((string)($db['dsn'] ?? ''));
    if ($dsn === '') {
        $database = trim((string)($db['database'] ?? ''));
        $username = trim((string)($db['username'] ?? ''));
        $password = (string)($db['password'] ?? '');
        if ($database === '' || flow_admin_looks_placeholder($database) || $username === '' || flow_admin_looks_placeholder($username) || flow_admin_looks_placeholder($password)) {
            throw new RuntimeException("Admin {$name} database config still has CHANGE_ME/empty values. Fill admin/admin_config.php inside the admin folder with real DB name, username and password.");
        }
        $host = (string)($db['host'] ?? 'localhost');
        $port = (string)($db['port'] ?? '3306');
        $charset = (string)($db['charset'] ?? 'utf8mb4');
        $dsn = "mysql:host={$host};port={$port};dbname={$database};charset={$charset}";
    }
    $username = trim((string)($db['username'] ?? ''));
    $password = (string)($db['password'] ?? '');
    if ($username === '' || flow_admin_looks_placeholder($username) || flow_admin_looks_placeholder($password)) {
        throw new RuntimeException("Admin {$name} database username/password still has CHANGE_ME/empty values in admin/admin_config.php.");
    }
    $pdo = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);
    if ($name === 'chat') flow_admin_ensure_admin_schema($pdo);
    return $connections[$name] = $pdo;
}

function flow_admin_db(): PDO { return flow_admin_db_name('chat'); }
function flow_admin_task_db(): PDO { return flow_admin_db_name('task'); }
function flow_admin_employee_db(): PDO { return flow_admin_db_name('employee'); }

function flow_admin_ensure_admin_schema(PDO $pdo): void
{
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS flow_admin_audit_log (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            admin_emp_id INT NOT NULL,
            action VARCHAR(80) NOT NULL,
            target_type VARCHAR(80) NOT NULL,
            target_id VARCHAR(120) NOT NULL,
            payload_json TEXT NULL,
            ip_address VARCHAR(64) NULL,
            user_agent VARCHAR(255) NULL,
            status VARCHAR(24) NOT NULL DEFAULT \'success\',
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_flow_admin_audit_admin_created (admin_emp_id, created_at),
            INDEX idx_flow_admin_audit_action_created (action, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
}

function flow_admin_ejabberd_request(string $command, array $payload = []): mixed
{
    if (!function_exists('curl_init')) throw new RuntimeException('PHP cURL extension is not enabled.');
    $url = rtrim((string)flow_admin_config('ejabberd_api_url', FLOW_ADMIN_EJABBERD_API_DEFAULT), '/') . '/' . rawurlencode($command);
    $ch = curl_init($url);
    if ($ch === false) throw new RuntimeException('Unable to initialize ejabberd API request.');
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_HTTPHEADER => ['Content-Type: application/json', 'Accept: application/json'],
        CURLOPT_POSTFIELDS => json_encode($payload, JSON_UNESCAPED_SLASHES),
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 6,
        CURLOPT_TIMEOUT => 12,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
    ]);
    $adminJid = (string)flow_admin_config('ejabberd_admin_jid', '');
    $adminPassword = (string)flow_admin_config('ejabberd_admin_password', '');
    if ($adminJid !== '' && $adminPassword !== '') {
        curl_setopt($ch, CURLOPT_USERPWD, $adminJid . ':' . $adminPassword);
        curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
    }
    $body = curl_exec($ch);
    $error = curl_error($ch);
    $status = (int)curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    curl_close($ch);
    if ($body === false || $error !== '') throw new RuntimeException('ejabberd API connection failed: ' . $error);
    $decoded = json_decode((string)$body, true);
    if ($status < 200 || $status >= 300) {
        $message = is_array($decoded) ? json_encode($decoded, JSON_UNESCAPED_SLASHES) : (string)$body;
        throw new RuntimeException('ejabberd API ' . $command . ' failed with HTTP ' . $status . ': ' . $message);
    }
    return $decoded ?? $body;
}

function flow_admin_looks_placeholder(string $value): bool
{
    $value = trim($value);
    return $value === '' || stripos($value, 'CHANGE_ME') !== false || stripos($value, 'your_') !== false;
}

function flow_admin_database_authenticate(int $empId, string $password): bool
{
    $pdo = flow_admin_db();
    if (!flow_admin_table_exists($pdo, 'xmpp_users')) return false;
    $stmt = $pdo->prepare('SELECT xmpp_password FROM xmpp_users WHERE emp_id = :emp_id OR jid = :jid LIMIT 1');
    $stmt->execute([':emp_id' => $empId, ':jid' => flow_admin_jid($empId)]);
    $stored = (string)($stmt->fetchColumn() ?: '');
    if ($stored === '') return false;
    if (hash_equals($stored, $password)) return true;
    if (str_starts_with($stored, '$2y$') || str_starts_with($stored, '$argon2')) {
        return password_verify($password, $stored);
    }
    return false;
}
function flow_admin_ejabberd_authenticate(string $user, string $password): bool
{
    $adminJid = (string)flow_admin_config('ejabberd_admin_jid', '');
    $adminPassword = (string)flow_admin_config('ejabberd_admin_password', '');
    if ($adminJid === '' || $adminPassword === '') {
        throw new RuntimeException('Admin Ejabberd credentials are missing. Fill admin/admin_config.php inside the admin folder. No outside config files are used.');
    }
    try {
        $response = flow_admin_ejabberd_request('check_password', [
            'user' => $user,
            'host' => (string)flow_admin_config('chat_domain', FLOW_ADMIN_CHAT_DOMAIN_DEFAULT),
            'password' => $password,
        ]);
        if (is_bool($response)) return $response;
        if (is_numeric($response)) return (int)$response === 0;
        if (is_string($response)) return in_array(strtolower(trim($response)), ['0', '1', 'true', 'ok', 'success'], true);
        if (is_array($response)) {
            if (isset($response['result'])) return in_array(strtolower((string)$response['result']), ['0', '1', 'true', 'ok', 'success'], true);
            return empty($response['error']) && !in_array(strtolower((string)($response['status'] ?? '')), ['error', 'failed', 'false'], true);
        }
    } catch (Throwable $e) {
        error_log('flow admin ejabberd auth failed: ' . $e->getMessage());
    }
    return false;
}

function flow_admin_user_payload(int $empId): array
{
    $payload = ['emp_id' => (string)$empId, 'name' => 'Admin ' . $empId, 'designation' => 'Master Admin', 'jid' => flow_admin_jid($empId)];
    try {
        $pdo = flow_admin_employee_db();
        foreach (['employee', 'tbl_employee', 'employees'] as $table) {
            if (!flow_admin_table_exists($pdo, $table)) continue;
            $stmt = $pdo->prepare("SELECT * FROM {$table} WHERE emp_id = :emp_id OR id = :emp_id LIMIT 1");
            $stmt->execute([':emp_id' => $empId]);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            if ($row) {
                $payload['name'] = (string)($row['name'] ?? $row['emp_name'] ?? $row['employee_name'] ?? $payload['name']);
                $payload['designation'] = (string)($row['designation'] ?? $row['desig'] ?? $row['role'] ?? $payload['designation']);
                break;
            }
        }
    } catch (Throwable $e) {
        error_log('flow admin user payload failed: ' . $e->getMessage());
    }
    return $payload;
}

function flow_admin_table_exists(PDO $pdo, string $table): bool
{
    try {
        $plain = trim($table, '`');
        if (str_contains($plain, '.')) {
            [$schema, $plain] = array_map(static fn($part) => trim($part, '`'), explode('.', $plain, 2));
        } else {
            $schema = (string)$pdo->query('SELECT DATABASE()')->fetchColumn();
        }
        $stmt = $pdo->prepare('SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = :schema_name AND TABLE_NAME = :table_name');
        $stmt->execute([':schema_name' => $schema, ':table_name' => $plain]);
        return (int)$stmt->fetchColumn() > 0;
    } catch (Throwable) {
        return false;
    }
}

function flow_admin_column_exists(PDO $pdo, string $table, string $column): bool
{
    try {
        $stmt = $pdo->prepare('SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :table_name AND COLUMN_NAME = :column_name');
        $stmt->execute([':table_name' => $table, ':column_name' => $column]);
        return (int)$stmt->fetchColumn() > 0;
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
    } catch (Throwable $e) {
        error_log('flow admin count failed: ' . $e->getMessage());
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

function flow_admin_audit(int $adminEmpId, string $action, string $targetType, string $targetId, array $payload, string $status = 'success'): void
{
    try {
        $pdo = flow_admin_db();
        $stmt = $pdo->prepare('INSERT INTO flow_admin_audit_log (admin_emp_id, action, target_type, target_id, payload_json, ip_address, user_agent, status) VALUES (:admin_emp_id, :action, :target_type, :target_id, :payload_json, :ip_address, :user_agent, :status)');
        $stmt->execute([
            ':admin_emp_id' => $adminEmpId,
            ':action' => $action,
            ':target_type' => $targetType,
            ':target_id' => $targetId,
            ':payload_json' => json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            ':ip_address' => substr((string)($_SERVER['REMOTE_ADDR'] ?? ''), 0, 64),
            ':user_agent' => substr((string)($_SERVER['HTTP_USER_AGENT'] ?? ''), 0, 255),
            ':status' => $status,
        ]);
    } catch (Throwable $e) {
        error_log('flow admin audit failed: ' . $e->getMessage());
    }
}

function flow_admin_json(array $payload, int $status = 200): never
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    header('X-Content-Type-Options: nosniff');
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function flow_admin_html(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES, 'UTF-8');
}
