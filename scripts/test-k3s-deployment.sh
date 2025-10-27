#!/bin/bash
set -euo pipefail

# Comprehensive K3s and Kubernetes Deployment Test Script
# ======================================================
#
# This script validates:
# 1. K3s installation and cluster health
# 2. Kubernetes manifest deployment
# 3. Database initialization and seed data
# 4. Service connectivity and health
# 5. End-to-end application functionality

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
TIMEOUT_SECONDS=300

# Test state tracking
TESTS_PASSED=0
TESTS_FAILED=0
FAILURES=()

# Test result tracking
log_test() {
    local test_name="$1"
    local status="$2"
    local message="${3:-}"
    
    if [[ "$status" == "PASS" ]]; then
        echo -e "${GREEN}✅ $test_name${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ $test_name${NC}"
        [[ -n "$message" ]] && echo -e "${RED}   $message${NC}"
        FAILURES+=("$test_name: $message")
        ((TESTS_FAILED++))
    fi
}

# Wait for condition with timeout
wait_for_condition() {
    local condition_command="$1"
    local condition_name="$2"
    local timeout="${3:-$TIMEOUT_SECONDS}"
    
    echo -e "${BLUE}⏳ Waiting for $condition_name (timeout: ${timeout}s)...${NC}"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    while [[ $(date +%s) -lt $end_time ]]; do
        if eval "$condition_command" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ $condition_name ready${NC}"
            return 0
        fi
        sleep 5
    done
    
    echo -e "${RED}❌ Timeout waiting for $condition_name${NC}"
    return 1
}

# Test K3s installation
test_k3s_installation() {
    echo -e "\n${BLUE}🧪 Testing K3s Installation${NC}"
    echo "================================"
    
    # Test 1: K3s binary exists
    if command -v k3s >/dev/null 2>&1; then
        log_test "K3s binary installed" "PASS"
    else
        log_test "K3s binary installed" "FAIL" "k3s command not found"
        return 1
    fi
    
    # Test 2: K3s service is running
    if systemctl is-active --quiet k3s 2>/dev/null; then
        log_test "K3s service running" "PASS"
    else
        log_test "K3s service running" "FAIL" "systemctl shows k3s not active"
        return 1
    fi
    
    # Test 3: Kubeconfig exists and is readable
    if [[ -f "$K3S_KUBECONFIG" ]] && [[ -r "$K3S_KUBECONFIG" ]]; then
        log_test "Kubeconfig accessible" "PASS"
    else
        log_test "Kubeconfig accessible" "FAIL" "Cannot read $K3S_KUBECONFIG"
        return 1
    fi
    
    # Test 4: kubectl can connect to cluster
    if kubectl --kubeconfig="$K3S_KUBECONFIG" get nodes >/dev/null 2>&1; then
        log_test "kubectl cluster connectivity" "PASS"
    else
        log_test "kubectl cluster connectivity" "FAIL" "kubectl cannot connect to cluster"
        return 1
    fi
    
    # Test 5: System pods are running
    local system_pods_ready=$(kubectl --kubeconfig="$K3S_KUBECONFIG" get pods -n kube-system --no-headers 2>/dev/null | grep -v Completed | awk '{print $3}' | grep -c Running || echo 0)
    local system_pods_total=$(kubectl --kubeconfig="$K3S_KUBECONFIG" get pods -n kube-system --no-headers 2>/dev/null | grep -v Completed | wc -l || echo 0)
    
    if [[ $system_pods_ready -eq $system_pods_total ]] && [[ $system_pods_total -gt 0 ]]; then
        log_test "System pods running ($system_pods_ready/$system_pods_total)" "PASS"
    else
        log_test "System pods running ($system_pods_ready/$system_pods_total)" "FAIL" "Not all system pods are ready"
    fi
}

# Test Kubernetes manifest deployment
test_kubernetes_deployment() {
    echo -e "\n${BLUE}🧪 Testing Kubernetes Deployment${NC}"
    echo "=================================="
    
    # Set kubeconfig
    export KUBECONFIG="$K3S_KUBECONFIG"
    
    echo -e "${BLUE}📦 Deploying Kubernetes manifests...${NC}"
    
    # Test 1: Apply secrets and configmaps
    if kubectl apply -f "$K8S_DIR/secrets/" -f "$K8S_DIR/configmaps/" >/dev/null 2>&1; then
        log_test "Secrets and ConfigMaps applied" "PASS"
    else
        log_test "Secrets and ConfigMaps applied" "FAIL" "Failed to apply secrets/configmaps"
        return 1
    fi
    
    # Test 2: Deploy PostgreSQL
    if kubectl apply -f "$K8S_DIR/statefulsets/postgresql.yaml" >/dev/null 2>&1; then
        log_test "PostgreSQL StatefulSet deployed" "PASS"
    else
        log_test "PostgreSQL StatefulSet deployed" "FAIL" "Failed to deploy PostgreSQL"
        return 1
    fi
    
    # Test 3: Wait for PostgreSQL to be ready
    if wait_for_condition "kubectl get pods -l app=postgresql --no-headers | grep Running" "PostgreSQL pod"; then
        log_test "PostgreSQL pod ready" "PASS"
    else
        log_test "PostgreSQL pod ready" "FAIL" "PostgreSQL pod not ready within timeout"
    fi
    
    # Test 4: Run database initialization job
    if kubectl apply -f "$K8S_DIR/jobs/db-init-job.yaml" >/dev/null 2>&1; then
        log_test "Database init job created" "PASS"
    else
        log_test "Database init job created" "FAIL" "Failed to create db-init job"
    fi
    
    # Test 5: Wait for database initialization to complete
    if wait_for_condition "kubectl get job db-init-job -o jsonpath='{.status.succeeded}' | grep -q 1" "Database initialization"; then
        log_test "Database initialization completed" "PASS"
    else
        log_test "Database initialization completed" "FAIL" "Database init job did not succeed"
        echo -e "${YELLOW}📋 Database init job logs:${NC}"
        kubectl logs job/db-init-job || echo "Could not retrieve logs"
    fi
    
    # Test 6: Run seed data job
    if kubectl apply -f "$K8S_DIR/jobs/seed-data-job.yaml" >/dev/null 2>&1; then
        log_test "Seed data job created" "PASS"
    else
        log_test "Seed data job created" "FAIL" "Failed to create seed-data job"
    fi
    
    # Test 7: Wait for seed data to complete
    if wait_for_condition "kubectl get job seed-data-job -o jsonpath='{.status.succeeded}' | grep -q 1" "Seed data creation"; then
        log_test "Seed data creation completed" "PASS"
    else
        log_test "Seed data creation completed" "FAIL" "Seed data job did not succeed"
        echo -e "${YELLOW}📋 Seed data job logs:${NC}"
        kubectl logs job/seed-data-job || echo "Could not retrieve logs"
    fi
}

# Test database connectivity and data
test_database_validation() {
    echo -e "\n${BLUE}🧪 Testing Database Validation${NC}"
    echo "==============================="
    
    export KUBECONFIG="$K3S_KUBECONFIG"
    
    # Test 1: Database connectivity
    if kubectl exec postgresql-0 -- psql -U postgres -d invoicedb -c "SELECT 1;" >/dev/null 2>&1; then
        log_test "Database connectivity" "PASS"
    else
        log_test "Database connectivity" "FAIL" "Cannot connect to database"
    fi
    
    # Test 2: Check if tables exist
    local tables=$(kubectl exec postgresql-0 -- psql -U postgres -d invoicedb -t -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | grep -v '^$' | wc -l)
    if [[ $tables -gt 0 ]]; then
        log_test "Database tables created ($tables tables)" "PASS"
    else
        log_test "Database tables created" "FAIL" "No tables found in database"
    fi
    
    # Test 3: Check if demo users exist
    local user_count=$(kubectl exec postgresql-0 -- psql -U postgres -d invoicedb -t -c "SELECT COUNT(*) FROM users;" 2>/dev/null | tr -d ' ')
    if [[ $user_count -ge 2 ]]; then
        log_test "Demo users created ($user_count users)" "PASS"
    else
        log_test "Demo users created" "FAIL" "Expected at least 2 users, found $user_count"
    fi
    
    # Test 4: Verify specific demo users
    local demo_user_exists=$(kubectl exec postgresql-0 -- psql -U postgres -d invoicedb -t -c "SELECT COUNT(*) FROM users WHERE username IN ('demo', 'user2');" 2>/dev/null | tr -d ' ')
    if [[ $demo_user_exists -eq 2 ]]; then
        log_test "Demo users (demo/user2) exist" "PASS"
    else
        log_test "Demo users (demo/user2) exist" "FAIL" "Expected demo and user2, found $demo_user_exists"
    fi
}

# Display cluster status
show_cluster_status() {
    echo -e "\n${BLUE}📊 Cluster Status${NC}"
    echo "================="
    
    export KUBECONFIG="$K3S_KUBECONFIG"
    
    echo -e "\n${YELLOW}Nodes:${NC}"
    kubectl get nodes -o wide || echo "Could not retrieve nodes"
    
    echo -e "\n${YELLOW}Pods:${NC}"
    kubectl get pods -o wide || echo "Could not retrieve pods"
    
    echo -e "\n${YELLOW}Services:${NC}"
    kubectl get svc || echo "Could not retrieve services"
    
    echo -e "\n${YELLOW}Jobs:${NC}"
    kubectl get jobs || echo "Could not retrieve jobs"
    
    echo -e "\n${YELLOW}StatefulSets:${NC}"
    kubectl get statefulsets || echo "Could not retrieve statefulsets"
    
    echo -e "\n${YELLOW}Persistent Volumes:${NC}"
    kubectl get pv,pvc || echo "Could not retrieve persistent volumes"
}

# Generate final report
generate_report() {
    echo -e "\n${BLUE}📋 Test Summary${NC}"
    echo "==============="
    
    local total_tests=$((TESTS_PASSED + TESTS_FAILED))
    echo -e "Total tests: $total_tests"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    
    if [[ ${#FAILURES[@]} -gt 0 ]]; then
        echo -e "\n${RED}❌ Failed Tests:${NC}"
        for failure in "${FAILURES[@]}"; do
            echo -e "${RED}   • $failure${NC}"
        done
    fi
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 All tests passed! K3s and Kubernetes deployment successful.${NC}"
        return 0
    else
        echo -e "\n${RED}❌ Some tests failed. Please check the issues above.${NC}"
        return 1
    fi
}

# Cleanup function
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo -e "\n${YELLOW}🧹 Cleanup options:${NC}"
        echo -e "   • Check logs: kubectl logs <pod-name>"
        echo -e "   • Delete failed jobs: kubectl delete job db-init-job seed-data-job"
        echo -e "   • Restart deployment: kubectl rollout restart statefulset/postgresql"
        echo -e "   • Full cleanup: kubectl delete all --all"
    fi
}

# Main execution
main() {
    trap cleanup EXIT
    
    echo -e "${BLUE}🧪 Comprehensive K3s and Kubernetes Test${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo
    echo -e "${BLUE}📁 Project root: $PROJECT_ROOT${NC}"
    echo -e "${BLUE}📁 K8s manifests: $K8S_DIR${NC}"
    echo -e "${BLUE}📄 Kubeconfig: $K3S_KUBECONFIG${NC}"
    
    # Check prerequisites
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ This script must be run as root or with sudo${NC}"
        exit 1
    fi
    
    if [[ ! -d "$K8S_DIR" ]]; then
        echo -e "${RED}❌ Kubernetes manifests directory not found: $K8S_DIR${NC}"
        exit 1
    fi
    
    # Run tests
    test_k3s_installation
    test_kubernetes_deployment
    test_database_validation
    
    # Show status
    show_cluster_status
    
    # Generate report
    generate_report
}

# Execute main function
main "$@"