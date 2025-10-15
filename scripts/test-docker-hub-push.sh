#!/bin/bash

# test-docker-hub-push.sh
# Test Docker Hub authentication and push locally before running CI

set -e

echo "🧪 Testing Docker Hub push locally..."
echo "======================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker Hub credentials are provided
DOCKERHUB_USERNAME=${DOCKERHUB_USERNAME:-"techs129"}
DOCKERHUB_TOKEN=${DOCKERHUB_TOKEN:-""}

if [ -z "$DOCKERHUB_TOKEN" ]; then
    echo -e "${RED}❌ DOCKERHUB_TOKEN environment variable is not set${NC}"
    echo "Please set it with: export DOCKERHUB_TOKEN=your_token"
    echo "Set your Docker Hub token with: export DOCKERHUB_TOKEN=your_token_here"
    exit 1
fi

echo -e "${YELLOW}Testing Docker Hub login...${NC}"
echo "$DOCKERHUB_TOKEN" | docker login docker.io -u "$DOCKERHUB_USERNAME" --password-stdin

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Docker Hub login successful${NC}"
else
    echo -e "${RED}❌ Docker Hub login failed${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Building a test image...${NC}"
# Create a simple test Dockerfile
cat > Dockerfile.test << EOF
FROM alpine:latest
RUN echo "Test image for Docker Hub push validation"
CMD echo "Hello from test image"
EOF

# Build test image
TEST_IMAGE="$DOCKERHUB_USERNAME/test-ci-validation:$(date +%s)"
docker build -f Dockerfile.test -t "$TEST_IMAGE" .

echo -e "\n${YELLOW}Pushing test image to Docker Hub...${NC}"
docker push "$TEST_IMAGE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Test image push successful${NC}"
    echo -e "${GREEN}✅ Image available at: https://hub.docker.com/r/$DOCKERHUB_USERNAME/test-ci-validation${NC}"
    
    echo -e "\n${YELLOW}Testing pull...${NC}"
    docker rmi "$TEST_IMAGE" || true
    docker pull "$TEST_IMAGE"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Test image pull successful${NC}"
        echo -e "${GREEN}🎉 Docker Hub integration is working correctly!${NC}"
    else
        echo -e "${RED}❌ Test image pull failed${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Test image push failed${NC}"
    exit 1
fi

# Cleanup
docker rmi "$TEST_IMAGE" || true
rm -f Dockerfile.test

echo -e "\n${GREEN}🚀 Ready to run CI with Docker Hub push enabled!${NC}"
echo -e "${YELLOW}Make sure these secrets are set in your GitHub repository:${NC}"
echo "  - PUSH_IMAGES=true"
echo "  - REGISTRY=docker.io (optional, defaults to docker.io now)"
echo "  - DOCKERHUB_USERNAME=techs129"
echo "  - DOCKERHUB_TOKEN=your_docker_hub_token"