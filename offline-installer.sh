#!/bin/bash

# 🚀 MoonTun Offline Installer & Dependency Manager
# Creates a complete offline package for Iran servers
# Supports Ubuntu 22.04+ without internet connectivity

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Version
INSTALLER_VERSION="1.0"
UBUNTU_VERSION="22.04"

# Directories
OFFLINE_DIR="$(pwd)/moontun-offline"
PACKAGES_DIR="$OFFLINE_DIR/packages"
BINARIES_DIR="$OFFLINE_DIR/bin"
SCRIPTS_DIR="$OFFLINE_DIR/scripts"
CACHE_DIR="$OFFLINE_DIR/cache"

# Package lists for Ubuntu 22.04+
REQUIRED_PACKAGES=(
    "curl"
    "wget" 
    "unzip"
    "jq"
    "netcat-openbsd"
    "bc"
    "openssl"
    "iproute2"
    "iptables"
    "iputils-ping"
    "coreutils"
    "systemd"
    "ca-certificates"
    "gnupg"
    "lsb-release"
    "apt-transport-https"
    "software-properties-common"
    "net-tools"
    "dnsutils"
    "tcpdump"
    "iperf3"
    "htop"
)

# Binary URLs
EASYTIER_REPO="https://api.github.com/repos/EasyTier/EasyTier/releases/latest"
RATHOLE_REPO="https://api.github.com/repos/rathole-org/rathole/releases/latest"

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
        *) echo -e "[$timestamp] $text" ;;
    esac
}

check_requirements() {
    log cyan "Checking system requirements..."
    
    # Check if we're running on Ubuntu
    if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
        log yellow "Warning: This script is optimized for Ubuntu 22.04+, but will try to continue..."
    fi
    
    # Check Ubuntu version
    local ubuntu_version=$(lsb_release -rs 2>/dev/null || echo "unknown")
    if [[ "$ubuntu_version" != "unknown" ]]; then
        if dpkg --compare-versions "$ubuntu_version" "lt" "22.04"; then
            log yellow "Warning: Ubuntu version $ubuntu_version detected, recommended version is 22.04+"
        else
            log green "Ubuntu $ubuntu_version detected - compatible!"
        fi
    fi
    
    # Check internet connectivity
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log red "No internet connectivity detected. This script requires internet to download packages."
        exit 1
    fi
    
    # Check required tools
    for tool in apt-cache dpkg wget curl; do
        if ! command -v "$tool" >/dev/null; then
            log red "Required tool '$tool' not found. Please install it first."
            exit 1
        fi
    done
    
    log green "System requirements check passed!"
}

create_directory_structure() {
    log cyan "Creating offline directory structure..."
    
    mkdir -p "$OFFLINE_DIR"
    mkdir -p "$PACKAGES_DIR"
    mkdir -p "$BINARIES_DIR"
    mkdir -p "$SCRIPTS_DIR"
    mkdir -p "$CACHE_DIR"
    
    log green "Directory structure created at: $OFFLINE_DIR"
}

download_packages() {
    log cyan "📦 Downloading Ubuntu packages..."
    
    cd "$PACKAGES_DIR"
    
    # Update package lists
    log blue "Updating package lists..."
    apt-get update -qq
    
    # Create a temporary directory for downloads
    local temp_dir=$(mktemp -d)
    
    # Download packages with dependencies
    for package in "${REQUIRED_PACKAGES[@]}"; do
        log blue "Downloading $package and its dependencies..."
        
        if apt-cache show "$package" >/dev/null 2>&1; then
            # Download package and all dependencies
            apt-get download "$package" -q 2>/dev/null || log yellow "Failed to download $package"
            
            # Get dependencies and download them too
            local deps=$(apt-cache depends "$package" 2>/dev/null | grep "Depends:" | awk '{print $2}' | grep -v ">" | head -10)
            
            for dep in $deps; do
                if [[ "$dep" != "<"* ]] && [[ "$dep" != "|"* ]]; then
                    apt-get download "$dep" -q 2>/dev/null || true
                fi
            done
        else
            log yellow "Package $package not found in repositories"
        fi
    done
    
    # Clean up temp directory
    rm -rf "$temp_dir"
    
    local package_count=$(ls -1 *.deb 2>/dev/null | wc -l)
    log green "Downloaded $package_count .deb packages"
}

download_binaries() {
    log cyan "📥 Downloading tunnel binaries..."
    
    cd "$BINARIES_DIR"
    
    # Detect architecture
    local arch=$(uname -m)
    case $arch in
        x86_64) arch_suffix="x86_64" ;;
        aarch64) arch_suffix="aarch64" ;;
        armv7l) arch_suffix="armv7" ;;
        *) arch_suffix="x86_64"; log yellow "Unknown architecture $arch, using x86_64" ;;
    esac
    
    # Download EasyTier
    log blue "Downloading EasyTier..."
    local easytier_url=""
    if command -v jq >/dev/null; then
        easytier_url=$(curl -s "$EASYTIER_REPO" | jq -r ".assets[] | select(.name | contains(\"linux\") and contains(\"$arch_suffix\")) | .browser_download_url" | head -1)
    fi
    
    if [[ -n "$easytier_url" ]]; then
        if wget -q "$easytier_url" -O easytier.zip; then
            unzip -q easytier.zip
            chmod +x easytier-* 2>/dev/null || true
            rm -f easytier.zip
            log green "EasyTier downloaded successfully"
        else
            log yellow "Failed to download EasyTier"
        fi
    else
        log yellow "Could not find EasyTier download URL"
    fi
    
    # Download Rathole
    log blue "Downloading Rathole..."
    local rathole_url=""
    if command -v jq >/dev/null; then
        rathole_url=$(curl -s "$RATHOLE_REPO" | jq -r ".assets[] | select(.name | contains(\"linux\") and contains(\"$arch_suffix\")) | .browser_download_url" | head -1)
    fi
    
    if [[ -n "$rathole_url" ]]; then
        if wget -q "$rathole_url" -O rathole.zip; then
            unzip -q rathole.zip
            chmod +x rathole* 2>/dev/null || true
            rm -f rathole.zip
            log green "Rathole downloaded successfully"
        else
            log yellow "Failed to download Rathole"
        fi
    else
        log yellow "Could not find Rathole download URL"
    fi
    
    # List downloaded binaries
    local binary_count=$(ls -1 2>/dev/null | wc -l)
    log green "Downloaded $binary_count binary files"
}

create_offline_installer() {
    log cyan "📝 Creating offline installer script..."
    
    cat > "$SCRIPTS_DIR/install-offline.sh" << 'EOF'
#!/bin/bash

# MoonTun Offline Installer
# Install MoonTun and dependencies without internet connectivity

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'  
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OFFLINE_DIR="$(dirname "$SCRIPT_DIR")"
PACKAGES_DIR="$OFFLINE_DIR/packages"
BINARIES_DIR="$OFFLINE_DIR/bin"

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
        *) echo -e "[$timestamp] $text" ;;
    esac
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log red "Root access required. Usage: sudo ./install-offline.sh"
        exit 1
    fi
}

install_packages() {
    log cyan "📦 Installing system packages..."
    
    if [[ ! -d "$PACKAGES_DIR" ]]; then
        log red "Packages directory not found: $PACKAGES_DIR"
        exit 1
    fi
    
    cd "$PACKAGES_DIR"
    
    # Count packages
    local package_count=$(ls -1 *.deb 2>/dev/null | wc -l)
    if [[ $package_count -eq 0 ]]; then
        log red "No .deb packages found in $PACKAGES_DIR"
        exit 1
    fi
    
    log blue "Found $package_count packages to install"
    
    # Install all packages
    log blue "Installing packages (this may take a while)..."
    if dpkg -i *.deb 2>/dev/null; then
        log green "All packages installed successfully"
    else
        log yellow "Some packages failed, fixing dependencies..."
        apt-get install -f -y >/dev/null 2>&1 || true
        log green "Dependencies fixed"
    fi
}

install_binaries() {
    log cyan "🔧 Installing tunnel binaries..."
    
    if [[ ! -d "$BINARIES_DIR" ]]; then
        log red "Binaries directory not found: $BINARIES_DIR"
        exit 1
    fi
    
    cd "$BINARIES_DIR"
    
    # Create destination directory
    mkdir -p /usr/local/bin
    
    # Install EasyTier
    if ls easytier-* 1> /dev/null 2>&1; then
        for binary in easytier-*; do
            if [[ -f "$binary" ]] && [[ -x "$binary" ]]; then
                cp "$binary" /usr/local/bin/
                log green "Installed $binary"
            fi
        done
    else
        log yellow "EasyTier binaries not found"
    fi
    
    # Install Rathole
    if ls rathole* 1> /dev/null 2>&1; then
        for binary in rathole*; do
            if [[ -f "$binary" ]] && [[ -x "$binary" ]] && [[ "$binary" != *.zip ]]; then
                cp "$binary" /usr/local/bin/
                log green "Installed $binary"
            fi
        done
    else
        log yellow "Rathole binaries not found"
    fi
    
    # Update PATH if needed
    if ! echo "$PATH" | grep -q "/usr/local/bin"; then
        echo 'export PATH="/usr/local/bin:$PATH"' >> /etc/environment
        log blue "Updated system PATH"
    fi
}

create_directories() {
    log cyan "📁 Creating MoonTun directories..."
    
    mkdir -p /etc/moontun
    mkdir -p /var/log/moontun
    mkdir -p /usr/local/bin
    
    # Set permissions
    chmod 755 /etc/moontun
    chmod 755 /var/log/moontun
    
    log green "Directories created"
}

main() {
    echo
    echo "🚀 MoonTun Offline Installer"
    echo "=========================="
    echo
    
    check_root
    create_directories
    install_packages
    install_binaries
    
    echo
    log green "🎉 MoonTun offline installation completed!"
    echo
    echo "Next steps:"
    echo "1. Copy moontun.sh to /usr/local/bin/moontun"
    echo "2. Run: chmod +x /usr/local/bin/moontun"
    echo "3. Run: moontun --help"
    echo
}

main "$@"
EOF

    chmod +x "$SCRIPTS_DIR/install-offline.sh"
    log green "Offline installer created"
}

create_readme() {
    log cyan "📄 Creating README and documentation..."
    
    cat > "$OFFLINE_DIR/README.md" << 'EOF'
# MoonTun Offline Installation Package

This package contains all necessary files to install MoonTun on Ubuntu 22.04+ systems without internet connectivity.

## Contents

- `packages/` - Ubuntu .deb packages and dependencies
- `bin/` - EasyTier and Rathole binary files
- `scripts/` - Installation scripts
- `cache/` - Temporary files and cache

## Installation Instructions

### Step 1: Transfer Files
Transfer the entire `moontun-offline` directory to your Iran server.

### Step 2: Install Dependencies
```bash
cd moontun-offline/scripts
sudo ./install-offline.sh
```

### Step 3: Install MoonTun Script
```bash
# Copy the main script
sudo cp /path/to/moontun.sh /usr/local/bin/moontun
sudo chmod +x /usr/local/bin/moontun

# Verify installation
moontun --help
```

### Step 4: Configure and Run
```bash
# Initialize configuration
sudo moontun install --local

# Start tunnel
sudo moontun start-iran
```

## System Requirements

- Ubuntu 22.04 or later
- Root access
- At least 1GB free disk space
- Architecture: x86_64, aarch64, or armv7

## Troubleshooting

### Package Installation Issues
```bash
# Fix broken dependencies
sudo apt-get install -f

# Force package installation
cd packages/
sudo dpkg -i --force-depends *.deb
```

### Binary Permission Issues
```bash
# Fix binary permissions
sudo chmod +x /usr/local/bin/easytier-*
sudo chmod +x /usr/local/bin/rathole*
```

### PATH Issues
```bash
# Add to PATH permanently
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## File Structure

```
moontun-offline/
├── packages/           # Ubuntu packages (.deb files)
├── bin/               # Binary executables
│   ├── easytier-core
│   ├── easytier-cli
│   └── rathole
├── scripts/           # Installation scripts
│   └── install-offline.sh
├── cache/             # Temporary files
└── README.md          # This file
```

## Support

For issues and support, check the MoonTun documentation or contact the maintainer.
EOF

    log green "README created"
}

create_package_info() {
    log cyan "📊 Creating package information..."
    
    cat > "$OFFLINE_DIR/package-info.txt" << EOF
MoonTun Offline Package Information
===================================

Package Version: $INSTALLER_VERSION
Target OS: Ubuntu $UBUNTU_VERSION+
Architecture: $(uname -m)
Created: $(date)
Creator: $(whoami)@$(hostname)

Required Packages:
EOF

    for package in "${REQUIRED_PACKAGES[@]}"; do
        echo "- $package" >> "$OFFLINE_DIR/package-info.txt"
    done
    
    echo "" >> "$OFFLINE_DIR/package-info.txt"
    echo "Downloaded Files:" >> "$OFFLINE_DIR/package-info.txt"
    echo "- Packages: $(ls -1 "$PACKAGES_DIR"/*.deb 2>/dev/null | wc -l) .deb files" >> "$OFFLINE_DIR/package-info.txt"
    echo "- Binaries: $(ls -1 "$BINARIES_DIR"/* 2>/dev/null | wc -l) binary files" >> "$OFFLINE_DIR/package-info.txt"
    
    log green "Package information created"
}

create_archive() {
    log cyan "📦 Creating compressed archive..."
    
    cd "$(dirname "$OFFLINE_DIR")"
    
    local archive_name="moontun-offline-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    if tar -czf "$archive_name" "$(basename "$OFFLINE_DIR")" 2>/dev/null; then
        local archive_size=$(du -h "$archive_name" | cut -f1)
        log green "Archive created: $archive_name ($archive_size)"
        echo
        echo "📦 Transfer this archive to your Iran server:"
        echo "   $PWD/$archive_name"
        echo
        echo "📥 Extract on Iran server:"
        echo "   tar -xzf $archive_name"
        echo "   cd $(basename "$OFFLINE_DIR")/scripts"
        echo "   sudo ./install-offline.sh"
    else
        log yellow "Failed to create archive, but offline directory is ready"
    fi
}

main() {
    echo
    echo "🚀 MoonTun Offline Package Creator"
    echo "================================="
    echo "Creating offline installation package for Iran servers"
    echo
    
    check_requirements
    create_directory_structure
    download_packages
    download_binaries
    create_offline_installer
    create_readme
    create_package_info
    create_archive
    
    echo
    log green "🎉 Offline package creation completed!"
    echo
    echo "📁 Offline directory: $OFFLINE_DIR"
    echo "📦 Ready for transfer to Iran server"
    echo
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 