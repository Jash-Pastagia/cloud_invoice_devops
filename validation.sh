#!/bin/bash
# validation.sh - Comprehensive validation script for Cloud Invoice DevOps

# Don't exit on error - we want to collect all issues
set +e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Cloud Invoice DevOps - Validation Script${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Function to print section headers
print_section() {
    echo ""
    echo -e "${BLUE}▶ $1${NC}"
    echo "----------------------------------------"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    ((PASSED++))
}

# Function to print error
print_error() {
    echo -e "${RED}✗ $1${NC}"
    ((FAILED++))
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    ((WARNINGS++))
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

#######################################
# 1. Prerequisites Check
#######################################
print_section "1. Checking Prerequisites"

if command_exists node; then
    NODE_VERSION=$(node --version)
    print_success "Node.js installed: $NODE_VERSION"
else
    print_error "Node.js not installed"
fi

if command_exists npm; then
    NPM_VERSION=$(npm --version)
    print_success "npm installed: $NPM_VERSION"
else
    print_error "npm not installed"
fi

if command_exists docker; then
    DOCKER_VERSION=$(docker --version)
    print_success "Docker installed: $DOCKER_VERSION"
else
    print_error "Docker not installed"
fi

if command_exists kubectl; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -1)
    print_success "kubectl installed: $KUBECTL_VERSION"
else
    print_warning "kubectl not installed (needed for Kubernetes deployment)"
fi

if command_exists terraform; then
    TERRAFORM_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
    print_success "Terraform installed: $TERRAFORM_VERSION"
else
    print_warning "Terraform not installed (needed for infrastructure deployment)"
fi

if command_exists aws; then
    AWS_VERSION=$(aws --version 2>&1)
    print_success "AWS CLI installed: $AWS_VERSION"
else
    print_warning "AWS CLI not installed (needed for AWS deployment)"
fi

#######################################
# 2. Project Structure Validation
#######################################
print_section "2. Validating Project Structure"

REQUIRED_DIRS=(
    "auth-service"
    "invoice-service"
    "payment-service"
    "notification-service"
    "analytics-service"
    "frontend"
    "k8s"
    "lib"
    ".github/workflows"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        print_success "Directory exists: $dir"
    else
        print_error "Directory missing: $dir"
    fi
done

REQUIRED_FILES=(
    "docker-compose.yml"
    "README.md"
    ".github/workflows/ci.yml"
    ".github/workflows/devsecops.yml"
    ".github/workflows/terraform.yml"
    ".github/workflows/cd.yml"
    "lib/kafka.js"
    "DEPLOYMENT_GUIDE.md"
    "CI_CD_IMPLEMENTATION_SUMMARY.md"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_success "File exists: $file"
    else
        print_error "File missing: $file"
    fi
done

#######################################
# 3. Service Package.json Validation
#######################################
print_section "3. Validating Service Configurations"

SERVICES=(
    "auth-service"
    "invoice-service"
    "payment-service"
    "notification-service"
    "analytics-service"
    "frontend"
)

for service in "${SERVICES[@]}"; do
    if [ -f "$service/package.json" ]; then
        print_success "$service/package.json exists"
        
        # Check for required dependencies
        if [ "$service" != "frontend" ]; then
            if grep -q "express" "$service/package.json"; then
                print_success "$service has express dependency"
            else
                print_warning "$service missing express dependency"
            fi
        fi
    else
        print_error "$service/package.json missing"
    fi
    
    if [ -f "$service/Dockerfile" ]; then
        print_success "$service/Dockerfile exists"
    else
        print_error "$service/Dockerfile missing"
    fi
done

#######################################
# 4. Kubernetes Manifests Validation
#######################################
print_section "4. Validating Kubernetes Manifests"

K8S_FILES=(
    "k8s/auth-deployment.yaml"
    "k8s/invoice-deployment.yaml"
    "k8s/payment-deployment.yaml"
    "k8s/services.yaml"
    "k8s/ingress.yaml"
    "k8s/secret.yaml"
)

for file in "${K8S_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_success "$file exists"
        
        # Validate YAML syntax if kubectl is available
        if command_exists kubectl; then
            if kubectl apply --dry-run=client -f "$file" >/dev/null 2>&1; then
                print_success "$file is valid YAML"
            else
                print_error "$file has invalid YAML syntax"
            fi
        fi
    else
        print_error "$file missing"
    fi
done

#######################################
# 5. Terraform Structure Validation
#######################################
print_section "5. Validating Terraform Structure"

if [ -d "terraform" ]; then
    print_success "Terraform directory exists"
    
    TERRAFORM_FILES=(
        "terraform/main.tf"
        "terraform/variables.tf"
        "terraform/outputs.tf"
    )
    
    for file in "${TERRAFORM_FILES[@]}"; do
        if [ -f "$file" ]; then
            print_success "$file exists"
        else
            print_error "$file missing"
        fi
    done
    
    # Check for VPC module
    if [ -d "terraform/modules/vpc" ]; then
        print_success "VPC module exists"
        
        VPC_FILES=(
            "terraform/modules/vpc/main.tf"
            "terraform/modules/vpc/variables.tf"
            "terraform/modules/vpc/outputs.tf"
        )
        
        for file in "${VPC_FILES[@]}"; do
            if [ -f "$file" ]; then
                print_success "$file exists"
            else
                print_error "$file missing"
            fi
        done
    else
        print_error "VPC module missing"
    fi
    
    # Check for other modules
    MODULES=("eks" "rds" "msk" "iam" "security")
    for module in "${MODULES[@]}"; do
        if [ -d "terraform/modules/$module" ]; then
            print_success "$module module exists"
        else
            print_warning "$module module not yet created (pending)"
        fi
    done
    
    # Validate Terraform syntax if terraform is available
    if command_exists terraform; then
        cd terraform
        if terraform fmt -check -recursive >/dev/null 2>&1; then
            print_success "Terraform code is properly formatted"
        else
            print_warning "Terraform code needs formatting (run: terraform fmt -recursive)"
        fi
        
        if terraform validate -backend=false >/dev/null 2>&1; then
            print_success "Terraform syntax is valid"
        else
            print_error "Terraform has syntax errors"
        fi
        cd ..
    fi
else
    print_error "Terraform directory missing"
fi

#######################################
# 6. GitHub Workflows Validation
#######################################
print_section "6. Validating GitHub Workflows"

WORKFLOWS=(
    ".github/workflows/ci.yml"
    ".github/workflows/devsecops.yml"
    ".github/workflows/terraform.yml"
    ".github/workflows/cd.yml"
)

for workflow in "${WORKFLOWS[@]}"; do
    if [ -f "$workflow" ]; then
        print_success "$(basename $workflow) exists"
        
        # Check for required sections
        if grep -q "jobs:" "$workflow"; then
            print_success "$(basename $workflow) has jobs defined"
        else
            print_error "$(basename $workflow) missing jobs"
        fi
    else
        print_error "$(basename $workflow) missing"
    fi
done

#######################################
# 7. Docker Validation
#######################################
print_section "7. Validating Docker Configuration"

if [ -f "docker-compose.yml" ]; then
    print_success "docker-compose.yml exists"
    
    if command_exists docker; then
        # Validate docker-compose syntax
        if docker compose config >/dev/null 2>&1; then
            print_success "docker-compose.yml is valid"
        else
            print_error "docker-compose.yml has syntax errors"
        fi
        
        # Check if Docker daemon is running
        if docker info >/dev/null 2>&1; then
            print_success "Docker daemon is running"
            
            # Check for running containers
            RUNNING_CONTAINERS=$(docker ps --format "{{.Names}}" | wc -l)
            if [ "$RUNNING_CONTAINERS" -gt 0 ]; then
                print_success "$RUNNING_CONTAINERS Docker containers running"
            else
                print_warning "No Docker containers currently running"
            fi
        else
            print_error "Docker daemon is not running"
        fi
    fi
else
    print_error "docker-compose.yml missing"
fi

#######################################
# 8. Shared Library Validation
#######################################
print_section "8. Validating Shared Libraries"

if [ -f "lib/kafka.js" ]; then
    print_success "lib/kafka.js exists"
    
    # Check for required exports
    if grep -q "module.exports" "lib/kafka.js"; then
        print_success "lib/kafka.js has exports"
    else
        print_error "lib/kafka.js missing exports"
    fi
    
    # Check for key functions
    REQUIRED_FUNCTIONS=("createProducer" "createConsumer" "waitForBroker")
    for func in "${REQUIRED_FUNCTIONS[@]}"; do
        if grep -q "$func" "lib/kafka.js"; then
            print_success "lib/kafka.js has $func function"
        else
            print_error "lib/kafka.js missing $func function"
        fi
    done
else
    print_error "lib/kafka.js missing"
fi

#######################################
# 9. Environment Variables Check
#######################################
print_section "9. Checking Environment Variables"

ENV_VARS=(
    "JWT_SECRET:Optional (default: supersecretdevops)"
    "KAFKA_BROKERS:Optional (default: kafka:9092)"
    "DB_HOST:Optional (default: localhost)"
    "DB_PASSWORD:Optional (default: postgres)"
)

for var_info in "${ENV_VARS[@]}"; do
    VAR_NAME=$(echo "$var_info" | cut -d: -f1)
    VAR_DESC=$(echo "$var_info" | cut -d: -f2-)
    
    if [ -z "${!VAR_NAME}" ]; then
        print_warning "$VAR_NAME not set - $VAR_DESC"
    else
        print_success "$VAR_NAME is set"
    fi
done

#######################################
# 10. Kubernetes Cluster Check
#######################################
print_section "10. Checking Kubernetes Cluster"

if command_exists kubectl; then
    if kubectl cluster-info >/dev/null 2>&1; then
        CLUSTER_INFO=$(kubectl config current-context)
        print_success "Connected to Kubernetes cluster: $CLUSTER_INFO"
        
        # Check for namespace
        if kubectl get namespace innovative-ci >/dev/null 2>&1; then
            print_success "Namespace 'innovative-ci' exists"
            
            # Check for deployments
            DEPLOYMENTS=$(kubectl get deployments -n innovative-ci --no-headers 2>/dev/null | wc -l)
            if [ "$DEPLOYMENTS" -gt 0 ]; then
                print_success "$DEPLOYMENTS deployments found in innovative-ci namespace"
            else
                print_warning "No deployments found in innovative-ci namespace"
            fi
            
            # Check for pods
            PODS=$(kubectl get pods -n innovative-ci --no-headers 2>/dev/null | wc -l)
            RUNNING_PODS=$(kubectl get pods -n innovative-ci --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
            if [ "$RUNNING_PODS" -gt 0 ]; then
                print_success "$RUNNING_PODS/$PODS pods running in innovative-ci namespace"
            else
                print_warning "No pods running in innovative-ci namespace"
            fi
        else
            print_warning "Namespace 'innovative-ci' does not exist"
        fi
    else
        print_warning "Not connected to a Kubernetes cluster"
    fi
else
    print_warning "kubectl not available - skipping cluster check"
fi

#######################################
# 11. Documentation Validation
#######################################
print_section "11. Validating Documentation"

DOCS=(
    "README.md"
    "DEPLOYMENT_GUIDE.md"
    "CI_CD_IMPLEMENTATION_SUMMARY.md"
)

for doc in "${DOCS[@]}"; do
    if [ -f "$doc" ]; then
        print_success "$doc exists"
        
        # Check file size (should be substantial)
        SIZE=$(wc -c < "$doc")
        if [ "$SIZE" -gt 1000 ]; then
            print_success "$doc has substantial content ($SIZE bytes)"
        else
            print_warning "$doc seems incomplete ($SIZE bytes)"
        fi
    else
        print_error "$doc missing"
    fi
done

#######################################
# 12. Git Repository Check
#######################################
print_section "12. Checking Git Repository"

if [ -d ".git" ]; then
    print_success "Git repository initialized"
    
    # Check for uncommitted changes
    if git diff --quiet 2>/dev/null; then
        print_success "No uncommitted changes"
    else
        print_warning "Uncommitted changes detected"
    fi
    
    # Check current branch
    BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
    print_success "Current branch: $BRANCH"
else
    print_warning "Not a git repository"
fi

#######################################
# Summary
#######################################
print_section "Validation Summary"

TOTAL=$((PASSED + FAILED + WARNINGS))
echo ""
echo -e "${GREEN}✓ Passed: $PASSED${NC}"
echo -e "${RED}✗ Failed: $FAILED${NC}"
echo -e "${YELLOW}⚠ Warnings: $WARNINGS${NC}"
echo -e "Total Checks: $TOTAL"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}✓ All critical validations passed!${NC}"
    echo -e "${GREEN}============================================${NC}"
    
    if [ $WARNINGS -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}Note: There are $WARNINGS warnings. These are not critical but should be addressed.${NC}"
    fi
    
    exit 0
else
    echo -e "${RED}============================================${NC}"
    echo -e "${RED}✗ Validation failed with $FAILED errors${NC}"
    echo -e "${RED}============================================${NC}"
    echo ""
    echo "Please fix the errors above before proceeding."
    exit 1
fi
