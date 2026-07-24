<?php
declare(strict_types=1);

function flow_api_ext_ensure(PDO $pdo): void
{
    $pdo->exec("CREATE TABLE IF NOT EXISTS flow_api_saved_messages (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        emp_id INT NOT NULL,
        body TEXT NULL,
        file_url VARCHAR(500) NULL,
        file_name VARCHAR(255) NULL,
        file_type VARCHAR(120) NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_flow_saved_emp (emp_id, id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    $pdo->exec("CREATE TABLE IF NOT EXISTS flow_api_ai_keys (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        title VARCHAR(160) NOT NULL,
        ai_name VARCHAR(80) NOT NULL,
        model VARCHAR(120) NULL,
        endpoint VARCHAR(500) NULL,
        api_key_hash VARCHAR(128) NOT NULL,
        api_key_mask VARCHAR(80) NOT NULL,
        other_details TEXT NULL,
        status TINYINT NOT NULL DEFAULT 1,
        created_by_emp_id INT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    $pdo->exec("CREATE TABLE IF NOT EXISTS flow_api_ai_room_access (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        group_id INT NOT NULL,
        ai_key_id BIGINT NOT NULL,
        enabled TINYINT NOT NULL DEFAULT 1,
        daily_tokens INT NOT NULL DEFAULT 0,
        daily_searches INT NOT NULL DEFAULT 0,
        created_by_emp_id INT NULL,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uq_ai_room (group_id, ai_key_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    $pdo->exec("CREATE TABLE IF NOT EXISTS flow_api_external_user_requests (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        group_id INT NOT NULL,
        display_name VARCHAR(160) NOT NULL,
        email VARCHAR(190) NULL,
        phone VARCHAR(40) NULL,
        whatsapp_number VARCHAR(40) NULL,
        telegram_username VARCHAR(120) NULL,
        delivery_channels VARCHAR(160) NOT NULL DEFAULT '',
        status VARCHAR(30) NOT NULL DEFAULT 'pending',
        requested_by_emp_id INT NULL,
        approved_by_emp_id INT NULL,
        approved_at DATETIME NULL,
        external_contact_id INT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_ext_req_status (status, created_at),
        INDEX idx_ext_req_group (group_id, status)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    $pdo->exec("CREATE TABLE IF NOT EXISTS flow_api_storage_limits (
        emp_id INT PRIMARY KEY,
        limit_bytes BIGINT NOT NULL DEFAULT 2147483648,
        updated_by_emp_id INT NULL,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    $pdo->exec("CREATE TABLE IF NOT EXISTS flow_api_attendance_events (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        emp_id INT NOT NULL,
        event_type VARCHAR(20) NOT NULL,
        latitude DECIMAL(10,7) NULL,
        longitude DECIMAL(10,7) NULL,
        address VARCHAR(500) NULL,
        source VARCHAR(80) NOT NULL DEFAULT 'external_api',
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_att_emp_created (emp_id, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
}

function flow_api_ext_save_upload(array $input): array
{
    $fileName = basename((string)($input['file_name'] ?? ('file-' . time())));
    $fileType = (string)($input['file_type'] ?? 'application/octet-stream');
    $base64 = (string)($input['file_base64'] ?? '');
    if ($base64 === '') flow_api_error('file_base64 is required for API uploads.', 422, 'VALIDATION_ERROR');
    if (str_contains($base64, ',')) $base64 = substr($base64, strpos($base64, ',') + 1);
    $bytes = base64_decode($base64, true);
    if ($bytes === false) flow_api_error('Invalid file_base64.', 422, 'VALIDATION_ERROR');
    $root = dirname(__DIR__, 2);
    $relDir = 'uploads/api/' . date('Y/m');
    $absDir = $root . '/' . $relDir;
    if (!is_dir($absDir)) mkdir($absDir, 0775, true);
    $safe = bin2hex(random_bytes(8)) . '-' . preg_replace('/[^A-Za-z0-9._-]/', '_', $fileName);
    file_put_contents($absDir . '/' . $safe, $bytes);
    return ['file_url' => $relDir . '/' . $safe, 'file_name' => $fileName, 'file_type' => $fileType, 'file_size' => strlen($bytes)];
}

function flow_api_ext_chat(array $auth, array $segments): never
{
    $pdo = flow_api_chat_db(); flow_api_ext_ensure($pdo);
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'GET' && ($segments[0] ?? '') === 'search') {
        $q = trim((string)($_GET['q'] ?? ''));
        if ($q === '') flow_api_error('q is required.', 422, 'VALIDATION_ERROR');
        $stmt = $pdo->prepare('SELECT id, from_jid, to_jid, body, file_name, message_type, created_at FROM xmpp_messages WHERE deleted_at IS NULL AND (body LIKE :q OR file_name LIKE :q) ORDER BY id DESC LIMIT 100');
        $stmt->execute([':q' => '%' . $q . '%']);
        flow_api_success($auth, 'chat:read', ['results' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }
    if ($method === 'GET' && isset($segments[0]) && ctype_digit($segments[0]) && ($segments[1] ?? '') === 'info') {
        $stmt = $pdo->prepare('SELECT * FROM xmpp_messages WHERE id = :id LIMIT 1');
        $stmt->execute([':id' => (int)$segments[0]]);
        $msg = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$msg) flow_api_error('Message not found.', 404, 'NOT_FOUND');
        flow_api_success($auth, 'chat:read', ['message' => $msg]);
    }
    if ($method === 'POST' && isset($segments[0]) && ctype_digit($segments[0])) {
        $id = (int)$segments[0]; $action = $segments[1] ?? '';
        $input = flow_api_input();
        if ($action === 'edit') {
            $body = trim((string)($input['body'] ?? ''));
            if ($body === '') flow_api_error('body is required.', 422, 'VALIDATION_ERROR');
            $pdo->prepare('UPDATE xmpp_messages SET body = :body, edited_at = NOW() WHERE id = :id')->execute([':body' => $body, ':id' => $id]);
            flow_api_success($auth, 'chat:write', ['message_id' => $id, 'edited' => true]);
        }
        if ($action === 'delete') {
            $pdo->prepare('UPDATE xmpp_messages SET deleted_at = NOW() WHERE id = :id')->execute([':id' => $id]);
            flow_api_success($auth, 'chat:write', ['message_id' => $id, 'deleted' => true]);
        }
        if ($action === 'pin') {
            $msg = $pdo->prepare('SELECT to_jid FROM xmpp_messages WHERE id = :id LIMIT 1'); $msg->execute([':id' => $id]); $conversation = (string)($msg->fetchColumn() ?: ''); if ($conversation === '') flow_api_error('Message not found.', 404, 'NOT_FOUND'); $pdo->prepare('INSERT INTO xmpp_message_pins (message_id, conversation_jid, pinned_by_emp_id) VALUES (:id, :jid, :emp) ON DUPLICATE KEY UPDATE pinned_at = CURRENT_TIMESTAMP')->execute([':id' => $id, ':jid' => $conversation, ':emp' => (int)$auth['actor_emp_id']]);
            flow_api_success($auth, 'chat:write', ['message_id' => $id, 'pinned' => true]);
        }
        if ($action === 'bookmark' || $action === 'star') {
            $pdo->prepare('INSERT INTO xmpp_message_stars (message_id, emp_id) VALUES (:id, :emp) ON DUPLICATE KEY UPDATE created_at = CURRENT_TIMESTAMP')->execute([':id' => $id, ':emp' => (int)$auth['actor_emp_id']]);
            flow_api_success($auth, 'chat:write', ['message_id' => $id, 'bookmarked' => true]);
        }
        if ($action === 'reaction') {
            $emoji = (string)($input['emoji'] ?? '??');
            $pdo->prepare('INSERT INTO xmpp_message_reactions (message_id, emp_id, reaction) VALUES (:id, :emp, :emoji) ON DUPLICATE KEY UPDATE reaction = VALUES(reaction), created_at = CURRENT_TIMESTAMP')->execute([':id' => $id, ':emp' => (int)$auth['actor_emp_id'], ':emoji' => $emoji]);
            flow_api_success($auth, 'chat:write', ['message_id' => $id, 'emoji' => $emoji]);
        }
        if ($action === 'forward') {
            $to = trim((string)($input['to_jid'] ?? ''));
            if ($to === '') flow_api_error('to_jid is required.', 422, 'VALIDATION_ERROR');
            $msg = $pdo->prepare('SELECT body, file_url, file_name, file_type, file_size FROM xmpp_messages WHERE id = :id LIMIT 1');
            $msg->execute([':id' => $id]); $row = $msg->fetch(PDO::FETCH_ASSOC);
            if (!$row) flow_api_error('Message not found.', 404, 'NOT_FOUND');
            $from = flow_api_jid_for_emp($pdo, (int)$auth['actor_emp_id']);
            $ins = $pdo->prepare('INSERT INTO xmpp_messages (from_jid, to_jid, body, file_url, file_name, file_type, file_size, message_type, forwarded_from_message_id, source_device, source_name, status) VALUES (:from_jid,:to_jid,:body,:file_url,:file_name,:file_type,:file_size,"chat",:forwarded,"api",:source,"sent")');
            $ins->execute([':from_jid'=>$from, ':to_jid'=>$to, ':body'=>$row['body'], ':file_url'=>$row['file_url'], ':file_name'=>$row['file_name'], ':file_type'=>$row['file_type'], ':file_size'=>(int)$row['file_size'], ':forwarded'=>$id, ':source'=>$auth['client_name']]);
            flow_api_success($auth, 'chat:write', ['message_id' => (int)$pdo->lastInsertId(), 'forwarded_from' => $id], 201);
        }
    }
    flow_api_handle_chat($auth, $segments);
}

function flow_api_ext_groups_channels(array $auth, array $segments, string $type): never
{
    $pdo = flow_api_chat_db(); flow_api_ext_ensure($pdo);
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if (isset($segments[0]) && ctype_digit($segments[0])) {
        $groupId = (int)$segments[0]; $sub = $segments[1] ?? '';
        if ($method === 'GET' && $sub === 'members') flow_api_success($auth, $type . 's:read', ['members' => flow_api_group_detail($groupId)['members']]);
        if ($method === 'POST' && $sub === 'members' && count($segments) === 2) {
            $input = flow_api_input(); $ids = array_values(array_unique(array_map('intval', $input['emp_ids'] ?? [$input['emp_id'] ?? 0])));
            $role = (string)($input['role'] ?? 'member');
            $ins = $pdo->prepare('INSERT INTO xmpp_group_members (group_id, emp_id, role, history_visible_from) VALUES (:gid,:emp,:role,:from) ON DUPLICATE KEY UPDATE role = VALUES(role)');
            foreach ($ids as $emp) if ($emp > 0) $ins->execute([':gid'=>$groupId, ':emp'=>$emp, ':role'=>$role, ':from'=>empty($input['show_old_messages']) ? date('Y-m-d H:i:s') : null]);
            flow_api_success($auth, $type . 's:write', ['group_id'=>$groupId, 'added_emp_ids'=>$ids], 201);
        }
        if ($method === 'DELETE' && $sub === 'members' && isset($segments[2])) {
            $pdo->prepare('DELETE FROM xmpp_group_members WHERE group_id = :gid AND emp_id = :emp')->execute([':gid'=>$groupId, ':emp'=>(int)$segments[2]]);
            flow_api_success($auth, $type . 's:write', ['group_id'=>$groupId, 'removed_emp_id'=>(int)$segments[2]]);
        }
        if ($method === 'POST' && $sub === 'members' && isset($segments[2]) && ($segments[3] ?? '') === 'promote') {
            $pdo->prepare('UPDATE xmpp_group_members SET role = "admin" WHERE group_id = :gid AND emp_id = :emp')->execute([':gid'=>$groupId, ':emp'=>(int)$segments[2]]);
            flow_api_success($auth, $type . 's:write', ['group_id'=>$groupId, 'admin_emp_id'=>(int)$segments[2]]);
        }
        if ($method === 'GET' && $sub === 'wakeup') {
            $stmt = $pdo->prepare('SELECT wakeup_enabled, wakeup_interval_minutes, wakeup_last_sent_at, DATE_ADD(COALESCE(wakeup_last_sent_at, NOW()), INTERVAL wakeup_interval_minutes MINUTE) AS next_wakeup_at FROM xmpp_groups WHERE id = :id LIMIT 1');
            $stmt->execute([':id'=>$groupId]); flow_api_success($auth, $type . 's:read', ['wakeup'=>$stmt->fetch(PDO::FETCH_ASSOC)]);
        }
        if (($method === 'POST' || $method === 'PATCH') && $sub === 'wakeup') {
            $input = flow_api_input();
            $pdo->prepare('UPDATE xmpp_groups SET wakeup_enabled = :enabled, wakeup_interval_minutes = :mins, wakeup_updated_by_emp_id = :emp, wakeup_updated_at = NOW() WHERE id = :id')->execute([':enabled'=>(int)($input['enabled'] ?? 0), ':mins'=>(int)($input['interval_minutes'] ?? 1440), ':emp'=>(int)$auth['actor_emp_id'], ':id'=>$groupId]);
            flow_api_success($auth, $type . 's:write', ['group_id'=>$groupId, 'wakeup_updated'=>true]);
        }
        if ($method === 'POST' && $sub === 'external-users') {
            $input = flow_api_input();
            $name = trim((string)($input['display_name'] ?? ''));
            if ($name === '') flow_api_error('display_name is required.', 422, 'VALIDATION_ERROR');
            $stmt = $pdo->prepare('INSERT INTO flow_api_external_user_requests (group_id, display_name, email, phone, whatsapp_number, telegram_username, delivery_channels, requested_by_emp_id) VALUES (:gid,:name,:email,:phone,:wa,:tg,:channels,:emp)');
            $stmt->execute([':gid'=>$groupId, ':name'=>$name, ':email'=>$input['email'] ?? null, ':phone'=>$input['phone'] ?? null, ':wa'=>$input['whatsapp_number'] ?? null, ':tg'=>$input['telegram_username'] ?? null, ':channels'=>implode(',', $input['delivery_channels'] ?? []), ':emp'=>(int)$auth['actor_emp_id']]);
            flow_api_success($auth, 'external-users:write', ['request_id'=>(int)$pdo->lastInsertId(), 'status'=>'pending'], 201);
        }
        if ($method === 'GET' && $sub === 'ai') {
            $stmt = $pdo->prepare('SELECT ra.*, k.title, k.ai_name, k.model, k.api_key_mask FROM flow_api_ai_room_access ra INNER JOIN flow_api_ai_keys k ON k.id = ra.ai_key_id WHERE ra.group_id = :gid ORDER BY ra.id DESC');
            $stmt->execute([':gid'=>$groupId]); flow_api_success($auth, 'ai:read', ['ai_access'=>$stmt->fetchAll(PDO::FETCH_ASSOC)]);
        }
        if ($method === 'POST' && $sub === 'ai') {
            $input = flow_api_input();
            $pdo->prepare('INSERT INTO flow_api_ai_room_access (group_id, ai_key_id, enabled, daily_tokens, daily_searches, created_by_emp_id) VALUES (:gid,:key,:enabled,:tokens,:searches,:emp) ON DUPLICATE KEY UPDATE enabled=VALUES(enabled), daily_tokens=VALUES(daily_tokens), daily_searches=VALUES(daily_searches)')->execute([':gid'=>$groupId, ':key'=>(int)$input['ai_key_id'], ':enabled'=>(int)($input['enabled'] ?? 1), ':tokens'=>(int)($input['daily_tokens'] ?? 0), ':searches'=>(int)($input['daily_searches'] ?? 0), ':emp'=>(int)$auth['actor_emp_id']]);
            flow_api_success($auth, 'ai:write', ['group_id'=>$groupId, 'ai_key_id'=>(int)$input['ai_key_id']]);
        }
        if ($method === 'DELETE') {
            $pdo->prepare('UPDATE xmpp_groups SET is_archived = 1, archived_at = NOW(), status = "Deleted" WHERE id = :id AND group_type = :type')->execute([':id'=>$groupId, ':type'=>$type]);
            flow_api_success($auth, $type . 's:write', ['id'=>$groupId, 'deleted'=>true]);
        }
    }
    flow_api_handle_groups_channels($auth, $segments, $type);
}

function flow_api_ext_files(array $auth, array $segments): never
{
    $pdo = flow_api_chat_db(); flow_api_ext_ensure($pdo);
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'POST') {
        $input = flow_api_input(); $to = trim((string)($input['to_jid'] ?? ''));
        if ($to === '') flow_api_error('to_jid is required.', 422, 'VALIDATION_ERROR');
        $file = flow_api_ext_save_upload($input); $from = flow_api_jid_for_emp($pdo, (int)$auth['actor_emp_id']);
        $stmt = $pdo->prepare('INSERT INTO xmpp_messages (from_jid,to_jid,body,file_url,file_name,file_type,file_size,file_restricted,message_type,source_device,source_name,status) VALUES (:from,:to,:body,:url,:name,:type,:size,:restricted,:message_type,"api",:source,"sent")');
        $stmt->execute([':from'=>$from, ':to'=>$to, ':body'=>(string)($input['caption'] ?? ''), ':url'=>$file['file_url'], ':name'=>$file['file_name'], ':type'=>$file['file_type'], ':size'=>$file['file_size'], ':restricted'=>(int)($input['restricted'] ?? 0), ':message_type'=>(string)($input['message_type'] ?? 'file'), ':source'=>$auth['client_name']]);
        flow_api_success($auth, 'files:write', ['message_id'=>(int)$pdo->lastInsertId(), 'file'=>$file], 201);
    }
    flow_api_handle_simple_table($auth, 'files:read', 'xmpp_messages', 'files');
}

function flow_api_ext_saved(array $auth, array $segments): never
{
    $pdo = flow_api_chat_db(); flow_api_ext_ensure($pdo); $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'POST') {
        $input = flow_api_input();
        $pdo->prepare('INSERT INTO flow_api_saved_messages (emp_id, body, file_url, file_name, file_type) VALUES (:emp,:body,:url,:name,:type)')->execute([':emp'=>(int)$auth['actor_emp_id'], ':body'=>(string)($input['body'] ?? ''), ':url'=>$input['file_url'] ?? null, ':name'=>$input['file_name'] ?? null, ':type'=>$input['file_type'] ?? null]);
        flow_api_success($auth, 'saved:write', ['saved_message_id'=>(int)$pdo->lastInsertId()], 201);
    }
    $stmt = $pdo->prepare('SELECT * FROM flow_api_saved_messages WHERE emp_id = :emp ORDER BY id DESC LIMIT 200');
    $stmt->execute([':emp'=>(int)$auth['actor_emp_id']]); flow_api_success($auth, 'saved:read', ['saved_messages'=>$stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function flow_api_ext_ai(array $auth, array $segments): never
{
    $pdo = flow_api_chat_db(); flow_api_ext_ensure($pdo); $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'POST') {
        $input = flow_api_input(); $key = (string)($input['api_key'] ?? '');
        if ($key === '') flow_api_error('api_key is required.', 422, 'VALIDATION_ERROR');
        $mask = substr($key, 0, 4) . str_repeat('*', max(4, strlen($key) - 8)) . substr($key, -4);
        $pdo->prepare('INSERT INTO flow_api_ai_keys (title, ai_name, model, endpoint, api_key_hash, api_key_mask, other_details, status, created_by_emp_id) VALUES (:title,:ai,:model,:endpoint,:hash,:mask,:details,:status,:emp)')->execute([':title'=>(string)($input['title'] ?? 'AI API'), ':ai'=>(string)($input['ai_name'] ?? 'custom'), ':model'=>$input['model'] ?? null, ':endpoint'=>$input['endpoint'] ?? null, ':hash'=>hash('sha256', $key), ':mask'=>$mask, ':details'=>(string)($input['other_details'] ?? ''), ':status'=>(int)($input['status'] ?? 1), ':emp'=>(int)$auth['actor_emp_id']]);
        flow_api_success($auth, 'ai:write', ['ai_key_id'=>(int)$pdo->lastInsertId()], 201);
    }
    $stmt = $pdo->query('SELECT id, title, ai_name, model, endpoint, api_key_mask, status, updated_at FROM flow_api_ai_keys ORDER BY id DESC');
    flow_api_success($auth, 'ai:read', ['ai_keys'=>$stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function flow_api_ext_external_users(array $auth, array $segments): never
{
    $pdo = flow_api_chat_db(); flow_api_ext_ensure($pdo); $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'POST' && isset($segments[0]) && ctype_digit($segments[0]) && ($segments[1] ?? '') === 'approve') {
        $id = (int)$segments[0]; $req = $pdo->prepare('SELECT * FROM flow_api_external_user_requests WHERE id = :id LIMIT 1'); $req->execute([':id'=>$id]); $r = $req->fetch(PDO::FETCH_ASSOC);
        if (!$r) flow_api_error('External request not found.', 404, 'NOT_FOUND');
        $pdo->prepare('INSERT INTO external_contacts (display_name,email,phone,whatsapp_number,telegram_username,status,created_by_emp_id,updated_by_emp_id) VALUES (:name,:email,:phone,:wa,:tg,1,:emp,:emp)')->execute([':name'=>$r['display_name'], ':email'=>$r['email'], ':phone'=>$r['phone'], ':wa'=>$r['whatsapp_number'], ':tg'=>$r['telegram_username'], ':emp'=>(int)$auth['actor_emp_id']]);
        $contactId = (int)$pdo->lastInsertId();
        $pdo->prepare('INSERT INTO xmpp_group_external_members (group_id, external_contact_id, delivery_channels, mention_token, status, added_by_emp_id) VALUES (:gid,:cid,:channels,:token,1,:emp) ON DUPLICATE KEY UPDATE status=1, removed_at=NULL')->execute([':gid'=>(int)$r['group_id'], ':cid'=>$contactId, ':channels'=>$r['delivery_channels'], ':token'=>'@' . preg_replace('/\s+/', '_', strtolower((string)$r['display_name'])), ':emp'=>(int)$auth['actor_emp_id']]);
        $pdo->prepare('UPDATE flow_api_external_user_requests SET status="approved", approved_by_emp_id=:emp, approved_at=NOW(), external_contact_id=:cid WHERE id=:id')->execute([':emp'=>(int)$auth['actor_emp_id'], ':cid'=>$contactId, ':id'=>$id]);
        flow_api_success($auth, 'external-users:write', ['request_id'=>$id, 'external_contact_id'=>$contactId, 'approved'=>true]);
    }
    $stmt = $pdo->query('SELECT * FROM flow_api_external_user_requests ORDER BY id DESC LIMIT 200');
    flow_api_success($auth, 'external-users:read', ['requests'=>$stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

function flow_api_ext_storage(array $auth, array $segments): never
{
    $pdo = flow_api_chat_db(); flow_api_ext_ensure($pdo); $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if (($method === 'POST' || $method === 'PATCH') && isset($segments[0]) && ctype_digit($segments[0])) {
        $input = flow_api_input(); $mb = (float)($input['limit_mb'] ?? 2048); $bytes = (int)round($mb * 1024 * 1024);
        $pdo->prepare('INSERT INTO flow_api_storage_limits (emp_id, limit_bytes, updated_by_emp_id) VALUES (:emp,:bytes,:actor) ON DUPLICATE KEY UPDATE limit_bytes=VALUES(limit_bytes), updated_by_emp_id=VALUES(updated_by_emp_id)')->execute([':emp'=>(int)$segments[0], ':bytes'=>$bytes, ':actor'=>(int)$auth['actor_emp_id']]);
        flow_api_success($auth, 'storage:write', ['emp_id'=>(int)$segments[0], 'limit_bytes'=>$bytes]);
    }
    $emp = (int)($_GET['emp_id'] ?? ($segments[0] ?? $auth['actor_emp_id']));
    $used = function_exists('chat_user_uploaded_storage_bytes') ? chat_user_uploaded_storage_bytes($pdo, $emp) : 0;
    $stmt = $pdo->prepare('SELECT limit_bytes, updated_at FROM flow_api_storage_limits WHERE emp_id = :emp LIMIT 1'); $stmt->execute([':emp'=>$emp]);
    $limit = $stmt->fetch(PDO::FETCH_ASSOC) ?: ['limit_bytes'=>2147483648, 'updated_at'=>null];
    flow_api_success($auth, 'storage:read', ['storage'=>['emp_id'=>$emp, 'used_bytes'=>$used, 'limit_bytes'=>(int)$limit['limit_bytes'], 'updated_at'=>$limit['updated_at']]]);
}

function flow_api_ext_location(array $auth, array $segments): never
{
    $pdo = flow_api_chat_db(); $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'POST') {
        $input = flow_api_input();
        chat_ensure_column($pdo, 'xmpp_location_tracking', 'latitude', 'DECIMAL(10,7) NULL AFTER stopped_at'); chat_ensure_column($pdo, 'xmpp_location_tracking', 'longitude', 'DECIMAL(10,7) NULL AFTER latitude'); chat_ensure_column($pdo, 'xmpp_location_tracking', 'address', 'VARCHAR(500) NULL AFTER longitude'); chat_ensure_column($pdo, 'xmpp_location_tracking', 'source', "VARCHAR(80) NOT NULL DEFAULT 'external_api' AFTER address"); $empId = (int)($input['emp_id'] ?? $auth['actor_emp_id']); $tokenHash = hash('sha256', (string)$empId . '-api'); $pdo->prepare('INSERT INTO xmpp_location_tracking (emp_id, token_hash, latitude, longitude, address, source, last_location_at) VALUES (:emp, :token_hash, :lat, :lng, :address, :source, NOW()) ON DUPLICATE KEY UPDATE latitude=VALUES(latitude), longitude=VALUES(longitude), address=VALUES(address), source=VALUES(source), last_location_at=NOW(), active=1')->execute([':emp'=>$empId, ':token_hash'=>$tokenHash, ':lat'=>$input['latitude'] ?? null, ':lng'=>$input['longitude'] ?? null, ':address'=>$input['address'] ?? null, ':source'=>(string)($input['source'] ?? 'external_api')]);
        flow_api_success($auth, 'location:write', ['location_id'=>(int)$pdo->lastInsertId()], 201);
    }
    flow_api_handle_simple_table($auth, 'location:read', 'xmpp_location_tracking', 'locations');
}

function flow_api_ext_attendance(array $auth, array $segments): never
{
    $pdo = flow_api_chat_db(); flow_api_ext_ensure($pdo); $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'POST') {
        $input = flow_api_input(); $event = (string)($input['event_type'] ?? $segments[0] ?? 'punch_in');
        $pdo->prepare('INSERT INTO flow_api_attendance_events (emp_id,event_type,latitude,longitude,address) VALUES (:emp,:event,:lat,:lng,:address)')->execute([':emp'=>(int)($input['emp_id'] ?? $auth['actor_emp_id']), ':event'=>$event, ':lat'=>$input['latitude'] ?? null, ':lng'=>$input['longitude'] ?? null, ':address'=>$input['address'] ?? null]);
        flow_api_success($auth, 'attendance:write', ['attendance_event_id'=>(int)$pdo->lastInsertId()], 201);
    }
    flow_api_handle_simple_table($auth, 'attendance:read', 'flow_api_attendance_events', 'attendance_events');
}

function flow_api_ext_releases(array $auth, array $segments): never
{
    $pdo = flow_api_chat_db(); $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'POST' && isset($segments[0]) && ctype_digit($segments[0]) && in_array(($segments[1] ?? ''), ['approve','rollback'], true)) {
        $action = $segments[1]; $to = $action === 'approve' ? 'ProductionApproved' : 'RolledBack';
        $pdo->prepare('UPDATE xmpp_release_builds SET status=:status, approved_by_emp_id=:emp, approved_at=NOW() WHERE id=:id')->execute([':status'=>$to, ':emp'=>(int)$auth['actor_emp_id'], ':id'=>(int)$segments[0]]);
        $pdo->prepare('INSERT INTO xmpp_release_history (release_id, actor_emp_id, action, to_status, notes) VALUES (:id,:emp,:action,:status,:notes)')->execute([':id'=>(int)$segments[0], ':emp'=>(int)$auth['actor_emp_id'], ':action'=>$action, ':status'=>$to, ':notes'=>'External API']);
        flow_api_success($auth, 'releases:write', ['release_id'=>(int)$segments[0], 'status'=>$to]);
    }
    if ($method === 'POST') {
        $input = flow_api_input();
        $pdo->prepare('INSERT INTO xmpp_release_builds (platform,version,build_number,stage,status,apk_url,notes,uploaded_by_emp_id) VALUES (:platform,:version,:build,"Development","Draft",:url,:notes,:emp)')->execute([':platform'=>(string)($input['platform'] ?? 'android'), ':version'=>(string)$input['version'], ':build'=>(int)($input['build_number'] ?? 0), ':url'=>$input['artifact_url'] ?? null, ':notes'=>$input['notes'] ?? null, ':emp'=>(int)$auth['actor_emp_id']]);
        flow_api_success($auth, 'releases:write', ['release_id'=>(int)$pdo->lastInsertId()], 201);
    }
    flow_api_handle_simple_table($auth, 'releases:read', 'xmpp_release_builds', 'releases');
}

function flow_api_ext_json_message(array $auth, string $prefix): never
{
    $input = flow_api_input(); $to = trim((string)($input['to_jid'] ?? ''));
    if ($to === '') flow_api_error('to_jid is required.', 422, 'VALIDATION_ERROR');
    $body = $prefix . json_encode($input['payload'] ?? $input, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    $pdo = flow_api_chat_db(); $from = flow_api_jid_for_emp($pdo, (int)$auth['actor_emp_id']);
    $pdo->prepare('INSERT INTO xmpp_messages (from_jid,to_jid,body,message_type,source_device,source_name,status) VALUES (:from,:to,:body,"chat","api",:source,"sent")')->execute([':from'=>$from, ':to'=>$to, ':body'=>$body, ':source'=>$auth['client_name']]);
    flow_api_success($auth, 'chat:write', ['message_id'=>(int)$pdo->lastInsertId()], 201);
}
