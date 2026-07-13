<?php
declare(strict_types=1);

function worker_fail(Throwable $e): void
{
    error_log('notification_worker failed: ' . $e->getMessage());
    if (PHP_SAPI === 'cli') {
        fwrite(STDERR, 'notification_worker failed: ' . $e->getMessage() . "\n");
        exit(1);
    }
    http_response_code(500);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'status' => false,
        'error' => 'Notification worker failed.',
        'detail' => $e->getMessage(),
    ], JSON_UNESCAPED_SLASHES);
    exit;
}

try {
    $projectRoot = dirname(__DIR__);
    if (!is_file($projectRoot . '/config.php') || !is_file($projectRoot . '/db.php')) {
        throw new RuntimeException('Deployment path is wrong: chat/notification_worker.php must be inside router_login/chat so ../config.php and ../db.php exist.');
    }

    require_once __DIR__ . '/bootstrap.php';
    require_once __DIR__ . '/notification_helpers.php';

    $scheduledHelper = __DIR__ . '/scheduled_message_helpers.php';
    $scheduledAvailable = is_file($scheduledHelper);
    if ($scheduledAvailable) {
        require_once $scheduledHelper;
    } else {
        error_log('notification_worker: scheduled_message_helpers.php missing; scheduled-message queue skipped.');
    }

    require_once __DIR__ . '/wakeup_helpers.php';

    if (PHP_SAPI !== 'cli') {
        $fixedToken = 'skylink_worker_20260702_Ajith_9xK4mP7qR2vN8sL5';
        $expected = trim((string)(getenv('SKYLINK_NOTIFICATION_WORKER_TOKEN') ?: $fixedToken));
        $provided = trim((string)($_SERVER['HTTP_X_SKYLINK_WORKER_TOKEN'] ?? $_GET['token'] ?? ''));
        if ($expected === '' || !hash_equals($expected, $provided)) {
            chat_json(['status' => false, 'error' => 'Worker authorization required.'], 403);
        }
    }

    $pdo = chat_db();
    chat_ensure_schema($pdo);
    notification_materialize_due($pdo);
    if ($scheduledAvailable && function_exists('scheduled_message_process')) {
        scheduled_message_process($pdo);
    }
    $wakeupCount = wakeup_process_due($pdo);

    if (PHP_SAPI === 'cli') {
        fwrite(STDOUT, "Notification and wake-up queues processed. Wake-up sent: {$wakeupCount}. Scheduled helper: " . ($scheduledAvailable ? 'ok' : 'missing') . "\n");
        exit(0);
    }
    chat_json([
        'status' => true,
        'wakeup_sent' => $wakeupCount,
        'scheduled_helper' => $scheduledAvailable ? 'ok' : 'missing',
    ]);
} catch (Throwable $e) {
    worker_fail($e);
}