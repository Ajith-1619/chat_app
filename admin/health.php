<?php
declare(strict_types=1);
header('Content-Type: text/plain; charset=utf-8');
function npath(string $path): string { return str_replace('\\', '/', $path); }
$roots = array_values(array_unique(array_filter([
    __DIR__, dirname(__DIR__), dirname(__DIR__, 2), dirname(__DIR__, 3),
    (string)($_SERVER['DOCUMENT_ROOT'] ?? ''), dirname((string)($_SERVER['DOCUMENT_ROOT'] ?? '')),
    '/home', '/var/www', '/var/www/html', '/usr/local/apache/htdocs', '/opt/lampp/htdocs', 'C:/xampp/htdocs',
], static fn(string $root): bool => $root !== '' && is_dir($root))));
$candidates = [];
$envPath = trim((string)(getenv('FLOW_ADMIN_CHAT_BOOTSTRAP') ?: ''));
if ($envPath !== '') $candidates[] = $envPath;
foreach ($roots as $root) {
    $root = rtrim(npath($root), '/');
    foreach (['chat/bootstrap.php','router_login/chat/bootstrap.php','public_html/chat/bootstrap.php','public_html/router_login/chat/bootstrap.php','www/chat/bootstrap.php','www/router_login/chat/bootstrap.php'] as $suffix) {
        $candidates[] = $root . '/' . $suffix;
    }
}
foreach ([$_SERVER['DOCUMENT_ROOT'] ?? '', dirname(__DIR__), dirname(__DIR__, 2)] as $root) {
    $root = (string)$root;
    if ($root === '' || !is_dir($root)) continue;
    foreach (@glob(rtrim(npath($root), '/') . '/*/chat/bootstrap.php') ?: [] as $match) $candidates[] = $match;
    foreach (@glob(rtrim(npath($root), '/') . '/*/*/chat/bootstrap.php') ?: [] as $match) $candidates[] = $match;
}
$candidates = array_values(array_unique(array_map('npath', $candidates)));
echo "Flow Admin Health\n";
echo "PHP: " . PHP_VERSION . "\n";
echo "Admin dir: " . __DIR__ . "\n";
echo "Document root: " . (string)($_SERVER['DOCUMENT_ROOT'] ?? '') . "\n";
echo "Env FLOW_ADMIN_CHAT_BOOTSTRAP: " . ($envPath ?: '-') . "\n\n";
$found = 0;
foreach ($candidates as $candidate) {
    $ok = is_file($candidate);
    if ($ok) $found++;
    echo ($ok ? 'FOUND  ' : 'MISS   ') . $candidate . "\n";
}
echo "\nFound count: {$found}\n";
