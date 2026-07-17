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

        $error = '';
        if ($request->isMethod('post')) {
            try {
                flow_admin_login((string) $request->input('username', ''), (string) $request->input('password', ''));
                return redirect()->route('admin.dashboard');
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

        return view('admin.dashboard', [
            'admin' => $admin,
            'legacyCsrf' => flow_admin_csrf_token(),
            'title' => 'Flow Admin Console',
        ]);
    }

    public function logout(): RedirectResponse
    {
        $this->loadLegacy();
        flow_admin_logout();

        return redirect()->route('admin.dashboard');
    }
}
