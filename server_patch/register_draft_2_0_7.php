<?php
declare(strict_types=1);
require_once __DIR__ . '/chat/bootstrap.php';

$pdo = chat_db();
chat_ensure_schema($pdo);

$notes = implode("\n", [
    'v2.0.7 multi-platform draft build generated on 2026-07-28.',
    'Includes Horizon map zoom/pan improvements, reporting-scope access, and address timeline updates present in the workspace build.',
    'Includes Flow chat /help command guide and current conversation, metadata, storage, activity, API, and admin updates present in the workspace build.',
    'Artifacts include Web ZIP, Android release APK, and Windows installer EXE.',
    'Draft only: stage Development, status Draft, rollout 0%, force update disabled.',
    'Production rollout requires Employee ID 302 approval from Release Management.',
]);

$builds = [
    ['android', '2.0.7', 30, 'https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-v2.0.7.apk'],
    ['windows', '2.0.7', 30, 'https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-Setup-v2.0.7.exe'],
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
           force_update = 0,
           uploaded_by_emp_id = 302"
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
    if ($id > 0) {
        $hist = $pdo->prepare(
            "INSERT INTO xmpp_release_history
             (release_id, actor_emp_id, action, from_status, to_status, notes)
             VALUES (:id, 302, 'register', NULL, 'Draft', :notes)"
        );
        $hist->execute([
            ':id' => $id,
            ':notes' => 'Auto-registered v2.0.7 ' . $platform . ' draft after artifact upload',
        ]);
    }
    echo $platform . ' draft release_id=' . $id . PHP_EOL;
}
