# Cloud Invoice DevOps - Microservices Project

A cloud-native invoice management system built with microservices architecture, demonstrating DevOps practices including containerization with Docker and orchestration with Kubernetes.

## 📋 Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Local Development with Docker Compose](#local-development-with-docker-compose)
- [Kubernetes Deployment with Minikube](#kubernetes-deployment-with-minikube)
- [API Testing Guide](#api-testing-guide)
- [Troubleshooting](#troubleshooting)
- [Technologies Used](#technologies-used)

## 🎯 Project Overview

This project implements a microservices-based invoice management system with three core services:

- **Auth Service** (Port 4000): Handles user authentication and JWT token generation
- **Invoice Service** (Port 5000): Manages invoice creation, retrieval, and status updates
- **Payment Service** (Port 6000): Processes mock payments and updates invoice status

## 🏗️ Architecture

```
┌─────────────────┐
│   Ingress/LB    │
│ (cloudinvoice.  │
│     local)      │
└────────┬────────┘
         │
    ┌────┴────┬────────────┐
    │         │            │
┌───▼───┐ ┌──▼────┐ ┌─────▼──┐
│ Auth  │ │Invoice│ │Payment │
│Service│ │Service│ │Service │
│:4000  │ │:5000  │ │:6000   │
└───────┘ └───────┘ └────────┘
```

## ✅ Prerequisites

### Required Software

| Software | Version | Purpose |
|----------|---------|---------|
| **Docker Desktop** | 28.4.0+ | Container runtime |
| **Minikube** | v1.37.0+ | Local Kubernetes cluster |
| **kubectl** | v1.32.2+ | Kubernetes CLI |
| **Node.js** | 18+ | Runtime for services |
| **PowerShell** | 5.1+ | Command line (Windows) |

### System Requirements

- **OS**: Windows 11 (tested), Windows 10, macOS, or Linux
- **RAM**: Minimum 8GB (16GB recommended)
- **CPU**: 4+ cores recommended
- **Disk**: 20GB free space

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
