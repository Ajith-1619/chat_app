<?php

use Illuminate\Foundation\Application;
use Illuminate\Http\Request;

define('LARAVEL_START', microtime(true));

// Shared hosting/FTP deployments often skip empty Laravel storage folders.
// Ensure Blade/cache/session directories exist before Laravel compiles views.
foreach ([
    __DIR__ . '/../storage/framework',
    __DIR__ . '/../storage/framework/views',
    __DIR__ . '/../storage/framework/cache',
    __DIR__ . '/../storage/framework/sessions',
    __DIR__ . '/../storage/logs',
    __DIR__ . '/../bootstrap/cache',
] as $directory) {
    if (!is_dir($directory)) {
        @mkdir($directory, 0777, true);
    }
}

$logFile = __DIR__ . '/../storage/logs/laravel.log';
if (!is_file($logFile)) {
    @touch($logFile);
}
@chmod(__DIR__ . '/../storage/logs', 0777);
@chmod($logFile, 0666);

// Determine if the application is in maintenance mode...
if (file_exists($maintenance = __DIR__.'/../storage/framework/maintenance.php')) {
    require $maintenance;
}

// Register the Composer autoloader...
require __DIR__.'/../vendor/autoload.php';

// Bootstrap Laravel and handle the request...
/** @var Application $app */
$app = require_once __DIR__.'/../bootstrap/app.php';

$app->handleRequest(Request::capture());
