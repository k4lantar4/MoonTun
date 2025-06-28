# 📦 MVTunnel Installation Guide

Complete installation guide for MVTunnel on various Linux distributions.

## 🔧 System Requirements

### Minimum Requirements
- **OS**: Linux (Ubuntu 18+, CentOS 7+, Debian 9+)
- **Architecture**: x86_64, aarch64, armv7l
- **RAM**: 256MB available memory
- **Storage**: 100MB free space
- **Network**: Internet connection for installation
- **Privileges**: Root access

### Recommended Requirements
- **RAM**: 512MB+ for better performance
- **Storage**: 500MB+ for logs and backups
- **Network**: Stable internet connection

## 🚀 Quick Installation

### One-Line Install (Recommended)
```bash
curl -fsSL https://github.com/k4lantar4/mvtunnel/raw/main/mvtunnel.sh | sudo bash -s -- --install
```

### Alternative with wget
```bash
wget -qO- https://github.com/k4lantar4/mvtunnel/raw/main/mvtunnel.sh | sudo bash -s -- --install
```

## 📋 Manual Installation

### 1. Download Script
```bash
# Using curl
curl -fsSL https://github.com/k4lantar4/mvtunnel/raw/main/mvtunnel.sh -o mvtunnel.sh

# Or using wget  
wget https://github.com/k4lantar4/mvtunnel/raw/main/mvtunnel.sh
```

### 2. Make Executable
```bash
chmod +x mvtunnel.sh
```

### 3. Run Installation
```bash
sudo ./mvtunnel.sh --install
```

## 🎯 Distribution-Specific Instructions

### Ubuntu/Debian
```bash
# Update package list
sudo apt update

# Install dependencies
sudo apt install -y curl wget unzip jq netcat-openbsd

# Install MVTunnel
curl -fsSL https://github.com/k4lantar4/mvtunnel/raw/main/mvtunnel.sh | sudo bash -s -- --install
```

### CentOS/RHEL
```bash
# Install dependencies
sudo yum install -y curl wget unzip jq nc

# Install MVTunnel
curl -fsSL https://github.com/k4lantar4/mvtunnel/raw/main/mvtunnel.sh | sudo bash -s -- --install
```

### Fedora
```bash
# Install dependencies
sudo dnf install -y curl wget unzip jq nc

# Install MVTunnel
curl -fsSL https://github.com/k4lantar4/mvtunnel/raw/main/mvtunnel.sh | sudo bash -s -- --install
```

### Alpine Linux
```bash
# Install dependencies
sudo apk add curl wget unzip jq netcat-openbsd bash

# Install MVTunnel
curl -fsSL https://github.com/k4lantar4/mvtunnel/raw/main/mvtunnel.sh | sudo bash -s -- --install
```

## 🔧 Post-Installation Setup

### 1. Verify Installation
```bash
# Check if command is available
which mv

# Check version
sudo mv version

# Check status
sudo mv status
```

### 2. Install Tunnel Cores
```bash
# Install both EasyTier and Rathole cores
sudo mv install-cores
```

### 3. Configure Tunnel
```bash
# Interactive setup
sudo mv setup
```

### 4. Start Tunnel
```bash
# Connect tunnel
sudo mv connect

# Check status
sudo mv status
```

## 🗂️ Installation Directory Structure

```
/usr/local/bin/
├── mv                      # Main MVTunnel command

/etc/mvtunnel/
├── mvtunnel.conf          # Main configuration
├── easytier.json          # EasyTier config
├── rathole.toml           # Rathole config
├── monitor.conf           # Monitoring config
├── tunnel_status          # Status file
└── backups/               # Configuration backups

/var/log/mvtunnel/
├── mvtunnel.log          # Main log file
├── easytier.log          # EasyTier logs
└── rathole.log           # Rathole logs

/etc/systemd/system/
└── mvtunnel.service      # Systemd service
```

## 🔄 Offline Installation

### 1. Download Dependencies
```bash
# On a machine with internet access
wget https://github.com/k4lantar4/mvtunnel/archive/main.zip
unzip main.zip
cd mvtunnel-main
```

### 2. Transfer to Target Machine
```bash
# Copy entire directory to target machine
scp -r mvtunnel-main/ user@target-server:/tmp/
```

### 3. Install from Local Files
```bash
# On target machine
cd /tmp/mvtunnel-main
sudo ./mvtunnel.sh --install
sudo mv install-cores
# Select option 3: Local Files
# Point to binaries/x86_64/ directory
```

## 🔧 Advanced Installation Options

### Custom Installation Directory
```bash
# Set custom installation directory
export DEST_DIR="/opt/mvtunnel/bin"
sudo ./mvtunnel.sh --install
```

### Silent Installation
```bash
# Install without prompts
sudo ./mvtunnel.sh --auto
```

### Development Installation
```bash
# Install from specific branch
curl -fsSL https://github.com/k4lantar4/mvtunnel/raw/dev/mvtunnel.sh | sudo bash -s -- --install
```

## 🛠️ Troubleshooting Installation

### Common Issues

#### Permission Denied
```bash
# Ensure script is executable
chmod +x mvtunnel.sh

# Run with sudo
sudo ./mvtunnel.sh --install
```

#### Missing Dependencies
```bash
# Ubuntu/Debian
sudo apt install -y curl wget unzip jq netcat-openbsd

# CentOS/RHEL
sudo yum install -y curl wget unzip jq nc
```

#### Network Issues
```bash
# Test connectivity
curl -I https://github.com

# Use alternative download method
wget --no-check-certificate https://github.com/k4lantar4/mvtunnel/raw/main/mvtunnel.sh
```

#### Space Issues
```bash
# Check available space
df -h

# Clean system
sudo apt autoremove  # Ubuntu/Debian
sudo yum clean all   # CentOS/RHEL
```

### Installation Logs
```bash
# Check installation logs
sudo journalctl -f | grep mvtunnel

# Check system logs
tail -f /var/log/syslog | grep mvtunnel
```

## 🔄 Updating MVTunnel

### Update Script
```bash
# Download latest version
curl -fsSL https://github.com/k4lantar4/mvtunnel/raw/main/mvtunnel.sh -o mvtunnel.sh

# Update installation
sudo ./mvtunnel.sh --install
```

### Update Cores Only
```bash
# Update tunnel cores
sudo mv install-cores
# Select update option
```

## 🗑️ Uninstallation

### Complete Removal
```bash
# Stop services
sudo mv stop

# Remove systemd service
sudo systemctl disable mvtunnel
sudo rm /etc/systemd/system/mvtunnel.service

# Remove files
sudo rm -rf /etc/mvtunnel
sudo rm -rf /var/log/mvtunnel
sudo rm /usr/local/bin/mv

# Clean up
sudo systemctl daemon-reload
```

### Keep Configuration
```bash
# Remove binaries only, keep configs
sudo rm /usr/local/bin/mv
sudo systemctl disable mvtunnel
sudo rm /etc/systemd/system/mvtunnel.service
```

## 📞 Getting Help

If you encounter issues during installation:

1. **Check Requirements**: Ensure your system meets minimum requirements
2. **Check Logs**: Review installation and system logs
3. **Network**: Verify internet connectivity
4. **Permissions**: Ensure you're running with root privileges
5. **GitHub Issues**: Report bugs at [GitHub Issues](https://github.com/k4lantar4/mvtunnel/issues) 