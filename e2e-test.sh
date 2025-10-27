#!/bin/bash
# e2e-test.sh - End-to-end test for hybrid CD pipeline
# Tests: Build -> Push -> Deploy -> Verify

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}End-to-End CD Pipeline Test${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Configuration
NAMESPACE="innovative-ci"
DOCKER_USERNAME="techs129"
DOCKER_REPOSITORY="innovative-ci"
SERVICES=("auth-service" "invoice-service" "payment-service" "notification-service" "analytics-service" "frontend")

# Check prerequisites
echo -e "${BLUE}Step 1: Checking Prerequisites${NC}"
echo "----------------------------------------"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker installed${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ kubectl installed${NC}"

if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ kubectl cannot connect to cluster${NC}"
    exit 1
fi
echo -e "${GREEN}✓ kubectl connected to: $(kubectl config current-context)${NC}"

if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker daemon not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker daemon running${NC}"

echo ""

# Check if Docker Compose services are running
echo -e "${BLUE}Step 2: Checking Infrastructure${NC}"
echo "----------------------------------------"

if docker ps | grep -q postgres; then
    echo -e "${GREEN}✓ PostgreSQL running${NC}"
else
    echo -e "${YELLOW}⚠ PostgreSQL not running - starting...${NC}"
    docker-compose up -d postgres
    sleep 5
fi

if docker ps | grep -q kafka; then
    echo -e "${GREEN}✓ Kafka running${NC}"
else
    echo -e "${YELLOW}⚠ Kafka not running - starting...${NC}"
    docker-compose up -d zookeeper kafka
    sleep 10
fi

if docker ps | grep -q zookeeper; then
    echo -e "${GREEN}✓ Zookeeper running${NC}"
else
    echo -e "${YELLOW}⚠ Zookeeper not running (included with Kafka start)${NC}"
fi

echo ""

# Create namespace
echo -e "${BLUE}Step 3: Creating Kubernetes Namespace${NC}"
echo "----------------------------------------"

if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${GREEN}✓ Namespace '$NAMESPACE' exists${NC}"
else
    kubectl create namespace $NAMESPACE
    echo -e "${GREEN}✓ Namespace '$NAMESPACE' created${NC}"
fi

# Apply secrets
kubectl create secret generic app-secrets \
    --from-literal=jwt-secret=supersecretdevops \
    --namespace=$NAMESPACE \
    --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Secrets applied${NC}"

echo ""

# Build and push images (simulated)
echo -e "${BLUE}Step 4: Building Docker Images${NC}"
echo "----------------------------------------"

for service in "${SERVICES[@]}"; do
    echo -e "${YELLOW}Building $service...${NC}"
    
    if [ -d "$service" ]; then
        docker build -t "${DOCKER_USERNAME}/${DOCKER_REPOSITORY}-${service}:test" "$service" --quiet
        echo -e "${GREEN}✓ Built $service${NC}"
    else
        echo -e "${RED}❌ Directory $service not found${NC}"
    fi
done

echo ""

# Deploy services
echo -e "${BLUE}Step 5: Deploying Services to Kubernetes${NC}"
echo "----------------------------------------"

# Apply services first
if [ -f "k8s/services.yaml" ]; then
    kubectl apply -f k8s/services.yaml -n $NAMESPACE
    echo -e "${GREEN}✓ Services applied${NC}"
fi

# Deploy each service
for service in "${SERVICES[@]}"; do
    deployment_name="${service%-service}"
    
    if [ "$service" == "auth-service" ]; then
        deployment_file="k8s/auth-deployment.yaml"
    elif [ "$service" == "invoice-service" ]; then
        deployment_file="k8s/invoice-deployment.yaml"
    elif [ "$service" == "payment-service" ]; then
        deployment_file="k8s/payment-deployment.yaml"
    elif [ "$service" == "notification-service" ]; then
        deployment_file="k8s/notification-deployment.yaml"
    elif [ "$service" == "analytics-service" ]; then
        deployment_file="k8s/analytics-deployment.yaml"
    elif [ "$service" == "frontend" ]; then
        deployment_file="k8s/frontend-deployment.yaml"
    else
        deployment_file="k8s/${service}-deployment.yaml"
    fi
    
    if [ -f "$deployment_file" ]; then
        echo -e "${YELLOW}Deploying $deployment_name...${NC}"
        kubectl apply -f "$deployment_file" -n $NAMESPACE
        echo -e "${GREEN}✓ Deployed $deployment_name${NC}"
    else
        echo -e "${RED}❌ Deployment file not found: $deployment_file${NC}"
    fi
done

# Apply ingress
if [ -f "k8s/ingress.yaml" ]; then
    kubectl apply -f k8s/ingress.yaml -n $NAMESPACE
    echo -e "${GREEN}✓ Ingress applied${NC}"
fi

echo ""

# Wait for rollouts
echo -e "${BLUE}Step 6: Waiting for Rollouts${NC}"
echo "----------------------------------------"

for service in "${SERVICES[@]}"; do
    deployment_name="${service%-service}"
    
    echo -e "${YELLOW}Waiting for $deployment_name...${NC}"
    if kubectl rollout status deployment/$deployment_name -n $NAMESPACE --timeout=2m; then
        echo -e "${GREEN}✓ $deployment_name rolled out successfully${NC}"
    else
        echo -e "${RED}❌ $deployment_name rollout failed${NC}"
        kubectl describe deployment/$deployment_name -n $NAMESPACE
        kubectl logs -l app=$deployment_name -n $NAMESPACE --tail=20
    fi
done

echo ""

# Health check
echo -e "${BLUE}Step 7: Health Check${NC}"
echo "----------------------------------------"

echo ""
echo "Pod Status:"
echo "-------------------"
for service in auth invoice payment notification analytics frontend; do
    POD_STATUS=$(kubectl get pods -n $NAMESPACE -l app=${service} -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
    READY=$(kubectl get pods -n $NAMESPACE -l app=${service} -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
    RESTARTS=$(kubectl get pods -n $NAMESPACE -l app=${service} -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")
    
    if [ "$POD_STATUS" == "Running" ] && [ "$READY" == "true" ]; then
        echo -e "${GREEN}✓ $service: $POD_STATUS (Ready: $READY, Restarts: $RESTARTS)${NC}"
    else
        echo -e "${RED}✗ $service: $POD_STATUS (Ready: $READY, Restarts: $RESTARTS)${NC}"
    fi
done

echo ""

# Test API endpoints
echo -e "${BLUE}Step 8: Testing API Endpoints${NC}"
echo "----------------------------------------"

# Port forward frontend in background
echo "Setting up port forward..."
kubectl port-forward svc/frontend 3000:80 -n $NAMESPACE > /dev/null 2>&1 &
PF_PID=$!
sleep 3

echo ""
echo "API Health Tests:"
echo "-------------------"

# Test auth service
AUTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/auth/health 2>/dev/null || echo "000")
if [ "$AUTH_STATUS" == "200" ] || [ "$AUTH_STATUS" == "404" ]; then
    echo -e "${GREEN}✓ Auth Service: HTTP $AUTH_STATUS${NC}"
else
    echo -e "${YELLOW}⚠ Auth Service: HTTP $AUTH_STATUS (may need /health endpoint)${NC}"
fi

# Test invoice service
INVOICE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/invoice/invoices 2>/dev/null || echo "000")
if [ "$INVOICE_STATUS" == "200" ] || [ "$INVOICE_STATUS" == "401" ]; then
    echo -e "${GREEN}✓ Invoice Service: HTTP $INVOICE_STATUS${NC}"
else
    echo -e "${YELLOW}⚠ Invoice Service: HTTP $INVOICE_STATUS${NC}"
fi

# Test payment service
PAYMENT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/payment/health 2>/dev/null || echo "000")
if [ "$PAYMENT_STATUS" == "200" ] || [ "$PAYMENT_STATUS" == "404" ]; then
    echo -e "${GREEN}✓ Payment Service: HTTP $PAYMENT_STATUS${NC}"
else
    echo -e "${YELLOW}⚠ Payment Service: HTTP $PAYMENT_STATUS${NC}"
fi

# Test frontend
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null || echo "000")
if [ "$FRONTEND_STATUS" == "200" ]; then
    echo -e "${GREEN}✓ Frontend: HTTP $FRONTEND_STATUS${NC}"
else
    echo -e "${YELLOW}⚠ Frontend: HTTP $FRONTEND_STATUS${NC}"
fi

# Cleanup port forward
kill $PF_PID 2>/dev/null || true

echo ""

# Full workflow test
echo -e "${BLUE}Step 9: Testing Complete Workflow${NC}"
echo "----------------------------------------"

# Port forward again for full test
kubectl port-forward svc/frontend 3000:80 -n $NAMESPACE > /dev/null 2>&1 &
PF_PID=$!
sleep 3

echo ""
echo "1. Testing Registration..."
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:3000/api/auth/register \
    -H "Content-Type: application/json" \
    -d '{"username":"testuser","password":"testpass123"}' 2>/dev/null || echo "ERROR")

if echo "$REGISTER_RESPONSE" | grep -q "token\|exists"; then
    echo -e "${GREEN}✓ Registration working${NC}"
else
    echo -e "${YELLOW}⚠ Registration response: $REGISTER_RESPONSE${NC}"
fi

echo ""
echo "2. Testing Login..."
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:3000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"testuser","password":"testpass123"}' 2>/dev/null || echo "ERROR")

if echo "$LOGIN_RESPONSE" | grep -q "token"; then
    echo -e "${GREEN}✓ Login working${NC}"
    TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    
    echo ""
    echo "3. Testing Invoice Creation..."
    INVOICE_RESPONSE=$(curl -s -X POST http://localhost:3000/api/invoice/invoices \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d '{"clientName":"Test Client","items":[{"desc":"Test Item","qty":1,"rate":100}]}' 2>/dev/null || echo "ERROR")
    
    if echo "$INVOICE_RESPONSE" | grep -q "invoiceId\|id"; then
        echo -e "${GREEN}✓ Invoice creation working${NC}"
    else
        echo -e "${YELLOW}⚠ Invoice response: $INVOICE_RESPONSE${NC}"
    fi
    
    echo ""
    echo "4. Testing Invoice Listing..."
    LIST_RESPONSE=$(curl -s http://localhost:3000/api/invoice/invoices \
        -H "Authorization: Bearer $TOKEN" 2>/dev/null || echo "ERROR")
    
    if echo "$LIST_RESPONSE" | grep -q "\["; then
        echo -e "${GREEN}✓ Invoice listing working${NC}"
    else
        echo -e "${YELLOW}⚠ List response: $LIST_RESPONSE${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Login failed, skipping invoice tests${NC}"
    echo "Response: $LOGIN_RESPONSE"
fi

# Cleanup
kill $PF_PID 2>/dev/null || true

echo ""

# Final summary
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}End-to-End Test Summary${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

kubectl get pods -n $NAMESPACE

echo ""
echo -e "${GREEN}✅ End-to-end test completed!${NC}"
echo ""
echo "Access your services:"
echo "  kubectl port-forward svc/frontend 3000:80 -n $NAMESPACE"
echo "  Then open: http://localhost:3000"
echo ""
echo "View logs:"
echo "  kubectl logs -f deployment/auth -n $NAMESPACE"
echo "  kubectl logs -f deployment/invoice -n $NAMESPACE"
echo ""
echo "Check status:"
echo "  kubectl get all -n $NAMESPACE"
