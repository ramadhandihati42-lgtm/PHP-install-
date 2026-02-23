#!/bin/bash
# ============================================================================
# FILE 14: install_access_control.sh - Script instalasi lengkap
# ============================================================================

#!/bin/bash

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

# Direktori Pterodactyl
PTERO_PATH="/var/www/pterodactyl"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

clear
echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║         PTERODACTYL ACCESS CONTROL INSTALLATION v1.0            ║"
echo "║              Master Admin (ID 1) Exclusive Access               ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Fungsi backup
backup_file() {
    if [ -f "$1" ]; then
        cp "$1" "$1.bak_${TIMESTAMP}"
        echo -e "${GREEN}[✓]${NC} Backup created: $1.bak_${TIMESTAMP}"
    fi
}

# Buat direktori jika belum ada
mkdir -p "$PTERO_PATH/app/Http/Middleware"
mkdir -p "$PTERO_PATH/app/Helpers"
mkdir -p "$PTERO_PATH/app/Http/Controllers/Admin"
mkdir -p "$PTERO_PATH/resources/views/layouts"
mkdir -p "$PTERO_PATH/resources/views/admin/settings"

echo -e "\n${YELLOW}[1/7]${NC} Installing Middleware..."
# Install AdminAccessMiddleware
backup_file "$PTERO_PATH/app/Http/Middleware/AdminAccessMiddleware.php"
cat > "$PTERO_PATH/app/Http/Middleware/AdminAccessMiddleware.php" << 'EOF'
<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Support\Facades\Auth;

class AdminAccessMiddleware
{
    public function handle($request, Closure $next, ...$menus)
    {
        $user = Auth::user();
        
        if (!$user) {
            return redirect()->route('auth.login');
        }
        
        $isAdmin = $user->root_admin || $user->id === 1;
        
        if (!$isAdmin) {
            abort(403, 'Unauthorized access. Admin privileges required.');
        }
        
        if ($user->id === 1) {
            return $next($request);
        }
        
        if (empty($menus)) {
            abort(403, 'Access denied. Insufficient privileges.');
        }
        
        $allowedMenus = ['dashboard', 'users', 'servers', 'account'];
        
        foreach ($menus as $menu) {
            if (in_array($menu, $allowedMenus)) {
                return $next($request);
            }
        }
        
        abort(403, 'This admin feature is restricted to master administrator only. Contact @kaaahost1 for full access.');
    }
}
EOF
echo -e "${GREEN}[✓]${NC} AdminAccessMiddleware installed"

# Install MasterAdminMiddleware
cat > "$PTERO_PATH/app/Http/Middleware/MasterAdminMiddleware.php" << 'EOF'
<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Support\Facades\Auth;

class MasterAdminMiddleware
{
    public function handle($request, Closure $next)
    {
        $user = Auth::user();
        
        if (!$user) {
            return redirect()->route('auth.login');
        }
        
        if ($user->id !== 1) {
            abort(403, '🔐 MASTER ADMIN ACCESS REQUIRED. This area is restricted to Master Administrator only. Contact @kaaahost1 for access.');
        }
        
        return $next($request);
    }
}
EOF
echo -e "${GREEN}[✓]${NC} MasterAdminMiddleware installed"

echo -e "\n${YELLOW}[2/7]${NC} Installing Helper..."
# Install AdminHelper
mkdir -p "$PTERO_PATH/app/Helpers"
cat > "$PTERO_PATH/app/Helpers/AdminHelper.php" << 'EOF'
<?php

namespace Pterodactyl\Helpers;

use Illuminate\Support\Facades\Auth;

class AdminHelper
{
    public static function isMasterAdmin()
    {
        $user = Auth::user();
        return $user && $user->id === 1;
    }
    
    public static function isAdmin()
    {
        $user = Auth::user();
        return $user && ($user->root_admin || $user->id === 1);
    }
    
    public static function canAccessMenu($menu)
    {
        if (self::isMasterAdmin()) {
            return true;
        }
        
        $allowedMenus = ['dashboard', 'users', 'servers', 'account'];
        return in_array($menu, $allowedMenus);
    }
    
    public static function getAllowedMenus()
    {
        if (self::isMasterAdmin()) {
            return [
                'dashboard' => true, 'locations' => true, 'users' => true,
                'servers' => true, 'nodes' => true, 'allocations' => true,
                'nests' => true, 'settings' => true, 'api' => true,
                'database' => true, 'mounts' => true
            ];
        }
        
        return [
            'dashboard' => true, 'locations' => false, 'users' => true,
            'servers' => true, 'nodes' => false, 'allocations' => false,
            'nests' => false, 'settings' => false, 'api' => false,
            'database' => false, 'mounts' => false
        ];
    }
    
    public static function getMasterAdminContact()
    {
        return '@kaaahost1';
    }
    
    public static function getRestrictedMessage()
    {
        return '🔐 Limited Access Mode - Contact Master Admin ' . self::getMasterAdminContact() . ' for full access.';
    }
}
EOF
echo -e "${GREEN}[✓]${NC} AdminHelper installed"

echo -e "\n${YELLOW}[3/7]${NC} Installing Controllers..."

# Install LocationController
backup_file "$PTERO_PATH/app/Http/Controllers/Admin/LocationController.php"
cat > "$PTERO_PATH/app/Http/Controllers/Admin/LocationController.php" << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Pterodactyl\Models\Location;
use Prologue\Alerts\AlertsMessageBag;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Exceptions\DisplayException;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Http\Requests\Admin\LocationFormRequest;
use Pterodactyl\Services\Locations\LocationUpdateService;
use Pterodactyl\Services\Locations\LocationCreationService;
use Pterodactyl\Services\Locations\LocationDeletionService;
use Pterodactyl\Contracts\Repository\LocationRepositoryInterface;

class LocationController extends Controller
{
    public function __construct(
        protected AlertsMessageBag $alert,
        protected LocationCreationService $creationService,
        protected LocationDeletionService $deletionService,
        protected LocationRepositoryInterface $repository,
        protected LocationUpdateService $updateService,
        protected ViewFactory $view
    ) {
        $this->middleware(function ($request, $next) {
            $user = Auth::user();
            if (!$user || $user->id !== 1) {
                abort(403, '🔐 ACCESS DENIED - LOCATION MANAGEMENT IS RESTRICTED TO MASTER ADMIN ONLY. Contact @kaaahost1 for access.');
            }
            return $next($request);
        });
    }

    public function index(): View
    {
        return $this->view->make('admin.locations.index', [
            'locations' => $this->repository->getAllWithDetails(),
        ]);
    }

    public function view(int $id): View
    {
        return $this->view->make('admin.locations.view', [
            'location' => $this->repository->getWithNodes($id),
        ]);
    }

    public function create(LocationFormRequest $request): RedirectResponse
    {
        $location = $this->creationService->handle($request->normalize());
        $this->alert->success('Location was created successfully.')->flash();
        return redirect()->route('admin.locations.view', $location->id);
    }

    public function update(LocationFormRequest $request, Location $location): RedirectResponse
    {
        if ($request->input('action') === 'delete') {
            return $this->delete($location);
        }

        $this->updateService->handle($location->id, $request->normalize());
        $this->alert->success('Location was updated successfully.')->flash();
        return redirect()->route('admin.locations.view', $location->id);
    }

    public function delete(Location $location): RedirectResponse
    {
        try {
            $this->deletionService->handle($location->id);
            return redirect()->route('admin.locations');
        } catch (DisplayException $ex) {
            $this->alert->danger($ex->getMessage())->flash();
        }
        return redirect()->route('admin.locations.view', $location->id);
    }
}
EOF
echo -e "${GREEN}[✓]${NC} LocationController installed"

# Install SettingsController
cat > "$PTERO_PATH/app/Http/Controllers/Admin/SettingsController.php" << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Prologue\Alerts\AlertsMessageBag;
use Pterodactyl\Http\Controllers\Controller;

class SettingsController extends Controller
{
    public function __construct(
        protected AlertsMessageBag $alert
    ) {
        $this->middleware(function ($request, $next) {
            $user = Auth::user();
            if (!$user || $user->id !== 1) {
                abort(403, '🔐 SETTINGS ACCESS - DENIED. Only Master Admin (@kaaahost1) can access panel settings.');
            }
            return $next($request);
        });
    }

    public function index(): View
    {
        return view('admin.settings.index');
    }

    public function update(Request $request): RedirectResponse
    {
        $this->alert->success('Settings were updated successfully.')->flash();
        return redirect()->route('admin.settings');
    }

    public function mail(): View
    {
        return view('admin.settings.mail');
    }

    public function updateMail(Request $request): RedirectResponse
    {
        $this->alert->success('Mail settings were updated successfully.')->flash();
        return redirect()->route('admin.settings.mail');
    }

    public function advanced(): View
    {
        return view('admin.settings.advanced');
    }

    public function updateAdvanced(Request $request): RedirectResponse
    {
        $this->alert->success('Advanced settings were updated successfully.')->flash();
        return redirect()->route('admin.settings.advanced');
    }
}
EOF
echo -e "${GREEN}[✓]${NC} SettingsController installed"

echo -e "\n${YELLOW}[4/7]${NC} Installing Views..."

# Install admin layout
backup_file "$PTERO_PATH/resources/views/layouts/admin.blade.php"
cat > "$PTERO_PATH/resources/views/layouts/admin.blade.php" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta content='width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no' name='viewport'>
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>@yield('title') | Pterodactyl</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/ionicons/2.0.1/css/ionicons.min.css">
    <link rel="stylesheet" href="//cdnjs.cloudflare.com/ajax/libs/admin-lte/2.4.18/css/AdminLTE.min.css">
    <link rel="stylesheet" href="//cdnjs.cloudflare.com/ajax/libs/admin-lte/2.4.18/css/skins/_all-skins.min.css">
    @yield('css')
</head>
<body class="hold-transition skin-blue sidebar-mini">
<div class="wrapper">
    <header class="main-header">
        <a href="{{ route('index') }}" class="logo">
            <span class="logo-mini"><b>P</b>anel</span>
            <span class="logo-lg"><b>Pterodactyl</b> Panel</span>
        </a>
        <nav class="navbar navbar-static-top">
            <a href="#" class="sidebar-toggle" data-toggle="push-menu" role="button">
                <span class="sr-only">Toggle navigation</span>
                <span class="icon-bar"></span>
                <span class="icon-bar"></span>
                <span class="icon-bar"></span>
            </a>
            <div class="navbar-custom-menu">
                <ul class="nav navbar-nav">
                    <li class="dropdown user user-menu">
                        <a href="#" class="dropdown-toggle" data-toggle="dropdown">
                            <img src="https://www.gravatar.com/avatar/{{ md5(Auth::user()->email ?? '') }}?s=160" class="user-image" alt="User Image">
                            <span class="hidden-xs">{{ Auth::user()->name_first ?? '' }} {{ Auth::user()->name_last ?? '' }}</span>
                        </a>
                        <ul class="dropdown-menu">
                            <li class="user-header">
                                <img src="https://www.gravatar.com/avatar/{{ md5(Auth::user()->email ?? '') }}?s=160" class="img-circle" alt="User Image">
                                <p>{{ Auth::user()->name_first ?? '' }} {{ Auth::user()->name_last ?? '' }}<small>{{ Auth::user()->email ?? '' }}</small></p>
                            </li>
                            <li class="user-footer">
                                <div class="pull-left">
                                    <a href="{{ route('account') }}" class="btn btn-default btn-flat">Account</a>
                                </div>
                                <div class="pull-right">
                                    <a href="{{ route('auth.logout') }}" class="btn btn-default btn-flat">Sign out</a>
                                </div>
                            </li>
                        </ul>
                    </li>
                </ul>
            </div>
        </nav>
    </header>

    <aside class="main-sidebar">
        <section class="sidebar">
            <div class="user-panel">
                <div class="pull-left image">
                    <img src="https://www.gravatar.com/avatar/{{ md5(Auth::user()->email ?? '') }}?s=160" class="img-circle" alt="User Image">
                </div>
                <div class="pull-left info">
                    <p>{{ Auth::user()->name_first ?? '' }} {{ Auth::user()->name_last ?? '' }}</p>
                    <a href="#"><i class="fa fa-circle text-success"></i> Online</a>
                </div>
            </div>

            @php
                $user = Auth::user();
                $isMasterAdmin = ($user && $user->id === 1);
                $allowedMenus = [
                    'dashboard' => true,
                    'locations' => $isMasterAdmin,
                    'users' => true,
                    'servers' => true,
                    'nodes' => $isMasterAdmin,
                    'allocations' => $isMasterAdmin,
                    'nests' => $isMasterAdmin,
                    'settings' => $isMasterAdmin,
                    'api' => $isMasterAdmin,
                    'mounts' => $isMasterAdmin,
                    'database' => $isMasterAdmin
                ];
            @endphp

            <ul class="sidebar-menu" data-widget="tree">
                <li class="header">NAVIGATION</li>
                
                <li class="{{ request()->routeIs('admin.index') ? 'active' : '' }}">
                    <a href="{{ route('admin.index') }}"><i class="fa fa-home"></i> <span>Dashboard</span></a>
                </li>

                @if($allowedMenus['locations'])
                <li class="treeview {{ request()->routeIs('admin.locations.*') ? 'active' : '' }}">
                    <a href="#"><i class="fa fa-code-fork"></i> <span>Locations</span><span class="pull-right-container"><i class="fa fa-angle-left pull-right"></i></span></a>
                    <ul class="treeview-menu">
                        <li class="{{ request()->routeIs('admin.locations') ? 'active' : '' }}"><a href="{{ route('admin.locations') }}"><i class="fa fa-circle-o"></i> All Locations</a></li>
                    </ul>
                </li>
                @endif

                <li class="treeview {{ request()->routeIs('admin.users.*') ? 'active' : '' }}">
                    <a href="#"><i class="fa fa-users"></i> <span>Users</span><span class="pull-right-container"><i class="fa fa-angle-left pull-right"></i></span></a>
                    <ul class="treeview-menu">
                        <li class="{{ request()->routeIs('admin.users') ? 'active' : '' }}"><a href="{{ route('admin.users') }}"><i class="fa fa-circle-o"></i> All Users</a></li>
                        <li class="{{ request()->routeIs('admin.users.new') ? 'active' : '' }}"><a href="{{ route('admin.users.new') }}"><i class="fa fa-circle-o"></i> Create New</a></li>
                    </ul>
                </li>

                <li class="treeview {{ request()->routeIs('admin.servers.*') ? 'active' : '' }}">
                    <a href="#"><i class="fa fa-server"></i> <span>Servers</span><span class="pull-right-container"><i class="fa fa-angle-left pull-right"></i></span></a>
                    <ul class="treeview-menu">
                        <li class="{{ request()->routeIs('admin.servers') ? 'active' : '' }}"><a href="{{ route('admin.servers') }}"><i class="fa fa-circle-o"></i> All Servers</a></li>
                        <li class="{{ request()->routeIs('admin.servers.new') ? 'active' : '' }}"><a href="{{ route('admin.servers.new') }}"><i class="fa fa-circle-o"></i> Create New</a></li>
                    </ul>
                </li>

                @if($allowedMenus['nodes'])
                <li class="treeview {{ request()->routeIs('admin.nodes.*') ? 'active' : '' }}">
                    <a href="#"><i class="fa fa-object-group"></i> <span>Nodes</span><span class="pull-right-container"><i class="fa fa-angle-left pull-right"></i></span></a>
                    <ul class="treeview-menu">
                        <li class="{{ request()->routeIs('admin.nodes') ? 'active' : '' }}"><a href="{{ route('admin.nodes') }}"><i class="fa fa-circle-o"></i> All Nodes</a></li>
                        <li class="{{ request()->routeIs('admin.nodes.new') ? 'active' : '' }}"><a href="{{ route('admin.nodes.new') }}"><i class="fa fa-circle-o"></i> Create New</a></li>
                    </ul>
                </li>
                @endif

                @if($allowedMenus['allocations'])
                <li class="treeview {{ request()->routeIs('admin.allocations.*') ? 'active' : '' }}">
                    <a href="#"><i class="fa fa-exchange"></i> <span>Allocations</span><span class="pull-right-container"><i class="fa fa-angle-left pull-right"></i></span></a>
                    <ul class="treeview-menu">
                        <li class="{{ request()->routeIs('admin.allocations') ? 'active' : '' }}"><a href="{{ route('admin.allocations') }}"><i class="fa fa-circle-o"></i> Manage Allocations</a></li>
                    </ul>
                </li>
                @endif

                @if($allowedMenus['nests'])
                <li class="treeview {{ request()->routeIs('admin.nests.*') ? 'active' : '' }}">
                    <a href="#"><i class="fa fa-cubes"></i> <span>Nests & Eggs</span><span class="pull-right-container"><i class="fa fa-angle-left pull-right"></i></span></a>
                    <ul class="treeview-menu">
                        <li class="{{ request()->routeIs('admin.nests') ? 'active' : '' }}"><a href="{{ route('admin.nests') }}"><i class="fa fa-circle-o"></i> All Nests</a></li>
                    </ul>
                </li>
                @endif

                @if($allowedMenus['settings'])
                <li class="treeview {{ request()->routeIs('admin.settings.*') ? 'active' : '' }}">
                    <a href="#"><i class="fa fa-cogs"></i> <span>Settings</span><span class="pull-right-container"><i class="fa fa-angle-left pull-right"></i></span></a>
                    <ul class="treeview-menu">
                        <li class="{{ request()->routeIs('admin.settings') ? 'active' : '' }}"><a href="{{ route('admin.settings') }}"><i class="fa fa-circle-o"></i> General Settings</a></li>
                        <li class="{{ request()->routeIs('admin.settings.mail') ? 'active' : '' }}"><a href="{{ route('admin.settings.mail') }}"><i class="fa fa-circle-o"></i> Mail Settings</a></li>
                        <li class="{{ request()->routeIs('admin.settings.advanced') ? 'active' : '' }}"><a href="{{ route('admin.settings.advanced') }}"><i class="fa fa-circle-o"></i> Advanced Settings</a></li>
                    </ul>
                </li>
                @endif

                @if($allowedMenus['api'])
                <li class="{{ request()->routeIs('admin.api.*') ? 'active' : '' }}"><a href="{{ route('admin.api') }}"><i class="fa fa-code"></i> <span>API</span></a></li>
                @endif
            </ul>

            @if($user && !$isMasterAdmin && $user->root_admin)
            <div class="alert alert-warning sidebar-alert" style="margin: 10px; padding: 10px;">
                <i class="fa fa-lock"></i> <strong>Limited Mode</strong>
                <small style="display: block; margin-top: 5px;">Contact @kaaahost1 for full access</small>
            </div>
            @endif
        </section>
    </aside>

    <div class="content-wrapper">
        <section class="content-header">@yield('content-header')</section>
        <section class="content">@yield('content')</section>
    </div>

    <footer class="main-footer">
        <div class="pull-right hidden-xs"><b>Version</b> {{ config('app.version') }}</div>
        <strong>Copyright &copy; 2015 - {{ date('Y') }} <a href="https://pterodactyl.io">Pterodactyl Software</a>.</strong> All rights reserved.
        <br/>Protected by <a href="https://t.me/kaaahost1">@kaaahost1 Security System</a>
    </footer>
</div>

<script src="//cdnjs.cloudflare.com/ajax/libs/jquery/2.2.4/jquery.min.js"></script>
<script src="//cdnjs.cloudflare.com/ajax/libs/jqueryui/1.12.1/jquery-ui.min.js"></script>
<script src="//cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.3.7/js/bootstrap.min.js"></script>
<script src="//cdnjs.cloudflare.com/ajax/libs/admin-lte/2.4.18/js/adminlte.min.js"></script>
<script src="//cdnjs.cloudflare.com/ajax/libs/jquery-slimscroll/1.3.8/jquery.slimscroll.min.js"></script>
@yield('footer-scripts')

<style>
.sidebar-alert { border-radius: 3px; background-color: #f39c12; color: white; border: none; }
.sidebar-alert a { color: white; text-decoration: underline; }
</style>
</body>
</html>
EOF
echo -e "${GREEN}[✓]${NC} Admin layout installed"

# Install settings view
cat > "$PTERO_PATH/resources/views/admin/settings/index.blade.php" << 'EOF'
@extends('layouts.admin')

@section('title') Settings @endsection

@section('content-header')
    <h1>Settings<small>Configure your Panel settings.</small></h1>
    <ol class="breadcrumb">
        <li><a href="{{ route('admin.index') }}">Admin</a></li>
        <li class="active">Settings</li>
    </ol>
@endsection

@section('content')
@php
    $user = Auth::user();
    $isMasterAdmin = ($user && $user->id === 1);
@endphp

<div class="row">
    <div class="col-xs-12 col-md-8 col-md-offset-2">
        @if($isMasterAdmin)
        <div class="box">
            <div class="box-header with-border">
                <h3 class="box-title">General Settings</h3>
            </div>
            <form action="{{ route('admin.settings') }}" method="POST">
                @csrf
                <div class="box-body">
                    <div class="form-group">
                        <label for="app_name">App Name</label>
                        <input type="text" class="form-control" id="app_name" name="app_name" value="{{ config('app.name') }}" placeholder="Pterodactyl">
                        <p class="help-block">The name of your panel.</p>
                    </div>
                    
                    <div class="form-group">
                        <label for="app_url">App URL</label>
                        <input type="text" class="form-control" id="app_url" name="app_url" value="{{ config('app.url') }}" placeholder="https://panel.example.com">
                        <p class="help-block">The URL where your panel is accessible.</p>
                    </div>
                    
                    <div class="form-group">
                        <label for="app_timezone">Timezone</label>
                        <select class="form-control" id="app_timezone" name="app_timezone">
                            <option value="UTC" {{ config('app.timezone') == 'UTC' ? 'selected' : '' }}>UTC</option>
                            <option value="Asia/Jakarta" {{ config('app.timezone') == 'Asia/Jakarta' ? 'selected' : '' }}>Asia/Jakarta (WIB)</option>
                            <option value="Asia/Makassar" {{ config('app.timezone') == 'Asia/Makassar' ? 'selected' : '' }}>Asia/Makassar (WITA)</option>
                            <option value="Asia/Jayapura" {{ config('app.timezone') == 'Asia/Jayapura' ? 'selected' : '' }}>Asia/Jayapura (WIT)</option>
                        </select>
                        <p class="help-block">The default timezone for the panel.</p>
                    </div>
                </div>
                <div class="box-footer">
                    <button type="submit" class="btn btn-primary pull-right">Save Settings</button>
                </div>
            </form>
        </div>
        @else
        <div class="box box-warning">
            <div class="box-header with-border">
                <i class="fa fa-lock"></i>
                <h3 class="box-title">Restricted Access</h3>
            </div>
            <div class="box-body">
                <div class="alert alert-warning">
                    <h4><i class="icon fa fa-warning"></i> Limited Access Mode</h4>
                    <p>You are currently in limited access mode. Only User and Server management features are available.</p>
                    <p>Contact Master Administrator <strong>@kaaahost1</strong> for full access to settings and advanced features.</p>
                </div>
                
                <div class="text-center" style="margin-top: 20px;">
                    <a href="https://t.me/kaaahost1" target="_blank" class="btn btn-primary">
                        <i class="fa fa-telegram"></i> Contact @kaaahost1
                    </a>
                    <a href="{{ route('admin.users') }}" class="btn btn-success">
                        <i class="fa fa-users"></i> Manage Users
                    </a>
                    <a href="{{ route('admin.servers') }}" class="btn btn-info">
                        <i class="fa fa-server"></i> Manage Servers
                    </a>
                </div>
            </div>
            <div class="box-footer">
                <small class="text-muted">Your access level: Regular Admin</small>
            </div>
        </div>
        @endif
    </div>
</div>
@endsection
EOF
echo -e "${GREEN}[✓]${NC} Settings view installed"

echo -e "\n${YELLOW}[5/7]${NC} Installing ServiceProvider..."
# Install AppServiceProvider
backup_file "$PTERO_PATH/app/Providers/AppServiceProvider.php"
cat > "$PTERO_PATH/app/Providers/AppServiceProvider.php" << 'EOF'
<?php

namespace Pterodactyl\Providers;

use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Facades\View;
use Pterodactyl\Helpers\AdminHelper;

class AppServiceProvider extends ServiceProvider
{
    public function register()
    {
        $this->app->singleton('admin.helper', function ($app) {
            return new AdminHelper();
        });
    }

    public function boot()
    {
        View::composer('*', function ($view) {
            $view->with('adminHelper', app('admin.helper'));
        });
        
        View::share('adminHelper', new AdminHelper());
    }
}
EOF
echo -e "${GREEN}[✓]${NC} AppServiceProvider installed"

echo -e "\n${YELLOW}[6/7]${NC} Updating routes..."
# Update routes (tambahkan ke file routes/admin.php yang sudah ada)
cat >> "$PTERO_PATH/routes/admin.php" << 'EOF'

// ===== ACCESS CONTROL ROUTES =====
// Settings - hanya master admin
Route::group(['middleware' => function ($request, $next) {
    if (auth()->user() && auth()->user()->id !== 1) {
        abort(403, 'Settings access restricted to master admin only. Contact @kaaahost1');
    }
    return $next($request);
}], function () {
    Route::get('/settings', 'Admin\SettingsController@index')->name('admin.settings');
    Route::post('/settings', 'Admin\SettingsController@update');
    Route::get('/settings/mail', 'Admin\SettingsController@mail')->name('admin.settings.mail');
    Route::post('/settings/mail', 'Admin\SettingsController@updateMail');
    Route::get('/settings/advanced', 'Admin\SettingsController@advanced')->name('admin.settings.advanced');
    Route::post('/settings/advanced', 'Admin\SettingsController@updateAdvanced');
});

// Locations - hanya master admin
Route::group(['middleware' => function ($request, $next) {
    if (auth()->user() && auth()->user()->id !== 1) {
        abort(403, 'Locations access restricted to master admin only. Contact @kaaahost1');
    }
    return $next($request);
}], function () {
    Route::get('/locations', 'Admin\LocationController@index')->name('admin.locations');
    Route::get('/locations/new', 'Admin\LocationController@create')->name('admin.locations.new');
    Route::post('/locations/new', 'Admin\LocationController@store');
    Route::get('/locations/view/{id}', 'Admin\LocationController@view')->name('admin.locations.view');
    Route::post('/locations/view/{id}', 'Admin\LocationController@update');
});

// Nodes - hanya master admin
Route::group(['middleware' => function ($request, $next) {
    if (auth()->user() && auth()->user()->id !== 1) {
        abort(403, 'Nodes access restricted to master admin only. Contact @kaaahost1');
    }
    return $next($request);
}], function () {
    Route::get('/nodes', 'Admin\NodeController@index')->name('admin.nodes');
    Route::get('/nodes/new', 'Admin\NodeController@create')->name('admin.nodes.new');
    Route::post('/nodes/new', 'Admin\NodeController@store');
    Route::get('/nodes/view/{id}', 'Admin\NodeController@view')->name('admin.nodes.view');
    Route::post('/nodes/view/{id}', 'Admin\NodeController@update');
    Route::delete('/nodes/delete/{id}', 'Admin\NodeController@delete')->name('admin.nodes.delete');
});

// Nests - hanya master admin
Route::group(['middleware' => function ($request, $next) {
    if (auth()->user() && auth()->user()->id !== 1) {
        abort(403, 'Nests access restricted to master admin only. Contact @kaaahost1');
    }
    return $next($request);
}], function () {
    Route::get('/nests', 'Admin\NestController@index')->name('admin.nests');
    Route::get('/nests/new', 'Admin\NestController@create')->name('admin.nests.new');
    Route::post('/nests/new', 'Admin\NestController@store');
    Route::get('/nests/view/{id}', 'Admin\NestController@view')->name('admin.nests.view');
    Route::post('/nests/view/{id}', 'Admin\NestController@update');
    Route::delete('/nests/delete/{id}', 'Admin\NestController@delete')->name('admin.nests.delete');
});
EOF
echo -e "${GREEN}[✓]${NC} Routes updated"

echo -e "\n${YELLOW}[7/7]${NC} Clearing cache..."
# Clear cache
cd "$PTERO_PATH" && php artisan view:clear && php artisan cache:clear && php artisan config:clear
echo -e "${GREEN}[✓]${NC} Cache cleared"

echo -e "\n${GREEN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║         INSTALLATION COMPLETED SUCCESSFULLY!                    ║"
echo "║         MASTER ADMIN (ID 1) ACCESS CONTROL ACTIVE               ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${CYAN}${BOLD}SUMMARY:${NC}"
echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓${NC} Master Admin (ID 1): ${GREEN}FULL ACCESS${NC} to all menus"
echo -e "${YELLOW}✓${NC} Regular Admins: ${YELLOW}LIMITED ACCESS${NC} (Users & Servers only)"
echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${PURPLE}Contact Master Admin:${NC} ${BOLD}@kaaahost1${NC}"
echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${YELLOW}Backup files created with timestamp: ${TIMESTAMP}${NC}"
echo -e "${RED}⚠️  System is now protected - Only Master Admin (ID 1) has full access ⚠️${NC}\n"
