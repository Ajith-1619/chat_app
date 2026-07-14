<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';

try {
    chat_process_push_queue(50);
} catch (Throwable $e) {
    error_log('push_worker failed: ' . $e->getMessage());
    if (PHP_SAPI === 'cli') {
        fwrite(STDERR, 'push_worker failed: ' . $e->getMessage() . PHP_EOL);
    }
}
