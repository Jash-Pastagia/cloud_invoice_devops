#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Add common paths
export PATH="/Applications/Docker.app/Contents/Resources/bin:/usr/local/bin:$PATH"

# Configuration
CLUSTER_NAME="innovative-ci"
NAMESPACE="innovative-ci"
JWT_SECRET="supersecretdevops"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Hybrid CD Infrastructure Setup      ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Check Docker
echo -e "${YELLOW}[1/8] Checking Docker...${NC}"

# Add Docker to PATH if it's installed but not in PATH
if ! command -v docker &> /dev/null; then
    if [ -d "/Applications/Docker.app" ]; then
        echo -e "${YELLOW}⚠️  Docker found but not in PATH, adding...${NC}"
        export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
        # Also add to current shell profile for future sessions
        if [ -f "$HOME/.zshrc" ]; then
            if ! grep -q "Docker.app/Contents/Resources/bin" "$HOME/.zshrc"; then
                echo 'export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"' >> "$HOME/.zshrc"
                echo -e "${GREEN}✓ Added Docker to ~/.zshrc${NC}"
            fi
        fi
    fi
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found${NC}"
    echo "Please install Docker Desktop: https://www.docker.com/products/docker-desktop"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${YELLOW}⚠️  Docker daemon not running${NC}"
    echo "Starting Docker Desktop..."
    open -a Docker
    echo "Waiting for Docker to start (this may take 30-60 seconds)..."
    
    # Wait up to 60 seconds for Docker to start
    for i in {1..60}; do
        if docker info &> /dev/null; then
            echo -e "${GREEN}✓ Docker is running${NC}"
            break
        fi
        sleep 1
        echo -n "."
    done
    echo ""
    
    if ! docker info &> /dev/null; then
        echo -e "${RED}❌ Docker failed to start. Please start Docker Desktop manually and try again.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Docker is running${NC}"
fi

# Step 2: Check kubectl
echo ""
echo -e "${YELLOW}[2/8] Checking kubectl...${NC}"
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found${NC}"
    echo "Installing kubectl via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install kubectl
        echo -e "${GREEN}✓ kubectl installed${NC}"
    else
        echo -e "${RED}Please install kubectl manually: brew install kubectl${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ kubectl is installed${NC}"
fi

# Step 3: Check kind
echo ""
echo -e "${YELLOW}[3/8] Checking kind...${NC}"
if ! command -v kind &> /dev/null; then
    echo -e "${YELLOW}⚠️  kind not found${NC}"
    echo "Installing kind via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install kind
        echo -e "${GREEN}✓ kind installed${NC}"
    else
        echo -e "${YELLOW}Installing kind manually...${NC}"
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-darwin-amd64
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
        echo -e "${GREEN}✓ kind installed${NC}"
    fi
else
    echo -e "${GREEN}✓ kind is installed${NC}"
fi

# Step 4: Create or verify kind cluster
echo ""
echo -e "${YELLOW}[4/8] Setting up kind cluster...${NC}"
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${GREEN}✓ Cluster '${CLUSTER_NAME}' already exists${NC}"
else
    echo "Creating kind cluster '${CLUSTER_NAME}'..."
    kind create cluster --name ${CLUSTER_NAME}
    echo -e "${GREEN}✓ Cluster created${NC}"
fi

# Set kubectl context
kubectl config use-context kind-${CLUSTER_NAME}
echo -e "${GREEN}✓ kubectl context set to kind-${CLUSTER_NAME}${NC}"

# Step 5: Start Docker Compose services
echo ""
echo -e "${YELLOW}[5/8] Starting infrastructure services (PostgreSQL, Kafka, Zookeeper)...${NC}"
if [ -f "docker-compose.yml" ]; then
    docker-compose up -d
    echo -e "${GREEN}✓ Docker Compose services started${NC}"
    
    # Wait for services to be healthy
    echo "Waiting for services to be ready..."
    sleep 10
    
    # Check PostgreSQL
    if docker ps | grep -q postgres; then
        echo -e "${GREEN}✓ PostgreSQL is running${NC}"
    else
        echo -e "${YELLOW}⚠️  PostgreSQL may not be running${NC}"
    fi
    
    # Check Kafka
    if docker ps | grep -q kafka; then
        echo -e "${GREEN}✓ Kafka is running${NC}"
    else
        echo -e "${YELLOW}⚠️  Kafka may not be running${NC}"
    fi
    
    # Check Zookeeper
    if docker ps | grep -q zookeeper; then
        echo -e "${GREEN}✓ Zookeeper is running${NC}"
    else
        echo -e "${YELLOW}⚠️  Zookeeper may not be running${NC}"
    fi
else
    echo -e "${RED}❌ docker-compose.yml not found${NC}"
    exit 1
fi

# Step 6: Create Kubernetes namespace
echo ""
echo -e "${YELLOW}[6/8] Creating Kubernetes namespace...${NC}"
if kubectl get namespace ${NAMESPACE} &> /dev/null; then
    echo -e "${GREEN}✓ Namespace '${NAMESPACE}' already exists${NC}"
else
    kubectl create namespace ${NAMESPACE}
    echo -e "${GREEN}✓ Namespace '${NAMESPACE}' created${NC}"
fi

# Step 7: Create Kubernetes secrets
echo ""
echo -e "${YELLOW}[7/8] Creating Kubernetes secrets...${NC}"
if kubectl get secret app-secrets -n ${NAMESPACE} &> /dev/null; then
    echo -e "${GREEN}✓ Secret 'app-secrets' already exists${NC}"
else
    kubectl create secret generic app-secrets \
        --from-literal=jwt-secret=${JWT_SECRET} \
        --namespace=${NAMESPACE}
    echo -e "${GREEN}✓ Secret 'app-secrets' created${NC}"
fi

# Step 8: Verify connectivity
echo ""
echo -e "${YELLOW}[8/8] Verifying setup...${NC}"

# Check cluster info
if kubectl cluster-info &> /dev/null; then
    echo -e "${GREEN}✓ Kubernetes cluster is accessible${NC}"
else
    echo -e "${RED}❌ Cannot access Kubernetes cluster${NC}"
    exit 1
fi

# Check nodes
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | xargs)
echo -e "${GREEN}✓ Cluster has ${NODE_COUNT} node(s)${NC}"

# Check namespace
echo -e "${GREEN}✓ Namespace '${NAMESPACE}' is ready${NC}"

# Check secrets
SECRET_COUNT=$(kubectl get secrets -n ${NAMESPACE} --no-headers 2>/dev/null | wc -l | xargs)
echo -e "${GREEN}✓ Found ${SECRET_COUNT} secret(s) in namespace${NC}"

# Check docker services
DOCKER_SERVICES=$(docker ps --format '{{.Names}}' | grep -E 'postgres|kafka|zookeeper' | wc -l | xargs)
echo -e "${GREEN}✓ ${DOCKER_SERVICES} infrastructure service(s) running${NC}"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ Infrastructure setup complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Build and deploy services:"
echo -e "   ${BLUE}./e2e-test.sh${NC}"
echo ""
echo "2. Or deploy manually:"
echo -e "   ${BLUE}kubectl apply -f k8s/ -n ${NAMESPACE}${NC}"
echo ""
echo "3. Check deployment status:"
echo -e "   ${BLUE}kubectl get pods -n ${NAMESPACE}${NC}"
echo ""
echo "4. Access frontend (after deployment):"
echo -e "   ${BLUE}kubectl port-forward svc/frontend 3000:80 -n ${NAMESPACE}${NC}"
echo -e "   Then open: ${BLUE}http://localhost:3000${NC}"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo -e "  View logs:        ${BLUE}kubectl logs -f deployment/auth -n ${NAMESPACE}${NC}"
echo -e "  Check status:     ${BLUE}kubectl get all -n ${NAMESPACE}${NC}"
echo -e "  Restart service:  ${BLUE}kubectl rollout restart deployment/auth -n ${NAMESPACE}${NC}"
echo ""
echo -e "${YELLOW}To cleanup:${NC}"
echo -e "  ${BLUE}kubectl delete all --all -n ${NAMESPACE}${NC}"
echo -e "  ${BLUE}docker-compose down${NC}"
echo -e "  ${BLUE}kind delete cluster --name ${CLUSTER_NAME}${NC}"
echo ""
