<?php
declare(strict_types=1);
require_once __DIR__ . '/chat/bootstrap.php';

$pdo = chat_db();
chat_ensure_schema($pdo);

$notes = implode("
", [
    'v2.0.4 multi-platform draft build generated on 2026-07-16.',
    'Includes latest chat UI fixes: message selection scroll lock, desktop profile panel stays closed until profile click, compact WhatsApp/Telegram-style message bubble width.',
    'Includes restricted attachment handling, Saved Messages forward target, saved-message paste/drop improvements, checklist/poll UI updates, and recent task/location fixes present in the workspace build.',
    'Windows artifact is an installer EXE. Web artifact is a downloadable ZIP draft. Android artifact is release APK.',
    'Draft only: stage Development, status Draft, rollout 0%, force update disabled.',
    'Production rollout requires Employee ID 302 approval from Release Management.',
]);

$builds = [
    ['android', '2.0.4', 27, 'https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-v2.0.4.apk'],
    ['windows', '2.0.4', 27, 'https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-Setup-v2.0.4.exe'],
    ['web', '2.0.4', 27, 'https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-Web-v2.0.4.zip'],
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
             VALUES (:id, 302, 'register', NULL, 'Draft',
             'Auto-registered v2.0.4 multi-platform draft after artifact upload')"
        );
        $hist->execute([':id' => $id]);
    }
    echo $platform . ' draft release_id=' . $id . PHP_EOL;
}
