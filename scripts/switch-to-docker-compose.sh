#!/bin/bash

set -e

export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

echo "🔄 Switching from Kubernetes to Docker Compose..."
echo ""

# Stop port forwards
echo "🛑 Stopping kubectl port forwards..."
pkill -f "kubectl port-forward" 2>/dev/null || true
sleep 2

# Note about kind cluster
echo ""
echo "ℹ️  Keeping kind cluster running (you can access k8s services if needed)"
echo "   To delete it later: kind delete cluster --name innovative-ci"
echo ""

# Check if Docker is running
if ! docker ps &>/dev/null; then
    echo "❌ Docker is not running!"
    echo "   Please start Docker Desktop and try again."
    exit 1
fi

echo "🐳 Starting all services with Docker Compose..."
echo ""

# Start docker-compose
docker-compose down 2>/dev/null || true
docker-compose up -d

echo ""
echo "⏳ Waiting for services to be healthy..."
sleep 10

# Check status
echo ""
echo "📊 Service Status:"
docker-compose ps

echo ""
echo "✅ All services started!"
echo ""
echo "📡 Available Endpoints:"
echo "   🎨 Frontend:      http://localhost:3000"
echo "   🔐 Auth:          http://localhost:4000"
echo "   📄 Invoice:       http://localhost:5050"
echo "   💳 Payment:       http://localhost:6060"
echo "   🔔 Notification:  http://localhost:7200"
echo "   📊 Analytics:     http://localhost:7100"
echo "   🔍 Kafka UI:      http://localhost:8080"
echo ""
echo "👤 Login Credentials:"
echo "   Username: demo"
echo "   Password: demo123"
echo ""
echo "🎉 Open http://localhost:3000 in your browser!"
echo ""
echo "📝 Commands:"
echo "   docker-compose logs -f           # View all logs"
echo "   docker-compose logs -f frontend  # View frontend logs"
echo "   docker-compose ps                # Check status"
echo "   docker-compose down              # Stop everything"
echo ""
