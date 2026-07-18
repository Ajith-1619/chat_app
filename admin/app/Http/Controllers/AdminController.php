<?php

namespace App\Http\Controllers;

use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;
use Throwable;

class AdminController extends Controller
{
    private function loadLegacy(): void
    {
        require_once base_path('legacy_standalone/_bootstrap.php');
    }

    public function index(Request $request): View|RedirectResponse
    {
        $this->loadLegacy();

        if ($request->query('ajax') === 'api') {
            require base_path('legacy_standalone/api.php');
        }

        if ($request->query('logout') === '1') {
            flow_admin_logout();
            return redirect()->to($request->url());
        }

        $error = '';
        if ($request->isMethod('post')) {
            try {
                flow_admin_login((string) $request->input('username', ''), (string) $request->input('password', ''));
                return redirect()->to($request->url());
            } catch (Throwable $e) {
                $error = $e->getMessage();
            }
        }

        $admin = null;
        try {
            $admin = flow_admin_current_emp_id() > 0 ? flow_admin_require() : null;
        } catch (Throwable $e) {
            $error = $error !== '' ? $error : $e->getMessage();
        }

        if (!$admin) {
            return view('admin.login', [
                'error' => $error,
                'title' => 'Flow Master Admin',
            ]);
        }

        $module = (string) $request->query('module', 'overview');
        if (!array_key_exists($module, $this->modules())) {
            $module = 'overview';
        }

        return $this->dashboardView($admin, $module);
    }

    public function module(string $module): View|RedirectResponse
    {
        $this->loadLegacy();
        $allowed = array_keys($this->modules());
        if (!in_array($module, $allowed, true)) {
            abort(404);
        }

        try {
            $admin = flow_admin_require();
        } catch (Throwable) {
            return redirect()->to($this->adminBaseUrl());
        }

        return $this->dashboardView($admin, $module);
    }

    private function adminBaseUrl(): string
    {
        $script = str_replace('\\', '/', (string)($_SERVER['SCRIPT_NAME'] ?? ''));
        if ($script !== '' && !str_starts_with($script, '/')) {
            $script = '/' . $script;
        }
        if (str_ends_with($script, '/public/index.php')) {
            return rtrim(dirname($script), '/') . '/';
        }
        $base = rtrim(dirname($script), '/');
        return ($base === '' || $base === '.') ? '/' : $base . '/';
    }
    private function dashboardView(array $admin, string $activeView): View
    {
        $modules = $this->modules();
        $meta = $modules[$activeView] ?? $modules['overview'];

        return view('admin.dashboard', [
            'admin' => $admin,
            'legacyCsrf' => flow_admin_csrf_token(),
            'title' => 'Flow Admin Console - ' . $meta['title'],
            'activeView' => $activeView,
            'pageTitle' => $meta['title'],
            'pageSubtitle' => $meta['subtitle'],
            'modules' => $modules,
        ]);
    }

    private function modules(): array
    {
        return [
            'overview' => ['title' => 'Overview', 'subtitle' => 'Chat application control center'],
            'users' => ['title' => 'Users', 'subtitle' => 'Employee access, presence and profile identity'],
            'groups' => ['title' => 'Groups', 'subtitle' => 'Group list, members, wake-up and admin controls'],
            'channels' => ['title' => 'Channels', 'subtitle' => 'Channel list, type, wake-up and admin controls'],
            'tasks' => ['title' => 'Tasks', 'subtitle' => 'MyHub task master records'],
            'location' => ['title' => 'Location', 'subtitle' => 'Location visibility and presence policy'],
            'notifications' => ['title' => 'Notifications', 'subtitle' => 'Push queue and delivery status'],
            'releases' => ['title' => 'Releases', 'subtitle' => 'Draft/live app release management'],
            'diagnostics' => ['title' => 'Diagnostics', 'subtitle' => 'API, database and notification timings'],
            'audit' => ['title' => 'Audit Log', 'subtitle' => 'All super-admin changes and security events'],
        ];
    }

    public function logout(): RedirectResponse
    {
        $this->loadLegacy();
        flow_admin_logout();

        return redirect()->route('admin.dashboard');
    }
}
