<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$empId = (int)$session['emp_id'];
$pdo = chat_db();
chat_ensure_schema($pdo);

function release_history(PDO $pdo, int $releaseId, int $actor, string $action, ?string $from, ?string $to, string $notes = ''): void
{
    $stmt = $pdo->prepare(
        'INSERT INTO xmpp_release_history (release_id, actor_emp_id, action, from_status, to_status, notes)
         VALUES (:release_id, :actor, :action, :from_status, :to_status, :notes)'
    );
    $stmt->execute([
        ':release_id' => $releaseId,
        ':actor' => $actor,
        ':action' => $action,
        ':from_status' => $from,
        ':to_status' => $to,
        ':notes' => $notes,
    ]);
}

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $stmt = $pdo->query(
        'SELECT * FROM xmpp_release_builds
         ORDER BY created_at DESC, id DESC LIMIT 100'
    );
    $historyStmt = $pdo->query(
        'SELECT * FROM xmpp_release_history ORDER BY created_at DESC LIMIT 250'
    );
    chat_json([
        'status' => true,
        'can_approve_production' => $empId === SKYCHAT_RELEASE_APPROVER_EMP_ID,
        'builds' => $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [],
        'history' => $historyStmt->fetchAll(PDO::FETCH_ASSOC) ?: [],
        'stages' => ['Development', 'Testing', 'Production'],
        'actions' => [
            'reject_build',
            'deploy_to_testers',
            'deploy_to_pilot_users',
            'approve_for_production',
            'rollback_release',
        ],
    ]);
}

$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);
$action = strtolower(trim((string)($input['action'] ?? 'register')));

try {
    if ($action === 'register') {
        $platform = strtolower(trim((string)($input['platform'] ?? 'android')));
        $version = trim((string)($input['version'] ?? ''));
        $buildNumber = max(0, (int)($input['build_number'] ?? 0));
        $url = trim((string)($input['url'] ?? ''));
        $notes = trim((string)($input['notes'] ?? ''));
        if (!in_array($platform, ['android', 'windows', 'linux'], true) || $version === '') {
            chat_json(['status' => false, 'error' => 'Valid platform and version are required'], 422);
        }
        $stmt = $pdo->prepare(
            'INSERT INTO xmpp_release_builds
             (platform, version, build_number, stage, status, apk_url, notes, uploaded_by_emp_id)
             VALUES (:platform, :version, :build_number, \'Development\', \'Draft\', :url, :notes, :actor)
             ON DUPLICATE KEY UPDATE notes = VALUES(notes), apk_url = VALUES(apk_url)'
        );
        $stmt->execute([
            ':platform' => $platform,
            ':version' => $version,
            ':build_number' => $buildNumber,
            ':url' => $url !== '' ? $url : null,
            ':notes' => $notes,
            ':actor' => $empId,
        ]);
        $releaseId = (int)($pdo->lastInsertId() ?: 0);
        if ($releaseId === 0) {
            $lookup = $pdo->prepare(
                'SELECT id FROM xmpp_release_builds
                 WHERE platform = :platform AND version = :version AND build_number = :build_number LIMIT 1'
            );
            $lookup->execute([':platform' => $platform, ':version' => $version, ':build_number' => $buildNumber]);
            $releaseId = (int)$lookup->fetchColumn();
        }
        release_history($pdo, $releaseId, $empId, 'register', null, 'Draft', $notes);
        $noteStmt = $pdo->prepare(
            'INSERT INTO xmpp_release_notes
             (platform, version, release_date, new_features, improvements, bug_fixes,
              security_updates, implementation_details, created_by_emp_id)
             VALUES
             (:platform, :version, CURDATE(), :features, :improvements, :bug_fixes,
              :security, :implementation, :actor)
             ON DUPLICATE KEY UPDATE
               new_features = VALUES(new_features),
               improvements = VALUES(improvements),
               implementation_details = VALUES(implementation_details),
               updated_at = CURRENT_TIMESTAMP'
        );
        $noteStmt->execute([
            ':platform' => $platform,
            ':version' => $version,
            ':features' => $notes !== '' ? $notes : 'No feature notes were entered.',
            ':improvements' => 'Registered through the release management workflow.',
            ':bug_fixes' => 'No bug-fix notes were entered.',
            ':security' => 'No security-update notes were entered.',
            ':implementation' => 'Build registered as Draft; distribution requires approved release governance.',
            ':actor' => $empId,
        ]);
        chat_json(['status' => true, 'release_id' => $releaseId, 'release_status' => 'Draft']);
    }

    $releaseId = max(0, (int)($input['release_id'] ?? 0));
    $notes = trim((string)($input['notes'] ?? ''));
    if ($releaseId <= 0) chat_json(['status' => false, 'error' => 'Release ID is required'], 422);
    $current = $pdo->prepare('SELECT * FROM xmpp_release_builds WHERE id = :id LIMIT 1');
    $current->execute([':id' => $releaseId]);
    $release = $current->fetch(PDO::FETCH_ASSOC);
    if (!$release) chat_json(['status' => false, 'error' => 'Release not found'], 404);
    $from = (string)$release['status'];

    $updates = [];
    if ($action === 'reject_build') {
        $updates = ['stage' => 'Development', 'status' => 'Rejected', 'rollout_percent' => 0, 'force_update' => 0];
    } elseif ($action === 'deploy_to_testers') {
        $updates = ['stage' => 'Testing', 'status' => 'Testing', 'rollout_percent' => 0, 'force_update' => 0, 'deployed_at' => date('Y-m-d H:i:s')];
    } elseif ($action === 'deploy_to_pilot_users') {
        $percent = min(100, max(1, (int)($input['rollout_percent'] ?? 10)));
        $updates = ['stage' => 'Testing', 'status' => 'Pilot', 'rollout_percent' => $percent, 'force_update' => 0, 'deployed_at' => date('Y-m-d H:i:s')];
    } elseif ($action === 'approve_for_production') {
        if ($empId !== SKYCHAT_RELEASE_APPROVER_EMP_ID) {
            chat_json(['status' => false, 'error' => 'Only Ajith (302) may approve Production releases'], 403);
        }
        $force = !empty($input['force_update']) ? 1 : 0;
        $updates = [
            'stage' => 'Production',
            'status' => 'ProductionApproved',
            'rollout_percent' => 100,
            'force_update' => $force,
            'approved_by_emp_id' => $empId,
            'approved_at' => date('Y-m-d H:i:s'),
            'deployed_at' => date('Y-m-d H:i:s'),
        ];
        $demote = $pdo->prepare(
            'UPDATE xmpp_release_builds
             SET status = \'Superseded\', force_update = 0
             WHERE platform = :platform AND id <> :id AND stage = \'Production\' AND status = \'ProductionApproved\''
        );
        $demote->execute([':platform' => $release['platform'], ':id' => $releaseId]);
    } elseif ($action === 'rollback_release') {
        if ($empId !== SKYCHAT_RELEASE_APPROVER_EMP_ID) {
            chat_json(['status' => false, 'error' => 'Only Ajith (302) may rollback Production releases'], 403);
        }
        $updates = ['status' => 'RolledBack', 'force_update' => 0, 'rollout_percent' => 0];
    } else {
        chat_json(['status' => false, 'error' => 'Unknown release action'], 422);
    }

    $set = [];
    $params = [':id' => $releaseId];
    foreach ($updates as $key => $value) {
        $set[] = "{$key} = :{$key}";
        $params[":{$key}"] = $value;
    }
    $stmt = $pdo->prepare('UPDATE xmpp_release_builds SET ' . implode(', ', $set) . ' WHERE id = :id');
    $stmt->execute($params);
    release_history($pdo, $releaseId, $empId, $action, $from, (string)($updates['status'] ?? $from), $notes);
    chat_json(['status' => true, 'release_id' => $releaseId, 'release_status' => $updates['status'] ?? $from]);
} catch (Throwable $e) {
    error_log('chat/releases failed: ' . $e->getMessage());
    chat_json(['status' => false, 'error' => 'Unable to update release workflow'], 500);
}
