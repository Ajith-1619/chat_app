<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

function external_user_request_token(string $name): string
{
    $token = preg_replace('/[^A-Za-z0-9_]+/', '', str_replace(' ', '_', trim($name))) ?: 'external';
    return '@' . mb_substr($token, 0, 80);
}

function ensure_external_user_request_tables(PDO $pdo): void
{
    chat_ensure_schema($pdo);
    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS external_user_requests (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            group_id INT NOT NULL,
            requested_by_emp_id INT NOT NULL,
            display_name VARCHAR(160) NOT NULL,
            email VARCHAR(190) NULL,
            phone VARCHAR(40) NULL,
            whatsapp_number VARCHAR(40) NULL,
            telegram_username VARCHAR(120) NULL,
            delivery_channels VARCHAR(160) NOT NULL DEFAULT \'\',
            mention_token VARCHAR(180) NOT NULL DEFAULT \'\',
            reason TEXT NULL,
            status VARCHAR(24) NOT NULL DEFAULT \'pending\',
            reviewed_by_emp_id INT NULL,
            reviewed_at DATETIME NULL,
            review_note TEXT NULL,
            external_contact_id INT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_external_user_requests_status (status, created_at),
            INDEX idx_external_user_requests_group (group_id, status),
            INDEX idx_external_user_requests_requested_by (requested_by_emp_id, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );
    chat_ensure_column($pdo, 'external_user_requests', 'delivery_channels', 'VARCHAR(160) NOT NULL DEFAULT \'\'');
    chat_ensure_column($pdo, 'external_user_requests', 'mention_token', 'VARCHAR(180) NOT NULL DEFAULT \'\'');
    chat_ensure_column($pdo, 'external_user_requests', 'reason', 'TEXT NULL');
    chat_ensure_column($pdo, 'external_user_requests', 'review_note', 'TEXT NULL');
    chat_ensure_column($pdo, 'external_user_requests', 'external_contact_id', 'INT NULL');
}

$session = chat_require_user();
$input = json_decode(file_get_contents('php://input') ?: '{}', true);
if (!is_array($input)) chat_json(['status' => false, 'error' => 'Invalid JSON'], 422);

$groupId = (int)($input['group_id'] ?? 0);
$name = mb_substr(trim((string)($input['display_name'] ?? '')), 0, 160);
$email = mb_substr(trim((string)($input['email'] ?? '')), 0, 190);
$phone = mb_substr(trim((string)($input['phone'] ?? '')), 0, 40);
$whatsapp = mb_substr(trim((string)($input['whatsapp_number'] ?? '')), 0, 40);
$telegram = mb_substr(trim((string)($input['telegram_username'] ?? '')), 0, 120);
$reason = mb_substr(trim((string)($input['reason'] ?? '')), 0, 1000);
$channels = array_values(array_unique(array_filter(array_map(
    static fn($value): string => strtolower(trim((string)$value)),
    is_array($input['delivery_channels'] ?? null) ? $input['delivery_channels'] : explode(',', (string)($input['delivery_channels'] ?? ''))
), static fn(string $value): bool => in_array($value, ['email', 'whatsapp', 'telegram', 'sms'], true))));

if ($groupId <= 0 || $name === '' || !$channels) {
    chat_json(['status' => false, 'error' => 'Group, external user name and at least one delivery channel are required.'], 422);
}
foreach ($channels as $channel) {
    if ($channel === 'email' && $email === '') chat_json(['status' => false, 'error' => 'Email is required for email delivery.'], 422);
    if ($channel === 'sms' && $phone === '') chat_json(['status' => false, 'error' => 'Phone is required for SMS delivery.'], 422);
    if ($channel === 'whatsapp' && $whatsapp === '' && $phone === '') chat_json(['status' => false, 'error' => 'WhatsApp number or phone is required.'], 422);
    if ($channel === 'telegram' && $telegram === '') chat_json(['status' => false, 'error' => 'Telegram username/chat id is required.'], 422);
}

try {
    $pdo = chat_db();
    ensure_external_user_request_tables($pdo);
    $member = $pdo->prepare(
        'SELECT g.id, g.room_jid, g.room_name, gm.role
         FROM xmpp_groups g
         INNER JOIN xmpp_group_members gm ON gm.group_id = g.id
         WHERE g.id = :group_id AND gm.emp_id = :emp_id
         LIMIT 1'
    );
    $member->execute([':group_id' => $groupId, ':emp_id' => (int)$session['emp_id']]);
    $group = $member->fetch(PDO::FETCH_ASSOC) ?: [];
    if (!$group) chat_json(['status' => false, 'error' => 'You are not a member of this group/channel.'], 403);
    if (!in_array((string)$group['role'], ['owner', 'admin'], true)) {
        chat_json(['status' => false, 'error' => 'Only owner/admin can request external users.'], 403);
    }
    $token = external_user_request_token($name);
    $stmt = $pdo->prepare(
        'INSERT INTO external_user_requests (group_id, requested_by_emp_id, display_name, email, phone, whatsapp_number, telegram_username, delivery_channels, mention_token, reason, status)
         VALUES (:group_id, :requested_by, :display_name, :email, :phone, :whatsapp, :telegram, :channels, :token, :reason, \'pending\')'
    );
    $stmt->execute([
        ':group_id' => $groupId,
        ':requested_by' => (int)$session['emp_id'],
        ':display_name' => $name,
        ':email' => $email !== '' ? $email : null,
        ':phone' => $phone !== '' ? $phone : null,
        ':whatsapp' => $whatsapp !== '' ? $whatsapp : null,
        ':telegram' => $telegram !== '' ? $telegram : null,
        ':channels' => implode(',', $channels),
        ':token' => $token,
        ':reason' => $reason !== '' ? $reason : null,
    ]);
    chat_json(['status' => true, 'request_id' => (int)$pdo->lastInsertId(), 'mention_token' => $token]);
} catch (Throwable $e) {
    error_log('chat/external_user_request failed: ' . $e->getMessage());
    chat_json(['status' => false, 'error' => 'Unable to submit external user request.'], 500);
}