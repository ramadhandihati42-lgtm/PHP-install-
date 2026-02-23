<?php
session_start();

// Konfigurasi Database
define('DB_HOST', 'localhost');
define('DB_NAME', 'admin_panel');
define('DB_USER', 'root');
define('DB_PASS', '');

// Koneksi Database
try {
    $pdo = new PDO("mysql:host=" . DB_HOST . ";dbname=" . DB_NAME, DB_USER, DB_PASS);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
    
    // Buat tabel jika belum ada
    $pdo->exec("CREATE TABLE IF NOT EXISTS users (
        id INT PRIMARY KEY AUTO_INCREMENT,
        username VARCHAR(50) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL,
        role ENUM('admin', 'user') DEFAULT 'user',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )");
    
    $pdo->exec("CREATE TABLE IF NOT EXISTS servers (
        id INT PRIMARY KEY AUTO_INCREMENT,
        name VARCHAR(100) NOT NULL,
        ip_address VARCHAR(50),
        status ENUM('active', 'inactive') DEFAULT 'active',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )");
    
    // Insert admin default jika belum ada
    $checkAdmin = $pdo->query("SELECT COUNT(*) FROM users WHERE id = 1");
    if ($checkAdmin->fetchColumn() == 0) {
        $hashedPassword = password_hash('admin123', PASSWORD_DEFAULT);
        $pdo->exec("INSERT INTO users (id, username, password, role) VALUES (1, 'admin', '$hashedPassword', 'admin')");
    }
    
} catch(PDOException $e) {
    die("Koneksi database gagal: " . $e->getMessage());
}

// Fungsi Authentication
function isLoggedIn() {
    return isset($_SESSION['user_id']);
}

// Fungsi untuk mengecek apakah user adalah admin utama (ID 1)
function isMainAdmin() {
    return isset($_SESSION['user_id']) && $_SESSION['user_id'] == 1;
}

// Handle Login
if (isset($_POST['login'])) {
    $username = $_POST['username'] ?? '';
    $password = $_POST['password'] ?? '';
    
    $stmt = $pdo->prepare("SELECT * FROM users WHERE username = ?");
    $stmt->execute([$username]);
    $user = $stmt->fetch();
    
    if ($user && password_verify($password, $user['password'])) {
        $_SESSION['user_id'] = $user['id'];
        $_SESSION['username'] = $user['username'];
        $_SESSION['role'] = $user['role'];
        header('Location: ' . $_SERVER['PHP_SELF']);
        exit;
    } else {
        $error = "Username atau password salah!";
    }
}

// Handle Logout
if (isset($_GET['logout'])) {
    session_destroy();
    header('Location: ' . $_SERVER['PHP_SELF']);
    exit;
}

// Handle Tambah User (hanya admin utama ID 1)
if (isMainAdmin() && isset($_POST['add_user'])) {
    $username = $_POST['username'] ?? '';
    $password = password_hash($_POST['password'] ?? '', PASSWORD_DEFAULT);
    $role = $_POST['role'] ?? 'user';
    
    $stmt = $pdo->prepare("INSERT INTO users (username, password, role) VALUES (?, ?, ?)");
    $stmt->execute([$username, $password, $role]);
    $success = "User berhasil ditambahkan!";
    header('Location: ' . $_SERVER['PHP_SELF'] . '?page=users');
    exit;
}

// Handle Hapus User (hanya admin utama ID 1)
if (isMainAdmin() && isset($_GET['delete_user'])) {
    $id = $_GET['delete_user'];
    if ($id != 1) {
        $stmt = $pdo->prepare("DELETE FROM users WHERE id = ?");
        $stmt->execute([$id]);
    }
    header('Location: ' . $_SERVER['PHP_SELF'] . '?page=users');
    exit;
}

// Handle Edit User (hanya admin utama ID 1)
if (isMainAdmin() && isset($_POST['edit_user'])) {
    $id = $_POST['id'];
    $username = $_POST['username'];
    $role = $_POST['role'];
    
    $stmt = $pdo->prepare("UPDATE users SET username = ?, role = ? WHERE id = ?");
    $stmt->execute([$username, $role, $id]);
    
    if (!empty($_POST['new_password'])) {
        $password = password_hash($_POST['new_password'], PASSWORD_DEFAULT);
        $stmt = $pdo->prepare("UPDATE users SET password = ? WHERE id = ?");
        $stmt->execute([$password, $id]);
    }
    
    header('Location: ' . $_SERVER['PHP_SELF'] . '?page=users');
    exit;
}

// Handle Tambah Server
if (isLoggedIn() && isset($_POST['add_server'])) {
    $name = $_POST['name'] ?? '';
    $ip_address = $_POST['ip_address'] ?? '';
    
    $stmt = $pdo->prepare("INSERT INTO servers (name, ip_address) VALUES (?, ?)");
    $stmt->execute([$name, $ip_address]);
    header('Location: ' . $_SERVER['PHP_SELF'] . '?page=servers');
    exit;
}

// Handle Hapus Server
if (isLoggedIn() && isset($_GET['delete_server'])) {
    $stmt = $pdo->prepare("DELETE FROM servers WHERE id = ?");
    $stmt->execute([$_GET['delete_server']]);
    header('Location: ' . $_SERVER['PHP_SELF'] . '?page=servers');
    exit;
}

// Handle Edit Server
if (isLoggedIn() && isset($_POST['edit_server'])) {
    $id = $_POST['id'];
    $name = $_POST['name'];
    $ip_address = $_POST['ip_address'];
    $status = $_POST['status'];
    
    $stmt = $pdo->prepare("UPDATE servers SET name = ?, ip_address = ?, status = ? WHERE id = ?");
    $stmt->execute([$name, $ip_address, $status, $id]);
    header('Location: ' . $_SERVER['PHP_SELF'] . '?page=servers');
    exit;
}

// Get Current Page
$page = $_GET['page'] ?? (isMainAdmin() ? 'dashboard' : 'users');
?>

<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Panel - Pterodactyl</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: Arial, sans-serif;
            background: #f5f5f5;
        }
        
        .login-container {
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        
        .login-box {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 10px 25px rgba(0,0,0,0.2);
            width: 400px;
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
        }
        
        .btn-login, .btn {
            padding: 10px 20px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 14px;
        }
        
        .btn-login {
            width: 100%;
            background: #667eea;
            color: white;
            font-size: 16px;
        }
        
        .btn-login:hover {
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
        
        .btn-primary {
            background: #667eea;
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
        
        .navbar {
            background: white;
            padding: 15px 30px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
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
            padding: 8px 16px;
            border-radius: 5px;
        }
        
        .nav-menu a:hover, .nav-menu a.active {
            background: #667eea;
            color: white;
        }
        
        .nav-menu .user-info {
            background: #f0f0f0;
            padding: 8px 16px;
            border-radius: 20px;
            color: #333;
        }
        
        .nav-menu .logout {
            background: #fee;
            color: #c33;
        }
        
        .nav-menu .logout:hover {
            background: #c33;
            color: white;
        }
        
        .container {
            max-width: 1200px;
            margin: 20px auto;
            padding: 0 20px;
        }
        
        .content-card {
            background: white;
            border-radius: 10px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            padding: 30px;
        }
        
        .content-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
        }
        
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
        
        .status-badge {
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
        }
        
        .status-active {
            background: #d4edda;
            color: #155724;
        }
        
        .status-inactive {
            background: #f8d7da;
            color: #721c24;
        }
        
        .main-admin-badge {
            background: #dc3545;
            color: white;
            padding: 2px 6px;
            border-radius: 3px;
            font-size: 11px;
            margin-left: 5px;
        }
        
        .admin-badge {
            background: #ffc107;
            color: #333;
            padding: 2px 6px;
            border-radius: 3px;
            font-size: 11px;
            margin-left: 5px;
        }
        
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
        }
        
        .modal-buttons {
            display: flex;
            gap: 10px;
            justify-content: flex-end;
            margin-top: 20px;
        }
        
        .system-info {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 20px;
        }
        
        .system-info a {
            color: white;
        }
        
        .welcome-message {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 20px;
            border-left: 4px solid #667eea;
        }
        
        .info-box {
            background: #e7f3ff;
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 20px;
            border-left: 4px solid #17a2b8;
        }
        
        .dashboard-stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        
        .stat-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 10px;
        }
        
        .stat-card h3 {
            margin-bottom: 10px;
            font-size: 16px;
        }
        
        .stat-card p {
            font-size: 36px;
            font-weight: bold;
        }
        
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
        
        .menu-item h3 {
            margin-bottom: 10px;
            color: #333;
        }
        
        .menu-item p {
            color: #666;
            font-size: 14px;
            margin-bottom: 10px;
        }
        
        .action-buttons {
            display: flex;
            gap: 5px;
        }
        
        .btn-small {
            padding: 5px 10px;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <?php if (!isLoggedIn()): ?>
        <div class="login-container">
            <div class="login-box">
                <h2>🔐 Admin Panel Login</h2>
                <?php if (isset($error)): ?>
                    <div class="error"><?php echo $error; ?></div>
                <?php endif; ?>
                <form method="POST">
                    <div class="form-group">
                        <label>Username</label>
                        <input type="text" name="username" required>
                    </div>
                    <div class="form-group">
                        <label>Password</label>
                        <input type="password" name="password" required>
                    </div>
                    <button type="submit" name="login" class="btn-login">Login</button>
                </form>
            </div>
        </div>
    <?php else: ?>
        <div class="navbar">
            <div class="nav-brand">Pterodactyl <span>Admin</span></div>
            <div class="nav-menu">
                <?php if (isMainAdmin()): ?>
                    <a href="?page=dashboard" class="<?php echo $page == 'dashboard' ? 'active' : ''; ?>">Dashboard</a>
                <?php endif; ?>
                <a href="?page=users" class="<?php echo $page == 'users' ? 'active' : ''; ?>">Users</a>
                <a href="?page=servers" class="<?php echo $page == 'servers' ? 'active' : ''; ?>">Servers</a>
                <?php if (isMainAdmin()): ?>
                    <a href="?page=all" class="<?php echo $page == 'all' ? 'active' : ''; ?>">All Menu</a>
                <?php endif; ?>
                <span class="user-info">
                    👤 <?php echo $_SESSION['username']; ?>
                    <?php if (isMainAdmin()): ?>
                        <span class="main-admin-badge">Main Admin</span>
                    <?php endif; ?>
                </span>
                <a href="?logout=1" class="logout">Logout</a>
            </div>
        </div>
        
        <div class="container">
            <div class="system-info">
                <strong>⚠️ System Information:</strong> Panel version 1.12.1 | 
                <a href="#">Get Help</a> | Copyright © 2025
            </div>
            
            <div class="welcome-message">
                <strong>Selamat datang, <?php echo $_SESSION['username']; ?>!</strong><br>
                <?php if (isMainAdmin()): ?>
                    Anda login sebagai <strong>Admin Utama (ID: 1)</strong> dengan akses penuh.
                <?php else: ?>
                    Anda login sebagai <strong>User (ID: <?php echo $_SESSION['user_id']; ?>)</strong> dengan akses terbatas.
                <?php endif; ?>
            </div>
            
            <?php if (!isMainAdmin()): ?>
            <div class="info-box">
                <strong>ℹ️ Informasi Akses:</strong> Anda hanya dapat melihat daftar users (tanpa edit/hapus) dan mengelola servers.
            </div>
            <?php endif; ?>
            
            <?php if ($page == 'dashboard' && isMainAdmin()): ?>
                <div class="content-card">
                    <div class="content-header">
                        <h1>📊 Dashboard</h1>
                    </div>
                    
                    <?php
                    $totalUsers = $pdo->query("SELECT COUNT(*) FROM users")->fetchColumn();
                    $totalServers = $pdo->query("SELECT COUNT(*) FROM servers")->fetchColumn();
                    $totalAdmins = $pdo->query("SELECT COUNT(*) FROM users WHERE role = 'admin'")->fetchColumn();
                    $activeServers = $pdo->query("SELECT COUNT(*) FROM servers WHERE status = 'active'")->fetchColumn();
                    ?>
                    
                    <div class="dashboard-stats">
                        <div class="stat-card">
                            <h3>Total Users</h3>
                            <p><?php echo $totalUsers; ?></p>
                        </div>
                        <div class="stat-card" style="background: linear-gradient(135deg, #28a745 0%, #20c997 100%);">
                            <h3>Total Servers</h3>
                            <p><?php echo $totalServers; ?></p>
                        </div>
                        <div class="stat-card" style="background: linear-gradient(135deg, #ffc107 0%, #fd7e14 100%);">
                            <h3>Total Admins</h3>
                            <p><?php echo $totalAdmins; ?></p>
                        </div>
                        <div class="stat-card" style="background: linear-gradient(135deg, #17a2b8 0%, #6f42c1 100%);">
                            <h3>Active Servers</h3>
                            <p><?php echo $activeServers; ?></p>
                        </div>
                    </div>
                </div>
            <?php endif; ?>
            
            <?php if ($page == 'users'): ?>
                <div class="content-card">
                    <div class="content-header">
                        <h1>👥 User Management</h1>
                        <?php if (isMainAdmin()): ?>
                            <button class="btn btn-success" onclick="openModal('addUserModal')">+ Add User</button>
                        <?php endif; ?>
                    </div>
                    
                    <table>
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>Username</th>
                                <th>Role</th>
                                <th>Status</th>
                                <th>Created</th>
                                <?php if (isMainAdmin()): ?>
                                    <th>Actions</th>
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
                                        <span class="main-admin-badge">Main Admin</span>
                                    <?php elseif ($user['role'] == 'admin'): ?>
                                        <span class="admin-badge">Admin</span>
                                    <?php endif; ?>
                                </td>
                                <td><?php echo ucfirst($user['role']); ?></td>
                                <td><span class="status-badge status-active">Active</span></td>
                                <td><?php echo $user['created_at']; ?></td>
                                <?php if (isMainAdmin()): ?>
                                    <td>
                                        <?php if ($user['id'] != 1): ?>
                                            <button class="btn btn-warning btn-small" onclick="editUser(<?php echo $user['id']; ?>, '<?php echo $user['username']; ?>', '<?php echo $user['role']; ?>')">Edit</button>
                                            <a href="?page=users&delete_user=<?php echo $user['id']; ?>" class="btn btn-danger btn-small" onclick="return confirm('Hapus user?')">Delete</a>
                                        <?php else: ?>
                                            <span style="color: #999;">No actions</span>
                                        <?php endif; ?>
                                    </td>
                                <?php endif; ?>
                            </tr>
                            <?php endwhile; ?>
                        </tbody>
                    </table>
                </div>
            <?php endif; ?>
            
            <?php if ($page == 'servers'): ?>
                <div class="content-card">
                    <div class="content-header">
                        <h1>🖥️ Server Management</h1>
                        <button class="btn btn-success" onclick="openModal('addServerModal')">+ Add Server</button>
                    </div>
                    
                    <table>
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>Name</th>
                                <th>IP Address</th>
                                <th>Status</th>
                                <th>Created</th>
                                <th>Actions</th>
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
                                    <span class="status-badge status-<?php echo $server['status']; ?>">
                                        <?php echo ucfirst($server['status']); ?>
                                    </span>
                                </td>
                                <td><?php echo $server['created_at']; ?></td>
                                <td>
                                    <button class="btn btn-warning btn-small" onclick="editServer(<?php echo $server['id']; ?>, '<?php echo $server['name']; ?>', '<?php echo $server['ip_address']; ?>', '<?php echo $server['status']; ?>')">Edit</button>
                                    <a href="?page=servers&delete_server=<?php echo $server['id']; ?>" class="btn btn-danger btn-small" onclick="return confirm('Hapus server?')">Delete</a>
                                </td>
                            </tr>
                            <?php endwhile; ?>
                        </tbody>
                    </table>
                </div>
            <?php endif; ?>
            
            <?php if ($page == 'all' && isMainAdmin()): ?>
                <div class="content-card">
                    <div class="content-header">
                        <h1>📋 Complete Administration</h1>
                    </div>
                    
                    <h3>Basic Administration</h3>
                    <div class="menu-grid">
                        <div class="menu-item">
                            <h3>📊 Overview</h3>
                            <p>System statistics</p>
                            <button class="btn btn-primary btn-small" onclick="alert('Overview - Main Admin only')">View</button>
                        </div>
                        <div class="menu-item">
                            <h3>⚙️ Settings</h3>
                            <p>System settings</p>
                            <button class="btn btn-primary btn-small" onclick="alert('Settings - Main Admin only')">View</button>
                        </div>
                        <div class="menu-item">
                            <h3>🔑 API</h3>
                            <p>API access</p>
                            <button class="btn btn-primary btn-small" onclick="alert('API - Main Admin only')">View</button>
                        </div>
                    </div>
                    
                    <h3>Management</h3>
                    <div class="menu-grid">
                        <div class="menu-item">
                            <h3>🗄️ Databases</h3>
                            <p>Manage databases</p>
                            <button class="btn btn-primary btn-small" onclick="alert('Databases - Main Admin only')">View</button>
                        </div>
                        <div class="menu-item">
                            <h3>📍 Locations</h3>
                            <p>Server locations</p>
                            <button class="btn btn-primary btn-small" onclick="alert('Locations - Main Admin only')">View</button>
                        </div>
                        <div class="menu-item">
                            <h3>🌐 Nodes</h3>
                            <p>Manage nodes</p>
                            <button class="btn btn-primary btn-small" onclick="alert('Nodes - Main Admin only')">View</button>
                        </div>
                    </div>
                    
                    <h3>Service Management</h3>
                    <div class="menu-grid">
                        <div class="menu-item">
                            <h3>💾 Mounts</h3>
                            <p>Manage mounts</p>
                            <button class="btn btn-primary btn-small" onclick="alert('Mounts - Main Admin only')">View</button>
                        </div>
                        <div class="menu-item">
                            <h3>🏠 Nests</h3>
                            <p>Manage nests</p>
                            <button class="btn btn-primary btn-small" onclick="alert('Nests - Main Admin only')">View</button>
                        </div>
                    </div>
                </div>
            <?php endif; ?>
        </div>
        
        <?php if (isMainAdmin()): ?>
        <div id="addUserModal" class="modal">
            <div class="modal-content">
                <h2>Tambah User</h2>
                <form method="POST">
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
                        <button type="button" class="btn btn-secondary" onclick="closeModal('addUserModal')">Batal</button>
                        <button type="submit" name="add_user" class="btn btn-primary">Simpan</button>
                    </div>
                </form>
            </div>
        </div>
        
        <div id="editUserModal" class="modal">
            <div class="modal-content">
                <h2>Edit User</h2>
                <form method="POST">
                    <input type="hidden" name="id" id="edit_user_id">
                    <div class="form-group">
                        <label>Username</label>
                        <input type="text" name="username" id="edit_username" required>
                    </div>
                    <div class="form-group">
                        <label>Password Baru</label>
                        <input type="password" name="new_password" placeholder="Kosongkan jika tidak ingin mengubah">
                    </div>
                    <div class="form-group">
                        <label>Role</label>
                        <select name="role" id="edit_role">
                            <option value="user">User</option>
                            <option value="admin">Admin</option>
                        </select>
                    </div>
                    <div class="modal-buttons">
                        <button type="button" class="btn btn-secondary" onclick="closeModal('editUserModal')">Batal</button>
                        <button type="submit" name="edit_user" class="btn btn-primary">Update</button>
                    </div>
                </form>
            </div>
        </div>
        <?php endif; ?>
        
        <div id="addServerModal" class="modal">
            <div class="modal-content">
                <h2>Tambah Server</h2>
                <form method="POST">
                    <div class="form-group">
                        <label>Nama Server</label>
                        <input type="text" name="name" required>
                    </div>
                    <div class="form-group">
                        <label>IP Address</label>
                        <input type="text" name="ip_address">
                    </div>
                    <div class="modal-buttons">
                        <button type="button" class="btn btn-secondary" onclick="closeModal('addServerModal')">Batal</button>
                        <button type="submit" name="add_server" class="btn btn-primary">Simpan</button>
                    </div>
                </form>
            </div>
        </div>
        
        <div id="editServerModal" class="modal">
            <div class="modal-content">
                <h2>Edit Server</h2>
                <form method="POST">
                    <input type="hidden" name="id" id="edit_server_id">
                    <div class="form-group">
                        <label>Nama Server</label>
                        <input type="text" name="name" id="edit_server_name" required>
                    </div>
                    <div class="form-group">
                        <label>IP Address</label>
                        <input type="text" name="ip_address" id="edit_server_ip">
                    </div>
                    <div class="form-group">
                        <label>Status</label>
                        <select name="status" id="edit_server_status">
                            <option value="active">Active</option>
                            <option value="inactive">Inactive</option>
                        </select>
                    </div>
                    <div class="modal-buttons">
                        <button type="button" class="btn btn-secondary" onclick="closeModal('editServerModal')">Batal</button>
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
            
            function editUser(id, username, role) {
                document.getElementById('edit_user_id').value = id;
                document.getElementById('edit_username').value = username;
                document.getElementById('edit_role').value = role;
                openModal('editUserModal');
            }
            
            function editServer(id, name, ip, status) {
                document.getElementById('edit_server_id').value = id;
                document.getElementById('edit_server_name').value = name;
                document.getElementById('edit_server_ip').value = ip;
                document.getElementById('edit_server_status').value = status;
                openModal('editServerModal');
            }
            
            window.onclick = function(event) {
                if (event.target.classList.contains('modal')) {
                    event.target.classList.remove('active');
                }
            }
        </script>
    <?php endif; ?>
</body>
</html>
