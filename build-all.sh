#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOCKER_USERNAME="techs129"
DOCKER_REPOSITORY="innovative-ci"
TAG="${1:-latest}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Building Docker Images              ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Services to build
SERVICES=("auth-service" "invoice-service" "payment-service" "notification-service" "analytics-service" "frontend")

# Build each service
for SERVICE in "${SERVICES[@]}"; do
    SERVICE_DIR="${SERVICE}"
    IMAGE_NAME="${DOCKER_USERNAME}/${DOCKER_REPOSITORY}-${SERVICE}:${TAG}"
    
    echo -e "${YELLOW}Building ${SERVICE}...${NC}"
    
    if [ ! -d "${SERVICE_DIR}" ]; then
        echo -e "${RED}❌ Directory ${SERVICE_DIR} not found${NC}"
        continue
    fi
    
    if [ ! -f "${SERVICE_DIR}/Dockerfile" ]; then
        echo -e "${RED}❌ Dockerfile not found in ${SERVICE_DIR}${NC}"
        continue
    fi
    
    echo -e "${BLUE}Building ${IMAGE_NAME}...${NC}"
    docker build -t ${IMAGE_NAME} ./${SERVICE_DIR}
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Successfully built ${IMAGE_NAME}${NC}"
    else
        echo -e "${RED}❌ Failed to build ${IMAGE_NAME}${NC}"
        exit 1
    fi
    
    echo ""
done

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ All images built successfully!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# List built images
echo -e "${YELLOW}Built images:${NC}"
docker images | grep "${DOCKER_USERNAME}/${DOCKER_REPOSITORY}" | grep "${TAG}"

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Push images to Docker Hub (optional):"
echo -e "   ${BLUE}docker login${NC}"
echo -e "   ${BLUE}docker push ${DOCKER_USERNAME}/${DOCKER_REPOSITORY}-auth-service:${TAG}${NC}"
echo -e "   ${BLUE}docker push ${DOCKER_USERNAME}/${DOCKER_REPOSITORY}-invoice-service:${TAG}${NC}"
echo -e "   ${BLUE}# ... (repeat for all services)${NC}"
echo ""
echo "2. Load images into kind cluster:"
echo -e "   ${BLUE}kind load docker-image ${DOCKER_USERNAME}/${DOCKER_REPOSITORY}-auth-service:${TAG} --name innovative-ci${NC}"
echo -e "   ${BLUE}kind load docker-image ${DOCKER_USERNAME}/${DOCKER_REPOSITORY}-invoice-service:${TAG} --name innovative-ci${NC}"
echo -e "   ${BLUE}# ... (repeat for all services)${NC}"
echo ""
echo "3. Deploy to Kubernetes:"
echo -e "   ${BLUE}kubectl apply -f k8s/ -n innovative-ci${NC}"
echo ""
echo "4. Check status:"
echo -e "   ${BLUE}kubectl get pods -n innovative-ci${NC}"
echo ""
