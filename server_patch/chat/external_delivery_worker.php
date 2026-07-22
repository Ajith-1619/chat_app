<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

function flow_external_smtp_config(): array
{
    $file = __DIR__ . '/external_mail_config.php';
    $config = is_file($file) ? require $file : [];
    return is_array($config) ? $config : [];
}

function flow_smtp_expect($socket, array $codes): string
{
    $response = '';
    while (($line = fgets($socket, 2048)) !== false) {
        $response .= $line;
        if (strlen($line) >= 4 && $line[3] === ' ') break;
    }
    $code = (int)substr($response, 0, 3);
    if (!in_array($code, $codes, true)) {
        throw new RuntimeException('SMTP response ' . trim($response));
    }
    return $response;
}

function flow_smtp_send($socket, string $command, array $expect): string
{
    fwrite($socket, $command . "\r\n");
    return flow_smtp_expect($socket, $expect);
}

function flow_smtp_address(string $email, string $name = ''): string
{
    $email = trim($email);
    $name = trim(str_replace(["\r", "\n", '"'], ' ', $name));
    if ($name === '') return '<' . $email . '>';
    return '"' . addcslashes($name, '"\\') . '" <' . $email . '>';
}

function flow_smtp_message(string $fromEmail, string $fromName, string $toEmail, string $toName, string $subject, string $body): string
{
    $subject = trim(str_replace(["\r", "\n"], ' ', $subject));
    $headers = [
        'Date: ' . date(DATE_RFC2822),
        'From: ' . flow_smtp_address($fromEmail, $fromName),
        'To: ' . flow_smtp_address($toEmail, $toName),
        'Subject: =?UTF-8?B?' . base64_encode($subject) . '?=',
        'MIME-Version: 1.0',
        'Content-Type: text/plain; charset=UTF-8',
        'Content-Transfer-Encoding: 8bit',
    ];
    $payload = implode("\r\n", $headers) . "\r\n\r\n" . str_replace(["\r\n", "\r"], "\n", $body);
    $payload = str_replace("\n", "\r\n", $payload);
    return preg_replace('/^\./m', '..', $payload) . "\r\n.";
}

function flow_send_external_email(string $toEmail, string $toName, string $subject, string $body): void
{
    $config = flow_external_smtp_config();
    $host = (string)($config['host'] ?? '');
    $port = (int)($config['port'] ?? 587);
    $username = (string)($config['username'] ?? '');
    $password = (string)($config['password'] ?? '');
    $fromEmail = (string)($config['from_email'] ?? $username);
    $fromName = (string)($config['from_name'] ?? 'Flow Messager');
    $timeout = max(5, (int)($config['timeout_seconds'] ?? 20));
    if ($host === '' || $username === '' || $password === '' || $fromEmail === '') {
        throw new RuntimeException('External mail SMTP config is incomplete.');
    }
    $socket = @stream_socket_client('tcp://' . $host . ':' . $port, $errno, $errstr, $timeout, STREAM_CLIENT_CONNECT);
    if (!$socket) throw new RuntimeException('SMTP connect failed: ' . $errstr);
    stream_set_timeout($socket, $timeout);
    try {
        flow_smtp_expect($socket, [220]);
        flow_smtp_send($socket, 'EHLO ' . ($_SERVER['SERVER_NAME'] ?? 'flow.local'), [250]);
        flow_smtp_send($socket, 'STARTTLS', [220]);
        if (!stream_socket_enable_crypto($socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
            throw new RuntimeException('SMTP STARTTLS failed.');
        }
        flow_smtp_send($socket, 'EHLO ' . ($_SERVER['SERVER_NAME'] ?? 'flow.local'), [250]);
        flow_smtp_send($socket, 'AUTH LOGIN', [334]);
        flow_smtp_send($socket, base64_encode($username), [334]);
        flow_smtp_send($socket, base64_encode($password), [235]);
        flow_smtp_send($socket, 'MAIL FROM:<' . $fromEmail . '>', [250]);
        flow_smtp_send($socket, 'RCPT TO:<' . $toEmail . '>', [250, 251]);
        flow_smtp_send($socket, 'DATA', [354]);
        flow_smtp_send($socket, flow_smtp_message($fromEmail, $fromName, $toEmail, $toName, $subject, $body), [250]);
        flow_smtp_send($socket, 'QUIT', [221]);
    } finally {
        if (is_resource($socket)) fclose($socket);
    }
}

function flow_process_external_email_queue(int $limit = 25): array
{
    $pdo = chat_db();
    chat_ensure_schema($pdo);
    $select = $pdo->prepare("SELECT q.id, q.external_contact_id, q.destination, q.subject, q.body, c.display_name
        FROM xmpp_external_delivery_queue q
        LEFT JOIN external_contacts c ON c.id = q.external_contact_id
        WHERE q.status = 'queued' AND q.channel = 'email'
        ORDER BY q.created_at ASC
        LIMIT :limit");
    $select->bindValue(':limit', max(1, min(100, $limit)), PDO::PARAM_INT);
    $select->execute();
    $rows = $select->fetchAll(PDO::FETCH_ASSOC) ?: [];
    $sent = 0;
    $failed = 0;
    foreach ($rows as $row) {
        $id = (int)$row['id'];
        $claim = $pdo->prepare("UPDATE xmpp_external_delivery_queue SET status = 'processing', attempts = attempts + 1 WHERE id = :id AND status = 'queued'");
        $claim->execute([':id' => $id]);
        if ($claim->rowCount() < 1) continue;
        try {
            flow_send_external_email((string)$row['destination'], (string)($row['display_name'] ?? ''), (string)$row['subject'], (string)$row['body']);
            $done = $pdo->prepare("UPDATE xmpp_external_delivery_queue SET status = 'sent', sent_at = NOW(), last_error = NULL WHERE id = :id");
            $done->execute([':id' => $id]);
            $sent++;
        } catch (Throwable $e) {
            $fail = $pdo->prepare("UPDATE xmpp_external_delivery_queue SET status = IF(attempts >= 3, 'failed', 'queued'), last_error = :error WHERE id = :id");
            $fail->execute([':id' => $id, ':error' => mb_substr($e->getMessage(), 0, 1000)]);
            $failed++;
            error_log('external email delivery failed #' . $id . ': ' . $e->getMessage());
        }
    }
    return ['status' => true, 'processed' => count($rows), 'sent' => $sent, 'failed' => $failed];
}

if (PHP_SAPI === 'cli') {
    $result = flow_process_external_email_queue((int)($argv[1] ?? 25));
    echo json_encode($result, JSON_UNESCAPED_SLASHES) . PHP_EOL;
    exit;
}

chat_require_user();
chat_json(flow_process_external_email_queue((int)($_GET['limit'] ?? 10)));