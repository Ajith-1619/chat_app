<?php
declare(strict_types=1);

function chat_ai_ensure_room_table(PDO $pdo): void
{
    $pdo->exec("CREATE TABLE IF NOT EXISTS flow_admin_ai_providers (
        id INT AUTO_INCREMENT PRIMARY KEY,
        provider_name VARCHAR(120) NOT NULL,
        api_type VARCHAR(80) NOT NULL,
        model_name VARCHAR(160) NULL,
        api_endpoint VARCHAR(500) NULL,
        api_key TEXT NULL,
        status TINYINT NOT NULL DEFAULT 1,
        notes TEXT NULL,
        created_by_emp_id INT NULL,
        updated_by_emp_id INT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    $pdo->exec("CREATE TABLE IF NOT EXISTS flow_admin_ai_room_access (
        group_id INT NOT NULL PRIMARY KEY,
        provider_id INT NULL,
        enabled TINYINT NOT NULL DEFAULT 0,
        trigger_token VARCHAR(40) NOT NULL DEFAULT '@ai',
        max_context_messages INT NOT NULL DEFAULT 50,
        updated_by_emp_id INT NULL,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_ai_room_enabled (enabled, provider_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
}

function chat_ai_room_config(PDO $pdo, int $groupId): ?array
{
    if ($groupId <= 0) return null;
    chat_ai_ensure_room_table($pdo);
    $stmt = $pdo->prepare('SELECT a.group_id, a.provider_id, a.trigger_token, a.max_context_messages, p.provider_name, p.api_type, p.model_name, p.api_endpoint, p.api_key
        FROM flow_admin_ai_room_access a
        INNER JOIN flow_admin_ai_providers p ON p.id = a.provider_id AND p.status = 1
        WHERE a.group_id = :group_id AND a.enabled = 1
        LIMIT 1');
    $stmt->execute([':group_id' => $groupId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC) ?: null;
    return $row ?: null;
}

function chat_ai_triggered(string $body, string $trigger): bool
{
    $trigger = trim($trigger) !== '' ? trim($trigger) : '@ai';
    return preg_match('/(^|\s)' . preg_quote($trigger, '/') . '(\s|$|[,:?.!])/i', $body) === 1;
}

function chat_ai_question(string $body, string $trigger): string
{
    $trigger = trim($trigger) !== '' ? trim($trigger) : '@ai';
    $question = preg_replace('/(^|\s)' . preg_quote($trigger, '/') . '(\s|$|[,:?.!])/i', ' ', $body) ?? $body;
    return trim((string)$question) ?: 'Summarize the recent conversation and answer helpfully.';
}

function chat_ai_recent_context(PDO $pdo, string $roomJid, int $currentMessageId, int $limit): array
{
    $limit = max(5, min(50, $limit));
    $stmt = $pdo->prepare("SELECT id, from_jid, body, file_name, created_at
        FROM xmpp_messages
        WHERE to_jid = :room_jid
          AND id <> :message_id
          AND deleted_at IS NULL
          AND COALESCE(visibility_mode, 'all') = 'all'
          AND (body IS NOT NULL OR file_name IS NOT NULL)
        ORDER BY id DESC
        LIMIT {$limit}");
    $stmt->execute([':room_jid' => strtolower($roomJid), ':message_id' => $currentMessageId]);
    return array_reverse($stmt->fetchAll(PDO::FETCH_ASSOC) ?: []);
}

function chat_ai_endpoint(array $provider): string
{
    $endpoint = trim((string)($provider['api_endpoint'] ?? ''));
    $haystack = strtolower(implode(' ', [$provider['provider_name'] ?? '', $provider['api_type'] ?? '', $provider['model_name'] ?? '']));
    if ($endpoint === '' || preg_match('/^\d+$/', $endpoint) || str_contains($haystack, 'open router') || str_contains($haystack, 'openrouter')) {
        return 'https://openrouter.ai/api/v1/chat/completions';
    }
    return $endpoint;
}

function chat_ai_model(array $provider): string
{
    $model = trim((string)($provider['model_name'] ?? ''));
    if ($model === '' || strcasecmp($model, 'Open Router API') === 0 || strcasecmp($model, 'OpenRouter API') === 0) {
        return 'openai/gpt-4o-mini';
    }
    return $model;
}

function chat_ai_call_provider(array $provider, string $roomName, array $contextRows, string $question, string $roomDescription = ''): string
{
    $apiKey = trim((string)($provider['api_key'] ?? ''));
    if ($apiKey === '') throw new RuntimeException('AI provider API key is missing.');

    $contextLines = [];
    foreach ($contextRows as $row) {
        $sender = preg_replace('/@.*/', '', (string)($row['from_jid'] ?? ''));
        $body = trim((string)($row['body'] ?? ''));
        $file = trim((string)($row['file_name'] ?? ''));
        $text = $body !== '' ? $body : ('[file] ' . $file);
        $contextLines[] = '[' . (string)($row['created_at'] ?? '') . '] ' . $sender . ': ' . mb_substr($text, 0, 900);
    }

    $descriptionLine = trim($roomDescription) !== '' ? "Channel purpose/description: {$roomDescription}\n" : '';
    $prompt = "Room: {$roomName}\n" . $descriptionLine . "Recent conversation:\n" . implode("\n", $contextLines) . "\n\nUser question: {$question}";
    $payload = [
        'model' => chat_ai_model($provider),
        'messages' => [
            ['role' => 'system', 'content' => 'You are Flow AI for an enterprise group/channel. Use the recent conversation context when relevant. Be concise, practical, and do not invent facts not present in the context.'],
            ['role' => 'user', 'content' => $prompt],
        ],
        'temperature' => 0.2,
        'max_tokens' => 700,
    ];

    $ch = curl_init(chat_ai_endpoint($provider));
    if (!$ch) throw new RuntimeException('Unable to initialize AI request.');
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => [
            'Authorization: Bearer ' . $apiKey,
            'Content-Type: application/json',
            'HTTP-Referer: https://chat.skylinkonline.net',
            'X-Title: Skylink Flow',
        ],
        CURLOPT_POSTFIELDS => json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
        CURLOPT_CONNECTTIMEOUT => 8,
        CURLOPT_TIMEOUT => 25,
    ]);
    $raw = curl_exec($ch);
    $status = (int)curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    $error = curl_error($ch);
    curl_close($ch);
    if ($raw === false || $status < 200 || $status >= 300) {
        throw new RuntimeException('AI request failed: HTTP ' . $status . ($error !== '' ? ' ' . $error : ''));
    }
    $data = json_decode((string)$raw, true);
    $reply = trim((string)($data['choices'][0]['message']['content'] ?? $data['choices'][0]['text'] ?? ''));
    if ($reply === '') throw new RuntimeException('AI provider returned an empty reply.');
    return $reply;
}

function chat_ai_insert_reply(PDO $pdo, string $roomJid, string $reply, string $roomName): int
{
    $from = 'flow-ai@chat.skylinkonline.net';
    $stmt = $pdo->prepare("INSERT INTO xmpp_messages (from_jid, to_jid, body, message_type, source_device, source_name, visibility_mode, status, created_at) VALUES (:from_jid, :to_jid, :body, 'groupchat', 'ai', :source_name, 'all', 'sent', NOW())");
    $stmt->execute([
        ':from_jid' => $from,
        ':to_jid' => strtolower($roomJid),
        ':body' => $reply,
        ':source_name' => 'Flow AI - ' . mb_substr($roomName, 0, 80),
    ]);
    $id = (int)$pdo->lastInsertId();
    try {
        if (function_exists('chat_send_xmpp_message')) chat_send_xmpp_message($from, strtolower($roomJid), $reply);
    } catch (Throwable $e) {
        error_log('chat ai room xmpp send skipped: ' . $e->getMessage());
    }
    return $id;
}

function chat_try_send_ai_room_reply(PDO $pdo, array $group, int $messageId, string $body): void
{
    $groupId = (int)($group['id'] ?? 0);
    $roomJid = strtolower((string)($group['room_jid'] ?? ''));
    if ($groupId <= 0 || $roomJid === '' || $messageId <= 0 || trim($body) === '') return;
    $config = chat_ai_room_config($pdo, $groupId);
    if (!$config) return;
    $trigger = (string)($config['trigger_token'] ?? '@ai');
    if (!chat_ai_triggered($body, $trigger)) return;
    $contextRows = chat_ai_recent_context($pdo, $roomJid, $messageId, (int)($config['max_context_messages'] ?? 50));
    $question = chat_ai_question($body, $trigger);
    $roomName = (string)($group['room_name'] ?? 'Flow group/channel');
    $roomDescription = (string)($group['description'] ?? '');
    $reply = chat_ai_call_provider($config, $roomName, $contextRows, $question, $roomDescription);
    chat_ai_insert_reply($pdo, $roomJid, $reply, $roomName);
}

