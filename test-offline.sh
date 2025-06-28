#!/bin/bash

# 🧪 MoonTun Offline Installation Test Script
# Verifies all components are properly installed and configured

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

log() {
    local color="$1"
    local text="$2"
    
    case $color in
        red) echo -e "${RED}❌ $text${NC}" ;;
        green) echo -e "${GREEN}✅ $text${NC}" ;;
        yellow) echo -e "${YELLOW}⚠️  $text${NC}" ;;
        cyan) echo -e "${CYAN}🔧 $text${NC}" ;;
        blue) echo -e "${BLUE}ℹ️  $text${NC}" ;;
        *) echo -e "$text" ;;
    esac
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TOTAL_TESTS++))
    
    echo -n "Testing $test_name... "
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED_TESTS++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        ((FAILED_TESTS++))
        return 1
    fi
}

test_dependencies() {
    log cyan "🔍 Testing System Dependencies"
    echo "================================"
    
    run_test "curl availability" "command -v curl"
    run_test "wget availability" "command -v wget"
    run_test "unzip availability" "command -v unzip"
    run_test "jq availability" "command -v jq"
    run_test "netcat availability" "command -v nc"
    run_test "bc availability" "command -v bc"
    run_test "openssl availability" "command -v openssl"
    run_test "ping utility" "command -v ping"
    run_test "ip utility" "command -v ip"
    run_test "iptables availability" "command -v iptables"
    
    echo
}

test_tunnel_cores() {
    log cyan "🔍 Testing Tunnel Cores"
    echo "========================"
    
    run_test "EasyTier core binary" "[[ -f /usr/local/bin/easytier-core ]]"
    run_test "EasyTier core executable" "[[ -x /usr/local/bin/easytier-core ]]"
    run_test "EasyTier CLI binary" "[[ -f /usr/local/bin/easytier-cli ]]"
    run_test "Rathole core binary" "[[ -f /usr/local/bin/rathole ]]"
    run_test "Rathole core executable" "[[ -x /usr/local/bin/rathole ]]"
    
    # Test if binaries can actually run
    run_test "EasyTier core version" "/usr/local/bin/easytier-core --version"
    run_test "Rathole core help" "/usr/local/bin/rathole --help"
    
    echo
}

test_moontun_installation() {
    log cyan "🔍 Testing MoonTun Installation"
    echo "==============================="
    
    run_test "MoonTun script installed" "[[ -f /usr/local/bin/moontun ]]"
    run_test "MoonTun script executable" "[[ -x /usr/local/bin/moontun ]]"
    run_test "MoonTun command in PATH" "command -v moontun"
    run_test "MoonTun help command" "moontun --help"
    run_test "MoonTun version command" "moontun version"
    
    echo
}

test_directories() {
    log cyan "🔍 Testing Directory Structure"
    echo "==============================="
    
    run_test "Config directory exists" "[[ -d /etc/moontun ]]"
    run_test "Config directory writable" "[[ -w /etc/moontun ]]"
    run_test "Log directory exists" "[[ -d /var/log/moontun ]]"
    run_test "Log directory writable" "[[ -w /var/log/moontun ]]"
    
    echo
}

test_system_requirements() {
    log cyan "🔍 Testing System Requirements"
    echo "==============================="
    
    # Check Ubuntu version
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        if [[ "$ID" == "ubuntu" ]]; then
            echo -n "Ubuntu version compatibility... "
            if dpkg --compare-versions "$VERSION_ID" "ge" "22.04"; then
                echo -e "${GREEN}PASS${NC} (Ubuntu $VERSION_ID)"
                ((PASSED_TESTS++))
            else
                echo -e "${YELLOW}WARNING${NC} (Ubuntu $VERSION_ID < 22.04)"
                ((FAILED_TESTS++))
            fi
            ((TOTAL_TESTS++))
        fi
    fi
    
    # Check architecture
    local arch=$(uname -m)
    echo -n "Architecture support... "
    case $arch in
        x86_64|aarch64|armv7l)
            echo -e "${GREEN}PASS${NC} ($arch)"
            ((PASSED_TESTS++))
            ;;
        *)
            echo -e "${YELLOW}WARNING${NC} ($arch may not be fully supported)"
            ((FAILED_TESTS++))
            ;;
    esac
    ((TOTAL_TESTS++))
    
    # Check disk space
    local disk_space=$(df /usr/local/bin | tail -1 | awk '{print $4}')
    echo -n "Disk space check... "
    if [[ $disk_space -gt 1048576 ]]; then  # 1GB in KB
        echo -e "${GREEN}PASS${NC} ($(($disk_space / 1024 / 1024))GB available)"
        ((PASSED_TESTS++))
    else
        echo -e "${YELLOW}WARNING${NC} (Less than 1GB available)"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
    
    # Check root access
    echo -n "Root access check... "
    if [[ $EUID -eq 0 ]]; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}FAIL${NC} (Root access required)"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
    
    echo
}

test_network_connectivity() {
    log cyan "🔍 Testing Network Connectivity"
    echo "==============================="
    
    # These tests are optional since we're testing offline installation
    echo -n "Internet connectivity... "
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${GREEN}AVAILABLE${NC}"
    else
        echo -e "${YELLOW}OFFLINE${NC} (Expected for Iran servers)"
    fi
    
    echo -n "DNS resolution... "
    if nslookup google.com >/dev/null 2>&1; then
        echo -e "${GREEN}WORKING${NC}"
    else
        echo -e "${YELLOW}LIMITED${NC} (May be filtered)"
    fi
    
    echo
}

test_offline_package() {
    log cyan "🔍 Testing Offline Package Structure"
    echo "===================================="
    
    local offline_dir=""
    
    # Find offline directory
    if [[ -d "./moontun-offline" ]]; then
        offline_dir="./moontun-offline"
    elif [[ -d "../moontun-offline" ]]; then
        offline_dir="../moontun-offline"
    elif [[ -d "/root/moontun-offline" ]]; then
        offline_dir="/root/moontun-offline"
    fi
    
    if [[ -n "$offline_dir" ]]; then
        run_test "Offline directory found" "[[ -d '$offline_dir' ]]"
        run_test "Packages directory exists" "[[ -d '$offline_dir/packages' ]]"
        run_test "Binaries directory exists" "[[ -d '$offline_dir/bin' ]]"
        run_test "Scripts directory exists" "[[ -d '$offline_dir/scripts' ]]"
        
        # Count packages and binaries
        local pkg_count=$(ls -1 "$offline_dir/packages"/*.deb 2>/dev/null | wc -l)
        local bin_count=$(ls -1 "$offline_dir/bin"/* 2>/dev/null | wc -l)
        
        echo "   • Found $pkg_count .deb packages"
        echo "   • Found $bin_count binary files"
    else
        log yellow "Offline package directory not found (may have been cleaned up)"
    fi
    
    echo
}

show_results() {
    echo
    log cyan "📊 Test Results Summary"
    echo "======================="
    echo
    echo "Total Tests: $TOTAL_TESTS"
    echo -e "Passed:      ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed:      ${RED}$FAILED_TESTS${NC}"
    
    local success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo "Success Rate: $success_rate%"
    
    echo
    
    if [[ $success_rate -ge 90 ]]; then
        log green "🎉 Excellent! MoonTun offline installation is working perfectly"
    elif [[ $success_rate -ge 70 ]]; then
        log yellow "⚠️  Good! Minor issues detected but system should work"
    else
        log red "❌ Issues detected! Please review failed tests and fix problems"
    fi
    
    echo
    echo "Next steps:"
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo "1. Run: sudo moontun setup"
        echo "2. Configure your tunnel settings"
        echo "3. Run: sudo moontun start"
    else
        echo "1. Fix the failed tests above"
        echo "2. Re-run this test: sudo ./test-offline.sh"
        echo "3. Proceed with setup once all tests pass"
    fi
}

main() {
    clear
    echo "🧪 MoonTun Offline Installation Test"
    echo "===================================="
    echo
    
    test_system_requirements
    test_dependencies
    test_tunnel_cores
    test_moontun_installation
    test_directories
    test_network_connectivity
    test_offline_package
    
    show_results
}

main "$@" 