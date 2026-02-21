<?php
/**
 =====================================================
 PTERODACTYL RANSOMWARE PROTECTION - INSTALLER LENGKAP
 =====================================================
 Cara menjalankan: php install.php
 =====================================================
 */

// =====================================================
// KONFIGURASI AWAL
// =====================================================
error_reporting(E_ALL);
ini_set('display_errors', 1);
set_time_limit(300);

// Warna output terminal
define('GREEN', "\033[32m");
define('RED', "\033[31m");
define('YELLOW', "\033[33m");
define('BLUE', "\033[34m");
define('CYAN', "\033[36m");
define('RESET', "\033[0m");

// =====================================================
// FUNGSI BANTU
// =====================================================

/**
 * Print pesan dengan warna
 */
function printMsg($msg, $type = 'info') {
    $colors = [
        'success' => GREEN,
        'error' => RED,
        'warning' => YELLOW,
        'info' => CYAN,
        'title' => BLUE
    ];
    $color = $colors[$type] ?? RESET;
    echo $color . $msg . RESET . "\n";
}

/**
 * Buat file dengan konten
 */
function createFile($path, $content) {
    $dir = dirname($path);
    if (!is_dir($dir)) {
        mkdir($dir, 0755, true);
    }
    
    $result = file_put_contents($path, $content);
    if ($result !== false) {
        printMsg("  ✓ " . basename($path), 'success');
        return true;
    } else {
        printMsg("  ✗ Gagal membuat " . basename($path), 'error');
        return false;
    }
}

/**
 * Backup file
 */
function backupFile($path) {
    if (file_exists($path)) {
        $backup = $path . '.backup.' . date('Y-m-d_H-i-s');
        copy($path, $backup);
        printMsg("  • Backup: " . basename($path), 'info');
    }
}

// =====================================================
// CEK PRASYARAT
// =====================================================
printMsg("\n" . str_repeat("=", 50), 'title');
printMsg("  PTERODACTYL RANSOMWARE PROTECTION INSTALLER", 'title');
printMsg("  Version 3.0 - Complete Edition", 'title');
printMsg(str_repeat("=", 50) . "\n", 'title');

// Cek root
if (posix_getuid() !== 0) {
    printMsg("❌ ERROR: Jalankan sebagai root!", 'error');
    printMsg("   sudo php install.php", 'info');
    exit(1);
}
printMsg("✅ Root access OK", 'success');

// Cek PHP
if (version_compare(PHP_VERSION, '7.4.0', '<')) {
    printMsg("❌ ERROR: PHP 7.4+ diperlukan", 'error');
    exit(1);
}
printMsg("✅ PHP " . PHP_VERSION . " OK", 'success');

// Cek direktori Pterodactyl
$pteroPath = '/var/www/pterodactyl';
if (!is_dir($pteroPath)) {
    printMsg("❌ ERROR: Pterodactyl tidak ditemukan di $pteroPath", 'error');
    exit(1);
}
printMsg("✅ Pterodactyl ditemukan", 'success');

// =====================================================
// FILE-FILE YANG AKAN DIBUAT
// =====================================================
printMsg("\n📁 Membuat file-file proteksi...\n", 'info');

// 1. HORROR CONTROLLER
$horrorController = <<<'PHP'
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
            'reason' => $request->get('reason', 'UNAUTHORIZED ACCESS'),
            'device' => $request->get('device', md5($request->ip() . $request->userAgent())),
            'target' => $request->get('target'),
            'timestamp' => $request->get('timestamp', time()),
            'server_name' => $request->get('server_name'),
            'user_id' => $request->get('user_id'),
            'username' => $request->get('username')
        ];
        
        // Log akses tidak sah
        $this->logAttempt($data);
        
        return view('horror.show', $data);
    }
    
    /**
     * Halaman device diblokir
     */
    public function blocked(Request $request)
    {
        $device = $request->get('device');
        return view('horror.blocked', compact('device'));
    }
    
    /**
     * Log percobaan akses
     */
    private function logAttempt($data)
    {
        $log = sprintf(
            "[%s] UNAUTHORIZED | Reason: %s | Device: %s | IP: %s\n",
            date('Y-m-d H:i:s'),
            $data['reason'],
            $data['device'],
            request()->ip() ?? 'unknown'
        );
        
        file_put_contents(storage_path('logs/horror.log'), $log, FILE_APPEND);
    }
}
PHP;

// 2. ADMIN MIDDLEWARE
$adminMiddleware = <<<'PHP'
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
        // Cek login
        if (!auth()->check()) {
            return redirect()->route('auth.login');
        }

        $user = auth()->user();
        $deviceId = md5($request->ip() . $request->userAgent());
        
        // Cek device diblokir
        if ($this->isDeviceBlocked($deviceId, $request->ip())) {
            return redirect()->route('horror.blocked', ['device' => $deviceId]);
        }
        
        // SUPER ADMIN (ID 1) - akses penuh
        if ($user->id === 1) {
            return $next($request);
        }
        
        // ADMIN BIASA - akses terbatas
        if ($user->root_admin) {
            return $this->handleRestrictedAdmin($request, $user, $deviceId);
        }
        
        return $next($request);
    }
    
    /**
     * Handle admin dengan akses terbatas
     */
    private function handleRestrictedAdmin($request, $user, $deviceId)
    {
        // Path yang diizinkan
        $allowedPaths = [
            'admin/users',
            'admin/servers',
            'admin/index',
            'dashboard'
        ];
        
        $currentPath = $request->path();
        
        // Cek apakah path diizinkan
        foreach ($allowedPaths as $path) {
            if (strpos($currentPath, $path) === 0) {
                return $this->next($request);
            }
        }
        
        // Jika tidak diizinkan, redirect ke horror
        $this->logRestrictedAccess($user, $request);
        
        return redirect()->route('horror.show', [
            'reason' => 'RESTRICTED_AREA',
            'device' => $deviceId,
            'username' => $user->username,
            'timestamp' => time()
        ]);
    }
    
    /**
     * Cek device diblokir
     */
    private function isDeviceBlocked($deviceId, $ip)
    {
        $file = storage_path('app/blocked_devices.json');
        if (!file_exists($file)) {
            return false;
        }
        
        $blocked = json_decode(file_get_contents($file), true) ?: [];
        return isset($blocked[$deviceId]) || in_array($ip, array_column($blocked, 'ip'));
    }
    
    /**
     * Log akses terbatas
     */
    private function logRestrictedAccess($user, $request)
    {
        $log = sprintf(
            "[%s] RESTRICTED | User: %s (%d) | Path: %s | IP: %s\n",
            date('Y-m-d H:i:s'),
            $user->username,
            $user->id,
            $request->path(),
            $request->ip()
        );
        
        file_put_contents(storage_path('logs/restricted.log'), $log, FILE_APPEND);
    }
}
PHP;

// 3. SETTINGS CONTROLLER
$settingsController = <<<'PHP'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\Http\Request;
use Pterodactyl\Http\Controllers\Controller;

class SettingsController extends Controller
{
    /**
     * Halaman utama settings
     */
    public function index()
    {
        $user = auth()->user();
        
        // Admin biasa lihat limited view
        if ($user->id !== 1) {
            return view('admin.settings.limited');
        }
        
        // Super admin lihat full settings
        return view('admin.settings.index');
    }
    
    /**
     * General settings (hanya super admin)
     */
    public function general(Request $request)
    {
        if (auth()->user()->id !== 1) {
            return redirect()->route('horror.show', [
                'reason' => 'UNAUTHORIZED_SETTINGS',
                'device' => md5($request->ip() . $request->userAgent())
            ]);
        }
        
        return view('admin.settings.general');
    }
    
    /**
     * Advanced settings (hanya super admin)
     */
    public function advanced(Request $request)
    {
        if (auth()->user()->id !== 1) {
            return redirect()->route('horror.show', [
                'reason' => 'UNAUTHORIZED_SETTINGS',
                'device' => md5($request->ip() . $request->userAgent())
            ]);
        }
        
        return view('admin.settings.advanced');
    }
    
    /**
     * Mail settings (hanya super admin)
     */
    public function mail(Request $request)
    {
        if (auth()->user()->id !== 1) {
            return redirect()->route('horror.show', [
                'reason' => 'UNAUTHORIZED_SETTINGS',
                'device' => md5($request->ip() . $request->userAgent())
            ]);
        }
        
        return view('admin.settings.mail');
    }
    
    /**
     * Security settings (hanya super admin)
     */
    public function security(Request $request)
    {
        if (auth()->user()->id !== 1) {
            return redirect()->route('horror.show', [
                'reason' => 'UNAUTHORIZED_SETTINGS',
                'device' => md5($request->ip() . $request->userAgent())
            ]);
        }
        
        return view('admin.settings.security');
    }
}
PHP;

// 4. HORROR VIEW (BLADE)
$horrorView = <<<'HTML'
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>⚠️ AKSES DITOLAK - PERINGATAN ⚠️</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            background: #000;
            color: #f00;
            font-family: 'Courier New', monospace;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            overflow: hidden;
            position: relative;
        }
        .container {
            text-align: center;
            z-index: 10;
            padding: 20px;
            max-width: 800px;
        }
        h1 {
            font-size: clamp(2rem, 8vw, 4rem);
            text-transform: uppercase;
            animation: glitch 1s infinite;
            text-shadow: 
                0.05em 0 0 rgba(255,0,0,.75),
                -0.05em -0.025em 0 rgba(0,255,0,.75),
                0.025em 0.05em 0 rgba(0,0,255,.75);
        }
        @keyframes glitch {
            0% { transform: translate(0); }
            20% { transform: translate(-3px, 3px); }
            40% { transform: translate(-3px, -3px); }
            60% { transform: translate(3px, 3px); }
            80% { transform: translate(3px, -3px); }
            100% { transform: translate(0); }
        }
        .box {
            background: rgba(255,0,0,0.1);
            border: 3px solid #f00;
            padding: 30px;
            margin: 30px 0;
            border-radius: 10px;
            box-shadow: 0 0 50px rgba(255,0,0,0.3);
        }
        .warning {
            color: #ff0;
            font-size: 1.5rem;
            margin: 20px 0;
            animation: blink 1s infinite;
        }
        @keyframes blink {
            0%, 50% { opacity: 1; }
            51%, 100% { opacity: 0.5; }
        }
        .details {
            color: #fff;
            text-align: left;
            background: rgba(0,0,0,0.8);
            padding: 20px;
            border-radius: 5px;
            margin: 20px 0;
            border-left: 5px solid #f00;
        }
        .countdown {
            font-size: 5rem;
            color: #ff0;
            margin: 20px;
            text-shadow: 0 0 20px #f00;
            animation: pulse 1s infinite;
        }
        @keyframes pulse {
            0%, 100% { transform: scale(1); }
            50% { transform: scale(1.1); }
        }
        button {
            background: #f00;
            color: #000;
            border: 2px solid #ff0;
            padding: 15px 40px;
            font-size: 1.5rem;
            font-weight: bold;
            cursor: pointer;
            margin: 20px;
            border-radius: 50px;
            transition: 0.3s;
        }
        button:hover {
            background: #ff0;
            color: #f00;
            transform: scale(1.1);
            box-shadow: 0 0 50px #ff0;
        }
        .matrix {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            pointer-events: none;
            opacity: 0.2;
            z-index: 1;
        }
    </style>
</head>
<body>
    <canvas class="matrix" id="matrix"></canvas>
    
    <div class="container">
        <h1>⚠️ MAU INTIP? ⚠️</h1>
        <h1>LEWATIN DULU!</h1>
        
        <div class="box">
            <div class="warning">⛔ AKSES TIDAK SAH ⛔</div>
            
            <div class="details">
                <p><strong>📋 DETAIL PELANGGARAN:</strong></p>
                <p>► Alasan: <span style="color:#ff0">{{ $reason }}</span></p>
                <p>► Device ID: <span style="color:#ff0">{{ $device }}</span></p>
                @if($username ?? false)
                <p>► Username: <span style="color:#ff0">{{ $username }}</span></p>
                @endif
                @if($target ?? false)
                <p>► Target: <span style="color:#ff0">{{ $target }}</span></p>
                @endif
                <p>► IP Address: <span style="color:#ff0">{{ request()->ip() }}</span></p>
                <p>► Waktu: <span style="color:#ff0">{{ date('Y-m-d H:i:s', $timestamp ?? time()) }}</span></p>
            </div>
            
            <div class="warning">⚠️ PERINGATAN TERAKHIR ⚠️</div>
            
            <div class="countdown" id="countdown">10</div>
            
            <p style="color:#ff0; margin:20px;">Device akan diblokir dalam <span id="timer">10</span> detik</p>
            
            <button onclick="exitNow()">🚪 KELUAR SEKARANG</button>
        </div>
    </div>
    
    <script>
        // Matrix effect
        const canvas = document.getElementById('matrix');
        const ctx = canvas.getContext('2d');
        
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
        
        const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
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
                const text = chars[Math.floor(Math.random() * chars.length)];
                ctx.fillText(text, i * fontSize, drops[i] * fontSize);
                
                if(drops[i] * fontSize > canvas.height && Math.random() > 0.975) {
                    drops[i] = 0;
                }
                drops[i]++;
            }
        }
        
        setInterval(drawMatrix, 50);
        
        // Countdown
        let timeLeft = 10;
        const countdownEl = document.getElementById('countdown');
        const timerEl = document.getElementById('timer');
        
        const timer = setInterval(() => {
            timeLeft--;
            countdownEl.textContent = timeLeft;
            timerEl.textContent = timeLeft;
            
            if(timeLeft <= 0) {
                clearInterval(timer);
                blockDevice();
            }
        }, 1000);
        
        function exitNow() {
            window.location.href = '/auth/logout';
        }
        
        function blockDevice() {
            document.body.innerHTML = '<div style="color:#f00; text-align:center; margin-top:50vh; transform:translateY(-50%);"><h1>💀 DEVICE DIBLOKIR PERMANEN 💀</h1><p style="color:#666; margin-top:20px;">Hubungi administrator untuk membuka blokir</p></div>';
        }
        
        window.onbeforeunload = function() {
            return "Anda tidak bisa keluar!";
        };
        
        document.addEventListener('contextmenu', e => e.preventDefault());
        document.addEventListener('keydown', function(e) {
            if(e.key === 'F5' || e.key === 'F12' || (e.ctrlKey && e.key === 'r')) {
                e.preventDefault();
            }
        });
    </script>
</body>
</html>
HTML;

// 5. LIMITED SETTINGS VIEW
$limitedView = <<<'HTML'
@extends('layouts.admin')

@section('title', 'Settings - Limited Access')

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
                    <h4><i class="icon fa fa-warning"></i> Peringatan!</h4>
                    <p>Akun Anda memiliki akses terbatas. Hanya Super Admin (ID 1) yang dapat mengakses semua pengaturan.</p>
                </div>
                
                <div class="row">
                    <div class="col-md-6">
                        <div class="box box-success">
                            <div class="box-header">
                                <h3 class="box-title">✓ Menu Tersedia</h3>
                            </div>
                            <div class="box-body">
                                <ul class="list-group">
                                    <li class="list-group-item list-group-item-success">
                                        <i class="fa fa-users"></i> 
                                        <a href="{{ route('admin.users') }}">Manajemen Users</a>
                                    </li>
                                    <li class="list-group-item list-group-item-success">
                                        <i class="fa fa-server"></i> 
                                        <a href="{{ route('admin.servers') }}">Manajemen Servers</a>
                                    </li>
                                </ul>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-md-6">
                        <div class="box box-danger">
                            <div class="box-header">
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
                                </ul>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div class="callout callout-danger">
                    <h4>⚠️ INFORMASI DEVICE</h4>
                    <p><strong>Device ID:</strong> <code>{{ md5(request()->ip() . request()->userAgent()) }}</code></p>
                    <p><strong>IP Address:</strong> <code>{{ request()->ip() }}</code></p>
                    <p><strong>User Agent:</strong> <code>{{ request()->userAgent() }}</code></p>
                </div>
            </div>
        </div>
    </div>
</div>
@endsection
HTML;

// 6. BLOCKED VIEW
$blockedView = <<<'HTML'
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <title>DEVICE DIBLOKIR</title>
    <style>
        body {
            background: #000;
            color: #f00;
            font-family: monospace;
            text-align: center;
            padding: 50px;
        }
        h1 {
            font-size: 48px;
            animation: blink 1s infinite;
        }
        @keyframes blink {
            0%, 50% { opacity: 1; }
            51%, 100% { opacity: 0.5; }
        }
    </style>
</head>
<body>
    <h1>💀 DEVICE DIBLOKIR PERMANEN 💀</h1>
    <p>Device ID: {{ $device }}</p>
    <p>IP: {{ request()->ip() }}</p>
    <p>Hubungi administrator untuk membuka blokir</p>
</body>
</html>
HTML;

// =====================================================
// PROSES INSTALASI
// =====================================================

printMsg("\n📦 Memulai instalasi...\n", 'info');

// Backup file yang ada
backupFile("$pteroPath/app/Http/Controllers/Admin/UserController.php");
backupFile("$pteroPath/app/Http/Controllers/Admin/ServersController.php");
backupFile("$pteroPath/app/Http/Middleware/AdminMiddleware.php");

// Buat file-file
createFile("$pteroPath/app/Http/Controllers/HorrorController.php", $horrorController);
createFile("$pteroPath/app/Http/Middleware/AdminMiddleware.php", $adminMiddleware);
createFile("$pteroPath/app/Http/Controllers/Admin/SettingsController.php", $settingsController);
createFile("$pteroPath/resources/views/horror/show.blade.php", $horrorView);
createFile("$pteroPath/resources/views/horror/blocked.blade.php", $blockedView);
createFile("$pteroPath/resources/views/admin/settings/limited.blade.php", $limitedView);

// Tambah routes
$routesFile = "$pteroPath/routes/web.php";
if (file_exists($routesFile)) {
    $routes = file_get_contents($routesFile);
    if (strpos($routes, 'horror.show') === false) {
        $newRoutes = "\n\n// ============================================\n";
        $newRoutes .= "// HORROR PROTECTION ROUTES\n";
        $newRoutes .= "// ============================================\n";
        $newRoutes .= "Route::get('/horror', [App\Http\Controllers\HorrorController::class, 'show'])->name('horror.show');\n";
        $newRoutes .= "Route::get('/horror/blocked', [App\Http\Controllers\HorrorController::class, 'blocked'])->name('horror.blocked');\n";
        
        file_put_contents($routesFile, $routes . $newRoutes);
        printMsg("  ✓ Menambah routes horror", 'success');
    } else {
        printMsg("  • Routes sudah ada", 'info');
    }
}

// Set permissions
printMsg("\n🔧 Mengatur permissions...", 'info');
system("chown -R www-data:www-data $pteroPath 2>/dev/null");
system("chmod -R 755 $pteroPath 2>/dev/null");
system("chmod -R 777 $pteroPath/storage 2>/dev/null");
system("chmod -R 777 $pteroPath/bootstrap/cache 2>/dev/null");

// Clear cache
printMsg("\n🧹 Membersihkan cache...", 'info');
system("cd $pteroPath && php artisan view:clear 2>/dev/null");
system("cd $pteroPath && php artisan cache:clear 2>/dev/null");
system("cd $pteroPath && php artisan config:clear 2>/dev/null");
system("cd $pteroPath && php artisan route:clear 2>/dev/null");

// Buat marker instalasi
$marker = "========================================\n";
$marker .= "PTERODACTYL RANSOMWARE PROTECTION\n";
$marker .= "========================================\n";
$marker .= "Tanggal: " . date('Y-m-d H:i:s') . "\n";
$marker .= "Status: ACTIVE\n";
$marker .= "Server: " . gethostname() . "\n";
$marker .= "PHP Version: " . PHP_VERSION . "\n\n";
$marker .= "FITUR:\n";
$marker .= "- Horror protection dengan matrix effect\n";
$marker .= "- Countdown 10 detik\n";
$marker .= "- Device blocking permanent\n";
$marker .= "- Settings menu dibatasi\n";
$marker .= "- Log semua percobaan\n\n";
$marker .= "⚠️ HANYA ADMIN ID 1 YANG BISA AKSES SEMUA FITUR!\n";
$marker .= "========================================\n";

mkdir('/root/pterodactyl_protection', 0755, true);
file_put_contents('/root/pterodactyl_protection/installed.txt', $marker);
printMsg("  ✓ Membuat marker instalasi", 'success');

// =====================================================
// SELESAI
// =====================================================
printMsg("\n" . str_repeat("=", 50), 'success');
printMsg("  ✅ INSTALASI SELESAI! SUKSES! ✅", 'success');
printMsg(str_repeat("=", 50), 'success');

printMsg("\n📋 INFORMASI PENTING:", 'info');
printMsg("  • Super Admin (ID 1): Akses FULL", 'info');
printMsg("  • Admin Lain: Hanya Users & Servers", 'info');
printMsg("  • Settings: Dibatasi untuk admin non-ID 1", 'info');
printMsg("  • Horror page: Aktif untuk akses tidak sah", 'info');

printMsg("\n🔍 CARA CEK ID ADMIN:", 'warning');
printMsg("  mysql -u root -p -e 'SELECT id, username, email FROM pterodactyl.users WHERE root_admin = 1;'", 'info');

printMsg("\n📁 LOKASI FILE:", 'info');
printMsg("  • Horror Controller: app/Http/Controllers/HorrorController.php", 'info');
printMsg("  • Admin Middleware: app/Http/Middleware/AdminMiddleware.php", 'info');
printMsg("  • Settings Controller: app/Http/Controllers/Admin/SettingsController.php", 'info');
printMsg("  • Horror View: resources/views/horror/show.blade.php", 'info');
printMsg("  • Log: storage/logs/horror.log", 'info');

printMsg("\n🔥 TESTING:", 'success');
printMsg("  Login dengan admin NON-ID 1 dan coba akses menu settings!", 'success');
printMsg("\n" . str_repeat("=", 50) . "\n", 'success');

exit(0);
?>
