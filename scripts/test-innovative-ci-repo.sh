#!/bin/bash

# test-innovative-ci-repo.sh
# Test pushing to innovative_ci repository and running full stack

set -e

echo "🧪 Testing innovative_ci repository push and stack..."
echo "=================================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
DOCKERHUB_USERNAME=${DOCKERHUB_USERNAME:-"techs129"}
DOCKERHUB_TOKEN=${DOCKERHUB_TOKEN:-""}
REPO_PREFIX="innovative-ci"
IMAGE_TAG=${IMAGE_TAG:-"test-$(date +%s)"}

if [ -z "$DOCKERHUB_TOKEN" ]; then
    echo -e "${RED}❌ DOCKERHUB_TOKEN environment variable is not set${NC}"
    echo "Please set it with: export DOCKERHUB_TOKEN=your_docker_hub_token"
    exit 1
fi

# Services to build and push
SERVICES=("auth-service" "invoice-service" "payment-service" "notification-service" "analytics-service" "frontend")

echo -e "${YELLOW}Step 1: Login to Docker Hub...${NC}"
echo "$DOCKERHUB_TOKEN" | docker login docker.io -u "$DOCKERHUB_USERNAME" --password-stdin

echo -e "\n${YELLOW}Step 2: Build and push all services to innovative_ci repository...${NC}"
for service in "${SERVICES[@]}"; do
    echo -e "\n${YELLOW}Building and pushing $service...${NC}"
    
    if [ ! -f "$service/Dockerfile" ]; then
        echo -e "${RED}❌ Dockerfile not found for $service${NC}"
        continue
    fi
    
    # Build the image locally first
    LOCAL_TAG="$DOCKERHUB_USERNAME/$REPO_PREFIX-$service:$IMAGE_TAG"
    
    echo "Building: $LOCAL_TAG"
    docker build -f "./$service/Dockerfile" -t "$LOCAL_TAG" --build-arg NODE_ENV=production .
    
    # Also tag as latest
    docker tag "$LOCAL_TAG" "$DOCKERHUB_USERNAME/$REPO_PREFIX-$service:latest"
    
    echo "Pushing: $LOCAL_TAG"
    docker push "$LOCAL_TAG"
    
    echo "Pushing: $DOCKERHUB_USERNAME/$REPO_PREFIX-$service:latest"
    docker push "$DOCKERHUB_USERNAME/$REPO_PREFIX-$service:latest"
    
    echo -e "${GREEN}✅ $service pushed successfully${NC}"
done

echo -e "\n${YELLOW}Step 3: Test pulling images...${NC}"
for service in "${SERVICES[@]}"; do
    IMAGE_NAME="$DOCKERHUB_USERNAME/$REPO_PREFIX-$service:latest"
    echo "Testing pull: $IMAGE_NAME"
    
    # Remove local image if exists
    docker rmi "$IMAGE_NAME" 2>/dev/null || true
    
    # Pull from Docker Hub
    docker pull "$IMAGE_NAME"
    echo -e "${GREEN}✅ Successfully pulled $IMAGE_NAME${NC}"
done

echo -e "\n${YELLOW}Step 4: Create .env file for docker-compose...${NC}"
cat > .env.registry << EOF
DOCKER_REGISTRY=docker.io
DOCKER_REPOSITORY=$DOCKERHUB_USERNAME/$REPO_PREFIX
IMAGE_TAG=latest
EOF

echo "Created .env.registry with:"
cat .env.registry

echo -e "\n${YELLOW}Step 5: Test docker-compose with registry images...${NC}"
echo "Starting infrastructure services first..."
docker-compose -f docker-compose.registry.yml --env-file .env.registry up -d zookeeper kafka postgres kafka-ui

echo "Waiting for infrastructure to be ready..."
sleep 10

echo "Starting application services..."
docker-compose -f docker-compose.registry.yml --env-file .env.registry up -d

echo -e "\n${YELLOW}Step 6: Check service status...${NC}"
docker-compose -f docker-compose.registry.yml --env-file .env.registry ps

echo -e "\n${YELLOW}Step 7: Test service connectivity...${NC}"
sleep 5

# Test if services are responding
echo "Testing auth-service..."
curl -f http://localhost:4000/health 2>/dev/null && echo -e "${GREEN}✅ auth-service is responding${NC}" || echo -e "${RED}❌ auth-service not responding${NC}"

echo "Testing invoice-service..."
curl -f http://localhost:5050/health 2>/dev/null && echo -e "${GREEN}✅ invoice-service is responding${NC}" || echo -e "${RED}❌ invoice-service not responding${NC}"

echo "Testing frontend..."
curl -f http://localhost:3000 2>/dev/null && echo -e "${GREEN}✅ frontend is responding${NC}" || echo -e "${RED}❌ frontend not responding${NC}"

echo -e "\n${GREEN}🎉 innovative_ci repository test completed!${NC}"
echo -e "${YELLOW}Docker Hub repository: https://hub.docker.com/r/$DOCKERHUB_USERNAME/$REPO_PREFIX${NC}"
echo -e "${YELLOW}Services are running on:${NC}"
echo "  - Frontend: http://localhost:3000"
echo "  - Auth Service: http://localhost:4000"
echo "  - Invoice Service: http://localhost:5050"
echo "  - Payment Service: http://localhost:6060"
echo "  - Notification Service: http://localhost:7200"
echo "  - Analytics Service: http://localhost:7100"
echo "  - Kafka UI: http://localhost:8080"

echo -e "\n${YELLOW}To stop the stack:${NC}"
echo "docker-compose -f docker-compose.registry.yml --env-file .env.registry down"

echo -e "\n${YELLOW}To run the stack again:${NC}"
echo "docker-compose -f docker-compose.registry.yml --env-file .env.registry up -d"