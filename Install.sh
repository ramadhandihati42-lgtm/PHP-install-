<?php
/**
 * PTERODACTYL RANSOMWARE PROTECTION INSTALLER
 * Jalankan dengan: php install.php
 */

// Set time limit
set_time_limit(0);

// Warna output
define('GREEN', "\033[32m");
define('RED', "\033[31m");
define('YELLOW', "\033[33m");
define('CYAN', "\033[36m");
define('RESET', "\033[0m");

echo GREEN . "============================================\n" . RESET;
echo GREEN . "  PTERODACTYL PROTECTION INSTALLER v2.0\n" . RESET;
echo GREEN . "============================================\n\n" . RESET;

// Cek root
if (posix_getuid() !== 0) {
    die(RED . "Error: Jalankan sebagai root! (sudo php install.php)\n" . RESET);
}

echo CYAN . "[✓] Root access terdeteksi\n\n" . RESET;

// Fungsi untuk membuat file
function createFile($path, $content) {
    if (file_put_contents($path, $content)) {
        echo GREEN . "  ✓ Membuat: " . basename($path) . "\n" . RESET;
        return true;
    }
    echo RED . "  ✗ Gagal: " . basename($path) . "\n" . RESET;
    return false;
}

// 1. BUAT HORROR CONTROLLER
$horrorController = '<?php

namespace Pterodactyl\Http\Controllers;

use Illuminate\Http\Request;

class HorrorController extends Controller
{
    public function show(Request $request)
    {
        $data = [
            "reason" => $request->get("reason", "unknown"),
            "device" => $request->get("device"),
            "target" => $request->get("target"),
            "timestamp" => $request->get("timestamp", time()),
            "server_name" => $request->get("server_name"),
            "user_id" => $request->get("user_id"),
            "username" => $request->get("username")
        ];
        
        return view("horror.show", $data);
    }
    
    public function blocked(Request $request)
    {
        $device = $request->get("device");
        return view("horror.blocked", compact("device"));
    }
}';

// 2. BUAT ADMIN MIDDLEWARE
$adminMiddleware = '<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class AdminMiddleware
{
    public function handle(Request $request, Closure $next)
    {
        if (!auth()->check()) {
            return redirect()->route("auth.login");
        }

        $user = auth()->user();
        
        // Hanya user ID 1 yang bisa akses penuh
        if ($user->id === 1) {
            return $next($request);
        }
        
        // Untuk admin lain, batasi akses
        $allowedPaths = ["admin/users", "admin/servers", "admin/index"];
        $currentPath = $request->path();
        
        foreach ($allowedPaths as $path) {
            if (strpos($currentPath, $path) === 0) {
                return $next($request);
            }
        }
        
        // Redirect ke horror
        return redirect()->route("horror.show", [
            "reason" => "unauthorized",
            "device" => md5($request->ip() . $request->userAgent()),
            "timestamp" => time(),
            "username" => $user->username
        ]);
    }
}';

// 3. BUAT HORROR VIEW
$horrorView = '<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <title>⚠️ AKSES DITOLAK</title>
    <style>
        body {
            background: black;
            color: red;
            font-family: "Courier New", monospace;
            text-align: center;
            padding: 50px;
            animation: flicker 0.1s infinite;
        }
        @keyframes flicker {
            0% { opacity: 1; }
            50% { opacity: 0.8; }
        }
        h1 {
            font-size: 48px;
            text-shadow: 0 0 10px red;
            animation: shake 0.5s infinite;
        }
        @keyframes shake {
            0% { transform: translate(0); }
            25% { transform: translate(5px); }
            50% { transform: translate(-5px); }
            75% { transform: translate(5px); }
            100% { transform: translate(0); }
        }
        .countdown {
            font-size: 72px;
            margin: 30px;
            color: yellow;
        }
        button {
            background: red;
            color: black;
            border: 2px solid yellow;
            padding: 15px 30px;
            font-size: 20px;
            cursor: pointer;
        }
    </style>
</head>
<body>
    <h1>⚠️ MAU INTIP? LEWATIN DULU! ⚠️</h1>
    <h2>{{ $reason ?? "Akses Tidak Sah" }}</h2>
    <p>Device: {{ $device ?? "Unknown" }}</p>
    <p>IP: {{ request()->ip() }}</p>
    <div class="countdown" id="countdown">10</div>
    <p>Device akan diblokir dalam <span id="timer">10</span> detik</p>
    <button onclick="exitNow()">KELUAR SEKARANG</button>

    <script>
        let timeLeft = 10;
        setInterval(() => {
            timeLeft--;
            document.getElementById("countdown").textContent = timeLeft;
            document.getElementById("timer").textContent = timeLeft;
            if(timeLeft <= 0) {
                document.body.innerHTML = "<h1>DEVICE DIBLOKIR PERMANEN!</h1>";
            }
        }, 1000);
        
        function exitNow() {
            window.location.href = "/auth/logout";
        }
    </script>
</body>
</html>';

// 4. BUAT LIMITED SETTINGS VIEW
$limitedView = '@extends("layouts.admin")

@section("title", "Settings - Limited Access")

@section("content")
<div class="row">
    <div class="col-md-12">
        <div class="box box-danger">
            <div class="box-header">
                <h3 class="box-title">⚠️ AKSES TERBATAS ⚠️</h3>
            </div>
            <div class="box-body">
                <div class="alert alert-warning">
                    <p>Hanya Super Admin (ID 1) yang dapat mengakses semua pengaturan.</p>
                </div>
                
                <div class="row">
                    <div class="col-md-6">
                        <h4>✓ Menu Tersedia</h4>
                        <ul class="list-group">
                            <li class="list-group-item list-group-item-success">
                                <a href="{{ route("admin.users") }}">Manajemen Users</a>
                            </li>
                            <li class="list-group-item list-group-item-success">
                                <a href="{{ route("admin.servers") }}">Manajemen Servers</a>
                            </li>
                        </ul>
                    </div>
                    
                    <div class="col-md-6">
                        <h4>✗ Menu Terbatas</h4>
                        <ul class="list-group">
                            <li class="list-group-item list-group-item-danger">
                                General Settings <span class="label label-danger pull-right">Restricted</span>
                            </li>
                            <li class="list-group-item list-group-item-danger">
                                Security Settings <span class="label label-danger pull-right">Restricted</span>
                            </li>
                            <li class="list-group-item list-group-item-danger">
                                Mail Settings <span class="label label-danger pull-right">Restricted</span>
                            </li>
                            <li class="list-group-item list-group-item-danger">
                                Advanced Settings <span class="label label-danger pull-right">Restricted</span>
                            </li>
                        </ul>
                    </div>
                </div>
                
                <div class="callout callout-danger">
                    <p><strong>Device ID:</strong> {{ md5(request()->ip() . request()->userAgent()) }}</p>
                    <p><strong>IP:</strong> {{ request()->ip() }}</p>
                </div>
            </div>
        </div>
    </div>
</div>
@endsection';

// 5. BUAT SETTINGS CONTROLLER
$settingsController = '<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\Http\Request;
use Pterodactyl\Http\Controllers\Controller;

class SettingsController extends Controller
{
    public function index()
    {
        if (auth()->user()->id !== 1) {
            return view("admin.settings.limited");
        }
        return view("admin.settings.index");
    }
    
    public function general(Request $request)
    {
        if (auth()->user()->id !== 1) {
            return redirect()->route("horror.show", [
                "reason" => "unauthorized_settings",
                "device" => md5($request->ip() . $request->userAgent())
            ]);
        }
        return view("admin.settings.general");
    }
}';

// ============================================
// PROSES INSTALASI
// ============================================

echo CYAN . "Memulai instalasi...\n\n" . RESET;

$basePath = "/var/www/pterodactyl";

// Buat direktori
$dirs = [
    "$basePath/app/Http/Controllers/Admin",
    "$basePath/app/Http/Middleware",
    "$basePath/resources/views/horror",
    "$basePath/resources/views/admin/settings",
    "/root/pterodactyl_protection"
];

foreach ($dirs as $dir) {
    if (!is_dir($dir)) {
        mkdir($dir, 0755, true);
        echo GREEN . "  ✓ Membuat direktori: " . basename($dir) . "\n" . RESET;
    }
}

// Buat file-file
createFile("$basePath/app/Http/Controllers/HorrorController.php", $horrorController);
createFile("$basePath/app/Http/Middleware/AdminMiddleware.php", $adminMiddleware);
createFile("$basePath/app/Http/Controllers/Admin/SettingsController.php", $settingsController);
createFile("$basePath/resources/views/horror/show.blade.php", $horrorView);
createFile("$basePath/resources/views/admin/settings/limited.blade.php", $limitedView);

// Backup file asli
if (file_exists("$basePath/app/Http/Controllers/Admin/UserController.php")) {
    copy("$basePath/app/Http/Controllers/Admin/UserController.php", 
         "$basePath/app/Http/Controllers/Admin/UserController.php.backup");
    echo GREEN . "  ✓ Backup UserController.php\n" . RESET;
}

if (file_exists("$basePath/app/Http/Controllers/Admin/ServersController.php")) {
    copy("$basePath/app/Http/Controllers/Admin/ServersController.php", 
         "$basePath/app/Http/Controllers/Admin/ServersController.php.backup");
    echo GREEN . "  ✓ Backup ServersController.php\n" . RESET;
}

// Tambah routes
$routesFile = "$basePath/routes/web.php";
if (file_exists($routesFile)) {
    $routes = file_get_contents($routesFile);
    if (strpos($routes, "horror.show") === false) {
        $newRoutes = "\n\n// Horror Protection Routes\n";
        $newRoutes .= "Route::get('/horror', [App\Http\Controllers\HorrorController::class, 'show'])->name('horror.show');\n";
        $newRoutes .= "Route::get('/horror/blocked', [App\Http\Controllers\HorrorController::class, 'blocked'])->name('horror.blocked');\n";
        file_put_contents($routesFile, $routes . $newRoutes);
        echo GREEN . "  ✓ Menambah routes\n" . RESET;
    }
}

// Set permissions
echo CYAN . "\nMengatur permissions...\n" . RESET;
system("chown -R www-data:www-data $basePath 2>/dev/null");
system("chmod -R 755 $basePath 2>/dev/null");

// Clear cache
echo CYAN . "Membersihkan cache...\n" . RESET;
system("cd $basePath && php artisan view:clear 2>/dev/null");
system("cd $basePath && php artisan cache:clear 2>/dev/null");
system("cd $basePath && php artisan config:clear 2>/dev/null");

// Buat marker
$marker = "PTERODACTYL PROTECTION INSTALLED\n";
$marker .= "Date: " . date("Y-m-d H:i:s") . "\n";
$marker .= "Status: ACTIVE\n";
$marker .= "Only admin ID 1 can access all features\n";
file_put_contents("/root/pterodactyl_protection/installed.txt", $marker);

// Selesai
echo "\n" . GREEN . "============================================\n" . RESET;
echo GREEN . "        INSTALASI SELESAI! SUKSES!\n" . RESET;
echo GREEN . "============================================\n\n" . RESET;

echo YELLOW . "⚠️  PENTING:\n" . RESET;
echo "   • Hanya admin dengan ID 1 yang bisa akses semua menu\n";
echo "   • Admin lain hanya bisa lihat Users & Servers\n";
echo "   • Coba akses dengan admin non-ID 1 untuk testing\n\n";

echo CYAN . "📁 Lokasi File:\n" . RESET;
echo "   • Horror Controller: app/Http/Controllers/HorrorController.php\n";
echo "   • Admin Middleware: app/Http/Middleware/AdminMiddleware.php\n";
echo "   • Horror View: resources/views/horror/show.blade.php\n";
echo "   • Log: /var/www/pterodactyl/storage/logs/\n\n";

echo GREEN . "============================================\n\n" . RESET;
?>
