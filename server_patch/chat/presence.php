<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

$session = chat_require_user();
$jid = strtolower(trim((string)($_GET['jid'] ?? '')));
if (!chat_is_user_jid($jid) && !chat_is_room_jid($jid)) {
    chat_json(['status' => false, 'error' => 'Valid JID is required'], 422);
}

try {
    $pdo = chat_db();
    $online = false;
    $lastSeen = null;
    if (!chat_is_room_jid($jid) && preg_match('/^(\d+)@/i', $jid, $match)) {
        $presenceStmt = $pdo->prepare(
            'SELECT last_seen_at,
                    last_seen_at >= DATE_SUB(NOW(), INTERVAL 45 SECOND) AS is_online
             FROM xmpp_user_presence WHERE emp_id = :emp_id LIMIT 1'
        );
        $presenceStmt->execute([':emp_id' => (int)$match[1]]);
        $presenceRow = $presenceStmt->fetch(PDO::FETCH_ASSOC) ?: [];
        $online = (int)($presenceRow['is_online'] ?? 0) === 1;
        $presenceValue = trim((string)($presenceRow['last_seen_at'] ?? ''));
        if ($presenceValue !== '') {
            $lastSeen = new DateTimeImmutable(
                $presenceValue,
                new DateTimeZone('Asia/Kolkata')
            );
        }
    }
    if (!$online && !chat_is_room_jid($jid) && isset($match[1])) {
        $fallback = $pdo->prepare(
            'SELECT MAX(seen_at) FROM (
                SELECT MAX(last_seen_at) AS seen_at
                FROM xmpp_user_presence WHERE emp_id = :presence_emp
                UNION ALL
                SELECT MAX(created_at) AS seen_at
                FROM xmpp_messages
                WHERE from_jid = :message_jid
            ) presence_fallback'
        );
        $fallback->execute([
            ':presence_emp' => (int)$match[1],
            ':message_jid' => $jid,
        ]);
        $fallbackValue = trim((string)($fallback->fetchColumn() ?: ''));
        if ($fallbackValue !== '') {
            $lastSeen = new DateTimeImmutable(
                $fallbackValue,
                new DateTimeZone('Asia/Kolkata')
            );
        }
    }
    $mobileActive = false;
    $launchpadActive = false;
    $locationAvailable = false;
    if (isset($match[1])) {
        $presenceEmp = (int)$match[1];
        try {
            $stmt = $pdo->prepare(
                'SELECT EXISTS(SELECT 1 FROM xmpp_app_sessions
                 WHERE emp_id = :emp_id
                   AND platform IN (\'android\', \'ios\')
                   AND revoked_at IS NULL
                   AND last_seen_at >= DATE_SUB(NOW(), INTERVAL 10 MINUTE))'
            );
            $stmt->execute([':emp_id' => $presenceEmp]);
            $mobileActive = (bool)$stmt->fetchColumn();
        } catch (Throwable $e) {
            error_log('chat/presence mobile status skipped: ' . $e->getMessage());
        }
        try {
            $stmt = $pdo->prepare(
                'SELECT EXISTS(SELECT 1 FROM xmpp_user_presence
                 WHERE emp_id = :emp_id
                   AND last_seen_at >= DATE_SUB(NOW(), INTERVAL 10 MINUTE))'
            );
            $stmt->execute([':emp_id' => $presenceEmp]);
            $launchpadActive = (bool)$stmt->fetchColumn();
        } catch (Throwable $e) {
            error_log('chat/presence launchpad status skipped: ' . $e->getMessage());
        }
        try {
            $locationPdo = getTaskDB();
            $stmt = $locationPdo->prepare(
                'SELECT EXISTS(SELECT 1 FROM locations_test
                 WHERE user_id = :emp_id
                   AND date_created >= DATE_SUB(NOW(), INTERVAL 30 MINUTE))'
            );
            $stmt->execute([':emp_id' => $presenceEmp]);
            $locationAvailable = (bool)$stmt->fetchColumn();
        } catch (Throwable $e) {
            error_log('chat/presence location status skipped: ' . $e->getMessage());
        }
    }
    chat_json([
        'status' => true,
        'online' => $online,
        'last_seen' => $lastSeen?->format(DATE_ATOM),
        'messenger_connected' => $online,
        'mobile_active' => $mobileActive,
        'launchpad_active' => $launchpadActive,
        'location_available' => $locationAvailable,
    ]);
} catch (Throwable $e) {
    error_log('chat/presence failed: ' . $e->getMessage());
    chat_json(['status' => true, 'online' => false, 'last_seen' => null]);
}
