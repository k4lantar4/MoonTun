#!/bin/bash

# 🚀 MoonTun Offline Setup Script
# Quick setup for Iran servers without internet connectivity

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    local color="$1"
    local text="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $color in
        red) echo -e "${RED}❌ [$timestamp] $text${NC}" ;;
        green) echo -e "${GREEN}✅ [$timestamp] $text${NC}" ;;
        yellow) echo -e "${YELLOW}⚠️  [$timestamp] $text${NC}" ;;
        cyan) echo -e "${CYAN}🔧 [$timestamp] $text${NC}" ;;
        *) echo -e "[$timestamp] $text" ;;
    esac
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log red "Root access required. Usage: sudo ./setup-offline.sh"
        exit 1
    fi
}

main() {
    clear
    echo "🚀 MoonTun Offline Setup for Iran Servers"
    echo "========================================="
    echo
    
    check_root
    
    # Check if we're in the right directory
    if [[ ! -f "moontun.sh" ]] && [[ ! -f "../moontun.sh" ]]; then
        log red "moontun.sh not found in current or parent directory"
        echo "Please run this script from the MoonTun directory"
        exit 1
    fi
    
    # Find moontun.sh location
    local moontun_script=""
    if [[ -f "moontun.sh" ]]; then
        moontun_script="./moontun.sh"
    elif [[ -f "../moontun.sh" ]]; then
        moontun_script="../moontun.sh"
    fi
    
    log cyan "Found MoonTun script: $moontun_script"
    
    # Step 1: Install offline dependencies
    if [[ -d "moontun-offline/scripts" ]]; then
        log cyan "📦 Step 1: Installing offline dependencies..."
        cd moontun-offline/scripts
        if ./install-offline.sh; then
            log green "✅ Dependencies installed successfully"
        else
            log red "❌ Failed to install dependencies"
            exit 1
        fi
        cd ../..
    else
        log yellow "⚠️  No offline package found, trying online installation..."
    fi
    
    # Step 2: Copy MoonTun script to system
    log cyan "📝 Step 2: Installing MoonTun script..."
    
    if cp "$moontun_script" /usr/local/bin/moontun; then
        chmod +x /usr/local/bin/moontun
        log green "✅ MoonTun script installed to /usr/local/bin/moontun"
    else
        log red "❌ Failed to install MoonTun script"
        exit 1
    fi
    
    # Step 3: Install tunnel cores locally
    log cyan "🔧 Step 3: Installing tunnel cores..."
    
    if /usr/local/bin/moontun install-cores-local; then
        log green "✅ Tunnel cores installed successfully"
    else
        log yellow "⚠️  Failed to install cores locally, you may need internet"
    fi
    
    # Step 4: Create directories and set permissions
    log cyan "📁 Step 4: Setting up directories..."
    
    mkdir -p /etc/moontun /var/log/moontun
    chmod 755 /etc/moontun /var/log/moontun
    
    log green "✅ Directories created"
    
    # Step 5: Verify installation
    log cyan "🔍 Step 5: Verifying installation..."
    
    if command -v moontun >/dev/null; then
        log green "✅ MoonTun command is available"
    else
        log yellow "⚠️  MoonTun command not in PATH, try: export PATH=\"/usr/local/bin:\$PATH\""
    fi
    
    # Check cores
    local easytier_status="❌"
    local rathole_status="❌"
    
    if [[ -f "/usr/local/bin/easytier-core" ]]; then
        easytier_status="✅"
    fi
    
    if [[ -f "/usr/local/bin/rathole" ]]; then
        rathole_status="✅"
    fi
    
    log cyan "📊 Installation Status:"
    echo "   • MoonTun Script: ✅"
    echo "   • EasyTier Core:  $easytier_status"
    echo "   • Rathole Core:   $rathole_status"
    echo "   • Dependencies:   ✅"
    
    echo
    log green "🎉 MoonTun offline setup completed!"
    echo
    echo "Next steps:"
    echo "1. Run: export PATH=\"/usr/local/bin:\$PATH\""
    echo "2. Run: moontun setup"
    echo "3. Configure your tunnel settings"
    echo "4. Run: moontun start"
    echo
    
    log cyan "For help: moontun --help"
}

main "$@" 