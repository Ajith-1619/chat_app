<?php
declare(strict_types=1);

require_once __DIR__ . '/../../../../_shared/bootstrap.php';

flow_api_cors();
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$requiredScope = $method === 'GET' ? 'chat:read' : 'chat:write';
$auth = flow_api_auth([$requiredScope]);
$pdo = flow_api_chat_db();

try {
    if ($method === 'GET') {
        $peerEmpId = (int)($_GET['recipient_emp_id'] ?? $_GET['to_emp_id'] ?? $_GET['peer_emp_id'] ?? $_GET['recipient_id'] ?? $_GET['to'] ?? 0);
        $senderEmpId = (int)($_GET['sender_emp_id'] ?? $_GET['from_emp_id'] ?? $_GET['sender_id'] ?? $_GET['from'] ?? $auth['actor_emp_id']);
        if ($peerEmpId <= 0) flow_api_error('recipient_emp_id is required.', 422, 'VALIDATION_ERROR');
        if ($senderEmpId <= 0) flow_api_error('sender_emp_id is invalid.', 422, 'VALIDATION_ERROR');
        $actorJid = flow_api_jid_for_emp($pdo, $senderEmpId);
        $peerJid = flow_api_jid_for_emp($pdo, $peerEmpId);
        $limit = max(1, min(200, (int)($_GET['limit'] ?? 50)));
        $stmt = $pdo->prepare('SELECT * FROM xmpp_messages WHERE deleted_at IS NULL AND message_type = "chat" AND ((from_jid = :actor AND to_jid = :peer) OR (from_jid = :peer AND to_jid = :actor)) ORDER BY id DESC LIMIT :limit');
        $stmt->bindValue(':actor', $actorJid);
        $stmt->bindValue(':peer', $peerJid);
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->execute();
        flow_api_success($auth, 'chat:read', ['messages' => array_reverse($stmt->fetchAll(PDO::FETCH_ASSOC)), 'from_jid' => $actorJid, 'to_jid' => $peerJid]);
    }

    if ($method !== 'POST') {
        flow_api_error('Method not allowed.', 405, 'METHOD_NOT_ALLOWED');
    }

    $rawBody = file_get_contents('php://input') ?: '';
    $decoded = $rawBody !== '' ? json_decode($rawBody, true) : [];
    $input = is_array($decoded) ? $decoded : [];
    if (!$input && $_POST) $input = $_POST;
    $input = array_merge($_GET, $input);

    $recipientEmpId = (int)($input['recipient_emp_id'] ?? $input['to_emp_id'] ?? $input['recipient_id'] ?? $input['to'] ?? 0);
    $senderEmpId = (int)($input['sender_emp_id'] ?? $input['from_emp_id'] ?? $input['sender_id'] ?? $input['from'] ?? $auth['actor_emp_id']);
    $body = trim((string)($input['body'] ?? $input['message'] ?? $input['text'] ?? ''));
    $debug = [
        'handler' => 'physical_direct_messages_v2',
        'content_type' => $_SERVER['CONTENT_TYPE'] ?? '',
        'raw_length' => strlen($rawBody),
        'json_error' => $rawBody === '' ? 'empty_body' : json_last_error_msg(),
        'input_keys' => array_keys($input),
    ];
    if ($recipientEmpId <= 0) flow_api_error('recipient_emp_id is required.', 422, 'VALIDATION_ERROR', ['debug' => $debug]);
    if ($senderEmpId <= 0) flow_api_error('sender_emp_id is invalid.', 422, 'VALIDATION_ERROR', ['debug' => $debug]);
    if ($body === '') flow_api_error('body is required.', 422, 'VALIDATION_ERROR', ['debug' => $debug]);

    $from = flow_api_jid_for_emp($pdo, $senderEmpId);
    $to = flow_api_jid_for_emp($pdo, $recipientEmpId);
    $stmt = $pdo->prepare('INSERT INTO xmpp_messages (from_jid, to_jid, body, message_type, source_device, source_name, client_message_id, status) VALUES (:from_jid, :to_jid, :body, "chat", "api", :source_name, :client_message_id, "sent")');
    $stmt->execute([
        ':from_jid' => $from,
        ':to_jid' => $to,
        ':body' => $body,
        ':source_name' => (string)($input['source_name'] ?? $auth['client_name']),
        ':client_message_id' => (string)($input['client_message_id'] ?? ('api-direct-' . flow_api_request_id())),
    ]);
    $id = (int)$pdo->lastInsertId();
    $message = ['id' => $id, 'from_jid' => $from, 'to_jid' => $to, 'body' => $body, 'message_type' => 'chat', 'created_at' => date('c')];
    flow_plugin_emit($pdo, 'message.sent', ['event_id' => 'api-direct-message-sent-' . $id, 'actor_emp_id' => $senderEmpId, 'message' => $message]);
    flow_plugin_emit($pdo, 'message.received', ['event_id' => 'api-direct-message-received-' . $id, 'actor_emp_id' => $senderEmpId, 'message' => $message]);
    try { chat_ejabberd_send_message($from, $to, $body); } catch (Throwable $e) { error_log('Flow API direct XMPP send skipped: ' . $e->getMessage()); }
    flow_api_success($auth, 'chat:write', ['message' => $message, 'recipient_emp_id' => $recipientEmpId, 'sender_emp_id' => $senderEmpId], 201, 'direct_message', (string)$id);
} catch (PDOException $e) {
    flow_api_audit($auth, $requiredScope, 500, 'error', $e->getMessage());
    flow_api_error('Database error: ' . $e->getMessage(), 500, 'DATABASE_ERROR');
} catch (Throwable $e) {
    flow_api_audit($auth, $requiredScope, 500, 'error', $e->getMessage());
    flow_api_error('Server error: ' . $e->getMessage(), 500, 'SERVER_ERROR');
}