#!/bin/bash

set -e

echo "========================================="
echo "Deploying Cloud Invoice System to Kubernetes"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if kind cluster exists
echo -e "${YELLOW}Checking Kubernetes cluster...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Kubernetes cluster not accessible${NC}"
    echo "Please ensure kind cluster is running: kind create cluster --name innovative-ci"
    exit 1
fi

echo -e "${GREEN}✓ Kubernetes cluster is accessible${NC}"
echo ""

# Stop any running docker-compose services
echo -e "${YELLOW}Stopping Docker Compose services...${NC}"
docker compose down 2>/dev/null || true
echo -e "${GREEN}✓ Docker Compose stopped${NC}"
echo ""

# Apply Kubernetes manifests in order
echo "========================================="
echo "Deploying Services..."
echo "========================================="
echo ""

# 1. Secrets
echo -e "${YELLOW}1. Creating secrets...${NC}"
kubectl apply -f k8s/secret.yaml
echo -e "${GREEN}✓ Secrets created${NC}"
echo ""

# 2. PostgreSQL
echo -e "${YELLOW}2. Deploying PostgreSQL...${NC}"
kubectl apply -f k8s/postgresql-deployment.yaml
echo "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgresql --timeout=120s
echo -e "${GREEN}✓ PostgreSQL deployed${NC}"
echo ""

# 3. Zookeeper
echo -e "${YELLOW}3. Deploying Zookeeper...${NC}"
kubectl apply -f k8s/zookeeper-deployment.yaml
echo "Waiting for Zookeeper to be ready..."
sleep 10
kubectl wait --for=condition=ready pod -l app=zookeeper --timeout=120s
echo -e "${GREEN}✓ Zookeeper deployed${NC}"
echo ""

# 4. Kafka
echo -e "${YELLOW}4. Deploying Kafka...${NC}"
kubectl apply -f k8s/kafka-deployment.yaml
echo "Waiting for Kafka to be ready..."
sleep 15
kubectl wait --for=condition=ready pod -l app=kafka --timeout=180s
echo -e "${GREEN}✓ Kafka deployed${NC}"
echo ""

# 5. Backend Services
echo -e "${YELLOW}5. Deploying backend services...${NC}"
kubectl apply -f k8s/auth-deployment.yaml
kubectl apply -f k8s/invoice-deployment.yaml
kubectl apply -f k8s/payment-deployment.yaml
kubectl apply -f k8s/notification-deployment.yaml
kubectl apply -f k8s/analytics-deployment.yaml
echo "Waiting for backend services..."
sleep 10
kubectl wait --for=condition=ready pod -l app=auth-service --timeout=120s
kubectl wait --for=condition=ready pod -l app=invoice-service --timeout=120s
kubectl wait --for=condition=ready pod -l app=payment-service --timeout=120s
echo -e "${GREEN}✓ Backend services deployed${NC}"
echo ""

# 6. Frontend
echo -e "${YELLOW}6. Deploying frontend...${NC}"
kubectl apply -f k8s/frontend-deployment.yaml
echo "Waiting for frontend..."
sleep 5
kubectl wait --for=condition=ready pod -l app=frontend --timeout=120s
echo -e "${GREEN}✓ Frontend deployed${NC}"
echo ""

# 7. Services
echo -e "${YELLOW}7. Creating services...${NC}"
kubectl apply -f k8s/services.yaml
echo -e "${GREEN}✓ Services created${NC}"
echo ""

# Check all pods
echo "========================================="
echo "Deployment Status"
echo "========================================="
kubectl get pods
echo ""

echo "========================================="
echo "Services"
echo "========================================="
kubectl get svc
echo ""

# Get frontend URL
FRONTEND_PORT=$(kubectl get svc frontend -o jsonpath='{.spec.ports[0].nodePort}')

echo "========================================="
echo -e "${GREEN}✓ Deployment Complete!${NC}"
echo "========================================="
echo ""
echo "Access your application:"
echo -e "${GREEN}Frontend:${NC} http://localhost:${FRONTEND_PORT}"
echo ""
echo "To access from your browser, you may need to port-forward:"
echo -e "${YELLOW}kubectl port-forward svc/frontend 3000:80${NC}"
echo ""
echo "Then visit: http://localhost:3000"
echo ""
echo "Login credentials:"
echo "  Username: demo"
echo "  Password: demo123"
echo ""
echo "To view logs:"
echo "  kubectl logs -f deployment/[service-name]"
echo ""
echo "To check Kafka:"
echo "  kubectl logs -f deployment/kafka"
echo ""
