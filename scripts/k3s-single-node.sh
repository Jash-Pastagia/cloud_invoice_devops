#!/bin/bash
set -euo pipefail

# K3s Single-Node Installation Script
# =================================
# 
# This script installs K3s (lightweight Kubernetes) in single-node mode
# on a Linux system. It's designed to be safe, idempotent, and informative.
#
# Requirements:
# - Linux operating system (Ubuntu, CentOS, RHEL, etc.)
# - Root/sudo access 
# - Internet connectivity
# - Disable swap if enabled (K3s requirement)
#
# Usage:
#   sudo ./scripts/k3s-single-node.sh
#   K3S_VERSION=v1.28.4+k3s1 K3S_TOKEN=mytoken sudo -E ./scripts/k3s-single-node.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
K3S_VERSION="${K3S_VERSION:-v1.28.4+k3s1}"
K3S_TOKEN="${K3S_TOKEN:-}"
K3S_KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
TIMEOUT_SECONDS=180  # 3 minutes

# Generate random token if not provided
if [ -z "$K3S_TOKEN" ]; then
    if command -v openssl >/dev/null 2>&1; then
        K3S_TOKEN=$(openssl rand -hex 16)
        echo -e "${BLUE}ℹ️  Generated K3s token using openssl${NC}"
    elif command -v uuidgen >/dev/null 2>&1; then
        K3S_TOKEN=$(uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]')
        echo -e "${BLUE}ℹ️  Generated K3s token using uuidgen${NC}"
    else
        K3S_TOKEN="default-$(date +%s)"
        echo -e "${YELLOW}⚠️  Using timestamp-based token (consider installing openssl or uuid-tools)${NC}"
    fi
fi

# Pre-flight checks
echo -e "${BLUE}🔍 Running pre-flight checks...${NC}"

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${RED}❌ This script is designed for Linux systems only${NC}"
    echo -e "${YELLOW}   Current OS: $OSTYPE${NC}"
    exit 1
fi

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root or with sudo${NC}"
    echo -e "${YELLOW}   Usage: sudo $0${NC}"
    exit 1
fi

# Check and warn about swap
if swapon --show 2>/dev/null | grep -q .; then
    echo -e "${YELLOW}⚠️  Swap is enabled. Kubernetes recommends disabling swap.${NC}"
    echo -e "${YELLOW}   To disable: sudo swapoff -a && sudo sed -i '/swap/d' /etc/fstab${NC}"
    read -p "Continue anyway? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if k3s is already installed
if command -v k3s >/dev/null 2>&1; then
    echo -e "${GREEN}✅ K3s is already installed${NC}"
    
    # Get current version
    CURRENT_VERSION=$(k3s --version | head -n1 | awk '{print $3}')
    echo -e "${BLUE}   Current version: $CURRENT_VERSION${NC}"
    echo -e "${BLUE}   Requested version: $K3S_VERSION${NC}"
    
    if [[ "$CURRENT_VERSION" == "$K3S_VERSION" ]]; then
        echo -e "${GREEN}✅ Version matches - skipping installation${NC}"
        SKIP_INSTALL=true
    else
        echo -e "${YELLOW}⚠️  Version mismatch - will upgrade/downgrade${NC}"
        read -p "Continue with version change? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        SKIP_INSTALL=false
    fi
else
    echo -e "${BLUE}ℹ️  K3s not found - will install${NC}"
    SKIP_INSTALL=false
fi

# Function to detect server IP
get_server_ip() {
    # Try multiple methods to get the primary IP
    local ip=""
    
    # Method 1: ip route (most reliable)
    if command -v ip >/dev/null 2>&1; then
        ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' | head -1)
    fi
    
    # Method 2: hostname -I (fallback)
    if [[ -z "$ip" ]] && command -v hostname >/dev/null 2>&1; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    
    # Method 3: ip addr (last resort)
    if [[ -z "$ip" ]] && command -v ip >/dev/null 2>&1; then
        ip=$(ip addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)
    fi
    
    # Default fallback
    if [[ -z "$ip" ]]; then
        ip="127.0.0.1"
    fi
    
    echo "$ip"
}

# Function to wait for system pods to be ready
wait_for_system_pods() {
    echo -e "${BLUE}⏳ Waiting for system pods to be ready (timeout: ${TIMEOUT_SECONDS}s)...${NC}"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + TIMEOUT_SECONDS))
    
    while [[ $(date +%s) -lt $end_time ]]; do
        # Check if kubectl is available and k3s is responding
        if ! kubectl --kubeconfig="$K3S_KUBECONFIG" get nodes >/dev/null 2>&1; then
            echo -e "${YELLOW}   Waiting for K3s API server...${NC}"
            sleep 5
            continue
        fi
        
        # Check kube-system pods
        local kube_system_ready=$(kubectl --kubeconfig="$K3S_KUBECONFIG" get pods -n kube-system --no-headers 2>/dev/null | grep -v Completed | awk '{print $3}' | grep -c Running || echo 0)
        local kube_system_total=$(kubectl --kubeconfig="$K3S_KUBECONFIG" get pods -n kube-system --no-headers 2>/dev/null | grep -v Completed | wc -l || echo 0)
        
        # Check local-path-provisioner pods  
        local local_path_ready=$(kubectl --kubeconfig="$K3S_KUBECONFIG" get pods -n kube-system -l app=local-path-provisioner --no-headers 2>/dev/null | awk '{print $3}' | grep -c Running || echo 0)
        
        echo -e "${BLUE}   System pods: $kube_system_ready/$kube_system_total ready${NC}"
        
        # Consider ready when all kube-system pods are running and local-path is ready
        if [[ $kube_system_total -gt 0 ]] && [[ $kube_system_ready -eq $kube_system_total ]] && [[ $local_path_ready -gt 0 ]]; then
            echo -e "${GREEN}✅ All system pods are ready!${NC}"
            return 0
        fi
        
        sleep 5
    done
    
    echo -e "${YELLOW}⚠️  Timeout waiting for pods. Some pods may still be starting.${NC}"
    echo -e "${BLUE}   You can check status with: kubectl --kubeconfig=$K3S_KUBECONFIG get pods -A${NC}"
    return 1
}

# Install or upgrade K3s
if [[ "$SKIP_INSTALL" == "false" ]]; then
    echo -e "${BLUE}🚀 Installing K3s version $K3S_VERSION...${NC}"
    echo -e "${BLUE}   Token: ${K3S_TOKEN:0:8}...${NC}"
    
    # Download and run the K3s installer
    curl -sfL https://get.k3s.io | \
        INSTALL_K3S_VERSION="$K3S_VERSION" \
        K3S_TOKEN="$K3S_TOKEN" \
        sh -s - server \
        --write-kubeconfig-mode 644 \
        --disable=traefik \
        --node-name="$(hostname)" \
        --cluster-init
    
    echo -e "${GREEN}✅ K3s installation completed${NC}"
else
    echo -e "${GREEN}✅ Using existing K3s installation${NC}"
fi

# Verify installation
echo -e "${BLUE}🔍 Verifying K3s installation...${NC}"

# Check if K3s service is running
if systemctl is-active --quiet k3s; then
    echo -e "${GREEN}✅ K3s service is running${NC}"
else
    echo -e "${RED}❌ K3s service is not running${NC}"
    echo -e "${BLUE}   Checking service status...${NC}"
    systemctl status k3s --no-pager -l
    exit 1
fi

# Check if kubeconfig exists and is readable
if [[ -f "$K3S_KUBECONFIG" ]] && [[ -r "$K3S_KUBECONFIG" ]]; then
    echo -e "${GREEN}✅ Kubeconfig is accessible${NC}"
else
    echo -e "${RED}❌ Kubeconfig not found or not readable: $K3S_KUBECONFIG${NC}"
    exit 1
fi

# Wait for system pods
wait_for_system_pods

# Get server information
SERVER_IP=$(get_server_ip)
K3S_VERSION_ACTUAL=$(k3s --version | head -n1 | awk '{print $3}')

# Display summary
echo
echo -e "${GREEN}🎉 K3s Single-Node Cluster Ready!${NC}"
echo -e "${GREEN}=================================${NC}"
echo
echo -e "${BLUE}📋 Cluster Information:${NC}"
echo -e "   Version: $K3S_VERSION_ACTUAL"
echo -e "   Server IP: $SERVER_IP"
echo -e "   Node Name: $(hostname)"
echo -e "   Kubeconfig: $K3S_KUBECONFIG"
echo
echo -e "${BLUE}🔧 Usage Instructions:${NC}"
echo -e "   # Export kubeconfig for current session:"
echo -e "   export KUBECONFIG=$K3S_KUBECONFIG"
echo
echo -e "   # Or copy to default location:"
echo -e "   mkdir -p ~/.kube"
echo -e "   cp $K3S_KUBECONFIG ~/.kube/config"
echo -e "   chown \$(id -u):\$(id -g) ~/.kube/config"
echo
echo -e "   # Check cluster status:"
echo -e "   kubectl get nodes"
echo -e "   kubectl get pods -A"
echo
echo -e "${BLUE}🌐 Access from remote machines:${NC}"
echo -e "   # Copy $K3S_KUBECONFIG to your local machine"
echo -e "   # Replace 'server: https://127.0.0.1:6443' with 'server: https://$SERVER_IP:6443'"
echo
echo -e "${BLUE}🛑 Management Commands:${NC}"
echo -e "   # Stop K3s: sudo systemctl stop k3s"
echo -e "   # Start K3s: sudo systemctl start k3s" 
echo -e "   # Uninstall: /usr/local/bin/k3s-uninstall.sh"
echo

# Show current cluster status
echo -e "${BLUE}📊 Current Cluster Status:${NC}"
kubectl --kubeconfig="$K3S_KUBECONFIG" get nodes
echo
kubectl --kubeconfig="$K3S_KUBECONFIG" get pods -A

echo
echo -e "${GREEN}✅ K3s installation script completed successfully!${NC}"