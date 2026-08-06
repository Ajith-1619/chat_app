<?php
declare(strict_types=1);

/*
 * Apache deployments may execute this file directly instead of rewriting
 * /api. Dispatch through Laravel so the encrypted Laravel session cookie is
 * available to the legacy API. Including api.php directly would start a
 * different native PHP session and lose the admin login.
 */
require_once __DIR__ . '/../vendor/autoload.php';

use Illuminate\Http\Request;

$app = require __DIR__ . '/../bootstrap/app.php';
$query = (string) ($_SERVER['QUERY_STRING'] ?? '');
$bridgeUri = '/api' . ($query !== '' ? '?' . $query : '');
$request = Request::create(
    $bridgeUri,
    (string) ($_SERVER['REQUEST_METHOD'] ?? 'GET'),
    $_POST,
    $_COOKIE,
    $_FILES,
    $_SERVER,
    file_get_contents('php://input')
);

$app->handleRequest($request);