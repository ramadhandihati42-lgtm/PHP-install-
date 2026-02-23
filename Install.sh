<?php
session_start();

// Konfigurasi Database
$DB_HOST = "localhost";
$DB_NAME = "admin_panel";
$DB_USER = "root";
$DB_PASS = "";

// Koneksi Database
try {
    $pdo = new PDO("mysql:host=$DB_HOST;dbname=$DB_NAME", $DB_USER, $DB_PASS);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Buat tabel users
    $pdo->exec("CREATE TABLE IF NOT EXISTS users (
        id INT PRIMARY KEY AUTO_INCREMENT,
        username VARCHAR(50) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL,
        role VARCHAR(20) DEFAULT 'user',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )");
    
    // Buat tabel servers
    $pdo->exec("CREATE TABLE IF NOT EXISTS servers (
        id INT PRIMARY KEY AUTO_INCREMENT,
        name VARCHAR(100) NOT NULL,
        ip_address VARCHAR(50),
        status VARCHAR(20) DEFAULT 'active',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )");
    
    // Cek apakah admin dengan ID 1 sudah ada
    $stmt = $pdo->query("SELECT COUNT(*) FROM users WHERE id = 1");
    if ($stmt->fetchColumn() == 0) {
        // Buat admin default (ID 1 otomatis)
        $password = password_hash("admin123", PASSWORD_DEFAULT);
        $pdo->exec("INSERT INTO users (username, password, role) VALUES ('admin', '$password', 'admin')");
    }
    
} catch(PDOException $e) {
    die("Koneksi database gagal: " . $e->getMessage());
}

// Fungsi cek login
function isLogin() {
    return isset($_SESSION['user_id']);
}

// Fungsi cek admin utama (ID 1)
function isAdminUtama() {
    return (isset($_SESSION['user_id']) && $_SESSION['user_id'] == 1);
}

// Proses Login
if (isset($_POST['login'])) {
    $username = $_POST['username'];
    $password = $_POST['password'];
    
    $stmt = $pdo->prepare("SELECT * FROM users WHERE username = ?");
    $stmt->execute([$username]);
    $user = $stmt->fetch();
    
    if ($user && password_verify($password, $user['password'])) {
        $_SESSION['user_id'] = $user['id'];
        $_SESSION['username'] = $user['username'];
        $_SESSION['role'] = $user['role'];
        header("Location: ".$_SERVER['PHP_SELF']);
        exit();
    } else {
        $error = "Username atau password salah!";
    }
}

// Proses Logout
if (isset($_GET['logout'])) {
    session_destroy();
    header("Location: ".$_SERVER['PHP_SELF']);
    exit();
}

// Proses Tambah User (hanya admin utama)
if (isAdminUtama() && isset($_POST['tambah_user'])) {
    $username = $_POST['username'];
    $password = password_hash($_POST['password'], PASSWORD_DEFAULT);
    $role = $_POST['role'];
    
    $stmt = $pdo->prepare("INSERT INTO users (username, password, role) VALUES (?, ?, ?)");
    $stmt->execute([$username, $password, $role]);
    header("Location: ".$_SERVER['PHP_SELF']."?page=users");
    exit();
}

// Proses Hapus User (hanya admin utama)
if (isAdminUtama() && isset($_GET['hapus_user'])) {
    $id = $_GET['hapus_user'];
    if ($id != 1) {
        $stmt = $pdo->prepare("DELETE FROM users WHERE id = ?");
        $stmt->execute([$id]);
    }
    header("Location: ".$_SERVER['PHP_SELF']."?page=users");
    exit();
}

// Proses Tambah Server (semua user)
if (isLogin() && isset($_POST['tambah_server'])) {
    $name = $_POST['name'];
    $ip = $_POST['ip_address'];
    
    $stmt = $pdo->prepare("INSERT INTO servers (name, ip_address) VALUES (?, ?)");
    $stmt->execute([$name, $ip]);
    header("Location: ".$_SERVER['PHP_SELF']."?page=servers");
    exit();
}

// Proses Hapus Server (semua user)
if (isLogin() && isset($_GET['hapus_server'])) {
    $stmt = $pdo->prepare("DELETE FROM servers WHERE id = ?");
    $stmt->execute([$_GET['hapus_server']]);
    header("Location: ".$_SERVER['PHP_SELF']."?page=servers");
    exit();
}

// Proses Edit Server (semua user)
if (isLogin() && isset($_POST['edit_server'])) {
    $id = $_POST['id'];
    $name = $_POST['name'];
    $ip = $_POST['ip_address'];
    $status = $_POST['status'];
    
    $stmt = $pdo->prepare("UPDATE servers SET name=?, ip_address=?, status=? WHERE id=?");
    $stmt->execute([$name, $ip, $status, $id]);
    header("Location: ".$_SERVER['PHP_SELF']."?page=servers");
    exit();
}

// Halaman yang aktif
$page = isset($_GET['page']) ? $_GET['page'] : 'users';
if (isAdminUtama() && $page == '') {
    $page = 'dashboard';
}
?>
<!DOCTYPE html>
<html>
<head>
    <title>Admin Panel</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: Arial, sans-serif;
        }
        
        body {
            background: #f0f2f5;
        }
        
        /* Login Page */
        .login-container {
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            background: linear-gradient(135deg, #667eea, #764ba2);
        }
        
        .login-box {
            background: white;
            padding: 40px;
            border-radius: 10px;
            width: 400px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        
        .login-box h2 {
            text-align: center;
            margin-bottom: 30px;
            color: #333;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        .form-group label {
            display: block;
            margin-bottom: 5px;
            color: #555;
        }
        
        .form-group input, .form-group select {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 5px;
            font-size: 14px;
        }
        
        .btn {
            padding: 10px 20px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 14px;
        }
        
        .btn-primary {
            background: #667eea;
            color: white;
            width: 100%;
            font-size: 16px;
        }
        
        .btn-primary:hover {
            background: #5a67d8;
        }
        
        .btn-success {
            background: #28a745;
            color: white;
        }
        
        .btn-warning {
            background: #ffc107;
            color: #333;
        }
        
        .btn-danger {
            background: #dc3545;
            color: white;
        }
        
        .btn-secondary {
            background: #6c757d;
            color: white;
        }
        
        .error {
            background: #f8d7da;
            color: #721c24;
            padding: 10px;
            border-radius: 5px;
            margin-bottom: 20px;
            text-align: center;
        }
        
        /* Navbar */
        .navbar {
            background: white;
            padding: 15px 30px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .nav-brand {
            font-size: 20px;
            font-weight: bold;
            color: #333;
        }
        
        .nav-brand span {
            color: #667eea;
        }
        
        .nav-menu {
            display: flex;
            gap: 10px;
            align-items: center;
        }
        
        .nav-menu a {
            text-decoration: none;
            color: #555;
            padding: 8px 15px;
            border-radius: 5px;
        }
        
        .nav-menu a:hover, .nav-menu a.active {
            background: #667eea;
            color: white;
        }
        
        .user-info {
            background: #f0f0f0;
            padding: 8px 15px;
            border-radius: 20px;
            color: #333;
            margin: 0 10px;
        }
        
        .badge {
            padding: 3px 8px;
            border-radius: 3px;
            font-size: 11px;
            font-weight: bold;
            margin-left: 5px;
        }
        
        .badge-danger {
            background: #dc3545;
            color: white;
        }
        
        .badge-warning {
            background: #ffc107;
            color: #333;
        }
        
        /* Container */
        .container {
            max-width: 1200px;
            margin: 20px auto;
            padding: 0 20px;
        }
        
        /* Card */
        .card {
            background: white;
            border-radius: 10px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
            padding: 20px;
            margin-bottom: 20px;
        }
        
        .card-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 1px solid #eee;
        }
        
        /* Table */
        table {
            width: 100%;
            border-collapse: collapse;
        }
        
        th {
            background: #f8f9fa;
            padding: 12px;
            text-align: left;
            border-bottom: 2px solid #dee2e6;
        }
        
        td {
            padding: 12px;
            border-bottom: 1px solid #dee2e6;
        }
        
        .status {
            padding: 3px 8px;
            border-radius: 3px;
            font-size: 12px;
            display: inline-block;
        }
        
        .status-active {
            background: #d4edda;
            color: #155724;
        }
        
        .status-inactive {
            background: #f8d7da;
            color: #721c24;
        }
        
        /* Info Box */
        .info-box {
            background: #e7f3ff;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
            border-left: 4px solid #17a2b8;
        }
        
        .welcome-box {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
            border-left: 4px solid #667eea;
        }
        
        .system-info {
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        
        .system-info a {
            color: white;
        }
        
        /* Modal */
        .modal {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0,0,0,0.5);
            justify-content: center;
            align-items: center;
        }
        
        .modal.active {
            display: flex;
        }
        
        .modal-content {
            background: white;
            padding: 30px;
            border-radius: 10px;
            width: 500px;
            max-width: 90%;
        }
        
        .modal-content h3 {
            margin-bottom: 20px;
        }
        
        .modal-buttons {
            display: flex;
            gap: 10px;
            justify-content: flex-end;
            margin-top: 20px;
        }
        
        /* Dashboard */
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        
        .stat-card {
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            padding: 20px;
            border-radius: 10px;
        }
        
        .stat-card h4 {
            margin-bottom: 10px;
            font-size: 16px;
        }
        
        .stat-card p {
            font-size: 30px;
            font-weight: bold;
        }
        
        /* Menu Grid */
        .menu-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin: 20px 0;
        }
        
        .menu-item {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 10px;
            text-align: center;
        }
        
        .menu-item h4 {
            margin-bottom: 10px;
            color: #333;
        }
        
        .menu-item p {
            color: #666;
            font-size: 14px;
            margin-bottom: 10px;
        }
    </style>
</head>
<body>
    <?php if (!isLogin()): ?>
        <!-- Halaman Login -->
        <div class="login-container">
            <div class="login-box">
                <h2>🔐 Login Admin Panel</h2>
                <?php if (isset($error)): ?>
                    <div class="error"><?php echo $error; ?></div>
                <?php endif; ?>
                <form method="post">
                    <div class="form-group">
                        <label>Username</label>
                        <input type="text" name="username" required>
                    </div>
                    <div class="form-group">
                        <label>Password</label>
                        <input type="password" name="password" required>
                    </div>
                    <button type="submit" name="login" class="btn btn-primary">Login</button>
                </form>
                <p style="text-align: center; margin-top: 20px; color: #666; font-size: 14px;">
                    <strong>Default:</strong> admin / admin123
                </p>
            </div>
        </div>
    <?php else: ?>
        <!-- Navbar -->
        <div class="navbar">
            <div class="nav-brand">
                Pterodactyl <span>Panel</span>
            </div>
            <div class="nav-menu">
                <?php if (isAdminUtama()): ?>
                    <a href="?page=dashboard" class="<?php echo ($page == 'dashboard') ? 'active' : ''; ?>">Dashboard</a>
                <?php endif; ?>
                <a href="?page=users" class="<?php echo ($page == 'users') ? 'active' : ''; ?>">Users</a>
                <a href="?page=servers" class="<?php echo ($page == 'servers') ? 'active' : ''; ?>">Servers</a>
                <?php if (isAdminUtama()): ?>
                    <a href="?page=all" class="<?php echo ($page == 'all') ? 'active' : ''; ?>">All Menu</a>
                <?php endif; ?>
                <span class="user-info">
                    👤 <?php echo $_SESSION['username']; ?>
                    <?php if (isAdminUtama()): ?>
                        <span class="badge badge-danger">Admin Utama</span>
                    <?php elseif ($_SESSION['role'] == 'admin'): ?>
                        <span class="badge badge-warning">Admin</span>
                    <?php endif; ?>
                </span>
                <a href="?logout=1" class="btn btn-danger" style="color: white;">Logout</a>
            </div>
        </div>
        
        <div class="container">
            <!-- System Info -->
            <div class="system-info">
                <strong>⚠️ System:</strong> Pterodactyl Panel 1.12.1 | 
                <a href="#">GitHub</a> | Copyright © 2025
            </div>
            
            <!-- Welcome Message -->
            <div class="welcome-box">
                <strong>Selamat datang, <?php echo $_SESSION['username']; ?>!</strong><br>
                <?php if (isAdminUtama()): ?>
                    Anda login sebagai <strong>Admin Utama (ID: 1)</strong> - Akses Penuh
                <?php else: ?>
                    Anda login sebagai <strong><?php echo ucfirst($_SESSION['role']); ?> (ID: <?php echo $_SESSION['user_id']; ?>)</strong>
                <?php endif; ?>
            </div>
            
            <!-- Info untuk non-admin utama -->
            <?php if (!isAdminUtama()): ?>
            <div class="info-box">
                <strong>ℹ️ Info Akses:</strong> 
                - Users: Hanya bisa melihat (tidak bisa edit/hapus)<br>
                - Servers: Bisa tambah/edit/hapus
            </div>
            <?php endif; ?>
            
            <!-- Halaman Dashboard (khusus admin utama) -->
            <?php if ($page == 'dashboard' && isAdminUtama()): ?>
                <div class="card">
                    <div class="card-header">
                        <h2>📊 Dashboard</h2>
                    </div>
                    <?php
                    $totalUsers = $pdo->query("SELECT COUNT(*) FROM users")->fetchColumn();
                    $totalServers = $pdo->query("SELECT COUNT(*) FROM servers")->fetchColumn();
                    $totalAdmins = $pdo->query("SELECT COUNT(*) FROM users WHERE role='admin'")->fetchColumn();
                    $activeServers = $pdo->query("SELECT COUNT(*) FROM servers WHERE status='active'")->fetchColumn();
                    ?>
                    <div class="stats">
                        <div class="stat-card">
                            <h4>Total Users</h4>
                            <p><?php echo $totalUsers; ?></p>
                        </div>
                        <div class="stat-card" style="background: linear-gradient(135deg, #28a745, #20c997);">
                            <h4>Total Servers</h4>
                            <p><?php echo $totalServers; ?></p>
                        </div>
                        <div class="stat-card" style="background: linear-gradient(135deg, #ffc107, #fd7e14);">
                            <h4>Total Admins</h4>
                            <p><?php echo $totalAdmins; ?></p>
                        </div>
                        <div class="stat-card" style="background: linear-gradient(135deg, #17a2b8, #6f42c1);">
                            <h4>Active Servers</h4>
                            <p><?php echo $activeServers; ?></p>
                        </div>
                    </div>
                </div>
            <?php endif; ?>
            
            <!-- Halaman Users -->
            <?php if ($page == 'users'): ?>
                <div class="card">
                    <div class="card-header">
                        <h2>👥 Manajemen Users</h2>
                        <?php if (isAdminUtama()): ?>
                            <button class="btn btn-success" onclick="openModal('modalUser')">+ Tambah User</button>
                        <?php endif; ?>
                    </div>
                    
                    <table>
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>Username</th>
                                <th>Role</th>
                                <th>Status</th>
                                <th>Dibuat</th>
                                <?php if (isAdminUtama()): ?>
                                    <th>Aksi</th>
                                <?php endif; ?>
                            </tr>
                        </thead>
                        <tbody>
                            <?php
                            $users = $pdo->query("SELECT * FROM users ORDER BY id DESC");
                            while($user = $users->fetch()):
                            ?>
                            <tr>
                                <td><?php echo $user['id']; ?></td>
                                <td>
                                    <?php echo $user['username']; ?>
                                    <?php if ($user['id'] == 1): ?>
                                        <span class="badge badge-danger">Admin Utama</span>
                                    <?php elseif ($user['role'] == 'admin'): ?>
                                        <span class="badge badge-warning">Admin</span>
                                    <?php endif; ?>
                                </td>
                                <td><?php echo ucfirst($user['role']); ?></td>
                                <td><span class="status status-active">Active</span></td>
                                <td><?php echo date('d/m/Y', strtotime($user['created_at'])); ?></td>
                                <?php if (isAdminUtama()): ?>
                                    <td>
                                        <?php if ($user['id'] != 1): ?>
                                            <a href="?page=users&hapus_user=<?php echo $user['id']; ?>" class="btn btn-danger btn-small" onclick="return confirm('Hapus user?')">Hapus</a>
                                        <?php else: ?>
                                            <span style="color: #999;">-</span>
                                        <?php endif; ?>
                                    </td>
                                <?php endif; ?>
                            </tr>
                            <?php endwhile; ?>
                        </tbody>
                    </table>
                </div>
            <?php endif; ?>
            
            <!-- Halaman Servers -->
            <?php if ($page == 'servers'): ?>
                <div class="card">
                    <div class="card-header">
                        <h2>🖥️ Manajemen Servers</h2>
                        <button class="btn btn-success" onclick="openModal('modalServer')">+ Tambah Server</button>
                    </div>
                    
                    <table>
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>Nama Server</th>
                                <th>IP Address</th>
                                <th>Status</th>
                                <th>Dibuat</th>
                                <th>Aksi</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php
                            $servers = $pdo->query("SELECT * FROM servers ORDER BY id DESC");
                            while($server = $servers->fetch()):
                            ?>
                            <tr>
                                <td><?php echo $server['id']; ?></td>
                                <td><?php echo $server['name']; ?></td>
                                <td><?php echo $server['ip_address']; ?></td>
                                <td>
                                    <span class="status status-<?php echo $server['status']; ?>">
                                        <?php echo ucfirst($server['status']); ?>
                                    </span>
                                </td>
                                <td><?php echo date('d/m/Y', strtotime($server['created_at'])); ?></td>
                                <td>
                                    <button class="btn btn-warning btn-small" onclick="editServer(<?php echo $server['id']; ?>, '<?php echo $server['name']; ?>', '<?php echo $server['ip_address']; ?>', '<?php echo $server['status']; ?>')">Edit</button>
                                    <a href="?page=servers&hapus_server=<?php echo $server['id']; ?>" class="btn btn-danger btn-small" onclick="return confirm('Hapus server?')">Hapus</a>
                                </td>
                            </tr>
                            <?php endwhile; ?>
                        </tbody>
                    </table>
                </div>
            <?php endif; ?>
            
            <!-- Halaman All Menu (khusus admin utama) -->
            <?php if ($page == 'all' && isAdminUtama()): ?>
                <div class="card">
                    <div class="card-header">
                        <h2>📋 Semua Menu Administrasi</h2>
                    </div>
                    
                    <h3>Basic Administration</h3>
                    <div class="menu-grid">
                        <div class="menu-item">
                            <h4>📊 Overview</h4>
                            <p>Statistik sistem</p>
                            <button class="btn btn-primary btn-small" onclick="alert('Overview - Admin Utama')">View</button>
                        </div>
                        <div class="menu-item">
                            <h4>⚙️ Settings</h4>
                            <p>Pengaturan sistem</p>
                            <button class="btn btn-primary btn-small" onclick="alert('Settings - Admin Utama')">View</button>
                        </div>
                        <div class="menu-item">
                            <h4>🔑 API</h4>
                            <p>API Access</p>
                            <button class="btn btn-primary btn-small" onclick="alert('API - Admin Utama')">View</button>
                        </div>
                    </div>
                    
                    <h3>Management</h3>
                    <div class="menu-grid">
                        <div class="menu-item">
                            <h4>🗄️ Databases</h4>
                            <p>Database</p>
                            <button class="btn btn-primary btn-small" onclick="alert('Databases - Admin Utama')">View</button>
                        </div>
                        <div class="menu-item">
                            <h4>📍 Locations</h4>
                            <p>Lokasi</p>
                            <button class="btn btn-primary btn-small" onclick="alert('Locations - Admin Utama')">View</button>
                        </div>
                        <div class="menu-item">
                            <h4>🌐 Nodes</h4>
                            <p>Nodes</p>
                            <button class="btn btn-primary btn-small" onclick="alert('Nodes - Admin Utama')">View</button>
                        </div>
                    </div>
                    
                    <h3>Service Management</h3>
                    <div class="menu-grid">
                        <div class="menu-item">
                            <h4>💾 Mounts</h4>
                            <p>Mounts</p>
                            <button class="btn btn-primary btn-small" onclick="alert('Mounts - Admin Utama')">View</button>
                        </div>
                        <div class="menu-item">
                            <h4>🏠 Nests</h4>
                            <p>Nests</p>
                            <button class="btn btn-primary btn-small" onclick="alert('Nests - Admin Utama')">View</button>
                        </div>
                    </div>
                </div>
            <?php endif; ?>
        </div>
        
        <!-- Modal Tambah User (hanya admin utama) -->
        <?php if (isAdminUtama()): ?>
        <div id="modalUser" class="modal">
            <div class="modal-content">
                <h3>Tambah User Baru</h3>
                <form method="post">
                    <div class="form-group">
                        <label>Username</label>
                        <input type="text" name="username" required>
                    </div>
                    <div class="form-group">
                        <label>Password</label>
                        <input type="password" name="password" required>
                    </div>
                    <div class="form-group">
                        <label>Role</label>
                        <select name="role">
                            <option value="user">User</option>
                            <option value="admin">Admin</option>
                        </select>
                    </div>
                    <div class="modal-buttons">
                        <button type="button" class="btn btn-secondary" onclick="closeModal('modalUser')">Batal</button>
                        <button type="submit" name="tambah_user" class="btn btn-primary">Simpan</button>
                    </div>
                </form>
            </div>
        </div>
        <?php endif; ?>
        
        <!-- Modal Tambah Server -->
        <div id="modalServer" class="modal">
            <div class="modal-content">
                <h3>Tambah Server Baru</h3>
                <form method="post">
                    <div class="form-group">
                        <label>Nama Server</label>
                        <input type="text" name="name" required>
                    </div>
                    <div class="form-group">
                        <label>IP Address</label>
                        <input type="text" name="ip_address">
                    </div>
                    <div class="modal-buttons">
                        <button type="button" class="btn btn-secondary" onclick="closeModal('modalServer')">Batal</button>
                        <button type="submit" name="tambah_server" class="btn btn-primary">Simpan</button>
                    </div>
                </form>
            </div>
        </div>
        
        <!-- Modal Edit Server -->
        <div id="modalEditServer" class="modal">
            <div class="modal-content">
                <h3>Edit Server</h3>
                <form method="post">
                    <input type="hidden" name="id" id="edit_id">
                    <div class="form-group">
                        <label>Nama Server</label>
                        <input type="text" name="name" id="edit_name" required>
                    </div>
                    <div class="form-group">
                        <label>IP Address</label>
                        <input type="text" name="ip_address" id="edit_ip">
                    </div>
                    <div class="form-group">
                        <label>Status</label>
                        <select name="status" id="edit_status">
                            <option value="active">Active</option>
                            <option value="inactive">Inactive</option>
                        </select>
                    </div>
                    <div class="modal-buttons">
                        <button type="button" class="btn btn-secondary" onclick="closeModal('modalEditServer')">Batal</button>
                        <button type="submit" name="edit_server" class="btn btn-primary">Update</button>
                    </div>
                </form>
            </div>
        </div>
        
        <script>
            function openModal(id) {
                document.getElementById(id).classList.add('active');
            }
            
            function closeModal(id) {
                document.getElementById(id).classList.remove('active');
            }
            
            function editServer(id, name, ip, status) {
                document.getElementById('edit_id').value = id;
                document.getElementById('edit_name').value = name;
                document.getElementById('edit_ip').value = ip;
                document.getElementById('edit_status').value = status;
                openModal('modalEditServer');
            }
            
            window.onclick = function(e) {
                if (e.target.classList.contains('modal')) {
                    e.target.classList.remove('active');
                }
            }
        </script>
    <?php endif; ?>
</body>
</html>
