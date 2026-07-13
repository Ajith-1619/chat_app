<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$empId = (int)$session['emp_id'];
$pdo = chat_db();
chat_ensure_schema($pdo);

function release_notes_platform(): string
{
    $platform = strtolower(trim((string)($_GET['platform'] ?? 'android')));
    return in_array($platform, ['android', 'windows', 'linux'], true) ? $platform : 'android';
}

function release_notes_row(PDO $pdo, int $empId, string $platform, string $version): ?array
{
    $stmt = $pdo->prepare(
        'SELECT rn.*,
                CASE WHEN rv.emp_id IS NULL THEN 0 ELSE 1 END AS viewed
         FROM xmpp_release_notes rn
         LEFT JOIN xmpp_release_note_views rv
           ON rv.release_note_id = rn.id AND rv.emp_id = :emp_id
         WHERE rn.platform = :platform AND rn.version = :version
         LIMIT 1'
    );
    $stmt->execute([
        ':emp_id' => $empId,
        ':platform' => $platform,
        ':version' => $version,
    ]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC) ?: null;
    if ($row) return $row;

    $fallback = $pdo->prepare(
        'SELECT *
         FROM xmpp_release_builds
         WHERE platform = :platform AND version = :version
         ORDER BY created_at DESC, id DESC LIMIT 1'
    );
    $fallback->execute([':platform' => $platform, ':version' => $version]);
    $build = $fallback->fetch(PDO::FETCH_ASSOC);
    if (!$build && $platform === 'android' && $version === '1.4.0') {
        $insert = $pdo->prepare(
            'INSERT INTO xmpp_release_notes
             (platform, version, release_date, new_features, improvements, bug_fixes,
              security_updates, implementation_details, created_by_emp_id)
             VALUES
             (:platform, :version, :release_date, :features, :improvements, :bug_fixes,
              :security, :implementation, :actor)
             ON DUPLICATE KEY UPDATE
               new_features = VALUES(new_features),
               improvements = VALUES(improvements),
               bug_fixes = VALUES(bug_fixes),
               security_updates = VALUES(security_updates),
               implementation_details = VALUES(implementation_details)'
        );
        $insert->execute([
            ':platform' => $platform,
            ':version' => $version,
            ':release_date' => '2026-06-24',
            ':features' => "What's New under Settings, location visibility controls, message location metadata, global search jump-to-message, and improved chat folder/channel archive placement.",
            ':improvements' => 'Message metadata now carries device, app version, latitude and longitude. Formatting controls appear only when text is selected.',
            ':bug_fixes' => 'Fixed empty release notes fallback, global search result navigation, and repeated SQL placeholders in discovery search.',
            ':security' => 'Location details are hidden by default and visible only to employees enabled through Location visibility. Initial visibility is enabled for 116 and 302 only.',
            ':implementation' => 'Release notes are centralized in xmpp_release_notes and viewed state is tracked in xmpp_release_note_views. This fallback row is created only when the build record is not yet registered.',
            ':actor' => 302,
        ]);
        return release_notes_row($pdo, $empId, $platform, $version);
    }
    if (!$build) return null;

    $insert = $pdo->prepare(
        'INSERT INTO xmpp_release_notes
         (platform, version, release_date, new_features, improvements, bug_fixes,
          security_updates, implementation_details, created_by_emp_id)
         VALUES
         (:platform, :version, DATE(:release_date), :features, :improvements, :bug_fixes,
          :security, :implementation, :actor)
         ON DUPLICATE KEY UPDATE
           improvements = VALUES(improvements),
           implementation_details = VALUES(implementation_details)'
    );
    $notes = trim((string)($build['notes'] ?? ''));
    $insert->execute([
        ':platform' => $platform,
        ':version' => $version,
        ':release_date' => (string)($build['approved_at'] ?? $build['created_at'] ?? date('Y-m-d')),
        ':features' => $notes !== '' ? $notes : 'No new features were documented for this build.',
        ':improvements' => 'Release governance metadata is available for this version.',
        ':bug_fixes' => 'No bug fixes were documented for this build.',
        ':security' => 'No security updates were documented for this build.',
        ':implementation' => 'Release note generated from the registered build record.',
        ':actor' => (int)($build['uploaded_by_emp_id'] ?? 0) ?: null,
    ]);
    return release_notes_row($pdo, $empId, $platform, $version);
}

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $platform = release_notes_platform();
    $version = trim((string)($_GET['version'] ?? ''));
    if ($version === '') {
        $latest = $pdo->prepare(
            'SELECT version FROM xmpp_release_notes
             WHERE platform = :platform ORDER BY release_date DESC, id DESC LIMIT 1'
        );
        $latest->execute([':platform' => $platform]);
        $version = (string)($latest->fetchColumn() ?: '');
    }
    if ($version === '') {
        chat_json(['status' => true, 'note' => null]);
    }
    $row = release_notes_row($pdo, $empId, $platform, $version);
    chat_json(['status' => true, 'note' => $row]);
}

$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
$action = strtolower(trim((string)($input['action'] ?? 'mark_viewed')));
if ($action !== 'mark_viewed') {
    chat_json(['status' => false, 'error' => 'Invalid release note action'], 422);
}
$noteId = max(0, (int)($input['release_note_id'] ?? 0));
if ($noteId <= 0) chat_json(['status' => false, 'error' => 'Release note is required'], 422);
$stmt = $pdo->prepare(
    'INSERT INTO xmpp_release_note_views (release_note_id, emp_id)
     VALUES (:id, :emp_id)
     ON DUPLICATE KEY UPDATE viewed_at = CURRENT_TIMESTAMP'
);
$stmt->execute([':id' => $noteId, ':emp_id' => $empId]);
chat_json(['status' => true, 'viewed' => true]);
