// analytics-service/db.js
// Postgres persistence for analytics events
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

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

// Retry connection with exponential backoff
async function connectWithRetry(maxAttempts = 5) {
  let attempt = 1;
  let delay = 1000;

  while (attempt <= maxAttempts) {
    try {
      console.log(`[analytics-service] DB connection attempt ${attempt}/${maxAttempts}`);
      
      if (!pool) {
        pool = new Pool(config);
      }

      // Test connection
      const client = await pool.connect();
      await client.query('SELECT NOW()');
      client.release();
      
      isConnected = true;
      console.log(`[analytics-service] DB connected successfully to ${config.host}:${config.port}/${config.database}`);
      return true;
    } catch (error) {
      console.error(`[analytics-service] DB connection attempt ${attempt} failed:`, error.message);
      
      if (attempt === maxAttempts) {
        console.error(`[analytics-service] Failed to connect to DB after ${maxAttempts} attempts`);
        isConnected = false;
        return false;
      }
      
      // Exponential backoff
      console.log(`[analytics-service] Retrying in ${delay}ms...`);
      await new Promise(resolve => setTimeout(resolve, delay));
      delay *= 2;
      attempt++;
    }
  }
  
  return false;
}

// Initialize database connection and create schema/tables
async function init() {
  console.log('[analytics-service] Initializing database...');
  
  const connected = await connectWithRetry();
  if (!connected) {
    console.error('[analytics-service] Database initialization failed');
    return false;
  }

  try {
    // Create analytics schema
    await pool.query('CREATE SCHEMA IF NOT EXISTS analytics');
    console.log('[analytics-service] Analytics schema ready');

    // Execute table creation directly with better error handling
    try {
      const createTableResult = await pool.query(`
        CREATE TABLE IF NOT EXISTS analytics.events (
          id TEXT PRIMARY KEY,
          event_type TEXT NOT NULL,
          event_ts TIMESTAMPTZ NOT NULL,
          payload JSONB,
          meta JSONB,
          source TEXT,
          received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
          raw TEXT
        );
      `);
      console.log('[analytics-service] Events table creation executed successfully');
      
      // Verify table exists
      const verifyResult = await pool.query(`
        SELECT EXISTS (
          SELECT FROM information_schema.tables 
          WHERE table_schema = 'analytics' 
          AND table_name = 'events'
        );
      `);
      
      if (verifyResult.rows[0].exists) {
        console.log('[analytics-service] Events table verified to exist');
      } else {
        throw new Error('Events table was not created properly');
      }
      
    } catch (tableError) {
      console.error('[analytics-service] Table creation failed:', tableError.message);
      console.error('[analytics-service] Full error:', tableError);
      throw tableError;
    }
    
    // Create indexes
    try {
      await pool.query(`CREATE INDEX IF NOT EXISTS idx_events_event_type_ts ON analytics.events(event_type, event_ts DESC);`);
      await pool.query(`CREATE INDEX IF NOT EXISTS idx_events_received_at ON analytics.events(received_at DESC);`);
      await pool.query(`CREATE INDEX IF NOT EXISTS idx_events_source ON analytics.events(source) WHERE source IS NOT NULL;`);
      await pool.query(`CREATE INDEX IF NOT EXISTS idx_events_event_ts_desc ON analytics.events(event_ts DESC);`);
      await pool.query(`CREATE INDEX IF NOT EXISTS idx_events_type_received ON analytics.events(event_type, received_at DESC);`);
      console.log('[analytics-service] All database indexes created successfully');
    } catch (indexError) {
      console.warn('[analytics-service] Index creation warning:', indexError.message);
      // Continue - indexes are not critical
    }
    
    console.log('[analytics-service] Analytics tables and indexes ready');
    return true;
  } catch (error) {
    console.error('[analytics-service] Failed to initialize database schema:', error.message);
    console.error('[analytics-service] Full schema error:', error);
    isConnected = false;
    return false;
  }
}

// Insert analytics event into database
async function insertEvent(evt) {
  if (!isConnected || !pool) {
    throw new Error('Database not connected');
  }

  const {
    id,
    event_type,
    event_ts,
    payload,
    meta,
    source,
    raw
  } = evt;

  const insertSQL = `
    INSERT INTO analytics.events (id, event_type, event_ts, payload, meta, source, raw)
    VALUES ($1, $2, $3, $4, $5, $6, $7)
    ON CONFLICT (id) DO UPDATE SET
      event_type = EXCLUDED.event_type,
      event_ts = EXCLUDED.event_ts,
      payload = EXCLUDED.payload,
      meta = EXCLUDED.meta,
      source = EXCLUDED.source,
      raw = EXCLUDED.raw,
      received_at = now();
  `;

  const values = [
    id,
    event_type,
    event_ts,
    payload,
    meta,
    source,
    raw
  ];

  try {
    await pool.query(insertSQL, values);
    console.log(`[analytics-service] inserted event id=${id} type=${event_type}`);
  } catch (error) {
    console.error(`[analytics-service] db insert failed id=${id} error=${error.message}`);
    throw error;
  }
}

// Get recent events from database
async function getRecentEvents(limit = 100) {
  if (!isConnected || !pool) {
    throw new Error('Database not connected');
  }

  const selectSQL = `
    SELECT id, event_type, event_ts, payload, meta, source, received_at, raw
    FROM analytics.events
    ORDER BY received_at DESC
    LIMIT $1;
  `;

  try {
    const result = await pool.query(selectSQL, [Math.min(limit, 1000)]);
    return result.rows;
  } catch (error) {
    console.error('[analytics-service] Failed to fetch recent events:', error.message);
    throw error;
  }
}

// Get count of events within time window for specific event type
async function aggregateCountsWithinWindow(eventType, windowSeconds) {
  if (!isConnected || !pool) {
    throw new Error('Database not connected');
  }

  const countSQL = `
    SELECT count(*) as count
    FROM analytics.events
    WHERE event_type = $1 
    AND event_ts >= now() - interval '${windowSeconds} seconds';
  `;

  try {
    const result = await pool.query(countSQL, [eventType]);
    return parseInt(result.rows[0].count, 10);
  } catch (error) {
    console.error(`[analytics-service] Failed to aggregate counts for ${eventType}:`, error.message);
    throw error;
  }
}

// Get counts by event type within time window
async function countsByTypeWindow(seconds) {
  if (!isConnected || !pool) {
    throw new Error('Database not connected');
  }

  const countsSQL = `
    SELECT event_type, count(*) as count
    FROM analytics.events
    WHERE event_ts >= now() - interval '${seconds} seconds'
    GROUP BY event_type
    ORDER BY count DESC;
  `;

  try {
    const result = await pool.query(countsSQL);
    const counts = {};
    result.rows.forEach(row => {
      counts[row.event_type] = parseInt(row.count, 10);
    });
    return counts;
  } catch (error) {
    console.error(`[analytics-service] Failed to get counts by type:`, error.message);
    throw error;
  }
}

// Get latest event timestamp
async function getLatestEventTime() {
  if (!isConnected || !pool) {
    throw new Error('Database not connected');
  }

  const latestSQL = `
    SELECT event_ts
    FROM analytics.events
    ORDER BY event_ts DESC
    LIMIT 1;
  `;

  try {
    const result = await pool.query(latestSQL);
    return result.rows.length > 0 ? result.rows[0].event_ts : null;
  } catch (error) {
    console.error('[analytics-service] Failed to get latest event time:', error.message);
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
    console.log('[analytics-service] Database connection closed');
  }
}

module.exports = {
  init,
  insertEvent,
  getRecentEvents,
  aggregateCountsWithinWindow,
  countsByTypeWindow,
  getLatestEventTime,
  isDbConnected,
  close
};