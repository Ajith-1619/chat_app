<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    echo "Not found\n";
    exit(1);
}

$options = getopt('', ['name:', 'key:', 'owner::', 'scopes::']);
$name = trim((string)($options['name'] ?? ''));
$key = trim((string)($options['key'] ?? ''));
$owner = (int)($options['owner'] ?? 302);
$scopeText = trim((string)($options['scopes'] ?? '*'));

if ($name === '' || $key === '') {
    fwrite(STDERR, "Usage: php create_client.php --name=ExternalPortal --key=<api-key> --owner=302 --scopes=chat:read,chat:write,tasks:read,tasks:write\n");
    exit(2);
}

$scopes = array_values(array_filter(array_map('trim', explode(',', $scopeText))));
if (!$scopes) $scopes = ['*'];

$pdo = flow_api_chat_db();
$stmt = $pdo->prepare('INSERT INTO flow_api_clients (client_name, api_key_hash, owner_emp_id, scopes_json, status) VALUES (:name, :hash, :owner, :scopes, 1) ON DUPLICATE KEY UPDATE client_name = VALUES(client_name), owner_emp_id = VALUES(owner_emp_id), scopes_json = VALUES(scopes_json), status = 1');
$stmt->execute([
    ':name' => $name,
    ':hash' => hash('sha256', $key),
    ':owner' => $owner,
    ':scopes' => json_encode($scopes),
]);

echo "Flow API client saved: {$name}\n";
echo "Owner employee: {$owner}\n";
echo "Scopes: " . implode(', ', $scopes) . "\n";
echo "API key is stored as SHA-256 hash only. Keep the original key securely.\n";
