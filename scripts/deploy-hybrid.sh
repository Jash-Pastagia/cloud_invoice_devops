#!/bin/bash

set -e

echo "========================================="
echo "Hybrid Deployment: Kafka in Docker, Services in K8s"
echo "========================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 1. Start Kafka stack in Docker
echo -e "${YELLOW}1. Starting Kafka, Zookeeper, and PostgreSQL in Docker...${NC}"
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
docker compose up -d zookeeper kafka postgres
sleep 15
echo -e "${GREEN}✓ Kafka stack started${NC}"
echo ""

# 2. Get Docker host IP for kind cluster
echo -e "${YELLOW}2. Detecting Docker host IP...${NC}"
# For kind, services can access Docker host via host.docker.internal or the gateway IP
DOCKER_HOST_IP="host.docker.internal"
echo "Using: $DOCKER_HOST_IP"
echo -e "${GREEN}✓ Host IP configured${NC}"
echo ""

# 3. Create/Update secrets with external database and Kafka
echo -e "${YELLOW}3. Configuring Kubernetes secrets...${NC}"
kubectl delete secret app-secrets 2>/dev/null || true
kubectl create secret generic app-secrets \
  --from-literal=POSTGRES_USER=postgres \
  --from-literal=POSTGRES_PASSWORD=postgres \
  --from-literal=POSTGRES_DB=invoicedb \
  --from-literal=JWT_SECRET=supersecretdevops \
  --from-literal=DB_HOST=$DOCKER_HOST_IP \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME=invoicedb \
  --from-literal=DB_USER=postgres \
  --from-literal=DB_PASSWORD=postgres \
  --from-literal=KAFKA_BROKERS=$DOCKER_HOST_IP:9092

echo -e "${GREEN}✓ Secrets configured${NC}"
echo ""

# 4. Deploy backend services to K8s
echo -e "${YELLOW}4. Deploying backend services to Kubernetes...${NC}"
kubectl apply -f k8s/auth-deployment.yaml
kubectl apply -f k8s/invoice-deployment.yaml
kubectl apply -f k8s/payment-deployment.yaml
kubectl apply -f k8s/notification-deployment.yaml
kubectl apply -f k8s/analytics-deployment.yaml

sleep 10
echo "Waiting for services..."
kubectl wait --for=condition=available deployment/auth-service --timeout=120s || true
kubectl wait --for=condition=available deployment/invoice-service --timeout=120s || true
kubectl wait --for=condition=available deployment/payment-service --timeout=120s || true

echo -e "${GREEN}✓ Backend services deployed${NC}"
echo ""

# 5. Deploy frontend to K8s
echo -e "${YELLOW}5. Deploying frontend to Kubernetes...${NC}"
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/services.yaml

sleep 5
kubectl wait --for=condition=available deployment/frontend --timeout=120s || true

echo -e "${GREEN}✓ Frontend deployed${NC}"
echo ""

# 6. Show status
echo "========================================="
echo "Deployment Status"
echo "========================================="
kubectl get pods
echo ""
kubectl get svc
echo ""

echo "========================================="
echo -e "${GREEN}✓ Hybrid Deployment Complete!${NC}"
echo "========================================="
echo ""
echo "Services Running:"
echo -e "${GREEN}✓ Kafka (Docker):${NC} localhost:9092"
echo -e "${GREEN}✓ PostgreSQL (Docker):${NC} localhost:5432"
echo -e "${GREEN}✓ Kafka UI (Docker):${NC} http://localhost:8080"
echo -e "${GREEN}✓ Backend Services (K8s):${NC} auth, invoice, payment, notification, analytics"
echo -e "${GREEN}✓ Frontend (K8s):${NC} http://localhost:3000"
echo ""
echo "Login credentials:"
echo "  Username: demo"
echo "  Password: demo123"
echo ""
echo "Useful commands:"
echo "  kubectl logs -f deployment/auth-service"
echo "  kubectl get pods"
echo "  docker compose logs -f kafka"
echo ""
