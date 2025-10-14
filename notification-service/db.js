// notification-service/db.js
// Postgres persistence for notification events
const { Pool } = require('pg');

let pool = null;
let isConnected = false;

// Database connection configuration from environment
const config = {
  host: process.env.DB_HOST || 'postgres',
  port: parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME || 'cloud_invoice',
  user: process.env.DB_USER || 'dev',
  password: process.env.DB_PASSWORD || 'devpass',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
};

// Create notifications table if it doesn't exist
const createTableSQL = `
  CREATE TABLE IF NOT EXISTS notifications (
    id TEXT PRIMARY KEY,
    event_type TEXT,
    invoice_id TEXT,
    payload JSONB,
    meta JSONB,
    received_at TIMESTAMPTZ,
    source_topic TEXT
  );
`;

// Retry connection with exponential backoff
async function connectWithRetry(maxAttempts = 5) {
  let attempt = 1;
  let delay = 1000;

  while (attempt <= maxAttempts) {
    try {
      console.log(`[notification-service] DB connection attempt ${attempt}/${maxAttempts}`);
      
      if (!pool) {
        pool = new Pool(config);
      }

      // Test connection
      const client = await pool.connect();
      await client.query('SELECT NOW()');
      client.release();
      
      isConnected = true;
      console.log(`[notification-service] DB connected successfully to ${config.host}:${config.port}/${config.database}`);
      return true;
    } catch (error) {
      console.error(`[notification-service] DB connection attempt ${attempt} failed:`, error.message);
      
      if (attempt === maxAttempts) {
        console.error(`[notification-service] Failed to connect to DB after ${maxAttempts} attempts`);
        isConnected = false;
        return false;
      }
      
      // Exponential backoff
      console.log(`[notification-service] Retrying in ${delay}ms...`);
      await new Promise(resolve => setTimeout(resolve, delay));
      delay *= 2;
      attempt++;
    }
  }
  
  return false;
}

// Initialize database connection and create table
async function init() {
  console.log('[notification-service] Initializing database...');
  
  const connected = await connectWithRetry();
  if (!connected) {
    console.warn('[notification-service] Database initialization failed - will fallback to in-memory mode');
    return false;
  }

  try {
    // Create table if it doesn't exist
    await pool.query(createTableSQL);
    console.log('[notification-service] Notifications table ready');
    return true;
  } catch (error) {
    console.error('[notification-service] Failed to create notifications table:', error.message);
    isConnected = false;
    return false;
  }
}

// Save notification to database
async function saveNotification(notification) {
  if (!isConnected || !pool) {
    throw new Error('Database not connected');
  }

  const {
    id,
    eventType,
    invoiceId,
    payload,
    meta,
    receivedAt,
    sourceTopic
  } = notification;

  const insertSQL = `
    INSERT INTO notifications (id, event_type, invoice_id, payload, meta, received_at, source_topic)
    VALUES ($1, $2, $3, $4, $5, $6, $7)
    ON CONFLICT (id) DO UPDATE SET
      event_type = EXCLUDED.event_type,
      invoice_id = EXCLUDED.invoice_id,
      payload = EXCLUDED.payload,
      meta = EXCLUDED.meta,
      received_at = EXCLUDED.received_at,
      source_topic = EXCLUDED.source_topic;
  `;

  try {
    // Ensure payload and meta are proper JSON objects or null
    const payloadJson = payload && typeof payload === 'object' ? payload : (payload ? { data: payload } : null);
    const metaJson = meta && typeof meta === 'object' ? meta : null;
    
    await pool.query(insertSQL, [
      id,
      eventType,
      invoiceId,
      payloadJson,
      metaJson,
      receivedAt,
      sourceTopic
    ]);
    
    console.log(`[notification-service] saved notification id=${id} type=${eventType}`);
  } catch (error) {
    console.error(`[notification-service] db save failed id=${id} error=${error.message}`);
    throw error;
  }
}

// Get recent notifications from database
async function getRecentNotifications(limit = 50) {
  if (!isConnected || !pool) {
    throw new Error('Database not connected');
  }

  const selectSQL = `
    SELECT id, event_type as "eventType", invoice_id as "invoiceId", 
           payload, meta, received_at as "receivedAt", source_topic as "sourceTopic"
    FROM notifications
    ORDER BY received_at DESC
    LIMIT $1;
  `;

  try {
    const result = await pool.query(selectSQL, [limit]);
    return result.rows;
  } catch (error) {
    console.error('[notification-service] Failed to fetch notifications from DB:', error.message);
    throw error;
  }
}

// Check if database is connected
function isDbConnected() {
  return isConnected;
}

// Gracefully close database connection
async function close() {
  if (pool) {
    await pool.end();
    pool = null;
    isConnected = false;
    console.log('[notification-service] Database connection closed');
  }
}

module.exports = {
  init,
  saveNotification,
  getRecentNotifications,
  isDbConnected,
  close
};