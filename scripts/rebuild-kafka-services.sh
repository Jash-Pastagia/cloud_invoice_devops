#!/bin/bash
set -e

echo "🔨 Rebuilding Kafka-dependent services..."

cd "/Users/meghshah/Megh Data/B.TECH Folder/Sem 7/DevOps/Innovative/cloud_invoice_devops"

# Services that use lib/kafka.js
SERVICES=("invoice-service" "payment-service" "notification-service" "analytics-service")

for SERVICE in "${SERVICES[@]}"; do
    echo ""
    echo "📦 Building $SERVICE..."
    docker build -t techs129/innovative-ci-$SERVICE:latest -f $SERVICE/Dockerfile .
    
    echo "⬆️  Pushing $SERVICE..."
    docker push techs129/innovative-ci-$SERVICE:latest
done

echo ""
echo "🔄 Restarting Kubernetes deployments..."
kubectl rollout restart deployment/invoice-service
kubectl rollout restart deployment/payment-service
kubectl rollout restart deployment/notification-service
kubectl rollout restart deployment/analytics-service

echo ""
echo "⏳ Waiting for rollout to complete..."
kubectl rollout status deployment/invoice-service --timeout=120s
kubectl rollout status deployment/payment-service --timeout=120s
kubectl rollout status deployment/notification-service --timeout=120s
kubectl rollout status deployment/analytics-service --timeout=120s

echo ""
echo "✅ All services rebuilt and redeployed!"
