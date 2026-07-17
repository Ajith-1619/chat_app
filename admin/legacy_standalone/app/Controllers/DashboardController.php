<?php
declare(strict_types=1);

final class DashboardController
{
    public function show(): void
    {
        $auth = (new AuthController())->login();
        $error = (string)$auth['error'];
        $admin = null;

        try {
            $admin = flow_admin_current_emp_id() > 0 ? flow_admin_require() : null;
        } catch (Throwable $e) {
            $error = $error !== '' ? $error : $e->getMessage();
        }

        View::render($admin ? 'admin.dashboard' : 'auth.login', [
            'admin' => $admin,
            'csrf' => $admin ? flow_admin_csrf_token() : '',
            'error' => $error,
            'title' => $admin ? 'Flow Admin Console' : 'Flow Master Admin',
        ]);
    }
}
