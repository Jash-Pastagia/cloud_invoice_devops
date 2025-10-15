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
  console.log('✅ Invoice Service: Connected to PostgreSQL database');
});

pool.on('error', (err) => {
  console.error('❌ Invoice Service: Database connection error:', err);
});

async function init() {
  try {
    // Ensure tables exist (migrations should have created them)
    await pool.query(`
      CREATE TABLE IF NOT EXISTS invoices (
        id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
        creator_id TEXT NOT NULL,
        assignee_id TEXT NOT NULL,
        customer JSONB NOT NULL,
        items JSONB NOT NULL,
        total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
        due_date DATE NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'overdue', 'cancelled')),
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW(),
        paid_at TIMESTAMPTZ NULL,
        paid_by TEXT NULL
      )
    `);
    
    console.log('✅ Invoice Service: Database tables verified');
  } catch (error) {
    console.error('❌ Invoice Service: Database initialization error:', error);
    throw error;
  }
}

function calculateTotalAmount(items) {
  return items.reduce((total, item) => {
    const itemTotal = (parseFloat(item.qty) || 0) * (parseFloat(item.price) || 0);
    return total + itemTotal;
  }, 0);
}

async function createInvoice({ creatorId, assigneeId, customer, items, dueDate }) {
  const client = await pool.connect();
  try {
    // Validate and calculate total
    const totalAmount = calculateTotalAmount(items);
    
    const result = await client.query(`
      INSERT INTO invoices (creator_id, assignee_id, customer, items, total_amount, due_date, status)
      VALUES ($1, $2, $3, $4, $5, $6, 'pending')
      RETURNING *
    `, [creatorId, assigneeId, JSON.stringify(customer), JSON.stringify(items), totalAmount, dueDate]);
    
    return result.rows[0];
  } finally {
    client.release();
  }
}

async function getInvoicesByCreator(creatorId, limit = 100, offset = 0) {
  const client = await pool.connect();
  try {
    const result = await client.query(`
      SELECT * FROM invoices 
      WHERE creator_id = $1 
      ORDER BY created_at DESC 
      LIMIT $2 OFFSET $3
    `, [creatorId, limit, offset]);
    
    return result.rows;
  } finally {
    client.release();
  }
}

async function getInvoicesAssignedTo(userId, limit = 100, offset = 0) {
  const client = await pool.connect();
  try {
    const result = await client.query(`
      SELECT * FROM invoices 
      WHERE assignee_id = $1 
      ORDER BY created_at DESC 
      LIMIT $2 OFFSET $3
    `, [userId, limit, offset]);
    
    return result.rows;
  } finally {
    client.release();
  }
}

async function getAllInvoicesForUser(userId, limit = 100, offset = 0) {
  const client = await pool.connect();
  try {
    const result = await client.query(`
      SELECT * FROM invoices 
      WHERE creator_id = $1 OR assignee_id = $1 
      ORDER BY created_at DESC 
      LIMIT $2 OFFSET $3
    `, [userId, limit, offset]);
    
    return result.rows;
  } finally {
    client.release();
  }
}

async function getInvoiceById(id) {
  const client = await pool.connect();
  try {
    const result = await client.query('SELECT * FROM invoices WHERE id = $1', [id]);
    return result.rows[0];
  } finally {
    client.release();
  }
}

async function markPaid(id, paidBy) {
  const client = await pool.connect();
  try {
    const result = await client.query(`
      UPDATE invoices 
      SET status = 'paid', paid_at = NOW(), paid_by = $2, updated_at = NOW() 
      WHERE id = $1 
      RETURNING *
    `, [id, paidBy]);
    
    return result.rows[0];
  } finally {
    client.release();
  }
}

async function updateInvoiceStatus(id, status) {
  const client = await pool.connect();
  try {
    const result = await client.query(`
      UPDATE invoices 
      SET status = $2, updated_at = NOW() 
      WHERE id = $1 
      RETURNING *
    `, [id, status]);
    
    return result.rows[0];
  } finally {
    client.release();
  }
}

async function getInvoiceStats(userId) {
  const client = await pool.connect();
  try {
    const result = await client.query(`
      SELECT 
        COUNT(*) as total_invoices,
        COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_invoices,
        COUNT(CASE WHEN status = 'paid' THEN 1 END) as paid_invoices,
        COALESCE(SUM(CASE WHEN status = 'pending' THEN total_amount END), 0) as pending_amount,
        COALESCE(SUM(CASE WHEN status = 'paid' THEN total_amount END), 0) as paid_amount
      FROM invoices 
      WHERE creator_id = $1 OR assignee_id = $1
    `, [userId]);
    
    return result.rows[0];
  } finally {
    client.release();
  }
}

module.exports = {
  init,
  createInvoice,
  getInvoicesByCreator,
  getInvoicesAssignedTo,
  getAllInvoicesForUser,
  getInvoiceById,
  markPaid,
  updateInvoiceStatus,
  getInvoiceStats,
  calculateTotalAmount,
  // check if a user exists (used to validate assignee/creator IDs before inserts)
  userExists: async function(userId) {
    const client = await pool.connect();
    try {
      const result = await client.query('SELECT 1 FROM users WHERE id = $1 LIMIT 1', [userId]);
      return result.rowCount > 0;
    } finally {
      client.release();
    }
  },
  pool
};