<?php
declare(strict_types=1);
require_once __DIR__ . '/chat/bootstrap.php';

$pdo = chat_db();
chat_ensure_schema($pdo);

$notes = implode("\n", [
    'v2.0.0 Android draft build.',
    'Includes recent Flow chat fixes: text send stability, task creation persistence, member mentions, and current/live location map-card rendering.',
    'This build is Draft only. Force update is disabled. Production deployment requires Ajith (Employee ID 302) approval.',
]);

$builds = [
    ['android', '2.0.0', 23, 'https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-v2.0.0.apk'],
];

foreach ($builds as $build) {
    [$platform, $version, $buildNumber, $url] = $build;
    $stmt = $pdo->prepare(
        "INSERT INTO xmpp_release_builds
         (platform, version, build_number, stage, status, apk_url, notes,
          rollout_percent, force_update, uploaded_by_emp_id)
         VALUES
         (:platform, :version, :build_number, 'Development', 'Draft', :url,
          :notes, 0, 0, 302)
         ON DUPLICATE KEY UPDATE
           stage = 'Development',
           status = 'Draft',
           apk_url = VALUES(apk_url),
           notes = VALUES(notes),
           rollout_percent = 0,
           force_update = 0"
    );
    $stmt->execute([
        ':platform' => $platform,
        ':version' => $version,
        ':build_number' => $buildNumber,
        ':url' => $url,
        ':notes' => $notes,
    ]);
    $id = (int)($pdo->lastInsertId() ?: 0);
    if ($id === 0) {
        $lookup = $pdo->prepare(
            'SELECT id FROM xmpp_release_builds
             WHERE platform = :platform AND version = :version AND build_number = :build_number LIMIT 1'
        );
        $lookup->execute([
            ':platform' => $platform,
            ':version' => $version,
            ':build_number' => $buildNumber,
        ]);
        $id = (int)$lookup->fetchColumn();
    }
    $hist = $pdo->prepare(
        "INSERT INTO xmpp_release_history
         (release_id, actor_emp_id, action, from_status, to_status, notes)
         VALUES (:id, 302, 'register', NULL, 'Draft',
         'Auto-registered v2.0.0 Android draft after APK upload')"
    );
    $hist->execute([':id' => $id]);
    echo $platform . ' draft release_id=' . $id . PHP_EOL;
}