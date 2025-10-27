# Cloud Invoice DevOps - Event-Driven Microservices System

> **A production-ready, cloud-native invoice management system with event-driven architecture, real-time analytics, and comprehensive DevOps automation.**

[![CI/CD Pipeline](https://img.shields.io/badge/CI%2FCD-Automated-success)](/.github/workflows)
[![Docker](https://img.shields.io/badge/Docker-Containerized-blue)](https://www.docker.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-Orchestrated-326CE5)](https://kubernetes.io/)
[![Apache Kafka](https://img.shields.io/badge/Apache%20Kafka-Event%20Streaming-231F20)](https://kafka.apache.org/)

## 📋 Table of Contents

- [🎯 Project Overview](#-project-overview)
- [✨ Key Features](#-key-features)
- [🏗️ System Architecture](#️-system-architecture)
- [🚀 Quick Start](#-quick-start)
- [📦 Prerequisites](#-prerequisites)
- [⚙️ Complete Setup Guide](#️-complete-setup-guide)
- [🔍 Accessing Components](#-accessing-components)
- [🧪 Testing & Validation](#-testing--validation)
- [🗂️ Project Structure](#️-project-structure)
- [🔄 CI/CD Pipeline](#-cicd-pipeline)
- [📊 Monitoring & Analytics](#-monitoring--analytics)
- [🛠️ Development Guide](#️-development-guide)
- [❓ Troubleshooting](#-troubleshooting)
- [🤝 Contributing](#-contributing)

---

## 🎯 Project Overview

This project showcases a **production-grade microservices architecture** implementing an invoice management system with:

- **6 Microservices**: Authentication, Invoice Management, Payment Processing, Notifications, Analytics, and Frontend
- **Event-Driven Architecture**: Apache Kafka for asynchronous event streaming
- **Hybrid Infrastructure**: Docker Compose for infrastructure + Kubernetes for applications
- **Real-Time Analytics**: Event aggregation and metrics dashboard
- **Notification System**: Real-time event notifications via Kafka consumers
- **Full CI/CD Pipeline**: Automated testing, building, and deployment

### Core Services

| Service | Port | Purpose | Technology |
|---------|------|---------|------------|
| **Auth Service** | 4000 | User authentication & JWT tokens | Node.js + PostgreSQL |
| **Invoice Service** | 5050 | Invoice CRUD operations | Node.js + PostgreSQL + Kafka |
| **Payment Service** | 6060 | Payment processing | Node.js + Kafka |
| **Analytics Service** | 7100 | Real-time metrics & event aggregation | Node.js + PostgreSQL + Kafka |
| **Notification Service** | 7200 | Event notifications & alerts | Node.js + PostgreSQL + Kafka |
| **Frontend** | 80 | React SPA with Nginx reverse proxy | React + Nginx |

### Infrastructure Components

| Component | Port | Purpose |
|-----------|------|---------|
| **PostgreSQL** | 5432 | Primary database for all services |
| **Apache Kafka** | 9092 | Event streaming platform |
| **Zookeeper** | 2181 | Kafka coordination service |
| **Kafka UI** | 8080 | Web interface for Kafka management |

---

## ✨ Key Features

### 🔐 Authentication & Authorization
- JWT-based authentication
- User registration and login
- Secure password hashing
- Token-based API access control

### 📄 Invoice Management
- Create, read, update invoices
- Assign invoices to users
- Track invoice status (pending, paid)
- Due date management
- Item-level details with quantities and pricing

### 💳 Payment Processing
- Process payments for invoices
- Automatic status updates
- Payment history tracking
- Event publishing to Kafka

### 📊 Real-Time Analytics
- Dashboard with key metrics:
  - Invoices created (last 24h)
  - Invoices paid (last 24h)
  - Payments processed (last 24h)
  - Events by type (last hour)
- Event history and aggregation
- Real-time data updates

### 🔔 Notification System
- Real-time event notifications
- Kafka event consumption
- Notification persistence
- Auto-refresh every 10 seconds

### 🎨 Modern Frontend
- React-based SPA
- Responsive design
- Real-time updates
- Analytics dashboard
- Notification center

### 🔄 Event-Driven Architecture
- Kafka topics for event streaming:
  - `invoice.created`
  - `invoice.paid`
  - `payment.initiated`
  - `payment.processed`
- Multiple consumer groups
- Event persistence and replay capability

### 🚀 DevOps & CI/CD
- Automated Docker image building
- Kubernetes deployment automation
- GitHub Actions CI/CD pipeline
- Security scanning with Trivy
- SBOM generation
- Automated testing

---

## 🏗️ System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Frontend (React + Nginx)             │
│                    http://localhost:3000                     │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTP/REST
        ┌──────────────────┼──────────────────┐
        │                  │                  │
┌───────▼────────┐ ┌──────▼───────┐ ┌───────▼────────┐
│  Auth Service  │ │Invoice Service│ │Payment Service │
│    :4000       │ │     :5050     │ │     :6060      │
└───────┬────────┘ └──────┬────────┘ └───────┬────────┘
        │                 │ Publishes         │ Publishes
        │                 │ Events            │ Events
        │          ┌──────▼───────────────────▼─────┐
        │          │      Apache Kafka :9092         │
        │          │  (Event Streaming Platform)     │
        │          └──────┬───────────────────┬──────┘
        │                 │ Consumes          │ Consumes
        │                 │ Events            │ Events
        │          ┌──────▼────────┐   ┌─────▼─────────┐
        │          │   Analytics   │   │ Notification  │
        │          │   Service     │   │   Service     │
        │          │    :7100      │   │    :7200      │
        │          └──────┬────────┘   └─────┬─────────┘
        │                 │                  │
        └─────────────────┼──────────────────┘
                          │
                   ┌──────▼────────┐
                   │  PostgreSQL   │
                   │     :5432     │
                   └───────────────┘
```

### Deployment Architecture (Hybrid Model)

```
┌─────────────────────────────────────────────────────────────┐
│                    DOCKER COMPOSE                           │
│                  (Infrastructure Layer)                      │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐      │
│  │  PostgreSQL  │  │Apache Kafka  │  │ Zookeeper   │      │
│  │    :5432     │  │    :9092     │  │   :2181     │      │
│  └──────────────┘  └──────────────┘  └─────────────┘      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                          ▲
                          │ host.docker.internal
                          │
┌─────────────────────────┼───────────────────────────────────┐
│                KUBERNETES (kind cluster)                     │
│                 (Application Layer)                          │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Auth Service │  │Invoice Service│  │Payment Service│     │
│  │  Pod + Svc   │  │  Pod + Svc    │  │  Pod + Svc   │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Analytics    │  │Notification   │  │  Frontend    │     │
│  │  Pod + Svc   │  │  Pod + Svc    │  │  Pod + Svc   │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Event Flow

```
User Action → Invoice Service → Kafka Topic → [Analytics, Notification]
                                                     ↓              ↓
                                                PostgreSQL    PostgreSQL
                                                (metrics)   (notifications)
```

---

## 🚀 Quick Start

Get the system running in **5 minutes**:

```bash
# 1. Clone the repository
git clone https://github.com/Jash-Pastagia/cloud_invoice_devops.git
cd cloud_invoice_devops

# 2. Setup infrastructure (Docker, Kubernetes, PostgreSQL, Kafka)
./setup-infrastructure.sh

# 3. Access the application
kubectl port-forward -n innovative-ci svc/frontend 3000:80 &

# 4. Open in browser
open http://localhost:3000
```

**Login credentials:**
- Username: `demo`
- Password: `demo123`

---

## 📦 Prerequisites

### Required Software

| Software | Version | Installation | Purpose |
|----------|---------|--------------|---------|
| **Docker Desktop** | 20.10+ | [Download](https://www.docker.com/products/docker-desktop) | Container runtime |
| **kubectl** | 1.28+ | Included with Docker Desktop | Kubernetes CLI |
| **kind** | 0.20+ | `brew install kind` (Mac) or [Install Guide](https://kind.sigs.k8s.io/docs/user/quick-start/) | Local Kubernetes cluster |
| **Git** | 2.0+ | [Download](https://git-scm.com/) | Version control |
| **Node.js** | 18+ | [Download](https://nodejs.org/) | For local development (optional) |

### System Requirements

- **OS**: macOS, Linux, or Windows with WSL2
- **RAM**: Minimum 8GB (16GB recommended)
- **CPU**: 4+ cores recommended
- **Disk**: 20GB free space
- **Network**: Internet connection for downloading images

### Verify Installation

```bash
# Check Docker
docker --version
docker ps

# Check kubectl (comes with Docker Desktop)
kubectl version --client

# Check kind
kind version

# Check Git
git --version
```

---

## 🧪 Testing & Validation

### Run End-to-End Tests

```bash
# Frontend E2E test (comprehensive)
chmod +x test-frontend-e2e.sh
./test-frontend-e2e.sh
```

**Test Coverage:**
- ✅ Port availability check
- ✅ Frontend accessibility
- ✅ Authentication endpoints
- ✅ Invoice management APIs
- ✅ Analytics service APIs
- ✅ Notification service APIs
- ✅ Response validation

**Expected Output:**
```
🧪 Frontend E2E Testing Script
==============================

✅ Port 3000 is available
✅ Frontend is accessible
✅ Authentication endpoints work
✅ Invoice endpoints work
✅ Analytics endpoints work
✅ Notifications endpoints work

✅ All tests passed! Frontend is working correctly.
```

### Manual API Testing

**Authentication:**
```bash
# Register a new user
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "test123",
    "fullName": "Test User",
    "email": "test@example.com"
  }'

# Login
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "test123"
  }'

# Save the token from login response
TOKEN="<your_jwt_token>"
```

**Invoice Management:**
```bash
# Create invoice
curl -X POST http://localhost:3000/api/invoice/invoices \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "customer": {
      "name": "ACME Corp",
      "email": "billing@acme.com"
    },
    "items": [
      {
        "description": "Consulting Services",
        "quantity": 10,
        "price": 150.00
      }
    ],
    "dueDate": "2024-12-31"
  }'

# List invoices
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:3000/api/invoice/invoices

# Get specific invoice
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:3000/api/invoice/invoices/{invoice_id}
```

**Payment Processing:**
```bash
# Create payment
curl -X POST http://localhost:3000/api/payment/payments \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "invoiceId": "<invoice_id>",
    "amount": 1500.00,
    "method": "credit_card",
    "metadata": {
      "cardLast4": "4242"
    }
  }'
```

**Analytics & Notifications:**
```bash
# Get analytics metrics
curl http://localhost:3000/api/analytics/metrics

# Get event statistics
curl http://localhost:3000/api/analytics/events/stats

# Get notifications
curl http://localhost:3000/api/notification/notifications

# Get notification counts
curl http://localhost:3000/api/notification/notifications/count
```

### Verify Kafka Message Flow

```bash
# 1. Create an invoice (generates invoice.created event)
curl -X POST http://localhost:3000/api/invoice/invoices \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"customer":{"name":"Test"},"items":[{"description":"Item","quantity":1,"price":100}]}'

# 2. Check Kafka UI for new messages
open http://localhost:8080

# 3. Verify in analytics database
docker exec -it cloud-invoice-devops-postgres-1 psql -U invoice_user -d invoicedb
SELECT * FROM analytics_events ORDER BY received_at DESC LIMIT 5;

# 4. Verify in notifications database
SELECT * FROM notifications ORDER BY received_at DESC LIMIT 5;
```

### Check System Health

```bash
# Kubernetes pods
kubectl get pods -n innovative-ci

# Docker containers
docker ps

# Service logs
kubectl logs -n innovative-ci deployment/analytics-service --tail=50
kubectl logs -n innovative-ci deployment/notification-service --tail=50

# Database connection
docker exec cloud-invoice-devops-postgres-1 pg_isready -U invoice_user

# Kafka topics
docker exec cloud-invoice-devops-kafka-1 \
  kafka-topics --list --bootstrap-server localhost:9092
```

---

## 📁 Project Structure

```
cloud_invoice_devops/
├── .github/
│   └── workflows/
│       └── cd.yml                    # GitHub Actions CD pipeline
│
├── auth-service/
│   ├── index.js                      # Express server with JWT auth
│   ├── package.json                  # Dependencies (express, pg, bcrypt, jsonwebtoken)
│   └── Dockerfile                    # Node.js 18 Alpine
│
├── invoice-service/
│   ├── index.js                      # Invoice CRUD + Kafka producer
│   ├── db.json                       # Initial data (if needed)
│   ├── package.json                  # Dependencies (express, pg, kafkajs)
│   └── Dockerfile                    # Node.js 18 Alpine
│
├── payment-service/
│   ├── index.js                      # Payment processing + Kafka producer
│   ├── package.json                  # Dependencies (express, kafkajs)
│   └── Dockerfile                    # Node.js 18 Alpine
│
├── analytics-service/
│   ├── index.js                      # Kafka consumer + PostgreSQL writer
│   ├── package.json                  # Dependencies (express, pg, kafkajs)
│   └── Dockerfile                    # Node.js 18 Alpine
│
├── notification-service/
│   ├── index.js                      # Kafka consumer + notification storage
│   ├── package.json                  # Dependencies (express, pg, kafkajs)
│   └── Dockerfile                    # Node.js 18 Alpine
│
├── frontend/
│   ├── src/
│   │   ├── App.jsx                   # Main React app
│   │   ├── components/               # React components
│   │   ├── api/
│   │   │   └── api.k8s.js           # API client (uses relative paths)
│   │   └── ...
│   ├── nginx.conf                    # Reverse proxy configuration
│   ├── package.json                  # React + Vite dependencies
│   └── Dockerfile                    # Multi-stage (build + nginx)
│
├── k8s/
│   ├── auth-deployment.yaml          # Auth service deployment (1 replica)
│   ├── invoice-deployment.yaml       # Invoice service deployment (1 replica)
│   ├── payment-deployment.yaml       # Payment service deployment (1 replica)
│   ├── analytics-deployment.yaml     # Analytics service deployment (1 replica)
│   ├── notification-deployment.yaml  # Notification service deployment (1 replica)
│   ├── frontend-deployment.yaml      # Frontend deployment (1 replica)
│   ├── services.yaml                 # All ClusterIP services
│   ├── secret.yaml                   # Database & Kafka credentials
│   └── ingress.yaml                  # Ingress configuration (optional)
│
├── docker-compose.yml                # Infrastructure: PostgreSQL, Kafka, Zookeeper
├── setup-infrastructure.sh           # Automated setup script
├── build-all.sh                      # Build all Docker images
├── validation.sh                     # Validation script
├── e2e-test.sh                       # End-to-end deployment test
├── test-frontend-e2e.sh             # Frontend testing script
├── README.md                         # This file
└── DEPLOYMENT_GUIDE.md               # Detailed deployment guide
```

---

## 🔄 CI/CD Pipeline

### GitHub Actions Workflow

**File:** `.github/workflows/cd.yml`

**Trigger:** Push to `main` branch

**Pipeline Stages:**

1. **Build Stage**
   - Checkout code
   - Login to Docker Hub
   - Build all 6 service images
   - Tag with commit SHA and `latest`
   - Push to Docker Hub

2. **Deploy Stage**
   - Setup kubectl
   - Configure Kubernetes context
   - Apply secrets and configurations
   - Deploy all services
   - Wait for rollout completion

3. **Test Stage**
   - Run health checks on all services
   - Test API endpoints
   - Verify Kafka connectivity
   - Validate database connections

**Environment Variables Required:**
```yaml
DOCKER_USERNAME: <your-docker-hub-username>
DOCKER_PASSWORD: <your-docker-hub-token>
KUBE_CONFIG: <base64-encoded-kubeconfig>
```

**Setup Instructions:**

1. Fork the repository
2. Add secrets in GitHub Settings → Secrets and variables → Actions:
   - `DOCKER_USERNAME`: Your Docker Hub username
   - `DOCKER_PASSWORD`: Your Docker Hub access token
   - `KUBE_CONFIG`: Base64-encoded kubeconfig file

3. Push to `main` branch to trigger deployment

**Manual Trigger:**
```bash
# Via GitHub UI: Actions → CD Pipeline → Run workflow

# Or push a tag
git tag v1.0.0
git push origin v1.0.0
```

---

## 📈 Monitoring & Analytics

### Analytics Dashboard

The analytics service tracks all system events in real-time:

**Metrics Available:**
- Total invoices created
- Total invoices paid
- Total payments processed
- Payment success rate
- Invoice aging analysis
- Revenue trends

**Access:**
```bash
# Get current metrics
curl http://localhost:3000/api/analytics/metrics

# Get event statistics
curl http://localhost:3000/api/analytics/events/stats

# Response example:
{
  "totalInvoices": 45,
  "paidInvoices": 32,
  "pendingInvoices": 13,
  "totalRevenue": 125400.50,
  "avgInvoiceAmount": 2786.68,
  "last24hInvoices": 8
}
```

### Notification Center

All system events generate notifications:

**Notification Types:**
- Invoice created
- Invoice paid
- Payment initiated
- Payment processed
- Payment failed

**Access:**
```bash
# Get all notifications
curl http://localhost:3000/api/notification/notifications

# Get notification count
curl http://localhost:3000/api/notification/notifications/count

# Frontend: Check notifications icon (bell icon in header)
```

### Kafka Monitoring

**Kafka UI Dashboard:**
- URL: http://localhost:8080
- Monitor topics, consumers, messages
- View consumer lag
- Browse message contents

**CLI Monitoring:**
```bash
# Consumer group lag
docker exec cloud-invoice-devops-kafka-1 \
  kafka-consumer-groups --describe \
  --group analytics-service-group-v2 \
  --bootstrap-server localhost:9092

# Topic message count
docker exec cloud-invoice-devops-kafka-1 \
  kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 \
  --topic invoice.created
```

---

## 🛠️ Development Guide

### Local Development Setup

**Run services locally without Kubernetes:**

1. **Start infrastructure:**
```bash
docker-compose up -d
```

2. **Run individual service:**
```bash
cd auth-service
npm install
PORT=4000 \
DB_HOST=localhost \
DB_PORT=5432 \
DB_NAME=invoicedb \
DB_USER=invoice_user \
DB_PASSWORD=invoice_password \
JWT_SECRET=dev-secret \
node index.js
```

3. **Run frontend locally:**
```bash
cd frontend
npm install
npm run dev  # Runs on http://localhost:5173
```

### Environment Variables

Each service uses these environment variables:

**All Services:**
- `NODE_ENV`: `production` or `development`
- `PORT`: Service port number
- `DB_HOST`: PostgreSQL host
- `DB_PORT`: PostgreSQL port (5432)
- `DB_NAME`: Database name (invoicedb)
- `DB_USER`: Database user
- `DB_PASSWORD`: Database password

**Kafka-enabled Services (invoice, payment, analytics, notification):**
- `KAFKA_BROKERS`: Kafka broker URL (host.docker.internal:9092)
- `KAFKA_CLIENT_ID`: Unique client ID
- `KAFKA_GROUP_ID`: Consumer group ID (for consumers)

**Auth Service Only:**
- `JWT_SECRET`: Secret key for JWT signing

### Code Changes & Hot Reload

**For Kubernetes deployment:**
```bash
# 1. Make code changes
# 2. Rebuild specific service
docker build -t <service-name>:latest ./<service-name>

# 3. Load into kind cluster
kind load docker-image <service-name>:latest --name innovative-ci

# 4. Restart deployment
kubectl rollout restart deployment/<service-name> -n innovative-ci

# 5. Watch rollout
kubectl rollout status deployment/<service-name> -n innovative-ci
```

**For local development:**
- Use `nodemon` for auto-reload
- Install: `npm install -g nodemon`
- Run: `nodemon index.js`

### Database Migrations

**Add new tables:**
```bash
# 1. Connect to database
docker exec -it cloud-invoice-devops-postgres-1 psql -U invoice_user -d invoicedb

# 2. Create table
CREATE TABLE your_table (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- your columns
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

# 3. Update service code to use new table
```

**Backup database:**
```bash
docker exec cloud-invoice-devops-postgres-1 pg_dump -U invoice_user invoicedb > backup.sql
```

**Restore database:**
```bash
docker exec -i cloud-invoice-devops-postgres-1 psql -U invoice_user -d invoicedb < backup.sql
```

---

## 🐛 Troubleshooting

### Common Issues

#### 1. Frontend shows 503 errors

**Symptom:** Analytics/notifications not loading, browser shows "Service Unavailable"

**Solution:**
```bash
# Check port-forward is running on correct port
kubectl port-forward -n innovative-ci svc/frontend 3000:80

# Verify in browser: http://localhost:3000 (not 3001!)

# Check if port is in use
lsof -i :3000

# Kill any process using port 3000
kill -9 <PID>
```

#### 2. Pods not starting

**Symptom:** `kubectl get pods` shows pods in `Pending` or `CrashLoopBackOff`

**Solution:**
```bash
# Check pod logs
kubectl logs -n innovative-ci <pod-name>

# Describe pod for events
kubectl describe pod -n innovative-ci <pod-name>

# Common fixes:
# - Image not loaded: kind load docker-image <image>:latest --name innovative-ci
# - Resource limits: Check if enough RAM/CPU available
# - Secret missing: kubectl apply -f k8s/secret.yaml
```

#### 3. Database connection errors

**Symptom:** Services log "Error connecting to database"

**Solution:**
```bash
# Verify PostgreSQL is running
docker ps | grep postgres

# Check database is accessible
docker exec cloud-invoice-devops-postgres-1 pg_isready -U invoice_user

# Verify database exists
docker exec -it cloud-invoice-devops-postgres-1 psql -U invoice_user -l

# Check connection from pod
kubectl exec -n innovative-ci deployment/auth-service -- \
  wget -O- --post-data="" http://host.docker.internal:5432
```

#### 4. Kafka connection errors

**Symptom:** Analytics/notification services can't connect to Kafka

**Solution:**
```bash
# Verify Kafka is running
docker ps | grep kafka

# Check Kafka logs
docker logs cloud-invoice-devops-kafka-1 --tail=50

# Test Kafka connectivity
docker exec cloud-invoice-devops-kafka-1 \
  kafka-broker-api-versions --bootstrap-server localhost:9092

# Restart Kafka if needed
docker-compose restart kafka
```

#### 5. Authentication not working

**Symptom:** Login/register returns 500 error

**Solution:**
```bash
# Check auth-service logs
kubectl logs -n innovative-ci deployment/auth-service

# Verify JWT secret is set
kubectl get secret app-secrets -n innovative-ci -o jsonpath='{.data.JWT_SECRET}' | base64 --decode

# Test auth endpoint directly
kubectl exec -n innovative-ci deployment/auth-service -- \
  wget -O- http://localhost:4000/health
```

#### 6. Images not updating

**Symptom:** Code changes not reflected after rebuild

**Solution:**
```bash
# 1. Delete old image from kind
docker exec innovative-ci-control-plane crictl rmi <image>:latest

# 2. Rebuild image
docker build -t <service>:latest ./<service>

# 3. Load into kind
kind load docker-image <service>:latest --name innovative-ci

# 4. Force pod restart
kubectl delete pod -n innovative-ci -l app=<service>

# 5. Verify new pod is running
kubectl get pods -n innovative-ci -w
```

### Debugging Commands

```bash
# View all resources at once
kubectl get all -n innovative-ci

# Check node resources
kubectl top nodes

# Check pod resource usage
kubectl top pods -n innovative-ci

# Get detailed pod information
kubectl describe pod -n innovative-ci <pod-name>

# Check events
kubectl get events -n innovative-ci --sort-by='.lastTimestamp'

# Check service endpoints
kubectl get endpoints -n innovative-ci

# Test service DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup auth-service.innovative-ci.svc.cluster.local
```

### Reset Everything

**If all else fails, complete reset:**

```bash
# 1. Delete kind cluster
kind delete cluster --name innovative-ci

# 2. Stop Docker Compose
docker-compose down -v

# 3. Clean up Docker
docker system prune -af
docker volume prune -f

# 4. Re-run setup
./setup-infrastructure.sh
```

---

## 📝 Additional Resources

- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Detailed deployment documentation
- **Kafka Documentation:** [https://kafka.apache.org/documentation/](https://kafka.apache.org/documentation/)
- **Kubernetes Documentation:** [https://kubernetes.io/docs/](https://kubernetes.io/docs/)
- **kind Documentation:** [https://kind.sigs.k8s.io/](https://kind.sigs.k8s.io/)

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit changes: `git commit -am 'Add new feature'`
4. Push to branch: `git push origin feature/your-feature`
5. Submit a Pull Request

### Development Workflow

1. Make changes to service code
2. Test locally with `docker-compose`
3. Build Docker image
4. Test in kind cluster
5. Run `test-frontend-e2e.sh` to validate
6. Submit PR with test results

---

## 📄 License

This project is for educational purposes as part of B.TECH DevOps coursework.

---

## 👥 Authors

- **Megh Shah** - DevOps Engineer
- **Institution:** B.TECH, Semester 7 - DevOps Course

---

## 🎯 Project Goals

This project demonstrates:
- ✅ Microservices architecture
- ✅ Event-driven design with Apache Kafka
- ✅ Containerization with Docker
- ✅ Orchestration with Kubernetes
- ✅ Hybrid infrastructure (Docker + Kubernetes)
- ✅ CI/CD with GitHub Actions
- ✅ Service mesh patterns (using host.docker.internal)
- ✅ Full-stack development (React + Node.js)
- ✅ Database management (PostgreSQL)
- ✅ Real-time analytics and notifications

---

**🚀 Happy Deploying!**

For questions or issues, please open a GitHub issue or contact the maintainers.



### Step 1: Clone the Repository

```bash
git clone https://github.com/Jash-Pastagia/cloud_invoice_devops.git
cd cloud_invoice_devops
```

### Step 2: Run Setup Script

The setup script will automatically:
- ✅ Verify Docker and kubectl installation
- ✅ Create a kind Kubernetes cluster
- ✅ Start infrastructure services (PostgreSQL, Kafka, Zookeeper)
- ✅ Create Kubernetes namespace and secrets
- ✅ Load Docker images into the cluster
- ✅ Deploy all microservices

```bash
chmod +x setup-infrastructure.sh
./setup-infrastructure.sh
```

**Expected output:**
```
✅ Docker is running
✅ kubectl is installed
✅ kind cluster created: innovative-ci
✅ Infrastructure services started
✅ Kubernetes namespace created
✅ Secrets configured
✅ All services deployed
```

### Step 3: Verify Deployment

```bash
# Check all resources
kubectl get all -n innovative-ci

# Expected output:
# NAME                                       READY   STATUS    RESTARTS   AGE
# pod/analytics-service-xxx                  1/1     Running   0          2m
# pod/auth-service-xxx                       1/1     Running   0          2m
# pod/frontend-xxx                           1/1     Running   0          2m
# pod/invoice-service-xxx                    1/1     Running   0          2m
# pod/notification-service-xxx               1/1     Running   0          2m
# pod/payment-service-xxx                    1/1     Running   0          2m
```

### Step 4: Access the Application

```bash
# Start port-forward (runs in background)
kubectl port-forward -n innovative-ci svc/frontend 3000:80 &

# Open in browser
# macOS
open http://localhost:3000

# Linux
xdg-open http://localhost:3000

# Windows
start http://localhost:3000
```

### Step 5: Test the System

```bash
# Run comprehensive tests
chmod +x test-frontend-e2e.sh
./test-frontend-e2e.sh
```

---

## 🔍 Accessing Components

### 🌐 Frontend Application

**URL:** http://localhost:3000 (with port-forward active)

```bash
# Start port-forward
kubectl port-forward -n innovative-ci svc/frontend 3000:80

# Access in browser
open http://localhost:3000
```

**Features:**
- User authentication (Login/Register)
- Invoice management (Create, View, List)
- Payment processing
- Analytics dashboard
- Notifications center

### 🗄️ PostgreSQL Database

**Access from local machine:**

```bash
# Method 1: Using psql CLI
docker exec -it cloud-invoice-devops-postgres-1 psql -U invoice_user -d invoicedb

# Method 2: Using Docker exec
docker exec -it cloud-invoice-devops-postgres-1 bash
psql -U invoice_user -d invoicedb
```

**Common PostgreSQL Commands:**

```sql
-- List all databases
\l

-- Connect to invoicedb
\c invoicedb

-- List all tables
\dt

-- View users table
SELECT * FROM users;

-- View invoices table
SELECT * FROM invoices LIMIT 10;

-- View analytics events
SELECT * FROM analytics_events ORDER BY received_at DESC LIMIT 10;

-- View notifications
SELECT * FROM notifications ORDER BY received_at DESC LIMIT 10;

-- Count records
SELECT COUNT(*) FROM invoices;
SELECT COUNT(*) FROM users;
SELECT COUNT(*) FROM notifications;

-- Exit psql
\q
```

**Database Schema:**

```sql
-- Users table (auth-service)
CREATE TABLE users (
    id UUID PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    email VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Invoices table (invoice-service)
CREATE TABLE invoices (
    id UUID PRIMARY KEY,
    customer JSONB NOT NULL,
    items JSONB NOT NULL,
    total_amount DECIMAL(10,2),
    status VARCHAR(50) DEFAULT 'pending',
    due_date DATE,
    creator_id UUID REFERENCES users(id),
    assignee_id UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMP
);

-- Analytics events table (analytics-service)
CREATE TABLE analytics_events (
    id UUID PRIMARY KEY,
    event_type VARCHAR(255) NOT NULL,
    event_ts TIMESTAMP NOT NULL,
    payload JSONB,
    meta JSONB,
    source VARCHAR(255),
    received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    raw TEXT
);

-- Notifications table (notification-service)
CREATE TABLE notifications (
    id UUID PRIMARY KEY,
    event_type VARCHAR(255) NOT NULL,
    invoice_id UUID,
    payload JSONB,
    meta JSONB,
    received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_topic VARCHAR(255)
);
```

### 📡 Apache Kafka

**Access Kafka UI:**

```bash
# Kafka UI is already running on port 8080
open http://localhost:8080
```

**Kafka UI Features:**
- View all topics
- Monitor consumer groups
- See message counts
- Browse messages
- Monitor lag

**Access Kafka CLI:**

```bash
# Enter Kafka container
docker exec -it cloud-invoice-devops-kafka-1 bash

# List all topics
kafka-topics --list --bootstrap-server localhost:9092

# Describe a topic
kafka-topics --describe --topic invoice.created --bootstrap-server localhost:9092

# View messages in a topic
kafka-console-consumer --bootstrap-server localhost:9092 \
  --topic invoice.created \
  --from-beginning \
  --max-messages 10

# List consumer groups
kafka-consumer-groups --list --bootstrap-server localhost:9092

# Describe consumer group
kafka-consumer-groups --describe \
  --group analytics-service-group-v2 \
  --bootstrap-server localhost:9092

# Exit container
exit
```

**Kafka Topics in the System:**

| Topic | Producers | Consumers | Purpose |
|-------|-----------|-----------|---------|
| `invoice.created` | Invoice Service | Analytics, Notification | New invoice created |
| `invoice.paid` | Invoice Service | Analytics, Notification | Invoice marked as paid |
| `payment.initiated` | Payment Service | Analytics, Notification | Payment started |
| `payment.processed` | Payment Service | Analytics, Notification | Payment completed |

### 🐳 Docker Containers

**View running containers:**

```bash
# List all containers
docker ps

# View logs for specific container
docker logs cloud-invoice-devops-postgres-1
docker logs cloud-invoice-devops-kafka-1
docker logs cloud-invoice-devops-zookeeper-1

# Follow logs in real-time
docker logs -f cloud-invoice-devops-kafka-1

# Execute commands in containers
docker exec -it cloud-invoice-devops-postgres-1 bash
docker exec -it cloud-invoice-devops-kafka-1 bash
```

### ☸️ Kubernetes Pods & Services

**View all resources:**

```bash
# Get all resources in namespace
kubectl get all -n innovative-ci

# Get pods with detailed info
kubectl get pods -n innovative-ci -o wide

# Get services
kubectl get svc -n innovative-ci

# Get deployments
kubectl get deployments -n innovative-ci
```

**Access pod logs:**

```bash
# View logs for a specific service
kubectl logs -n innovative-ci deployment/auth-service
kubectl logs -n innovative-ci deployment/invoice-service
kubectl logs -n innovative-ci deployment/payment-service
kubectl logs -n innovative-ci deployment/analytics-service
kubectl logs -n innovative-ci deployment/notification-service
kubectl logs -n innovative-ci deployment/frontend

# Follow logs in real-time
kubectl logs -n innovative-ci deployment/analytics-service -f

# View logs from all pods of a deployment
kubectl logs -n innovative-ci deployment/invoice-service --all-containers=true

# View logs from previous container (if pod restarted)
kubectl logs -n innovative-ci deployment/auth-service --previous
```

**Execute commands in pods:**

```bash
# Get shell access to a pod
kubectl exec -it -n innovative-ci deployment/auth-service -- sh

# Run a specific command
kubectl exec -n innovative-ci deployment/invoice-service -- env

# Test network connectivity
kubectl exec -n innovative-ci deployment/auth-service -- wget -O- http://invoice-service:5050/health
```

**Port-forward to services:**

```bash
# Forward specific services to local ports
kubectl port-forward -n innovative-ci svc/auth-service 4000:4000
kubectl port-forward -n innovative-ci svc/invoice-service 5050:5050
kubectl port-forward -n innovative-ci svc/payment-service 6060:6060
kubectl port-forward -n innovative-ci svc/analytics-service 7100:7100
kubectl port-forward -n innovative-ci svc/notification-service 7200:7200
kubectl port-forward -n innovative-ci svc/frontend 3000:80

# Access services
curl http://localhost:4000/health
curl http://localhost:5050/health
curl http://localhost:7100/health
curl http://localhost:7200/
```

### 📊 Service Health Checks

**Check all services at once:**

```bash
# Auth service
curl http://localhost:4000/health

# Invoice service  
curl http://localhost:5050/health

# Analytics service (via frontend proxy)
curl http://localhost:3000/api/analytics/health

# Notification service (via frontend proxy)
curl http://localhost:3000/api/notification/

# Expected response:
# {"status":"ok","service":"<service-name>","..."}
```

### 🔐 Kubernetes Secrets

**View secrets:**

```bash
# List all secrets
kubectl get secrets -n innovative-ci

# View secret details (base64 encoded)
kubectl get secret app-secrets -n innovative-ci -o yaml

# Decode a specific secret value
kubectl get secret app-secrets -n innovative-ci -o jsonpath='{.data.DB_HOST}' | base64 --decode
```

**Secret values:**
- `DB_HOST`: host.docker.internal:5432
- `DB_NAME`: invoicedb
- `DB_USER`: invoice_user
- `DB_PASSWORD`: invoice_password
- `KAFKA_BROKERS`: host.docker.internal:9092
- `JWT_SECRET`: your-secret-key-change-this-in-production

---

## 📁 Project Structure

```
cloud-invoice-devops/
├── auth-service/
│   ├── Dockerfile
│   ├── index.js
│   └── package.json
├── invoice-service/
│   ├── Dockerfile
│   ├── index.js
│   ├── db.json
│   └── package.json
├── payment-service/
│   ├── Dockerfile
│   ├── index.js
│   └── package.json
├── k8s/
│   ├── auth-deployment.yaml
│   ├── invoice-deployment.yaml
│   ├── payment-deployment.yaml
│   ├── ingress.yaml
│   ├── secret.yaml
│   └── services.yaml
├── docker-compose.yml
└── README.md
```

## 🐳 Local Development with Docker Compose

### Step 1: Verify Docker Installation

```powershell
# Check Docker version
docker version

# Verify Docker is running
docker info
```

**Expected Output:**
```
Client:
 Version:           28.4.0
 API version:       1.51
 ...
Server: Docker Desktop 4.46.0
 Engine:
  Version:          28.4.0
  ...
```

### Step 2: Build and Run Services

```powershell
# Navigate to project directory
cd "D:\Nirma University\Sem - 7\Cloud Native and DevOps (CNAOps)\Mini Project\cloud-invoice-devops"

# Build and start all services in detached mode
docker compose up -d --build
```

**Expected Output:**
```
[+] Building 3.3s (29/29) FINISHED
[+] Running 7/7
 ✔ Network cloud-invoice-devops_devnet   Created
 ✔ Container auth-service                Started
 ✔ Container invoice-service             Started
 ✔ Container payment-service             Started
```

### Step 3: Verify Running Containers

```powershell
# Check running containers
docker ps

# View container logs
docker logs auth-service
docker logs invoice-service
docker logs payment-service
```

### Step 4: Test Services

Access the following endpoints in your browser or with curl:

- **Auth Service**: http://localhost:4000/
- **Invoice Service**: http://localhost:5000/
- **Payment Service**: http://localhost:6000/

### Stop Services

```powershell
# Stop all services
docker compose down

# Stop and remove volumes
docker compose down -v
```

## ☸️ Kubernetes Deployment with Minikube

### Step 1: Start Minikube

```powershell
# Start Minikube with Docker driver
minikube start
```

**Expected Output:**
```
😄  minikube v1.37.0 on Microsoft Windows 11
✨  Using the docker driver based on existing profile
👍  Starting "minikube" primary control-plane node in "minikube" cluster
🐳  Preparing Kubernetes v1.34.0 on Docker 28.4.0 ...
🏄  Done! kubectl is now configured to use "minikube" cluster
```

### Step 2: Verify Cluster

```powershell
# Check cluster nodes
kubectl get nodes

# Check all system pods
kubectl get pods -A
```

**Expected Output:**
```
NAME       STATUS   ROLES           AGE    VERSION
minikube   Ready    control-plane   4d3h   v1.34.0
```

### Step 3: Enable Ingress Addon

```powershell
# Enable ingress controller
minikube addons enable ingress
```

**Expected Output:**
```
💡  ingress is an addon maintained by Kubernetes
🔎  Verifying ingress addon...
🌟  The 'ingress' addon is enabled
```

### Step 4: Build and Load Docker Images into Minikube

**Option A: Build Directly in Minikube's Docker Daemon (Recommended)**

```powershell
# Point Docker CLI to Minikube's Docker daemon
& minikube -p minikube docker-env --shell powershell | Invoke-Expression

# Build images (they'll be available in Minikube)
docker build -t cloud-invoice-devops-auth-service:latest ./auth-service
docker build -t cloud-invoice-devops-invoice-service:latest ./invoice-service
docker build -t cloud-invoice-devops-payment-service:latest ./payment-service

# Verify images
docker images | Select-String cloud-invoice
```

**Option B: Build with Docker Desktop and Load into Minikube**

```powershell
# Build images with Docker Desktop (default context)
docker compose up -d --build

# Load images into Minikube
minikube image load cloud-invoice-devops-auth-service:latest
minikube image load cloud-invoice-devops-invoice-service:latest
minikube image load cloud-invoice-devops-payment-service:latest
```

### Step 5: Deploy to Kubernetes

```powershell
# Create secret for JWT
kubectl apply -f k8s/secret.yaml

# Deploy all services
kubectl apply -f k8s/auth-deployment.yaml
kubectl apply -f k8s/invoice-deployment.yaml
kubectl apply -f k8s/payment-deployment.yaml

# Deploy ingress
kubectl apply -f k8s/ingress.yaml
```

**Expected Output:**
```
secret/jwt-secret created
deployment.apps/auth-service created
service/auth-service created
deployment.apps/invoice-service created
service/invoice-service created
deployment.apps/payment-service created
service/payment-service created
Warning: annotation "kubernetes.io/ingress.class" is deprecated...
ingress.networking.k8s.io/invoice-ingress created
```

### Step 6: Verify Deployments

```powershell
# Check all resources
kubectl get all

# Check pods status
kubectl get pods

# Check services
kubectl get svc

# Check ingress
kubectl get ingress
```

**Expected Output:**
```
NAME                                   READY   STATUS    RESTARTS   AGE
pod/auth-service-84b644b586-24sdl      1/1     Running   0          2m
pod/invoice-service-7f6f98bff4-hq2lh   1/1     Running   0          2m
pod/payment-service-7959f98c77-kngxp   1/1     Running   0          2m

NAME                      TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)
service/auth-service      ClusterIP   10.108.127.126   <none>        4000/TCP
service/invoice-service   ClusterIP   10.97.231.239    <none>        5000/TCP
service/payment-service   ClusterIP   10.97.93.128     <none>        6000/TCP
```

### Step 7: Configure Local DNS (Ingress Access)

```powershell
# Get Minikube IP
minikube ip
```

**Output example:** `192.168.49.2`

**Add to hosts file:**

1. Open `C:\Windows\System32\drivers\etc\hosts` as Administrator
2. Add this line:
   ```
   192.168.49.2 cloudinvoice.local
   ```

### Step 8: Access Application

```powershell
# Start Minikube tunnel (run in a separate terminal, keep it running)
minikube tunnel
```

Access the application:
- **Base URL**: http://cloudinvoice.local
- **Auth Service**: http://cloudinvoice.local/auth
- **Invoice Service**: http://cloudinvoice.local/invoices
- **Payment Service**: http://cloudinvoice.local/payments

## 🧪 API Testing Guide

### 1️⃣ Login to Get JWT Token

**Request:**
```powershell
# Using PowerShell
$response = Invoke-RestMethod -Uri "http://localhost:4000/login" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"username":"demo","password":"demo123"}'
$token = $response.token
```

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### 2️⃣ Create an Invoice

**Request:**
```powershell
$invoice = Invoke-RestMethod -Uri "http://localhost:5000/invoices" `
  -Method POST `
  -ContentType "application/json" `
  -Headers @{Authorization="Bearer $token"} `
  -Body @"
{
  "customer": {"name": "Acme Corp", "email": "billing@acme.com"},
  "items": [
    {"description": "Website Hosting", "qty": 1, "price": 100},
    {"description": "Maintenance", "qty": 2, "price": 50}
  ],
  "dueDate": "2025-10-15"
}
"@
$invoiceId = $invoice.id
```

**Response:**
```json
{
  "id": "ce9afd2f-6ce7-4e4e-b45a-adfa5257438b",
  "customer": {"name": "Acme Corp", "email": "billing@acme.com"},
  "items": [...],
  "status": "unpaid",
  "createdAt": "2025-10-04T09:49:09.447Z"
}
```

### 3️⃣ View All Invoices

**Request:**
```powershell
Invoke-RestMethod -Uri "http://localhost:5000/invoices" `
  -Method GET `
  -Headers @{Authorization="Bearer $token"}
```

### 4️⃣ Process Payment

**Request:**
```powershell
$payment = Invoke-RestMethod -Uri "http://localhost:6000/payments" `
  -Method POST `
  -ContentType "application/json" `
  -Headers @{Authorization="Bearer $token"} `
  -Body "{`"invoiceId`":`"$invoiceId`",`"amount`":200}"
```

**Response:**
```json
{
  "message": "Payment processed (mock)",
  "invoice": {
    "id": "ce9afd2f-6ce7-4e4e-b45a-adfa5257438b",
    "status": "paid",
    "paidAt": "2025-10-04T09:10:00.000Z"
  },
  "amount": 200
}
```

## 🔧 Troubleshooting

### Issue: ImagePullBackOff in Kubernetes

**Symptoms:**
```
pod/auth-service-84b644b586-24sdl      0/1     ImagePullBackOff   0          2m
```

**Solution:**

1. **Ensure images are built and loaded into Minikube:**
   ```powershell
   # Point to Minikube's Docker daemon
   & minikube -p minikube docker-env --shell powershell | Invoke-Expression
   
   # Build images
   docker build -t cloud-invoice-devops-auth-service:latest ./auth-service
   docker build -t cloud-invoice-devops-invoice-service:latest ./invoice-service
   docker build -t cloud-invoice-devops-payment-service:latest ./payment-service
   
   # Verify images exist
   docker images
   ```

2. **Update deployment manifests to use `imagePullPolicy: Never`:**
   ```yaml
   spec:
     containers:
     - name: auth
       image: cloud-invoice-devops-auth-service:latest
       imagePullPolicy: Never  # Add this line
   ```

3. **Restart deployments:**
   ```powershell
   kubectl rollout restart deployment auth-service
   kubectl rollout restart deployment invoice-service
   kubectl rollout restart deployment payment-service
   ```

### Issue: Minikube Can't Connect to Docker

**Symptoms:**
```
💣  Exiting due to PROVIDER_DOCKER_VERSION_EXIT_1
error during connect: Get "http://%2F%2F.%2Fpipe%2FdockerDesktopLinuxEngine/v1.51/version"
```

**Solution:**

1. **Start Docker Desktop:**
   - Ensure Docker Desktop is running
   - Check system tray for Docker icon
   - Wait for Docker to fully start (whale icon should be stable)

2. **Verify Docker is running:**
   ```powershell
   docker version
   docker info
   ```

3. **Restart Minikube:**
   ```powershell
   minikube delete
   minikube start --driver=docker
   ```

### Issue: Ingress Conflict

**Symptoms:**
```
Error from server (BadRequest): admission webhook denied the request: 
host "cloudinvoice.local" and path "/auth" is already defined in ingress default/invoice-ingress
```

**Solution:**

1. **Delete existing ingress in default namespace:**
   ```powershell
   kubectl delete ingress invoice-ingress
   ```

2. **Or deploy to a specific namespace:**
   ```powershell
   # Create namespace
   kubectl create namespace cloudinvoice
   
   # Deploy to namespace
   kubectl apply -f k8s/ -n cloudinvoice
   
   # Check resources
   kubectl get all -n cloudinvoice
   ```

### Issue: Cannot Access Services via Ingress

**Solution:**

1. **Verify ingress is running:**
   ```powershell
   kubectl get ingress
   kubectl describe ingress invoice-ingress
   ```

2. **Check ingress controller pods:**
   ```powershell
   kubectl get pods -n ingress-nginx
   ```

3. **Start Minikube tunnel (required for LoadBalancer access):**
   ```powershell
   # Run in a separate terminal and keep it open
   minikube tunnel
   ```

4. **Update hosts file with Minikube IP:**
   ```powershell
   # Get IP
   minikube ip
   
   # Add to C:\Windows\System32\drivers\etc\hosts
   192.168.49.2 cloudinvoice.local
   ```

### Issue: Pods Stuck in ContainerCreating

**Solution:**

1. **Check pod events:**
   ```powershell
   kubectl describe pod <pod-name>
   ```

2. **Check persistent volume claims:**
   ```powershell
   kubectl get pvc
   ```

3. **Restart pod:**
   ```powershell
   kubectl delete pod <pod-name>
   ```

### Useful Debugging Commands

```powershell
# View pod logs
kubectl logs <pod-name>

# Follow logs in real-time
kubectl logs -f <pod-name>

# Describe resource for detailed info
kubectl describe pod <pod-name>
kubectl describe deployment <deployment-name>
kubectl describe service <service-name>

# Execute command in pod
kubectl exec -it <pod-name> -- sh

# Port forward for direct access
kubectl port-forward pod/<pod-name> 8080:4000

# Get events
kubectl get events --sort-by='.lastTimestamp'

# Check resource usage
kubectl top nodes
kubectl top pods
```

## 🛠️ Technologies Used

| Technology | Version | Purpose |
|------------|---------|---------|
| **Node.js** | 18 | Runtime environment |
| **Express** | 4.18.2 | Web framework |
| **JWT** | 9.0.0 | Authentication |
| **Docker** | 28.4.0 | Containerization |
| **Docker Compose** | 2.39.2 | Multi-container orchestration |
| **Kubernetes** | 1.34.0 | Container orchestration |
| **Minikube** | 1.37.0 | Local Kubernetes |
| **Nginx Ingress** | 1.13.2 | Ingress controller |

## 📝 Environment Variables

| Variable | Service | Default | Description |
|----------|---------|---------|-------------|
| `JWT_SECRET` | All | `supersecretdevops` | Secret key for JWT signing |
| `PORT` | Auth | `4000` | Auth service port |
| `PORT` | Invoice | `5000` | Invoice service port |
| `PORT` | Payment | `6000` | Payment service port |
| `INVOICE_URL` | Payment | `http://invoice-service:5000` | Invoice service endpoint |

## 🚀 Quick Start Commands

### Docker Compose (Local Development)

```powershell
# Start
docker compose up -d --build

# Check status
docker ps

# View logs
docker compose logs -f

# Stop
docker compose down
```

### Kubernetes (Minikube)

```powershell
# Start cluster
minikube start

# Deploy
kubectl apply -f k8s/

# Check status
kubectl get all

# Access logs
kubectl logs -f deployment/auth-service

# Cleanup
kubectl delete -f k8s/
minikube stop
```

## 📚 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [Express.js Documentation](https://expressjs.com/)
- [JWT Introduction](https://jwt.io/introduction)

## 📄 License

This project is created for educational purposes as part of the Cloud Native and DevOps course.

## 👥 Contributors

- Nirma University - Sem 7 - Cloud Native and DevOps (CNAOps) Mini Project

---

**Note**: This is a demonstration project. For production use, implement proper security measures, use managed secrets, add monitoring, and follow cloud-native best practices.
