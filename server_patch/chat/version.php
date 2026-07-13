<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

header('Content-Type: application/json; charset=utf-8');

$defaults = [
    'android' => [
        'latest' => '1.3.5',
        'minimum' => '1.3.5',
        'url' => 'https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-latest.apk',
        'force_update' => false,
        'release_status' => 'ProductionApproved',
    ],
    'windows' => [
        'latest' => '1.3.5',
        'minimum' => '1.1.0',
        'url' => 'https://dns.watchtower247.in/router_login/downloads/Skylink-Chat-Windows-Setup-latest.exe',
        'force_update' => false,
        'release_status' => 'ProductionApproved',
    ],
    'linux' => [
        'latest' => '1.3.5',
        'minimum' => '1.3.5',
        'url' => 'https://dns.watchtower247.in/router_login/downloads/skylink-chat_1.3.5_amd64.deb',
        'force_update' => false,
        'release_status' => 'ProductionApproved',
    ],
];

try {
    $pdo = chat_db();
    chat_ensure_schema($pdo);
    foreach (array_keys($defaults) as $platform) {
        $stmt = $pdo->prepare(
            'SELECT *
             FROM xmpp_release_builds
             WHERE platform = :platform
               AND stage = \'Production\'
               AND status = \'ProductionApproved\'
               AND approved_by_emp_id = :approver
             ORDER BY approved_at DESC, id DESC LIMIT 1'
        );
        $stmt->execute([
            ':platform' => $platform,
            ':approver' => SKYCHAT_RELEASE_APPROVER_EMP_ID,
        ]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$row) continue;
        $defaults[$platform]['latest'] = (string)$row['version'];
        $defaults[$platform]['minimum'] = !empty($row['force_update'])
            ? (string)$row['version']
            : $defaults[$platform]['minimum'];
        if (!empty($row['apk_url'])) $defaults[$platform]['url'] = (string)$row['apk_url'];
        $defaults[$platform]['force_update'] = !empty($row['force_update']);
        $defaults[$platform]['release_status'] = (string)$row['status'];
        $defaults[$platform]['release_id'] = (int)$row['id'];
    }
} catch (Throwable $e) {
    error_log('chat/version dynamic lookup failed: ' . $e->getMessage());
}

echo json_encode([
    'status' => true,
    'release_governance' => [
        'production_approver_emp_id' => SKYCHAT_RELEASE_APPROVER_EMP_ID,
        'drafts_visible_to_users' => false,
        'force_update_requires_production_approval' => true,
    ],
    'android' => $defaults['android'],
    'windows' => $defaults['windows'],
    'linux' => $defaults['linux'],
], JSON_UNESCAPED_SLASHES);
