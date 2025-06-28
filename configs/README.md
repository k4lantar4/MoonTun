# 🔧 MVTunnel Configuration Examples

This directory contains example configurations for different MVTunnel setups.

## 📂 Available Configurations

### EasyTier Configurations
- **`easytier-master.conf`** - Foreign server configuration (master node)
- **`easytier-client.conf`** - Iran server configuration (client node)

### Rathole Configurations  
- **`rathole-server.conf`** - Foreign server configuration
- **`rathole-client.conf`** - Iran server configuration

### Hybrid Configuration
- **`hybrid-mode.conf`** - Intelligent failover between EasyTier and Rathole

## 🚀 How to Use

### 1. Copy Configuration
```bash
# Copy desired config to MVTunnel config directory
sudo cp configs/easytier-master.conf /etc/mvtunnel/mvtunnel.conf
```

### 2. Edit Configuration
```bash
# Edit with your specific settings
sudo nano /etc/mvtunnel/mvtunnel.conf

# Replace placeholders:
# - YOUR_FOREIGN_SERVER_IP with actual server IP
# - your-secret-key-here with your secret key
```

### 3. Apply Configuration
```bash
# Apply the configuration
sudo mv connect
```

## 🎯 Configuration Types

### Master/Server Node (Foreign Server)
- Acts as the central node
- Listens for incoming connections
- No need to specify remote peers
- Use `easytier-master.conf` or `rathole-server.conf`

### Client Node (Iran Server)
- Connects to master/server
- Requires remote server IP
- Use `easytier-client.conf` or `rathole-client.conf`

### Hybrid Mode
- Intelligent failover
- Maximum reliability
- Auto-switching between cores
- Use `hybrid-mode.conf`

## 🔐 Security Notes

- Always change the default `NETWORK_SECRET`
- Use strong, unique secrets for each deployment
- Keep your configuration files secure (mode 600)

```bash
# Secure config file permissions
sudo chmod 600 /etc/mvtunnel/mvtunnel.conf
```

## 📋 Configuration Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `TUNNEL_MODE` | Tunnel core to use | `easytier`, `rathole`, `hybrid` |
| `LOCAL_IP` | Local tunnel IP | `10.10.10.1` |
| `REMOTE_SERVER` | Remote server address | `203.0.113.1` |
| `NETWORK_SECRET` | Shared secret key | `your-secret-key` |
| `PROTOCOL` | Connection protocol | `udp`, `tcp`, `ws` |
| `PORT` | Connection port | `1377` |
| `FAILOVER_ENABLED` | Enable automatic failover | `true`/`false` | 