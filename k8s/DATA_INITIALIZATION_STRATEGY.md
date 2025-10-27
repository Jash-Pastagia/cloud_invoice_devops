# Kubernetes Data Initialization Strategy
# =====================================

## Overview
This document outlines how to replicate docker-compose seed data functionality in Kubernetes,
ensuring databases are properly initialized and demo users are seeded before application services start.

## Components Required

### 1. Database Initialization
- **ConfigMaps**: Store SQL migration files and seed scripts
- **Init Containers**: Run database setup before main application containers
- **Jobs**: One-time seed data creation tasks
- **Secrets**: Database credentials, JWT secrets

### 2. Execution Order
1. PostgreSQL StatefulSet starts
2. Database init Job runs (creates schemas, tables, indexes)
3. Seed data Job runs (creates demo users)
4. Kafka StatefulSet starts
5. Application Deployments start (with proper dependencies)

### 3. Key Design Decisions

#### Database Schema Management
- Use Kubernetes Jobs for running SQL migrations
- Store migration files in ConfigMaps
- Use init containers in services for table verification
- Implement idempotent operations (CREATE IF NOT EXISTS, etc.)

#### Seed Data Management
- Create dedicated seed-data Job using Node.js image
- Mount seed script via ConfigMap
- Use environment variables for database connection
- Run only once using Job completion tracking

#### Service Dependencies
- Use initContainers to wait for database readiness
- Implement proper readiness/liveness probes
- Use Kubernetes Services for service discovery
- Configure resource requests/limits appropriately

### 4. Files to Create

#### Database Setup
- `k8s/configmaps/db-migrations.yaml` - SQL migration files
- `k8s/configmaps/db-seed-script.yaml` - Node.js seed script
- `k8s/jobs/db-init-job.yaml` - Database initialization
- `k8s/jobs/seed-data-job.yaml` - User seeding

#### Infrastructure
- `k8s/statefulsets/postgresql.yaml` - Database with persistent volume
- `k8s/statefulsets/kafka.yaml` - Kafka cluster with Zookeeper
- `k8s/services/` - Service definitions for all components

#### Applications  
- `k8s/deployments/` - All microservice deployments with init containers
- `k8s/configmaps/app-configs.yaml` - Application configuration
- `k8s/secrets/app-secrets.yaml` - JWT secrets, DB passwords

#### Networking & Storage
- `k8s/services/` - ClusterIP and LoadBalancer services
- `k8s/ingress.yaml` - Ingress for external access
- `k8s/persistent-volumes/` - Storage for PostgreSQL and Kafka

### 5. Testing Strategy

#### Validation Steps
1. Verify K3s cluster is healthy
2. Apply all manifests in correct order
3. Check Job completion status
4. Validate database schema and seed data
5. Test service connectivity and API endpoints
6. Verify frontend can authenticate with demo users

#### Health Checks
- PostgreSQL: `pg_isready` readiness probe
- Kafka: TCP socket check on 9092
- Services: HTTP health check endpoints
- Frontend: HTTP availability check

### 6. Deployment Commands

```bash
# 1. Apply secrets and configmaps
kubectl apply -f k8s/secrets/
kubectl apply -f k8s/configmaps/

# 2. Apply persistent volumes
kubectl apply -f k8s/persistent-volumes/

# 3. Deploy infrastructure
kubectl apply -f k8s/statefulsets/postgresql.yaml
kubectl wait --for=condition=ready pod -l app=postgresql --timeout=300s

# 4. Run database initialization
kubectl apply -f k8s/jobs/db-init-job.yaml
kubectl wait --for=condition=complete job/db-init-job --timeout=300s

# 5. Run seed data job
kubectl apply -f k8s/jobs/seed-data-job.yaml  
kubectl wait --for=condition=complete job/seed-data-job --timeout=300s

# 6. Deploy Kafka
kubectl apply -f k8s/statefulsets/kafka.yaml
kubectl wait --for=condition=ready pod -l app=kafka --timeout=300s

# 7. Deploy application services
kubectl apply -f k8s/deployments/
kubectl apply -f k8s/services/

# 8. Apply ingress
kubectl apply -f k8s/ingress.yaml
```

### 7. Monitoring and Troubleshooting

#### Log Analysis
```bash
# Check job logs
kubectl logs job/db-init-job
kubectl logs job/seed-data-job

# Check service logs
kubectl logs deployment/auth-service
kubectl logs deployment/invoice-service

# Check database connectivity
kubectl exec -it postgresql-0 -- psql -U postgres -d invoicedb -c "\dt"
```

#### Common Issues
- **PV binding failures**: Check storage class and node capacity
- **Job failures**: Verify database connectivity and permissions
- **Service startup**: Check init container logs and dependencies
- **Network issues**: Verify service discovery and DNS resolution

This strategy ensures reliable, repeatable deployment with proper data initialization in Kubernetes.