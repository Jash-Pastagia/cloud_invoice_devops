#!/bin/bash

export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

echo "🚀 Starting port forwarding for all services..."
echo ""

# Kill any existing port forwards
echo "🧹 Cleaning up existing port forwards..."
pkill -f "kubectl port-forward" 2>/dev/null
sleep 2

# Check if kind cluster is running
if ! kubectl cluster-info &>/dev/null; then
    echo "❌ Kubernetes cluster not accessible!"
    echo "   Run: kind create cluster --name innovative-ci"
    exit 1
fi

# Check if services exist
echo "🔍 Checking services..."
SERVICES=$(kubectl get svc --no-headers 2>/dev/null | awk '{print $1}')

if echo "$SERVICES" | grep -q "auth-service"; then
    echo "✅ auth-service found"
    kubectl port-forward svc/auth-service 4000:4000 &
    PF_AUTH=$!
else
    echo "⚠️  auth-service not found"
fi

if echo "$SERVICES" | grep -q "invoice-service"; then
    echo "✅ invoice-service found"
    kubectl port-forward svc/invoice-service 5050:5050 &
    PF_INVOICE=$!
else
    echo "⚠️  invoice-service not found"
fi

if echo "$SERVICES" | grep -q "payment-service"; then
    echo "✅ payment-service found"
    kubectl port-forward svc/payment-service 6060:6060 &
    PF_PAYMENT=$!
else
    echo "⚠️  payment-service not found"
fi

if echo "$SERVICES" | grep -q "notification-service"; then
    echo "✅ notification-service found"
    kubectl port-forward svc/notification-service 7200:7200 &
    PF_NOTIF=$!
else
    echo "ℹ️  notification-service not deployed (optional)"
fi

if echo "$SERVICES" | grep -q "analytics-service"; then
    echo "✅ analytics-service found"
    kubectl port-forward svc/analytics-service 7100:7100 &
    PF_ANALYTICS=$!
else
    echo "ℹ️  analytics-service not deployed (optional)"
fi

sleep 3

echo ""
echo "✅ Port forwarding active!"
echo ""
echo "📡 Available Endpoints:"
echo "   🔐 Auth:         http://localhost:4000"
echo "   📄 Invoice:      http://localhost:5050"
echo "   💳 Payment:      http://localhost:6060"
[ -n "$PF_NOTIF" ] && echo "   🔔 Notification: http://localhost:7200"
[ -n "$PF_ANALYTICS" ] && echo "   📊 Analytics:    http://localhost:7100"
echo ""
echo "🎨 Start your frontend with:"
echo "   cd frontend && npm run dev"
echo ""
echo "⏸️  Press Ctrl+C to stop all port forwards"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "🛑 Stopping port forwards..."
    pkill -f "kubectl port-forward"
    exit 0
}

trap cleanup INT TERM

# Wait indefinitely
wait
