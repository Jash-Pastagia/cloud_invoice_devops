#!/bin/bash
set -euo pipefail

# Complete K3s + Application Deployment Script
# ============================================
#
# This script performs a complete deployment of:
# 1. K3s single-node cluster
# 2. Database infrastructure (PostgreSQL)
# 3. Database initialization (schema + seed data)
# 4. Application services (future: auth, invoice, payment, etc.)
#
# Usage:
#   sudo ./scripts/deploy-to-k3s.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
K8S_DIR="$PROJECT_ROOT/k8s"
K3S_KUBECONFIG="/etc/rancher/k3s/k3s.yaml"

# Deployment phases
PHASES=(
    "install_k3s"
    "deploy_infrastructure" 
    "initialize_database"
    "validate_deployment"
)

# Phase execution tracking
CURRENT_PHASE=""
COMPLETED_PHASES=()
PHASE_START_TIME=""

# Phase management
start_phase() {
    CURRENT_PHASE="$1"
    PHASE_START_TIME=$(date +%s)
    echo -e "\n${BLUE}🚀 Phase: $1${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..50})${NC}"
}

complete_phase() {
    local phase_duration=$(($(date +%s) - PHASE_START_TIME))
    COMPLETED_PHASES+=("$CURRENT_PHASE")
    echo -e "${GREEN}✅ Phase '$CURRENT_PHASE' completed in ${phase_duration}s${NC}"
    CURRENT_PHASE=""
}

# Error handling
handle_error() {
    local exit_code=$?
    echo -e "\n${RED}❌ Deployment failed in phase: $CURRENT_PHASE${NC}"
    echo -e "${RED}Exit code: $exit_code${NC}"
    
    if [[ -n "$CURRENT_PHASE" ]]; then
        echo -e "\n${YELLOW}🔍 Troubleshooting tips for phase '$CURRENT_PHASE':${NC}"
        case "$CURRENT_PHASE" in
            "install_k3s")
                echo -e "   • Check if script has root privileges"
                echo -e "   • Verify internet connectivity"
                echo -e "   • Check system logs: journalctl -u k3s"
                ;;
            "deploy_infrastructure")
                echo -e "   • Check cluster status: kubectl get nodes"
                echo -e "   • Verify manifests: kubectl get pods -A"
                echo -e "   • Check storage: kubectl get pv,pvc"
                ;;
            "initialize_database")
                echo -e "   • Check job logs: kubectl logs job/db-init-job"
                echo -e "   • Check PostgreSQL: kubectl logs postgresql-0"
                echo -e "   • Verify database connectivity"
                ;;
            "validate_deployment")
                echo -e "   • Run test script manually for details"
                echo -e "   • Check individual component logs"
                ;;
        esac
    fi
    
    echo -e "\n${YELLOW}📊 Completed phases: ${#COMPLETED_PHASES[@]}/${#PHASES[@]}${NC}"
    for phase in "${COMPLETED_PHASES[@]}"; do
        echo -e "${GREEN}   ✅ $phase${NC}"
    done
    
    exit $exit_code
}

# Install K3s cluster
install_k3s() {
    start_phase "install_k3s"
    
    echo -e "${BLUE}Installing K3s single-node cluster...${NC}"
    
    # Run K3s installation script
    if [[ -x "$SCRIPT_DIR/k3s-single-node.sh" ]]; then
        "$SCRIPT_DIR/k3s-single-node.sh"
    else
        echo -e "${RED}❌ K3s installation script not found or not executable${NC}"
        echo -e "${YELLOW}Expected: $SCRIPT_DIR/k3s-single-node.sh${NC}"
        return 1
    fi
    
    # Verify installation
    echo -e "${BLUE}Verifying K3s installation...${NC}"
    export KUBECONFIG="$K3S_KUBECONFIG"
    
    # Wait for cluster to be fully ready
    local max_retries=30
    local retry=0
    
    while [[ $retry -lt $max_retries ]]; do
        if kubectl get nodes --no-headers | grep -q Ready; then
            echo -e "${GREEN}✅ K3s cluster is ready${NC}"
            break
        fi
        
        echo -e "${YELLOW}⏳ Waiting for cluster to be ready... ($((retry+1))/$max_retries)${NC}"
        sleep 10
        ((retry++))
    done
    
    if [[ $retry -eq $max_retries ]]; then
        echo -e "${RED}❌ Cluster not ready within timeout${NC}"
        return 1
    fi
    
    complete_phase
}

# Deploy infrastructure components
deploy_infrastructure() {
    start_phase "deploy_infrastructure"
    
    export KUBECONFIG="$K3S_KUBECONFIG"
    
    echo -e "${BLUE}Deploying secrets and configuration...${NC}"
    kubectl apply -f "$K8S_DIR/secrets/"
    kubectl apply -f "$K8S_DIR/configmaps/"
    
    echo -e "${BLUE}Deploying PostgreSQL...${NC}"
    kubectl apply -f "$K8S_DIR/statefulsets/postgresql.yaml"
    
    # Wait for PostgreSQL to be ready
    echo -e "${BLUE}Waiting for PostgreSQL to be ready...${NC}"
    kubectl wait --for=condition=ready pod -l app=postgresql --timeout=300s || {
        echo -e "${RED}❌ PostgreSQL not ready within timeout${NC}"
        echo -e "${YELLOW}📋 PostgreSQL pod status:${NC}"
        kubectl get pods -l app=postgresql
        kubectl describe pods -l app=postgresql
        return 1
    }
    
    echo -e "${GREEN}✅ PostgreSQL is ready${NC}"
    complete_phase
}

# Initialize database with schema and seed data
initialize_database() {
    start_phase "initialize_database"
    
    export KUBECONFIG="$K3S_KUBECONFIG"
    
    # Run database initialization job
    echo -e "${BLUE}Running database schema initialization...${NC}"
    kubectl apply -f "$K8S_DIR/jobs/db-init-job.yaml"
    
    # Wait for db-init job to complete
    echo -e "${BLUE}Waiting for database initialization to complete...${NC}"
    kubectl wait --for=condition=complete job/db-init-job --timeout=300s || {
        echo -e "${RED}❌ Database initialization failed${NC}"
        echo -e "${YELLOW}📋 Database init job logs:${NC}"
        kubectl logs job/db-init-job
        return 1
    }
    
    echo -e "${GREEN}✅ Database schema initialized${NC}"
    
    # Run seed data job
    echo -e "${BLUE}Running seed data creation...${NC}"
    kubectl apply -f "$K8S_DIR/jobs/seed-data-job.yaml"
    
    # Wait for seed-data job to complete
    echo -e "${BLUE}Waiting for seed data creation to complete...${NC}"
    kubectl wait --for=condition=complete job/seed-data-job --timeout=300s || {
        echo -e "${RED}❌ Seed data creation failed${NC}"
        echo -e "${YELLOW}📋 Seed data job logs:${NC}"
        kubectl logs job/seed-data-job
        return 1
    }
    
    echo -e "${GREEN}✅ Seed data created${NC}"
    
    # Verify database contents
    echo -e "${BLUE}Verifying database contents...${NC}"
    local user_count=$(kubectl exec postgresql-0 -- psql -U postgres -d invoicedb -t -c "SELECT COUNT(*) FROM users;" 2>/dev/null | tr -d ' ' || echo "0")
    
    if [[ $user_count -ge 2 ]]; then
        echo -e "${GREEN}✅ Database contains $user_count users${NC}"
    else
        echo -e "${YELLOW}⚠️  Expected at least 2 users, found $user_count${NC}"
    fi
    
    complete_phase
}

# Validate entire deployment
validate_deployment() {
    start_phase "validate_deployment"
    
    export KUBECONFIG="$K3S_KUBECONFIG"
    
    echo -e "${BLUE}Running comprehensive deployment validation...${NC}"
    
    # Run test script if available
    if [[ -x "$SCRIPT_DIR/test-k3s-deployment.sh" ]]; then
        "$SCRIPT_DIR/test-k3s-deployment.sh" || {
            echo -e "${YELLOW}⚠️  Some validation tests failed${NC}"
            echo -e "${YELLOW}Check the test output above for details${NC}"
        }
    else
        echo -e "${YELLOW}⚠️  Validation test script not found, running basic checks...${NC}"
        
        # Basic validation
        echo -e "${BLUE}Checking cluster status...${NC}"
        kubectl get nodes
        kubectl get pods
        kubectl get services
        
        echo -e "${BLUE}Checking database connectivity...${NC}"
        kubectl exec postgresql-0 -- psql -U postgres -d invoicedb -c "SELECT version();"
    fi
    
    complete_phase
}

# Display deployment summary
show_deployment_summary() {
    echo -e "\n${GREEN}🎉 Deployment Summary${NC}"
    echo -e "${GREEN}=====================${NC}"
    
    echo -e "\n${BLUE}📋 Completed phases:${NC}"
    for phase in "${COMPLETED_PHASES[@]}"; do
        echo -e "${GREEN}   ✅ $phase${NC}"
    done
    
    echo -e "\n${BLUE}🔧 Cluster Information:${NC}"
    echo -e "   Kubeconfig: $K3S_KUBECONFIG"
    echo -e "   Cluster type: K3s single-node"
    
    echo -e "\n${BLUE}📊 Current Status:${NC}"
    export KUBECONFIG="$K3S_KUBECONFIG"
    
    echo -e "${YELLOW}Nodes:${NC}"
    kubectl get nodes --no-headers | head -3
    
    echo -e "\n${YELLOW}Running Pods:${NC}"
    kubectl get pods --no-headers | grep Running | head -5
    
    echo -e "\n${BLUE}🔗 Next Steps:${NC}"
    echo -e "   1. Export kubeconfig: export KUBECONFIG=$K3S_KUBECONFIG"
    echo -e "   2. Check pod status: kubectl get pods"
    echo -e "   3. View logs: kubectl logs <pod-name>"
    echo -e "   4. Connect to database: kubectl exec -it postgresql-0 -- psql -U postgres -d invoicedb"
    
    echo -e "\n${BLUE}📝 Demo User Credentials:${NC}"
    echo -e "   Username: demo     | Password: demo123"
    echo -e "   Username: user2    | Password: user2123"
    
    echo -e "\n${GREEN}✅ K3s deployment completed successfully!${NC}"
}

# Main execution
main() {
    # Set up error handling
    trap handle_error ERR
    
    echo -e "${BLUE}🚀 Complete K3s + Application Deployment${NC}"
    echo -e "${BLUE}=========================================${NC}"
    
    local start_time=$(date +%s)
    
    # Check prerequisites
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ This script must be run as root or with sudo${NC}"
        echo -e "${YELLOW}Usage: sudo $0${NC}"
        exit 1
    fi
    
    if [[ ! -d "$K8S_DIR" ]]; then
        echo -e "${RED}❌ Kubernetes manifests directory not found: $K8S_DIR${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}📁 Project root: $PROJECT_ROOT${NC}"
    echo -e "${BLUE}📁 K8s manifests: $K8S_DIR${NC}"
    echo -e "${BLUE}📄 Target kubeconfig: $K3S_KUBECONFIG${NC}"
    
    # Execute deployment phases
    for phase in "${PHASES[@]}"; do
        $phase
    done
    
    # Calculate total time
    local total_time=$(($(date +%s) - start_time))
    echo -e "\n${GREEN}⏱️  Total deployment time: ${total_time}s${NC}"
    
    # Show summary
    show_deployment_summary
}

# Execute main function
main "$@"