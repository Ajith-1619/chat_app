<?php
declare(strict_types=1);
require_once __DIR__ . '/chat/bootstrap.php';

$pdo = chat_db();
chat_ensure_schema($pdo);

$notes = implode("\n", [
    'v1.4.3 draft build.',
    'Adds MyHub task assignee/follower multi-select, deadline date-time picker, fixes MyHub directory/tasks/leave endpoints, and reduces send-message lag with faster GPS fallback plus reverse-geocode caching.',
    'This build is Draft only. Force update is disabled. Production deployment requires Ajith (Employee ID 302) approval.',
]);

$builds = [
    ['android', '1.4.3', 22, 'https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-v1.4.3.apk'],
    ['windows', '1.4.3', 22, 'https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-Windows-v1.4.3.zip'],
    ['web', '1.4.3', 22, 'https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-Web-v1.4.3.zip'],
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
         'Auto-registered v1.4.3 draft after artifact upload')"
    );
    $hist->execute([':id' => $id]);
    echo $platform . ' draft release_id=' . $id . PHP_EOL;
}
