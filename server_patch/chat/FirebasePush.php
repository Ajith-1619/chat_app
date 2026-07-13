<?php
declare(strict_types=1);

final class FirebasePush
{
    private const OAUTH_URL = 'https://oauth2.googleapis.com/token';
    private const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    public function __construct(private readonly string $credentialsPath) {}

    public function send(string $token, string $title, string $body, array $data = []): bool
    {
        $credentials = $this->credentials();
        $projectId = trim((string)($credentials['project_id'] ?? ''));
        if ($projectId === '') {
            throw new RuntimeException('Firebase project_id is missing');
        }

        $payload = [
            'message' => [
                'token' => $token,
                'notification' => ['title' => $title, 'body' => $body],
                'data' => array_map('strval', $data),
                'android' => [
                    'priority' => 'HIGH',
                    'notification' => [
                        'channel_id' => 'skylink_messages',
                        'sound' => 'default',
                    ],
                ],
            ],
        ];

        $response = $this->request(
            'https://fcm.googleapis.com/v1/projects/' . rawurlencode($projectId) . '/messages:send',
            $payload,
            ['Authorization: Bearer ' . $this->accessToken()]
        );
        return $response['status'] >= 200 && $response['status'] < 300;
    }

    private function accessToken(): string
    {
        $cachePath = rtrim(sys_get_temp_dir(), DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR . 'skylink-fcm-token.json';
        if (is_file($cachePath)) {
            $cached = json_decode((string)file_get_contents($cachePath), true);
            if (is_array($cached) &&
                !empty($cached['token']) &&
                (int)($cached['expires_at'] ?? 0) > time() + 60) {
                return (string)$cached['token'];
            }
        }

        $credentials = $this->credentials();
        $now = time();
        $header = $this->base64Url(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
        $claims = $this->base64Url(json_encode([
            'iss' => (string)($credentials['client_email'] ?? ''),
            'scope' => self::SCOPE,
            'aud' => self::OAUTH_URL,
            'iat' => $now,
            'exp' => $now + 3600,
        ]));
        $unsigned = $header . '.' . $claims;
        $signature = '';
        if (!openssl_sign(
            $unsigned,
            $signature,
            (string)($credentials['private_key'] ?? ''),
            OPENSSL_ALGO_SHA256
        )) {
            throw new RuntimeException('Unable to sign Firebase access token');
        }

        $response = $this->request(self::OAUTH_URL, [
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $unsigned . '.' . $this->base64Url($signature),
        ], [], true);
        $decoded = json_decode($response['body'], true);
        $token = is_array($decoded) ? trim((string)($decoded['access_token'] ?? '')) : '';
        if ($response['status'] < 200 || $response['status'] >= 300 || $token === '') {
            throw new RuntimeException('Firebase OAuth token request failed');
        }
        @file_put_contents($cachePath, json_encode([
            'token' => $token,
            'expires_at' => $now + (int)($decoded['expires_in'] ?? 3600),
        ]), LOCK_EX);
        return $token;
    }

    private function credentials(): array
    {
        if (!is_file($this->credentialsPath) || !is_readable($this->credentialsPath)) {
            throw new RuntimeException('Firebase service account file is unavailable');
        }
        $credentials = json_decode((string)file_get_contents($this->credentialsPath), true);
        if (!is_array($credentials) ||
            ($credentials['type'] ?? '') !== 'service_account' ||
            empty($credentials['client_email']) ||
            empty($credentials['private_key'])) {
            throw new RuntimeException('Firebase service account file is invalid');
        }
        return $credentials;
    }

    private function request(string $url, array $payload, array $headers = [], bool $form = false): array
    {
        $ch = curl_init($url);
        if ($ch === false) throw new RuntimeException('Unable to initialize Firebase request');
        $headers[] = $form
            ? 'Content-Type: application/x-www-form-urlencoded'
            : 'Content-Type: application/json';
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_POSTFIELDS => $form ? http_build_query($payload) : json_encode($payload),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CONNECTTIMEOUT => 8,
            CURLOPT_TIMEOUT => 20,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
        ]);
        $body = curl_exec($ch);
        $error = curl_error($ch);
        $status = (int)curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
        curl_close($ch);
        if ($body === false || $error !== '') {
            throw new RuntimeException('Firebase request failed: ' . $error);
        }
        return ['status' => $status, 'body' => (string)$body];
    }

    private function base64Url(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }
}
