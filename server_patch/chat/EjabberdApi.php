<?php
declare(strict_types=1);

final class EjabberdApi
{
    public function __construct(
        private readonly string $baseUrl,
        private readonly string $adminJid,
        private readonly string $adminPassword,
        private readonly string $host,
        private readonly string $mucHost,
    ) {}

    public function request(string $command, array $payload = []): mixed
    {
        if (!function_exists('curl_init')) {
            throw new RuntimeException('PHP cURL extension is not enabled');
        }

        $ch = curl_init(rtrim($this->baseUrl, '/') . '/' . rawurlencode($command));
        if ($ch === false) {
            throw new RuntimeException('Unable to initialize ejabberd API request');
        }

        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_HTTPHEADER => ['Content-Type: application/json', 'Accept: application/json'],
            CURLOPT_POSTFIELDS => json_encode($payload, JSON_UNESCAPED_SLASHES),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CONNECTTIMEOUT => 6,
            CURLOPT_TIMEOUT => 12,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
        ]);

        if ($this->adminJid !== '' && $this->adminPassword !== '') {
            curl_setopt($ch, CURLOPT_USERPWD, $this->adminJid . ':' . $this->adminPassword);
            curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
        }

        $body = curl_exec($ch);
        $error = curl_error($ch);
        $status = (int)curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
        curl_close($ch);

        if ($body === false || $error !== '') {
            throw new RuntimeException('ejabberd API connection failed: ' . $error);
        }

        $decoded = json_decode((string)$body, true);
        if ($status < 200 || $status >= 300) {
            $message = is_array($decoded) ? json_encode($decoded, JSON_UNESCAPED_SLASHES) : (string)$body;
            throw new RuntimeException('ejabberd API ' . $command . ' failed with HTTP ' . $status . ': ' . $message);
        }

        return $decoded ?? $body;
    }

    public function registeredUsers(): array
    {
        $response = $this->request('registered_users', ['host' => $this->host]);
        if (is_array($response) && array_is_list($response)) {
            return array_values(array_filter(array_map('strval', $response)));
        }
        if (is_array($response) && isset($response['users']) && is_array($response['users'])) {
            return array_values(array_filter(array_map('strval', $response['users'])));
        }
        return [];
    }

    public function connectedUsers(): array
    {
        $response = $this->request('connected_users', []);
        if (is_array($response) && array_is_list($response)) {
            return array_values(array_filter(array_map('strval', $response)));
        }
        if (is_array($response) && isset($response['users']) && is_array($response['users'])) {
            return array_values(array_filter(array_map('strval', $response['users'])));
        }
        return [];
    }

    public function isOnline(string $jid): bool
    {
        $bare = strtolower(explode('/', $jid, 2)[0]);
        foreach ($this->connectedUsers() as $connected) {
            if (strtolower(explode('/', $connected, 2)[0]) === $bare) {
                return true;
            }
        }
        return false;
    }

    public function lastSeen(string $jid): ?DateTimeImmutable
    {
        $bare = strtolower(explode('/', $jid, 2)[0]);
        [$user, $host] = array_pad(explode('@', $bare, 2), 2, '');
        if ($user === '' || $host === '') return null;
        try {
            $response = $this->request('get_last', [
                'user' => $user,
                'host' => $host,
            ]);
            if (is_array($response)) {
                $seconds = (int)($response['seconds'] ?? $response['last'] ?? 0);
                if ($seconds > 0) {
                    return (new DateTimeImmutable('now'))->modify("-{$seconds} seconds");
                }
                $timestamp = trim((string)($response['timestamp'] ?? ''));
                if ($timestamp !== '') return new DateTimeImmutable($timestamp);
            }
            if (is_numeric($response) && (int)$response > 0) {
                return (new DateTimeImmutable('now'))->modify('-' . (int)$response . ' seconds');
            }
        } catch (Throwable $e) {
            error_log('ejabberd get_last failed: ' . $e->getMessage());
        }
        return null;
    }

    public function accountExists(string $user): bool
    {
        try {
            $response = $this->request('check_account', ['user' => $user, 'host' => $this->host]);
            if (is_bool($response)) return $response;
            if (is_numeric($response)) return (int)$response === 0;
            if (is_string($response)) return $response === '0' || stripos($response, 'exist') !== false;
            if (is_array($response)) return empty($response['error']) && (($response['status'] ?? '') !== 'error');
        } catch (Throwable $e) {
            error_log('ejabberd check_account failed: ' . $e->getMessage());
        }
        return in_array($user, $this->registeredUsers(), true);
    }

    public function register(string $user, string $password): void
    {
        if ($this->accountExists($user)) {
            return;
        }
        $this->request('register', ['user' => $user, 'host' => $this->host, 'password' => $password]);
    }

    public function unregister(string $user): void
    {
        $this->request('unregister', ['user' => $user, 'host' => $this->host]);
    }

    public function changePassword(string $user, string $password): void
    {
        $this->request('change_password', ['user' => $user, 'host' => $this->host, 'newpass' => $password]);
    }

    public function authenticate(string $user, string $password): bool
    {
        try {
            $response = $this->request('check_password', [
                'user' => $user,
                'host' => $this->host,
                'password' => $password,
            ]);
            if (is_bool($response)) return $response;
            if (is_numeric($response)) return (int)$response === 0;
            if (is_string($response)) {
                $value = strtolower(trim($response));
                return in_array($value, ['0', '1', 'true', 'ok', 'success'], true);
            }
            if (is_array($response)) {
                if (isset($response['result'])) {
                    return in_array(strtolower((string)$response['result']), ['0', '1', 'true', 'ok', 'success'], true);
                }
                return empty($response['error']) &&
                    !in_array(strtolower((string)($response['status'] ?? '')), ['error', 'failed', 'false'], true);
            }
        } catch (Throwable $e) {
            error_log('ejabberd check_password failed: ' . $e->getMessage());
        }
        return false;
    }

    public function sendMessage(string $fromJid, string $toJid, string $body, string $type = 'chat'): mixed
    {
        return $this->request('send_message', [
            'type' => $type,
            'from' => $fromJid,
            'to' => $toJid,
            'subject' => '',
            'body' => $body,
        ]);
    }

    public function createRoom(string $room, string $name = ''): void
    {
        $this->request('create_room', [
            'name' => $room,
            'service' => $this->mucHost,
            'host' => $this->host,
        ]);
        if ($name !== '') {
            $this->request('change_room_option', [
                'name' => $room,
                'service' => $this->mucHost,
                'option' => 'title',
                'value' => $name,
            ]);
        }
        foreach (['persistent' => 'true', 'members_only' => 'true'] as $option => $value) {
            $this->request('change_room_option', [
                'name' => $room,
                'service' => $this->mucHost,
                'option' => $option,
                'value' => $value,
            ]);
        }
    }

    public function inviteToRoom(string $room, string $userJid, string $reason = ''): void
    {
        $this->request('send_direct_invitation', [
            'name' => $room,
            'service' => $this->mucHost,
            'password' => '',
            'reason' => $reason,
            'users' => $userJid,
        ]);
    }

    public function setRoomAffiliation(string $room, string $userJid, string $affiliation = 'member'): void
    {
        $this->request('set_room_affiliation', [
            'name' => $room,
            'service' => $this->mucHost,
            'jid' => $userJid,
            'affiliation' => $affiliation,
        ]);
    }
}
