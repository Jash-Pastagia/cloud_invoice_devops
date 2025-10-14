const express = require('express');
const bodyParser = require('body-parser');
const { v4: uuidv4 } = require('uuid');
const cors = require('cors');
const db = require('./db');

const app = express();

// Enable CORS for frontend
app.use(cors({
  origin: 'http://localhost:3000',
  credentials: true,
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
// Explicitly handle preflight requests
app.options('/health', cors({
  origin: 'http://localhost:3000',
  credentials: true,
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.options('/metrics', cors({
  origin: 'http://localhost:3000',
  credentials: true,
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.options('/events', cors({
  origin: 'http://localhost:3000',
  credentials: true,
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(bodyParser.json());

// Environment configuration
const PORT = process.env.PORT || 7100;
const TOPICS = (process.env.TOPICS || 'invoice.created,invoice.paid,payment.processed').split(',');
const KAFKA_CONSUMER_GROUP = process.env.KAFKA_CONSUMER_GROUP || 'analytics-service-group';
const KAFKA_BROKERS = process.env.KAFKA_BROKERS || 'kafka:9092';

// Service state tracking
let dbConnected = false;
let kafkaConnected = false;
let consumer = null;

// Shared library loader
let createConsumer;
try {
  createConsumer = require('../lib/kafka').createConsumer;
  console.log('[analytics-service] loaded shared kafka library from ../lib/kafka');
} catch (err) {
  try {
    createConsumer = require('./lib/kafka').createConsumer;
    console.log('[analytics-service] loaded local kafka library from ./lib/kafka');
  } catch (localErr) {
    console.error('[analytics-service] ERROR: Cannot load kafka library from ../lib/kafka or ./lib/kafka');
    console.error('Make sure the shared lib/kafka.js exists in the repository root');
    process.exit(1);
  }
}

/**
 * Safely parse JSON string
 * @param {string} str - JSON string to parse
 * @returns {object|null} Parsed object or null if invalid
 */
function safeJsonParse(str) {
  try {
    return JSON.parse(str);
  } catch (err) {
    return null;
  }
}

/**
 * Process Kafka message and insert into analytics database
 * @param {string} topic - Kafka topic
 * @param {string} message - Raw message string
 */
async function processMessage(topic, message) {
  const rawString = message || '';
  const parsed = safeJsonParse(rawString);
  
  // Build analytics event object following the expected format
  const evt = {
    id: parsed?.meta?.trace_id || parsed?.id || uuidv4(),
    event_type: parsed?.event_type || topic,
    event_ts: parsed?.timestamp || parsed?.event_ts || new Date().toISOString(),
    payload: parsed?.payload || parsed || null,
    meta: parsed?.meta || null,
    source: parsed?.meta?.source || parsed?.source || 'unknown',
    raw: rawString
  };

  // Insert with retry logic
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      await db.insertEvent(evt);
      return; // Success, exit retry loop
    } catch (error) {
      console.error(`[analytics-service] db insert attempt ${attempt}/3 failed for id=${evt.id}:`, error.message);
      if (attempt === 3) {
        console.error(`[analytics-service] giving up on event id=${evt.id} after 3 attempts`);
      } else {
        // Wait before retry
        await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
      }
    }
  }
}

// Express routes

/**
 * Health check endpoint
 */
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    db: dbConnected ? 'connected' : 'disconnected',
    kafka: kafkaConnected ? 'connected' : 'disconnected',
    service: 'analytics-service',
    version: '1.0.0'
  });
});

/**
 * GET /metrics - Return analytics metrics
 */
app.get('/metrics', async (req, res) => {
  try {
    if (!dbConnected) {
      return res.status(503).json({ error: 'Database not available' });
    }

    // Get 24h counts for specific event types
    const [
      invoicesCreated24h,
      invoicesPaid24h,
      paymentsProcessed24h,
      eventsLast1h,
      latestEventTime
    ] = await Promise.all([
      db.aggregateCountsWithinWindow('invoice.created', 24 * 60 * 60),
      db.aggregateCountsWithinWindow('invoice.paid', 24 * 60 * 60),
      db.aggregateCountsWithinWindow('payment.processed', 24 * 60 * 60),
      db.countsByTypeWindow(60 * 60), // 1 hour
      db.getLatestEventTime()
    ]);

    res.json({
      invoices_created_last_24h: invoicesCreated24h,
      invoices_paid_last_24h: invoicesPaid24h,
      payments_processed_last_24h: paymentsProcessed24h,
      events_last_1h_by_type: eventsLast1h,
      last_event_time: latestEventTime
    });
  } catch (error) {
    console.error('[analytics-service] Failed to generate metrics:', error.message);
    res.status(500).json({ error: 'Failed to generate metrics' });
  }
});

/**
 * GET /events - Return recent events
 */
app.get('/events', async (req, res) => {
  try {
    if (!dbConnected) {
      return res.status(503).json({ error: 'Database not available' });
    }

    const limit = Math.min(parseInt(req.query.limit || '100', 10), 1000);
    const events = await db.getRecentEvents(limit);
    
    res.json({
      events,
      count: events.length,
      limit
    });
  } catch (error) {
    console.error('[analytics-service] Failed to fetch events:', error.message);
    res.status(500).json({ error: 'Failed to fetch events' });
  }
});

/**
 * Root endpoint
 */
app.get('/', (req, res) => {
  res.json({ 
    service: 'analytics-service', 
    status: 'ok',
    endpoints: ['/health', '/metrics', '/events']
  });
});

/**
 * Start Kafka consumer
 */
async function startKafkaConsumer() {
  try {
    console.log(`[analytics-service] Starting Kafka consumer for topics: ${TOPICS.join(', ')}`);
    
    consumer = await createConsumer({
      groupId: KAFKA_CONSUMER_GROUP,
      topics: TOPICS,
      eachMessage: async ({ topic, partition, message }) => {
        try {
          const messageValue = message.value?.toString() || '';
          console.log(`[analytics-service] consumed ${topic} message`);
          
          await processMessage(topic, messageValue);
        } catch (err) {
          console.error(`[analytics-service] Error processing message from ${topic}:`, err.message);
          // Continue processing other messages
        }
      }
    });

    kafkaConnected = true;
    console.log('[analytics-service] Kafka consumer started successfully');
    
  } catch (err) {
    console.error('[analytics-service] ERROR: Failed to start Kafka consumer:', err);
    kafkaConnected = false;
    // Don't exit, allow service to run for health checks
  }
}

/**
 * Initialize and start the analytics service
 */
async function startService() {
  try {
    console.log('[analytics-service] Starting analytics service...');
    
    // Initialize database
    console.log('[analytics-service] Initializing database...');
    dbConnected = await db.init();
    
    if (dbConnected) {
      console.log('[analytics-service] Database connected - analytics ready');
    } else {
      console.error('[analytics-service] Database unavailable - metrics will be limited');
    }
    
    // Start Kafka consumer
    await startKafkaConsumer();
    
    // Start HTTP server
    const server = app.listen(PORT, () => {
      console.log(`[analytics-service] HTTP server listening on port ${PORT}`);
      console.log(`[analytics-service] Topics: ${TOPICS.join(', ')}`);
      console.log(`[analytics-service] Consumer Group: ${KAFKA_CONSUMER_GROUP}`);
      console.log(`[analytics-service] Kafka Brokers: ${KAFKA_BROKERS}`);
      console.log(`[analytics-service] Database: ${dbConnected ? 'Connected' : 'Disconnected'}`);
      console.log(`[analytics-service] Kafka: ${kafkaConnected ? 'Connected' : 'Disconnected'}`);
    });
    
    // Store server reference for graceful shutdown
    app.locals.server = server;
    
  } catch (error) {
    console.error('[analytics-service] Failed to start service:', error);
    process.exit(1);
  }
}

// Graceful shutdown
const gracefulShutdown = async (signal) => {
  console.log(`[analytics-service] Received ${signal}, shutting down gracefully...`);
  
  // Disconnect Kafka consumer
  if (consumer && consumer.disconnect) {
    try {
      await consumer.disconnect();
      console.log('[analytics-service] Kafka consumer disconnected');
    } catch (err) {
      console.error('[analytics-service] Error disconnecting consumer:', err);
    }
  }
  
  // Close database connection
  if (dbConnected) {
    try {
      await db.close();
      console.log('[analytics-service] Database connection closed');
    } catch (err) {
      console.error('[analytics-service] Error closing database:', err);
    }
  }
  
  // Close HTTP server
  if (app.locals.server) {
    app.locals.server.close(() => {
      console.log('[analytics-service] HTTP server closed');
      process.exit(0);
    });
  } else {
    process.exit(0);
  }
};

process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

// Start the service
startService();