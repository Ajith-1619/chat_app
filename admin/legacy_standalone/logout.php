<?php
declare(strict_types=1);
require_once __DIR__ . '/_bootstrap.php';
require_once __DIR__ . '/app/Controllers/AuthController.php';

(new AuthController())->logout();
