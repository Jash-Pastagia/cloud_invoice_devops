# Analytics Service

Analytics microservice for the cloud invoice system. Consumes events from Kafka and provides real-time metrics and analytics data stored in PostgreSQL.

## Features

- **Event Processing**: Consumes events from Kafka topics (`invoice.created`, `invoice.paid`, `payment.processed`, `payment.initiated`)
- **PostgreSQL Storage**: Stores analytics events in a dedicated `analytics.events` table with JSONB support
- **Metrics API**: Provides aggregated metrics and event counts
- **Health Monitoring**: Health check endpoint for service monitoring
- **Graceful Shutdown**: Proper cleanup of Kafka consumers and database connections

## API Endpoints

### GET /health
Returns service health status including database and Kafka connectivity.

```json
{
  "status": "ok",
  "db": "connected",
  "kafka": "connected",
  "service": "analytics-service", 
  "version": "1.0.0"
}
```

### GET /metrics
Returns analytics metrics for the last 24 hours and 1 hour.

```json
{
  "invoices_created_last_24h": 15,
  "invoices_paid_last_24h": 12,
  "payments_processed_last_24h": 12,
  "events_last_1h_by_type": {
    "invoice.created": 3,
    "payment.processed": 2,
    "invoice.paid": 2
  },
  "last_event_time": "2025-10-14T10:42:50.474Z"
}
```

### GET /events?limit=100
Returns recent events (max 1000, default 100).

```json
{
  "events": [...],
  "count": 50,
  "limit": 100
}
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `7100` | HTTP server port |
| `KAFKA_BROKERS` | `kafka:9092` | Kafka broker endpoints |
| `KAFKA_CONSUMER_GROUP` | `analytics-service-group` | Kafka consumer group ID |
| `TOPICS` | `invoice.created,invoice.paid,payment.processed` | Comma-separated Kafka topics |
| `DB_HOST` | `postgres` | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_NAME` | `cloud_invoice` | Database name |
| `DB_USER` | `dev` | Database user |
| `DB_PASSWORD` | `devpass` | Database password |

## Development

### Local Development
```bash
# Install dependencies
cd analytics-service && npm ci

# Start service (ensure Kafka and PostgreSQL are running)
npm run dev
```

### Docker Development
```bash
# Build and run with docker-compose
docker-compose up -d --build analytics-service

# Check logs
docker-compose logs -f analytics-service
```

### Kubernetes Deployment
```bash
# Deploy to Kubernetes
kubectl apply -f k8s/analytics-deployment.yaml

# Check status
kubectl get pods -l app=analytics-service
kubectl logs -l app=analytics-service
```

## Database Schema

The service creates an `analytics` schema with an `events` table:

```sql
CREATE TABLE analytics.events (
  id TEXT PRIMARY KEY,
  event_type TEXT NOT NULL,
  event_ts TIMESTAMPTZ NOT NULL,
  payload JSONB,
  meta JSONB,
  source TEXT,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  raw TEXT
);
```

Includes optimized indexes for:
- Event type and timestamp queries
- Recent events retrieval
- Source-based filtering

## Verification Steps

### 1. Build and Start Service
```bash
cd analytics-service && npm ci
docker-compose build analytics-service
docker-compose up -d analytics-service
```

### 2. Generate Test Events
Create invoices and payments to generate events:
```bash
# Get auth token
TOKEN=$(curl -s -X POST http://localhost:4000/login \
  -H "Content-Type: application/json" \
  -d '{"username": "demo", "password": "demo123"}' | jq -r '.token')

# Create invoice
curl -s -X POST http://localhost:5050/invoices \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"customer": "Test", "items": [{"name": "Test", "price": 100, "quantity": 1}]}' | jq

# Process payment (use invoice ID from above)
curl -s -X POST http://localhost:6000/payments \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"invoiceId": "INVOICE_ID", "amount": 100, "method": "test"}' | jq
```

### 3. Verify Analytics
```bash
# Check health
curl http://localhost:7100/health | jq

# Check metrics
curl http://localhost:7100/metrics | jq

# Check recent events
curl http://localhost:7100/events?limit=10 | jq
```

### 4. Verify Database
```bash
# Connect to PostgreSQL and check data
PG_CONTAINER=$(docker ps -qf "ancestor=postgres:18-alpine")
docker exec -it $PG_CONTAINER psql -U dev -d cloud_invoice -c \
  "SELECT event_type, count(*) FROM analytics.events GROUP BY event_type;"
```

## Monitoring

- Health checks available at `/health`
- Logs include structured information about event processing
- Database connection retry with exponential backoff
- Kafka consumer connection monitoring
- Graceful shutdown on SIGINT/SIGTERM

## Architecture

```
Kafka Topics → Analytics Service → PostgreSQL
     ↓              ↓                ↓
Events Flow    Processing &      Analytics
               Aggregation        Storage
                    ↓
               HTTP API (Metrics)
```

The service operates in event-driven mode, consuming from Kafka topics and providing real-time analytics through HTTP endpoints.