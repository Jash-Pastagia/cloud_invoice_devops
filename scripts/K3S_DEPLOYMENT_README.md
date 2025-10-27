# K3s Single-Node Kubernetes Deployment

This directory contains comprehensive scripts and manifests for deploying the invoice system on a single-node K3s Kubernetes cluster with complete data initialization.

## 🎯 Quick Start

**One-command deployment (requires root/sudo):**
```bash
sudo ./scripts/deploy-to-k3s.sh
```

This will:
1. Install K3s single-node cluster
2. Deploy PostgreSQL with persistent storage
3. Initialize database schema and seed demo users
4. Validate entire deployment

## 📁 File Structure

```
scripts/
├── k3s-single-node.sh         # Safe K3s installation script
├── deploy-to-k3s.sh          # Complete deployment orchestration
└── test-k3s-deployment.sh    # Comprehensive validation tests

k8s/
├── configmaps/
│   ├── db-migrations.yaml     # Database schema SQL
│   └── seed-script.yaml       # Node.js user seeding script
├── jobs/
│   ├── db-init-job.yaml       # Database initialization job
│   └── seed-data-job.yaml     # Demo user creation job
├── secrets/
│   └── app-secrets.yaml       # Database credentials, JWT secrets
├── statefulsets/
│   └── postgresql.yaml        # PostgreSQL with persistent volumes
└── DATA_INITIALIZATION_STRATEGY.md  # Detailed strategy docs
```

## 🚀 Manual Step-by-Step Deployment

### 1. Install K3s
```bash
sudo ./scripts/k3s-single-node.sh
```

**What it does:**
- Installs K3s v1.28.4+k3s1 (configurable)
- Generates secure random token
- Configures kubeconfig with proper permissions
- Waits for system pods to be ready
- Provides usage instructions

### 2. Deploy Database Infrastructure
```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Apply secrets and configs
kubectl apply -f k8s/secrets/
kubectl apply -f k8s/configmaps/

# Deploy PostgreSQL
kubectl apply -f k8s/statefulsets/postgresql.yaml
kubectl wait --for=condition=ready pod -l app=postgresql --timeout=300s
```

### 3. Initialize Database
```bash
# Create schema and tables
kubectl apply -f k8s/jobs/db-init-job.yaml
kubectl wait --for=condition=complete job/db-init-job --timeout=300s

# Create demo users
kubectl apply -f k8s/jobs/seed-data-job.yaml
kubectl wait --for=condition=complete job/seed-data-job --timeout=300s
```

### 4. Validate Deployment
```bash
sudo ./scripts/test-k3s-deployment.sh
```

## 🔧 Configuration Options

### K3s Installation Options
```bash
# Custom K3s version
K3S_VERSION=v1.29.0+k3s1 sudo -E ./scripts/k3s-single-node.sh

# Custom token
K3S_TOKEN=your-secure-token sudo -E ./scripts/k3s-single-node.sh
```

### Database Configuration
Edit `k8s/secrets/app-secrets.yaml` to change:
- Database credentials
- JWT secrets
- Kafka configuration

**Note:** Values are base64 encoded:
```bash
echo -n "new-password" | base64
```

## 🧪 Testing and Validation

### Comprehensive Test Suite
```bash
sudo ./scripts/test-k3s-deployment.sh
```

**Tests include:**
- ✅ K3s installation and service health
- ✅ Kubernetes manifest deployment
- ✅ Database connectivity and schema validation
- ✅ Demo user creation verification
- ✅ Pod readiness and resource status

### Manual Verification
```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Check cluster status
kubectl get nodes -o wide
kubectl get pods -o wide

# Verify database
kubectl exec -it postgresql-0 -- psql -U postgres -d invoicedb
\dt                           # List tables
SELECT * FROM users;          # Check demo users

# Check job logs
kubectl logs job/db-init-job
kubectl logs job/seed-data-job
```

## 📊 Demo Data

**Created users:**
- **Username:** `demo` | **Password:** `demo123`
- **Username:** `user2` | **Password:** `user2123`

**Database schema includes:**
- `users` - User accounts with bcrypt-hashed passwords
- `invoices` - Multi-user invoice system
- `notifications` - User notifications
- `analytics_events` - Event tracking

## 🛠 Management Commands

### K3s Cluster Management
```bash
# Stop K3s
sudo systemctl stop k3s

# Start K3s
sudo systemctl start k3s

# Uninstall K3s
/usr/local/bin/k3s-uninstall.sh
```

### Application Management
```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Restart database
kubectl rollout restart statefulset/postgresql

# Re-run initialization (if needed)
kubectl delete job db-init-job seed-data-job
kubectl apply -f k8s/jobs/

# Check resource usage
kubectl top pods
kubectl describe pod postgresql-0
```

### Storage Management
```bash
# Check persistent volumes
kubectl get pv,pvc

# Backup database (example)
kubectl exec postgresql-0 -- pg_dump -U postgres invoicedb > backup.sql

# Delete all data (caution!)
kubectl delete all --all
kubectl delete pvc --all
```

## 🔍 Troubleshooting

### Common Issues

**K3s installation fails:**
- Check root privileges: `sudo whoami`
- Verify internet connectivity: `curl -I https://get.k3s.io`
- Check logs: `journalctl -u k3s`

**PostgreSQL pod won't start:**
- Check node storage: `df -h`
- Verify pod logs: `kubectl logs postgresql-0`
- Check events: `kubectl get events --sort-by=.metadata.creationTimestamp`

**Database jobs fail:**
- Check job logs: `kubectl logs job/db-init-job`
- Verify database connectivity: `kubectl exec postgresql-0 -- pg_isready`
- Check secrets: `kubectl get secrets app-secrets -o yaml`

**Storage issues:**
- Check storage class: `kubectl get storageclass`
- Verify PVC binding: `kubectl get pvc`
- Check node capacity: `kubectl describe node`

### Debug Commands
```bash
# Comprehensive cluster info
kubectl cluster-info dump

# Pod resource usage
kubectl top pods --all-namespaces

# Network debugging
kubectl exec -it postgresql-0 -- netstat -tlnp

# Storage debugging
kubectl describe pvc postgresql-data-postgresql-0
```

## 🎯 Next Steps

1. **Add application services** - Deploy auth, invoice, payment microservices
2. **Configure ingress** - Set up external access with ingress controller
3. **Add monitoring** - Deploy Prometheus/Grafana for observability
4. **Implement backups** - Set up automated database backups
5. **Security hardening** - Configure RBAC, network policies, secrets management

## 📚 References

- [K3s Documentation](https://docs.k3s.io/)
- [Kubernetes Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [PostgreSQL on Kubernetes](https://kubernetes.io/docs/tutorials/stateful-application/postgresql/)