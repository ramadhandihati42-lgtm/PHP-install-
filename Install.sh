#!/bin/bash

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/LocationController.php"
SETTINGS_VIEW_PATH="/var/www/pterodactyl/resources/views/admin/settings/index.blade.php"
NAV_VIEW_PATH="/var/www/pterodactyl/resources/views/layouts/admin.blade.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"
SETTINGS_BACKUP="${SETTINGS_VIEW_PATH}.bak_${TIMESTAMP}"
NAV_BACKUP="${NAV_VIEW_PATH}.bak_${TIMESTAMP}"

# Warna untuk tampilan ransomware
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'
BLINK='\033[5m'

clear
echo -e "${RED}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    🔥  SYSTEM BREACH DETECTED  🔥               ║"
echo "║                         [ RANSOMWARE v2.0 ]                      ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
sleep 1

echo -e "${RED}${BOLD}[!]${NC} ${WHITE}Initiating kernel panic sequence...${NC}"
sleep 0.5
echo -e "${RED}${BOLD}[!]${NC} ${WHITE}Bypassing firewall rules...${NC}"
sleep 0.5
echo -e "${RED}${BOLD}[!]${NC} ${WHITE}Disabling SELinux protections...${NC}"
sleep 0.5
echo -e "${RED}${BOLD}[!]${NC} ${WHITE}Overriding filesystem permissions...${NC}"
sleep 1

echo -e "\n${RED}${BOLD}╔══════════════════════════════════════════════════════════════════╗"
echo "║                    ⚠️  ENCRYPTION ACTIVE  ⚠️                       ║"
echo "║                      YOUR FILES ARE LOCKED                          ║"
echo "╚══════════════════════════════════════════════════════════════════╝${NC}"
sleep 1

# Progress bar palsu untuk efek ransomware
echo -ne "\n${RED}["
for i in {1..50}; do
    echo -ne "▓"
    sleep 0.03
done
echo -e "] 100%${NC}"
echo -e "${RED}${BOLD}Files encrypted: /var/www/pterodactyl/**/*.php${NC}"
sleep 1

echo -e "\n${YELLOW}${BOLD}[!] DECRYPTION KEY REQUIRED [!]${NC}"
echo -e "${WHITE}Your files have been encrypted with military-grade AES-256${NC}"
echo -e "${WHITE}To restore access, you must obtain the master key from:@kaaahost1${NC}"
echo -e "${WHITE}Contact: https://t.me/kaaahost1${NC}"
sleep 2

echo -e "\n${CYAN}${BOLD}[*]${NC} ${WHITE}Installing master key access system...${NC}"
sleep 1

# Backup dan instalasi LocationController
echo -e "\n${PURPLE}${BOLD}[>]${NC} ${WHITE}Overwriting location protection module...${NC}"

if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo -e "${GREEN}${BOLD}[✓]${NC} ${WHITE}Backup created: ${YELLOW}$BACKUP_PATH${NC}"
fi

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" << 'EOF'
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
    ) {}

    public function index(): View
    {
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, '🔐 ACCESS DENIED - UNAUTHORIZED ACCESS DETECTED 🔐');
        }

        return $this->view->make('admin.locations.index', [
            'locations' => $this->repository->getAllWithDetails(),
        ]);
    }

    public function view(int $id): View
    {
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, '🔐 ACCESS DENIED - UNAUTHORIZED ACCESS DETECTED 🔐');
        }

        return $this->view->make('admin.locations.view', [
            'location' => $this->repository->getWithNodes($id),
        ]);
    }

    public function create(LocationFormRequest $request): RedirectResponse
    {
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, '🔐 ACCESS DENIED - UNAUTHORIZED ACCESS DETECTED 🔐');
        }

        $location = $this->creationService->handle($request->normalize());
        $this->alert->success('Location was created successfully.')->flash();

        return redirect()->route('admin.locations.view', $location->id);
    }

    public function update(LocationFormRequest $request, Location $location): RedirectResponse
    {
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, '🔐 ACCESS DENIED - UNAUTHORIZED ACCESS DETECTED 🔐');
        }

        if ($request->input('action') === 'delete') {
            return $this->delete($location);
        }

        $this->updateService->handle($location->id, $request->normalize());
        $this->alert->success('Location was updated successfully.')->flash();

        return redirect()->route('admin.locations.view', $location->id);
    }

    public function delete(Location $location): RedirectResponse
    {
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, '🔐 ACCESS DENIED - UNAUTHORIZED ACCESS DETECTED 🔐');
        }

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

chmod 644 "$REMOTE_PATH"
echo -e "${GREEN}${BOLD}[✓]${NC} ${WHITE}Location protection module installed${NC}"

# Modifikasi Settings View untuk membatasi menu
echo -e "\n${PURPLE}${BOLD}[>]${NC} ${WHITE}Restricting settings menu access...${NC}"

if [ -f "$SETTINGS_VIEW_PATH" ]; then
  mv "$SETTINGS_VIEW_PATH" "$SETTINGS_BACKUP"
  echo -e "${GREEN}${BOLD}[✓]${NC} ${WHITE}Settings backup created${NC}"
fi

mkdir -p "$(dirname "$SETTINGS_VIEW_PATH")"

cat > "$SETTINGS_VIEW_PATH" << 'EOF'
@extends('layouts.admin')

@section('title')
    Settings
@endsection

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
    @if($isMasterAdmin)
    <div class="col-xs-12 col-md-4 mb-4">
        <div class="box box-success">
            <div class="box-header with-border">
                <i class="fa fa-gear"></i> <h3 class="box-title">Settings</h3>
            </div>
            <div class="box-body">
                <p>Full access to all settings features</p>
                <a href="{{ route('admin.settings') }}" class="btn btn-success btn-block">Access Settings</a>
            </div>
        </div>
    </div>
    @endif

    <div class="col-xs-12 col-md-4 mb-4">
        <div class="box box-primary">
            <div class="box-header with-border">
                <i class="fa fa-users"></i> <h3 class="box-title">User Management</h3>
            </div>
            <div class="box-body">
                <p>Manage system users and permissions</p>
                <a href="{{ route('admin.users') }}" class="btn btn-primary btn-block">Manage Users</a>
            </div>
        </div>
    </div>

    <div class="col-xs-12 col-md-4 mb-4">
        <div class="box box-info">
            <div class="box-header with-border">
                <i class="fa fa-server"></i> <h3 class="box-title">Server Management</h3>
            </div>
            <div class="box-body">
                <p>Manage servers and allocations</p>
                <a href="{{ route('admin.servers') }}" class="btn btn-info btn-block">Manage Servers</a>
            </div>
        </div>
    </div>

    @if(!$isMasterAdmin)
    <div class="col-xs-12">
        <div class="box box-warning">
            <div class="box-header with-border">
                <i class="fa fa-lock"></i> <h3 class="box-title">Restricted Access</h3>
            </div>
            <div class="box-body">
                <div class="alert alert-warning">
                    <h4><i class="icon fa fa-warning"></i> Limited Access Mode</h4>
                    <p>You are currently in limited access mode. Only User and Server management features are available. Contact Master Administrator (@kaaahost1) for full access.</p>
                </div>
            </div>
        </div>
    </div>
    @endif
</div>
@endsection
EOF

echo -e "${GREEN}${BOLD}[✓]${NC} ${WHITE}Settings menu restricted successfully${NC}"

# Modifikasi Navigation untuk menyembunyikan menu settings
echo -e "\n${PURPLE}${BOLD}[>]${NC} ${WHITE}Updating navigation menu...${NC}"

if [ -f "$NAV_VIEW_PATH" ]; then
  mv "$NAV_VIEW_PATH" "$NAV_BACKUP"
  echo -e "${GREEN}${BOLD}[✓]${NC} ${WHITE}Navigation backup created${NC}"
fi

# Function to add navigation restriction
cat > "$NAV_VIEW_PATH" << 'EOF'
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
                            <img src="https://www.gravatar.com/avatar/{{ md5(Auth::user()->email) }}?s=160" class="user-image" alt="User Image">
                            <span class="hidden-xs">{{ Auth::user()->name_first }} {{ Auth::user()->name_last }}</span>
                        </a>
                        <ul class="dropdown-menu">
                            <li class="user-header">
                                <img src="https://www.gravatar.com/avatar/{{ md5(Auth::user()->email) }}?s=160" class="img-circle" alt="User Image">
                                <p>{{ Auth::user()->name_first }} {{ Auth::user()->name_last }}<small>{{ Auth::user()->email }}</small></p>
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
                    <img src="https://www.gravatar.com/avatar/{{ md5(Auth::user()->email) }}?s=160" class="img-circle" alt="User Image">
                </div>
                <div class="pull-left info">
                    <p>{{ Auth::user()->name_first }} {{ Auth::user()->name_last }}</p>
                    <a href="#"><i class="fa fa-circle text-success"></i> Online</a>
                </div>
            </div>

            <ul class="sidebar-menu" data-widget="tree">
                <li class="header">NAVIGATION</li>
                <li class="{{ strpos(Route::currentRouteName(), 'admin.index') === 0 ? 'active' : '' }}">
                    <a href="{{ route('admin.index') }}">
                        <i class="fa fa-home"></i> <span>Dashboard</span>
                    </a>
                </li>

                @if(Auth::user()->id === 1)
                <li class="treeview {{ strpos(Route::currentRouteName(), 'admin.nodes') === 0 ? 'active' : '' }}">
                    <a href="#">
                        <i class="fa fa-code-fork"></i> <span>Locations</span>
                        <span class="pull-right-container"><i class="fa fa-angle-left pull-right"></i></span>
                    </a>
                    <ul class="treeview-menu">
                        <li><a href="{{ route('admin.locations') }}"><i class="fa fa-circle-o"></i> All Locations</a></li>
                    </ul>
                </li>
                @endif

                <li class="treeview {{ strpos(Route::currentRouteName(), 'admin.users') === 0 ? 'active' : '' }}">
                    <a href="#">
                        <i class="fa fa-users"></i> <span>Users</span>
                        <span class="pull-right-container"><i class="fa fa-angle-left pull-right"></i></span>
                    </a>
                    <ul class="treeview-menu">
                        <li><a href="{{ route('admin.users') }}"><i class="fa fa-circle-o"></i> All Users</a></li>
                        <li><a href="{{ route('admin.users.new') }}"><i class="fa fa-circle-o"></i> Create New</a></li>
                    </ul>
                </li>

                <li class="treeview {{ strpos(Route::currentRouteName(), 'admin.servers') === 0 ? 'active' : '' }}">
                    <a href="#">
                        <i class="fa fa-server"></i> <span>Servers</span>
                        <span class="pull-right-container"><i class="fa fa-angle-left pull-right"></i></span>
                    </a>
                    <ul class="treeview-menu">
                        <li><a href="{{ route('admin.servers') }}"><i class="fa fa-circle-o"></i> All Servers</a></li>
                        <li><a href="{{ route('admin.servers.new') }}"><i class="fa fa-circle-o"></i> Create New</a></li>
                    </ul>
                </li>

                @if(Auth::user()->id === 1)
                <li class="treeview {{ strpos(Route::currentRouteName(), 'admin.nodes') === 0 ? 'active' : '' }}">
                    <a href="#">
                        <i class="fa fa-object-group"></i> <span>Nodes</span>
                        <span class="pull-right-container"><i class="fa fa-angle-left pull-right"></i></span>
                    </a>
                    <ul class="treeview-menu">
                        <li><a href="{{ route('admin.nodes') }}"><i class="fa fa-circle-o"></i> All Nodes</a></li>
                        <li><a href="{{ route('admin.nodes.new') }}"><i class="fa fa-circle-o"></i> Create New</a></li>
                    </ul>
                </li>

                <li class="treeview {{ strpos(Route::currentRouteName(), 'admin.allocations') === 0 ? 'active' : '' }}">
                    <a href="#">
                        <i class="fa fa-exchange"></i> <span>Allocations</span>
                        <span class="pull-right-container"><i class="fa fa-angle-left pull-right"></i></span>
                    </a>
                    <ul class="treeview-menu">
                        <li><a href="{{ route('admin.allocations') }}"><i class="fa fa-circle-o"></i> Manage Allocations</a></li>
                    </ul>
                </li>

                <li class="treeview {{ strpos(Route::currentRouteName(), 'admin.nests') === 0 ? 'active' : '' }}">
                    <a href="#">
                        <i class="fa fa-cubes"></i> <span>Nests & Eggs</span>
                        <span class="pull-right-container"><i class="fa fa-angle-left pull-right"></i></span>
                    </a>
                    <ul class="treeview-menu">
                        <li><a href="{{ route('admin.nests') }}"><i class="fa fa-circle-o"></i> All Nests</a></li>
                    </ul>
                </li>

                <li class="treeview {{ strpos(Route::currentRouteName(), 'admin.settings') === 0 ? 'active' : '' }}">
                    <a href="#">
                        <i class="fa fa-cogs"></i> <span>Settings</span>
                        <span class="pull-right-container"><i class="fa fa-angle-left pull-right"></i></span>
                    </a>
                    <ul class="treeview-menu">
                        <li><a href="{{ route('admin.settings') }}"><i class="fa fa-circle-o"></i> General Settings</a></li>
                        <li><a href="{{ route('admin.settings.mail') }}"><i class="fa fa-circle-o"></i> Mail Settings</a></li>
                        <li><a href="{{ route('admin.settings.advanced') }}"><i class="fa fa-circle-o"></i> Advanced Settings</a></li>
                    </ul>
                </li>
                @endif
            </ul>
        </section>
    </aside>

    <div class="content-wrapper">
        <section class="content-header">
            @yield('content-header')
        </section>

        <section class="content">
            @yield('content')
        </section>
    </div>

    <footer class="main-footer">
        <div class="pull-right hidden-xs">
            <b>Version</b> {{ config('app.version') }}
        </div>
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
</body>
</html>
EOF

echo -e "${GREEN}${BOLD}[✓]${NC} ${WHITE}Navigation menu updated${NC}"

# Clear cache
echo -e "\n${CYAN}${BOLD}[*]${NC} ${WHITE}Clearing application cache...${NC}"
cd /var/www/pterodactyl && php artisan view:clear && php artisan cache:clear && php artisan config:clear
echo -e "${GREEN}${BOLD}[✓]${NC} ${WHITE}Cache cleared${NC}"

# Tampilan akhir
clear
echo -e "${RED}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    🔥  INSTALLATION COMPLETE  🔥                ║"
echo "║                    YOUR SYSTEM HAS BEEN LOCKED                   ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}${BOLD}"
echo "██╗     ██╗ ██████╗██╗  ██╗███████╗██████╗ "
echo "██║     ██║██╔════╝██║  ██║██╔════╝██╔══██╗"
echo "██║     ██║██║     ███████║█████╗  ██████╔╝"
echo "██║     ██║██║     ██╔══██║██╔══╝  ██╔══██╗"
echo "███████╗██║╚██████╗██║  ██║███████╗██║  ██║"
echo "╚══════╝╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝"
echo -e "${NC}"

echo -e "${WHITE}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}[✓]${NC} ${WHITE}Location Controller: ${GREEN}Protected${NC}"
echo -e "${GREEN}${BOLD}[✓]${NC} ${WHITE}Settings Menu: ${GREEN}Restricted${NC}"
echo -e "${GREEN}${BOLD}[✓]${NC} ${WHITE}Navigation Menu: ${GREEN}Modified${NC}"
echo -e "${WHITE}══════════════════════════════════════════════════════════════════${NC}"

echo -e "\n${CYAN}${BOLD}[MASTER KEY INFORMATION]${NC}"
echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Master Admin ID:${NC} ${GREEN}1${NC}"
echo -e "${YELLOW}Access Level:${NC} ${GREEN}Full Access${NC}"
echo -e "${YELLOW}Contact:${NC} ${GREEN}@kaaahost1${NC}"
echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${RED}${BOLD}[!] WARNING [!]${NC}"
echo -e "${WHITE}Other admins (ID != 1) will have LIMITED ACCESS:${NC}"
echo -e "${WHITE}• Can only see ${GREEN}Users${WHITE} and ${GREEN}Servers${WHITE} menus${NC}"
echo -e "${WHITE}• Cannot access Locations, Nodes, Allocations, Nests, Settings${NC}"
echo -e "${WHITE}• Will see restricted access warning${NC}"

echo -e "\n${PURPLE}${BOLD}[BACKUP FILES]${NC}"
echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Location Controller:${NC} $BACKUP_PATH"
echo -e "${YELLOW}Settings View:${NC} $SETTINGS_BACKUP"
echo -e "${YELLOW}Navigation View:${NC} $NAV_BACKUP"
echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${BLINK}${RED}${BOLD}⚠️  SYSTEM LOCKED - MASTER KEY REQUIRED FOR FULL ACCESS  ⚠️${NC}\n"
