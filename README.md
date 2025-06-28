# 🚀 MVTunnel - Intelligent Dual-Core Tunnel System

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub release](https://img.shields.io/github/release/k4lantar4/mvtunnel.svg)](https://github.com/k4lantar4/mvtunnel/releases)
[![Bash](https://img.shields.io/badge/Language-Bash-green.svg)](https://www.gnu.org/software/bash/)

**MVTunnel** is an intelligent dual-core tunnel system that combines **EasyTier** + **Rathole** with smart failover and protocol switching capabilities. Designed specifically for Iran-Foreign server tunneling with enterprise-grade stability.

## ✨ Features

🔥 **Dual-Core Architecture**
- **EasyTier Core**: Modern P2P mesh VPN with WireGuard-like performance
- **Rathole Core**: High-performance TCP/UDP tunnel with NAT traversal
- **Intelligent Failover**: Automatic switching between cores on failure

⚡ **Smart Protocol Switching**
- UDP, TCP, WebSocket, QUIC protocols support
- Automatic protocol detection and switching
- Iran network condition optimization

🛡️ **Enterprise-Grade Reliability**
- Real-time health monitoring
- Automatic recovery mechanisms
- Support for 1000+ concurrent users (3x-ui compatible)

🔧 **Easy Management**
- One-line installation
- Interactive setup wizard
- Command-line interface
- Web dashboard support

## 📦 Quick Installation

### One-Line Install
```bash
curl -fsSL https://github.com/k4lantar4/mvtunnel/raw/main/mvtunnel.sh | sudo bash -s -- --install
```

### Manual Installation
```bash
# Download script
wget https://github.com/k4lantar4/mvtunnel/raw/main/mvtunnel.sh

# Make executable
chmod +x mvtunnel.sh

# Install
sudo ./mvtunnel.sh --install
```

## 🚀 Quick Start

### 1. Setup Tunnel
```bash
sudo mv setup
```

### 2. Install Tunnel Cores
```bash
sudo mv install-cores
```

### 3. Connect
```bash
sudo mv connect
```

### 4. Monitor Status
```bash
sudo mv status
sudo mv monitor
```

## 📋 Available Commands

| Command | Description |
|---------|-------------|
| `sudo mv setup` | Interactive tunnel configuration |
| `sudo mv install-cores` | Manage tunnel cores (EasyTier/Rathole) |
| `sudo mv connect` | Connect tunnel with current config |
| `sudo mv status` | Show system and tunnel status |
| `sudo mv monitor` | Live monitoring dashboard |
| `sudo mv stop` | Stop all tunnel processes |
| `sudo mv restart` | Restart tunnel services |
| `sudo mv switch` | Switch between protocols |
| `sudo mv optimize` | Apply network optimizations |
| `sudo mv haproxy` | Setup HAProxy load balancing |
| `sudo mv logs` | View system logs |
| `sudo mv backup` | Create configuration backup |
| `sudo mv restore` | Restore configuration from backup |
| `sudo mv help` | Show help message |

## 🔧 Configuration Examples

### EasyTier Master Node (Foreign Server)
```bash
sudo mv setup
# Select: EasyTier mode
# Select: Master node (0.0.0.0 - No peers needed)
# Local IP: 10.10.10.1
# Protocol: UDP/TCP/WebSocket
```

### EasyTier Client Node (Iran Server)
```bash
sudo mv setup
# Select: EasyTier mode  
# Select: Client node
# Local IP: 10.10.10.2
# Remote server: YOUR_FOREIGN_SERVER_IP
# Protocol: UDP/TCP/WebSocket
```

### Rathole Server (Foreign Server)
```bash
sudo mv setup
# Select: Rathole mode
# Select: Server (receives connections)
# Configure ports and protocols
```

### Rathole Client (Iran Server)
```bash
sudo mv setup
# Select: Rathole mode
# Select: Client (connects to foreign)
# Remote server: YOUR_FOREIGN_SERVER_IP
```

## 📂 Project Structure

```
mvtunnel/
├── mvtunnel.sh           # Main script
├── binaries/             # Prebuilt binaries
│   ├── x86_64/          # Core files for x86_64
│   │   ├── easytier-core
│   │   ├── easytier-cli
│   │   └── rathole
│   └── amd64/           # GUI versions
│       ├── easytier-gui-amd64.AppImage
│       └── easytier-gui-amd64.deb
├── configs/             # Configuration examples
└── docs/               # Documentation
```

## 🔄 Tunnel Modes

### 1. EasyTier Mode
- **Master/Client architecture**
- **P2P mesh networking**
- **WireGuard-like performance**
- **Best for**: Stable long-term connections

### 2. Rathole Mode
- **Server/Client architecture**
- **High-performance tunneling**
- **Advanced NAT traversal**
- **Best for**: High-throughput applications

### 3. Hybrid Mode
- **Automatic failover between cores**
- **Best of both worlds**
- **Maximum reliability**
- **Best for**: Mission-critical applications

## 🌐 Protocol Support

| Protocol | Description | Use Case |
|----------|-------------|----------|
| **UDP** | Fast, low-latency | Gaming, real-time apps |
| **TCP** | Reliable, ordered | Web traffic, file transfer |
| **WebSocket** | HTTP-compatible | Firewall traversal |
| **QUIC** | Modern, fast | Next-gen applications |
| **WireGuard** | Secure, efficient | VPN connections |

## 📊 Monitoring & Health Checks

- **Real-time latency monitoring**
- **Automatic health checks**
- **Process monitoring**
- **Network quality assessment**
- **Live dashboard**

```bash
# View live monitoring
sudo mv monitor

# Check detailed status
sudo mv status

# View logs
sudo mv logs
```

## 🛠️ Advanced Features

### HAProxy Integration
```bash
sudo mv haproxy
# Automatically sets up load balancing
# Statistics available at: http://server:8080/stats
```

### Network Optimization
```bash
sudo mv optimize
# Applies kernel-level optimizations
# TCP BBR congestion control
# Buffer size tuning
```

### Backup & Restore
```bash
# Create backup
sudo mv backup

# Restore from backup
sudo mv restore
```

## 🔍 Troubleshooting

### Check Status
```bash
sudo mv status
```

### View Logs
```bash
sudo mv logs
```

### Restart Services
```bash
sudo mv restart
```

### Test Connectivity
```bash
# Check if cores are installed
sudo mv install-cores

# Test tunnel connection
ping 10.10.10.1  # Replace with your tunnel IP
```

## 📋 Requirements

- **OS**: Linux (Ubuntu 18+, CentOS 7+, Debian 9+)
- **Architecture**: x86_64, aarch64, armv7l
- **Memory**: 256MB+ available
- **Network**: Internet connection for installation
- **Privileges**: Root access required

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **[EasyTier](https://github.com/EasyTier/EasyTier)** - Modern P2P mesh VPN
- **[Rathole](https://github.com/rathole-org/rathole)** - High-performance tunnel
- **Iran Network Optimization** - Special thanks to Iranian developers

## 📞 Support

- **GitHub Issues**: [Report bugs](https://github.com/k4lantar4/mvtunnel/issues)
- **Documentation**: [Wiki](https://github.com/k4lantar4/mvtunnel/wiki)
- **Discussions**: [GitHub Discussions](https://github.com/k4lantar4/mvtunnel/discussions)

---

<div align="center">

**Made with ❤️ for the Iranian tech community**

⭐ Star this repository if it helped you!

</div> 