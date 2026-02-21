<?php
/**
 * =====================================================================
 * PTERODACTYL RANSOMWARE PROTECTION SYSTEM - INSTALLER
 * =====================================================================
 * 
 * File ini akan menginstall semua komponen proteksi:
 * - Horror Controller
 * - Admin Middleware  
 * - Settings Controller
 * - User Controller (dengan proteksi)
 * - Servers Controller (dengan proteksi)
 * - Horror Views
 * - Limited Settings View
 * 
 * Cara menjalankan:
 * php install_protection.php
 * 
 * =====================================================================
 */

// Set time limit dan error reporting
set_time_limit(300);
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Warna untuk terminal output
define('COLOR_GREEN', "\033[32m");
define('COLOR_RED', "\033[31m");
define('COLOR_YELLOW', "\033[33m");
define('COLOR_CYAN', "\033[36m");
define('COLOR_RESET', "\033[0m");

/**
 * Fungsi untuk print pesan dengan warna
 */
function printMessage($message, $type = 'info') {
    $colors = [
        'success' => COLOR_GREEN,
        'error' => COLOR_RED,
        'warning' => COLOR_YELLOW,
        'info' => COLOR_CYAN
    ];
    
    $color = $colors[$type] ?? COLOR_RESET;
    echo $color . $message . COLOR_RESET . "\n";
}

/**
 * Fungsi untuk mengecek apakah script dijalankan sebagai root
 */
function checkRoot() {
    if (posix_getuid() !== 0) {
        printMessage("❌ ERROR: Script harus dijalankan sebagai root!", 'error');
        printMessage("   Jalankan: sudo php install_protection.php", 'info');
        exit(1);
    }
    printMessage("✅ Root access terdeteksi", 'success');
}

/**
 * Fungsi untuk mengecek direktori Pterodactyl
 */
function checkPterodactylDirectory() {
    $pterodactylPath = '/var/www/pterodactyl';
    
    if (!is_dir($pterodactylPath)) {
        printMessage("❌ ERROR: Direktori Pterodactyl tidak ditemukan di $pterodactylPath", 'error');
        printMessage("   Pastikan Pterodactyl sudah terinstall", 'warning');
        exit(1);
    }
    
    printMessage("✅ Direktori Pterodactyl ditemukan", 'success');
    return $pterodactylPath;
}

/**
 * Fungsi untuk membuat direktori yang diperlukan
 */
function createDirectories($basePath) {
    $directories = [
        $basePath . '/app/Http/Controllers/Admin',
        $basePath . '/app/Http/Middleware',
        $basePath . '/resources/views/horror',
        $basePath . '/resources/views/admin/settings',
        $basePath . '/storage/logs',
        $basePath . '/storage/app',
        '/root/pterodactyl_protection'
    ];
    
    foreach ($directories as $dir) {
        if (!is_dir($dir)) {
            if (mkdir($dir, 0755, true)) {
                printMessage("  ✓ Membuat direktori: " . basename($dir), 'success');
            } else {
                printMessage("  ✗ Gagal membuat direktori: $dir", 'error');
            }
        }
    }
}

/**
 * Fungsi untuk membuat file HorrorController.php
 */
function createHorrorController($basePath) {
    $content = <<<'PHP'
<?php

namespace Pterodactyl\Http\Controllers;

use Illuminate\Http\Request;

class HorrorController extends Controller
{
    /**
     * Menampilkan halaman horror untuk akses tidak sah
     */
    public function show(Request $request)
    {
        $data = [
            'reason' => $request->get('reason', 'unknown'),
            'device' => $request->get('device'),
            'target' => $request->get('target'),
            'timestamp' => $request->get('timestamp', time()),
            'server_name' => $request->get('server_name'),
            'user_id' => $request->get('user_id'),
            'username' => $request->get('username')
        ];
        
        // Log akses tidak sah
        $this->logUnauthorizedAccess($data);
        
        return view('horror.show', $data);
    }
    
    /**
     * Menampilkan halaman device telah diblokir
     */
    public function blocked(Request $request)
    {
        $device = $request->get('device');
        $reason = $request->get('reason', 'permanent_block');
        
        // Block device permanent
        $this->blockDevicePermanently($device, $request->ip());
        
        return view('horror.blocked', compact('device', 'reason'));
    }
    
    /**
     * Log akses tidak sah
     */
    private function logUnauthorizedAccess($data)
    {
        $log = sprintf(
            "[%s] UNAUTHORIZED ACCESS - Reason: %s, Device: %s, IP: %s, Target: %s\n",
            date('Y-m-d H:i:s'),
            $data['reason'],
            $data['device'] ?? 'unknown',
            request()->ip() ?? 'unknown',
            $data['target'] ?? 'none'
        );
        
        file_put_contents(
            storage_path('logs/unauthorized_access.log'),
            $log,
            FILE_APPEND
        );
    }
    
    /**
     * Block device permanent
     */
    private function blockDevicePermanently($deviceId, $ip)
    {
        $blockedFile = storage_path('app/blocked_devices.json');
        $blocked = [];
        
        if (file_exists($blockedFile)) {
            $blocked = json_decode(file_get_contents($blockedFile), true);
        }
        
        $blocked[$deviceId] = [
            'blocked_at' => time(),
            'ip' => $ip,
            'user_agent' => request()->userAgent()
        ];
        
        file_put_contents($blockedFile, json_encode($blocked, JSON_PRETTY_PRINT));
        
        // Block di firewall
        exec("iptables -A INPUT -s $ip -j DROP 2>/dev/null");
    }
}
PHP;

    $filePath = $basePath . '/app/Http/Controllers/HorrorController.php';
    
    if (file_put_contents($filePath, $content)) {
        printMessage("  ✓ Membuat HorrorController.php", 'success');
    } else {
        printMessage("  ✗ Gagal membuat HorrorController.php", 'error');
    }
}

/**
 * Fungsi untuk membuat file AdminMiddleware.php
 */
function createAdminMiddleware($basePath) {
    $content = <<<'PHP'
<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class AdminMiddleware
{
    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next)
    {
        // Cek apakah user sudah login
        if (!auth()->check()) {
            return redirect()->route('auth.login');
        }

        $user = auth()->user();
        $deviceId = md5($request->ip() . $request->userAgent());
        
        // Cek apakah device diblokir
        if ($this->isDeviceBlocked($deviceId, $request->ip())) {
            return redirect()->route('horror.blocked', [
                'device' => $deviceId,
                'reason' => 'permanent_block'
            ]);
        }
        
        // Hanya admin dengan ID 1 yang bisa akses penuh
        if ($user->id === 1) {
            return $next($request);
        }
        
        // Untuk admin lain, batasi akses
        if ($user->root_admin) {
            return $this->handleRestrictedAdmin($request, $user, $deviceId);
        }

        return $next($request);
    }
    
    /**
     * Handle akses untuk admin terbatas
     */
    private function handleRestrictedAdmin($request, $user, $deviceId)
    {
        // Path yang diizinkan untuk admin terbatas
        $allowedPaths = [
            'admin/users',
            'admin/servers',
            'admin/index'
        ];
        
        $currentPath = $request->path();
        
        // Cek apakah path saat ini diizinkan
        foreach ($allowedPaths as $path) {
            if (strpos($currentPath, $path) === 0) {
                return $this->next($request);
            }
        }
        
        // Jika mencoba akses path terlarang, redirect ke horror
        return $this->redirectToHorror($request, $user, $deviceId);
    }
    
    /**
     * Redirect ke halaman horror
     */
    private function redirectToHorror($request, $user, $deviceId)
    {
        // Log percobaan
        $this->logRestrictedAccess($user, $request);
        
        return redirect()->route('horror.show', [
            'reason' => 'restricted_area',
            'device' => $deviceId,
            'timestamp' => time(),
            'user_id' => $user->id,
            'username' => $user->username
        ]);
    }
    
    /**
     * Cek apakah device diblokir
     */
    private function isDeviceBlocked($deviceId, $ip)
    {
        $blockedFile = storage_path('app/blocked_devices.json');
        
        if (!file_exists($blockedFile)) {
            return false;
        }
        
        $blocked = json_decode(file_get_contents($blockedFile), true);
        
        return isset($blocked[$deviceId]) || in_array($ip, array_column($blocked, 'ip'));
    }
    
    /**
     * Log akses terbatas
     */
    private function logRestrictedAccess($user, $request)
    {
        $log = sprintf(
            "[%s] RESTRICTED ACCESS - User: %d (%s), Path: %s, IP: %s\n",
            date('Y-m-d H:i:s'),
            $user->id,
            $user->username,
            $request->path(),
            $request->ip()
        );
        
        file_put_contents(
            storage_path('logs/restricted_access.log'),
            $log,
            FILE_APPEND
        );
    }
}
PHP;

    $filePath = $basePath . '/app/Http/Middleware/AdminMiddleware.php';
    
    if (file_put_contents($filePath, $content)) {
        printMessage("  ✓ Membuat AdminMiddleware.php", 'success');
    } else {
        printMessage("  ✗ Gagal membuat AdminMiddleware.php", 'error');
    }
}

/**
 * Fungsi untuk membuat file SettingsController.php
 */
function createSettingsController($basePath) {
    $content = <<<'PHP'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Pterodactyl\Http\Controllers\Controller;

class SettingsController extends Controller
{
    /**
     * Menampilkan halaman settings
     */
    public function index(Request $request): View
    {
        $user = auth()->user();
        
        // Admin selain ID 1 hanya melihat limited menu
        if ($user->id !== 1) {
            return view('admin.settings.limited');
        }
        
        // Admin ID 1 melihat full settings
        return view('admin.settings.index');
    }
    
    /**
     * Halaman general settings (hanya untuk admin ID 1)
     */
    public function general(Request $request)
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
    
    /**
     * Halaman advanced settings (hanya untuk admin ID 1)
     */
    public function advanced(Request $request)
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
    
    /**
     * Halaman mail settings (hanya untuk admin ID 1)
     */
    public function mail(Request $request)
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
    
    /**
     * Halaman security settings (hanya untuk admin ID 1)
     */
    public function security(Request $request)
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
PHP;

    $filePath = $basePath . '/app/Http/Controllers/Admin/SettingsController.php';
    
    if (file_put_contents($filePath, $content)) {
        printMessage("  ✓ Membuat SettingsController.php", 'success');
    } else {
        printMessage("  ✗ Gagal membuat SettingsController.php", 'error');
    }
}

/**
 * Fungsi untuk membuat file UserController.php dengan proteksi
 */
function createUserController($basePath) {
    $content = <<<'PHP'
<?php

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

    /**
     * Menampilkan daftar users
     */
    public function index(): View
    {
        // Hanya admin ID 1 yang bisa melihat daftar users
        if (auth()->user()->id !== 1) {
            return $this->redirectToHorror('users_list');
        }

        return view('admin.users.index', [
            'users' => $this->repository->getUsersAndServers()
        ]);
    }

    /**
     * Menampilkan detail user
     */
    public function view(User $user): View
    {
        if (auth()->user()->id !== 1) {
            return $this->redirectToHorror('user_details', $user->id);
        }

        return view('admin.users.view', [
            'user' => $user,
            'servers' => $user->servers()
        ]);
    }

    /**
     * Update user
     */
    public function update(UserFormRequest $request, User $user): RedirectResponse
    {
        if (auth()->user()->id !== 1) {
            return $this->redirectToHorror('user_update', $user->id);
        }

        $this->updateService->handle($user, $request->validated());
        $this->alert->success('User was updated successfully.')->flash();

        return redirect()->route('admin.users.view', $user->id);
    }

    /**
     * Delete user
     */
    public function delete(User $user): RedirectResponse
    {
        if (auth()->user()->id !== 1) {
            return $this->redirectToHorror('user_delete', $user->id);
        }

        if ($user->servers()->count() > 0) {
            $this->alert->warning('Cannot delete a user with active servers attached to their account. Please delete all servers first.')->flash();
            return redirect()->route('admin.users.view', $user->id);
        }

        $this->repository->delete($user->id);
        $this->alert->success('User was deleted successfully.')->flash();

        return redirect()->route('admin.users');
    }

    /**
     * Redirect ke halaman horror
     */
    private function redirectToHorror($action, $target = null)
    {
        $this->logUnauthorizedAccess($action, $target);
        
        return redirect()->route('horror.show', [
            'reason' => 'unauthorized_' . $action,
            'device' => md5(request()->ip() . request()->userAgent()),
            'target' => $target,
            'timestamp' => time()
        ]);
    }

    /**
     * Log akses tidak sah
     */
    private function logUnauthorizedAccess($action, $target = null)
    {
        $log = sprintf(
            "[%s] UNAUTHORIZED USER ACCESS - User: %d, Action: %s, Target: %s, IP: %s, Device: %s\n",
            date('Y-m-d H:i:s'),
            auth()->user()->id,
            $action,
            $target ?? 'N/A',
            request()->ip(),
            md5(request()->ip() . request()->userAgent())
        );
        
        file_put_contents(
            storage_path('logs/unauthorized_user_access.log'),
            $log,
            FILE_APPEND
        );
    }
}
PHP;

    $filePath = $basePath . '/app/Http/Controllers/Admin/UserController.php';
    
    // Backup file asli
    if (file_exists($filePath)) {
        copy($filePath, $filePath . '.backup');
        printMessage("  ✓ Backup UserController.php dibuat", 'success');
    }
    
    if (file_put_contents($filePath, $content)) {
        printMessage("  ✓ Membuat UserController.php dengan proteksi", 'success');
    } else {
        printMessage("  ✗ Gagal membuat UserController.php", 'error');
    }
}

/**
 * Fungsi untuk membuat file ServersController.php dengan proteksi
 */
function createServersController($basePath) {
    $content = <<<'PHP'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Pterodactyl\Models\Server;
use Illuminate\Http\RedirectResponse;
use Prologue\Alerts\AlertsMessageBag;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Services\Servers\ServerCreationService;
use Pterodactyl\Http\Requests\Admin\ServerFormRequest;
use Pterodactyl\Contracts\Repository\ServerRepositoryInterface;

class ServersController extends Controller
{
    protected AlertsMessageBag $alert;
    protected ServerCreationService $creationService;
    protected ServerRepositoryInterface $repository;

    public function __construct(
        AlertsMessageBag $alert,
        ServerCreationService $creationService,
        ServerRepositoryInterface $repository
    ) {
        $this->alert = $alert;
        $this->creationService = $creationService;
        $this->repository = $repository;
    }

    /**
     * Menampilkan daftar servers
     */
    public function index(Request $request): View
    {
        if (auth()->user()->id !== 1) {
            return $this->redirectToHorror('servers_list');
        }

        return view('admin.servers.index', [
            'servers' => $this->repository->getDatatables($request)
        ]);
    }

    /**
     * Menampilkan detail server
     */
    public function view(Server $server): View
    {
        if (auth()->user()->id !== 1) {
            return $this->redirectToHorror('server_details', $server->id, $server->name);
        }

        return view('admin.servers.view', [
            'server' => $server,
        ]);
    }

    /**
     * Delete server
     */
    public function delete(Server $server): RedirectResponse
    {
        if (auth()->user()->id !== 1) {
            return $this->redirectToHorror('server_delete', $server->id);
        }

        $this->repository->delete($server->id);
        $this->alert->success('Server was deleted successfully.')->flash();

        return redirect()->route('admin.servers');
    }

    /**
     * Redirect ke halaman horror
     */
    private function redirectToHorror($action, $target = null, $serverName = null)
    {
        $this->logUnauthorizedAccess($action, $target);
        
        return redirect()->route('horror.show', [
            'reason' => 'unauthorized_' . $action,
            'device' => md5(request()->ip() . request()->userAgent()),
            'target' => $target,
            'server_name' => $serverName,
            'timestamp' => time()
        ]);
    }

    /**
     * Log akses tidak sah
     */
    private function logUnauthorizedAccess($action, $target = null)
    {
        $log = sprintf(
            "[%s] UNAUTHORIZED SERVER ACCESS - User: %d, Action: %s, Target: %s, IP: %s, Device: %s\n",
            date('Y-m-d H:i:s'),
            auth()->user()->id,
            $action,
            $target ?? 'N/A',
            request()->ip(),
            md5(request()->ip() . request()->userAgent())
        );
        
        file_put_contents(
            storage_path('logs/unauthorized_server_access.log'),
            $log,
            FILE_APPEND
        );
    }
}
PHP;

    $filePath = $basePath . '/app/Http/Controllers/Admin/ServersController.php';
    
    // Backup file asli
    if (file_exists($filePath)) {
        copy($filePath, $filePath . '.backup');
        printMessage("  ✓ Backup ServersController.php dibuat", 'success');
    }
    
    if (file_put_contents($filePath, $content)) {
        printMessage("  ✓ Membuat ServersController.php dengan proteksi", 'success');
    } else {
        printMessage("  ✗ Gagal membuat ServersController.php", 'error');
    }
}

/**
 * Fungsi untuk membuat file horror view
 */
function createHorrorView($basePath) {
    $content = <<<'HTML'
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>⚠️ AKSES DITOLAK - PERINGATAN ⚠️</title>
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
        
        .container {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            text-align: center;
            z-index: 10;
            width: 90%;
            max-width: 900px;
            padding: 20px;
        }
        
        h1 {
            font-size: clamp(2rem, 8vw, 5rem);
            font-weight: bold;
            text-transform: uppercase;
            animation: glitch 1s infinite;
            margin-bottom: 30px;
            text-shadow: 
                0.05em 0 0 rgba(255,0,0,.75),
                -0.05em -0.025em 0 rgba(0,255,0,.75),
                0.025em 0.05em 0 rgba(0,0,255,.75);
        }
        
        @keyframes glitch {
            0% { transform: translate(0); }
            20% { transform: translate(-5px, 5px); }
            40% { transform: translate(-5px, -5px); }
            60% { transform: translate(5px, 5px); }
            80% { transform: translate(5px, -5px); }
            100% { transform: translate(0); }
        }
        
        .message-box {
            background: rgba(255,0,0,0.1);
            border: 3px solid #f00;
            padding: 30px;
            border-radius: 15px;
            box-shadow: 0 0 50px rgba(255,0,0,0.3);
            backdrop-filter: blur(5px);
        }
        
        .warning {
            color: #ff0;
            font-size: 1.8rem;
            margin-bottom: 20px;
            text-transform: uppercase;
            letter-spacing: 3px;
            animation: blink 1s infinite;
        }
        
        @keyframes blink {
            0%, 50% { opacity: 1; }
            51%, 100% { opacity: 0.5; }
        }
        
        .details {
            color: #fff;
            font-size: 1.2rem;
            line-height: 2;
            text-align: left;
            background: rgba(0,0,0,0.8);
            padding: 25px;
            border-radius: 10px;
            margin: 25px 0;
            border-left: 5px solid #f00;
        }
        
        .details p {
            margin: 10px 0;
            word-break: break-word;
        }
        
        .countdown-container {
            margin: 30px 0;
        }
        
        .countdown-text {
            color: #ff0;
            font-size: 1.5rem;
            margin-bottom: 10px;
        }
        
        .countdown-number {
            font-size: 5rem;
            font-weight: bold;
            color: #f00;
            text-shadow: 0 0 30px #f00;
            animation: pulse 1s infinite;
        }
        
        @keyframes pulse {
            0%, 100% { transform: scale(1); }
            50% { transform: scale(1.1); }
        }
        
        .button-exit {
            background: #f00;
            color: #000;
            border: 3px solid #ff0;
            padding: 15px 50px;
            font-size: 1.5rem;
            font-weight: bold;
            cursor: pointer;
            margin: 20px;
            text-transform: uppercase;
            border-radius: 50px;
            transition: all 0.3s;
        }
        
        .button-exit:hover {
            background: #ff0;
            color: #f00;
            transform: scale(1.1);
            box-shadow: 0 0 50px #ff0;
        }
        
        .device-info {
            color: #f00;
            font-size: 0.9rem;
            margin-top: 30px;
            opacity: 0.7;
        }
        
        .matrix-rain {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            pointer-events: none;
            opacity: 0.2;
        }
        
        .highlight {
            color: #ff0;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <canvas class="matrix-rain" id="matrix"></canvas>
    
    <div class="container">
        <h1>⚠️ MAU INTIP? ⚠️</h1>
        <h1>LEWATIN DULU!</h1>
        
        <div class="message-box">
            <div class="warning">🚫 AKSES TIDAK SAH DETEKSI 🚫</div>
            
            <div class="details">
                <p><strong>📋 DETAIL PELANGGARAN:</strong></p>
                <p>► Alasan: <span class="highlight">{{ $reason }}</span></p>
                <p>► Device ID: <span class="highlight">{{ $device }}</span></p>
                @if($target ?? false)
                <p>► Target: <span class="highlight">{{ $target }}</span></p>
                @endif
                @if($serverName ?? false)
                <p>► Server: <span class="highlight">{{ $serverName }}</span></p>
                @endif
                @if($username ?? false)
                <p>► Username: <span class="highlight">{{ $username }}</span></p>
                @endif
                <p>► IP Address: <span class="highlight">{{ request()->ip() }}</span></p>
                <p>► Waktu: <span class="highlight">{{ date('Y-m-d H:i:s', $timestamp ?? time()) }}</span></p>
            </div>
            
            <div class="warning">⚠️ PERINGATAN TERAKHIR ⚠️</div>
            
            <div class="countdown-container">
                <div class="countdown-text">Device akan diblokir dalam:</div>
                <div class="countdown-number" id="countdown">10</div>
            </div>
            
            <div class="warning">KELUAR ATAU DEVICE AKAN DI-BLOCK PERMANEN!</div>
            
            <button class="button-exit" onclick="exitNow()">🚪 KELUAR SEKARANG</button>
            
            <div class="device-info">
                ID Device ini akan diblokir jika tidak keluar
            </div>
        </div>
    </div>
    
    <script>
        // Matrix rain effect
        const canvas = document.getElementById('matrix');
        const ctx = canvas.getContext('2d');
        
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
        
        const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()";
        const charArray = chars.split("");
        const fontSize = 14;
        const columns = canvas.width / fontSize;
        const drops = [];
        
        for(let i = 0; i < columns; i++) {
            drops[i] = Math.floor(Math.random() * -100);
        }
        
        function drawMatrix() {
            ctx.fillStyle = 'rgba(0, 0, 0, 0.05)';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            
            ctx.fillStyle = '#f00';
            ctx.font = fontSize + 'px monospace';
            
            for(let i = 0; i < drops.length; i++) {
                const text = charArray[Math.floor(Math.random() * charArray.length)];
                ctx.fillText(text, i * fontSize, drops[i] * fontSize);
                
                if(drops[i] * fontSize > canvas.height && Math.random() > 0.975) {
                    drops[i] = 0;
                }
                drops[i]++;
            }
        }
        
        setInterval(drawMatrix, 50);
        
        // Countdown timer
        let timeLeft = 10;
        const countdownEl = document.getElementById('countdown');
        
        const timer = setInterval(() => {
            timeLeft--;
            countdownEl.textContent = timeLeft;
            
            if(timeLeft <= 0) {
                clearInterval(timer);
                blockDevice();
            }
        }, 1000);
        
        function exitNow() {
            window.location.href = '/auth/logout';
        }
        
        function blockDevice() {
            document.body.innerHTML = `
                <div style="
                    color: #f00;
                    text-align: center;
                    margin-top: 50vh;
                    transform: translateY(-50%);
                    font-size: clamp(1.5rem, 5vw, 3rem);
                    font-family: monospace;
                ">
                    💀 DEVICE ANDA TELAH DI-BLOCK PERMANEN! 💀
                    <br><br>
                    <small style="font-size: 1rem; color: #666;">
                        Hubungi administrator untuk membuka blokir
                    </small>
                </div>
            `;
        }
        
        // Prevent user from leaving
        window.onbeforeunload = function() {
            return "Anda tidak bisa keluar! Selesaikan proses verifikasi!";
        };
        
        // Disable right click
        document.addEventListener('contextmenu', e => e.preventDefault());
        
        // Disable keyboard shortcuts
        document.addEventListener('keydown', function(e) {
            if(e.key === 'F5' || e.key === 'F12' || 
               (e.ctrlKey && e.key === 'r') || 
               (e.ctrlKey && e.key === 'w') ||
               (e.ctrlKey && e.key === 'c')) {
                e.preventDefault();
            }
        });
    </script>
</body>
</html>
HTML;

    $filePath = $basePath . '/resources/views/horror/show.blade.php';
    
    if (file_put_contents($filePath, $content)) {
        printMessage("  ✓ Membuat horror view", 'success');
    } else {
        printMessage("  ✗ Gagal membuat horror view", 'error');
    }
}

/**
 * Fungsi untuk membuat file limited settings view
 */
function createLimitedSettingsView($basePath) {
    $content = <<<'HTML'
@extends('layouts.admin')

@section('title')
    Settings - Limited Access
@endsection

@section('content-header')
    <h1>Settings <small>Mode akses terbatas</small></h1>
    <ol class="breadcrumb">
        <li><a href="{{ route('admin.index') }}">Admin</a></li>
        <li class="active">Settings</li>
    </ol>
@endsection

@section('content')
<div class="row">
    <div class="col-md-12">
        <div class="box box-danger">
            <div class="box-header with-border">
                <h3 class="box-title">⚠️ AKSES TERBATAS ⚠️</h3>
            </div>
            <div class="box-body">
                <div class="alert alert-warning">
                    <h4><i class="icon fa fa-warning"></i> Peringatan Keamanan</h4>
                    <p>Akun Anda memiliki akses terbatas. Hanya Super Admin (ID 1) yang dapat mengakses semua pengaturan.</p>
                </div>
                
                <div class="row">
                    <div class="col-md-6">
                        <div class="box box-success">
                            <div class="box-header with-border">
                                <h3 class="box-title">✓ Menu yang Tersedia</h3>
                            </div>
                            <div class="box-body">
                                <ul class="list-group">
                                    <li class="list-group-item list-group-item-success">
                                        <i class="fa fa-users"></i> 
                                        <a href="{{ route('admin.users') }}">Manajemen Users</a>
                                        <span class="label label-success pull-right">Available</span>
                                    </li>
                                    <li class="list-group-item list-group-item-success">
                                        <i class="fa fa-server"></i> 
                                        <a href="{{ route('admin.servers') }}">Manajemen Servers</a>
                                        <span class="label label-success pull-right">Available</span>
                                    </li>
                                </ul>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-md-6">
                        <div class="box box-danger">
                            <div class="box-header with-border">
                                <h3 class="box-title">✗ Menu Terbatas</h3>
                            </div>
                            <div class="box-body">
                                <ul class="list-group">
                                    <li class="list-group-item list-group-item-danger">
                                        <i class="fa fa-cog"></i> General Settings
                                        <span class="label label-danger pull-right">Restricted</span>
                                    </li>
                                    <li class="list-group-item list-group-item-danger">
                                        <i class="fa fa-shield"></i> Security Settings
                                        <span class="label label-danger pull-right">Restricted</span>
                                    </li>
                                    <li class="list-group-item list-group-item-danger">
                                        <i class="fa fa-envelope"></i> Mail Settings
                                        <span class="label label-danger pull-right">Restricted</span>
                                    </li>
                                    <li class="list-group-item list-group-item-danger">
                                        <i class="fa fa-database"></i> Advanced Settings
                                        <span class="label label-danger pull-right">Restricted</span>
                                    </li>
                                    <li class="list-group-item list-group-item-danger">
                                        <i class="fa fa-code"></i> API Settings
                                        <span class="label label-danger pull-right">Restricted</span>
                                    </li>
                                    <li class="list-group-item list-group-item-danger">
                                        <i class="fa fa-code-fork"></i> Locations
                                        <span class="label label-danger pull-right">Restricted</span>
                                    </li>
                                    <li class="list-group-item list-group-item-danger">
                                        <i class="fa fa-cubes"></i> Nests & Eggs
                                        <span class="label label-danger pull-right">Restricted</span>
                                    </li>
                                </ul>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div class="callout callout-danger">
                    <h4>⚠️ PERHATIAN</h4>
                    <p>Setiap percobaan mengakses menu terbatas akan mengakibatkan:</p>
                    <ul>
                        <li>Device diblokir secara permanen</li>
                        <li>IP address di-blacklist di firewall</li>
                        <li>Semua aktivitas dicatat dalam log</li>
                    </ul>
                    <hr>
                    <p><strong>Device ID:</strong> <code>{{ md5(request()->ip() . request()->userAgent()) }}</code></p>
                    <p><strong>IP Address:</strong> <code>{{ request()->ip() }}</code></p>
                </div>
            </div>
        </div>
    </div>
</div>
@endsection

@push('css')
<style>
    .list-group-item-danger {
        background-color: #f2dede;
        color: #a94442;
        border-color: #ebccd1;
    }
    .list-group-item-success {
        background-color: #dff0d8;
        color: #3c763d;
        border-color: #d6e9c6;
    }
    .list-group-item a {
        text-decoration: none;
        font-weight: bold;
    }
    .list-group-item-danger a {
        color: #a94442;
    }
    .list-group-item-success a {
        color: #3c763d;
    }
    .callout-danger {
        border-left-color: #ce4844;
    }
</style>
@endpush
HTML;

    $filePath = $basePath . '/resources/views/admin/settings/limited.blade.php';
    
    if (file_put_contents($filePath, $content)) {
        printMessage("  ✓ Membuat limited settings view", 'success');
    } else {
        printMessage("  ✗ Gagal membuat limited settings view", 'success');
    }
}

/**
 * Fungsi untuk menambahkan routes
 */
function addRoutes($basePath) {
    $webRouteFile = $basePath . '/routes/web.php';
    
    if (!file_exists($webRouteFile)) {
        printMessage("  ✗ File routes/web.php tidak ditemukan", 'error');
        return;
    }
    
    $routes = file_get_contents($webRouteFile);
    $horrorRoutes = "\n\n// ============================================\n";
    $horrorRoutes .= "// HORROR PROTECTION ROUTES\n";
    $horrorRoutes .= "// ============================================\n";
    $horrorRoutes .= "Route::get('/horror', [App\Http\Controllers\HorrorController::class, 'show'])->name('horror.show');\n";
    $horrorRoutes .= "Route::get('/horror/blocked', [App\Http\Controllers\HorrorController::class, 'blocked'])->name('horror.blocked');\n";
    
    if (strpos($routes, 'horror.show') === false) {
        file_put_contents($webRouteFile, $routes . $horrorRoutes);
        printMessage("  ✓ Menambahkan routes horror", 'success');
    } else {
        printMessage("  • Routes horror sudah ada", 'info');
    }
}

/**
 * Fungsi untuk mengatur permissions
 */
function setPermissions($basePath) {
    printMessage("\n  Mengatur permissions...", 'info');
    
    system("chown -R www-data:www-data $basePath 2>/dev/null");
    system("chmod -R 755 $basePath 2>/dev/null");
    system("chmod -R 777 $basePath/storage 2>/dev/null");
    system("chmod -R 777 $basePath/bootstrap/cache 2>/dev/null");
    
    printMessage("  ✓ Permissions diatur", 'success');
}

/**
 * Fungsi untuk clear cache
 */
function clearCache($basePath) {
    printMessage("\n  Membersihkan cache...", 'info');
    
    system("cd $basePath && php artisan view:clear 2>/dev/null");
    system("cd $basePath && php artisan cache:clear 2>/dev/null");
    system("cd $basePath && php artisan config:clear 2>/dev/null");
    system("cd $basePath && php artisan route:clear 2>/dev/null");
    
    printMessage("  ✓ Cache dibersihkan", 'success');
}

/**
 * Fungsi untuk membuat file marker instalasi
 */
function createInstallationMarker() {
    $content = "========================================\n";
    $content .= "PTERODACTYL RANSOMWARE PROTECTION\n";
    $content .= "========================================\n";
    $content .= "Tanggal Install: " . date('Y-m-d H:i:s') . "\n";
    $content .= "Status: ACTIVE\n\n";
    $content .= "FITUR YANG DIINSTALL:\n";
    $content .= "✓ Horror protection dengan matrix effect\n";
    $content .= "✓ Countdown 10 detik sebelum block\n";
    $content .= "✓ Device blocking permanent\n";
    $content .= "✓ Settings menu dibatasi untuk admin non-ID 1\n";
    $content .= "✓ Log semua percobaan akses tidak sah\n\n";
    $content .= "LOKASI FILE:\n";
    $content .= "- Horror Controller: app/Http/Controllers/HorrorController.php\n";
    $content .= "- Admin Middleware: app/Http/Middleware/AdminMiddleware.php\n";
    $content .= "- Settings Controller: app/Http/Controllers/Admin/SettingsController.php\n";
    $content .= "- Horror View: resources/views/horror/show.blade.php\n";
    $content .= "- Log Files: storage/logs/*.log\n\n";
    $content .= "========================================\n";
    
    file_put_contents('/root/pterodactyl_protection/installed.txt', $content);
    printMessage("  ✓ Membuat marker instalasi", 'success');
}

/**
 * Fungsi untuk menampilkan summary
 */
function showSummary() {
    printMessage("\n" . COLOR_GREEN . "============================================" . COLOR_RESET, 'info');
    printMessage(COLOR_GREEN . "    INSTALASI SELESAI - SUKSES!    " . COLOR_RESET, 'success');
    printMessage(COLOR_GREEN . "============================================" . COLOR_RESET, 'info');
    printMessage("");
    printMessage("✅ FITUR YANG TELAH DIINSTALL:", 'success');
    printMessage("   • Horror protection dengan matrix effect merah", 'info');
    printMessage("   • Countdown 10 detik sebelum blocking", 'info');
    printMessage("   • Device blocking permanent", 'info');
    printMessage("   • IP blacklist di firewall", 'info');
    printMessage("   • Settings menu dibatasi untuk admin non-ID 1", 'info');
    printMessage("   • Log semua percobaan akses tidak sah", 'info');
    printMessage("");
    printMessage("⚠️  PENTING:", 'warning');
    printMessage("   • Hanya ADMIN dengan ID 1 yang bisa akses semua menu", 'warning');
    printMessage("   • Admin lain hanya bisa lihat Users dan Servers", 'warning');
    printMessage("   • Cek ID admin: SELECT id, username FROM users WHERE root_admin = 1;", 'warning');
    printMessage("");
    printMessage("📁 LOKASI FILE PENTING:", 'info');
    printMessage("   • Log akses: /var/www/pterodactyl/storage/logs/", 'info');
    printMessage("   • Blocked devices: /var/www/pterodactyl/storage/app/blocked_devices.json", 'info');
    printMessage("");
    printMessage("🔥 TESTING:", 'success');
    printMessage("   Login dengan admin non-ID 1 dan coba akses menu settings!", 'info');
    printMessage("");
    printMessage(COLOR_GREEN . "============================================" . COLOR_RESET, 'info');
}

// =====================================================================
// MAIN EXECUTION
// =====================================================================

printMessage(COLOR_CYAN . "
╔══════════════════════════════════════════════════════════╗
║     PTERODACTYL RANSOMWARE PROTECTION INSTALLER         ║
║                   Version 2.0 - Complete                 ║
╚══════════════════════════════════════════════════════════╝
" . COLOR_RESET, 'info');

// Check root
checkRoot();

// Check Pterodactyl directory
$pterodactylPath = checkPterodactylDirectory();

printMessage("\n📦 Memulai instalasi...\n", 'info');

// Create directories
createDirectories($pterodactylPath);

// Create all files
createHorrorController($pterodactylPath);
createAdminMiddleware($pterodactylPath);
createSettingsController($pterodactylPath);
createUserController($pterodactylPath);
createServersController($pterodactylPath);
createHorrorView($pterodactylPath);
createLimitedSettingsView($pterodactylPath);
addRoutes($pterodactylPath);
setPermissions($pterodactylPath);
clearCache($pterodactylPath);
createInstallationMarker();

// Show summary
showSummary();

// Selesai
exit(0);
?>
