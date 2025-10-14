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
app.options('/notifications', cors({
  origin: 'http://localhost:3000',
  credentials: true,
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.options('/notifications/send', cors({
  origin: 'http://localhost:3000',
  credentials: true,
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(bodyParser.json());

// Environment configuration
const PORT = process.env.PORT || 7000;
const TOPICS = (process.env.TOPICS || 'invoice.created,invoice.paid,payment.processed').split(',');
const KAFKA_CONSUMER_GROUP = process.env.KAFKA_CONSUMER_GROUP || 'notification-service-group';
const MAX_NOTIFICATIONS = parseInt(process.env.MAX_NOTIFICATIONS || '200', 10);
const KAFKA_BROKERS = process.env.KAFKA_BROKERS || 'kafka:9092';

// In-memory notifications store (newest first) - fallback when DB unavailable
let notifications = [];
let dbMode = false;

// Shared library loader
let createConsumer;
try {
  createConsumer = require('../lib/kafka').createConsumer;
  console.log('[notification-service] loaded shared kafka library from ../lib/kafka');
} catch (err) {
  try {
    createConsumer = require('./lib/kafka').createConsumer;
    console.log('[notification-service] loaded local kafka library from ./lib/kafka');
  } catch (localErr) {
    console.error('[notification-service] ERROR: Cannot load kafka library from ../lib/kafka or ./lib/kafka');
    console.error('Make sure the shared lib/kafka.js exists in the repository root');
    process.exit(1);
  }
}

/**
 * Add notification to in-memory store (newest first, capped at MAX_NOTIFICATIONS)
 * @param {object} notification - Notification object to add
 */
function addNotification(notification) {
  notifications.unshift(notification);
  if (notifications.length > MAX_NOTIFICATIONS) {
    notifications = notifications.slice(0, MAX_NOTIFICATIONS);
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

// Express routes
app.get('/', (req, res) => {
  res.json({ service: 'notification', status: 'ok' });
});

/**
 * GET /notifications - Return latest notifications
 */
app.get('/notifications', async (req, res) => {
  const limit = Math.min(parseInt(req.query.limit || '50', 10), MAX_NOTIFICATIONS);
  
  try {
    if (dbMode && db.isDbConnected()) {
      // Try to fetch from database first
      const dbNotifications = await db.getRecentNotifications(limit);
      console.log(`[notification-service] fetched ${dbNotifications.length} notifications from DB`);
      return res.json(dbNotifications);
    }
  } catch (error) {
    console.error('[notification-service] Failed to fetch from DB, falling back to in-memory:', error.message);
  }
  
  // Fallback to in-memory store
  console.log(`[notification-service] serving ${notifications.length} notifications from in-memory (fallback mode)`);
  res.json(notifications.slice(0, limit));
});

/**
 * POST /notifications/send - Create manual notification
 */
app.post('/notifications/send', async (req, res) => {
  const { invoiceId, message, eventType } = req.body;
  
  if (!message || !eventType) {
    return res.status(400).json({ error: 'message and eventType are required' });
  }

  const notification = {
    id: uuidv4(),
    eventType,
    invoiceId: invoiceId || null,
    payload: { message },
    meta: { manual: true },
    receivedAt: new Date().toISOString(),
    sourceTopic: 'manual'
  };

  // Save to database if available
  if (dbMode && db.isDbConnected()) {
    try {
      await db.saveNotification(notification);
    } catch (error) {
      console.error(`[notification-service] db save failed for manual notification id=${notification.id} error=${error.message}`);
    }
  }

  addNotification(notification);
  console.log(`[notification-service] manual notification created: ${notification.id}`);
  
  res.status(201).json(notification);
});

// Initialize database and start HTTP server
async function startServer() {
  try {
    // Initialize database connection
    console.log('[notification-service] Initializing database...');
    dbMode = await db.init();
    
    if (dbMode) {
      console.log('[notification-service] Database connected - using DB mode');
    } else {
      console.log('[notification-service] Database unavailable - using in-memory fallback mode');
    }
    
    // Start HTTP server
    const server = app.listen(PORT, () => {
      console.log(`[notification-service] HTTP server listening on port ${PORT}`);
      console.log(`[notification-service] Topics: ${TOPICS.join(', ')}`);
      console.log(`[notification-service] Consumer Group: ${KAFKA_CONSUMER_GROUP}`);
      console.log(`[notification-service] Kafka Brokers: ${KAFKA_BROKERS}`);
      console.log(`[notification-service] Mode: ${dbMode ? 'Database' : 'In-memory fallback'}`);
      
      // Start Kafka consumer after HTTP server is ready
      startKafkaConsumer();
    });
    
    // Store server reference for graceful shutdown
    app.locals.server = server;
    
  } catch (error) {
    console.error('[notification-service] Failed to start server:', error);
    process.exit(1);
  }
}

// Start the server
startServer();

/**
 * Start Kafka consumer
 */
async function startKafkaConsumer() {
  try {
    const consumer = await createConsumer({
      groupId: KAFKA_CONSUMER_GROUP,
      topics: TOPICS,
      eachMessage: async ({ topic, partition, message }) => {
        try {
          const rawString = message.value?.toString() || '';
          const parsed = safeJsonParse(rawString);
          
          // Parse payload more carefully to ensure proper JSON objects
          let processedPayload = null;
          if (parsed?.payload && typeof parsed.payload === 'object') {
            processedPayload = parsed.payload;
          } else if (parsed?.payload && typeof parsed.payload === 'string') {
            processedPayload = { data: parsed.payload };
          } else if (rawString && rawString !== '') {
            processedPayload = { raw: rawString };
          }

          const notification = {
            id: uuidv4(),
            eventType: parsed?.event_type || topic,
            invoiceId: parsed?.payload?.id || parsed?.payload?.invoiceId || null,
            payload: processedPayload,
            meta: parsed?.meta && typeof parsed.meta === 'object' ? parsed.meta : null,
            receivedAt: new Date().toISOString(),
            sourceTopic: topic
          };

          // Save to database if available (fire and forget with await for durability)
          if (dbMode && db.isDbConnected()) {
            try {
              await db.saveNotification(notification);
            } catch (error) {
              console.error(`[notification-service] db save failed id=${notification.id} error=${error.message}`);
            }
          }

          addNotification(notification);
          
          console.log(`[notification-service] consumed ${topic} invoice=${notification.invoiceId} id=${notification.id}`);
        } catch (err) {
          console.error(`[notification-service] Error processing message from ${topic}:`, err);
        }
      }
    });

    console.log('[notification-service] Kafka consumer started successfully');

    // Store consumer for graceful shutdown
    app.locals.consumer = consumer;
    
  } catch (err) {
    console.error('[notification-service] ERROR: Failed to start Kafka consumer:', err);
    process.exit(1);
  }
}

// Graceful shutdown
const gracefulShutdown = async (signal) => {
  console.log(`[notification-service] Received ${signal}, shutting down gracefully...`);
  
  if (app.locals.consumer && app.locals.consumer.disconnect) {
    try {
      await app.locals.consumer.disconnect();
      console.log('[notification-service] Kafka consumer disconnected');
    } catch (err) {
      console.error('[notification-service] Error disconnecting consumer:', err);
    }
  }
  
  // Close database connection
  if (dbMode) {
    try {
      await db.close();
      console.log('[notification-service] Database connection closed');
    } catch (err) {
      console.error('[notification-service] Error closing database:', err);
    }
  }
  
  if (app.locals.server) {
    app.locals.server.close(() => {
      console.log('[notification-service] HTTP server closed');
      process.exit(0);
    });
  } else {
    process.exit(0);
  }
};

process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));