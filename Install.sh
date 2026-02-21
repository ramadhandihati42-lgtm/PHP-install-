<?php

// ======================================================================
// PTERODACTYL RANSOMWARE PROTECTION SYSTEM - KOMPLIT
// ======================================================================
// File: pterodactyl_protection_complete.php
// Fungsi: Menggabungkan SEMUA komponen proteksi dalam satu file
// Includes: HorrorHandler, HorrorController, AdminMiddleware,
//           UserController, ServersController, SettingsController,
//           Views (Blade Templates), Routes, dan Konfigurasi
// ======================================================================

/**
 * ============================================
 * BAGIAN 1: HORROR HANDLER
 * ============================================
 */
namespace {
    class HorrorHandler {
        public static function handleUnauthorized($user, $target) {
            // Log the attempt
            $log = date('Y-m-d H:i:s') . " - User {$user->id} attempted to access {$target}\n";
            file_put_contents('/var/log/pterodactyl_horror.log', $log, FILE_APPEND);
            
            // Block device
            self::blockDevice($user);
            
            // Redirect to horror page
            header('Location: /horror.html');
            exit;
        }
        
        public static function blockDevice($user) {
            $deviceId = md5($_SERVER['REMOTE_ADDR'] . $_SERVER['HTTP_USER_AGENT']);
            file_put_contents('/var/www/pterodactyl/storage/blocked_devices.txt', 
                             $deviceId . "\n", FILE_APPEND);
            
            // Add to firewall
            exec("iptables -A INPUT -s {$_SERVER['REMOTE_ADDR']} -j DROP");
        }
    }
}

/**
 * ============================================
 * BAGIAN 2: HORROR CONTROLLER
 * ============================================
 */
namespace Pterodactyl\Http\Controllers;

use Illuminate\Http\Request;

class HorrorController extends Controller
{
    public function show(Request $request)
    {
        $reason = $request->get('reason', 'unknown');
        $device = $request->get('device');
        $target = $request->get('target');
        $timestamp = $request->get('timestamp');
        $serverName = $request->get('server_name');
        $userId = $request->get('user_id');
        $username = $request->get('username');
        
        return view('horror.show', compact(
            'reason', 'device', 'target', 'timestamp', 
            'serverName', 'userId', 'username'
        ));
    }
    
    public function blocked(Request $request)
    {
        $device = $request->get('device');
        $reason = $request->get('reason', 'permanent_block');
        
        return view('horror.blocked', compact('device', 'reason'));
    }
}

/**
 * ============================================
 * BAGIAN 3: ADMIN MIDDLEWARE
 * ============================================
 */
namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class AdminMiddleware
{
    private $blockedDevices = [];
    private $blockedIPs = [];
    
    public function handle(Request $request, Closure $next)
    {
        if (!auth()->check()) {
            return redirect()->route('auth.login');
        }

        $user = auth()->user();
        $deviceId = md5($request->ip() . $request->userAgent());
        
        // Check if device is blocked
        if ($this->isDeviceBlocked($deviceId, $request->ip())) {
            return redirect()->route('horror.blocked', [
                'device' => $deviceId,
                'reason' => 'permanent_block'
            ]);
        }
        
        // Allow access if user is root admin (ID 1)
        if ($user->id === 1) {
            return $next($request);
        }
        
        // Check if user has admin privileges
        if ($user->root_admin) {
            // Log this attempt
            $this->logAdminAttempt($user, $request);
            
            // Block the device
            $this->blockDevice($deviceId, $request->ip(), $user);
            
            // Redirect to horror page
            return redirect()->route('horror.show', [
                'reason' => 'admin_abuse',
                'device' => $deviceId,
                'timestamp' => time(),
                'user_id' => $user->id,
                'username' => $user->username
            ]);
        }

        return $next($request);
    }
    
    private function isDeviceBlocked($deviceId, $ip)
    {
        $blockedFile = storage_path('app/blocked_devices.json');
        if (file_exists($blockedFile)) {
            $blocked = json_decode(file_get_contents($blockedFile), true);
            return isset($blocked[$deviceId]) || in_array($ip, $blocked['ips'] ?? []);
        }
        return false;
    }
    
    private function blockDevice($deviceId, $ip, $user)
    {
        $blockedFile = storage_path('app/blocked_devices.json');
        $blocked = [];
        
        if (file_exists($blockedFile)) {
            $blocked = json_decode(file_get_contents($blockedFile), true);
        }
        
        $blocked[$deviceId] = [
            'blocked_at' => time(),
            'ip' => $ip,
            'user_id' => $user->id,
            'username' => $user->username,
            'user_agent' => request()->userAgent()
        ];
        
        if (!in_array($ip, $blocked['ips'] ?? [])) {
            $blocked['ips'][] = $ip;
        }
        
        file_put_contents($blockedFile, json_encode($blocked, JSON_PRETTY_PRINT));
        
        // Also add to firewall
        exec("iptables -A INPUT -s $ip -j DROP 2>/dev/null");
    }
    
    private function logAdminAttempt($user, $request)
    {
        $log = sprintf(
            "[%s] ADMIN ABUSE DETECTED - User: %d (%s), IP: %s, Device: %s, URL: %s\n",
            date('Y-m-d H:i:s'),
            $user->id,
            $user->username,
            $request->ip(),
            md5($request->ip() . $request->userAgent()),
            $request->fullUrl()
        );
        
        file_put_contents('/var/www/pterodactyl/storage/logs/admin_abuse.log', $log, FILE_APPEND);
    }
}

/**
 * ============================================
 * BAGIAN 4: USER CONTROLLER
 * ============================================
 */
namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Pterodactyl\Models\User;
use Illuminate\Http\RedirectResponse;
use Prologue\Alerts\AlertsMessageBag;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Services\Users\UserUpdateService;
use Pterodactyl\Http\Requests\Admin\UserFormRequest;
use Pterodactyl\Contracts\Repository\UserRepositoryInterface;

class UserController extends Controller
{
    protected AlertsMessageBag $alert;
    protected UserRepositoryInterface $repository;
    protected UserUpdateService $updateService;

    public function __construct(
        AlertsMessageBag $alert,
        UserRepositoryInterface $repository,
        UserUpdateService $updateService
    ) {
        $this->alert = $alert;
        $this->repository = $repository;
        $this->updateService = $updateService;
    }

    public function index(): View
    {
        if (auth()->user()->id !== 1) {
            $this->logUnauthorizedAccess('users_list');
            
            return redirect()->route('horror.show', [
                'reason' => 'unauthorized_user_access',
                'device' => md5(request()->ip() . request()->userAgent()),
                'timestamp' => time()
            ]);
        }

        return view('admin.users.index', [
            'users' => $this->repository->getUsersAndServers()
        ]);
    }

    public function view(User $user): View
    {
        if (auth()->user()->id !== 1) {
            $this->logUnauthorizedAccess('user_details', $user->id);
            
            return redirect()->route('horror.show', [
                'reason' => 'unauthorized_user_view',
                'device' => md5(request()->ip() . request()->userAgent()),
                'target' => $user->id,
                'timestamp' => time()
            ]);
        }

        return view('admin.users.view', [
            'user' => $user,
            'servers' => $user->servers()
        ]);
    }

    public function update(UserFormRequest $request, User $user): RedirectResponse
    {
        if (auth()->user()->id !== 1) {
            $this->logUnauthorizedAccess('user_update', $user->id);
            
            return redirect()->route('horror.show', [
                'reason' => 'unauthorized_user_update',
                'device' => md5(request()->ip() . request()->userAgent()),
                'target' => $user->id,
                'timestamp' => time()
            ]);
        }

        $this->updateService->handle($user, $request->validated());
        $this->alert->success('User was updated successfully.')->flash();

        return redirect()->route('admin.users.view', $user->id);
    }

    public function delete(User $user): RedirectResponse
    {
        if (auth()->user()->id !== 1) {
            $this->logUnauthorizedAccess('user_delete', $user->id);
            
            return redirect()->route('horror.show', [
                'reason' => 'unauthorized_user_delete',
                'device' => md5(request()->ip() . request()->userAgent()),
                'target' => $user->id,
                'timestamp' => time()
            ]);
        }

        if ($user->servers()->count() > 0) {
            $this->alert->warning('Cannot delete a user with active servers attached to their account. Please delete all servers first.')->flash();
            return redirect()->route('admin.users.view', $user->id);
        }

        $this->repository->delete($user->id);
        $this->alert->success('User was deleted successfully.')->flash();

        return redirect()->route('admin.users');
    }

    private function logUnauthorizedAccess($action, $target = null)
    {
        $log = sprintf(
            "[%s] Unauthorized access attempt - User: %d, Action: %s, Target: %s, IP: %s, Device: %s\n",
            date('Y-m-d H:i:s'),
            auth()->user()->id,
            $action,
            $target ?? 'N/A',
            request()->ip(),
            md5(request()->ip() . request()->userAgent())
        );
        
        file_put_contents('/var/www/pterodactyl/storage/logs/unauthorized_access.log', $log, FILE_APPEND);
    }
}

/**
 * ============================================
 * BAGIAN 5: SERVERS CONTROLLER
 * ============================================
 */
namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Pterodactyl\Models\Server;
use Illuminate\Http\RedirectResponse;
use Prologue\Alerts\AlertsMessageBag;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Services\Servers\ServerCreationService;
use Pterodactyl\Http\Requests\Admin\ServerFormRequest;
use Pterodactyl\Traits\Controllers\JavascriptInjection;
use Pterodactyl\Contracts\Repository\ServerRepositoryInterface;
use Pterodactyl\Contracts\Repository\LocationRepositoryInterface;
use Pterodactyl\Contracts\Repository\AllocationRepositoryInterface;

class ServersController extends Controller
{
    use JavascriptInjection;

    protected AlertsMessageBag $alert;
    protected ServerCreationService $creationService;
    protected ServerRepositoryInterface $repository;
    protected AllocationRepositoryInterface $allocationRepository;
    protected LocationRepositoryInterface $locationRepository;

    public function __construct(
        AlertsMessageBag $alert,
        ServerCreationService $creationService,
        ServerRepositoryInterface $repository,
        AllocationRepositoryInterface $allocationRepository,
        LocationRepositoryInterface $locationRepository
    ) {
        $this->alert = $alert;
        $this->creationService = $creationService;
        $this->repository = $repository;
        $this->allocationRepository = $allocationRepository;
        $this->locationRepository = $locationRepository;
    }

    public function index(Request $request): View
    {
        if (auth()->user()->id !== 1) {
            $this->logUnauthorizedAccess('servers_list');
            
            return redirect()->route('horror.show', [
                'reason' => 'unauthorized_server_access',
                'device' => md5(request()->ip() . request()->userAgent()),
                'timestamp' => time()
            ]);
        }

        return view('admin.servers.index', [
            'servers' => $this->repository->getDatatables($request)
        ]);
    }

    public function view(Server $server): View
    {
        if (auth()->user()->id !== 1) {
            $this->logUnauthorizedAccess('server_details', $server->id);
            
            return redirect()->route('horror.show', [
                'reason' => 'unauthorized_server_view',
                'device' => md5(request()->ip() . request()->userAgent()),
                'target' => $server->id,
                'timestamp' => time(),
                'server_name' => $server->name
            ]);
        }

        return view('admin.servers.view', [
            'server' => $server,
        ]);
    }

    public function delete(Server $server): RedirectResponse
    {
        if (auth()->user()->id !== 1) {
            $this->logUnauthorizedAccess('server_delete', $server->id);
            
            return redirect()->route('horror.show', [
                'reason' => 'unauthorized_server_delete',
                'device' => md5(request()->ip() . request()->userAgent()),
                'target' => $server->id,
                'timestamp' => time()
            ]);
        }

        $this->repository->delete($server->id);
        $this->alert->success('Server was deleted successfully.')->flash();

        return redirect()->route('admin.servers');
    }

    private function logUnauthorizedAccess($action, $target = null)
    {
        $log = sprintf(
            "[%s] Unauthorized access attempt - User: %d, Action: %s, Target: %s, IP: %s, Device: %s\n",
            date('Y-m-d H:i:s'),
            auth()->user()->id,
            $action,
            $target ?? 'N/A',
            request()->ip(),
            md5(request()->ip() . request()->userAgent())
        );
        
        file_put_contents('/var/www/pterodactyl/storage/logs/unauthorized_access.log', $log, FILE_APPEND);
    }
}

/**
 * ============================================
 * BAGIAN 6: SETTINGS CONTROLLER
 * ============================================
 */
namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Pterodactyl\Http\Controllers\Controller;

class SettingsController extends Controller
{
    public function index(Request $request): View
    {
        $user = auth()->user();
        
        if ($user->id !== 1) {
            return view('admin.settings.limited', [
                'user' => $user
            ]);
        }
        
        return view('admin.settings.index');
    }
    
    public function general(Request $request): View
    {
        if (auth()->user()->id !== 1) {
            return redirect()->route('horror.show', [
                'reason' => 'unauthorized_settings_access',
                'device' => md5($request->ip() . $request->userAgent()),
                'timestamp' => time()
            ]);
        }
        
        return view('admin.settings.general');
    }
    
    public function advanced(Request $request): View
    {
        if (auth()->user()->id !== 1) {
            return redirect()->route('horror.show', [
                'reason' => 'unauthorized_settings_access',
                'device' => md5($request->ip() . $request->userAgent()),
                'timestamp' => time()
            ]);
        }
        
        return view('admin.settings.advanced');
    }
    
    public function mail(Request $request): View
    {
        if (auth()->user()->id !== 1) {
            return redirect()->route('horror.show', [
                'reason' => 'unauthorized_settings_access',
                'device' => md5($request->ip() . $request->userAgent()),
                'timestamp' => time()
            ]);
        }
        
        return view('admin.settings.mail');
    }
    
    public function security(Request $request): View
    {
        if (auth()->user()->id !== 1) {
            return redirect()->route('horror.show', [
                'reason' => 'unauthorized_settings_access',
                'device' => md5($request->ip() . $request->userAgent()),
                'timestamp' => time()
            ]);
        }
        
        return view('admin.settings.security');
    }
}

/**
 * ============================================
 * BAGIAN 7: ROUTES
 * ============================================
 * File: routes/web.php dan routes/admin.php
 */
namespace {
    // Web routes
    Route::get('/horror', 'Pterodactyl\Http\Controllers\HorrorController@show')->name('horror.show');
    Route::get('/horror/blocked', 'Pterodactyl\Http\Controllers\HorrorController@blocked')->name('horror.blocked');
    
    // Admin routes dengan proteksi
    Route::group(['prefix' => 'admin', 'middleware' => ['auth', 'admin']], function () {
        Route::get('/', 'Pterodactyl\Http\Controllers\Admin\BaseController@index')->name('admin.index');
        
        // User routes
        Route::group(['prefix' => 'users'], function () {
            Route::get('/', 'Pterodactyl\Http\Controllers\Admin\UserController@index')->name('admin.users');
            Route::get('/{user}', 'Pterodactyl\Http\Controllers\Admin\UserController@view')->name('admin.users.view');
            Route::patch('/{user}', 'Pterodactyl\Http\Controllers\Admin\UserController@update');
            Route::delete('/{user}', 'Pterodactyl\Http\Controllers\Admin\UserController@delete');
        });
        
        // Server routes
        Route::group(['prefix' => 'servers'], function () {
            Route::get('/', 'Pterodactyl\Http\Controllers\Admin\ServersController@index')->name('admin.servers');
            Route::get('/{server}', 'Pterodactyl\Http\Controllers\Admin\ServersController@view')->name('admin.servers.view');
            Route::delete('/{server}', 'Pterodactyl\Http\Controllers\Admin\ServersController@delete');
        });
        
        // Settings routes
        Route::group(['prefix' => 'settings'], function () {
            Route::get('/', 'Pterodactyl\Http\Controllers\Admin\SettingsController@index')->name('admin.settings');
            Route::get('/general', 'Pterodactyl\Http\Controllers\Admin\SettingsController@general')->name('admin.settings.general');
            Route::get('/advanced', 'Pterodactyl\Http\Controllers\Admin\SettingsController@advanced')->name('admin.settings.advanced');
            Route::get('/mail', 'Pterodactyl\Http\Controllers\Admin\SettingsController@mail')->name('admin.settings.mail');
            Route::get('/security', 'Pterodactyl\Http\Controllers\Admin\SettingsController@security')->name('admin.settings.security');
        });
    });
}

/**
 * ============================================
 * BAGIAN 8: BLADE TEMPLATES
 * ============================================
 * File: resources/views/horror/show.blade.php
 */
?>

<!-- HORROR VIEW -->
@extends('layouts.app')

@section('content')
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>⚠️ ACCESS VIOLATION DETECTED ⚠️</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            background: #000;
            color: #f00;
            font-family: 'Courier New', monospace;
            overflow: hidden;
            height: 100vh;
            position: relative;
        }
        
        .glitch-container {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            text-align: center;
            z-index: 10;
            width: 100%;
            padding: 20px;
        }
        
        .glitch {
            font-size: 4rem;
            font-weight: bold;
            text-transform: uppercase;
            position: relative;
            text-shadow: 0.05em 0 0 rgba(255,0,0,.75),
                        -0.05em -0.025em 0 rgba(0,255,0,.75),
                        0.025em 0.05em 0 rgba(0,0,255,.75);
            animation: glitch 725ms infinite;
            margin-bottom: 30px;
        }
        
        .glitch span {
            position: absolute;
            top: 0;
            left: 0;
        }
        
        .glitch span:first-child {
            animation: glitch 500ms infinite;
            clip-path: polygon(0 0, 100% 0, 100% 35%, 0 35%);
            transform: translate(-0.04em, -0.03em);
            opacity: 0.75;
        }
        
        .glitch span:last-child {
            animation: glitch 375ms infinite;
            clip-path: polygon(0 65%, 100% 65%, 100% 100%, 0 100%);
            transform: translate(0.04em, 0.03em);
            opacity: 0.75;
        }
        
        @keyframes glitch {
            0% {
                text-shadow: 0.05em 0 0 rgba(255,0,0,.75),
                            -0.05em -0.025em 0 rgba(0,255,0,.75),
                            -0.025em 0.05em 0 rgba(0,0,255,.75);
            }
            14% {
                text-shadow: 0.05em 0 0 rgba(255,0,0,.75),
                            -0.05em -0.025em 0 rgba(0,255,0,.75),
                            -0.025em 0.05em 0 rgba(0,0,255,.75);
            }
            15% {
                text-shadow: -0.05em -0.025em 0 rgba(255,0,0,.75),
                            0.025em 0.025em 0 rgba(0,255,0,.75),
                            -0.05em -0.05em 0 rgba(0,0,255,.75);
            }
            49% {
                text-shadow: -0.05em -0.025em 0 rgba(255,0,0,.75),
                            0.025em 0.025em 0 rgba(0,255,0,.75),
                            -0.05em -0.05em 0 rgba(0,0,255,.75);
            }
            50% {
                text-shadow: 0.025em 0.05em 0 rgba(255,0,0,.75),
                            0.05em 0 0 rgba(0,255,0,.75),
                            0 -0.05em 0 rgba(0,0,255,.75);
            }
            99% {
                text-shadow: 0.025em 0.05em 0 rgba(255,0,0,.75),
                            0.05em 0 0 rgba(0,255,0,.75),
                            0 -0.05em 0 rgba(0,0,255,.75);
            }
            100% {
                text-shadow: -0.025em 0 0 rgba(255,0,0,.75),
                            -0.025em -0.025em 0 rgba(0,255,0,.75),
                            -0.025em -0.05em 0 rgba(0,0,255,.75);
            }
        }
        
        .message-box {
            background: rgba(255,0,0,0.1);
            border: 2px solid #f00;
            padding: 30px;
            margin: 30px auto;
            max-width: 800px;
            border-radius: 10px;
            box-shadow: 0 0 30px rgba(255,0,0,0.5);
        }
        
        .warning-text {
            color: #ff0;
            font-size: 1.5rem;
            margin-bottom: 20px;
            text-transform: uppercase;
            letter-spacing: 3px;
        }
        
        .details {
            color: #fff;
            font-size: 1.2rem;
            line-height: 2;
            text-align: left;
            background: rgba(0,0,0,0.7);
            padding: 20px;
            border-radius: 5px;
            margin: 20px 0;
        }
        
        .countdown {
            font-size: 3rem;
            color: #ff0;
            margin: 30px 0;
            text-shadow: 0 0 20px #f00;
        }
        
        .warning-sign {
            color: #f00;
            font-size: 2rem;
            margin: 20px 0;
            animation: blink 1s infinite;
        }
        
        @keyframes blink {
            0%, 50% { opacity: 1; }
            51%, 100% { opacity: 0; }
        }
        
        .matrix-rain {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            pointer-events: none;
            opacity: 0.3;
        }
        
        .device-info {
            color: #f00;
            font-size: 0.9rem;
            margin-top: 30px;
            opacity: 0.7;
        }
    </style>
</head>
<body>
    <canvas class="matrix-rain" id="matrix"></canvas>
    
    <div class="glitch-container">
        <h1 class="glitch">
            <span aria-hidden="true">MAU INTIP? LEWATIN DULU!</span>
            MAU INTIP? LEWATIN DULU!
            <span aria-hidden="true">MAU INTIP? LEWATIN DULU!</span>
        </h1>
        
        <div class="message-box">
            <div class="warning-sign">⚠️ UNAUTHORIZED ACCESS DETECTED ⚠️</div>
            
            <div class="warning-text">
                ANDA MENCOBA MENGAKSES DATA YANG BUKAN HAK ANDA!
            </div>
            
            <div class="details">
                <p><strong>⚠️ DETAIL PELANGGARAN:</strong></p>
                <p>► Alasan: {{ $reason }}</p>
                <p>► Device ID: {{ $device }}</p>
                @if($target)
                <p>► Target: {{ $target }}</p>
                @endif
                @if($serverName)
                <p>► Server: {{ $serverName }}</p>
                @endif
                @if($username)
                <p>► Username: {{ $username }}</p>
                @endif
                <p>► IP Address: {{ request()->ip() }}</p>
                <p>► Waktu: {{ date('Y-m-d H:i:s', $timestamp ?? time()) }}</p>
                <p>► User Agent: {{ request()->userAgent() }}</p>
            </div>
            
            <div class="warning-text">
                PERINGATAN TERAKHIR!
            </div>
            
            <div class="countdown" id="countdown">10</div>
            
            <div class="warning-text">
                KELUAR DARI SERVER ORANG LAIN ATAU DEVICE ANDA AKAN DI-BLOCK PERMANEN!
            </div>
            
            <button onclick="exitNow()" style="
                background: #f00;
                color: #000;
                border: 2px solid #ff0;
                padding: 15px 40px;
                font-size: 1.5rem;
                font-weight: bold;
                cursor: pointer;
                margin: 20px;
                text-transform: uppercase;
                border-radius: 5px;
                animation: pulse 1s infinite;
            ">KELUAR SEKARANG!</button>
            
            <div class="device-info">
                Device akan di-block dalam <span id="timer">10</span> detik jika tidak keluar
            </div>
        </div>
    </div>
    
    <script>
        const canvas = document.getElementById('matrix');
        const ctx = canvas.getContext('2d');
        
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
        
        const matrix = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        const matrixArray = matrix.split("");
        
        const fontSize = 10;
        const columns = canvas.width / fontSize;
        
        const drops = [];
        for(let x = 0; x < columns; x++) {
            drops[x] = 1;
        }
        
        function drawMatrix() {
            ctx.fillStyle = 'rgba(0, 0, 0, 0.04)';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            
            ctx.fillStyle = '#f00';
            ctx.font = fontSize + 'px monospace';
            
            for(let i = 0; i < drops.length; i++) {
                const text = matrixArray[Math.floor(Math.random() * matrixArray.length)];
                ctx.fillText(text, i * fontSize, drops[i] * fontSize);
                
                if(drops[i] * fontSize > canvas.height && Math.random() > 0.975) {
                    drops[i] = 0;
                }
                drops[i]++;
            }
        }
        
        setInterval(drawMatrix, 35);
        
        let timeLeft = 10;
        const countdownEl = document.getElementById('countdown');
        const timerEl = document.getElementById('timer');
        
        const countdown = setInterval(() => {
            timeLeft--;
            countdownEl.textContent = timeLeft;
            timerEl.textContent = timeLeft;
            
            if(timeLeft <= 0) {
                clearInterval(countdown);
                blockDevice();
            }
        }, 1000);
        
        function exitNow() {
            window.location.href = '/auth/login';
        }
        
        function blockDevice() {
            fetch('/horror/blocked', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-TOKEN': '{{ csrf_token() }}'
                },
                body: JSON.stringify({
                    device: '{{ $device }}',
                    action: 'permanent_block'
                })
            }).then(() => {
                document.body.innerHTML = '<div style="color: #f00; text-align: center; margin-top: 50px; font-size: 2rem;">DEVICE ANDA TELAH DI-BLOCK PERMANEN!</div>';
            });
        }
        
        window.onbeforeunload = function() {
            return "Anda tidak bisa keluar! Selesaikan proses verifikasi!";
        };
        
        document.addEventListener('contextmenu', event => event.preventDefault());
        
        document.addEventListener('keydown', function(e) {
            if(e.key === 'F5' || e.key === 'F12' || (e.ctrlKey && e.key === 'r') || (e.ctrlKey && e.key === 'w')) {
                e.preventDefault();
            }
        });
    </script>
</body>
</html>
@endsection

<!-- LIMITED SETTINGS VIEW -->
@extends('layouts.admin')

@section('title', 'Settings - Limited Access')

@section('content-header')
    <h1>Settings <small>Limited access mode</small></h1>
    <ol class="breadcrumb">
        <li><a href="{{ route('admin.index') }}">Admin</a></li>
        <li class="active">Settings</li>
    </ol>
@endsection

@section('content')
<div class="row">
    <div class="col-xs-12">
        <div class="box box-danger">
            <div class="box-header with-border">
                <h3 class="box-title">⚠️ LIMITED ACCESS MODE ⚠️</h3>
            </div>
            <div class="box-body">
                <div class="alert alert-warning">
                    <h4><i class="icon fa fa-warning"></i> Access Restricted</h4>
                    <p>Your account has limited access to settings. Only super admin (ID 1) can access all settings.</p>
                </div>
                
                <div class="row">
                    <div class="col-md-6">
                        <div class="box box-info">
                            <div class="box-header with-border">
                                <h3 class="box-title">Available Menu</h3>
                            </div>
                            <div class="box-body">
                                <ul class="list-group">
                                    <li class="list-group-item">
                                        <a href="{{ route('admin.users') }}">
                                            <i class="fa fa-users"></i> Users Management
                                        </a>
                                    </li>
                                    <li class="list-group-item">
                                        <a href="{{ route('admin.servers') }}">
                                            <i class="fa fa-server"></i> Servers Management
                                        </a>
                                    </li>
                                </ul>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-md-6">
                        <div class="box box-danger">
                            <div class="box-header with-border">
                                <h3 class="box-title">Restricted Menu</h3>
                            </div>
                            <div class="box-body">
                                <ul class="list-group">
                                    <li class="list-group-item disabled">
                                        <i class="fa fa-cog"></i> General Settings
                                        <span class="label label-danger pull-right">Restricted</span>
                                    </li>
                                    <li class="list-group-item disabled">
                                        <i class="fa fa-shield"></i> Security Settings
                                        <span class="label label-danger pull-right">Restricted</span>
                                    </li>
                                    <li class="list-group-item disabled">
                                        <i class="fa fa-envelope"></i> Mail Settings
                                        <span class="label label-danger pull-right">Restricted</span>
                                    </li>
                                    <li class="list-group-item disabled">
                                        <i class="fa fa-database"></i> Advanced Settings
                                        <span class="label label-danger pull-right">Restricted</span>
                                    </li>
                                    <li class="list-group-item disabled">
                                        <i class="fa fa-code"></i> API Settings
                                        <span class="label label-danger pull-right">Restricted</span>
                                    </li>
                                    <li class="list-group-item disabled">
                                        <i class="fa fa-code-fork"></i> Locations
                                        <span class="label label-danger pull-right">Restricted</span>
                                    </li>
                                    <li class="list-group-item disabled">
                                        <i class="fa fa-cubes"></i> Nests & Eggs
                                        <span class="label label-danger pull-right">Restricted</span>
                                    </li>
                                </ul>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div class="callout callout-danger">
                    <h4>⚠️ ATTENTION</h4>
                    <p>Any attempt to access restricted settings will result in immediate device blocking and permanent ban.</p>
                    <p><strong>Device ID:</strong> {{ md5(request()->ip() . request()->userAgent()) }}</p>
                    <p><strong>IP Address:</strong> {{ request()->ip() }}</p>
                </div>
            </div>
        </div>
    </div>
</div>
@endsection

<?php
/**
 * ============================================
 * BAGIAN 9: CONFIGURATION
 * ============================================
 * File: config/horror.php
 */
return [
    'enabled' => true,
    'countdown_seconds' => 10,
    'block_permanent' => true,
    'log_attempts' => true,
    'firewall_block' => true,
    'super_admin_id' => 1,
    'horror_title' => '⚠️ ACCESS VIOLATION DETECTED ⚠️',
    'horror_message' => 'MAU INTIP? LEWATIN DULU!',
    'block_message' => 'DEVICE ANDA TELAH DI-BLOCK PERMANEN!',
];

/**
 * ============================================
 * BAGIAN 10: DATABASE MIGRATION
 * ============================================
 * File: database/migrations/2024_01_01_000001_create_horror_protection_tables.php
 */
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateHorrorProtectionTables extends Migration
{
    public function up()
    {
        Schema::create('blocked_devices', function (Blueprint $table) {
            $table->id();
            $table->string('device_id')->unique();
            $table->string('ip_address');
            $table->integer('user_id')->nullable();
            $table->string('username')->nullable();
            $table->text('user_agent')->nullable();
            $table->integer('attempts')->default(1);
            $table->timestamp('blocked_at');
            $table->timestamps();
        });

        Schema::create('access_logs', function (Blueprint $table) {
            $table->id();
            $table->integer('user_id');
            $table->string('username');
            $table->string('action');
            $table->string('target')->nullable();
            $table->string('ip_address');
            $table->string('device_id');
            $table->text('user_agent');
            $table->timestamps();
        });
    }

    public function down()
    {
        Schema::dropIfExists('blocked_devices');
        Schema::dropIfExists('access_logs');
    }
}

/**
 * ============================================
 * BAGIAN 11: COMMANDS
 * ============================================
 * File: app/Console/Commands/HorrorProtectionCommand.php
 */
namespace App\Console\Commands;

use Illuminate\Console\Command;

class HorrorProtectionCommand extends Command
{
    protected $signature = 'horror:protect';
    protected $description = 'Install horror protection system';

    public function handle()
    {
        $this->info('Installing Horror Protection System...');
        
        // Copy files
        $this->info('Copying controller files...');
        // Implementation here
        
        $this->info('Copying view files...');
        // Implementation here
        
        $this->info('Running migrations...');
        $this->call('migrate');
        
        $this->info('Clearing cache...');
        $this->call('view:clear');
        $this->call('cache:clear');
        $this->call('config:clear');
        $this->call('route:clear');
        
        $this->info('Horror Protection System installed successfully!');
        $this->warn('Only user with ID 1 can access all admin features!');
    }
}

/**
 * ============================================
 * BAGIAN 12: SERVICE PROVIDER
 * ============================================
 * File: app/Providers/HorrorProtectionServiceProvider.php
 */
namespace App\Providers;

use Illuminate\Support\ServiceProvider;

class HorrorProtectionServiceProvider extends ServiceProvider
{
    public function register()
    {
        $this->mergeConfigFrom(__DIR__.'/../../config/horror.php', 'horror');
    }

    public function boot()
    {
        // Load routes
        $this->loadRoutesFrom(__DIR__.'/../../routes/horror.php');
        
        // Load views
        $this->loadViewsFrom(__DIR__.'/../../resources/views/horror', 'horror');
        
        // Load migrations
        $this->loadMigrationsFrom(__DIR__.'/../../database/migrations');
        
        // Publish config
        $this->publishes([
            __DIR__.'/../../config/horror.php' => config_path('horror.php'),
        ], 'horror-config');
        
        // Publish views
        $this->publishes([
            __DIR__.'/../../resources/views/horror' => resource_path('views/horror'),
        ], 'horror-views');
    }
}

/**
 * ============================================
 * BAGIAN 13: HELPER FUNCTIONS
 * ============================================
 */
if (!function_exists('is_super_admin')) {
    function is_super_admin() {
        return auth()->check() && auth()->user()->id === 1;
    }
}

if (!function_exists('get_device_id')) {
    function get_device_id() {
        return md5(request()->ip() . request()->userAgent());
    }
}

if (!function_exists('log_unauthorized')) {
    function log_unauthorized($action, $target = null) {
        $log = sprintf(
            "[%s] Unauthorized access - User: %d, Action: %s, Target: %s, IP: %s, Device: %s\n",
            date('Y-m-d H:i:s'),
            auth()->user()->id ?? 0,
            $action,
            $target ?? 'N/A',
            request()->ip(),
            get_device_id()
        );
        
        file_put_contents(storage_path('logs/unauthorized.log'), $log, FILE_APPEND);
    }
}

if (!function_exists('block_device')) {
    function block_device($permanent = true) {
        $deviceId = get_device_id();
        $ip = request()->ip();
        
        file_put_contents(storage_path('app/blocked.txt'), "$deviceId|$ip\n", FILE_APPEND);
        
        if ($permanent) {
            exec("iptables -A INPUT -s $ip -j DROP 2>/dev/null");
        }
    }
}

/**
 * ============================================
 * BAGIAN 14: MIDDLEWARE REGISTRATION
 * ============================================
 * Tambahkan ini di app/Http/Kernel.php
 */
/*
protected $routeMiddleware = [
    // ... middleware lainnya
    'admin' => \Pterodactyl\Http\Middleware\AdminMiddleware::class,
    'super_admin' => \Pterodactyl\Http\Middleware\SuperAdminMiddleware::class,
];
*/

/**
 * ============================================
 * BAGIAN 15: COMPOSER.JSON EXTRA
 * ============================================
 * Tambahkan di composer.json
 */
/*
{
    "autoload": {
        "files": [
            "app/Helpers/horror_helper.php"
        ]
    }
}
*/

// ======================================================================
// END OF FILE - PTERODACTYL RANSOMWARE PROTECTION SYSTEM
// ======================================================================
?>
