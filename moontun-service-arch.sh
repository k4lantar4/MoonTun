#!/bin/bash
# MoonTun Lightweight Service Architecture
# Minimal resource usage with maximum performance

# Core service configuration
MOONTUN_VERSION="3.0-arch"
SERVICE_DIR="/opt/moontun"
CACHE_DIR="/tmp/moontun"
LOG_LEVEL="warn"

# Lightweight service manager
class ServiceManager {
    private services=()
    private pids=()
    
    start_service() {
        local service_name="$1"
        local service_cmd="$2"
        
        # Check if already running
        if [[ -f "/var/run/moontun-${service_name}.pid" ]]; then
            local pid=$(cat "/var/run/moontun-${service_name}.pid")
            if kill -0 "$pid" 2>/dev/null; then
                echo "Service $service_name already running (PID: $pid)"
                return 0
            fi
        fi
        
        # Start service in background
        $service_cmd &
        local pid=$!
        echo "$pid" > "/var/run/moontun-${service_name}.pid"
        
        # Verify startup
        sleep 2
        if kill -0 "$pid" 2>/dev/null; then
            echo "Service $service_name started successfully (PID: $pid)"
            services+=("$service_name")
            pids+=("$pid")
            return 0
        else
            echo "Failed to start service $service_name"
            rm -f "/var/run/moontun-${service_name}.pid"
            return 1
        fi
    }
    
    stop_service() {
        local service_name="$1"
        local pid_file="/var/run/moontun-${service_name}.pid"
        
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            if kill -TERM "$pid" 2>/dev/null; then
                echo "Service $service_name stopped"
                rm -f "$pid_file"
            fi
        fi
    }
}

# Lightweight geo balancer service
geo_balancer_service() {
    local service_name="geo-balancer"
    local check_interval=300  # 5 minutes
    
    while true; do
        # Check for geo test requests
        if [[ -f "$CACHE_DIR/geo_request" ]]; then
            local servers=$(cat "$CACHE_DIR/geo_request")
            local best_server=$(fast_geo_select $servers)
            echo "$best_server" > "$CACHE_DIR/geo_result"
            rm -f "$CACHE_DIR/geo_request"
        fi
        
        sleep 10
    done
}

# Ultra-fast geo selection (< 3 seconds)
fast_geo_select() {
    local servers=($@)
    local best_server=""
    local best_latency=9999
    
    # Parallel ping with strict timeout
    for server in "${servers[@]}"; do
        (
            local latency=$(timeout 1 ping -c 1 -W 1 "$server" 2>/dev/null | 
                          grep "time=" | awk -F'time=' '{print $2}' | awk '{print $1}' || echo "999")
            echo "$server:$latency"
        ) &
    done | {
        # Process results as they come in
        while IFS=: read -r server latency; do
            if (( $(echo "$latency < $best_latency" | bc -l 2>/dev/null || echo 0) )); then
                best_server="$server"
                best_latency="$latency"
            fi
        done
        
        echo "$best_server"
    }
}

# Lightweight tunnel manager
tunnel_manager_service() {
    local service_name="tunnel-manager"
    local health_check_interval=30
    
    while true; do
        # Quick health check
        if ! check_tunnel_health_fast; then
            # Attempt auto-healing
            auto_heal_tunnel
        fi
        
        sleep "$health_check_interval"
    done
}

# Fast health check (< 1 second)
check_tunnel_health_fast() {
    local tunnel_type=$(cat "$CACHE_DIR/active_tunnel" 2>/dev/null || echo "none")
    
    case "$tunnel_type" in
        "easytier")
            pgrep -f "easytier-core" >/dev/null
            ;;
        "rathole")
            pgrep -f "rathole" >/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Auto-healing with circuit breaker pattern
auto_heal_tunnel() {
    local failure_count_file="$CACHE_DIR/failure_count"
    local failure_count=$(cat "$failure_count_file" 2>/dev/null || echo 0)
    
    # Circuit breaker: stop trying after 5 failures
    if [[ $failure_count -ge 5 ]]; then
        echo "Circuit breaker open - too many failures"
        return 1
    fi
    
    # Increment failure count
    echo $((failure_count + 1)) > "$failure_count_file"
    
    # Attempt restart
    if restart_tunnel_fast; then
        # Reset failure count on success
        echo 0 > "$failure_count_file"
        return 0
    fi
    
    return 1
}

# Ultra-fast tunnel restart (< 5 seconds)
restart_tunnel_fast() {
    local tunnel_type=$(cat "$CACHE_DIR/active_tunnel" 2>/dev/null || echo "none")
    
    # Kill existing tunnel processes
    case "$tunnel_type" in
        "easytier")
            pkill -f "easytier-core" 2>/dev/null
            ;;
        "rathole")
            pkill -f "rathole" 2>/dev/null
            ;;
    esac
    
    # Wait briefly for cleanup
    sleep 2
    
    # Restart with cached configuration
    if [[ -f "$CACHE_DIR/tunnel_config" ]]; then
        source "$CACHE_DIR/tunnel_config"
        start_tunnel_direct "$TUNNEL_MODE" "$REMOTE_SERVER" "$PORT"
        return $?
    fi
    
    return 1
}

# Direct tunnel start without geo balancing
start_tunnel_direct() {
    local mode="$1"
    local server="$2"
    local port="$3"
    
    case "$mode" in
        "easytier")
            nohup easytier-core \
                -i "10.20.1.$(shuf -i 10-250 -n 1)" \
                --hostname "moon-$(date +%s)" \
                --network-secret "$(generate_secret)" \
                --default-protocol tcp \
                --listeners "tcp://0.0.0.0:$port" \
                --peers "tcp://$server:$port" \
                --multi-thread \
                > /dev/null 2>&1 &
            ;;
        "rathole")
            nohup rathole -c "$CACHE_DIR/rathole.toml" > /dev/null 2>&1 &
            ;;
    esac
    
    local pid=$!
    echo "$mode" > "$CACHE_DIR/active_tunnel"
    echo "$pid" > "$CACHE_DIR/tunnel_pid"
    
    # Quick verification
    sleep 2
    kill -0 "$pid" 2>/dev/null
}

# Lightweight systemd integration
create_systemd_service() {
    cat > /etc/systemd/system/moontun.service << 'EOF'
[Unit]
Description=MoonTun Lightweight Tunnel Service
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
User=root
Group=root
ExecStart=/opt/moontun/bin/moontun-service
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=/bin/kill -TERM $MAINPID
Restart=on-failure
RestartSec=5
TimeoutStartSec=30
TimeoutStopSec=15
MemoryLimit=64M
CPUQuota=50%

# Lightweight resource limits
LimitNOFILE=1024
LimitNPROC=32

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable moontun
}

# Main service entry point
main() {
    # Create cache directory
    mkdir -p "$CACHE_DIR"
    
    # Initialize service manager
    local service_manager=ServiceManager
    
    # Start lightweight services
    $service_manager.start_service "geo-balancer" "geo_balancer_service"
    $service_manager.start_service "tunnel-manager" "tunnel_manager_service"
    
    # Notify systemd we're ready
    systemd-notify --ready 2>/dev/null || true
    
    # Main service loop
    while true; do
        # Handle service management
        handle_service_requests
        sleep 5
    done
}

# Handle service requests from CLI
handle_service_requests() {
    if [[ -f "$CACHE_DIR/service_request" ]]; then
        local request=$(cat "$CACHE_DIR/service_request")
        rm -f "$CACHE_DIR/service_request"
        
        case "$request" in
            "connect")
                echo "connecting" > "$CACHE_DIR/service_status"
                # Trigger geo balancer
                echo "$REMOTE_SERVER" > "$CACHE_DIR/geo_request"
                ;;
            "disconnect")
                echo "disconnecting" > "$CACHE_DIR/service_status"
                stop_all_tunnels
                ;;
            *)
                echo "unknown request: $request" > "$CACHE_DIR/service_status"
                ;;
        esac
    fi
}

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 