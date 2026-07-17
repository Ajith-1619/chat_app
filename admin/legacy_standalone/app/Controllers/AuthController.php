<?php
declare(strict_types=1);

final class AuthController
{
    public function login(): array
    {
        $error = '';
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            try {
                flow_admin_login((string)($_POST['username'] ?? ''), (string)($_POST['password'] ?? ''));
                header('Location: index.php');
                exit;
            } catch (Throwable $e) {
                $error = $e->getMessage();
            }
        }

        return ['error' => $error];
    }

    public function logout(): never
    {
        flow_admin_logout();
        header('Location: index.php');
        exit;
    }
}
