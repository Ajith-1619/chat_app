<?php

use App\Http\Controllers\AdminController;
use Illuminate\Support\Facades\Route;

Route::match(['GET', 'POST'], '/', [AdminController::class, 'index'])->name('admin.dashboard');
Route::get('/logout', [AdminController::class, 'logout'])->name('admin.logout');

Route::match(['GET', 'POST'], '/api', function () {
    require base_path('legacy_standalone/api.php');
})->name('admin.api');

Route::get('/health', function () {
    require base_path('legacy_standalone/health.php');
});

Route::get('/{module}', [AdminController::class, 'module'])
    ->where('module', 'overview|users|groups|channels|tasks|location|ai_access|notifications|releases|diagnostics|audit')
    ->name('admin.module');
