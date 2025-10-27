const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'invoicedb',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Test connection
pool.on('connect', () => {
  console.log('✅ Auth Service: Connected to PostgreSQL database');
});

pool.on('error', (err) => {
  console.error('❌ Auth Service: Database connection error:', err);
});

async function init() {
  try {
    // Ensure users table exists (migrations should have created it)
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        username VARCHAR(50) UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        full_name VARCHAR(100),
        email VARCHAR(100),
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      )
    `);
    
    console.log('✅ Auth Service: Database tables verified');
  } catch (error) {
    console.error('❌ Auth Service: Database initialization error:', error);
    throw error;
  }
}

async function createUser({ username, password, fullName, email }) {
  const client = await pool.connect();
  try {
    // Store plain text password for simplicity
    const passwordHash = password;
    
    const result = await client.query(
      'INSERT INTO users (username, password_hash, full_name, email) VALUES ($1, $2, $3, $4) RETURNING id, username, full_name, email, created_at',
      [username, passwordHash, fullName, email]
    );
    
    return result.rows[0];
  } catch (error) {
    if (error.code === '23505') { // Unique violation
      throw new Error('Username already exists');
    }
    throw error;
  } finally {
    client.release();
  }
}

async function getUserByUsername(username) {
  const client = await pool.connect();
  try {
    const result = await client.query(
      'SELECT id, username, password_hash, full_name, email, created_at FROM users WHERE username = $1',
      [username]
    );
    
    return result.rows[0];
  } finally {
    client.release();
  }
}

async function getUserById(userId) {
  const client = await pool.connect();
  try {
    const result = await client.query(
      'SELECT id, username, full_name, email, created_at FROM users WHERE id = $1',
      [userId]
    );
    
    return result.rows[0];
  } finally {
    client.release();
  }
}

async function verifyPassword(plainPassword, hashedPassword) {
  // Simple plain text comparison
  return plainPassword === hashedPassword;
}

module.exports = {
  init,
  createUser,
  getUserByUsername,
  getUserById,
  verifyPassword,
  pool
};