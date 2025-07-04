#!/bin/bash

# 🚀 MoonTun - Intelligent Multi-Node Tunnel System v2.0
# Created by K4lantar4 for Iran-Foreign Server Tunneling
# Combines EasyTier + Rathole with Smart Failover & Multi-Connection
# Enterprise-Grade Solution for 1000+ Concurrent Users with Multi-Server Support

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
# Iran Network Detection & Optimization Functions
# =============================================================================

detect_iran_network_conditions() {
    log cyan "🇮🇷 Detecting Iran network conditions..."
    
    local iran_indicators=0
    local total_checks=6
    
    # Check 1: DNS filtering detection (Google DNS)
    if ! timeout 3 nslookup google.com 8.8.8.8 >/dev/null 2>&1; then
        ((iran_indicators++))
        log blue "DNS filtering detected"
    fi
    
    # Check 2: Common blocked IPs
    if ! timeout 2 ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        ((iran_indicators++))
        log blue "Google DNS blocked"
    fi
    
    # Check 3: TLS fingerprinting resistance needed
    if ! timeout 5 curl -s --max-time 3 https://www.google.com >/dev/null 2>&1; then
        ((iran_indicators++))
        log blue "HTTPS connectivity issues detected"
    fi
    
    # Check 4: High latency to foreign servers
    local avg_latency=$(timeout 10 ping -c 3 1.1.1.1 2>/dev/null | tail -1 | awk -F'/' '{print $5}' | cut -d'.' -f1 2>/dev/null || echo "1000")
    if [[ "${avg_latency:-1000}" -gt 300 ]]; then
        ((iran_indicators++))
        log blue "High latency detected: ${avg_latency}ms"
    fi
    
    # Check 5: Packet loss detection
    local packet_loss=$(timeout 15 ping -c 10 1.1.1.1 2>/dev/null | grep "packet loss" | awk '{print $6}' | cut -d'%' -f1 2>/dev/null || echo "100")
    if [[ "${packet_loss:-100}" -gt 10 ]]; then
        ((iran_indicators++))
        log blue "High packet loss detected: ${packet_loss}%"
    fi
    
    # Check 6: Iran local time zone detection
    local timezone=$(timedatectl 2>/dev/null | grep "Time zone" | grep -i "tehran\|iran" || echo "")
    if [[ -n "$timezone" ]]; then
        ((iran_indicators++))
        log blue "Iran timezone detected"
    fi
    
    local iran_score=$((iran_indicators * 100 / total_checks))
    
    if [[ $iran_score -ge 50 ]]; then
        echo "iran_detected"
        log yellow "🇮🇷 Iran network conditions detected ($iran_score% confidence)"
        apply_iran_optimizations
    else
        echo "normal_network"
        log green "🌍 Normal network conditions detected ($iran_score% Iran indicators)"
    fi
    
    # Store detection result
    echo "IRAN_NETWORK_DETECTED=$([[ $iran_score -ge 50 ]] && echo "true" || echo "false")" >> "$STATUS_FILE"
    echo "IRAN_CONFIDENCE_SCORE=$iran_score" >> "$STATUS_FILE"
}

# Quick Iran network detection (< 2 seconds)
quick_detect_iran_network() {
    local iran_indicators=0
    local total_checks=3
    
    # Quick Check 1: DNS test (1 second max)
    if ! timeout 1 nslookup google.com 8.8.8.8 >/dev/null 2>&1; then
        ((iran_indicators++))
    fi
    
    # Quick Check 2: Single ping test (1 second max)  
    if ! timeout 1 ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
        ((iran_indicators++))
    fi
    
    # Quick Check 3: Check cached result from previous detailed test
    if [[ -f "$STATUS_FILE" ]] && grep -q "IRAN_NETWORK_DETECTED=true" "$STATUS_FILE" 2>/dev/null; then
        ((iran_indicators++))
    fi
    
    local iran_score=$((iran_indicators * 100 / total_checks))
    
    # Start detailed detection in background for future use
    (detect_iran_network_conditions) &
    
    if [[ $iran_score -ge 50 ]]; then
        echo "iran_detected"
        # Apply basic Iran optimizations quickly
        PROTOCOL="tcp"
        ENABLED_PROTOCOLS="tcp,ws,udp"
    else
        echo "normal_network"
    fi
}

apply_iran_optimizations() {
    log yellow "🇮🇷 Applying Iran-specific optimizations..."
    
    # Force TCP with enhanced settings
    PROTOCOL="tcp"
    ENABLED_PROTOCOLS="tcp,ws,udp"
    
    # Multiple port strategy for DPI evasion
    ADDITIONAL_PORTS="443,80,53,8080,8443,1194,1723"
    
    # Enhanced encryption and obfuscation
    ENCRYPTION="true"
    TLS_OBFUSCATION="true"
    
    # Enable packet fragmentation to avoid DPI
    PACKET_FRAGMENTATION="true"
    
    # Use Iran-friendly DNS servers
    BACKUP_DNS="178.22.122.100,185.51.200.2,10.202.10.10,10.202.10.11"
    
    # Optimize for high latency conditions
    TCP_WINDOW_SCALING="true"
    TCP_CONGESTION_CONTROL="bbr"
    
    # Enable connection persistence
    KEEP_ALIVE_ENABLED="true"
    KEEP_ALIVE_INTERVAL="30"
    
    log green "✅ Iran optimizations applied"
}

setup_iran_dns_optimization() {
    log cyan "🌐 Setting up Iran DNS optimization..."
    
    # Backup original resolv.conf
    if [[ -f "/etc/resolv.conf" ]] && [[ ! -f "/etc/resolv.conf.moontun.backup" ]]; then
        cp /etc/resolv.conf /etc/resolv.conf.moontun.backup
    fi
    
    # Create optimized resolv.conf for Iran
    cat > /etc/resolv.conf.moontun << 'EOF'
# MoonTun optimized DNS for Iran
nameserver 178.22.122.100
nameserver 185.51.200.2
nameserver 10.202.10.10
nameserver 10.202.10.11
nameserver 1.1.1.1
nameserver 8.8.8.8

options timeout:2
options attempts:3
options rotate
options single-request-reopen
EOF

    # Apply the optimized DNS
    cp /etc/resolv.conf.moontun /etc/resolv.conf
    
    log green "✅ DNS optimization applied"
}

restore_original_dns() {
    if [[ -f "/etc/resolv.conf.moontun.backup" ]]; then
        cp /etc/resolv.conf.moontun.backup /etc/resolv.conf
        log green "✅ Original DNS restored"
    fi
}

# =============================================================================
# Advanced Multi-Path & Load Balancing Functions
# =============================================================================

setup_multipath_routing() {
    log cyan "🌐 Setting up intelligent multi-path routing..."
    
    # Load configuration
    source "$MAIN_CONFIG" 2>/dev/null || return 1
    
    if [[ -z "$REMOTE_SERVER" ]]; then
        log yellow "No remote servers configured for multi-path"
        return 1
    fi
    
    # Read multiple foreign servers
    IFS=',' read -ra FOREIGN_SERVERS <<< "$REMOTE_SERVER"
    
    if [[ ${#FOREIGN_SERVERS[@]} -lt 2 ]]; then
        log yellow "Multi-path requires at least 2 servers, found ${#FOREIGN_SERVERS[@]}"
        return 1
    fi
    
    log cyan "🔍 Setting up paths for ${#FOREIGN_SERVERS[@]} servers"
    
    # Create multiple tunnel instances
    local instance_count=0
    local successful_instances=0
    
    for server in "${FOREIGN_SERVERS[@]}"; do
        server=$(echo "$server" | xargs)  # trim whitespace
        if [[ -n "$server" ]]; then
            if start_tunnel_instance "$server" "$instance_count"; then
                ((successful_instances++))
            fi
            ((instance_count++))
        fi
    done
    
    if [[ $successful_instances -gt 0 ]]; then
        # Setup ECMP routing for successful instances
        setup_ecmp_routing "${FOREIGN_SERVERS[@]}"
        
        # Start path monitoring
        start_path_quality_monitor
        
        log green "✅ Multi-path routing established with $successful_instances active paths"
        return 0
    else
        log red "❌ Failed to establish any tunnel instances"
        return 1
    fi
}

start_tunnel_instance() {
    local server="$1"
    local instance_id="$2"
    local instance_port=$((PORT + instance_id))
    local instance_ip="10.10.1$instance_id.1"
    
    log cyan "🚀 Starting tunnel instance $instance_id to $server"
    
    # Validate server connectivity first
    if ! timeout 5 nc -z "$server" "$PORT" 2>/dev/null; then
        log yellow "⚠️ Server $server:$PORT not reachable, skipping instance $instance_id"
        return 1
    fi
    
    # Start EasyTier instance
    nohup "$DEST_DIR/easytier-core" \
        -i "$instance_ip" \
        --peers "tcp://$server:$PORT" \
        --listeners "tcp://0.0.0.0:$instance_port" \
        --hostname "moon-iran-$instance_id" \
        --network-secret "$NETWORK_SECRET-$instance_id" \
        --multi-thread \
        --default-protocol tcp \
        --instance-name "iran-$instance_id" \
        --console-log-level warn \
        > "$LOG_DIR/easytier_$instance_id.log" 2>&1 &
        
    local pid=$!
    echo $pid > "$CONFIG_DIR/tunnel_$instance_id.pid"
    
    # Wait and verify instance startup
    sleep 5
    
    if kill -0 "$pid" 2>/dev/null; then
        log green "✅ Instance $instance_id started successfully (PID: $pid)"
        echo "TUNNEL_INSTANCE_${instance_id}_SERVER=$server" >> "$STATUS_FILE"
        echo "TUNNEL_INSTANCE_${instance_id}_PID=$pid" >> "$STATUS_FILE"
        echo "TUNNEL_INSTANCE_${instance_id}_PORT=$instance_port" >> "$STATUS_FILE"
        return 0
    else
        log red "❌ Instance $instance_id failed to start"
        rm -f "$CONFIG_DIR/tunnel_$instance_id.pid"
        return 1
    fi
}

setup_ecmp_routing() {
    local servers=("$@")
    log cyan "⚡ Setting up ECMP routing for ${#servers[@]} paths"
    
    # Clear existing multi-path routes
    ip route del default 2>/dev/null || true
    
    # Create routing tables for each instance
    for i in "${!servers[@]}"; do
        local instance_ip="10.10.1$i.1"
        local table_id=$((100 + i))
        
        # Create custom routing table
        ip route add default via "$instance_ip" table "$table_id" 2>/dev/null || true
        ip route add "${instance_ip}/32" dev lo table "$table_id" 2>/dev/null || true
        
        # Create policy routing rule
        ip rule add fwmark "$((i + 1))" table "$table_id" 2>/dev/null || true
        
        log blue "📋 Created routing table $table_id for instance $i"
    done
    
    # Setup iptables for load balancing
    setup_iptables_load_balancing "${#servers[@]}"
    
    log green "✅ ECMP routing configured"
}

setup_iptables_load_balancing() {
    local instance_count="$1"
    
    log cyan "🔧 Setting up iptables load balancing for $instance_count instances"
    
    # Create new chain for load balancing
    iptables -t mangle -N MOONTUN_LB 2>/dev/null || iptables -t mangle -F MOONTUN_LB
    
    # Add load balancing rules
    for ((i=0; i<instance_count; i++)); do
        local probability=$((100 / (instance_count - i)))
        local mark=$((i + 1))
        
        if [[ $i -eq $((instance_count - 1)) ]]; then
            # Last instance gets all remaining traffic
            iptables -t mangle -A MOONTUN_LB -j MARK --set-mark "$mark"
        else
            # Probabilistic distribution
            iptables -t mangle -A MOONTUN_LB -m statistic --mode random --probability "0.$(printf "%02d" $probability)" -j MARK --set-mark "$mark"
        fi
        
        log blue "📊 Instance $i: mark=$mark, probability=${probability}%"
    done
    
    # Apply load balancing to output traffic
    iptables -t mangle -A OUTPUT -j MOONTUN_LB 2>/dev/null || true
    
    log green "✅ Load balancing rules applied"
}

start_path_quality_monitor() {
    log cyan "📊 Starting path quality monitoring..."
    
    # Kill existing path monitor
    pkill -f "moontun_path_monitor" 2>/dev/null || true
    
    # Start background path monitor
    (path_quality_monitor_loop) &
    local monitor_pid=$!
    echo $monitor_pid > "$CONFIG_DIR/path_monitor.pid"
    
    log green "✅ Path monitoring started (PID: $monitor_pid)"
}

path_quality_monitor_loop() {
    while true; do
        monitor_all_paths
        sleep "${MONITOR_INTERVAL:-30}"
    done
}

monitor_all_paths() {
    local instance_count=0
    
    # Count active instances
    for pid_file in "$CONFIG_DIR"/tunnel_*.pid; do
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file" 2>/dev/null)
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                ((instance_count++))
            else
                # Clean up dead instance
                local instance_id=$(basename "$pid_file" .pid | cut -d'_' -f2)
                cleanup_dead_instance "$instance_id"
            fi
        fi
    done
    
    if [[ $instance_count -eq 0 ]]; then
        log red "🚨 All tunnel instances are down! Attempting recovery..."
        recover_all_instances
    else
        log blue "📊 Path monitoring: $instance_count active instances"
    fi
}

cleanup_dead_instance() {
    local instance_id="$1"
    
    log yellow "🧹 Cleaning up dead instance $instance_id"
    
    # Remove PID file
    rm -f "$CONFIG_DIR/tunnel_${instance_id}.pid"
    
    # Clean up routing
    local table_id=$((100 + instance_id))
    ip route flush table "$table_id" 2>/dev/null || true
    ip rule del fwmark "$((instance_id + 1))" 2>/dev/null || true
    
    # Remove from status file
    sed -i "/TUNNEL_INSTANCE_${instance_id}_/d" "$STATUS_FILE" 2>/dev/null || true
}

recover_all_instances() {
    log cyan "🔄 Attempting to recover all tunnel instances..."
    
    # Stop any remaining processes
    pkill -f "easytier-core" 2>/dev/null || true
    sleep 3
    
    # Restart multi-path routing
    setup_multipath_routing
}

# =============================================================================
# Smart Protocol & Port Hopping Functions
# =============================================================================

start_adaptive_tunneling() {
    log cyan "🔄 Starting adaptive anti-censorship tunneling..."
    
    # Define port pools based on Iran network conditions
    local common_ports=(80 443 53 8080 8443 1194 1723 500 4500 2222 9999)
    local iran_safe_ports=(443 53 80 8080 993 995 465 587)
    local random_ports=($(shuf -i 10000-65000 -n 10))
    
    # Choose port pool based on network detection
    local port_pool=("${common_ports[@]}")
    if [[ "${IRAN_NETWORK_DETECTED:-false}" == "true" ]]; then
        port_pool=("${iran_safe_ports[@]}" "${random_ports[@]}")
        log blue "🇮🇷 Using Iran-optimized port pool"
    else
        port_pool=("${common_ports[@]}" "${random_ports[@]}")
        log blue "🌍 Using standard port pool"
    fi
    
    # Define protocol pool
    local protocols=(tcp udp ws)
    if [[ "${IRAN_NETWORK_DETECTED:-false}" == "true" ]]; then
        protocols=(tcp ws tcp)  # Prefer TCP and WebSocket for Iran
    fi
    
    # Start hopping routine
    (adaptive_hop_routine "${port_pool[@]}") &
    local hop_pid=$!
    echo $hop_pid > "$CONFIG_DIR/hopping.pid"
    
    log green "✅ Adaptive tunneling started (PID: $hop_pid)"
}

adaptive_hop_routine() {
    local ports=("$@")
    local current_port_index=0
    local current_protocol_index=0
    local protocols=(tcp udp ws)
    local consecutive_failures=0
    local max_failures=3
    
    if [[ "${IRAN_NETWORK_DETECTED:-false}" == "true" ]]; then
        protocols=(tcp ws tcp)  # Iran-optimized protocols
    fi
    
    while true; do
        local current_port="${ports[$current_port_index]}"
        local current_protocol="${protocols[$current_protocol_index]}"
        
        log blue "🔄 Testing connection: $current_protocol://$REMOTE_SERVER:$current_port"
        
        # Test connection quality
        if test_connection_quality "$current_protocol" "$current_port"; then
            log green "✅ Stable connection found: $current_protocol:$current_port"
            
            # Update tunnel configuration
            if update_tunnel_config "$current_protocol" "$current_port"; then
                consecutive_failures=0
                
                # Use this config for 5-15 minutes (shorter for Iran conditions)
                local sleep_duration=300
                if [[ "${IRAN_NETWORK_DETECTED:-false}" == "true" ]]; then
                    sleep_duration=$((180 + RANDOM % 300))  # 3-8 minutes for Iran
                else
                    sleep_duration=$((300 + RANDOM % 600))  # 5-15 minutes for normal
                fi
                
                log blue "💤 Using stable connection for $((sleep_duration / 60)) minutes"
                sleep "$sleep_duration"
            else
                log yellow "⚠️ Failed to apply configuration, trying next..."
                ((consecutive_failures++))
            fi
        else
            log yellow "❌ Connection failed, trying next..."
            ((consecutive_failures++))
        fi
        
        # Emergency mode if too many failures
        if [[ $consecutive_failures -ge $max_failures ]]; then
            log red "🚨 Multiple failures detected, entering emergency mode"
            emergency_connection_mode
            consecutive_failures=0
        fi
        
        # Move to next port/protocol
        current_port_index=$(((current_port_index + 1) % ${#ports[@]}))
        if [[ $current_port_index -eq 0 ]]; then
            current_protocol_index=$(((current_protocol_index + 1) % ${#protocols[@]}))
        fi
        
        # Short delay between attempts
        sleep $((5 + RANDOM % 10))
    done
}

test_connection_quality() {
    local protocol="$1"
    local port="$2"
    local quality_score=0
    local max_score=4
    
    # Test 1: Basic connectivity
    case "$protocol" in
        "tcp")
            if timeout 5 nc -z "$REMOTE_SERVER" "$port" 2>/dev/null; then
                ((quality_score++))
            fi
            ;;
        "udp") 
            if timeout 5 nc -u -z "$REMOTE_SERVER" "$port" 2>/dev/null; then
                ((quality_score++))
            fi
            ;;
        "ws")
            if timeout 5 curl -s --max-time 3 "http://$REMOTE_SERVER:$port" >/dev/null 2>&1; then
                ((quality_score++))
            fi
            ;;
    esac
    
    # Test 2: Latency check
    local latency=$(timeout 5 ping -c 2 "$REMOTE_SERVER" 2>/dev/null | tail -1 | awk -F'/' '{print $5}' | cut -d'.' -f1 2>/dev/null || echo "999")
    if [[ "${latency:-999}" -lt 500 ]]; then
        ((quality_score++))
    fi
    
    # Test 3: Packet loss check
    local packet_loss=$(timeout 10 ping -c 5 "$REMOTE_SERVER" 2>/dev/null | grep "packet loss" | awk '{print $6}' | cut -d'%' -f1 2>/dev/null || echo "100")
    if [[ "${packet_loss:-100}" -lt 20 ]]; then
        ((quality_score++))
    fi
    
    # Test 4: Sustained connection test
    if timeout 10 curl -s --max-time 8 "http://$REMOTE_SERVER:80" >/dev/null 2>&1; then
        ((quality_score++))
    fi
    
    local quality_percentage=$((quality_score * 100 / max_score))
    log blue "🔍 Connection quality: $quality_score/$max_score ($quality_percentage%)"
    
    # Return success if quality is acceptable
    [[ $quality_score -ge 2 ]]
}

update_tunnel_config() {
    local new_protocol="$1"
    local new_port="$2"
    
    log cyan "🔧 Updating tunnel configuration: $new_protocol:$new_port"
    
    # Update configuration file
    if [[ -f "$MAIN_CONFIG" ]]; then
        sed -i "s/PROTOCOL=\".*\"/PROTOCOL=\"$new_protocol\"/" "$MAIN_CONFIG" || return 1
        sed -i "s/PORT=\".*\"/PORT=\"$new_port\"/" "$MAIN_CONFIG" || return 1
        
        # Reload configuration
        source "$MAIN_CONFIG"
        
        # Restart tunnel with new config
        if restart_tunnel_with_new_config; then
            log green "✅ Configuration updated successfully"
            
            # Log the change
            echo "$(date): Protocol switched to $new_protocol:$new_port" >> "$LOG_DIR/protocol_switches.log"
            echo "CURRENT_PROTOCOL=$new_protocol" > "$STATUS_FILE.tmp"
            echo "CURRENT_PORT=$new_port" >> "$STATUS_FILE.tmp"
            cat "$STATUS_FILE.tmp" >> "$STATUS_FILE" 2>/dev/null
            rm -f "$STATUS_FILE.tmp"
            
            return 0
        else
            log red "❌ Failed to restart tunnel with new configuration"
            return 1
        fi
    else
        log red "❌ Configuration file not found"
        return 1
    fi
}

restart_tunnel_with_new_config() {
    log cyan "🔄 Restarting tunnel with new configuration..."
    
    # Stop current tunnel gracefully
    pkill -TERM -f "easytier-core\|rathole" 2>/dev/null || true
    sleep 3
    
    # Force kill if still running
    pkill -KILL -f "easytier-core\|rathole" 2>/dev/null || true
    sleep 2
    
    # Start tunnel with new config
    case "$TUNNEL_MODE" in
        "easytier")
            start_easytier_optimized
            ;;
        "rathole")
            start_rathole_optimized
            ;;
        "hybrid")
            start_hybrid_mode_optimized
            ;;
        *)
            log red "Unknown tunnel mode: $TUNNEL_MODE"
            return 1
            ;;
    esac
}

emergency_connection_mode() {
    log red "🚨 Entering emergency connection mode!"
    
    # Stop all current activities
    pkill -f "easytier-core\|rathole" 2>/dev/null || true
    pkill -f "moontun_path_monitor\|adaptive_hop" 2>/dev/null || true
    
    # Clean all routes and rules
    cleanup_emergency_network
    
    # Emergency protocol sequence (most reliable for Iran)
    local emergency_protocols=(tcp tcp ws udp)
    local emergency_ports=(443 80 53 8080 993 465)
    
    log yellow "🚑 Attempting emergency connection sequence..."
    
    for protocol in "${emergency_protocols[@]}"; do
        for port in "${emergency_ports[@]}"; do
            log yellow "🚑 Emergency attempt: $protocol:$port"
            
            if attempt_emergency_connection "$protocol" "$port"; then
                log green "🎉 Emergency connection established!"
                
                # Update config with working emergency settings
                sed -i "s/PROTOCOL=\".*\"/PROTOCOL=\"$protocol\"/" "$MAIN_CONFIG"
                sed -i "s/PORT=\".*\"/PORT=\"$port\"/" "$MAIN_CONFIG"
                
                # Log emergency recovery
                echo "$(date): Emergency recovery successful with $protocol:$port" >> "$LOG_DIR/emergency_recovery.log"
                return 0
            fi
            
            sleep 3
        done
    done
    
    log red "❌ All emergency attempts failed - manual intervention required"
    echo "$(date): All emergency attempts failed" >> "$LOG_DIR/emergency_recovery.log"
    return 1
}

attempt_emergency_connection() {
    local protocol="$1"
    local port="$2"
    
    # Quick connectivity test first
    if ! timeout 3 nc -z "$REMOTE_SERVER" "$port" 2>/dev/null; then
        return 1
    fi
    
    # Try to establish tunnel
    case "$protocol" in
        "tcp")
            timeout 15 "$DEST_DIR/easytier-core" \
                -i "${LOCAL_IP}" \
                --peers "tcp://$REMOTE_SERVER:$port" \
                --listeners "tcp://0.0.0.0:$port" \
                --hostname "emergency-$(date +%s)" \
                --network-secret "$NETWORK_SECRET" \
                --default-protocol tcp \
                --multi-thread \
                --console-log-level error \
                > "$LOG_DIR/emergency.log" 2>&1 &
            ;;
        "udp")
            timeout 15 "$DEST_DIR/easytier-core" \
                -i "${LOCAL_IP}" \
                --peers "udp://$REMOTE_SERVER:$port" \
                --listeners "udp://0.0.0.0:$port" \
                --hostname "emergency-$(date +%s)" \
                --network-secret "$NETWORK_SECRET" \
                --default-protocol udp \
                --multi-thread \
                --console-log-level error \
                > "$LOG_DIR/emergency.log" 2>&1 &
            ;;
        "ws")
            timeout 15 "$DEST_DIR/easytier-core" \
                -i "${LOCAL_IP}" \
                --peers "ws://$REMOTE_SERVER:$port" \
                --listeners "ws://0.0.0.0:$port" \
                --hostname "emergency-$(date +%s)" \
                --network-secret "$NETWORK_SECRET" \
                --default-protocol ws \
                --multi-thread \
                --console-log-level error \
                > "$LOG_DIR/emergency.log" 2>&1 &
            ;;
    esac
    
    local pid=$!
    sleep 8
    
    # Check if tunnel is working
    if kill -0 "$pid" 2>/dev/null && ping -c 2 -W 3 "$REMOTE_IP" >/dev/null 2>&1; then
        echo $pid > "$CONFIG_DIR/emergency_tunnel.pid"
        return 0
    else
        kill "$pid" 2>/dev/null || true
        return 1
    fi
}

cleanup_emergency_network() {
    log cyan "🧹 Emergency network cleanup..."
    
    # Remove all MoonTun iptables rules
    iptables -t mangle -F MOONTUN_LB 2>/dev/null || true
    iptables -t mangle -X MOONTUN_LB 2>/dev/null || true
    iptables -t mangle -D OUTPUT -j MOONTUN_LB 2>/dev/null || true
    
    # Clear all custom routing tables
    for table_id in {100..120}; do
        ip route flush table "$table_id" 2>/dev/null || true
        ip rule del table "$table_id" 2>/dev/null || true
    done
    
    # Clear policy routing rules
    for mark in {1..20}; do
        ip rule del fwmark "$mark" 2>/dev/null || true
    done
    
    log green "✅ Emergency cleanup completed"
}

# =============================================================================
# Enhanced Health Monitoring Functions
# =============================================================================

enhanced_health_monitoring() {
    log cyan "📊 Starting enhanced health monitoring system..."
    
    # Kill any existing enhanced monitor
    pkill -f "moontun_enhanced_monitor" 2>/dev/null || true
    
    # Start enhanced monitoring loop
    (enhanced_monitor_loop) &
    local monitor_pid=$!
    echo $monitor_pid > "$CONFIG_DIR/enhanced_monitor.pid"
    
    log green "✅ Enhanced monitoring started (PID: $monitor_pid)"
}

enhanced_monitor_loop() {
    local monitor_interval="${MONITOR_INTERVAL:-15}"
    
    while true; do
        local health_metrics=$(collect_health_metrics)
        local tunnel_quality=$(analyze_tunnel_quality "$health_metrics")
        local network_conditions=$(detect_network_interference)
        
        # Store metrics for analysis
        echo "$health_metrics" >> "$LOG_DIR/health_metrics.log"
        
        # Intelligent decision making based on conditions
        case "$tunnel_quality" in
            "excellent")
                monitor_interval=60
                log green "📊 System health: Excellent"
                ;;
            "good")
                monitor_interval=30
                log cyan "📊 System health: Good"
                ;;
            "poor")
                monitor_interval=10
                log yellow "📊 System health: Poor - Triggering optimization"
                trigger_tunnel_optimization
                ;;
            "critical")
                monitor_interval=5
                log red "📊 System health: Critical - Emergency measures"
                trigger_emergency_recovery
                ;;
        esac
        
        # Adaptive monitoring based on Iran conditions
        if [[ "${IRAN_NETWORK_DETECTED:-false}" == "true" ]]; then
            monitor_interval=$((monitor_interval / 2))  # More frequent monitoring for Iran
        fi
        
        # Log detailed metrics
        log blue "Health: $tunnel_quality | Network: $network_conditions | Next check: ${monitor_interval}s"
        
        sleep "$monitor_interval"
    done
}

collect_health_metrics() {
    local metrics=""
    local timestamp=$(date +%s)
    
    # Latency metrics (multiple samples for accuracy)
    local latency_samples=()
    for i in {1..3}; do
        local lat=$(timeout 3 ping -c 1 "$REMOTE_IP" 2>/dev/null | grep "time=" | sed -n 's/.*time=\([0-9.]*\).*/\1/p' 2>/dev/null || echo "999")
        latency_samples+=("$lat")
        sleep 1
    done
    
    # Calculate average latency
    local total_latency=0
    local valid_samples=0
    for lat in "${latency_samples[@]}"; do
        if [[ "$lat" != "999" ]] && [[ -n "$lat" ]]; then
            total_latency=$(echo "$total_latency + $lat" | bc -l 2>/dev/null || echo "999")
            ((valid_samples++))
        fi
    done
    
    local avg_latency="999"
    if [[ $valid_samples -gt 0 ]]; then
        avg_latency=$(echo "scale=2; $total_latency / $valid_samples" | bc -l 2>/dev/null || echo "999")
    fi
    
    metrics+="timestamp:$timestamp,"
    metrics+="latency:${avg_latency},"
    
    # Packet loss measurement
    local packet_loss=$(timeout 15 ping -c 10 "$REMOTE_IP" 2>/dev/null | grep "packet loss" | awk '{print $6}' | cut -d'%' -f1 2>/dev/null || echo "100")
    metrics+="loss:${packet_loss},"
    
    # Bandwidth estimation using curl
    local bandwidth=0
    if command -v curl >/dev/null; then
        bandwidth=$(timeout 10 curl -s --max-time 8 -w "%{speed_download}" -o /dev/null "http://$REMOTE_IP:8080/test" 2>/dev/null || echo "0")
        bandwidth=$(echo "scale=0; $bandwidth / 1024" | bc -l 2>/dev/null || echo "0")  # Convert to KB/s
    fi
    metrics+="bandwidth:$bandwidth,"
    
    # Connection stability test
    local stability=$(check_connection_stability)
    metrics+="stability:$stability,"
    
    # CPU and memory usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "0")
    local mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}' 2>/dev/null || echo "0")
    metrics+="cpu:$cpu_usage,"
    metrics+="memory:$mem_usage,"
    
    # Active connections count
    local connections=$(ss -tun | grep -c ":$PORT " 2>/dev/null || echo "0")
    metrics+="connections:$connections,"
    
    # DNS resolution time
    local dns_time=$(timeout 5 time -p nslookup google.com 2>&1 | grep "real" | awk '{print $2}' 2>/dev/null || echo "5.0")
    metrics+="dns_time:$dns_time"
    
    echo "$metrics"
}

analyze_tunnel_quality() {
    local metrics="$1"
    
    # Extract values from metrics
    local latency=$(echo "$metrics" | grep -o "latency:[^,]*" | cut -d':' -f2)
    local loss=$(echo "$metrics" | grep -o "loss:[^,]*" | cut -d':' -f2)
    local bandwidth=$(echo "$metrics" | grep -o "bandwidth:[^,]*" | cut -d':' -f2)
    local stability=$(echo "$metrics" | grep -o "stability:[^,]*" | cut -d':' -f2)
    
    # Quality scoring algorithm
    local quality_score=0
    
    # Latency scoring (40% weight)
    if [[ $(echo "${latency:-999} < 100" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
        quality_score=$((quality_score + 40))
    elif [[ $(echo "${latency:-999} < 300" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
        quality_score=$((quality_score + 25))
    elif [[ $(echo "${latency:-999} < 500" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
        quality_score=$((quality_score + 15))
    fi
    
    # Packet loss scoring (30% weight)
    if [[ "${loss:-100}" -lt 1 ]]; then
        quality_score=$((quality_score + 30))
    elif [[ "${loss:-100}" -lt 5 ]]; then
        quality_score=$((quality_score + 20))
    elif [[ "${loss:-100}" -lt 15 ]]; then
        quality_score=$((quality_score + 10))
    fi
    
    # Bandwidth scoring (20% weight)
    if [[ "${bandwidth:-0}" -gt 1000 ]]; then
        quality_score=$((quality_score + 20))
    elif [[ "${bandwidth:-0}" -gt 500 ]]; then
        quality_score=$((quality_score + 15))
    elif [[ "${bandwidth:-0}" -gt 100 ]]; then
        quality_score=$((quality_score + 10))
    fi
    
    # Stability scoring (10% weight)
    if [[ "${stability:-0}" -gt 80 ]]; then
        quality_score=$((quality_score + 10))
    elif [[ "${stability:-0}" -gt 60 ]]; then
        quality_score=$((quality_score + 5))
    fi
    
    # Determine quality level
    if [[ $quality_score -ge 80 ]]; then
        echo "excellent"
    elif [[ $quality_score -ge 60 ]]; then
        echo "good"
    elif [[ $quality_score -ge 30 ]]; then
        echo "poor"
    else
        echo "critical"
    fi
}

check_connection_stability() {
    local stability_tests=5
    local successful_tests=0
    
    for ((i=1; i<=stability_tests; i++)); do
        if timeout 3 ping -c 1 "$REMOTE_IP" >/dev/null 2>&1; then
            ((successful_tests++))
        fi
        sleep 1
    done
    
    local stability_percentage=$((successful_tests * 100 / stability_tests))
    echo "$stability_percentage"
}

detect_network_interference() {
    local interference_score=0
    local max_score=4
    
    # Check for DPI interference (Iran-specific)
    if [[ "${IRAN_NETWORK_DETECTED:-false}" == "true" ]]; then
        # Test HTTPS connectivity to common sites
        if ! timeout 5 curl -s --max-time 3 https://www.google.com >/dev/null 2>&1; then
            ((interference_score++))
        fi
        
        # Test DNS over HTTPS
        if ! timeout 5 curl -s --max-time 3 "https://1.1.1.1/dns-query?name=google.com&type=A" >/dev/null 2>&1; then
            ((interference_score++))
        fi
    fi
    
    # Check for unusual latency patterns (QoS throttling)
    local current_latency=$(timeout 5 ping -c 1 "$REMOTE_IP" 2>/dev/null | grep "time=" | sed -n 's/.*time=\([0-9.]*\).*/\1/p' || echo "999")
    local historical_latency=$(tail -5 "$LOG_DIR/health_metrics.log" 2>/dev/null | grep -o "latency:[^,]*" | cut -d':' -f2 | tail -1 || echo "100")
    
    if [[ -n "$current_latency" ]] && [[ -n "$historical_latency" ]] && [[ "$current_latency" != "999" ]] && [[ "$historical_latency" != "999" ]]; then
        local latency_increase=$(echo "scale=2; ($current_latency - $historical_latency) / $historical_latency * 100" | bc -l 2>/dev/null || echo "0")
        if [[ $(echo "$latency_increase > 50" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
            ((interference_score++))
        fi
    fi
    
    # Check for port blocking patterns
    if ! timeout 3 nc -z "$REMOTE_SERVER" "$PORT" 2>/dev/null; then
        ((interference_score++))
    fi
    
    # Classify interference level
    local interference_percentage=$((interference_score * 100 / max_score))
    
    if [[ $interference_percentage -ge 75 ]]; then
        echo "high"
    elif [[ $interference_percentage -ge 50 ]]; then
        echo "medium"
    elif [[ $interference_percentage -ge 25 ]]; then
        echo "low"
    else
        echo "none"
    fi
}

trigger_tunnel_optimization() {
    log cyan "🔧 Triggering tunnel optimization..."
    
    # Apply Iran-specific optimizations if detected
    if [[ "${IRAN_NETWORK_DETECTED:-false}" == "true" ]]; then
        apply_iran_optimizations
        setup_iran_dns_optimization
    fi
    
    # Optimize TCP settings
    optimize_tcp_settings
    
    # Try alternative protocols
    if [[ "$PROTOCOL" == "tcp" ]]; then
        log blue "💡 Trying WebSocket protocol for better penetration"
        update_tunnel_config "ws" "$PORT"
    elif [[ "$PROTOCOL" == "udp" ]]; then
        log blue "💡 Switching to TCP for better reliability"
        update_tunnel_config "tcp" "$PORT"
    fi
}

optimize_tcp_settings() {
    log cyan "🔧 Applying TCP optimizations..."
    
    # TCP congestion control for high latency
    echo 'bbr' > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || true
    
    # TCP window scaling
    echo 1 > /proc/sys/net/ipv4/tcp_window_scaling 2>/dev/null || true
    
    # TCP keepalive settings
    echo 30 > /proc/sys/net/ipv4/tcp_keepalive_time 2>/dev/null || true
    echo 5 > /proc/sys/net/ipv4/tcp_keepalive_intvl 2>/dev/null || true
    echo 3 > /proc/sys/net/ipv4/tcp_keepalive_probes 2>/dev/null || true
    
    # TCP buffer sizes
    echo "4096 87380 16777216" > /proc/sys/net/ipv4/tcp_rmem 2>/dev/null || true
    echo "4096 65536 16777216" > /proc/sys/net/ipv4/tcp_wmem 2>/dev/null || true
    
    log green "✅ TCP optimizations applied"
}

trigger_emergency_recovery() {
    log red "🚨 Triggering emergency recovery procedures..."
    
    # Stop all tunnel processes
    pkill -KILL -f "easytier-core\|rathole" 2>/dev/null || true
    
    # Stop all monitoring
    pkill -KILL -f "moontun.*monitor" 2>/dev/null || true
    
    # Emergency network reset
    cleanup_emergency_network
    
    # Try emergency connection mode
    if emergency_connection_mode; then
        log green "✅ Emergency recovery successful"
        
        # Restart monitoring with reduced frequency
        MONITOR_INTERVAL=60
        enhanced_health_monitoring
    else
        log red "❌ Emergency recovery failed - system requires manual intervention"
        
        # Log critical failure
        echo "$(date): CRITICAL FAILURE - Manual intervention required" >> "$LOG_DIR/critical_failures.log"
        
        # Send notification if possible
        notify_critical_failure
    fi
}

notify_critical_failure() {
    log red "📢 Sending critical failure notification..."
    
    # Try to notify via multiple channels
    local notification_msg="MoonTun Critical Failure at $(date) on $(hostname). Manual intervention required."
    
    # Log to system journal
    logger -p daemon.crit "$notification_msg" 2>/dev/null || true
    
    # Create failure marker file
    echo "$notification_msg" > "$CONFIG_DIR/CRITICAL_FAILURE_$(date +%Y%m%d_%H%M%S)"
    
    # If curl is available, try webhook notification
    if command -v curl >/dev/null && [[ -n "${WEBHOOK_URL:-}" ]]; then
        curl -s -X POST -H "Content-Type: application/json" \
            -d "{\"text\":\"$notification_msg\"}" \
            "$WEBHOOK_URL" 2>/dev/null || true
    fi
}

# =============================================================================
# Geographic Load Balancing Functions
# =============================================================================

setup_geo_load_balancing() {
    log cyan "🌍 Setting up geographic load balancing..."
    
    # Load configuration
    source "$MAIN_CONFIG" 2>/dev/null || return 1
    
    if [[ -z "$REMOTE_SERVER" ]]; then
        log yellow "No remote servers configured for geo load balancing"
        return 1
    fi
    
    # FAST GEO BALANCING - Quick ping test only
    IFS=',' read -ra SERVERS <<< "$REMOTE_SERVER"
    log cyan "⚡ Fast testing ${#SERVERS[@]} servers for geo load balancing..."
    
    local best_server=""
    local best_latency=9999
    local temp_results="/tmp/moontun_geo_results.$$"
    
    # Parallel fast ping test (max 3 seconds total)
    for server in "${SERVERS[@]}"; do
        server=$(echo "$server" | xargs)  # trim whitespace
        if [[ -n "$server" ]]; then
            (
                # Single quick ping with 2 second timeout
                local latency=$(timeout 2 ping -c 1 -W 1 "$server" 2>/dev/null | 
                              grep "time=" | awk -F'time=' '{print $2}' | awk '{print $1}' 2>/dev/null || echo "999")
                echo "$server:$latency" >> "$temp_results"
                log blue "🔍 Testing server: $server - ${latency}ms"
            ) &
        fi
    done
    
    # Wait for all tests to complete (max 3 seconds)
    sleep 3
    wait
    
    # Select best server from results
    if [[ -f "$temp_results" ]]; then
        while IFS=: read -r server latency; do
            if [[ "$latency" != "999" ]] && (( $(echo "$latency < $best_latency" | bc -l 2>/dev/null || echo 0) )); then
                best_server="$server"
                best_latency="$latency"
            fi
        done < "$temp_results"
        rm -f "$temp_results"
    fi
    
    # Fallback to first server if no good results
    if [[ -z "$best_server" ]]; then
        best_server=$(echo "$REMOTE_SERVER" | cut -d',' -f1)
        log yellow "⚠️ Using fallback server: $best_server"
    else
        log green "🏆 Best server selected: $best_server (${best_latency}ms)"
    fi
    
    # Update configuration with selected server
    log cyan "📝 Updating configuration with server: $best_server"
    sed -i "s/REMOTE_SERVER=\".*\"/REMOTE_SERVER=\"$best_server\"/" "$MAIN_CONFIG"
    
    # Store geo metrics for monitoring
    echo "GEO_BALANCING_ENABLED=true" >> "$STATUS_FILE"
    echo "LAST_GEO_UPDATE=$(date +%s)" >> "$STATUS_FILE"
    echo "SELECTED_SERVER=$best_server" >> "$STATUS_FILE"
    echo "SELECTED_LATENCY=$best_latency" >> "$STATUS_FILE"
    
    log green "✅ Fast geo load balancing configured with $best_server"
    
    # Start background detailed testing for future use
    (background_detailed_geo_testing "$REMOTE_SERVER") &
    
    return 0
}

# Background detailed geo testing for future optimization
background_detailed_geo_testing() {
    local servers="$1"
    local cache_file="/tmp/moontun_detailed_geo_cache"
    
    # Only run if not already running
    if [[ -f "/tmp/moontun_geo_testing.lock" ]]; then
        return 0
    fi
    
    touch "/tmp/moontun_geo_testing.lock"
    
    log blue "🔍 Starting background detailed geo testing..."
    
    # Detailed testing with lower timeouts
    IFS=',' read -ra SERVERS <<< "$servers"
    echo "# Detailed geo test results - $(date)" > "$cache_file"
    
    for server in "${SERVERS[@]}"; do
        server=$(echo "$server" | xargs)
        if [[ -n "$server" ]]; then
            local latency=$(quick_test_server_latency "$server")
            local stability=$(quick_test_server_stability "$server")
            local location=$(quick_detect_location "$server")
            local score=$(calculate_quick_score "$latency" "$stability" "$location")
            
            echo "$server:$score:$latency:$stability:$location" >> "$cache_file"
            
            # Small delay to avoid overwhelming network
            sleep 2
        fi
    done
    
    log blue "✅ Background geo testing completed"
    rm -f "/tmp/moontun_geo_testing.lock"
}

# Quick versions of testing functions with reduced timeouts
quick_test_server_latency() {
    local server="$1"
    local latency=$(timeout 3 ping -c 2 "$server" 2>/dev/null | 
                   grep "time=" | tail -1 | awk -F'time=' '{print $2}' | awk '{print $1}' 2>/dev/null || echo "999")
    echo "$latency"
}

quick_test_server_stability() {
    local server="$1"
    local successful_tests=0
    local total_tests=3
    
    for ((i=1; i<=total_tests; i++)); do
        if timeout 2 ping -c 1 "$server" >/dev/null 2>&1; then
            ((successful_tests++))
        fi
    done
    
    local stability_percentage=$((successful_tests * 100 / total_tests))
    echo "$stability_percentage"
}

quick_detect_location() {
    local server="$1"
    local location="unknown"
    
    # Quick latency-based location detection
    local latency=$(timeout 2 ping -c 1 "$server" 2>/dev/null | grep "time=" | awk -F'time=' '{print $2}' | awk '{print $1}' 2>/dev/null || echo "999")
    
    if [[ -n "$latency" ]] && [[ "$latency" != "999" ]]; then
        if (( $(echo "$latency < 50" | bc -l 2>/dev/null || echo 0) )); then
            location="local"
        elif (( $(echo "$latency < 150" | bc -l 2>/dev/null || echo 0) )); then
            location="regional"
        else
            location="distant"
        fi
    fi
    
    echo "$location"
}

calculate_quick_score() {
    local latency="$1"
    local stability="$2"
    local location="$3"
    
    local score=0
    
    # Quick scoring based on latency (60% weight)
    if (( $(echo "${latency:-999} < 50" | bc -l 2>/dev/null || echo 0) )); then
        score=$((score + 60))
    elif (( $(echo "${latency:-999} < 100" | bc -l 2>/dev/null || echo 0) )); then
        score=$((score + 50))
    elif (( $(echo "${latency:-999} < 200" | bc -l 2>/dev/null || echo 0) )); then
        score=$((score + 30))
    elif (( $(echo "${latency:-999} < 500" | bc -l 2>/dev/null || echo 0) )); then
        score=$((score + 10))
    fi
    
    # Stability scoring (30% weight)
    if [[ "${stability:-0}" -gt 80 ]]; then
        score=$((score + 30))
    elif [[ "${stability:-0}" -gt 60 ]]; then
        score=$((score + 20))
    elif [[ "${stability:-0}" -gt 40 ]]; then
        score=$((score + 10))
    fi
    
    # Location bonus (10% weight)
    case "$location" in
        "local") score=$((score + 10)) ;;
        "regional") score=$((score + 8)) ;;
        "distant") score=$((score + 5)) ;;
    esac
    
    echo "$score"
}

test_server_latency() {
    local server="$1"
    local total_latency=0
    local valid_tests=0
    local test_count=5
    
    for ((i=1; i<=test_count; i++)); do
        local latency=$(timeout 5 ping -c 1 "$server" 2>/dev/null | grep "time=" | sed -n 's/.*time=\([0-9.]*\).*/\1/p' 2>/dev/null || echo "999")
        if [[ "$latency" != "999" ]] && [[ -n "$latency" ]]; then
            total_latency=$(echo "$total_latency + $latency" | bc -l 2>/dev/null || echo "999")
            ((valid_tests++))
        fi
        sleep 0.5
    done
    
    if [[ $valid_tests -gt 0 ]]; then
        local avg_latency=$(echo "scale=1; $total_latency / $valid_tests" | bc -l 2>/dev/null || echo "999")
        echo "$avg_latency"
    else
        echo "999"
    fi
}

test_server_stability() {
    local server="$1"
    local successful_tests=0
    local total_tests=10
    
    for ((i=1; i<=total_tests; i++)); do
        if timeout 3 ping -c 1 "$server" >/dev/null 2>&1; then
            ((successful_tests++))
        fi
        sleep 0.2
    done
    
    local stability_percentage=$((successful_tests * 100 / total_tests))
    echo "$stability_percentage"
}

test_server_bandwidth() {
    local server="$1"
    local bandwidth=0
    
    # Try HTTP speed test
    if timeout 8 curl -s --max-time 6 -w "%{speed_download}" -o /dev/null "http://$server:80" 2>/dev/null | grep -q "[0-9]"; then
        bandwidth=$(timeout 8 curl -s --max-time 6 -w "%{speed_download}" -o /dev/null "http://$server:80" 2>/dev/null || echo "0")
        bandwidth=$(echo "scale=0; $bandwidth / 1024" | bc -l 2>/dev/null || echo "0")
    fi
    
    # Fallback: estimate based on ping variance
    if [[ "$bandwidth" == "0" ]]; then
        local ping_variance=$(timeout 10 ping -c 5 "$server" 2>/dev/null | grep "min/avg/max/mdev" | awk -F'/' '{print $5}' | cut -d' ' -f1 2>/dev/null || echo "100")
        # Lower variance = better bandwidth estimate
        bandwidth=$(echo "scale=0; 1000 / (1 + $ping_variance)" | bc -l 2>/dev/null || echo "10")
    fi
    
    echo "$bandwidth"
}

detect_server_location() {
    local server="$1"
    local location="unknown"
    
    # Try to detect location using various methods
    if command -v curl >/dev/null; then
        # Method 1: IP geolocation API
        location=$(timeout 5 curl -s "http://ip-api.com/json/$server" 2>/dev/null | grep -o '"country":"[^"]*' | cut -d'"' -f4 2>/dev/null || echo "unknown")
        
        # Method 2: Whois data if first method fails
        if [[ "$location" == "unknown" ]] || [[ -z "$location" ]]; then
            location=$(timeout 5 whois "$server" 2>/dev/null | grep -i "country" | head -1 | awk '{print $NF}' 2>/dev/null || echo "unknown")
        fi
    fi
    
    # Method 3: Latency-based guess for Iran optimization
    if [[ "$location" == "unknown" ]]; then
        local latency=$(timeout 3 ping -c 1 "$server" 2>/dev/null | grep "time=" | sed -n 's/.*time=\([0-9.]*\).*/\1/p' 2>/dev/null || echo "999")
        if [[ -n "$latency" ]] && [[ "$latency" != "999" ]]; then
            if [[ $(echo "$latency < 50" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
                location="local"
            elif [[ $(echo "$latency < 150" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
                location="regional"
            else
                location="distant"
            fi
        fi
    fi
    
    echo "$location"
}

calculate_server_score() {
    local latency="$1"
    local stability="$2"
    local bandwidth="$3"
    local location="$4"
    
    local score=0
    
    # Latency scoring (35% weight) - Lower is better
    if [[ $(echo "${latency:-999} < 50" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
        score=$((score + 35))
    elif [[ $(echo "${latency:-999} < 100" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
        score=$((score + 30))
    elif [[ $(echo "${latency:-999} < 200" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
        score=$((score + 25))
    elif [[ $(echo "${latency:-999} < 300" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
        score=$((score + 15))
    elif [[ $(echo "${latency:-999} < 500" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
        score=$((score + 5))
    fi
    
    # Stability scoring (30% weight)
    if [[ "${stability:-0}" -gt 90 ]]; then
        score=$((score + 30))
    elif [[ "${stability:-0}" -gt 80 ]]; then
        score=$((score + 25))
    elif [[ "${stability:-0}" -gt 70 ]]; then
        score=$((score + 20))
    elif [[ "${stability:-0}" -gt 50 ]]; then
        score=$((score + 10))
    fi
    
    # Bandwidth scoring (25% weight)
    if [[ "${bandwidth:-0}" -gt 1000 ]]; then
        score=$((score + 25))
    elif [[ "${bandwidth:-0}" -gt 500 ]]; then
        score=$((score + 20))
    elif [[ "${bandwidth:-0}" -gt 200 ]]; then
        score=$((score + 15))
    elif [[ "${bandwidth:-0}" -gt 50 ]]; then
        score=$((score + 10))
    elif [[ "${bandwidth:-0}" -gt 10 ]]; then
        score=$((score + 5))
    fi
    
    # Location bonus (10% weight)
    case "$location" in
        "local"|"IR"|"Iran") score=$((score + 10)) ;;  # Local servers get highest bonus
        "regional"|"DE"|"NL"|"UK") score=$((score + 8)) ;;  # European servers good for Iran
        "US"|"CA") score=$((score + 6)) ;;  # North American servers
        "distant"|"AS"|"JP") score=$((score + 4)) ;;  # Asian servers
        *) score=$((score + 2)) ;;  # Unknown locations get minimal bonus
    esac
    
    echo "$score"
}

schedule_geo_rebalancing() {
    log cyan "⏰ Scheduling periodic geo rebalancing..."
    
    # Kill existing geo scheduler
    pkill -f "moontun_geo_scheduler" 2>/dev/null || true
    
    # Start geo rebalancing scheduler
    (geo_rebalancing_scheduler) &
    local scheduler_pid=$!
    echo $scheduler_pid > "$CONFIG_DIR/geo_scheduler.pid"
    
    log green "✅ Geo rebalancing scheduler started (PID: $scheduler_pid)"
}

geo_rebalancing_scheduler() {
    local rebalance_interval=$((4 * 3600))  # 4 hours default
    
    # Adjust interval based on Iran conditions
    if [[ "${IRAN_NETWORK_DETECTED:-false}" == "true" ]]; then
        rebalance_interval=$((2 * 3600))  # 2 hours for Iran
    fi
    
    while true; do
        sleep "$rebalance_interval"
        
        log cyan "⏰ Scheduled geo rebalancing triggered"
        
        # Check if current servers are still performing well
        if check_current_servers_performance; then
            log green "✅ Current servers performing well, skipping rebalancing"
        else
            log yellow "⚠️ Performance degradation detected, triggering rebalancing"
            setup_geo_load_balancing
            
            # Restart tunnels with new configuration
            restart_tunnel_with_new_config
        fi
    done
}

check_current_servers_performance() {
    source "$MAIN_CONFIG" 2>/dev/null || return 1
    
    local performance_threshold=60  # Minimum acceptable performance score
    local failed_servers=0
    local total_servers=0
    
    IFS=',' read -ra SERVERS <<< "$REMOTE_SERVER"
    
    for server in "${SERVERS[@]}"; do
        server=$(echo "$server" | xargs)
        if [[ -n "$server" ]]; then
            ((total_servers++))
            
            local latency=$(test_server_latency "$server")
            local stability=$(test_server_stability "$server")
            local score=$(calculate_server_score "$latency" "$stability" "100" "unknown")
            
            if [[ "$score" -lt $performance_threshold ]]; then
                ((failed_servers++))
                log yellow "⚠️ Server $server performance degraded (score: $score)"
            fi
        fi
    done
    
    # Return success if less than 50% of servers are failing
    local failure_percentage=$((failed_servers * 100 / total_servers))
    [[ $failure_percentage -lt 50 ]]
}

# =============================================================================
# Optimized EasyTier Functions
# =============================================================================

start_easytier_optimized() {
    log cyan "🚇 Starting optimized EasyTier tunnel..."
    
    if [[ ! -f "$DEST_DIR/easytier-core" ]]; then
        log red "EasyTier not installed. Use: moontun install-cores"
        return 1
    fi
    
    # Load configuration
    source "$MAIN_CONFIG"
    
    # Quick Iran network detection (non-blocking)
    local network_type=$(quick_detect_iran_network)
    
    # Build optimized EasyTier command
    local easytier_cmd="$DEST_DIR/easytier-core"
    local base_args=""
    local listeners=""
    local peers=""
    local performance_args=""
    local iran_args=""
    
    # Basic configuration
    base_args="-i $LOCAL_IP --hostname moon-$(hostname | cut -c1-10)-$(date +%s)"
    base_args="$base_args --network-secret $NETWORK_SECRET"
    base_args="$base_args --default-protocol $PROTOCOL"
    
    # Configure node type and connectivity
    if [[ "${EASYTIER_NODE_TYPE:-connected}" == "standalone" ]]; then
        log cyan "🏗️ Starting as optimized standalone node..."
        
        # Multi-protocol listeners for maximum compatibility
        listeners="--listeners"
        listeners="$listeners tcp://0.0.0.0:$PORT"
        listeners="$listeners udp://0.0.0.0:$((PORT + 1))"
        
        # Add IPv6 support if not Iran
        if [[ "$network_type" != "iran_detected" ]]; then
            listeners="$listeners tcp://[::]:$PORT"
            listeners="$listeners udp://[::]:$((PORT + 1))"
        fi
        
        # WebSocket listener for DPI evasion
        if [[ "$network_type" == "iran_detected" ]]; then
            listeners="$listeners ws://0.0.0.0:$((PORT + 2))"
        fi
        
        log cyan "💡 Standalone mode: Waiting for connections on multiple protocols"
    else
        log cyan "🔗 Starting as optimized connected node..."
        
        if [[ -z "$REMOTE_SERVER" ]]; then
            log red "Remote server(s) required for connected mode"
            return 1
        fi
        
        # Multi-protocol listeners
        listeners="--listeners"
        listeners="$listeners tcp://0.0.0.0:$PORT"
        listeners="$listeners udp://0.0.0.0:$((PORT + 1))"
        
        # Add WebSocket for Iran
        if [[ "$network_type" == "iran_detected" ]]; then
            listeners="$listeners ws://0.0.0.0:$((PORT + 2))"
        fi
        
        # Multi-peer support with protocol diversity
        local peer_list=""
        IFS=',' read -ra SERVERS <<< "$REMOTE_SERVER"
        local server_index=0
        
        for server in "${SERVERS[@]}"; do
            server=$(echo "$server" | xargs)
            if [[ -n "$server" ]]; then
                # Use different protocols for different servers
                case $((server_index % 3)) in
                    0) peer_list="$peer_list --peers tcp://${server}:${PORT}" ;;
                    1) peer_list="$peer_list --peers udp://${server}:$((PORT + 1))" ;;
                    2) 
                        if [[ "$network_type" == "iran_detected" ]]; then
                            peer_list="$peer_list --peers ws://${server}:$((PORT + 2))"
                        else
                            peer_list="$peer_list --peers tcp://${server}:${PORT}"
                        fi
                        ;;
                esac
                ((server_index++))
            fi
        done
        peers="$peer_list"
        
        log cyan "🎯 Connecting to ${#SERVERS[@]} peers with protocol diversity"
    fi
    
    # Performance optimizations
    performance_args="--multi-thread"
    performance_args="$performance_args --enable-exit-node"
    performance_args="$performance_args --relay-all-peer-rpc"
    
    # Advanced features
    performance_args="$performance_args --rpc-portal 0.0.0.0:$((PORT + 100))"
    performance_args="$performance_args --vpn-portal wg://0.0.0.0:$((PORT + 300))/10.20.0.0/24"
    
    # Iran-specific optimizations
    if [[ "$network_type" == "iran_detected" ]]; then
        iran_args="--console-log-level warn"  # Reduce logging for performance
        iran_args="$iran_args --instance-name iran-$(date +%s)"
        
        # Use public IP mapping if available
        local public_ip=$(get_public_ip)
        if [[ "$public_ip" != "Unknown" ]] && [[ -n "$public_ip" ]]; then
            iran_args="$iran_args --mapped-listeners tcp://$public_ip:$PORT"
        fi
        
        # Disable IPv6 for Iran to avoid issues
        iran_args="$iran_args --disable-ipv6"
        
        log blue "🇮🇷 Applied Iran-specific optimizations"
    else
        performance_args="$performance_args --console-log-level info"
    fi
    
    # Kill existing processes
    pkill -f "easytier-core" 2>/dev/null || true
    sleep 3
    
    # Build final command
    local final_cmd="$easytier_cmd $base_args $listeners $peers $performance_args $iran_args"
    
    log cyan "🚀 Starting EasyTier with command:"
    log blue "$final_cmd"
    
    # Start EasyTier with optimized configuration
    nohup $final_cmd > "$LOG_DIR/easytier_optimized.log" 2>&1 &
    local easytier_pid=$!
    
    # Quick startup verification with timeout
    local startup_timeout=10
    local wait_count=0
    
    while [[ $wait_count -lt $startup_timeout ]]; do
        if kill -0 "$easytier_pid" 2>/dev/null; then
            # Process is running, check if it's actually working
            if [[ $wait_count -gt 2 ]]; then
                # Give it a moment to initialize
                break
            fi
        else
            # Process died early
            log red "❌ EasyTier process died during startup"
            return 1
        fi
        sleep 1
        ((wait_count++))
    done
    
    if kill -0 "$easytier_pid" 2>/dev/null; then
        echo "ACTIVE_TUNNEL=easytier" > "$STATUS_FILE"
        echo "NODE_TYPE=${EASYTIER_NODE_TYPE:-connected}" >> "$STATUS_FILE"
        echo "EASYTIER_PID=$easytier_pid" >> "$STATUS_FILE"
        echo "NETWORK_TYPE=$network_type" >> "$STATUS_FILE"
        echo "OPTIMIZED_MODE=true" >> "$STATUS_FILE"
        
        log green "✅ Optimized EasyTier started successfully (PID: $easytier_pid)"
        
        # Start enhanced monitoring
        enhanced_health_monitoring
        
        # Start adaptive tunneling if Iran detected
        if [[ "$network_type" == "iran_detected" ]]; then
            start_adaptive_tunneling
        fi
        
        return 0
    else
        log red "❌ Failed to start optimized EasyTier"
        cat "$LOG_DIR/easytier_optimized.log" | tail -10
        
        # Try simplified fallback command
        log yellow "🔄 Attempting simplified EasyTier fallback..."
        if start_easytier_simple_fallback; then
            log green "✅ EasyTier started with simplified configuration"
            return 0
        else
            log red "❌ Both optimized and simplified EasyTier failed"
            return 1
        fi
    fi
}

# Simplified EasyTier fallback for critical situations
start_easytier_simple_fallback() {
    log cyan "⚡ Starting simplified EasyTier fallback..."
    
    # Kill any existing processes
    pkill -f "easytier-core" 2>/dev/null || true
    sleep 2
    
    # Load basic configuration
    source "$MAIN_CONFIG"
    
    # Build minimal working command
    local simple_cmd="$DEST_DIR/easytier-core"
    simple_cmd="$simple_cmd -i $LOCAL_IP"
    simple_cmd="$simple_cmd --network-secret $NETWORK_SECRET"
    simple_cmd="$simple_cmd --default-protocol tcp"
    simple_cmd="$simple_cmd --listeners tcp://0.0.0.0:$PORT"
    
    # Add peer connection if available
    if [[ -n "$REMOTE_SERVER" ]]; then
        local first_server=$(echo "$REMOTE_SERVER" | cut -d',' -f1)
        simple_cmd="$simple_cmd --peers tcp://$first_server:$PORT"
    fi
    
    log cyan "🚀 Simple EasyTier command: $simple_cmd"
    
    # Start with minimal configuration
    nohup $simple_cmd > "$LOG_DIR/easytier_simple.log" 2>&1 &
    local easytier_pid=$!
    
    # Quick verification
    sleep 3
    
    if kill -0 "$easytier_pid" 2>/dev/null; then
        echo "ACTIVE_TUNNEL=easytier" > "$STATUS_FILE"
        echo "NODE_TYPE=simple" >> "$STATUS_FILE"
        echo "EASYTIER_PID=$easytier_pid" >> "$STATUS_FILE"
        echo "FALLBACK_MODE=true" >> "$STATUS_FILE"
        
        log green "✅ Simple EasyTier started successfully (PID: $easytier_pid)"
        return 0
    else
        log red "❌ Simple EasyTier also failed"
        cat "$LOG_DIR/easytier_simple.log" | tail -10
        return 1
    fi
}

# =============================================================================
# Optimized Rathole Functions  
# =============================================================================

start_rathole_optimized() {
    log cyan "⚡ Starting optimized Rathole tunnel..."
    
    if [[ ! -f "$DEST_DIR/rathole" ]]; then
        log red "Rathole not installed. Use: moontun install-cores"
        return 1
    fi
    
    # Load configuration
    source "$MAIN_CONFIG"
    
    # Detect network conditions
    local network_type=$(detect_iran_network_conditions)
    
    # Create optimized Rathole configuration
    create_optimized_rathole_config "$network_type"
    
    # Determine configuration flag based on node type
    local config_flag=""
    case "${RATHOLE_NODE_TYPE:-bidirectional}" in
        "listener"|"server")
            config_flag="-s"
            log cyan "🔧 Starting as optimized Rathole server..."
            ;;
        "connector"|"client")
            config_flag="-c"
            log cyan "🔗 Starting as optimized Rathole client..."
            ;;
        "bidirectional"|*)
            # Intelligent mode selection
            if [[ -n "$REMOTE_SERVER" ]]; then
                config_flag="-c"
                log cyan "🔄 Starting in bidirectional mode as client..."
            else
                config_flag="-s"
                log cyan "🔄 Starting in bidirectional mode as server..."
            fi
            ;;
    esac
    
    # Kill existing processes
    pkill -f "rathole" 2>/dev/null || true
    sleep 3
    
    # Start Rathole with optimized config
    log cyan "🚀 Starting Rathole: rathole $config_flag $RATHOLE_CONFIG"
    
    nohup "$DEST_DIR/rathole" $config_flag "$RATHOLE_CONFIG" \
        > "$LOG_DIR/rathole_optimized.log" 2>&1 &
    local rathole_pid=$!
    
    # Wait and verify startup
    sleep 5
    
    if kill -0 "$rathole_pid" 2>/dev/null; then
        echo "ACTIVE_TUNNEL=rathole" > "$STATUS_FILE"
        echo "NODE_TYPE=${RATHOLE_NODE_TYPE:-bidirectional}" >> "$STATUS_FILE"
        echo "RATHOLE_PID=$rathole_pid" >> "$STATUS_FILE"
        echo "NETWORK_TYPE=$network_type" >> "$STATUS_FILE"
        echo "OPTIMIZED_MODE=true" >> "$STATUS_FILE"
        
        log green "✅ Optimized Rathole started successfully (PID: $rathole_pid)"
        
        # Start enhanced monitoring
        enhanced_health_monitoring
        
        return 0
    else
        log red "❌ Failed to start optimized Rathole"
        cat "$LOG_DIR/rathole_optimized.log" | tail -20
        return 1
    fi
}

create_optimized_rathole_config() {
    local network_type="$1"
    local node_type="${RATHOLE_NODE_TYPE:-bidirectional}"
    
    log cyan "📝 Creating optimized Rathole configuration..."
    
    # Determine if server or client config
    local is_server="false"
    if [[ "$node_type" == "listener" ]] || [[ "$node_type" == "server" ]] || [[ -z "$REMOTE_SERVER" ]]; then
        is_server="true"
    fi
    
    cat > "$RATHOLE_CONFIG" << EOF
# Optimized Rathole Configuration for MoonTun v${MOONTUN_VERSION}
# Network type: $network_type
# Generated: $(date)

[$([ "$is_server" == "true" ] && echo "server" || echo "client")]
$([ "$is_server" == "true" ] && echo "bind_addr = \"0.0.0.0:${PORT}\"" || echo "remote_addr = \"${REMOTE_SERVER}:${PORT}\"")
default_token = "${NETWORK_SECRET}"

# Optimized transport configuration
[$([ "$is_server" == "true" ] && echo "server" || echo "client").transport]
type = "${PROTOCOL}"

# TCP optimizations
[$([ "$is_server" == "true" ] && echo "server" || echo "client").transport.tcp]
nodelay = true
keepalive_secs = 30
keepalive_interval = 5
keepalive_retries = 3
EOF

    # Add Iran-specific optimizations
    if [[ "$network_type" == "iran_detected" ]]; then
        cat >> "$RATHOLE_CONFIG" << EOF

# Iran-specific TLS configuration for DPI evasion
[$([ "$is_server" == "true" ] && echo "server" || echo "client").transport.tls]
hostname = "update.microsoft.com"
trusted_root = "system"
EOF
    fi
    
    # Add service configurations
    cat >> "$RATHOLE_CONFIG" << EOF

# Main tunnel service
[$([ "$is_server" == "true" ] && echo "server" || echo "client").services.main]
type = "${PROTOCOL}"
$([ "$is_server" == "true" ] && echo "bind_addr = \"0.0.0.0:8080\"" || echo "local_addr = \"127.0.0.1:8080\"")
$([ "$is_server" != "true" ] && echo "remote_addr = \"0.0.0.0:8080\"")
token = "${NETWORK_SECRET}_main"

# SSH service
[$([ "$is_server" == "true" ] && echo "server" || echo "client").services.ssh]
type = "tcp"
$([ "$is_server" == "true" ] && echo "bind_addr = \"0.0.0.0:2222\"" || echo "local_addr = \"127.0.0.1:22\"")
$([ "$is_server" != "true" ] && echo "remote_addr = \"0.0.0.0:2222\"")
token = "${NETWORK_SECRET}_ssh"

# SOCKS5 proxy service
[$([ "$is_server" == "true" ] && echo "server" || echo "client").services.socks]
type = "tcp"
$([ "$is_server" == "true" ] && echo "bind_addr = \"0.0.0.0:1080\"" || echo "local_addr = \"127.0.0.1:1080\"")
$([ "$is_server" != "true" ] && echo "remote_addr = \"0.0.0.0:1080\"")
token = "${NETWORK_SECRET}_socks"
EOF

    # Add Iran-specific services
    if [[ "$network_type" == "iran_detected" ]]; then
        cat >> "$RATHOLE_CONFIG" << EOF

# DNS service for Iran
[$([ "$is_server" == "true" ] && echo "server" || echo "client").services.dns]
type = "udp"
$([ "$is_server" == "true" ] && echo "bind_addr = \"0.0.0.0:5353\"" || echo "local_addr = \"127.0.0.1:53\"")
$([ "$is_server" != "true" ] && echo "remote_addr = \"0.0.0.0:5353\"")
token = "${NETWORK_SECRET}_dns"

# HTTPS service for web traffic
[$([ "$is_server" == "true" ] && echo "server" || echo "client").services.https]
type = "tcp"
$([ "$is_server" == "true" ] && echo "bind_addr = \"0.0.0.0:8443\"" || echo "local_addr = \"127.0.0.1:443\"")
$([ "$is_server" != "true" ] && echo "remote_addr = \"0.0.0.0:8443\"")
token = "${NETWORK_SECRET}_https"
EOF
    fi
    
    # Add performance optimizations
    cat >> "$RATHOLE_CONFIG" << EOF

# Performance optimizations
[$([ "$is_server" == "true" ] && echo "server" || echo "client").services.main.nodelay]
enabled = true

[$([ "$is_server" == "true" ] && echo "server" || echo "client").services.main.compress]
enabled = $([[ "${COMPRESSION:-true}" == "true" ]] && echo "true" || echo "false")
algorithm = "zstd"

# Heartbeat configuration
[$([ "$is_server" == "true" ] && echo "server" || echo "client").heartbeat_timeout]
enabled = true
interval = $([[ "$network_type" == "iran_detected" ]] && echo "20" || echo "30")
EOF

    log green "✅ Optimized Rathole configuration created"
}

start_hybrid_mode_optimized() {
    log cyan "🔄 Starting optimized hybrid mode (EasyTier + Rathole)..."
    
    # Try EasyTier first with optimizations
    if start_easytier_optimized; then
        log green "✅ Primary tunnel: Optimized EasyTier active"
        echo "ACTIVE_TUNNEL=easytier" > "$STATUS_FILE"
        echo "BACKUP_AVAILABLE=rathole" >> "$STATUS_FILE"
        echo "HYBRID_MODE=optimized" >> "$STATUS_FILE"
        
        # Start backup Rathole instance on different port
        PORT=$((PORT + 10)) start_rathole_optimized &
        return 0
    elif start_rathole_optimized; then
        log green "✅ Backup tunnel: Optimized Rathole active"
        echo "ACTIVE_TUNNEL=rathole" > "$STATUS_FILE"
        echo "BACKUP_AVAILABLE=easytier" >> "$STATUS_FILE"
        echo "HYBRID_MODE=optimized" >> "$STATUS_FILE"
        return 0
    else
        log red "❌ Both optimized tunnels failed to start"
        return 1
    fi
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

install_dependencies_local() {
    log cyan "📦 Installing dependencies from local packages..."
    
    # Check if offline package directory exists
    local offline_dir="./moontun-offline"
    local packages_dir="$offline_dir/packages"
    
    if [[ ! -d "$packages_dir" ]]; then
        offline_dir="../moontun-offline"
        packages_dir="$offline_dir/packages"
    fi
    
    if [[ ! -d "$packages_dir" ]]; then
        log red "Local packages directory not found!"
        log yellow "Expected: ./moontun-offline/packages or ../moontun-offline/packages"
        log blue "Please ensure the offline package is extracted correctly"
        exit 1
    fi
    
    log blue "Found local packages directory: $packages_dir"
    
    # Count available packages
    local package_count=$(ls -1 "$packages_dir"/*.deb 2>/dev/null | wc -l)
    if [[ $package_count -eq 0 ]]; then
        log red "No .deb packages found in $packages_dir"
        exit 1
    fi
    
    log blue "Installing $package_count local packages..."
    
    # Install packages with dpkg
    cd "$packages_dir"
    
    if dpkg -i *.deb 2>/dev/null; then
        log green "✅ All local packages installed successfully"
    else
        log yellow "⚠️  Some packages failed, fixing dependencies..."
        # Try to fix broken dependencies
        apt-get install -f -y >/dev/null 2>&1 || true
        log green "✅ Dependencies fixed"
    fi
    
    # Return to original directory
    cd - >/dev/null
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

install_cores_from_repo() {
    log cyan "📦 Installing tunnel cores from repository..."
    
    # Detect architecture
    local arch=$(uname -m)
    local arch_dir=""
    
    case $arch in
        x86_64) arch_dir="x86_64" ;;
        aarch64) arch_dir="aarch64" ;;
        armv7l) arch_dir="armv7" ;;
        *) 
            log yellow "⚠️  Architecture $arch may not be supported"
            log cyan "Falling back to online installation..."
            install_easytier
            install_rathole
            return
            ;;
    esac
    
    # Check if bin directory exists and has files for our architecture
    if [[ -d "bin/$arch_dir" ]]; then
        log cyan "🔍 Found binaries for $arch architecture"
        
        # Install EasyTier
        if [[ -f "bin/$arch_dir/easytier-core" ]]; then
            cp "bin/$arch_dir/easytier-core" "$DEST_DIR/"
            chmod +x "$DEST_DIR/easytier-core"
            log green "✅ EasyTier core installed from repository"
            
            # Install CLI if available
            if [[ -f "bin/$arch_dir/easytier-cli" ]]; then
                cp "bin/$arch_dir/easytier-cli" "$DEST_DIR/"
                chmod +x "$DEST_DIR/easytier-cli"
                log green "✅ EasyTier CLI installed from repository"
            fi
        fi
        
        # Install Rathole
        if [[ -f "bin/$arch_dir/rathole" ]]; then
            cp "bin/$arch_dir/rathole" "$DEST_DIR/"
            chmod +x "$DEST_DIR/rathole"
            log green "✅ Rathole core installed from repository"
        fi
        
        # Check if we got the essential files
        if [[ -f "$DEST_DIR/easytier-core" ]] || [[ -f "$DEST_DIR/rathole" ]]; then
            log green "🎉 Repository installation completed successfully!"
        else
            log yellow "⚠️  No compatible binaries found, falling back to online installation"
            install_easytier
            install_rathole
        fi
    else
        log yellow "⚠️  No binaries found for $arch architecture in repository"
        log cyan "Falling back to online installation..."
        install_easytier
        install_rathole
    fi
}

install_cores_local() {
    log cyan "🔧 Installing tunnel cores from local binaries..."
    
    # Check if offline binary directory exists
    local offline_dir="./moontun-offline"
    local binaries_dir="$offline_dir/bin"
    
    if [[ ! -d "$binaries_dir" ]]; then
        offline_dir="../moontun-offline"
        binaries_dir="$offline_dir/bin"
    fi
    
    if [[ ! -d "$binaries_dir" ]]; then
        log red "Local binaries directory not found!"
        log yellow "Expected: ./moontun-offline/bin or ../moontun-offline/bin"
        log blue "Please ensure the offline package is extracted correctly"
        exit 1
    fi
    
    log blue "Found local binaries directory: $binaries_dir"
    
    cd "$binaries_dir"
    
    # Install EasyTier binaries
    local easytier_installed=false
    for binary in easytier-*; do
        if [[ -f "$binary" ]] && [[ -x "$binary" ]]; then
            cp "$binary" "$DEST_DIR/"
            chmod +x "$DEST_DIR/$binary"
            log green "✅ Installed $binary"
            easytier_installed=true
        fi
    done
    
    # Install Rathole binaries  
    local rathole_installed=false
    for binary in rathole*; do
        if [[ -f "$binary" ]] && [[ -x "$binary" ]] && [[ "$binary" != *.zip ]]; then
            cp "$binary" "$DEST_DIR/"
            chmod +x "$DEST_DIR/$binary"
            log green "✅ Installed $binary"
            rathole_installed=true
        fi
    done
    
    # Update PATH if needed
    if ! echo "$PATH" | grep -q "/usr/local/bin"; then
        echo 'export PATH="/usr/local/bin:$PATH"' >> /etc/environment
        log blue "📍 Updated system PATH"
    fi
    
    # Return to original directory
    cd - >/dev/null
    
    # Verify installation
    if [[ "$easytier_installed" == true ]]; then
        log green "✅ EasyTier cores installed successfully"
    else
        log yellow "⚠️  No EasyTier binaries found"
    fi
    
    if [[ "$rathole_installed" == true ]]; then
        log green "✅ Rathole cores installed successfully"
    else
        log yellow "⚠️  No Rathole binaries found"
    fi
    
    if [[ "$easytier_installed" == false ]] && [[ "$rathole_installed" == false ]]; then
        log red "❌ No tunnel cores installed!"
        exit 1
    fi
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
        # Clone MoonTun repository for access to binary files and resources
        log cyan "📥 Downloading MoonTun repository..."
        local temp_dir=$(mktemp -d)
        cd "$temp_dir"
        
        if git clone https://github.com/k4lantar4/moontun.git; then
            cd moontun
            log green "✅ Repository downloaded successfully"
            
            # Install tunnel cores from repository
            install_cores_from_repo
            
            # Install MoonTun manager with multiple locations for maximum compatibility
            log cyan "Installing MoonTun manager..."
            
            # Primary installation location
            cp moontun.sh "$DEST_DIR/moontun"
            chmod +x "$DEST_DIR/moontun"
            
            # Backup installation location (in case /usr/local/bin is not in PATH)
            cp moontun.sh "/usr/bin/moontun"
            chmod +x "/usr/bin/moontun"
            
            # Create symbolic link for additional compatibility
            ln -sf "/usr/bin/moontun" "/usr/local/bin/mv" 2>/dev/null || true
            ln -sf "/usr/bin/moontun" "/usr/bin/mv" 2>/dev/null || true
            
            # Copy binary files to system directories for offline access
            if [[ -d "bin" ]]; then
                log cyan "📦 Installing binary files from repository..."
                mkdir -p "/opt/moontun/bin"
                cp -r bin/* "/opt/moontun/bin/" 2>/dev/null || true
                chmod +x "/opt/moontun/bin/"* 2>/dev/null || true
                log green "✅ Binary files installed to /opt/moontun/bin/"
            fi
            
            cd /
            rm -rf "$temp_dir"
        else
            log red "Failed to clone MoonTun repository"
            log cyan "Falling back to online installation..."
            install_easytier_online
            install_rathole_online
            
            # Install MoonTun manager for fallback
            cp "$0" "$DEST_DIR/moontun"
            chmod +x "$DEST_DIR/moontun"
            cp "$0" "/usr/bin/moontun"
            chmod +x "/usr/bin/moontun"
            ln -sf "/usr/bin/moontun" "/usr/local/bin/mv" 2>/dev/null || true
            ln -sf "/usr/bin/moontun" "/usr/bin/mv" 2>/dev/null || true
        fi
    fi
    
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

create_systemd_service() {
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
}

# Function to diagnose installation issues
diagnose_installation() {
    clear
    log purple "🔍 MoonTun Installation Diagnosis"
    echo "================================="
    echo
    
    log cyan "Checking installation status..."
    
    # Check if files exist
    local files_check=true
    echo "📁 File existence check:"
    
    local install_paths=("/usr/bin/moontun" "/usr/local/bin/moontun" "/usr/local/bin/mv" "/usr/bin/mv")
    for path in "${install_paths[@]}"; do
        if [[ -f "$path" ]]; then
            echo "  ✅ $path: Found"
            if [[ -x "$path" ]]; then
                echo "     ✅ Executable: Yes"
            else
                echo "     ❌ Executable: No"
                chmod +x "$path" 2>/dev/null && echo "     🔧 Fixed executable permission"
            fi
        else
            echo "  ❌ $path: Not found"
            files_check=false
        fi
    done
    
    echo
    echo "🌍 PATH environment check:"
    echo "  Current PATH: $PATH"
    
    if [[ ":$PATH:" == *":/usr/local/bin:"* ]]; then
        echo "  ✅ /usr/local/bin is in PATH"
    else
        echo "  ❌ /usr/local/bin is NOT in PATH"
        echo "  🔧 Adding to current session..."
        export PATH="/usr/local/bin:$PATH"
    fi
    
    if [[ ":$PATH:" == *":/usr/bin:"* ]]; then
        echo "  ✅ /usr/bin is in PATH"
    else
        echo "  ❌ /usr/bin is NOT in PATH (unusual)"
    fi
    
    echo
    echo "🔍 Command availability check:"
    if command -v moontun >/dev/null 2>&1; then
        echo "  ✅ 'moontun' command: Available"
        echo "  📍 Location: $(which moontun)"
    else
        echo "  ❌ 'moontun' command: Not available"
    fi
    
    if command -v mv >/dev/null 2>&1; then
        local mv_location=$(which mv)
        if [[ "$mv_location" == "/usr/bin/moontun" ]] || [[ "$mv_location" == "/usr/local/bin/mv" ]]; then
            echo "  ✅ 'mv' command (MoonTun): Available"
            echo "  📍 Location: $mv_location"
        else
            echo "  ⚠️  'mv' command: System default (not MoonTun)"
            echo "  📍 Location: $mv_location"
        fi
    fi
    
    echo
    echo "🛠️  Quick fix options:"
    echo "1) Use direct path: sudo /usr/bin/moontun"
    echo "2) Reload shell: source ~/.bashrc"
    echo "3) Re-install: curl -fsSL https://raw.githubusercontent.com/k4lantar4/moontun/main/moontun.sh | sudo bash -s -- --install"
    echo "4) Manual PATH fix: export PATH=\"/usr/local/bin:\$PATH\""
    echo
    
    if [[ "$files_check" == "false" ]]; then
        log red "❌ Installation appears incomplete. Please re-run installation."
    else
        log green "✅ Files are installed correctly. Issue is likely with PATH."
    fi
    
    press_key
}

setup_log_rotation() {
    log cyan "Setting up log rotation..."
    
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
    
    log green "Log rotation configured"
}

# =============================================================================
# Configuration Functions
# =============================================================================

setup_tunnel() {
    clear
    log purple "🎯 MoonTun Intelligent Setup v2.0"
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
    
    # Detect Iran network conditions first
    log cyan "🌍 Detecting network conditions..."
    local network_type=$(detect_iran_network_conditions)
    
    if [[ "$network_type" == "iran_detected" ]]; then
        log yellow "🇮🇷 Iran network detected! Applying optimized settings..."
        echo "  ✅ Anti-DPI measures will be enabled"
        echo "  ✅ Iran-friendly DNS servers will be used"
        echo "  ✅ Protocol hopping will be activated"
        echo "  ✅ Enhanced encryption will be applied"
        echo
    else
        log green "🌍 Standard network detected"
        echo
    fi
    
    # Tunnel mode selection with intelligent recommendations
    log blue "🚇 Select tunnel mode:"
    if [[ "$network_type" == "iran_detected" ]]; then
        echo "1) EasyTier (🇮🇷 Recommended for Iran - Multi-protocol support)"
        echo "2) Rathole (High performance with TLS obfuscation)"
        echo "3) Hybrid (🌟 Best for Iran - Auto-switching + Anti-DPI)"
        echo
        log yellow "💡 For Iran conditions, Hybrid mode is strongly recommended"
        read -p "Select mode [3]: " mode_choice
        case ${mode_choice:-3} in
            1) TUNNEL_MODE="easytier" ;;
            2) TUNNEL_MODE="rathole" ;;
            3) TUNNEL_MODE="hybrid" ;;
            *) TUNNEL_MODE="hybrid" ;;
        esac
    else
        echo "1) EasyTier (Recommended for stability)"
        echo "2) Rathole (High performance)"
        echo "3) Hybrid (Intelligent switching)"
        echo
        read -p "Select mode [1]: " mode_choice
        case ${mode_choice:-1} in
            1) TUNNEL_MODE="easytier" ;;
            2) TUNNEL_MODE="rathole" ;;
            3) TUNNEL_MODE="hybrid" ;;
            *) TUNNEL_MODE="easytier" ;;
        esac
    fi
    
    # Rathole configuration for non-EasyTier modes
    if [[ "$TUNNEL_MODE" == "rathole" ]] || [[ "$TUNNEL_MODE" == "hybrid" ]]; then
        log blue "🔧 Rathole Configuration:"
        echo "1) Listener (Primary node - receives connections)"
        echo "2) Connector (Secondary node - initiates connections)"
        echo "3) Bidirectional (Auto-reconnect from both sides)"
        echo
        read -p "Select configuration [1-3]: " rathole_node_choice
        
        case ${rathole_node_choice:-3} in
            1) RATHOLE_NODE_TYPE="listener" ;;
            2) RATHOLE_NODE_TYPE="connector" ;;
            3) RATHOLE_NODE_TYPE="bidirectional" ;;
            *) RATHOLE_NODE_TYPE="bidirectional" ;;
        esac
    fi
    
    # Network configuration
    echo
    log blue "🌐 Network Configuration:"
    
    # Local IP configuration
    read -p "Local tunnel IP [10.10.10.1]: " input_local_ip
    LOCAL_IP=${input_local_ip:-10.10.10.1}
    
    # Improved Remote Peers Configuration
    echo
    if [[ "$TUNNEL_MODE" == "easytier" ]] || [[ "$TUNNEL_MODE" == "hybrid" ]]; then
        log blue "🏗️  EasyTier Remote Configuration:"
        echo "💡 Leave empty for Standalone mode (listen for connections)"
        echo "💡 Enter IP(s) for Connected mode - separate multiple IPs with commas"
        echo "💡 Examples: 10.10.10.2 or 10.10.10.2,10.10.10.3"
        read -p "Remote peer IP(s) [empty for standalone]: " input_remote_ips
        
        if [[ -z "$input_remote_ips" ]]; then
            # Standalone mode - listen for connections
            EASYTIER_NODE_TYPE="standalone"
            REMOTE_SERVER=""
            REMOTE_IP=""
            log cyan "💡 Standalone mode: Will listen for incoming connections"
        else
            # Connected mode - connect to peers
            EASYTIER_NODE_TYPE="connected"
            REMOTE_IP="$input_remote_ips"
            REMOTE_SERVER="$input_remote_ips"
            log cyan "💡 Connected mode: Will connect to peer(s): $input_remote_ips"
        fi
    else
        # For non-EasyTier modes, remote server is still required
        log blue "🌐 Remote Peers Configuration:"
        echo "Enter remote servers (comma-separated for multiple peers):"
        read -p "Remote server(s): " REMOTE_SERVER
        if [[ -z "$REMOTE_SERVER" ]]; then
            log red "At least one remote server is required for $TUNNEL_MODE mode"
            return 1
        fi
        
        read -p "Remote tunnel IP [10.10.10.2]: " input_remote_ip
        REMOTE_IP=${input_remote_ip:-10.10.10.2}
    fi
    
    read -p "Tunnel port [1377]: " input_port
    PORT=${input_port:-1377}
    
    # Protocol selection with Iran-aware recommendations
    echo
    log blue "🔗 Select primary protocol:"
    if [[ "$network_type" == "iran_detected" ]]; then
        echo "1) TCP (🇮🇷 Best for Iran - DPI resistant)"
        echo "2) WebSocket (🌟 Excellent for Iran - HTTP camouflage)"
        echo "3) UDP (Good speed but may be filtered)"
        echo "4) QUIC (Modern but may trigger DPI)"
        echo
        log yellow "💡 For Iran, TCP or WebSocket are recommended"
        read -p "Protocol [1]: " protocol_choice
        case ${protocol_choice:-1} in
            1) PROTOCOL="tcp" ;;
            2) PROTOCOL="ws" ;;
            3) PROTOCOL="udp" ;;
            4) PROTOCOL="quic" ;;
            *) PROTOCOL="tcp" ;;
        esac
    else
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
    fi
    
    # Generate network secret
    NETWORK_SECRET=$(generate_secret)
    log cyan "🔐 Generated network secret: $NETWORK_SECRET"
    read -p "Custom secret (or Enter to use generated): " custom_secret
    NETWORK_SECRET=${custom_secret:-$NETWORK_SECRET}
    
    # Advanced options with Iran-aware defaults
    echo
    log blue "⚙️  Advanced Options:"
    
    if [[ "$network_type" == "iran_detected" ]]; then
        log yellow "🇮🇷 Iran-optimized defaults will be applied"
        
        read -p "Enable automatic failover? [Y/n]: " enable_failover
        FAILOVER_ENABLED=$([[ ! "$enable_failover" =~ ^[Nn]$ ]] && echo "true" || echo "false")
        
        read -p "Enable auto protocol switching? [Y/n]: " enable_switching
        AUTO_SWITCH=$([[ ! "$enable_switching" =~ ^[Nn]$ ]] && echo "true" || echo "false")
        
        read -p "Enable geographic load balancing? [Y/n]: " enable_geo_balancing
        GEO_BALANCING_ENABLED=$([[ ! "$enable_geo_balancing" =~ ^[Nn]$ ]] && echo "true" || echo "false")
        
        read -p "Enable adaptive tunneling (port/protocol hopping)? [Y/n]: " enable_adaptive
        ADAPTIVE_TUNNELING=$([[ ! "$enable_adaptive" =~ ^[Nn]$ ]] && echo "true" || echo "false")
        
        # Force optimal settings for Iran
        MULTI_THREAD="true"
        COMPRESSION="true"
        ENCRYPTION="true"
        TLS_OBFUSCATION="true"
        
        log green "✅ Iran optimizations automatically enabled"
    else
        read -p "Enable automatic failover? [Y/n]: " enable_failover
        FAILOVER_ENABLED=$([[ ! "$enable_failover" =~ ^[Nn]$ ]] && echo "true" || echo "false")
        
        read -p "Enable auto protocol switching? [Y/n]: " enable_switching
        AUTO_SWITCH=$([[ ! "$enable_switching" =~ ^[Nn]$ ]] && echo "true" || echo "false")
        
        read -p "Enable geographic load balancing? [Y/n]: " enable_geo_balancing
        GEO_BALANCING_ENABLED=$([[ ! "$enable_geo_balancing" =~ ^[Nn]$ ]] && echo "true" || echo "false")
        
        # Performance tuning options
        echo
        log blue "🚀 Performance Options:"
        read -p "Enable multi-threading? [Y/n]: " enable_multi_thread
        MULTI_THREAD=$([[ ! "$enable_multi_thread" =~ ^[Nn]$ ]] && echo "true" || echo "false")
        
        read -p "Enable compression? [Y/n]: " enable_compression
        COMPRESSION=$([[ ! "$enable_compression" =~ ^[Nn]$ ]] && echo "true" || echo "false")
        
        read -p "Enable encryption? [Y/n]: " enable_encryption
        ENCRYPTION=$([[ ! "$enable_encryption" =~ ^[Nn]$ ]] && echo "true" || echo "false")
    fi
    
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
# MoonTun Configuration v2.0 - Generated $(date)
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

# Network Detection
NETWORK_TYPE="$network_type"
IRAN_NETWORK_DETECTED="$([[ "$network_type" == "iran_detected" ]] && echo "true" || echo "false")"

# Node Types
EASYTIER_NODE_TYPE="${EASYTIER_NODE_TYPE:-connected}"
RATHOLE_NODE_TYPE="${RATHOLE_NODE_TYPE:-bidirectional}"

# Performance Options
MULTI_THREAD="${MULTI_THREAD:-true}"
COMPRESSION="${COMPRESSION:-true}"
ENCRYPTION="${ENCRYPTION:-true}"

# Advanced Features
GEO_BALANCING_ENABLED="${GEO_BALANCING_ENABLED:-false}"
ADAPTIVE_TUNNELING="${ADAPTIVE_TUNNELING:-false}"
TLS_OBFUSCATION="${TLS_OBFUSCATION:-false}"

# Protocol Configuration
ENABLED_PROTOCOLS="${ENABLED_PROTOCOLS:-udp,tcp,ws,quic}"

# Iran-specific Settings
$(if [[ "$network_type" == "iran_detected" ]]; then
echo "BACKUP_DNS=\"178.22.122.100,185.51.200.2,10.202.10.10,10.202.10.11\""
echo "ADDITIONAL_PORTS=\"443,80,53,8080,8443,1194,1723\""
echo "TCP_WINDOW_SCALING=\"true\""
echo "TCP_CONGESTION_CONTROL=\"bbr\""
echo "KEEP_ALIVE_ENABLED=\"true\""
echo "KEEP_ALIVE_INTERVAL=\"30\""
echo "PACKET_FRAGMENTATION=\"true\""
fi)
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
    [[ -n "$NETWORK_SECRET" ]] || { log red "NETWORK_SECRET is empty"; return 1; }
    [[ -n "$PROTOCOL" ]] || { log red "PROTOCOL is empty"; return 1; }
    [[ -n "$PORT" ]] || { log red "PORT is empty"; return 1; }
    
    # For standalone EasyTier mode, REMOTE_IP and REMOTE_SERVER can be empty
    if [[ "$TUNNEL_MODE" == "easytier" ]] && [[ "${EASYTIER_NODE_TYPE:-}" == "standalone" ]]; then
        log blue "ℹ️  Standalone mode detected - skipping remote validation"
    else
        # For connected modes, validate remote configuration
        [[ -n "$REMOTE_IP" ]] || { log red "REMOTE_IP is empty"; return 1; }
        [[ -n "$REMOTE_SERVER" ]] || { log red "REMOTE_SERVER is empty"; return 1; }
        
        # Validate remote IP format (can be comma-separated list)
        local IFS=','
        local remote_ips=($REMOTE_IP)
        for ip in "${remote_ips[@]}"; do
            ip=$(echo "$ip" | xargs) # trim whitespace
            if ! [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                log red "Invalid REMOTE_IP format: $ip"; return 1
            fi
        done
    fi
    
    # Validate local IP format
    if ! [[ "$LOCAL_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        log red "Invalid LOCAL_IP format"; return 1
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
    log cyan "🔄 Installing from MoonTun repository..."
    
    # First check if we have local binaries from installation
    if [[ -d "/opt/moontun/bin" ]]; then
        log cyan "📦 Using cached repository binaries..."
        
        local arch=$(uname -m)
        local arch_dir=""
        
        case $arch in
            x86_64) arch_dir="x86_64" ;;
            aarch64) arch_dir="aarch64" ;;
            armv7l) arch_dir="armv7" ;;
            *) log red "Unsupported architecture: $arch"; press_key; return 1 ;;
        esac
        
        if [[ -d "/opt/moontun/bin/$arch_dir" ]]; then
            # Install EasyTier
            if [[ -f "/opt/moontun/bin/$arch_dir/easytier-core" ]]; then
                cp "/opt/moontun/bin/$arch_dir/easytier-core" "$DEST_DIR/"
                cp "/opt/moontun/bin/$arch_dir/easytier-cli" "$DEST_DIR/" 2>/dev/null || true
                chmod +x "$DEST_DIR/easytier-core" "$DEST_DIR/easytier-cli" 2>/dev/null || true
                log green "✅ EasyTier installed from cached repository"
            fi
            
            # Install Rathole
            if [[ -f "/opt/moontun/bin/$arch_dir/rathole" ]]; then
                cp "/opt/moontun/bin/$arch_dir/rathole" "$DEST_DIR/"
                chmod +x "$DEST_DIR/rathole"
                log green "✅ Rathole installed from cached repository"
            fi
            
            log green "🎉 Installation from cached repository completed!"
            press_key
            return
        fi
    fi
    
    # If no cached binaries, download fresh from repository
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    log cyan "📥 Cloning MoonTun repository..."
    if git clone https://github.com/k4lantar4/moontun.git; then
        cd moontun
        
        # Check for prebuilt binaries in bin directory
        if [[ -d "bin" ]]; then
            log cyan "📦 Installing prebuilt binaries..."
            
            local arch=$(uname -m)
            local arch_dir=""
            
            case $arch in
                x86_64) arch_dir="x86_64" ;;
                aarch64) arch_dir="aarch64" ;;
                armv7l) arch_dir="armv7" ;;
                *) log red "Unsupported architecture: $arch"; cd /; rm -rf "$temp_dir"; press_key; return 1 ;;
            esac
            
            if [[ -d "bin/$arch_dir" ]]; then
                # Install EasyTier
                if [[ -f "bin/$arch_dir/easytier-core" ]]; then
                    cp "bin/$arch_dir/easytier-core" "$DEST_DIR/"
                    cp "bin/$arch_dir/easytier-cli" "$DEST_DIR/" 2>/dev/null || true
                    chmod +x "$DEST_DIR/easytier-core" "$DEST_DIR/easytier-cli" 2>/dev/null || true
                    log green "✅ EasyTier installed from repository"
                fi
                
                # Install Rathole
                if [[ -f "bin/$arch_dir/rathole" ]]; then
                    cp "bin/$arch_dir/rathole" "$DEST_DIR/"
                    chmod +x "$DEST_DIR/rathole"
                    log green "✅ Rathole installed from repository"
                fi
                
                # Cache binaries for future use
                mkdir -p "/opt/moontun/bin"
                cp -r bin/* "/opt/moontun/bin/" 2>/dev/null || true
                chmod +x "/opt/moontun/bin/"*/* 2>/dev/null || true
                
                log green "🎉 Installation from MoonTun repository completed!"
            else
                log red "No prebuilt binaries for $arch architecture"
                log cyan "Falling back to online installation..."
                install_easytier_online
                install_rathole_online
            fi
        else
            log yellow "No bin directory found, falling back to online installation"
            install_easytier_online
            install_rathole_online
        fi
    else
        log red "Failed to clone MoonTun repository"
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
    
    # Check if we have cached repository files first
    if [[ -d "/opt/moontun/bin" ]]; then
        log blue "💡 MoonTun repository files detected. Install from:"
        echo "1) Cached repository files (/opt/moontun/bin)"
        echo "2) Custom local directory"
        echo
        read -p "Select option [1-2]: " source_choice
        
        if [[ "$source_choice" == "1" ]]; then
            local arch=$(uname -m)
            local arch_dir=""
            
            case $arch in
                x86_64) arch_dir="x86_64" ;;
                aarch64) arch_dir="aarch64" ;;
                armv7l) arch_dir="armv7" ;;
                *) 
                    log red "Unsupported architecture: $arch"
                    press_key
                    return 1
                    ;;
            esac
            
            local local_path="/opt/moontun/bin/$arch_dir"
            if [[ -d "$local_path" ]]; then
                log cyan "🔍 Using cached repository files for $arch"
            else
                log red "No cached files for $arch architecture"
                press_key
                return 1
            fi
        else
            read -p "📂 Enter path to local files directory: " local_path
            
            if [[ ! -d "$local_path" ]]; then
                log red "Directory not found: $local_path"
                press_key
                return 1
            fi
        fi
    else
        read -p "📂 Enter path to local files directory: " local_path
        
        if [[ ! -d "$local_path" ]]; then
            log red "Directory not found: $local_path"
            press_key
            return 1
        fi
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
    log purple "🚀 Connecting MoonTun Intelligent Tunnel..."
    
    # Load configuration
    if [[ ! -f "$MAIN_CONFIG" ]]; then
        log red "No configuration found. Run: moontun setup"
        return 1
    fi
    
    source "$MAIN_CONFIG"
    
    # Apply Iran-specific network optimizations if detected
    if [[ "${IRAN_NETWORK_DETECTED:-false}" == "true" ]]; then
        log cyan "🇮🇷 Applying Iran network optimizations..."
        setup_iran_dns_optimization
        optimize_tcp_settings
    fi
    
    # Setup geographic load balancing if enabled
    if [[ "${GEO_BALANCING_ENABLED:-false}" == "true" ]] && [[ -n "$REMOTE_SERVER" ]]; then
        log cyan "🌍 Setting up geographic load balancing..."
        if setup_geo_load_balancing; then
            # Reload config after geo optimization
            source "$MAIN_CONFIG"
            schedule_geo_rebalancing
        fi
    fi
    
    # Start tunnel based on mode using optimized functions
    case "$TUNNEL_MODE" in
        "easytier")
            start_easytier_optimized
            ;;
        "rathole")
            start_rathole_optimized
            ;;
        "hybrid")
            start_hybrid_mode_optimized
            ;;
        *)
            log red "Unknown tunnel mode: $TUNNEL_MODE"
            return 1
            ;;
    esac
    
    # Start enhanced monitoring if enabled
    if [[ "$FAILOVER_ENABLED" == "true" ]]; then
        enhanced_health_monitoring
    fi
    
    # Start adaptive tunneling for Iran conditions
    if [[ "${ADAPTIVE_TUNNELING:-false}" == "true" ]] && [[ "${IRAN_NETWORK_DETECTED:-false}" == "true" ]]; then
        log cyan "🔄 Starting adaptive anti-censorship tunneling..."
        start_adaptive_tunneling
    fi
    
    # Setup multi-path routing if multiple servers
    if [[ -n "$REMOTE_SERVER" ]] && [[ "$REMOTE_SERVER" == *","* ]]; then
        log cyan "🌐 Setting up multi-path routing..."
        setup_multipath_routing
    fi
    
    log green "🎉 MoonTun connected successfully with all optimizations!"
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
    if [[ "${EASYTIER_NODE_TYPE:-connected}" == "standalone" ]]; then
        log cyan "🏗️  Starting as Standalone Node..."
        
        # Standalone mode: Listen on both IPv4 and IPv6
        listeners="--listeners ${PROTOCOL}://[::]:${PORT} ${PROTOCOL}://0.0.0.0:${PORT}"
        
        # Standalone mode: Listen on 0.0.0.0 with local IP in virtual network
        easytier_cmd="$easytier_cmd -i $LOCAL_IP"
        
        log cyan "💡 Standalone mode: Listening on ${PROTOCOL}://0.0.0.0:${PORT} and ${PROTOCOL}://[::]:${PORT}"
        log cyan "💡 Waiting for nodes to connect..."
    else
        log cyan "🔗 Starting as Connected Node..."
        
        if [[ -z "$REMOTE_SERVER" ]]; then
            log red "Remote server(s) required for connected mode"
            return 1
        fi
        
        # Connected mode: Listen on both IPv4 and IPv6 + connect to peers
        listeners="--listeners ${PROTOCOL}://[::]:${PORT} ${PROTOCOL}://0.0.0.0:${PORT}"
        
        # Multi-peer support: Split comma-separated servers
        local peer_list=""
        IFS=',' read -ra SERVERS <<< "$REMOTE_SERVER"
        for server in "${SERVERS[@]}"; do
            server=$(echo "$server" | xargs)  # trim whitespace
            if [[ -n "$server" ]]; then
                peer_list="$peer_list --peers ${PROTOCOL}://${server}:${PORT}"
            fi
        done
        peers="$peer_list"
        
        # Connected mode: Connect to multiple peers
        easytier_cmd="$easytier_cmd -i $LOCAL_IP"
        
        log cyan "🎯 Connecting to peers: $REMOTE_SERVER"
        log cyan "💡 Also listening on ${PROTOCOL}://0.0.0.0:${PORT} and ${PROTOCOL}://[::]:${PORT}"
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
        echo "NODE_TYPE=${EASYTIER_NODE_TYPE:-connected}" >> "$STATUS_FILE"
        log green "✅ EasyTier started successfully as ${EASYTIER_NODE_TYPE:-connected}"
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
    case "${RATHOLE_NODE_TYPE:-bidirectional}" in
        "listener")
            log cyan "🔧 Starting as Rathole Listener..."
            create_rathole_server_config
            local config_flag="-s"
            log cyan "💡 Listener mode: Waiting for connections on port $PORT"
            ;;
        "connector") 
            log cyan "🔗 Starting as Rathole Connector..."
            
            if [[ -z "$REMOTE_SERVER" ]]; then
                log red "Remote server required for connector mode"
                return 1
            fi
            
            create_rathole_client_config
            local config_flag="-c"
            log cyan "🎯 Connecting to: $REMOTE_SERVER:$PORT"
            ;;
        "bidirectional"|*)
            log cyan "🔄 Starting Rathole in Bidirectional mode..."
            
            # Try as client first, then server on failure
            if [[ -n "$REMOTE_SERVER" ]]; then
                create_rathole_client_config
                local config_flag="-c"
                log cyan "🎯 Primary: Connecting to $REMOTE_SERVER:$PORT"
                log cyan "💡 Fallback: Will listen on port $PORT if connection fails"
            else
                create_rathole_server_config
                local config_flag="-s"
                log cyan "💡 Primary: Listening on port $PORT"
            fi
            ;;
    esac
    
    # Kill existing process
    pkill -f "rathole" 2>/dev/null || true
    sleep 2
    
    # Start Rathole with appropriate config
    nohup "$DEST_DIR/rathole" $config_flag "$RATHOLE_CONFIG" \
        > "$LOG_DIR/rathole.log" 2>&1 &
    
    sleep 3
    
    if pgrep -f "rathole" > /dev/null; then
        echo "ACTIVE_TUNNEL=rathole" > "$STATUS_FILE"
        echo "NODE_TYPE=${RATHOLE_NODE_TYPE:-bidirectional}" >> "$STATUS_FILE"
        log green "✅ Rathole started successfully as ${RATHOLE_NODE_TYPE:-bidirectional}"
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
    
    # Show node type and configuration
    if [[ "$TUNNEL_MODE" == "easytier" ]]; then
        if [[ "${EASYTIER_NODE_TYPE:-connected}" == "standalone" ]]; then
            echo "  🏗️  EasyTier Mode: Standalone (Listening for connections)"
            echo "  🎧 Listeners: ${PROTOCOL}://[::]:${PORT} and ${PROTOCOL}://0.0.0.0:${PORT}"
        else
            echo "  🔗 EasyTier Mode: Connected (Connecting to peers)"
            echo "  🎯 Remote peer IPs: $REMOTE_IP"
            echo "  🎧 Listeners: ${PROTOCOL}://[::]:${PORT} and ${PROTOCOL}://0.0.0.0:${PORT}"
        fi
    else
        echo "  🎯 Remote tunnel IP: $REMOTE_IP"
    fi
    
    echo "  🔌 Protocol: $PROTOCOL"
    echo "  🚪 Port: $PORT"
    echo "  🔐 Secret: $NETWORK_SECRET"
    echo "  📡 Public IP: $(get_public_ip)"
    
    # Show Iran detection status
    if [[ "${IRAN_NETWORK_DETECTED:-false}" == "true" ]]; then
        echo "  🇮🇷 Iran Network: Detected (${IRAN_CONFIDENCE_SCORE:-0}% confidence)"
        echo "  🛡️  Optimizations: Anti-DPI, DNS bypass, Protocol hopping"
    else
        echo "  🌍 Network Type: Standard"
    fi
    
    # Show connection instructions
    if [[ "$TUNNEL_MODE" == "easytier" ]] && [[ "${EASYTIER_NODE_TYPE:-connected}" == "standalone" ]]; then
        echo
        log blue "📢 Connection Instructions for Other Nodes:"
        echo "  Use this IP/Port to connect: $(get_public_ip):${PORT}"
        echo "  Protocol: ${PROTOCOL}"
        echo "  Example command for connecting node:"
        echo "    --peers ${PROTOCOL}://$(get_public_ip):${PORT}"
    fi
    
    # Show active features
    echo
    echo "  🔧 Active Features:"
    if [[ "${GEO_BALANCING_ENABLED:-false}" == "true" ]]; then
        echo "    ✅ Geographic Load Balancing"
    fi
    if [[ "${OPTIMIZED_MODE:-false}" == "true" ]]; then
        echo "    ✅ Optimized Tunnel Mode"
    fi
    if [[ "${HYBRID_MODE:-}" == "optimized" ]]; then
        echo "    ✅ Hybrid Mode (EasyTier + Rathole)"
    fi
    if [[ "${ENCRYPTION:-true}" == "true" ]]; then
        echo "    ✅ Encryption Enabled"
    fi
    if [[ "${MULTI_THREAD:-true}" == "true" ]]; then
        echo "    ✅ Multi-threading Enabled"
    fi
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
    log cyan "Stopping MoonTun..."
    
    # Stop all tunnel processes gracefully
    pkill -TERM -f "easytier-core" 2>/dev/null || true
    pkill -TERM -f "rathole" 2>/dev/null || true
    
    # Stop all monitoring and management processes
    pkill -TERM -f "moontun.*monitor" 2>/dev/null || true
    pkill -TERM -f "adaptive_hop" 2>/dev/null || true
    pkill -TERM -f "geo_scheduler" 2>/dev/null || true
    pkill -TERM -f "path_quality_monitor" 2>/dev/null || true
    
    # Wait for graceful shutdown
    sleep 5
    
    # Force kill if still running
    pkill -KILL -f "easytier-core" 2>/dev/null || true
    pkill -KILL -f "rathole" 2>/dev/null || true
    pkill -KILL -f "moontun.*monitor" 2>/dev/null || true
    pkill -KILL -f "adaptive_hop" 2>/dev/null || true
    pkill -KILL -f "geo_scheduler" 2>/dev/null || true
    
    # Stop all monitoring services
    for pid_file in "$CONFIG_DIR"/*.pid; do
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file" 2>/dev/null)
            if [[ -n "$pid" ]]; then
                kill "$pid" 2>/dev/null || true
            fi
            rm -f "$pid_file"
        fi
    done
    
    # Comprehensive network cleanup
    comprehensive_network_cleanup
    
    # Restore original DNS if modified
    restore_original_dns
    
    # Clear status and PID files
    rm -f "$STATUS_FILE" "$CONFIG_DIR/moontun.pid"
    rm -f "$CONFIG_DIR"/tunnel_*.pid
    rm -f "$CONFIG_DIR"/CRITICAL_FAILURE_*
    
    log green "MoonTun stopped and completely cleaned up"
}

network_cleanup() {
    log cyan "Performing basic network cleanup..."
    
    # Load configuration for cleanup
    if [[ -f "$MAIN_CONFIG" ]]; then
        source "$MAIN_CONFIG"
    fi
    
    # Clean up virtual interfaces created by tunnels
    local interfaces_to_clean=(
        "easytier0"
        "moontun0" 
        "rathole0"
        "tun-moontun"
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
    
    log green "Basic network cleanup completed"
}

comprehensive_network_cleanup() {
    log cyan "Performing comprehensive network cleanup..."
    
    # Basic cleanup first
    network_cleanup
    
    # Advanced cleanup for new features
    cleanup_multipath_routing
    cleanup_geo_balancing
    cleanup_adaptive_tunneling
    cleanup_enhanced_monitoring
    
    # Emergency cleanup
    cleanup_emergency_network
    
    # Clean up all MoonTun-related network configuration
    cleanup_all_moontun_network
    
    log green "Comprehensive network cleanup completed"
}

cleanup_multipath_routing() {
    log cyan "🧹 Cleaning up multi-path routing..."
    
    # Clean up all custom routing tables (100-120)
    for table_id in {100..120}; do
        ip route flush table "$table_id" 2>/dev/null || true
        ip rule del table "$table_id" 2>/dev/null || true
    done
    
    # Clean up policy routing rules by fwmark
    for mark in {1..20}; do
        ip rule del fwmark "$mark" 2>/dev/null || true
    done
    
    # Clean up ECMP routes
    ip route del default 2>/dev/null || true
    
    log green "✅ Multi-path routing cleaned up"
}

cleanup_geo_balancing() {
    log cyan "🧹 Cleaning up geographic load balancing..."
    
    # Remove geo balancing status
    sed -i '/GEO_BALANCING_ENABLED/d' "$STATUS_FILE" 2>/dev/null || true
    sed -i '/LAST_GEO_UPDATE/d' "$STATUS_FILE" 2>/dev/null || true
    sed -i '/TOP_SERVERS/d' "$STATUS_FILE" 2>/dev/null || true
    
    # Stop geo scheduler
    pkill -f "geo_scheduler" 2>/dev/null || true
    rm -f "$CONFIG_DIR/geo_scheduler.pid"
    
    log green "✅ Geographic load balancing cleaned up"
}

cleanup_adaptive_tunneling() {
    log cyan "🧹 Cleaning up adaptive tunneling..."
    
    # Stop adaptive processes
    pkill -f "adaptive_hop" 2>/dev/null || true
    pkill -f "moontun_path_monitor" 2>/dev/null || true
    
    # Remove PID files
    rm -f "$CONFIG_DIR/hopping.pid"
    rm -f "$CONFIG_DIR/path_monitor.pid"
    
    # Clean up emergency tunnel if exists
    if [[ -f "$CONFIG_DIR/emergency_tunnel.pid" ]]; then
        local emergency_pid=$(cat "$CONFIG_DIR/emergency_tunnel.pid" 2>/dev/null)
        if [[ -n "$emergency_pid" ]]; then
            kill "$emergency_pid" 2>/dev/null || true
        fi
        rm -f "$CONFIG_DIR/emergency_tunnel.pid"
    fi
    
    log green "✅ Adaptive tunneling cleaned up"
}

cleanup_enhanced_monitoring() {
    log cyan "🧹 Cleaning up enhanced monitoring..."
    
    # Stop enhanced monitor
    pkill -f "moontun_enhanced_monitor" 2>/dev/null || true
    rm -f "$CONFIG_DIR/enhanced_monitor.pid"
    
    # Clean up health metrics
    if [[ -f "$LOG_DIR/health_metrics.log" ]]; then
        # Keep only last 1000 lines to prevent log bloat
        tail -1000 "$LOG_DIR/health_metrics.log" > "$LOG_DIR/health_metrics.log.tmp" 2>/dev/null || true
        mv "$LOG_DIR/health_metrics.log.tmp" "$LOG_DIR/health_metrics.log" 2>/dev/null || true
    fi
    
    log green "✅ Enhanced monitoring cleaned up"
}

cleanup_all_moontun_network() {
    log cyan "🧹 Cleaning up all MoonTun network configurations..."
    
    # Remove all MoonTun-related iptables rules
    iptables-save 2>/dev/null | grep -v "MOONTUN" | iptables-restore 2>/dev/null || true
    
    # Clean up all tunnel interfaces
    local all_interfaces=$(ip link show | grep -o "tun[0-9]*\|easytier[0-9]*\|rathole[0-9]*\|moontun[0-9]*" 2>/dev/null || true)
    for iface in $all_interfaces; do
        if [[ -n "$iface" ]]; then
            ip link delete "$iface" 2>/dev/null || true
            log blue "Removed interface: $iface"
        fi
    done
    
    # Reset TCP settings to defaults if they were modified
    reset_tcp_settings
    
    log green "✅ All MoonTun network configurations cleaned up"
}

reset_tcp_settings() {
    log cyan "🔧 Resetting TCP settings to defaults..."
    
    # Reset TCP congestion control to default
    echo 'cubic' > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || true
    
    # Reset TCP window scaling
    echo 1 > /proc/sys/net/ipv4/tcp_window_scaling 2>/dev/null || true
    
    # Reset TCP keepalive settings to defaults
    echo 7200 > /proc/sys/net/ipv4/tcp_keepalive_time 2>/dev/null || true
    echo 75 > /proc/sys/net/ipv4/tcp_keepalive_intvl 2>/dev/null || true
    echo 9 > /proc/sys/net/ipv4/tcp_keepalive_probes 2>/dev/null || true
    
    log green "✅ TCP settings reset to defaults"
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
    log purple "🔄 Intelligent Protocol Switching"
    echo
    
    if [[ ! -f "$MAIN_CONFIG" ]]; then
        log red "No configuration found"
        return 1
    fi
    
    source "$MAIN_CONFIG"
    
    log blue "Current protocol: $PROTOCOL"
    echo
    
    # Load enabled protocols for current tunnel mode
    load_enabled_protocols
    show_protocol_menu
    
    read -p "Select new protocol [1-5]: " protocol_choice
    
    local new_protocol
    case $protocol_choice in
        1) new_protocol="udp" ;;
        2) new_protocol="tcp" ;;
        3) new_protocol="ws" ;;
        4) new_protocol="quic" ;;
        5) new_protocol="wg" ;;
        *) log red "Invalid option"; return 1 ;;
    esac
    
    # Check if protocol is enabled for current mode
    if ! is_protocol_enabled "$new_protocol"; then
        log red "Protocol $new_protocol is not enabled for $TUNNEL_MODE mode"
        return 1
    fi
    
    if [[ "$new_protocol" == "$PROTOCOL" ]]; then
        log yellow "Already using $PROTOCOL protocol"
        return 0
    fi
    
    log cyan "Testing $new_protocol protocol stability..."
    
    # Test new protocol before switching
    if test_protocol_stability "$new_protocol"; then
        log green "Protocol $new_protocol passed stability test"
        apply_protocol_switch "$new_protocol"
    else
        log red "Protocol $new_protocol failed stability test. Keeping current protocol."
    fi
}

load_enabled_protocols() {
    # Default enabled protocols per tunnel mode
    case "$TUNNEL_MODE" in
        "easytier")
            ENABLED_PROTOCOLS="udp,tcp,ws,quic,wg"
            ;;
        "rathole")
            ENABLED_PROTOCOLS="udp,tcp,ws"
            ;;
        "hybrid")
            ENABLED_PROTOCOLS="udp,tcp,ws,quic"
            ;;
        *)
            ENABLED_PROTOCOLS="udp,tcp"
            ;;
    esac
    
    # Load custom enabled protocols from config if exists
    if grep -q "ENABLED_PROTOCOLS=" "$MAIN_CONFIG" 2>/dev/null; then
        local custom_protocols=$(grep "ENABLED_PROTOCOLS=" "$MAIN_CONFIG" | cut -d'=' -f2 | tr -d '"')
        if [[ -n "$custom_protocols" ]]; then
            ENABLED_PROTOCOLS="$custom_protocols"
        fi
    fi
}

show_protocol_menu() {
    echo "Available protocols for $TUNNEL_MODE mode:"
    
    local protocols=(udp tcp ws quic wg)
    local descriptions=("Fast, low-latency" "Reliable, ordered" "HTTP-compatible" "Modern, fast" "Secure VPN")
    
    for i in "${!protocols[@]}"; do
        local proto="${protocols[$i]}"
        local desc="${descriptions[$i]}"
        local status=""
        
        if [[ "$proto" == "$PROTOCOL" ]]; then
            status="✅ Current"
        elif is_protocol_enabled "$proto"; then
            status="🟢 Available"  
        else
            status="🔴 Disabled"
        fi
        
        echo "$((i+1))) $proto - $desc ($status)"
    done
    echo
}

is_protocol_enabled() {
    local protocol="$1"
    [[ ",$ENABLED_PROTOCOLS," == *",$protocol,"* ]]
}

test_protocol_stability() {
    local test_protocol="$1"
    log cyan "🧪 Running 10-minute stability test for $test_protocol protocol..."
    
    # Backup current config
    local backup_protocol="$PROTOCOL"
    
    # Temporarily switch to test protocol
    sed -i "s/PROTOCOL=\".*\"/PROTOCOL=\"$test_protocol\"/" "$MAIN_CONFIG"
    
    # Start test tunnel
    log cyan "Starting test tunnel..."
    restart_tunnel
    
    # Wait for initial connection
    sleep 10
    
    local test_passed=true
    local test_duration=600  # 10 minutes in seconds
    local check_interval=30  # Check every 30 seconds
    local checks_done=0
    local total_checks=$((test_duration / check_interval))
    
    log cyan "Testing stability for $((test_duration / 60)) minutes..."
    
    while [[ $checks_done -lt $total_checks ]]; do
        local progress=$((checks_done * 100 / total_checks))
        echo -ne "\rProgress: $progress% (${checks_done}/${total_checks} checks)"
        
        # Perform connectivity test
        if ! check_tunnel_health; then
            log red "\nStability test failed at check $((checks_done + 1))"
            test_passed=false
            break
        fi
        
        sleep $check_interval
        ((checks_done++))
    done
    
    echo  # New line after progress
    
    # Restore original protocol
    sed -i "s/PROTOCOL=\".*\"/PROTOCOL=\"$backup_protocol\"/" "$MAIN_CONFIG"
    
    if [[ "$test_passed" == "true" ]]; then
        log green "✅ Stability test passed! Protocol $test_protocol is stable."
        return 0
    else
        log red "❌ Stability test failed! Protocol $test_protocol is unstable."
        restart_tunnel  # Restart with original protocol
        return 1
    fi
}

apply_protocol_switch() {
    local new_protocol="$1"
    
    log cyan "Applying protocol switch to $new_protocol..."
    
    # Update configuration permanently
    sed -i "s/PROTOCOL=\".*\"/PROTOCOL=\"$new_protocol\"/" "$MAIN_CONFIG"
    
    # Restart tunnel with new protocol
    restart_tunnel
    
    log green "Protocol switched to $new_protocol successfully!"
    
    # Save switch to history
    echo "$(date): Protocol switched from $PROTOCOL to $new_protocol" >> "$LOG_DIR/protocol_switches.log"
}

# =============================================================================
# Multi-Peer Configuration Functions
# =============================================================================

configure_multi_peer() {
    clear
    log purple "🌐 Multi-Peer Configuration"
    echo "================================="
    echo
    
    if [[ ! -f "$MAIN_CONFIG" ]]; then
        log red "No configuration found. Run setup first."
        press_key
        return 1
    fi
    
    source "$MAIN_CONFIG"
    
    log cyan "Current Configuration:"
    echo "  Tunnel Mode: $TUNNEL_MODE"
    echo "  Current Peers: $REMOTE_SERVER"
    echo
    
    case "$TUNNEL_MODE" in
        "easytier"|"hybrid")
            configure_easytier_multi_peer
            ;;
        "rathole")
            configure_rathole_multi_peer
            ;;
        *)
            log red "Multi-peer not supported for mode: $TUNNEL_MODE"
            press_key
            return 1
            ;;
    esac
}

configure_easytier_multi_peer() {
    log cyan "🚇 EasyTier Multi-Peer Configuration"
    echo
    
    log blue "Multi-peer options:"
    echo "1) Add new peer server"
    echo "2) Remove peer server"
    echo "3) Replace all peers"
    echo "4) Test peer connectivity"
    echo "0) Back"
    echo
    
    read -p "Select option [1-4]: " multi_choice
    
    case $multi_choice in
        1) add_peer_server ;;
        2) remove_peer_server ;;
        3) replace_all_peers ;;
        4) test_peer_connectivity ;;
        0) return ;;
        *) log red "Invalid option"; sleep 1; configure_easytier_multi_peer ;;
    esac
}

configure_rathole_multi_peer() {
    log cyan "⚡ Rathole Multi-Instance Configuration"
    echo
    
    log yellow "⚠️  Note: Rathole multi-peer requires multiple service instances"
    echo
    
    log blue "Multi-instance options:"
    echo "1) Configure multiple service ports"
    echo "2) Setup load balancing"
    echo "3) Configure service redundancy"
    echo "0) Back"
    echo
    
    read -p "Select option [1-3]: " rathole_choice
    
    case $rathole_choice in
        1) configure_rathole_multi_services ;;
        2) setup_rathole_load_balancing ;;
        3) configure_rathole_redundancy ;;
        0) return ;;
        *) log red "Invalid option"; sleep 1; configure_rathole_multi_peer ;;
    esac
}

add_peer_server() {
    echo
    log cyan "Adding new peer server..."
    
    read -p "Enter new peer IP/domain: " new_peer
    if [[ -z "$new_peer" ]]; then
        log red "Peer address cannot be empty"
        press_key
        return
    fi
    
    # Validate peer format
    if ! validate_peer_address "$new_peer"; then
        log red "Invalid peer address format"
        press_key
        return
    fi
    
    # Add to existing peers
    if [[ -z "$REMOTE_SERVER" ]]; then
        REMOTE_SERVER="$new_peer"
    else
        REMOTE_SERVER="$REMOTE_SERVER,$new_peer"
    fi
    
    # Update configuration
    sed -i "s/REMOTE_SERVER=\".*\"/REMOTE_SERVER=\"$REMOTE_SERVER\"/" "$MAIN_CONFIG"
    
    log green "✅ Peer $new_peer added successfully"
    log cyan "Updated peers: $REMOTE_SERVER"
    
    read -p "Restart tunnel to apply changes? [Y/n]: " restart_confirm
    if [[ ! "$restart_confirm" =~ ^[Nn]$ ]]; then
        restart_tunnel
    fi
    
    press_key
}

remove_peer_server() {
    echo
    log cyan "Removing peer server..."
    
    if [[ -z "$REMOTE_SERVER" ]]; then
        log yellow "No peers configured"
        press_key
        return
    fi
    
    # Show current peers
    log blue "Current peers:"
    IFS=',' read -ra PEERS <<< "$REMOTE_SERVER"
    for i in "${!PEERS[@]}"; do
        echo "  $((i+1))) ${PEERS[$i]}"
    done
    echo
    
    read -p "Select peer number to remove [1-${#PEERS[@]}]: " peer_choice
    
    if [[ "$peer_choice" =~ ^[0-9]+$ ]] && [[ "$peer_choice" -ge 1 ]] && [[ "$peer_choice" -le ${#PEERS[@]} ]]; then
        local peer_to_remove="${PEERS[$((peer_choice-1))]}"
        
        # Remove peer from list
        local new_peers=""
        for peer in "${PEERS[@]}"; do
            if [[ "$peer" != "$peer_to_remove" ]]; then
                if [[ -z "$new_peers" ]]; then
                    new_peers="$peer"
                else
                    new_peers="$new_peers,$peer"
                fi
            fi
        done
        
        REMOTE_SERVER="$new_peers"
        
        # Update configuration
        sed -i "s/REMOTE_SERVER=\".*\"/REMOTE_SERVER=\"$REMOTE_SERVER\"/" "$MAIN_CONFIG"
        
        log green "✅ Peer $peer_to_remove removed successfully"
        log cyan "Updated peers: $REMOTE_SERVER"
        
        read -p "Restart tunnel to apply changes? [Y/n]: " restart_confirm
        if [[ ! "$restart_confirm" =~ ^[Nn]$ ]]; then
            restart_tunnel
        fi
    else
        log red "Invalid selection"
    fi
    
    press_key
}

replace_all_peers() {
    echo
    log cyan "Replacing all peer servers..."
    
    echo "Current peers: $REMOTE_SERVER"
    echo
    echo "Enter new peers (comma-separated):"
    read -p "New peers: " new_peers
    
    if [[ -z "$new_peers" ]]; then
        log red "Peer list cannot be empty"
        press_key
        return
    fi
    
    # Validate all peers
    IFS=',' read -ra NEW_PEERS <<< "$new_peers"
    for peer in "${NEW_PEERS[@]}"; do
        peer=$(echo "$peer" | xargs)  # trim whitespace
        if [[ -n "$peer" ]] && ! validate_peer_address "$peer"; then
            log red "Invalid peer address: $peer"
            press_key
            return
        fi
    done
    
    REMOTE_SERVER="$new_peers"
    
    # Update configuration
    sed -i "s/REMOTE_SERVER=\".*\"/REMOTE_SERVER=\"$REMOTE_SERVER\"/" "$MAIN_CONFIG"
    
    log green "✅ All peers replaced successfully"
    log cyan "New peers: $REMOTE_SERVER"
    
    read -p "Restart tunnel to apply changes? [Y/n]: " restart_confirm
    if [[ ! "$restart_confirm" =~ ^[Nn]$ ]]; then
        restart_tunnel
    fi
    
    press_key
}

test_peer_connectivity() {
    echo
    log cyan "Testing peer connectivity..."
    
    if [[ -z "$REMOTE_SERVER" ]]; then
        log yellow "No peers configured"
        press_key
        return
    fi
    
    IFS=',' read -ra PEERS <<< "$REMOTE_SERVER"
    
    for peer in "${PEERS[@]}"; do
        peer=$(echo "$peer" | xargs)  # trim whitespace
        if [[ -n "$peer" ]]; then
            log blue "Testing: $peer"
            
            # Ping test
            if ping -c 3 -W 5 "$peer" >/dev/null 2>&1; then
                echo "  ✅ Ping: Success"
            else
                echo "  ❌ Ping: Failed"
            fi
            
            # Port test
            if nc -z -w 5 "$peer" "$PORT" 2>/dev/null; then
                echo "  ✅ Port $PORT: Open"
            else
                echo "  ❌ Port $PORT: Closed/Filtered"
            fi
            
            echo
        fi
    done
    
    press_key
}

validate_peer_address() {
    local peer="$1"
    
    # Check if it's a valid IP address
    if [[ "$peer" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    fi
    
    # Check if it's a valid domain name
    if [[ "$peer" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 0
    fi
    
    return 1
}

configure_rathole_multi_services() {
    log cyan "Configuring multiple Rathole services..."
    echo
    
    read -p "Enter number of services to configure [2-10]: " service_count
    
    if ! [[ "$service_count" =~ ^[0-9]+$ ]] || [[ "$service_count" -lt 2 ]] || [[ "$service_count" -gt 10 ]]; then
        log red "Invalid service count. Must be between 2-10"
        press_key
        return
    fi
    
    log cyan "Configuring $service_count services..."
    
    # Create multi-service configuration
    create_rathole_multi_config "$service_count"
    
    log green "✅ Multi-service configuration created"
    press_key
}

create_rathole_multi_config() {
    local service_count="$1"
    local base_port="$PORT"
    
    cat > "$RATHOLE_CONFIG" << EOF
# Rathole Multi-Service Configuration
# Generated by MoonTun v${MOONTUN_VERSION}

[$([ "${RATHOLE_NODE_TYPE:-bidirectional}" == "listener" ] && echo "server" || echo "client")]
$([ "${RATHOLE_NODE_TYPE:-bidirectional}" == "listener" ] && echo "bind_addr = \"0.0.0.0:${base_port}\"" || echo "remote_addr = \"${REMOTE_SERVER}:${base_port}\"")
default_token = "${NETWORK_SECRET}"

# Transport configuration
[$([ "${RATHOLE_NODE_TYPE:-bidirectional}" == "listener" ] && echo "server" || echo "client").transport]
type = "${PROTOCOL}"

[$([ "${RATHOLE_NODE_TYPE:-bidirectional}" == "listener" ] && echo "server" || echo "client").transport.tcp]
nodelay = true
keepalive_secs = 20

EOF

    # Add multiple services
    for ((i=1; i<=service_count; i++)); do
        local service_port=$((base_port + i))
        local local_port=$((8080 + i - 1))
        
        cat >> "$RATHOLE_CONFIG" << EOF
# Service $i
[$([ "${RATHOLE_NODE_TYPE:-bidirectional}" == "listener" ] && echo "server" || echo "client").services.service_$i]
type = "${PROTOCOL}"
$([ "${RATHOLE_NODE_TYPE:-bidirectional}" == "listener" ] && echo "bind_addr = \"0.0.0.0:${service_port}\"" || echo "local_addr = \"127.0.0.1:${local_port}\"")
$([ "${RATHOLE_NODE_TYPE:-bidirectional}" != "listener" ] && echo "remote_addr = \"0.0.0.0:${service_port}\"")
token = "${NETWORK_SECRET}"

EOF
    done
}

setup_rathole_load_balancing() {
    log cyan "Setting up Rathole load balancing with HAProxy..."
    
    # Create HAProxy config for Rathole load balancing
    create_rathole_haproxy_config
    
    log green "✅ Load balancing configured"
    press_key
}

create_rathole_haproxy_config() {
    cat >> /etc/haproxy/haproxy.cfg << EOF

# Rathole Load Balancing Configuration
# Added by MoonTun Multi-Peer Setup

frontend rathole_frontend
    bind *:$((PORT + 100))
    mode tcp
    default_backend rathole_backend

backend rathole_backend
    mode tcp
    balance roundrobin
    option tcp-check
    
    # Multiple Rathole instances
    server rathole1 127.0.0.1:$((PORT + 1)) check inter 5s
    server rathole2 127.0.0.1:$((PORT + 2)) check inter 5s
    server rathole3 127.0.0.1:$((PORT + 3)) check inter 5s

EOF

    systemctl reload haproxy 2>/dev/null || true
}

configure_rathole_redundancy() {
    log cyan "Configuring Rathole service redundancy..."
    
    # Create redundant service configuration
    create_redundant_rathole_services
    
    log green "✅ Service redundancy configured"
    press_key
}

create_redundant_rathole_services() {
    # Create multiple Rathole configurations for redundancy
    local configs=("primary" "secondary" "tertiary")
    
    for config in "${configs[@]}"; do
        local config_file="$CONFIG_DIR/rathole_${config}.toml"
        local port_offset=0
        
        case "$config" in
            "secondary") port_offset=10 ;;
            "tertiary") port_offset=20 ;;
        esac
        
        local service_port=$((PORT + port_offset))
        
        cat > "$config_file" << EOF
# Rathole ${config} configuration
[$([ "${RATHOLE_NODE_TYPE:-bidirectional}" == "listener" ] && echo "server" || echo "client")]
$([ "${RATHOLE_NODE_TYPE:-bidirectional}" == "listener" ] && echo "bind_addr = \"0.0.0.0:${service_port}\"" || echo "remote_addr = \"${REMOTE_SERVER}:${service_port}\"")
default_token = "${NETWORK_SECRET}_${config}"

[$([ "${RATHOLE_NODE_TYPE:-bidirectional}" == "listener" ] && echo "server" || echo "client").transport]
type = "${PROTOCOL}"

[$([ "${RATHOLE_NODE_TYPE:-bidirectional}" == "listener" ] && echo "server" || echo "client").services.main]
type = "${PROTOCOL}"
$([ "${RATHOLE_NODE_TYPE:-bidirectional}" == "listener" ] && echo "bind_addr = \"0.0.0.0:$((8080 + port_offset))\"" || echo "local_addr = \"127.0.0.1:$((8080 + port_offset))\"")
$([ "${RATHOLE_NODE_TYPE:-bidirectional}" != "listener" ] && echo "remote_addr = \"0.0.0.0:$((8080 + port_offset))\"")
token = "${NETWORK_SECRET}_${config}"
EOF
        
        log green "Created $config configuration: $config_file"
    done
}

# =============================================================================
# Help and Menu Functions
# =============================================================================

show_help() {
    clear
    echo -e "${CYAN}🚀 MoonTun - Intelligent Multi-Node Tunnel System v${MOONTUN_VERSION}${NC}"
    echo "================================================================="
    echo
    echo -e "${GREEN}USAGE:${NC}"
    echo "  sudo moontun <command> [options]"
    echo
    echo -e "${GREEN}INSTALLATION:${NC}"
    echo -e "${CYAN}  Online:  curl -fsSL https://github.com/k4lantar4/moontun/raw/main/moontun.sh | sudo bash -s -- --install${NC}"
    echo -e "${CYAN}  Offline: sudo moontun --local${NC}  (for Iran servers without internet)"
    echo
    echo -e "${GREEN}COMMANDS:${NC}"
    echo -e "${CYAN}  setup${NC}          Interactive tunnel configuration"
    echo -e "${CYAN}  install-cores${NC}  Manage tunnel cores (EasyTier/Rathole)"
    echo -e "${CYAN}  connect${NC}        Connect tunnel with current config"
    echo -e "${CYAN}  status${NC}         Show system and tunnel status"
    echo -e "${CYAN}  monitor${NC}        Live monitoring dashboard"
    echo -e "${CYAN}  stop${NC}           Stop all tunnel processes"
    echo -e "${CYAN}  restart${NC}        Restart tunnel services"
    echo -e "${CYAN}  switch${NC}         Intelligent protocol switching"
    echo -e "${CYAN}  multi-peer${NC}     Configure multi-peer connections"
    echo -e "${CYAN}  optimize${NC}       Apply network optimizations"
    echo -e "${CYAN}  haproxy${NC}        Setup HAProxy load balancing"
    echo -e "${CYAN}  logs${NC}           View system logs"
    echo -e "${CYAN}  backup${NC}         Create configuration backup"
    echo -e "${CYAN}  restore${NC}        Restore configuration from backup"
    echo -e "${CYAN}  diagnose${NC}       Diagnose installation issues"
    echo -e "${CYAN}  version${NC}        Show version information"
    echo -e "${CYAN}  help${NC}           Show this help message"
    echo
    echo -e "${GREEN}FEATURES:${NC}"
    echo "  • Multi-node tunnel system (EasyTier + Rathole)"
    echo "  • Intelligent failover and auto-recovery"
    echo "  • Multi-peer connections (2+ servers)"
    echo "  • Smart protocol switching with stability testing"
    echo "  • Bidirectional connection support"
    echo "  • Real-time network monitoring"
    echo "  • Enterprise-grade stability"
    echo "  • Iran network condition optimization"
    echo
    echo -e "${GREEN}EXAMPLES:${NC}"
    echo "  sudo moontun setup      # Configure new tunnel"
    echo "  sudo moontun connect    # Start tunneling"
    echo "  sudo moontun monitor    # Monitor live status"
    echo "  sudo moontun switch     # Smart protocol switching"
    echo "  sudo moontun multi-peer # Configure multi-server"
    echo
    echo -e "${PURPLE}For support: https://github.com/k4lantar4/moontun${NC}"
}

show_menu() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗"
    echo -e "║         ${WHITE}MoonTun Manager v${MOONTUN_VERSION}${CYAN}          ║"
    echo -e "║    ${WHITE}Intelligent Multi-Node System${CYAN}      ║"
    echo -e "╠════════════════════════════════════════╣"
    echo -e "║  ${WHITE}EasyTier + Rathole + Multi-Peer${CYAN}     ║"
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
    echo -e "${GREEN}[6]${NC}  🔄 Smart Protocol Switch"
    echo -e "${GREEN}[7]${NC}  🌐 Multi-Peer Configuration"
    echo -e "${GREEN}[8]${NC}  🛑 Stop Tunnel"
    echo -e "${GREEN}[9]${NC}  ♻️  Restart Tunnel"
    echo -e "${GREEN}[10]${NC} ⚡ Network Optimization"
    echo -e "${GREEN}[11]${NC} 📝 View Logs"
    echo -e "${GREEN}[12]${NC} 💾 Backup Configuration"
    echo -e "${GREEN}[13]${NC} 🔄 Restore Configuration"
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
            install_moontun
            ;;
        "--auto"|"auto")
            install_moontun "auto"
            ;;
        "--local"|"local"|"install-local")
            install_moontun "--local"
            ;;
        "setup")
            check_root
            setup_tunnel
            ;;
        "install-cores")
            check_root
            manage_tunnel_cores
            ;;
        "install-cores-local")
            check_root
            install_cores_local
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
        "multi-peer")
            check_root
            configure_multi_peer
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
        "diagnose"|"fix")
            diagnose_installation
            ;;
        "version")
            echo "MoonTun v${MOONTUN_VERSION}"
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        "menu")
            if [[ $EUID -eq 0 ]]; then
                # Interactive menu mode
                while true; do
                    show_menu
                    echo -n "Select option [0-13]: "
                    read choice
                    
                    case $choice in
                        1) setup_tunnel ;;
                        2) manage_tunnel_cores ;;
                        3) connect_tunnel ;;
                        4) show_status; press_key ;;
                        5) live_monitor ;;
                        6) switch_protocol ;;
                        7) configure_multi_peer ;;
                        8) stop_tunnel; press_key ;;
                        9) restart_tunnel; press_key ;;
                        10) optimize_network; press_key ;;
                        11) view_logs ;;
                        12) backup_configuration; press_key ;;
                        13) restore_configuration; press_key ;;
                        0) log green "👋 Goodbye!"; exit 0 ;;
                        *) log red "Invalid option"; sleep 1 ;;
                    esac
                done
            else
                log red "Interactive menu requires root access. Use: sudo moontun"
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