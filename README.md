# 🚀 MoonTun - Intelligent Multi-Node Tunnel System

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub release](https://img.shields.io/github/release/k4lantar4/moontun.svg)](https://github.com/k4lantar4/moontun/releases)
[![Bash](https://img.shields.io/badge/Language-Bash-green.svg)](https://www.gnu.org/software/bash/)

**MoonTun** is an intelligent multi-node tunnel system that combines **EasyTier** + **Rathole** with smart failover, multi-peer connections, and intelligent protocol switching. Designed specifically for Iran-Foreign server tunneling with enterprise-grade stability and 2+ server support.

## ✨ Features

🔥 **Multi-Node Architecture**
- **EasyTier Core**: Modern P2P mesh VPN with WireGuard-like performance
- **Rathole Core**: High-performance TCP/UDP tunnel with NAT traversal
- **Multi-Peer Support**: Connect 2+ servers simultaneously
- **Intelligent Failover**: Automatic switching between cores and peers

⚡ **Smart Protocol Switching**
- UDP, TCP, WebSocket, QUIC, WireGuard protocols support
- 10-minute stability testing before switching
- Automatic protocol detection and switching
- Bidirectional connection support
- Iran network condition optimization

🛡️ **Enterprise-Grade Reliability**
- Real-time health monitoring
- Automatic recovery mechanisms
- Support for 1000+ concurrent users (3x-ui compatible)
- Multi-server redundancy

🔧 **Easy Management**
- One-line installation
- Interactive setup wizard
- Multi-peer configuration
- Command-line interface
- Web dashboard support

## 📦 Quick Installation

### One-Line Install
```bash
curl -fsSL https://github.com/k4lantar4/moontun/raw/main/moontun.sh | sudo bash -s -- --install
```

### Manual Installation
```bash
# Download script
wget https://github.com/k4lantar4/moontun/raw/main/moontun.sh

# Make executable
chmod +x moontun.sh

# Install
sudo ./moontun.sh --install
```

## 🚀 Quick Start

### 1. Setup Tunnel
```bash
sudo moontun setup
```

### 2. Install Tunnel Cores
```bash
sudo moontun install-cores
```

### 3. Connect
```bash
sudo moontun connect
```

### 4. Monitor Status
```bash
sudo moontun status
sudo moontun monitor
```

## 📋 Available Commands

| Command | Description |
|---------|-------------|
| `sudo moontun setup` | Interactive tunnel configuration |
| `sudo moontun install-cores` | Manage tunnel cores (EasyTier/Rathole) |
| `sudo moontun connect` | Connect tunnel with current config |
| `sudo moontun status` | Show system and tunnel status |
| `sudo moontun monitor` | Live monitoring dashboard |
| `sudo moontun stop` | Stop all tunnel processes |
| `sudo moontun restart` | Restart tunnel services |
| `sudo moontun switch` | Smart protocol switching with testing |
| `sudo moontun multi-peer` | Configure multi-peer connections |
| `sudo moontun optimize` | Apply network optimizations |
| `sudo moontun haproxy` | Setup HAProxy load balancing |
| `sudo moontun logs` | View system logs |
| `sudo moontun backup` | Create configuration backup |
| `sudo moontun restore` | Restore configuration from backup |
| `sudo moontun help` | Show help message |

## 🔧 Configuration Examples

### EasyTier Standalone Node (Foreign Server)
```bash
sudo moontun setup
# Select: EasyTier mode
# Select: Standalone node (No remote peers - Listen for connections)
# Local IP: 10.10.10.1
# Protocol: UDP/TCP/WebSocket/QUIC/WireGuard
```

### EasyTier Connected Node (Iran Server)
```bash
sudo moontun setup
# Select: EasyTier mode  
# Select: Connected node
# Local IP: 10.10.10.2
# Remote servers: SERVER1_IP,SERVER2_IP,SERVER3_IP
# Protocol: UDP/TCP/WebSocket/QUIC/WireGuard
```

### Rathole Bidirectional (Any Server)
```bash
sudo moontun setup
# Select: Rathole mode
# Select: Bidirectional (Auto-reconnect from both sides)
# Remote servers: PRIMARY_IP,BACKUP_IP
# Configure ports and protocols
```

### Multi-Peer Configuration
```bash
sudo moontun multi-peer
# Add/remove/test multiple peer servers
# Configure load balancing
# Setup service redundancy
```

## 📂 Project Structure

```
moontun/
├── moontun.sh           # Main script
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
- **Standalone/Connected architecture**
- **P2P mesh networking**
- **Multi-peer support**
- **WireGuard-like performance**
- **Best for**: Stable long-term connections

### 2. Rathole Mode
- **Bidirectional connection support**
- **High-performance tunneling**
- **Multi-service instances**
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
sudo moontun monitor

# Check detailed status
sudo moontun status

# View logs
sudo moontun logs
```

## 🛠️ Advanced Features

### HAProxy Integration
```bash
sudo moontun haproxy
# Automatically sets up load balancing
# Statistics available at: http://server:8080/stats
```

### Network Optimization
```bash
sudo moontun optimize
# Applies kernel-level optimizations
# TCP BBR congestion control
# Buffer size tuning
```

### Backup & Restore
```bash
# Create backup
sudo moontun backup

# Restore from backup
sudo moontun restore
```

## 🔍 Troubleshooting

### Check Status
```bash
sudo moontun status
```

### View Logs
```bash
sudo moontun logs
```

### Restart Services
```bash
sudo moontun restart
```

### Test Connectivity
```bash
# Check if cores are installed
sudo moontun install-cores

# Test multi-peer connectivity
sudo moontun multi-peer

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

- **GitHub Issues**: [Report bugs](https://github.com/k4lantar4/moontun/issues)
- **Documentation**: [Wiki](https://github.com/k4lantar4/moontun/wiki)
- **Discussions**: [GitHub Discussions](https://github.com/k4lantar4/moontun/discussions)

---

<div align="center">

**Made with ❤️ for the Iranian tech community**

⭐ Star this repository if it helped you!

</div> 