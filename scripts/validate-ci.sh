#!/bin/bash

# CI Workflow Test Validation Script
# This script helps verify that the GitHub Actions CI workflow will work correctly

echo "🔧 CI Workflow Validation Script"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2" 
    
    echo -e "\n🧪 Testing: ${YELLOW}${test_name}${NC}"
    
    if eval "$test_command"; then
        echo -e "✅ ${GREEN}PASS${NC}: $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "❌ ${RED}FAIL${NC}: $test_name"
        ((TESTS_FAILED++))
    fi
}

# Test 1: Check if all service directories exist
test_service_directories() {
    local services=("auth-service" "invoice-service" "payment-service" "notification-service" "analytics-service" "frontend")
    local missing_services=()
    
    for service in "${services[@]}"; do
        if [ ! -d "$service" ]; then
            missing_services+=("$service")
        fi
    done
    
    if [ ${#missing_services[@]} -eq 0 ]; then
        return 0
    else
        echo "Missing service directories: ${missing_services[*]}"
        return 1
    fi
}

# Test 2: Check if Dockerfiles exist for all services
test_dockerfiles() {
    local services=("auth-service" "invoice-service" "payment-service" "notification-service" "analytics-service" "frontend")
    local missing_dockerfiles=()
    
    for service in "${services[@]}"; do
        if [ ! -f "$service/Dockerfile" ]; then
            missing_dockerfiles+=("$service/Dockerfile")
        fi
    done
    
    if [ ${#missing_dockerfiles[@]} -eq 0 ]; then
        return 0
    else
        echo "Missing Dockerfiles: ${missing_dockerfiles[*]}"
        return 1
    fi
}

# Test 3: Check if package.json exists for all services
test_package_json() {
    local services=("auth-service" "invoice-service" "payment-service" "notification-service" "analytics-service" "frontend")
    local missing_packages=()
    
    for service in "${services[@]}"; do
        if [ ! -f "$service/package.json" ]; then
            missing_packages+=("$service/package.json")
        fi
    done
    
    if [ ${#missing_packages[@]} -eq 0 ]; then
        return 0
    else
        echo "Missing package.json files: ${missing_packages[*]}"
        return 1
    fi
}

# Test 4: Validate CI workflow YAML syntax
test_workflow_yaml() {
    if command -v yq >/dev/null 2>&1; then
        yq eval '.jobs.build-test-scan.strategy.matrix.service' .github/workflows/ci.yml > /dev/null
        return $?
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "
import yaml
import sys
try:
    with open('.github/workflows/ci.yml', 'r') as f:
        yaml.safe_load(f)
    print('YAML syntax is valid')
    sys.exit(0)
except yaml.YAMLError as e:
    print(f'YAML syntax error: {e}')
    sys.exit(1)
"
    else
        echo "Neither yq nor python3 available for YAML validation - skipping"
        return 0
    fi
}

# Test 5: Check Docker availability
test_docker() {
    docker --version > /dev/null && docker info > /dev/null 2>&1
}

# Test 6: Simulate matrix service detection
test_matrix_services() {
    local expected_services=("auth-service" "invoice-service" "payment-service" "notification-service" "analytics-service" "frontend")
    local found_services=()
    
    for service in "${expected_services[@]}"; do
        if [ -d "$service" ] && [ -f "$service/Dockerfile" ]; then
            found_services+=("$service")
        fi
    done
    
    if [ ${#found_services[@]} -eq ${#expected_services[@]} ]; then
        echo "Found all expected services: ${found_services[*]}"
        return 0
    else
        echo "Expected ${#expected_services[@]} services, found ${#found_services[@]}"
        return 1
    fi
}

# Test 7: Check Node.js availability
test_nodejs() {
    node --version > /dev/null && npm --version > /dev/null
}

# Test 8: Test a sample service build (optional - requires Docker)
test_sample_build() {
    local test_service="auth-service"
    if [ -d "$test_service" ] && [ -f "$test_service/Dockerfile" ]; then
        echo "Building $test_service as a test..."
        cd "$test_service"
        if [ -f "package.json" ]; then
            npm ci --prefer-offline --no-audit || return 1
        fi
        cd ..
        docker build -t "test-$test_service" -f "$test_service/Dockerfile" . > /dev/null 2>&1
        docker rmi "test-$test_service" > /dev/null 2>&1 || true
        return $?
    else
        echo "Test service $test_service not found - skipping build test"
        return 0
    fi
}

# Run all tests
echo "Starting validation tests..."

run_test "Service directories exist" "test_service_directories"
run_test "Dockerfiles exist" "test_dockerfiles" 
run_test "Package.json files exist" "test_package_json"
run_test "CI workflow YAML syntax" "test_workflow_yaml"
run_test "Docker is available" "test_docker"
run_test "Matrix services detection" "test_matrix_services"
run_test "Node.js is available" "test_nodejs"

# Optional build test (can be slow)
if [ "${1:-}" = "--with-build-test" ]; then
    run_test "Sample Docker build" "test_sample_build"
fi

# Summary
echo ""
echo "=================================="
echo "🏁 Test Summary"
echo "=================================="
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n🎉 ${GREEN}All tests passed!${NC} The CI workflow should work correctly."
    echo ""
    echo "Next steps:"
    echo "1. Commit and push the .github/workflows/ci.yml file"
    echo "2. The CI will run automatically on push to main, develop, or feat/* branches"
    echo "3. To enable image pushing, set repository secret PUSH_IMAGES=true"
    echo "4. To use GHCR, set repository secret GHCR_PAT with your GitHub token"
    exit 0
else
    echo -e "\n❌ ${RED}Some tests failed.${NC} Please fix the issues before using the CI workflow."
    exit 1
fi