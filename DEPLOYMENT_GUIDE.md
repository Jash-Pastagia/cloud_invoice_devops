# Cloud Invoice DevOps - Complete CI/CD Pipeline

A cloud-native microservices-based invoice management system with complete DevOps automation, deployed on AWS EKS with Kafka messaging and PostgreSQL database.

## 🏗️ Architecture Overview

### Microservices
- **auth-service**: User authentication and JWT token management
- **invoice-service**: Invoice creation, listing, and management
- **payment-service**: Payment processing and status updates
- **notification-service**: Event-driven notifications via Kafka
- **analytics-service**: Metrics and analytics aggregation
- **frontend**: React-based user interface with Nginx proxy

### Infrastructure
- **Kubernetes (EKS)**: Orchestration platform for microservices
- **Kafka (MSK)**: Message broker for event streaming
- **PostgreSQL (RDS)**: Relational database for persistent storage
- **AWS VPC**: Network isolation with public/private subnets
- **Application Load Balancer**: Ingress traffic management

## 🚀 Features

### DevOps Capabilities
- ✅ **Continuous Integration (CI)**: Automated build, test, and security scanning
- ✅ **Continuous Deployment (CD)**: Multi-environment deployment automation
- ✅ **Infrastructure as Code**: Terraform for AWS resource provisioning
- ✅ **DevSecOps Pipeline**: Comprehensive security scanning at every stage
- ✅ **Container Security**: Image scanning with Trivy and Grype
- ✅ **Secret Management**: AWS Secrets Manager integration
- ✅ **Monitoring**: CloudWatch logs and metrics

### Security Features
- 🔒 Code quality scanning (ESLint)
- 🔒 Secret detection (TruffleHog, Gitleaks)
- 🔒 Dependency vulnerability scanning (npm audit, Snyk)
- 🔒 SAST analysis (CodeQL)
- 🔒 Container scanning (Trivy, Grype)
- 🔒 Dockerfile linting (Hadolint)
- 🔒 License compliance checking
- 🔒 Terraform security (TFSec, Checkov)
- 🔒 Kubernetes manifest scanning (Kubesec, Datree)

## 📁 Project Structure

```
cloud_invoice_devops/
├── .github/workflows/
│   ├── ci.yml              # Build, test, and package services
│   ├── devsecops.yml       # Security scanning pipeline
│   ├── terraform.yml       # Infrastructure deployment
│   └── cd.yml              # Continuous deployment
├── terraform/
│   ├── main.tf             # Main infrastructure orchestration
│   ├── variables.tf        # Configurable parameters
│   ├── outputs.tf          # Infrastructure outputs
│   └── modules/
│       ├── vpc/            # VPC networking
│       ├── eks/            # EKS cluster (to be created)
│       ├── rds/            # PostgreSQL database (to be created)
│       ├── msk/            # Kafka cluster (to be created)
│       ├── iam/            # IAM roles and policies (to be created)
│       └── security/       # Security groups (to be created)
├── k8s/
│   ├── auth-deployment.yaml
│   ├── invoice-deployment.yaml
│   ├── payment-deployment.yaml
│   ├── notification-deployment.yaml
│   ├── analytics-deployment.yaml
│   ├── frontend-deployment.yaml
│   ├── services.yaml
│   ├── ingress.yaml
│   └── secret.yaml
├── lib/
│   └── kafka.js            # Shared Kafka client library
├── auth-service/
├── invoice-service/
├── payment-service/
├── notification-service/
├── analytics-service/
└── frontend/
```

## 🛠️ Technology Stack

### Application Layer
- **Runtime**: Node.js 24
- **Framework**: Express.js
- **Frontend**: React 18
- **Authentication**: JWT (jsonwebtoken)
- **Database Client**: pg (PostgreSQL client)
- **Messaging**: kafkajs v2.x

### Infrastructure Layer
- **Cloud Provider**: AWS
- **Container Orchestration**: Kubernetes (EKS 1.28)
- **Message Broker**: Apache Kafka (MSK 3.5.1)
- **Database**: PostgreSQL 16.1 (RDS)
- **Infrastructure as Code**: Terraform >= 1.5.0
- **Container Registry**: Docker Hub / GitHub Container Registry

### DevOps Tools
- **CI/CD**: GitHub Actions
- **Security Scanning**: Trivy, Grype, Snyk, CodeQL
- **Code Quality**: ESLint, Hadolint
- **Infrastructure Scanning**: TFSec, Checkov
- **K8s Scanning**: Kubesec, Datree
- **Secret Detection**: TruffleHog, Gitleaks

## 🔧 Setup Instructions

### Prerequisites
- AWS Account with appropriate permissions
- GitHub repository with Actions enabled
- Docker installed locally
- kubectl and aws-cli configured
- Terraform >= 1.5.0 installed
- Node.js 24 installed

### Local Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/cloud_invoice_devops.git
   cd cloud_invoice_devops
   ```

2. **Install dependencies for each service**
   ```bash
   for service in auth-service invoice-service payment-service notification-service analytics-service; do
     cd $service
     npm install
     cd ..
   done
   ```

3. **Start local Kafka and PostgreSQL**
   ```bash
   docker-compose up -d
   ```

4. **Run services locally**
   ```bash
   # Terminal 1 - Auth Service
   cd auth-service && JWT_SECRET=supersecretdevops npm start
   
   # Terminal 2 - Invoice Service
   cd invoice-service && JWT_SECRET=supersecretdevops npm start
   
   # Terminal 3 - Payment Service
   cd payment-service && JWT_SECRET=supersecretdevops npm start
   
   # Terminal 4 - Notification Service
   cd notification-service && npm start
   
   # Terminal 5 - Analytics Service
   cd analytics-service && npm start
   
   # Terminal 6 - Frontend
   cd frontend && npm start
   ```

### Kubernetes Deployment (Local - kind)

1. **Create kind cluster**
   ```bash
   kind create cluster --name innovative-ci
   ```

2. **Deploy Docker services**
   ```bash
   docker-compose up -d
   ```

3. **Apply Kubernetes manifests**
   ```bash
   kubectl create namespace innovative-ci
   kubectl apply -f k8s/secret.yaml -n innovative-ci
   kubectl apply -f k8s/ -n innovative-ci
   ```

4. **Verify deployment**
   ```bash
   kubectl get pods -n innovative-ci
   kubectl get services -n innovative-ci
   ```

5. **Port forward to access services**
   ```bash
   kubectl port-forward svc/frontend 3000:80 -n innovative-ci
   ```

### AWS Deployment (Production)

#### Step 1: Configure AWS Credentials

**Option A: OIDC (Recommended)**
1. Create an IAM OIDC identity provider for GitHub
2. Create an IAM role with trust policy for GitHub Actions
3. Add role ARN to GitHub secrets as `AWS_ROLE_ARN`

**Option B: Access Keys**
1. Create IAM user with programmatic access
2. Add access keys to GitHub secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

#### Step 2: Configure GitHub Secrets

Required secrets:
```
AWS_ROLE_ARN          # IAM role for OIDC authentication
JWT_SECRET            # JWT signing secret (e.g., supersecretdevops)
DB_PASSWORD           # PostgreSQL password
DOCKERHUB_USERNAME    # Docker Hub username (optional)
DOCKERHUB_TOKEN       # Docker Hub token (optional)
PUSH_IMAGES           # Set to "true" to enable image pushes
```

#### Step 3: Deploy Infrastructure with Terraform

1. **Initialize Terraform**
   ```bash
   cd terraform
   terraform init
   ```

2. **Plan infrastructure changes**
   ```bash
   terraform plan -out=tfplan
   ```

3. **Apply infrastructure**
   ```bash
   terraform apply tfplan
   ```

4. **Get outputs**
   ```bash
   terraform output
   ```

Alternatively, use GitHub Actions:
- **Plan**: Open PR with Terraform changes
- **Apply**: Merge to main branch
- **Destroy**: Manual workflow dispatch with "destroy" action

#### Step 4: Deploy Applications

1. **Update kubeconfig**
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name cloud-invoice-dev
   ```

2. **Deploy via GitHub Actions**
   - **Dev Environment**: Automatic on merge to main
   - **Staging Environment**: Automatic on release tag
   - **Production Environment**: Manual approval required

3. **Manual deployment**
   ```bash
   kubectl apply -f k8s/ -n innovative-ci
   ```

## 🔄 CI/CD Workflows

### 1. Continuous Integration (ci.yml)

**Triggers**: Push/PR to main, develop, feat/*

**Jobs**:
- Build and test all 6 services in matrix
- Cache Node modules and Docker layers
- Run tests with coverage
- Security scan with Trivy
- Build multi-platform Docker images (amd64, arm64)
- Conditionally push to registry (if PUSH_IMAGES=true)
- Upload artifacts (images + metadata)

**Matrix Strategy**:
```yaml
service: [auth-service, invoice-service, payment-service, 
          notification-service, analytics-service, frontend]
```

### 2. DevSecOps Pipeline (devsecops.yml)

**Triggers**: Push/PR to main, daily schedule

**Security Scans**:
- **Code Quality**: ESLint, console.log detection
- **Secret Scanning**: TruffleHog, Gitleaks
- **Dependency Scanning**: npm audit, Snyk
- **SAST**: CodeQL JavaScript analysis
- **Container Scanning**: Trivy, Grype
- **Dockerfile Linting**: Hadolint
- **License Compliance**: license-checker
- **Infrastructure Security**: TFSec, Checkov
- **K8s Security**: Kubesec, Datree
- **Security Summary**: Consolidated dashboard

**SARIF Uploads**: Results uploaded to GitHub Security tab

### 3. Terraform Infrastructure (terraform.yml)

**Triggers**: 
- PR: terraform plan
- Merge to main: terraform apply
- Workflow dispatch: plan/apply/destroy

**Jobs**:
- **Validation**: terraform fmt, validate
- **Plan**: Generate execution plan, comment on PR
- **Apply**: Deploy infrastructure with approval
- **Destroy**: Remove infrastructure (manual only)

### 4. Continuous Deployment (cd.yml)

**Triggers**: 
- Merge to main: Deploy to dev
- Release tag: Deploy to staging
- Workflow dispatch: Manual deployment

**Jobs**:
- **Infrastructure Services**: Deploy PostgreSQL, Kafka (if not using AWS)
- **Application Services**: Deploy all 6 microservices
- **Health Check**: Verify pod health and API endpoints
- **Rollback**: Automatic rollback on failure

**Environments**:
- **dev**: No approval required
- **staging**: Optional approval
- **production**: Manual approval required

## 📊 Monitoring and Observability

### CloudWatch Logs
```bash
# View EKS cluster logs
aws logs tail /aws/eks/cloud-invoice-dev/cluster --follow

# View service logs
kubectl logs -f deployment/auth -n innovative-ci
kubectl logs -f deployment/invoice -n innovative-ci
kubectl logs -f deployment/payment -n innovative-ci
```

### Pod Health
```bash
# Check pod status
kubectl get pods -n innovative-ci

# Describe pod for events
kubectl describe pod <pod-name> -n innovative-ci

# Check resource usage
kubectl top pods -n innovative-ci
```

### Kafka Monitoring
```bash
# List topics
kubectl exec -it deployment/kafka -n innovative-ci -- kafka-topics --list --bootstrap-server localhost:9092

# Check consumer groups
kubectl exec -it deployment/kafka -n innovative-ci -- kafka-consumer-groups --list --bootstrap-server localhost:9092

# Describe consumer group
kubectl exec -it deployment/kafka -n innovative-ci -- kafka-consumer-groups --describe --group notification-service --bootstrap-server localhost:9092
```

### Database Monitoring
```bash
# Connect to PostgreSQL
kubectl exec -it deployment/postgres -n innovative-ci -- psql -U postgres

# Check connections
SELECT * FROM pg_stat_activity;

# Check database size
SELECT pg_size_pretty(pg_database_size('cloud_invoice'));
```

## 🧪 Testing

### API Testing
```bash
# Login
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# Create invoice
curl -X POST http://localhost:3000/api/invoice/invoices \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"clientName":"John Doe","items":[{"desc":"Consulting","qty":10,"rate":100}]}'

# List invoices
curl http://localhost:3000/api/invoice/invoices \
  -H "Authorization: Bearer <token>"

# Process payment
curl -X POST http://localhost:3000/api/payment/pay \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"invoiceId":"<invoice-id>","amount":1000,"paymentMethod":"credit_card"}'
```

### Integration Testing
```bash
# Run integration tests
npm run test:integration

# Run E2E tests
npm run test:e2e
```

## 🔒 Security Best Practices

1. **Never commit secrets** - Use AWS Secrets Manager or GitHub Secrets
2. **Use OIDC over access keys** - More secure and no credential rotation needed
3. **Enable VPC Flow Logs** - Monitor network traffic
4. **Use private subnets** - Keep services internal, expose via ALB
5. **Regular security scans** - Daily DevSecOps pipeline execution
6. **Principle of least privilege** - IAM roles with minimal permissions
7. **Enable encryption** - RDS, MSK, and S3 encryption at rest
8. **Use secrets rotation** - Automate credential rotation
9. **Network policies** - Implement K8s network policies
10. **Image signing** - Sign container images with Cosign

## 🐛 Troubleshooting

### Common Issues

**1. Pods in CrashLoopBackOff**
```bash
# Check logs
kubectl logs <pod-name> -n innovative-ci

# Common causes:
# - Database connection failure (check DB_HOST, DB_PASSWORD)
# - Kafka connection failure (check KAFKA_BROKERS)
# - Missing secrets (check JWT_SECRET)
```

**2. Services not accessible**
```bash
# Check service endpoints
kubectl get endpoints -n innovative-ci

# Check ingress
kubectl get ingress -n innovative-ci
kubectl describe ingress -n innovative-ci

# Port forward for testing
kubectl port-forward svc/<service-name> <local-port>:<service-port> -n innovative-ci
```

**3. Kafka connection timeout**
```bash
# Verify Kafka is running
kubectl get pods -l app=kafka -n innovative-ci

# Check Kafka logs
kubectl logs -l app=kafka -n innovative-ci

# Test connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- telnet kafka 9092
```

**4. Database migration issues**
```bash
# Connect to database
kubectl exec -it deployment/postgres -n innovative-ci -- psql -U postgres

# Check if tables exist
\dt

# Manually create tables if needed
CREATE TABLE IF NOT EXISTS users (...);
CREATE TABLE IF NOT EXISTS invoices (...);
```

**5. Terraform state lock**
```bash
# Force unlock (use with caution)
terraform force-unlock <lock-id>

# Alternative: Delete DynamoDB lock item manually
```

## 📈 Scaling

### Horizontal Pod Autoscaling
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: invoice-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: invoice
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### EKS Node Group Scaling
```bash
# Update desired capacity
aws eks update-nodegroup-config \
  --cluster-name cloud-invoice-dev \
  --nodegroup-name node-group-1 \
  --scaling-config minSize=1,maxSize=10,desiredSize=3
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feat/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feat/amazing-feature`)
5. Open Pull Request

## 📝 License

This project is licensed under the MIT License - see LICENSE file for details.

## 👥 Authors

- Megh Shah - DevOps Implementation

## 🙏 Acknowledgments

- Express.js community
- KafkaJS maintainers
- Terraform AWS provider contributors
- GitHub Actions community

## 📞 Support

For issues and questions:
- Open a GitHub issue
- Contact: [your-email@example.com]
- Documentation: [Wiki](https://github.com/yourusername/cloud_invoice_devops/wiki)

---

**Status**: ✅ CI/CD Complete | 🚧 Cloud Deployment In Progress

**Last Updated**: January 2025
