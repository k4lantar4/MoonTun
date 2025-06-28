#!/bin/bash

# 🚀 MVTunnel - Intelligent Dual-Core Tunnel System v1.0
# Created by K4lantar4 for Iran-Foreign Server Tunneling
# Combines EasyTier + Rathole with Smart Failover & Protocol Switching
# Enterprise-Grade Solution for 1000+ Concurrent Users

set -e

# Version
MVTUNNEL_VERSION="1.0"

# Colors for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# System Paths
CONFIG_DIR="/etc/mvtunnel"
LOG_DIR="/var/log/mvtunnel"
DEST_DIR="/usr/local/bin"
SERVICE_NAME="mvtunnel"

# Configuration Files
MAIN_CONFIG="$CONFIG_DIR/mvtunnel.conf"
EASYTIER_CONFIG="$CONFIG_DIR/easytier.json"
RATHOLE_CONFIG="$CONFIG_DIR/rathole.toml"
MONITOR_CONFIG="$CONFIG_DIR/monitor.conf"
STATUS_FILE="$CONFIG_DIR/tunnel_status"

# =============================================================================
# Utility Functions
# =============================================================================

log() {
    local color="$1"
    local text="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $color in
        red) echo -e "${RED}❌ [$timestamp] $text${NC}" ;;
        green) echo -e "${GREEN}✅ [$timestamp] $text${NC}" ;;
        yellow) echo -e "${YELLOW}⚠️  [$timestamp] $text${NC}" ;;
        cyan) echo -e "${CYAN}🔧 [$timestamp] $text${NC}" ;;
        blue) echo -e "${BLUE}ℹ️  [$timestamp] $text${NC}" ;;
        purple) echo -e "${PURPLE}🎯 [$timestamp] $text${NC}" ;;
        white) echo -e "${WHITE}$text${NC}" ;;
        *) echo -e "[$timestamp] $text" ;;
    esac
    
    # Also log to file
    echo "[$timestamp] $text" >> "$LOG_DIR/mvtunnel.log" 2>/dev/null || true
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log red "Root access required. Usage: sudo mv <command>"
        exit 1
    fi
}

press_key() {
    echo
    read -p "Press Enter to continue..."
}

generate_secret() {
    openssl rand -hex 8 2>/dev/null || echo "$(date +%s)$(shuf -i 1000-9999 -n 1)"
}

get_public_ip() {
    curl -s --max-time 5 ipinfo.io/ip 2>/dev/null || \
    curl -s --max-time 5 icanhazip.com 2>/dev/null || \
    curl -s --max-time 5 ifconfig.me 2>/dev/null || \
    echo "Unknown"
}

get_system_ip() {
    ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[0-9.]+' | head -1 || echo "127.0.0.1"
}

# =============================================================================
# Installation Functions
# =============================================================================

install_dependencies() {
    log cyan "Installing system dependencies..."
    
    # Update package lists
    if command -v apt-get >/dev/null; then
        apt-get update -qq
        apt-get install -y curl wget unzip jq netcat-openbsd bc >/dev/null 2>&1
    elif command -v yum >/dev/null; then
        yum install -y curl wget unzip jq nc bc >/dev/null 2>&1
    elif command -v dnf >/dev/null; then
        dnf install -y curl wget unzip jq nc bc >/dev/null 2>&1
    else
        log red "Unsupported package manager"
        exit 1
    fi
    
    log green "Dependencies installed successfully"
}

install_easytier() {
    log cyan "Installing EasyTier core..."
    
    # Detect architecture
    local arch=$(uname -m)
    case $arch in
        x86_64) arch_suffix="x86_64" ;;
        armv7l) arch_suffix="armv7" ;;
        aarch64) arch_suffix="aarch64" ;;
        *) log red "Unsupported architecture: $arch"; exit 1 ;;
    esac
    
    # Get latest version
    local latest_version=$(curl -s https://api.github.com/repos/EasyTier/EasyTier/releases/latest | jq -r '.tag_name' 2>/dev/null)
    if [[ -z "$latest_version" ]] || [[ "$latest_version" == "null" ]]; then
        log yellow "Using fallback EasyTier version"
        latest_version="v1.2.3"
    fi
    
    # Download and install
    local download_url="https://github.com/EasyTier/EasyTier/releases/latest/download/easytier-linux-${arch_suffix}-${latest_version}.zip"
    local temp_dir=$(mktemp -d)
    
    cd "$temp_dir"
    if curl -fsSL "$download_url" -o easytier.zip; then
        unzip -q easytier.zip 2>/dev/null
        find . -name "easytier-core" -executable -exec cp {} "$DEST_DIR/" \; 2>/dev/null
        find . -name "easytier-cli" -executable -exec cp {} "$DEST_DIR/" \; 2>/dev/null
        chmod +x "$DEST_DIR/easytier-core" "$DEST_DIR/easytier-cli" 2>/dev/null
        log green "EasyTier $latest_version installed"
    else
        log red "Failed to download EasyTier"
        exit 1
    fi
    
    cd / && rm -rf "$temp_dir"
}

install_rathole() {
    log cyan "Installing Rathole core..."
    
    # Detect architecture
    local arch=$(uname -m)
    case $arch in
        x86_64) arch_suffix="x86_64-unknown-linux-gnu" ;;
        aarch64) arch_suffix="aarch64-unknown-linux-musl" ;;
        *) 
            log yellow "Rathole not available for architecture: $arch"
            log yellow "Continuing with EasyTier only..."
            return 0
            ;;
    esac
    
    # Get latest version
    local latest_version=$(curl -s https://api.github.com/repos/rathole-org/rathole/releases/latest | jq -r '.tag_name' 2>/dev/null)
    if [[ -z "$latest_version" ]] || [[ "$latest_version" == "null" ]]; then
        log yellow "Using fallback Rathole version"
        latest_version="v0.5.0"
    fi
    
    # Download and install
    local download_url="https://github.com/rathole-org/rathole/releases/download/${latest_version}/rathole-${arch_suffix}.zip"
    local temp_dir=$(mktemp -d)
    
    cd "$temp_dir"
    if curl -fsSL "$download_url" -o rathole.zip; then
        unzip -q rathole.zip 2>/dev/null
        find . -name "rathole" -executable -exec cp {} "$DEST_DIR/" \; 2>/dev/null
        chmod +x "$DEST_DIR/rathole" 2>/dev/null
        log green "Rathole $latest_version installed"
    else
        log yellow "Rathole installation failed, continuing without it..."
    fi
    
    cd / && rm -rf "$temp_dir"
}

setup_directories() {
    log cyan "Setting up MVTunnel directories..."
    
    # Create directories
    mkdir -p "$CONFIG_DIR" "$LOG_DIR"
    chmod 755 "$CONFIG_DIR" "$LOG_DIR"
    
    # Create default configs
    create_default_configs
    
    log green "Directory structure created"
}

create_default_configs() {
    # Main configuration
    cat > "$MAIN_CONFIG" << 'EOF'
# MVTunnel Main Configuration
TUNNEL_MODE="easytier"
LOCAL_IP="10.10.10.1"
REMOTE_IP="10.10.10.2"
NETWORK_SECRET=""
PROTOCOL="udp"
PORT="1377"
FAILOVER_ENABLED="true"
MONITOR_INTERVAL="5"
AUTO_SWITCH="true"
REMOTE_SERVER=""
EOF

    # Monitor configuration
    cat > "$MONITOR_CONFIG" << 'EOF'
# Network Monitoring Configuration
PING_TIMEOUT="3"
PING_THRESHOLD="200"
PACKET_LOSS_THRESHOLD="5"
LATENCY_CHECK_INTERVAL="10"
PROTOCOL_SWITCH_THRESHOLD="3"
RECOVERY_CHECK_INTERVAL="30"
EOF
}

install_mvtunnel() {
    local auto_mode="$1"
    
    clear
    echo -e "${CYAN}🚀 MVTunnel Intelligent Tunnel System v${MVTUNNEL_VERSION}${NC}"
    echo "================================================================="
    echo
    
    if [[ "$auto_mode" != "auto" ]]; then
        log yellow "This will install MVTunnel with dual-core tunnel system"
        echo "Components:"
        echo "  • EasyTier Core (Latest version)"
        echo "  • Rathole Core (Latest version)"  
        echo "  • Intelligent Failover System"
        echo "  • Network Monitoring & Auto-switching"
        echo "  • HAProxy Integration"
        echo "  • Performance Optimization"
        echo
        read -p "Continue with installation? [Y/n]: " confirm_install
        if [[ "$confirm_install" =~ ^[Nn]$ ]]; then
            log cyan "Installation cancelled by user"
            exit 0
        fi
    fi
    
    # Installation steps
    check_root
    setup_directories
    install_dependencies
    install_easytier
    install_rathole
    
    # Install MVTunnel manager
    log cyan "Installing MVTunnel manager..."
    cp "$0" "$DEST_DIR/mv"
    chmod +x "$DEST_DIR/mv"
    
    # Create systemd service
    create_systemd_service
    
    # Setup log rotation
    setup_log_rotation
    
    log green "🎉 MVTunnel installed successfully!"
    echo
    log cyan "Quick Start:"
    echo "  sudo mv setup     # Initial setup"
    echo "  sudo mv connect   # Quick connect"
    echo "  sudo mv status    # Check status"
    echo "  sudo mv monitor   # Live monitoring"
    echo
}

create_systemd_service() {
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=MVTunnel Intelligent Tunnel Service
After=network.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$DEST_DIR/mv daemon-mode
ExecStop=/bin/kill -TERM \$MAINPID
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10
User=root
WorkingDirectory=$CONFIG_DIR
PIDFile=$CONFIG_DIR/mvtunnel.pid
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}.service
}

setup_log_rotation() {
    log cyan "Setting up log rotation..."
    
    # Create logrotate configuration
    cat > /etc/logrotate.d/mvtunnel << 'EOF'
/var/log/mvtunnel/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        systemctl reload mvtunnel 2>/dev/null || true
    endscript
}
EOF
    
    # Create log cleanup script
    cat > /usr/local/bin/mvtunnel-log-cleanup << 'EOF'
#!/bin/bash
# MVTunnel Log Cleanup Script
find /var/log/mvtunnel -name "*.log" -size +100M -exec truncate -s 50M {} \;
find /var/log/mvtunnel -name "*.log.*" -mtime +30 -delete
EOF
    
    chmod +x /usr/local/bin/mvtunnel-log-cleanup
    
    # Add to crontab for emergency cleanup
    (crontab -l 2>/dev/null | grep -v mvtunnel-log-cleanup; echo "0 2 * * * /usr/local/bin/mvtunnel-log-cleanup") | crontab -
    
    log green "Log rotation configured"
}

# =============================================================================
# Configuration Functions
# =============================================================================

setup_tunnel() {
    clear
    log purple "🎯 MVTunnel Intelligent Setup v2.0"
    echo
    
    # Check for existing configuration
    if [[ -f "$MAIN_CONFIG" ]]; then
        log yellow "Existing configuration found"
        read -p "Reconfigure? [y/N]: " reconfigure
        if [[ ! "$reconfigure" =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    log cyan "🔍 Gathering system information..."
    local public_ip=$(get_public_ip)
    local system_ip=$(get_system_ip)
    
    echo "📡 Public IP: $public_ip"
    echo "🏠 System IP: $system_ip"
    echo
    
    # Tunnel mode selection
    log blue "🚇 Select tunnel mode:"
    echo "1) EasyTier (Recommended for stability)"
    echo "2) Rathole (High performance)"
    echo "3) Hybrid (Intelligent switching)"
    echo
    read -p "Select mode [1-3]: " mode_choice
    
    case ${mode_choice:-1} in
        1) TUNNEL_MODE="easytier" ;;
        2) TUNNEL_MODE="rathole" ;;
        3) TUNNEL_MODE="hybrid" ;;
        *) TUNNEL_MODE="easytier" ;;
    esac
    
    # Node type selection based on tunnel mode
    echo
    if [[ "$TUNNEL_MODE" == "easytier" ]] || [[ "$TUNNEL_MODE" == "hybrid" ]]; then
        log blue "🏗️  EasyTier Node Type:"
        echo "1) Master Node (Server with 0.0.0.0 - No peers needed)"
        echo "2) Client Node (Connect to master/peers)"
        echo
        read -p "Select node type [1-2]: " easytier_node_choice
        
        case ${easytier_node_choice:-1} in
            1) EASYTIER_NODE_TYPE="master" ;;
            2) EASYTIER_NODE_TYPE="client" ;;
            *) EASYTIER_NODE_TYPE="master" ;;
        esac
    fi
    
    if [[ "$TUNNEL_MODE" == "rathole" ]] || [[ "$TUNNEL_MODE" == "hybrid" ]]; then
        log blue "🔧 Rathole Node Type:"
        echo "1) Server (Foreign server - receives connections)"
        echo "2) Client (Iran server - connects to foreign)"
        echo
        read -p "Select node type [1-2]: " rathole_node_choice
        
        case ${rathole_node_choice:-1} in
            1) RATHOLE_NODE_TYPE="server" ;;
            2) RATHOLE_NODE_TYPE="client" ;;
            *) RATHOLE_NODE_TYPE="client" ;;
        esac
    fi
    
    # Network configuration based on node types
    echo
    log blue "🌐 Network Configuration:"
    
    # Local IP configuration
    if [[ "$TUNNEL_MODE" == "easytier" ]] && [[ "$EASYTIER_NODE_TYPE" == "master" ]]; then
        read -p "Local tunnel IP [10.10.10.1]: " input_local_ip
        LOCAL_IP=${input_local_ip:-10.10.10.1}
        REMOTE_SERVER=""
        REMOTE_IP=""
        log cyan "💡 Master mode: No remote configuration needed"
    else
        read -p "Local tunnel IP [10.10.10.2]: " input_local_ip
        LOCAL_IP=${input_local_ip:-10.10.10.2}
        
        read -p "Remote server IP or domain: " REMOTE_SERVER
        if [[ -z "$REMOTE_SERVER" ]]; then
            log red "Remote server is required for client mode"
            return 1
        fi
        
        read -p "Remote tunnel IP [10.10.10.1]: " input_remote_ip
        REMOTE_IP=${input_remote_ip:-10.10.10.1}
    fi
    
    read -p "Tunnel port [1377]: " input_port
    PORT=${input_port:-1377}
    
    # Protocol selection with enhanced options
    echo
    log blue "🔗 Select primary protocol:"
    echo "1) UDP (Best for stability & speed)"
    echo "2) TCP (Better penetration & reliability)"
    echo "3) WebSocket (Maximum compatibility)"
    echo "4) QUIC (Modern, fast, experimental)"
    echo "5) WireGuard (High security)"
    read -p "Protocol [1]: " protocol_choice
    
    case ${protocol_choice:-1} in
        1) PROTOCOL="udp" ;;
        2) PROTOCOL="tcp" ;;
        3) PROTOCOL="ws" ;;
        4) PROTOCOL="quic" ;;
        5) PROTOCOL="wg" ;;
        *) PROTOCOL="udp" ;;
    esac
    
    # Generate network secret
    NETWORK_SECRET=$(generate_secret)
    log cyan "🔐 Generated network secret: $NETWORK_SECRET"
    read -p "Custom secret (or Enter to use generated): " custom_secret
    NETWORK_SECRET=${custom_secret:-$NETWORK_SECRET}
    
    # Advanced options
    echo
    log blue "⚙️  Advanced Options:"
    read -p "Enable automatic failover? [Y/n]: " enable_failover
    FAILOVER_ENABLED=$([[ ! "$enable_failover" =~ ^[Nn]$ ]] && echo "true" || echo "false")
    
    read -p "Enable auto protocol switching? [Y/n]: " enable_switching
    AUTO_SWITCH=$([[ ! "$enable_switching" =~ ^[Nn]$ ]] && echo "true" || echo "false")
    
    # Performance tuning options
    echo
    log blue "🚀 Performance Options:"
    read -p "Enable multi-threading? [Y/n]: " enable_multi_thread
    MULTI_THREAD=$([[ ! "$enable_multi_thread" =~ ^[Nn]$ ]] && echo "true" || echo "false")
    
    read -p "Enable compression? [Y/n]: " enable_compression
    COMPRESSION=$([[ ! "$enable_compression" =~ ^[Nn]$ ]] && echo "true" || echo "false")
    
    read -p "Enable encryption? [Y/n]: " enable_encryption
    ENCRYPTION=$([[ ! "$enable_encryption" =~ ^[Nn]$ ]] && echo "true" || echo "false")
    
    # Save configuration
    save_configuration
    
    log green "✅ Configuration saved successfully!"
    echo
    log cyan "Ready to connect! Use: sudo mv connect"
}

save_configuration() {
    # Create backup directory
    local backup_dir="$CONFIG_DIR/backups"
    mkdir -p "$backup_dir"
    
    # Backup existing configuration
    if [[ -f "$MAIN_CONFIG" ]]; then
        local backup_file="$backup_dir/mvtunnel.conf.$(date +%Y%m%d_%H%M%S)"
        cp "$MAIN_CONFIG" "$backup_file"
        log cyan "Configuration backed up to: $backup_file"
        
        # Keep only last 10 backups
        ls -t "$backup_dir"/mvtunnel.conf.* 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
    fi
    
    # Save new configuration
    cat > "$MAIN_CONFIG" << EOF
# MVTunnel Configuration v2.0 - Generated $(date)
TUNNEL_MODE="$TUNNEL_MODE"
LOCAL_IP="$LOCAL_IP"
REMOTE_IP="$REMOTE_IP"
REMOTE_SERVER="$REMOTE_SERVER"
NETWORK_SECRET="$NETWORK_SECRET"
PROTOCOL="$PROTOCOL"
PORT="$PORT"
FAILOVER_ENABLED="$FAILOVER_ENABLED"
MONITOR_INTERVAL="5"
AUTO_SWITCH="$AUTO_SWITCH"
PUBLIC_IP="$(get_public_ip)"
LAST_UPDATE="$(date)"

# Node Types
EASYTIER_NODE_TYPE="${EASYTIER_NODE_TYPE:-client}"
RATHOLE_NODE_TYPE="${RATHOLE_NODE_TYPE:-client}"

# Performance Options
MULTI_THREAD="${MULTI_THREAD:-true}"
COMPRESSION="${COMPRESSION:-true}"
ENCRYPTION="${ENCRYPTION:-true}"
EOF

    # Validate configuration
    if validate_configuration; then
        log green "Configuration saved and validated successfully"
    else
        log red "Configuration validation failed"
        restore_last_backup
        return 1
    fi
}

validate_configuration() {
    # Basic validation
    [[ -n "$TUNNEL_MODE" ]] || { log red "TUNNEL_MODE is empty"; return 1; }
    [[ -n "$LOCAL_IP" ]] || { log red "LOCAL_IP is empty"; return 1; }
    [[ -n "$REMOTE_IP" ]] || { log red "REMOTE_IP is empty"; return 1; }
    [[ -n "$REMOTE_SERVER" ]] || { log red "REMOTE_SERVER is empty"; return 1; }
    [[ -n "$NETWORK_SECRET" ]] || { log red "NETWORK_SECRET is empty"; return 1; }
    [[ -n "$PROTOCOL" ]] || { log red "PROTOCOL is empty"; return 1; }
    [[ -n "$PORT" ]] || { log red "PORT is empty"; return 1; }
    
    # Validate IP addresses
    if ! [[ "$LOCAL_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        log red "Invalid LOCAL_IP format"; return 1
    fi
    
    if ! [[ "$REMOTE_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        log red "Invalid REMOTE_IP format"; return 1
    fi
    
    # Validate port
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [[ "$PORT" -lt 1 ]] || [[ "$PORT" -gt 65535 ]]; then
        log red "Invalid PORT number"; return 1
    fi
    
    return 0
}

restore_last_backup() {
    local backup_dir="$CONFIG_DIR/backups"
    local last_backup=$(ls -t "$backup_dir"/mvtunnel.conf.* 2>/dev/null | head -1)
    
    if [[ -n "$last_backup" ]]; then
        cp "$last_backup" "$MAIN_CONFIG"
        log yellow "Configuration restored from backup: $last_backup"
    else
        log red "No backup found to restore"
    fi
}

backup_configuration() {
    log cyan "Creating manual configuration backup..."
    
    if [[ ! -f "$MAIN_CONFIG" ]]; then
        log red "No configuration file found to backup"
        return 1
    fi
    
    local backup_dir="$CONFIG_DIR/backups"
    mkdir -p "$backup_dir"
    
    local backup_file="$backup_dir/mvtunnel.conf.manual.$(date +%Y%m%d_%H%M%S)"
    cp "$MAIN_CONFIG" "$backup_file"
    
    log green "Configuration backed up to: $backup_file"
    
    # List all backups
    echo
    log cyan "Available backups:"
    ls -la "$backup_dir"/mvtunnel.conf.* 2>/dev/null | awk '{print "  " $9 " (" $5 " bytes, " $6 " " $7 " " $8 ")"}'
}

restore_configuration() {
    log cyan "Configuration Restore Menu"
    echo
    
    local backup_dir="$CONFIG_DIR/backups"
    
    if [[ ! -d "$backup_dir" ]]; then
        log red "No backup directory found"
        return 1
    fi
    
    local backups=($(ls -t "$backup_dir"/mvtunnel.conf.* 2>/dev/null))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        log red "No backups found"
        return 1
    fi
    
    echo "Available backups:"
    for i in "${!backups[@]}"; do
        local backup_file="${backups[$i]}"
        local backup_date=$(stat -c %y "$backup_file" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)
        echo "  $((i+1))) $(basename "$backup_file") ($backup_date)"
    done
    echo
    
    read -p "Select backup to restore [1-${#backups[@]}]: " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#backups[@]} ]]; then
        local selected_backup="${backups[$((choice-1))]}"
        
        # Backup current config before restore
        if [[ -f "$MAIN_CONFIG" ]]; then
            cp "$MAIN_CONFIG" "$backup_dir/mvtunnel.conf.pre-restore.$(date +%Y%m%d_%H%M%S)"
        fi
        
        # Restore selected backup
        cp "$selected_backup" "$MAIN_CONFIG"
        
        log green "Configuration restored from: $(basename "$selected_backup")"
        log yellow "Previous configuration backed up with 'pre-restore' prefix"
        
        # Validate restored config
        if validate_configuration; then
            log green "Restored configuration is valid"
        else
            log red "Warning: Restored configuration has validation errors"
        fi
    else
        log red "Invalid selection"
    fi
}

# =============================================================================
# Tunnel Core Management Functions
# =============================================================================

manage_tunnel_cores() {
    clear
    log purple "🔧 Tunnel Cores Management"
    echo "==============================="
    echo
    
    show_cores_status
    echo
    
    log cyan "📦 Core Management Options:"
    echo "1) Install EasyTier Core"
    echo "2) Install Rathole Core"
    echo "3) Install Both Cores"
    echo "4) Update Existing Cores"
    echo "5) Remove Cores"
    echo "6) Check Core Status"
    echo "7) Install from MVTunnel Repository"
    echo "8) Install from Local Files"
    echo "0) Back to Main Menu"
    echo
    
    read -p "Select option [1-8]: " core_choice
    
    case $core_choice in
        1) install_core_menu "easytier" ;;
        2) install_core_menu "rathole" ;;
        3) install_both_cores_menu ;;
        4) update_cores_menu ;;
        5) remove_cores_menu ;;
        6) show_detailed_cores_status ;;
        7) install_from_mvtunnel_repo ;;
        8) install_from_local_files ;;
        0) return ;;
        *) log red "Invalid option"; sleep 1; manage_tunnel_cores ;;
    esac
}

show_cores_status() {
    log cyan "🔍 Current Core Status:"
    
    # EasyTier status
    if [[ -f "$DEST_DIR/easytier-core" ]]; then
        local easytier_version=$("$DEST_DIR/easytier-core" --version 2>/dev/null | head -1 || echo "Unknown")
        local easytier_size=$(ls -lh "$DEST_DIR/easytier-core" | awk '{print $5}')
        local easytier_date=$(stat -c %y "$DEST_DIR/easytier-core" | cut -d' ' -f1)
        
        echo "  Status: ✅ Installed"
        echo "  Version: $easytier_version"
        echo "  Size: $easytier_size"
        echo "  Install Date: $easytier_date"
        echo "  Path: $DEST_DIR/easytier-core"
        
        if [[ -f "$DEST_DIR/easytier-cli" ]]; then
            echo "  CLI: ✅ Available"
        else
            echo "  CLI: ❌ Missing"
        fi
    else
        echo "  Status: ❌ Not installed"
    fi
    echo
    
    # Rathole status
    if [[ -f "$DEST_DIR/rathole" ]]; then
        local rathole_version=$("$DEST_DIR/rathole" --version 2>/dev/null | head -1 || echo "Unknown")
        local rathole_size=$(ls -lh "$DEST_DIR/rathole" | awk '{print $5}')
        local rathole_date=$(stat -c %y "$DEST_DIR/rathole" | cut -d' ' -f1)
        
        echo "  Status: ✅ Installed"
        echo "  Version: $rathole_version"
        echo "  Size: $rathole_size"
        echo "  Install Date: $rathole_date"
        echo "  Path: $DEST_DIR/rathole"
    else
        echo "  Status: ❌ Not installed"
    fi
    echo
    
    # System compatibility
    log cyan "🖥️  System Compatibility:"
    local arch=$(uname -m)
    echo "  Architecture: $arch"
    echo "  OS: $(lsb_release -d 2>/dev/null | cut -d: -f2 | xargs || uname -o)"
    echo "  Kernel: $(uname -r)"
    
    # Check requirements
    echo
    log cyan "📋 Requirements Check:"
    
    # Check for required commands
    local requirements=("curl" "wget" "unzip" "jq" "nc" "ping" "ss" "ip")
    for req in "${requirements[@]}"; do
        if command -v "$req" >/dev/null; then
            echo "  $req: ✅ Available"
        else
            echo "  $req: ❌ Missing"
        fi
    done
    
    press_key
}

install_core_menu() {
    local core_name="$1"
    
    clear
    log purple "📦 Install $core_name Core"
    echo
    
    log cyan "Installation Methods:"
    echo "1) Online (Download from GitHub releases)"
    echo "2) Offline (Install from local files)"
    echo "3) Compile from source"
    echo "0) Back"
    echo
    
    read -p "Select method [1-3]: " install_method
    
    case $install_method in
        1) install_core_online "$core_name" ;;
        2) install_core_offline "$core_name" ;;
        3) compile_core_from_source "$core_name" ;;
        0) return ;;
        *) log red "Invalid option"; sleep 1; install_core_menu "$core_name" ;;
    esac
}

install_core_online() {
    local core_name="$1"
    
    log cyan "🌐 Installing $core_name from GitHub releases..."
    
    case "$core_name" in
        "easytier")
            install_easytier_online
            ;;
        "rathole")
            install_rathole_online
            ;;
        *)
            log red "Unknown core: $core_name"
            return 1
            ;;
    esac
}

install_core_offline() {
    local core_name="$1"
    
    log cyan "📁 Installing $core_name from local files..."
    
    read -p "📂 Enter path to $core_name binary: " binary_path
    
    if [[ ! -f "$binary_path" ]]; then
        log red "File not found: $binary_path"
        press_key
        return 1
    fi
    
    if [[ ! -x "$binary_path" ]]; then
        log red "File is not executable: $binary_path"
        press_key
        return 1
    fi
    
    case "$core_name" in
        "easytier")
            cp "$binary_path" "$DEST_DIR/easytier-core"
            chmod +x "$DEST_DIR/easytier-core"
            
            # Ask for CLI binary
            read -p "📂 Enter path to easytier-cli (or ENTER to skip): " cli_path
            if [[ -f "$cli_path" ]] && [[ -x "$cli_path" ]]; then
                cp "$cli_path" "$DEST_DIR/easytier-cli"
                chmod +x "$DEST_DIR/easytier-cli"
                log green "✅ EasyTier CLI installed"
            fi
            
            log green "✅ EasyTier core installed from: $binary_path"
            ;;
        "rathole")
            cp "$binary_path" "$DEST_DIR/rathole"
            chmod +x "$DEST_DIR/rathole"
            log green "✅ Rathole core installed from: $binary_path"
            ;;
        *)
            log red "Unknown core: $core_name"
            return 1
            ;;
    esac
    
    press_key
}

install_easytier_online() {
    log cyan "Installing EasyTier from GitHub..."
    
    # Detect architecture
    local arch=$(uname -m)
    case $arch in
        x86_64) arch_suffix="x86_64" ;;
        armv7l) arch_suffix="armv7" ;;
        aarch64) arch_suffix="aarch64" ;;
        *) log red "Unsupported architecture: $arch"; return 1 ;;
    esac
    
    # Get latest version
    log cyan "🔍 Fetching latest EasyTier version..."
    local latest_version=$(curl -s https://api.github.com/repos/EasyTier/EasyTier/releases/latest | jq -r '.tag_name' 2>/dev/null)
    if [[ -z "$latest_version" ]] || [[ "$latest_version" == "null" ]]; then
        log yellow "Using fallback EasyTier version"
        latest_version="v1.2.3"
    fi
    
    log cyan "📥 Downloading EasyTier $latest_version..."
    
    # Download and install
    local download_url="https://github.com/EasyTier/EasyTier/releases/latest/download/easytier-linux-${arch_suffix}-${latest_version}.zip"
    local temp_dir=$(mktemp -d)
    
    cd "$temp_dir"
    if curl -fsSL "$download_url" -o easytier.zip; then
        unzip -q easytier.zip 2>/dev/null
        find . -name "easytier-core" -executable -exec cp {} "$DEST_DIR/" \; 2>/dev/null
        find . -name "easytier-cli" -executable -exec cp {} "$DEST_DIR/" \; 2>/dev/null
        chmod +x "$DEST_DIR/easytier-core" "$DEST_DIR/easytier-cli" 2>/dev/null
        log green "✅ EasyTier $latest_version installed successfully"
    else
        log red "❌ Failed to download EasyTier"
        cd / && rm -rf "$temp_dir"
        return 1
    fi
    
    cd / && rm -rf "$temp_dir"
    press_key
}

install_rathole_online() {
    log cyan "Installing Rathole from GitHub..."
    
    # Detect architecture
    local arch=$(uname -m)
    case $arch in
        x86_64) arch_suffix="x86_64-unknown-linux-gnu" ;;
        aarch64) arch_suffix="aarch64-unknown-linux-musl" ;;
        armv7l) arch_suffix="armv7-unknown-linux-musleabihf" ;;
        *) 
            log yellow "Rathole not available for architecture: $arch"
            log yellow "Supported: x86_64, aarch64, armv7l"
            press_key
            return 0
            ;;
    esac
    
    # Get latest version
    log cyan "🔍 Fetching latest Rathole version..."
    local latest_version=$(curl -s https://api.github.com/repos/rathole-org/rathole/releases/latest | jq -r '.tag_name' 2>/dev/null)
    if [[ -z "$latest_version" ]] || [[ "$latest_version" == "null" ]]; then
        log yellow "Using fallback Rathole version"
        latest_version="v0.5.0"
    fi
    
    log cyan "📥 Downloading Rathole $latest_version..."
    
    # Download and install
    local download_url="https://github.com/rathole-org/rathole/releases/download/${latest_version}/rathole-${arch_suffix}.zip"
    local temp_dir=$(mktemp -d)
    
    cd "$temp_dir"
    if curl -fsSL "$download_url" -o rathole.zip; then
        unzip -q rathole.zip 2>/dev/null
        find . -name "rathole" -executable -exec cp {} "$DEST_DIR/" \; 2>/dev/null
        chmod +x "$DEST_DIR/rathole" 2>/dev/null
        log green "✅ Rathole $latest_version installed successfully"
    else
        log yellow "⚠️ Rathole installation failed"
        log yellow "You can continue with EasyTier only"
    fi
    
    cd / && rm -rf "$temp_dir"
    press_key
}

install_from_mvtunnel_repo() {
    log cyan "🔄 Installing from MVTunnel repository..."
    
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    log cyan "📥 Cloning MVTunnel repository..."
    if git clone https://github.com/k4lantar4/mvtunnel.git; then
        cd mvtunnel
        
        # Check for prebuilt binaries
        if [[ -d "binaries" ]]; then
            log cyan "📦 Installing prebuilt binaries..."
            
            local arch=$(uname -m)
            local arch_dir=""
            
            case $arch in
                x86_64) arch_dir="x86_64" ;;
                aarch64) arch_dir="aarch64" ;;
                armv7l) arch_dir="armv7" ;;
                *) log red "Unsupported architecture: $arch"; cd /; rm -rf "$temp_dir"; return 1 ;;
            esac
            
            if [[ -d "binaries/$arch_dir" ]]; then
                # Install EasyTier
                if [[ -f "binaries/$arch_dir/easytier-core" ]]; then
                    cp "binaries/$arch_dir/easytier-core" "$DEST_DIR/"
                    cp "binaries/$arch_dir/easytier-cli" "$DEST_DIR/" 2>/dev/null || true
                    chmod +x "$DEST_DIR/easytier-core" "$DEST_DIR/easytier-cli" 2>/dev/null || true
                    log green "✅ EasyTier installed from repository"
                fi
                
                # Install Rathole
                if [[ -f "binaries/$arch_dir/rathole" ]]; then
                    cp "binaries/$arch_dir/rathole" "$DEST_DIR/"
                    chmod +x "$DEST_DIR/rathole"
                    log green "✅ Rathole installed from repository"
                fi
                
                log green "🎉 Installation from MVTunnel repository completed!"
            else
                log red "No prebuilt binaries for $arch architecture"
                log cyan "Falling back to online installation..."
                install_easytier_online
                install_rathole_online
            fi
        else
            log yellow "No binaries directory found, falling back to online installation"
            install_easytier_online
            install_rathole_online
        fi
    else
        log red "Failed to clone MVTunnel repository"
        log cyan "Falling back to online installation..."
        install_easytier_online
        install_rathole_online
    fi
    
    cd /
    rm -rf "$temp_dir"
    press_key
}

install_from_local_files() {
    log cyan "📁 Install from local files"
    echo
    
    read -p "📂 Enter path to local files directory: " local_path
    
    if [[ ! -d "$local_path" ]]; then
        log red "Directory not found: $local_path"
        press_key
        return 1
    fi
    
    log cyan "🔍 Scanning for tunnel cores in: $local_path"
    
    # Look for EasyTier
    local easytier_found=false
    for file in "$local_path"/easytier-core*; do
        if [[ -f "$file" ]] && [[ -x "$file" ]]; then
            cp "$file" "$DEST_DIR/easytier-core"
            chmod +x "$DEST_DIR/easytier-core"
            easytier_found=true
            log green "✅ EasyTier core installed from: $(basename "$file")"
            break
        fi
    done
    
    # Look for EasyTier CLI
    for file in "$local_path"/easytier-cli*; do
        if [[ -f "$file" ]] && [[ -x "$file" ]]; then
            cp "$file" "$DEST_DIR/easytier-cli"
            chmod +x "$DEST_DIR/easytier-cli"
            log green "✅ EasyTier CLI installed from: $(basename "$file")"
            break
        fi
    done
    
    # Look for Rathole
    local rathole_found=false
    for file in "$local_path"/rathole*; do
        if [[ -f "$file" ]] && [[ -x "$file" ]]; then
            cp "$file" "$DEST_DIR/rathole"
            chmod +x "$DEST_DIR/rathole"
            rathole_found=true
            log green "✅ Rathole core installed from: $(basename "$file")"
            break
        fi
    done
    
    if [[ "$easytier_found" == "false" ]] && [[ "$rathole_found" == "false" ]]; then
        log red "No tunnel cores found in: $local_path"
        log yellow "Expected files: easytier-core, easytier-cli, rathole"
    else
        log green "🎉 Local installation completed!"
    fi
    
    press_key
}

install_both_cores_menu() {
    clear
    log purple "📦 Install Both Tunnel Cores"
    echo
    
    log cyan "Installation Methods:"
    echo "1) Online (Recommended)"
    echo "2) MVTunnel Repository"
    echo "3) Local Files"
    echo "0) Back"
    echo
    
    read -p "Select method [1-3]: " method_choice
    
    case $method_choice in
        1)
            install_easytier_online
            install_rathole_online
            ;;
        2)
            install_from_mvtunnel_repo
            ;;
        3)
            install_from_local_files
            ;;
        0)
            return
            ;;
        *)
            log red "Invalid option"
            sleep 1
            install_both_cores_menu
            ;;
    esac
}

update_cores_menu() {
    clear
    log purple "🔄 Update Tunnel Cores"
    echo
    
    show_cores_status
    echo
    
    log cyan "Update Options:"
    echo "1) Update EasyTier"
    echo "2) Update Rathole"
    echo "3) Update Both"
    echo "0) Back"
    echo
    
    read -p "Select option [1-3]: " update_choice
    
    case $update_choice in
        1) 
            if [[ -f "$DEST_DIR/easytier-core" ]]; then
                install_easytier_online
            else
                log red "EasyTier not installed"
                press_key
            fi
            ;;
        2)
            if [[ -f "$DEST_DIR/rathole" ]]; then
                install_rathole_online
            else
                log red "Rathole not installed"
                press_key
            fi
            ;;
        3)
            install_easytier_online
            install_rathole_online
            ;;
        0)
            return
            ;;
        *)
            log red "Invalid option"
            sleep 1
            update_cores_menu
            ;;
    esac
}

remove_cores_menu() {
    clear
    log purple "🗑️  Remove Tunnel Cores"
    echo
    
    show_cores_status
    echo
    
    log yellow "⚠️  WARNING: This will remove tunnel cores from your system!"
    echo
    
    log cyan "Remove Options:"
    echo "1) Remove EasyTier"
    echo "2) Remove Rathole"
    echo "3) Remove Both"
    echo "0) Back"
    echo
    
    read -p "Select option [1-3]: " remove_choice
    
    case $remove_choice in
        1)
            read -p "Confirm remove EasyTier? [y/N]: " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                rm -f "$DEST_DIR/easytier-core" "$DEST_DIR/easytier-cli"
                log green "✅ EasyTier removed"
            fi
            ;;
        2)
            read -p "Confirm remove Rathole? [y/N]: " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                rm -f "$DEST_DIR/rathole"
                log green "✅ Rathole removed"
            fi
            ;;
        3)
            read -p "Confirm remove ALL tunnel cores? [y/N]: " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                rm -f "$DEST_DIR/easytier-core" "$DEST_DIR/easytier-cli" "$DEST_DIR/rathole"
                log green "✅ All tunnel cores removed"
            fi
            ;;
        0)
            return
            ;;
        *)
            log red "Invalid option"
            sleep 1
            remove_cores_menu
            ;;
    esac
    
    press_key
}

show_detailed_cores_status() {
    clear
    log purple "🔍 Detailed Core Status"
    echo "========================="
    echo
    
    # EasyTier detailed status
    log cyan "🚇 EasyTier Status:"
    if [[ -f "$DEST_DIR/easytier-core" ]]; then
        local easytier_version=$("$DEST_DIR/easytier-core" --version 2>/dev/null | head -1 || echo "Unknown")
        local easytier_size=$(ls -lh "$DEST_DIR/easytier-core" | awk '{print $5}')
        local easytier_date=$(stat -c %y "$DEST_DIR/easytier-core" | cut -d' ' -f1)
        
        echo "  Status: ✅ Installed"
        echo "  Version: $easytier_version"
        echo "  Size: $easytier_size"
        echo "  Install Date: $easytier_date"
        echo "  Path: $DEST_DIR/easytier-core"
        
        if [[ -f "$DEST_DIR/easytier-cli" ]]; then
            echo "  CLI: ✅ Available"
        else
            echo "  CLI: ❌ Missing"
        fi
    else
        echo "  Status: ❌ Not installed"
    fi
    echo
    
    # Rathole detailed status
    log cyan "⚡ Rathole Status:"
    if [[ -f "$DEST_DIR/rathole" ]]; then
        local rathole_version=$("$DEST_DIR/rathole" --version 2>/dev/null | head -1 || echo "Unknown")
        local rathole_size=$(ls -lh "$DEST_DIR/rathole" | awk '{print $5}')
        local rathole_date=$(stat -c %y "$DEST_DIR/rathole" | cut -d' ' -f1)
        
        echo "  Status: ✅ Installed"
        echo "  Version: $rathole_version"
        echo "  Size: $rathole_size"
        echo "  Install Date: $rathole_date"
        echo "  Path: $DEST_DIR/rathole"
    else
        echo "  Status: ❌ Not installed"
    fi
    echo
    
    # System compatibility
    log cyan "🖥️  System Compatibility:"
    local arch=$(uname -m)
    echo "  Architecture: $arch"
    echo "  OS: $(lsb_release -d 2>/dev/null | cut -d: -f2 | xargs || uname -o)"
    echo "  Kernel: $(uname -r)"
    
    # Check requirements
    echo
    log cyan "📋 Requirements Check:"
    
    # Check for required commands
    local requirements=("curl" "wget" "unzip" "jq" "nc" "ping" "ss" "ip")
    for req in "${requirements[@]}"; do
        if command -v "$req" >/dev/null; then
            echo "  $req: ✅ Available"
        else
            echo "  $req: ❌ Missing"
        fi
    done
    
    press_key
}

compile_core_from_source() {
    local core_name="$1"
    
    log cyan "🔨 Compiling $core_name from source..."
    log yellow "⚠️  This requires Rust compiler and may take several minutes"
    echo
    
    read -p "Continue with source compilation? [y/N]: " confirm_compile
    if [[ ! "$confirm_compile" =~ ^[Yy]$ ]]; then
        return
    fi
    
    # Check for Rust
    if ! command -v cargo >/dev/null; then
        log yellow "Rust not found. Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source ~/.cargo/env
    fi
    
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    case "$core_name" in
        "easytier")
            log cyan "📥 Cloning EasyTier repository..."
            git clone https://github.com/EasyTier/EasyTier.git
            cd EasyTier
            log cyan "🔨 Compiling EasyTier..."
            cargo build --release --bin easytier-core --bin easytier-cli
            cp target/release/easytier-core "$DEST_DIR/"
            cp target/release/easytier-cli "$DEST_DIR/"
            chmod +x "$DEST_DIR/easytier-core" "$DEST_DIR/easytier-cli"
            log green "✅ EasyTier compiled and installed"
            ;;
        "rathole")
            log cyan "📥 Cloning Rathole repository..."
            git clone https://github.com/rathole-org/rathole.git
            cd rathole
            log cyan "🔨 Compiling Rathole..."
            cargo build --release
            cp target/release/rathole "$DEST_DIR/"
            chmod +x "$DEST_DIR/rathole"
            log green "✅ Rathole compiled and installed"
            ;;
        *)
            log red "Unknown core: $core_name"
            cd /; rm -rf "$temp_dir"
            return 1
            ;;
    esac
    
    cd /
    rm -rf "$temp_dir"
    press_key
}

# =============================================================================
# Connection Functions
# =============================================================================

connect_tunnel() {
    log purple "🚀 Connecting MVTunnel..."
    
    # Load configuration
    if [[ ! -f "$MAIN_CONFIG" ]]; then
        log red "No configuration found. Run: mv setup"
        return 1
    fi
    
    source "$MAIN_CONFIG"
    
    # Start tunnel based on mode
    case "$TUNNEL_MODE" in
        "easytier")
            start_easytier
            ;;
        "rathole")
            start_rathole
            ;;
        "hybrid")
            start_hybrid_mode
            ;;
        *)
            log red "Unknown tunnel mode: $TUNNEL_MODE"
            return 1
            ;;
    esac
    
    # Start monitoring if enabled
    if [[ "$FAILOVER_ENABLED" == "true" ]]; then
        start_monitoring
    fi
    
    log green "🎉 MVTunnel connected successfully!"
    show_connection_status
}

start_easytier() {
    log cyan "Starting EasyTier tunnel..."
    
    if [[ ! -f "$DEST_DIR/easytier-core" ]]; then
        log red "EasyTier not installed. Use: mv install-cores"
        return 1
    fi
    
    # Load configuration
    source "$MAIN_CONFIG"
    
    # Build EasyTier command based on node type
    local easytier_cmd="$DEST_DIR/easytier-core"
    local listeners=""
    local peers=""
    local additional_args=""
    
    # Configure based on node type
    if [[ "${EASYTIER_NODE_TYPE:-client}" == "master" ]]; then
        log cyan "🏗️  Starting as Master Node..."
        listeners="--listeners ${PROTOCOL}://0.0.0.0:${PORT}"
        
        # Master mode: Listen on 0.0.0.0 with local IP in virtual network
        easytier_cmd="$easytier_cmd -i $LOCAL_IP"
        
        log cyan "💡 Master mode: Waiting for clients to connect..."
    else
        log cyan "🔗 Starting as Client Node..."
        
        if [[ -z "$REMOTE_SERVER" ]]; then
            log red "Remote server required for client mode"
            return 1
        fi
        
        listeners="--listeners ${PROTOCOL}://0.0.0.0:${PORT}"
        peers="--peers ${PROTOCOL}://${REMOTE_SERVER}:${PORT}"
        
        # Client mode: Connect to master/peers
        easytier_cmd="$easytier_cmd -i $LOCAL_IP"
        
        log cyan "🎯 Connecting to master: $REMOTE_SERVER:$PORT"
    fi
    
    # Add performance options
    if [[ "${MULTI_THREAD:-true}" == "true" ]]; then
        additional_args="$additional_args --multi-thread"
    fi
    
    if [[ "${ENCRYPTION:-true}" == "false" ]]; then
        additional_args="$additional_args --disable-encryption"
    fi
    
    # Protocol-specific optimizations
    case "$PROTOCOL" in
        "udp")
            additional_args="$additional_args --disable-ipv6"
            ;;
        "tcp")
            additional_args="$additional_args --tcp-nodelay"
            ;;
        "quic")
            additional_args="$additional_args --enable-exit-node"
            ;;
        "wg")
            additional_args="$additional_args --enable-wireguard"
            ;;
    esac
    
    # Kill existing process
    pkill -f "easytier-core" 2>/dev/null || true
    sleep 2
    
    # Start EasyTier with built command
    nohup $easytier_cmd \
        --hostname "mvtunnel-$(hostname)" \
        --network-secret "$NETWORK_SECRET" \
        --default-protocol "$PROTOCOL" \
        $listeners \
        $peers \
        $additional_args \
        > "$LOG_DIR/easytier.log" 2>&1 &
    
    sleep 3
    
    if pgrep -f "easytier-core" > /dev/null; then
        echo "ACTIVE_TUNNEL=easytier" > "$STATUS_FILE"
        echo "NODE_TYPE=${EASYTIER_NODE_TYPE:-client}" >> "$STATUS_FILE"
        log green "✅ EasyTier started successfully as ${EASYTIER_NODE_TYPE:-client}"
        return 0
    else
        log red "❌ Failed to start EasyTier"
        cat "$LOG_DIR/easytier.log" | tail -10
        return 1
    fi
}

start_rathole() {
    log cyan "Starting Rathole tunnel..."
    
    if [[ ! -f "$DEST_DIR/rathole" ]]; then
        log red "Rathole not installed. Use: mv install-cores"
        return 1
    fi
    
    # Load configuration
    source "$MAIN_CONFIG"
    
    # Create Rathole config based on node type
    if [[ "${RATHOLE_NODE_TYPE:-client}" == "server" ]]; then
        log cyan "🔧 Starting as Rathole Server..."
        create_rathole_server_config
        local config_flag="-s"
        log cyan "💡 Server mode: Listening for client connections on port $PORT"
    else
        log cyan "🔗 Starting as Rathole Client..."
        
        if [[ -z "$REMOTE_SERVER" ]]; then
            log red "Remote server required for client mode"
            return 1
        fi
        
        create_rathole_client_config
        local config_flag="-c"
        log cyan "🎯 Connecting to server: $REMOTE_SERVER:$PORT"
    fi
    
    # Kill existing process
    pkill -f "rathole" 2>/dev/null || true
    sleep 2
    
    # Start Rathole with appropriate config
    nohup "$DEST_DIR/rathole" $config_flag "$RATHOLE_CONFIG" \
        > "$LOG_DIR/rathole.log" 2>&1 &
    
    sleep 3
    
    if pgrep -f "rathole" > /dev/null; then
        echo "ACTIVE_TUNNEL=rathole" > "$STATUS_FILE"
        echo "NODE_TYPE=${RATHOLE_NODE_TYPE:-client}" >> "$STATUS_FILE"
        log green "✅ Rathole started successfully as ${RATHOLE_NODE_TYPE:-client}"
        return 0
    else
        log red "❌ Failed to start Rathole"
        cat "$LOG_DIR/rathole.log" | tail -10
        return 1
    fi
}

create_rathole_server_config() {
    cat > "$RATHOLE_CONFIG" << EOF
[server]
bind_addr = "0.0.0.0:${PORT}"
default_token = "${NETWORK_SECRET}"

[server.transport]
type = "${PROTOCOL}"

[server.transport.tcp]
nodelay = true
keepalive_secs = 20

[server.transport.tls]
hostname = "example.com"

[server.services.tunnel]
type = "${PROTOCOL}"
bind_addr = "0.0.0.0:8080"
token = "${NETWORK_SECRET}"

# Performance optimizations
[server.services.tunnel.nodelay]
enabled = true

# Additional services can be added here
# [server.services.web]
# type = "tcp"
# bind_addr = "0.0.0.0:80"
# token = "${NETWORK_SECRET}"
EOF
}

create_rathole_client_config() {
    cat > "$RATHOLE_CONFIG" << EOF
[client]
remote_addr = "${REMOTE_SERVER}:${PORT}"
default_token = "${NETWORK_SECRET}"

[client.transport]
type = "${PROTOCOL}"

[client.transport.tcp]
nodelay = true
keepalive_secs = 20

[client.transport.tls]
trusted_root = "ca.pem"
hostname = "example.com"

[client.services.tunnel]
type = "${PROTOCOL}"
local_addr = "127.0.0.1:8080"
remote_addr = "0.0.0.0:8080"
token = "${NETWORK_SECRET}"

# Performance optimizations
[client.services.tunnel.nodelay]
enabled = true

# Compression settings
[client.services.tunnel.compress]
enabled = $([[ "${COMPRESSION:-true}" == "true" ]] && echo "true" || echo "false")

# Heartbeat settings
[client.heartbeat_timeout]
enabled = true
interval = 30

# Additional local services
# [client.services.ssh]
# type = "tcp"
# local_addr = "127.0.0.1:22"
# remote_addr = "0.0.0.0:2222"
# token = "${NETWORK_SECRET}"

# [client.services.web]
# type = "tcp" 
# local_addr = "127.0.0.1:80"
# remote_addr = "0.0.0.0:8080"
# token = "${NETWORK_SECRET}"
EOF
}

start_hybrid_mode() {
    log cyan "Starting Hybrid mode (EasyTier + Rathole)..."
    
    # Try EasyTier first
    if start_easytier; then
        log green "Primary tunnel: EasyTier active"
        echo "ACTIVE_TUNNEL=easytier" > "$STATUS_FILE"
        echo "BACKUP_AVAILABLE=rathole" >> "$STATUS_FILE"
    elif start_rathole; then
        log green "Backup tunnel: Rathole active"
        echo "ACTIVE_TUNNEL=rathole" > "$STATUS_FILE"
        echo "BACKUP_AVAILABLE=easytier" >> "$STATUS_FILE"
    else
        log red "Both tunnels failed to start"
        return 1
    fi
}

# =============================================================================
# Monitoring Functions
# =============================================================================

start_monitoring() {
    log cyan "Starting intelligent monitoring..."
    
    # Kill existing monitor
    pkill -f "mvtunnel_monitor" 2>/dev/null || true
    
    # Start background monitor
    (monitor_loop) &
    echo $! > "$CONFIG_DIR/monitor.pid"
    
    log green "Monitoring started"
}

monitor_loop() {
    source "$MAIN_CONFIG" 2>/dev/null || return
    source "$MONITOR_CONFIG" 2>/dev/null || return
    
    local failed_checks=0
    
    while true; do
        if check_tunnel_health; then
            failed_checks=0
        else
            ((failed_checks++))
            log yellow "Tunnel health check failed ($failed_checks/3)"
            
            if [[ $failed_checks -ge 3 ]]; then
                log red "Tunnel failure detected, attempting recovery..."
                recover_tunnel
                failed_checks=0
            fi
        fi
        
        sleep "${MONITOR_INTERVAL:-5}"
    done
}

check_tunnel_health() {
    local target_ip="$REMOTE_IP"
    local health_score=0
    local max_score=5
    
    # 1. Process health check
    case "$TUNNEL_MODE" in
        "easytier")
            if pgrep -f "easytier-core" > /dev/null; then
                ((health_score++))
            fi
            ;;
        "rathole")
            if pgrep -f "rathole" > /dev/null; then
                ((health_score++))
            fi
            ;;
        "hybrid")
            if pgrep -f "easytier-core\|rathole" > /dev/null; then
                ((health_score++))
            fi
            ;;
    esac
    
    # 2. Basic connectivity test (ping)
    if ping -c 1 -W 3 "$target_ip" >/dev/null 2>&1; then
        ((health_score++))
    fi
    
    # 3. Port connectivity test
    if nc -z -w 3 "$target_ip" "$PORT" 2>/dev/null; then
        ((health_score++))
    fi
    
    # 4. Latency check (under 500ms acceptable)
    local latency=$(ping -c 1 "$target_ip" 2>/dev/null | grep 'time=' | sed -n 's/.*time=\([0-9.]*\).*/\1/p')
    if [[ -n "$latency" ]] && (( $(echo "$latency < 500" | bc -l 2>/dev/null || echo 0) )); then
        ((health_score++))
    fi
    
    # 5. Throughput test (basic)
    if command -v curl >/dev/null && curl -s --max-time 5 --connect-timeout 3 "http://$target_ip:80" >/dev/null 2>&1; then
        ((health_score++))
    fi
    
    # Log health status
    log blue "Health check: $health_score/$max_score ($(($health_score * 100 / $max_score))%)"
    
    # Consider healthy if score >= 3
    [[ $health_score -ge 3 ]]
}

recover_tunnel() {
    log cyan "Initiating tunnel recovery..."
    
    source "$MAIN_CONFIG"
    
    case "$TUNNEL_MODE" in
        "easytier")
            log yellow "Restarting EasyTier..."
            start_easytier
            ;;
        "rathole")
            log yellow "Restarting Rathole..."
            start_rathole
            ;;
        "hybrid")
            log yellow "Switching tunnel cores..."
            switch_tunnel_core
            ;;
    esac
}

switch_tunnel_core() {
    local current_tunnel="easytier"
    if [[ -f "$STATUS_FILE" ]]; then
        current_tunnel=$(grep "ACTIVE_TUNNEL=" "$STATUS_FILE" | cut -d'=' -f2)
    fi
    
    if [[ "$current_tunnel" == "easytier" ]]; then
        log cyan "Switching to Rathole..."
        pkill -f "easytier-core" 2>/dev/null || true
        if start_rathole; then
            log green "Switched to Rathole successfully"
        fi
    else
        log cyan "Switching to EasyTier..."
        pkill -f "rathole" 2>/dev/null || true
        if start_easytier; then
            log green "Switched to EasyTier successfully"
        fi
    fi
}

# =============================================================================
# Status and Management
# =============================================================================

show_status() {
    clear
    log purple "📊 MVTunnel System Status"
    echo "==============================="
    echo
    
    if [[ ! -f "$MAIN_CONFIG" ]]; then
        log red "No configuration found"
        return 1
    fi
    
    source "$MAIN_CONFIG"
    
    # System Info
    log cyan "🖥️  System Information:"
    echo "  Public IP: $(get_public_ip)"
    echo "  System IP: $(get_system_ip)"
    echo "  Hostname: $(hostname)"
    echo
    
    # Tunnel Status
    log cyan "🚇 Tunnel Configuration:"
    echo "  Mode: $TUNNEL_MODE"
    echo "  Local IP: $LOCAL_IP"
    echo "  Remote IP: $REMOTE_IP"
    echo "  Protocol: $PROTOCOL"
    echo "  Port: $PORT"
    echo
    
    # Process Status
    log cyan "⚙️  Process Status:"
    if pgrep -f "easytier-core" > /dev/null; then
        echo "  EasyTier: ✅ Running (PID: $(pgrep -f easytier-core))"
    else
        echo "  EasyTier: ❌ Stopped"
    fi
    
    if pgrep -f "rathole" > /dev/null; then
        echo "  Rathole: ✅ Running (PID: $(pgrep -f rathole))"
    else
        echo "  Rathole: ❌ Stopped"
    fi
    
    if [[ -f "$CONFIG_DIR/monitor.pid" ]] && kill -0 "$(cat $CONFIG_DIR/monitor.pid)" 2>/dev/null; then
        echo "  Monitor: ✅ Running"
    else
        echo "  Monitor: ❌ Stopped"
    fi
    echo
    
    # Network Health
    log cyan "🌐 Network Health:"
    if ping -c 1 -W 3 "$REMOTE_IP" >/dev/null 2>&1; then
        local latency=$(ping -c 1 "$REMOTE_IP" | grep 'time=' | sed -n 's/.*time=\([0-9.]*\).*/\1/p')
        echo "  Connection: ✅ Active (${latency}ms)"
    else
        echo "  Connection: ❌ Failed"
    fi
    
    # Active Tunnel
    if [[ -f "$STATUS_FILE" ]]; then
        local active_tunnel=$(grep "ACTIVE_TUNNEL=" "$STATUS_FILE" | cut -d'=' -f2)
        echo "  Active Core: $active_tunnel"
    fi
    
    echo
}

show_connection_status() {
    echo
    log cyan "📋 Connection Details:"
    echo "  🌐 Local tunnel IP: $LOCAL_IP"
    echo "  🎯 Remote tunnel IP: $REMOTE_IP"  
    echo "  🔌 Protocol: $PROTOCOL"
    echo "  🚪 Port: $PORT"
    echo "  🔐 Secret: $NETWORK_SECRET"
    echo "  📡 Public IP: $(get_public_ip)"
    echo
}

live_monitor() {
    clear
    log purple "📊 MVTunnel Live Monitor (Ctrl+C to exit)"
    echo "=============================================="
    echo
    
    trap 'echo; log cyan "Monitor stopped"; exit 0' INT
    
    while true; do
        clear
        echo -e "${PURPLE}📊 MVTunnel Live Monitor - $(date)${NC}"
        echo "=============================================="
        echo
        
        source "$MAIN_CONFIG" 2>/dev/null || true
        
        # Process status
        echo -e "${CYAN}Process Status:${NC}"
        if pgrep -f "easytier-core" > /dev/null; then
            echo "  EasyTier: ✅ Running"
        else
            echo "  EasyTier: ❌ Stopped"
        fi
        
        if pgrep -f "rathole" > /dev/null; then
            echo "  Rathole: ✅ Running"
        else
            echo "  Rathole: ❌ Stopped"
        fi
        echo
        
        # Network status
        echo -e "${CYAN}Network Status:${NC}"
        if [[ -n "$REMOTE_IP" ]]; then
            if ping -c 1 -W 2 "$REMOTE_IP" >/dev/null 2>&1; then
                local latency=$(ping -c 1 "$REMOTE_IP" | grep 'time=' | sed -n 's/.*time=\([0-9.]*\).*/\1/p')
                echo "  Tunnel: ✅ Connected (${latency}ms)"
            else
                echo "  Tunnel: ❌ Disconnected"
            fi
        fi
        
        # Active tunnel
        if [[ -f "$STATUS_FILE" ]]; then
            local active_tunnel=$(grep "ACTIVE_TUNNEL=" "$STATUS_FILE" | cut -d'=' -f2)
            echo "  Active Core: $active_tunnel"
        fi
        
        echo
        echo "Refreshing in 3 seconds..."
        sleep 3
    done
}

stop_tunnel() {
    log cyan "Stopping MVTunnel..."
    
    # Stop processes gracefully
    pkill -TERM -f "easytier-core" 2>/dev/null || true
    pkill -TERM -f "rathole" 2>/dev/null || true
    
    # Wait for graceful shutdown
    sleep 3
    
    # Force kill if still running
    pkill -KILL -f "easytier-core" 2>/dev/null || true
    pkill -KILL -f "rathole" 2>/dev/null || true
    
    # Stop monitor
    if [[ -f "$CONFIG_DIR/monitor.pid" ]]; then
        kill "$(cat $CONFIG_DIR/monitor.pid)" 2>/dev/null || true
        rm -f "$CONFIG_DIR/monitor.pid"
    fi
    
    # Network cleanup
    network_cleanup
    
    # Clear status and PID files
    rm -f "$STATUS_FILE" "$CONFIG_DIR/mvtunnel.pid"
    
    log green "MVTunnel stopped and cleaned up"
}

network_cleanup() {
    log cyan "Performing network cleanup..."
    
    # Load configuration for cleanup
    if [[ -f "$MAIN_CONFIG" ]]; then
        source "$MAIN_CONFIG"
    fi
    
    # Clean up virtual interfaces created by tunnels
    local interfaces_to_clean=(
        "easytier0"
        "mvtunnel0" 
        "rathole0"
        "tun-mvtunnel"
    )
    
    for iface in "${interfaces_to_clean[@]}"; do
        if ip link show "$iface" >/dev/null 2>&1; then
            log yellow "Removing interface: $iface"
            ip link delete "$iface" 2>/dev/null || true
        fi
    done
    
    # Clean up routing rules related to tunnel
    if [[ -n "${LOCAL_IP:-}" ]]; then
        # Remove routes for tunnel network
        local tunnel_network="${LOCAL_IP%.*}.0/24"
        ip route del "$tunnel_network" 2>/dev/null || true
        log blue "Removed route for: $tunnel_network"
    fi
    
    # Clean up iptables rules (if any were added)
    cleanup_iptables_rules
    
    # Clean up process-specific cleanup
    case "${TUNNEL_MODE:-}" in
        "easytier")
            cleanup_easytier_network
            ;;
        "rathole") 
            cleanup_rathole_network
            ;;
        "hybrid")
            cleanup_easytier_network
            cleanup_rathole_network
            ;;
    esac
    
    log green "Network cleanup completed"
}

cleanup_iptables_rules() {
    # Remove any MVTunnel-specific iptables rules
    local port="${PORT:-1377}"
    
    # Remove port forwarding rules
    iptables -D INPUT -p udp --dport "$port" -j ACCEPT 2>/dev/null || true
    iptables -D INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || true
    
    # Remove masquerading rules if any
    iptables -t nat -D POSTROUTING -s "${LOCAL_IP:-10.10.10.0}/24" -j MASQUERADE 2>/dev/null || true
    
    log blue "IPTables rules cleaned up"
}

cleanup_easytier_network() {
    # EasyTier specific cleanup
    local easytier_interfaces=$(ip link show | grep -o "easytier[0-9]*" || true)
    for iface in $easytier_interfaces; do
        if [[ -n "$iface" ]]; then
            ip link delete "$iface" 2>/dev/null || true
            log blue "Removed EasyTier interface: $iface"
        fi
    done
}

cleanup_rathole_network() {
    # Rathole specific cleanup
    # Remove any port forwarding rules specific to rathole
    local rathole_port="${PORT:-1377}"
    netstat -tuln | grep ":$rathole_port " | while read line; do
        log blue "Rathole cleanup: Found listening port $rathole_port"
    done
}

restart_tunnel() {
    log cyan "Restarting MVTunnel..."
    stop_tunnel
    sleep 3
    connect_tunnel
}

switch_protocol() {
    log purple "🔄 Protocol Switching"
    echo
    
    if [[ ! -f "$MAIN_CONFIG" ]]; then
        log red "No configuration found"
        return 1
    fi
    
    source "$MAIN_CONFIG"
    
    log blue "Current protocol: $PROTOCOL"
    echo
    echo "Available protocols:"
    echo "1) UDP (Current: $([ "$PROTOCOL" == "udp" ] && echo "✅" || echo "  "))"
    echo "2) TCP (Current: $([ "$PROTOCOL" == "tcp" ] && echo "✅" || echo "  "))"
    echo "3) WebSocket (Current: $([ "$PROTOCOL" == "ws" ] && echo "✅" || echo "  "))"
    echo
    
    read -p "Select new protocol [1-3]: " protocol_choice
    
    local new_protocol
    case $protocol_choice in
        1) new_protocol="udp" ;;
        2) new_protocol="tcp" ;;
        3) new_protocol="ws" ;;
        *) log red "Invalid option"; return 1 ;;
    esac
    
    if [[ "$new_protocol" == "$PROTOCOL" ]]; then
        log yellow "Already using $PROTOCOL protocol"
        return 0
    fi
    
    log cyan "Switching to $new_protocol protocol..."
    
    # Update configuration
    sed -i "s/PROTOCOL=\".*\"/PROTOCOL=\"$new_protocol\"/" "$MAIN_CONFIG"
    
    # Restart tunnel with new protocol
    restart_tunnel
    
    log green "Protocol switched to $new_protocol successfully!"
}

# =============================================================================
# Help and Menu Functions
# =============================================================================

show_help() {
    clear
    echo -e "${CYAN}🚀 MVTunnel - Intelligent Dual-Core Tunnel System v${MVTUNNEL_VERSION}${NC}"
    echo "================================================================="
    echo
    echo -e "${GREEN}USAGE:${NC}"
    echo "  sudo mv <command> [options]"
    echo
    echo -e "${GREEN}INSTALLATION:${NC}"
    echo -e "${CYAN}  curl -fsSL https://github.com/k4lantar4/mvtunnel/raw/main/mvtunnel.sh | sudo bash -s -- --install${NC}"
    echo
    echo -e "${GREEN}COMMANDS:${NC}"
    echo -e "${CYAN}  setup${NC}          Interactive tunnel configuration"
    echo -e "${CYAN}  install-cores${NC}  Manage tunnel cores (EasyTier/Rathole)"
    echo -e "${CYAN}  connect${NC}        Connect tunnel with current config"
    echo -e "${CYAN}  status${NC}         Show system and tunnel status"
    echo -e "${CYAN}  monitor${NC}        Live monitoring dashboard"
    echo -e "${CYAN}  stop${NC}           Stop all tunnel processes"
    echo -e "${CYAN}  restart${NC}        Restart tunnel services"
    echo -e "${CYAN}  switch${NC}         Switch between protocols"
    echo -e "${CYAN}  optimize${NC}       Apply network optimizations"
    echo -e "${CYAN}  haproxy${NC}        Setup HAProxy load balancing"
    echo -e "${CYAN}  logs${NC}           View system logs"
    echo -e "${CYAN}  backup${NC}         Create configuration backup"
    echo -e "${CYAN}  restore${NC}        Restore configuration from backup"
    echo -e "${CYAN}  version${NC}        Show version information"
    echo -e "${CYAN}  help${NC}           Show this help message"
    echo
    echo -e "${GREEN}FEATURES:${NC}"
    echo "  • Dual-core tunnel system (EasyTier + Rathole)"
    echo "  • Intelligent failover and auto-recovery"
    echo "  • Dynamic protocol switching (UDP/TCP/WS)"
    echo "  • Real-time network monitoring"
    echo "  • Enterprise-grade stability"
    echo "  • Iran network condition optimization"
    echo
    echo -e "${GREEN}EXAMPLES:${NC}"
    echo "  sudo mv setup      # Configure new tunnel"
    echo "  sudo mv connect    # Start tunneling"
    echo "  sudo mv monitor    # Monitor live status"
    echo "  sudo mv switch     # Change protocol"
    echo
    echo -e "${PURPLE}For support: https://github.com/k4lantar4/mvtunnel${NC}"
}

show_menu() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗"
    echo -e "║         ${WHITE}MVTunnel Manager v${MVTUNNEL_VERSION}${CYAN}         ║"
    echo -e "║    ${WHITE}Intelligent Dual-Core Tunnel System${CYAN}  ║"
    echo -e "╠════════════════════════════════════════╣"
    echo -e "║  ${WHITE}EasyTier + Rathole Integration      ${CYAN}║"
    echo -e "╚════════════════════════════════════════╝${NC}"
    echo
    
    # Show enhanced status indicators
    show_menu_status
    echo
    
    echo -e "${GREEN}[1]${NC}  🔧 Setup & Configuration"
    echo -e "${GREEN}[2]${NC}  📦 Manage Tunnel Cores"
    echo -e "${GREEN}[3]${NC}  🚀 Connect Tunnel"
    echo -e "${GREEN}[4]${NC}  📊 System Status"
    echo -e "${GREEN}[5]${NC}  📈 Live Monitor"
    echo -e "${GREEN}[6]${NC}  🔄 Switch Protocol"
    echo -e "${GREEN}[7]${NC}  🛑 Stop Tunnel"
    echo -e "${GREEN}[8]${NC}  ♻️  Restart Tunnel"
    echo -e "${GREEN}[9]${NC}  ⚡ Network Optimization"
    echo -e "${GREEN}[10]${NC} 📝 View Logs"
    echo -e "${GREEN}[11]${NC} 💾 Backup Configuration"
    echo -e "${GREEN}[12]${NC} 🔄 Restore Configuration"
    echo -e "${GREEN}[0]${NC}  ❌ Exit"
    echo
}

show_menu_status() {
    # Tunnel Status
    if [[ -f "$MAIN_CONFIG" ]]; then
        if pgrep -f "easytier-core\|rathole" > /dev/null; then
            echo -e "   ${GREEN}● Tunnel Status: Active${NC}"
            
            # Show active tunnel type
            if [[ -f "$STATUS_FILE" ]]; then
                local active_tunnel=$(grep "ACTIVE_TUNNEL=" "$STATUS_FILE" | cut -d'=' -f2)
                local node_type=$(grep "NODE_TYPE=" "$STATUS_FILE" | cut -d'=' -f2)
                echo -e "   ${CYAN}● Active Core: $active_tunnel ($node_type)${NC}"
            fi
        else
            echo -e "   ${RED}● Tunnel Status: Inactive${NC}"
        fi
    else
        echo -e "   ${YELLOW}● Tunnel Status: Not Configured${NC}"
    fi
    
    # Core Installation Status
    local easytier_status="❌"
    local rathole_status="❌"
    
    if [[ -f "$DEST_DIR/easytier-core" ]]; then
        easytier_status="✅"
    fi
    
    if [[ -f "$DEST_DIR/rathole" ]]; then
        rathole_status="✅"
    fi
    
    echo -e "   ${CYAN}● Cores: EasyTier $easytier_status | Rathole $rathole_status${NC}"
}

# =============================================================================
# HAProxy Integration Functions
# =============================================================================

setup_haproxy_integration() {
    clear
    log purple "🔄 HAProxy Integration Setup"
    echo "================================"
    echo
    
    # Check if HAProxy is installed
    if ! command -v haproxy >/dev/null; then
        log yellow "HAProxy not found. Installing..."
        
        # Install HAProxy
        if command -v apt-get >/dev/null; then
            apt-get update -qq
            apt-get install -y haproxy >/dev/null 2>&1
        elif command -v yum >/dev/null; then
            yum install -y haproxy >/dev/null 2>&1
        elif command -v dnf >/dev/null; then
            dnf install -y haproxy >/dev/null 2>&1
        else
            log red "Cannot install HAProxy automatically"
            press_key
            return 1
        fi
        
        if command -v haproxy >/dev/null; then
            log green "✅ HAProxy installed successfully"
        else
            log red "❌ HAProxy installation failed"
            press_key
            return 1
        fi
    fi
    
    log cyan "🔍 Configuring HAProxy for MVTunnel..."
    
    # Load current configuration
    if [[ -f "$MAIN_CONFIG" ]]; then
        source "$MAIN_CONFIG"
    else
        log red "No MVTunnel configuration found. Run: mv setup first"
        press_key
        return 1
    fi
    
    # Create HAProxy configuration
    create_haproxy_config
    
    # Test configuration
    if haproxy -c -f /etc/haproxy/haproxy.cfg >/dev/null 2>&1; then
        log green "✅ HAProxy configuration is valid"
        
        # Start/restart HAProxy
        systemctl enable haproxy
        systemctl restart haproxy
        
        if systemctl is-active --quiet haproxy; then
            log green "✅ HAProxy service is running"
        else
            log red "❌ Failed to start HAProxy service"
        fi
    else
        log red "❌ HAProxy configuration is invalid"
    fi
    
    echo
    log cyan "📋 HAProxy Status:"
    systemctl status haproxy --no-pager -l
    
    press_key
}

create_haproxy_config() {
    log cyan "📝 Creating HAProxy configuration..."
    
    # Backup existing config
    if [[ -f "/etc/haproxy/haproxy.cfg" ]]; then
        cp /etc/haproxy/haproxy.cfg "/etc/haproxy/haproxy.cfg.backup.$(date +%Y%m%d_%H%M%S)"
        log yellow "Existing config backed up"
    fi
    
    cat > /etc/haproxy/haproxy.cfg << EOF
# MVTunnel HAProxy Configuration
# Generated by MVTunnel v${MVTUNNEL_VERSION}

global
    daemon
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    
    # Performance tuning
    maxconn 4096
    tune.bufsize 32768
    tune.maxrewrite 1024
    
    # Logging
    log stdout local0

defaults
    mode tcp
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
    option tcplog
    option dontlognull
    option redispatch
    retries 3

# Statistics interface
listen stats
    bind *:8080
    stats enable
    stats uri /stats
    stats refresh 30s
    stats hide-version
    stats auth admin:mvtunnel123

# MVTunnel Load Balancer
frontend mvtunnel_frontend
    bind *:${PORT}
    mode tcp
    option tcplog
    default_backend mvtunnel_backend

backend mvtunnel_backend
    mode tcp
    balance roundrobin
    option tcp-check
    
    # EasyTier backend
    server easytier 127.0.0.1:$((PORT + 1)) check port $((PORT + 1)) inter 5s fall 3 rise 2
    
    # Rathole backend  
    server rathole 127.0.0.1:$((PORT + 2)) check port $((PORT + 2)) inter 5s fall 3 rise 2

# Health check endpoint
listen health_check
    bind *:8081
    mode http
    monitor-uri /health
    option httplog
EOF

    log green "✅ HAProxy configuration created"
}

# =============================================================================
# Network Optimization
# =============================================================================

optimize_network() {
    log purple "⚡ Applying Network Optimizations"
    echo
    
    log cyan "Optimizing kernel parameters..."
    
    # Create sysctl configuration
    cat > /etc/sysctl.d/99-mvtunnel.conf << 'EOF'
# MVTunnel Network Optimizations

# TCP/UDP Buffer Sizes
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216

# TCP Optimizations
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0

# Network Performance
net.core.netdev_max_backlog = 5000
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0

# Security
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.send_redirects = 0
EOF

    sysctl -p /etc/sysctl.d/99-mvtunnel.conf >/dev/null 2>&1
    
    log green "Network optimization applied successfully!"
    echo
    log cyan "Applied optimizations:"
    echo "  • Increased TCP/UDP buffer sizes"
    echo "  • Enabled BBR congestion control"
    echo "  • Optimized network queues"
    echo "  • Enhanced tunnel performance"
    echo
}

# =============================================================================
# Log Management
# =============================================================================

view_logs() {
    clear
    log purple "📝 MVTunnel Logs"
    echo
    
    echo "Available logs:"
    echo "1) MVTunnel main log"
    echo "2) EasyTier log"
    echo "3) Rathole log"
    echo "4) Live tail all logs"
    echo
    
    read -p "Select log [1-4]: " log_choice
    
    case $log_choice in
        1)
            if [[ -f "$LOG_DIR/mvtunnel.log" ]]; then
                tail -50 "$LOG_DIR/mvtunnel.log"
            else
                log yellow "No MVTunnel log found"
            fi
            ;;
        2)
            if [[ -f "$LOG_DIR/easytier.log" ]]; then
                tail -50 "$LOG_DIR/easytier.log"
            else
                log yellow "No EasyTier log found"
            fi
            ;;
        3)
            if [[ -f "$LOG_DIR/rathole.log" ]]; then
                tail -50 "$LOG_DIR/rathole.log"
            else
                log yellow "No Rathole log found"
            fi
            ;;
        4)
            log cyan "Live tailing logs (Ctrl+C to exit)..."
            tail -f "$LOG_DIR"/*.log 2>/dev/null || log yellow "No logs to tail"
            ;;
        *)
            log red "Invalid option"
            ;;
    esac
    
    echo
    press_key
}

# =============================================================================
# Daemon Mode Functions
# =============================================================================

run_daemon_mode() {
    log cyan "Starting MVTunnel in daemon mode..."
    
    # Create PID file
    echo $$ > "$CONFIG_DIR/mvtunnel.pid"
    
    # Setup signal handlers
    trap 'daemon_cleanup' TERM INT
    trap 'daemon_reload' HUP
    
    # Load configuration
    if [[ ! -f "$MAIN_CONFIG" ]]; then
        log red "No configuration found. Run: mv setup first"
        exit 1
    fi
    
    source "$MAIN_CONFIG"
    
    # Start tunnel
    log cyan "Starting tunnel in daemon mode..."
    connect_tunnel
    
    # Keep daemon running and monitor
    while true; do
        sleep 10
        
        # Check if tunnel is still running
        case "$TUNNEL_MODE" in
            "easytier")
                if ! pgrep -f "easytier-core" > /dev/null; then
                    log yellow "EasyTier process died, restarting..."
                    start_easytier
                fi
                ;;
            "rathole")
                if ! pgrep -f "rathole" > /dev/null; then
                    log yellow "Rathole process died, restarting..."
                    start_rathole
                fi
                ;;
            "hybrid")
                if ! pgrep -f "easytier-core\|rathole" > /dev/null; then
                    log yellow "All tunnel processes died, restarting..."
                    start_hybrid_mode
                fi
                ;;
        esac
    done
}

daemon_cleanup() {
    log cyan "Daemon received shutdown signal..."
    stop_tunnel
    network_cleanup
    rm -f "$CONFIG_DIR/mvtunnel.pid"
    exit 0
}

daemon_reload() {
    log cyan "Daemon received reload signal..."
    source "$MAIN_CONFIG"
    restart_tunnel
}

# =============================================================================
# Main Command Router
# =============================================================================

main() {
    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    
    case "${1:-menu}" in
        "--install"|"install")
            install_mvtunnel
            ;;
        "--auto"|"auto")
            install_mvtunnel "auto"
            ;;
        "setup")
            check_root
            setup_tunnel
            ;;
        "install-cores")
            check_root
            manage_tunnel_cores
            ;;
        "connect"|"start")
            check_root
            connect_tunnel
            ;;
        "status")
            show_status
            ;;
        "monitor")
            live_monitor
            ;;
        "stop")
            check_root
            stop_tunnel
            ;;
        "restart")
            check_root
            restart_tunnel
            ;;
        "switch")
            check_root
            switch_protocol
            ;;
        "optimize")
            check_root
            optimize_network
            ;;
        "haproxy")
            check_root
            setup_haproxy_integration
            ;;
        "logs")
            view_logs
            ;;
        "backup")
            backup_configuration
            ;;
        "restore")
            restore_configuration
            ;;
        "daemon-mode")
            check_root
            run_daemon_mode
            ;;
        "version")
            echo "MVTunnel v${MVTUNNEL_VERSION}"
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        "menu")
            if [[ $EUID -eq 0 ]]; then
                # Interactive menu mode
                while true; do
                    show_menu
                    echo -n "Select option [0-12]: "
                    read choice
                    
                    case $choice in
                        1) setup_tunnel ;;
                        2) manage_tunnel_cores ;;
                        3) connect_tunnel ;;
                        4) show_status; press_key ;;
                        5) live_monitor ;;
                        6) switch_protocol ;;
                        7) stop_tunnel; press_key ;;
                        8) restart_tunnel; press_key ;;
                        9) optimize_network; press_key ;;
                        10) view_logs ;;
                        11) backup_configuration; press_key ;;
                        12) restore_configuration; press_key ;;
                        0) log green "👋 Goodbye!"; exit 0 ;;
                        *) log red "Invalid option"; sleep 1 ;;
                    esac
                done
            else
                log red "Interactive menu requires root access. Use: sudo mv"
                show_help
            fi
            ;;
        *)
            show_help
            ;;
    esac
}

# Execute main function with all arguments
main "$@" 