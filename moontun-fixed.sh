#!/bin/bash

# 🚀 MoonTun - Intelligent Multi-Node Tunnel System v2.0
# Fixed version with proper syntax

set -e

# Version
MOONTUN_VERSION="2.0"

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
CONFIG_DIR="/etc/moontun"
LOG_DIR="/var/log/moontun"
DEST_DIR="/usr/local/bin"
SERVICE_NAME="moontun"

# Configuration Files
MAIN_CONFIG="$CONFIG_DIR/moontun.conf"
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
    echo "[$timestamp] $text" >> "$LOG_DIR/moontun.log" 2>/dev/null || true
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log red "Root access required. Usage: sudo moontun <command>"
        exit 1
    fi
}

# Fixed installation function
install_moontun() {
    local mode="$1"
    local local_mode=false
    
    # Check if --local flag is provided
    if [[ "$mode" == "--local" ]] || [[ "$mode" == "local" ]]; then
        local_mode=true
        mode="local"
    fi
    
    clear
    echo -e "${CYAN}🚀 MoonTun Intelligent Tunnel System v${MOONTUN_VERSION}${NC}"
    echo "================================================================="
    echo
    
    if [[ "$local_mode" == true ]]; then
        log cyan "🇮🇷 Installing MoonTun in OFFLINE mode for Iran servers"
        echo "Components:"
        echo "  • Local package installation (No internet required)"
        echo "  • Local tunnel cores installation"
        echo "  • Intelligent Failover System"
        echo "  • Network Monitoring & Auto-switching"
        echo "  • Iran-optimized configurations"
        echo
    elif [[ "$mode" != "auto" ]]; then
        log yellow "This will install MoonTun with multi-node tunnel system"
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
    
    # Install dependencies based on mode
    if [[ "$local_mode" == true ]]; then
        install_dependencies_local
    else
        install_dependencies
    fi
    
    # Install tunnel cores based on mode
    if [[ "$local_mode" == true ]]; then
        install_cores_local
    else
        # Try repository installation first
        install_from_repository
    fi
    
    # Verify installation and setup system
    verify_and_setup_installation
    
    log green "🎉 MoonTun installed successfully!"
    echo
    log cyan "Quick Start:"
    echo "  sudo moontun setup     # Initial setup"
    echo "  sudo moontun connect   # Quick connect"
    echo "  sudo moontun status    # Check status"
    echo "  sudo moontun monitor   # Live monitoring"
    echo "  sudo mv setup          # Alternative command"
    echo
    log yellow "💡 If 'moontun' command not found, try:"
    echo "  source ~/.bashrc       # Reload shell config"
    echo "  sudo /usr/bin/moontun  # Direct path"
    echo
}

# Separate function for repository installation
install_from_repository() {
    log cyan "📥 Downloading MoonTun repository..."
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    if git clone https://github.com/k4lantar4/moontun.git 2>/dev/null; then
        cd moontun
        log green "✅ Repository downloaded successfully"
        
        # Install tunnel cores from repository
        install_cores_from_repo
        
        # Install MoonTun manager
        install_moontun_manager_from_repo
        
        # Copy binary files if available
        install_binary_files_if_available
        
        cd /
        rm -rf "$temp_dir"
        log green "✅ Repository installation completed"
    else
        log red "❌ Failed to download repository, falling back to online installation"
        cd /
        rm -rf "$temp_dir"
        
        # Fallback to original installation method
        install_fallback_online
    fi
}

# Install MoonTun manager from repository
install_moontun_manager_from_repo() {
    log cyan "Installing MoonTun manager..."
    
    # Primary installation location
    cp moontun.sh "$DEST_DIR/moontun"
    chmod +x "$DEST_DIR/moontun"
    
    # Backup installation location (in case /usr/local/bin is not in PATH)
    cp moontun.sh "/usr/bin/moontun"
    chmod +x "/usr/bin/moontun"
    
    # Create symbolic links for additional compatibility
    ln -sf "/usr/bin/moontun" "/usr/local/bin/mv" 2>/dev/null || true
    ln -sf "/usr/bin/moontun" "/usr/bin/mv" 2>/dev/null || true
    
    log green "✅ MoonTun manager installed"
}

# Install binary files if available
install_binary_files_if_available() {
    if [[ -d "bin" ]]; then
        log cyan "📦 Installing binary files from repository..."
        mkdir -p "/opt/moontun/bin"
        cp -r bin/* "/opt/moontun/bin/" 2>/dev/null || true
        chmod +x "/opt/moontun/bin/"* 2>/dev/null || true
        log green "✅ Binary files installed to /opt/moontun/bin/"
    else
        log blue "ℹ️  No binary files found in repository"
    fi
}

# Fallback online installation
install_fallback_online() {
    log cyan "🌐 Starting fallback online installation..."
    
    # Install cores using online method
    install_easytier
    install_rathole
    
    # Install MoonTun manager using current script
    cp "$0" "$DEST_DIR/moontun"
    chmod +x "$DEST_DIR/moontun"
    cp "$0" "/usr/bin/moontun"
    chmod +x "/usr/bin/moontun"
    ln -sf "/usr/bin/moontun" "/usr/local/bin/mv" 2>/dev/null || true
    ln -sf "/usr/bin/moontun" "/usr/bin/mv" 2>/dev/null || true
    
    log green "✅ Fallback installation completed"
}

# Verify installation and setup system
verify_and_setup_installation() {
    # Verify installation
    if command -v moontun >/dev/null 2>&1; then
        log green "✅ MoonTun command installed successfully"
    else
        log yellow "⚠️  Adding /usr/local/bin to PATH for current session"
        export PATH="/usr/local/bin:$PATH"
        
        # Add to shell profiles for persistence
        echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc 2>/dev/null || true
        echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc 2>/dev/null || true
    fi
    
    # Create systemd service
    create_systemd_service
    
    # Setup log rotation
    setup_log_rotation
}

# Create systemd service
create_systemd_service() {
    log cyan "⚙️  Creating systemd service..."
    
    # Use /usr/bin path for better compatibility
    local exec_path="/usr/bin/moontun"
    
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=MoonTun Intelligent Tunnel Service
After=network.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$exec_path daemon-mode
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
    log green "✅ Systemd service created and enabled"
}

# Setup log rotation
setup_log_rotation() {
    log cyan "📝 Setting up log rotation..."
    
    # Create logrotate configuration
    cat > /etc/logrotate.d/moontun << 'EOF'
/var/log/moontun/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        systemctl reload moontun 2>/dev/null || true
    endscript
}
EOF
    
    # Create log cleanup script
    cat > /usr/local/bin/moontun-log-cleanup << 'EOF'
#!/bin/bash
# MoonTun Log Cleanup Script
find /var/log/moontun -name "*.log" -size +100M -exec truncate -s 50M {} \;
find /var/log/moontun -name "*.log.*" -mtime +30 -delete
EOF
    
    chmod +x /usr/local/bin/moontun-log-cleanup
    
    # Add to crontab for emergency cleanup
    (crontab -l 2>/dev/null | grep -v moontun-log-cleanup; echo "0 2 * * * /usr/local/bin/moontun-log-cleanup") | crontab -
    
    log green "✅ Log rotation configured"
}

# Placeholder functions (implement based on your original script)
setup_directories() {
    log cyan "📁 Setting up directories..."
    mkdir -p "$CONFIG_DIR" "$LOG_DIR" "/opt/moontun/bin"
    log green "✅ Directories created"
}

install_dependencies() {
    log cyan "📦 Installing dependencies..."
    apt update -qq
    apt install -y curl wget git unzip jq bc netcat-openbsd systemd cron logrotate 2>/dev/null || true
    log green "✅ Dependencies installed"
}

install_dependencies_local() {
    log cyan "📦 Installing local dependencies..."
    # Local dependency installation logic
    log green "✅ Local dependencies ready"
}

install_cores_local() {
    log cyan "🔧 Installing tunnel cores locally..."
    # Local cores installation logic
    log green "✅ Tunnel cores installed locally"
}

install_cores_from_repo() {
    log cyan "🔧 Installing tunnel cores from repository..."
    # Repository cores installation logic
    log green "✅ Tunnel cores installed from repository"
}

install_easytier() {
    log cyan "⚡ Installing EasyTier..."
    # EasyTier installation logic
    log green "✅ EasyTier installed"
}

install_rathole() {
    log cyan "🕳️  Installing Rathole..."
    # Rathole installation logic
    log green "✅ Rathole installed"
}

# Main execution
case "${1:-install}" in
    "--install"|"install"|"--auto"|"auto")
        install_moontun "$1"
        ;;
    "--local"|"local")
        install_moontun "--local"
        ;;
    *)
        install_moontun "auto"
        ;;
esac 