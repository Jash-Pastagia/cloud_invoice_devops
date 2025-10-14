#!/usr/bin/env node

/**
 * Demo Data Generator for Invoice Management System
 * Creates comprehensive test data including users, invoices, and analytics
 */

const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'invoicedb',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
});

// Demo data configurations
const DEMO_USERS = [
  { username: 'alice', password: 'alice123', fullName: 'Alice Johnson', email: 'alice@company.com' },
  { username: 'bob', password: 'bob123', fullName: 'Bob Smith', email: 'bob@startup.io' },
  { username: 'carol', password: 'carol123', fullName: 'Carol Davis', email: 'carol@freelance.com' },
  { username: 'david', password: 'david123', fullName: 'David Wilson', email: 'david@agency.net' }
];

const DEMO_CUSTOMERS = [
  'Acme Corporation', 'Tech Startup Inc', 'Global Solutions Ltd', 'Creative Agency',
  'Digital Marketing Co', 'E-commerce Platform', 'Mobile App Company', 'SaaS Provider',
  'Consulting Firm', 'Design Studio', 'Development House', 'Analytics Company'
];

const DEMO_SERVICES = [
  { name: 'Web Development', desc: 'Full-stack web application development', basePrice: 150 },
  { name: 'UI/UX Design', desc: 'User interface and experience design', basePrice: 120 },
  { name: 'Mobile App Development', desc: 'Native and cross-platform mobile apps', basePrice: 160 },
  { name: 'Database Design', desc: 'Database architecture and optimization', basePrice: 140 },
  { name: 'API Development', desc: 'RESTful API design and implementation', basePrice: 130 },
  { name: 'DevOps Consulting', desc: 'Infrastructure and deployment optimization', basePrice: 180 },
  { name: 'Security Audit', desc: 'Application security assessment', basePrice: 200 },
  { name: 'Performance Optimization', desc: 'Application performance tuning', basePrice: 170 },
  { name: 'Code Review', desc: 'Comprehensive code quality review', basePrice: 100 },
  { name: 'Technical Documentation', desc: 'API and system documentation', basePrice: 80 },
  { name: 'QA Testing', desc: 'Quality assurance and testing services', basePrice: 90 },
  { name: 'Project Management', desc: 'Technical project management', basePrice: 110 }
];

function randomDate(start, end) {
  return new Date(start.getTime() + Math.random() * (end.getTime() - start.getTime()));
}

function randomChoice(array) {
  return array[Math.floor(Math.random() * array.length)];
}

function randomNumber(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

async function createDemoUsers() {
  console.log('🏗️  Creating demo users...');
  
  for (const userData of DEMO_USERS) {
    try {
      const result = await pool.query(
        'INSERT INTO users (username, password_hash, full_name, email) VALUES ($1, $2, $3, $4) ON CONFLICT (username) DO NOTHING RETURNING id',
        [userData.username, userData.password, userData.fullName, userData.email]
      );
      
      if (result.rows.length > 0) {
        console.log(`   ✅ Created user: ${userData.fullName} (@${userData.username})`);
      } else {
        console.log(`   ⚠️  User already exists: ${userData.username}`);
      }
    } catch (error) {
      console.error(`   ❌ Error creating user ${userData.username}:`, error.message);
    }
  }
}

async function getAllUsers() {
  const result = await pool.query('SELECT id, username, full_name FROM users ORDER BY created_at');
  return result.rows;
}

async function createDemoInvoices(users) {
  console.log('📋 Creating demo invoices...');
  
  const invoiceCount = 25; // Generate 25 demo invoices
  const startDate = new Date('2025-09-01');
  const endDate = new Date('2025-10-14');
  
  for (let i = 0; i < invoiceCount; i++) {
    try {
      const creator = randomChoice(users);
      const assignee = randomChoice(users);
      const customer = randomChoice(DEMO_CUSTOMERS);
      const createdDate = randomDate(startDate, endDate);
      const dueDate = new Date(createdDate.getTime() + (randomNumber(7, 30) * 24 * 60 * 60 * 1000));
      
      // Generate 1-4 items per invoice
      const itemCount = randomNumber(1, 4);
      const items = [];
      let totalAmount = 0;
      
      for (let j = 0; j < itemCount; j++) {
        const service = randomChoice(DEMO_SERVICES);
        const qty = randomNumber(1, 5);
        const price = service.basePrice + randomNumber(-30, 50); // Add some price variation
        
        items.push({
          desc: `${service.name} - ${service.desc}`,
          qty: qty,
          price: price
        });
        
        totalAmount += qty * price;
      }
      
      // Random status with weighted distribution
      const statusRand = Math.random();
      let status = 'pending';
      let paidAt = null;
      let paidBy = null;
      
      if (statusRand < 0.6) { // 60% paid
        status = 'paid';
        paidAt = randomDate(createdDate, new Date());
        paidBy = assignee.id;
      } else if (statusRand < 0.8) { // 20% pending
        status = 'pending';
      } else { // 20% overdue
        status = 'overdue';
      }
      
      const result = await pool.query(`
        INSERT INTO invoices (
          creator_id, assignee_id, customer, items, total_amount, 
          due_date, status, created_at, updated_at, paid_at, paid_by
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $8, $9, $10)
        RETURNING id
      `, [
        creator.id, assignee.id, JSON.stringify({ name: customer }), 
        JSON.stringify(items), totalAmount, dueDate, status, 
        createdDate, paidAt, paidBy
      ]);
      
      console.log(`   ✅ Created invoice ${i + 1}/${invoiceCount}: $${totalAmount.toFixed(2)} (${status}) - ${customer}`);
      
      // Create analytics events for paid invoices
      if (status === 'paid') {
        await createAnalyticsEvents(result.rows[0].id, creator.id, assignee.id, totalAmount, createdDate, paidAt);
      }
      
    } catch (error) {
      console.error(`   ❌ Error creating invoice ${i + 1}:`, error.message);
    }
  }
}

async function createAnalyticsEvents(invoiceId, creatorId, assigneeId, amount, createdAt, paidAt) {
  const events = [
    {
      event_type: 'invoice.created',
      user_id: creatorId,
      invoice_id: invoiceId,
      event_data: { amount: amount, customer_type: 'business' },
      created_at: createdAt
    },
    {
      event_type: 'payment.initiated',
      user_id: assigneeId,
      invoice_id: invoiceId,
      event_data: { amount: amount, payment_method: 'credit_card' },
      created_at: paidAt
    },
    {
      event_type: 'payment.processed',
      user_id: assigneeId,
      invoice_id: invoiceId,
      event_data: { amount: amount, transaction_id: `txn_${Math.random().toString(36).substr(2, 9)}` },
      created_at: paidAt
    },
    {
      event_type: 'invoice.paid',
      user_id: assigneeId,
      invoice_id: invoiceId,
      event_data: { amount: amount, payment_date: paidAt },
      created_at: paidAt
    }
  ];
  
  for (const event of events) {
    try {
      await pool.query(`
        INSERT INTO analytics_events (event_type, user_id, invoice_id, data, occurred_at)
        VALUES ($1, $2, $3, $4, $5)
      `, [event.event_type, event.user_id, event.invoice_id, JSON.stringify(event.event_data), event.created_at]);
    } catch (error) {
      console.error(`      ❌ Error creating analytics event:`, error.message);
    }
  }
}

async function createDemoNotifications(users) {
  console.log('🔔 Creating demo notifications...');
  
  const notificationTypes = [
    { type: 'invoice.created', message: 'New invoice created and assigned to you' },
    { type: 'invoice.paid', message: 'Invoice payment received successfully' },
    { type: 'payment.processed', message: 'Payment has been processed' },
    { type: 'invoice.overdue', message: 'Invoice is now overdue' },
    { type: 'payment.failed', message: 'Payment processing failed, please retry' },
    { type: 'user.login', message: 'Successful login to your account' },
    { type: 'invoice.viewed', message: 'Your invoice was viewed by the client' },
    { type: 'system.maintenance', message: 'Scheduled system maintenance completed' }
  ];
  
  // Create 30 notifications with various timestamps
  for (let i = 0; i < 30; i++) {
    try {
      const user = randomChoice(users);
      const notification = randomChoice(notificationTypes);
      const createdAt = randomDate(new Date('2025-10-01'), new Date());
      
      await pool.query(`
        INSERT INTO notifications (user_id, type, title, message, data, received_at)
        VALUES ($1, $2, $3, $4, $5, $6)
      `, [
        user.id, 
        notification.type,
        `${notification.type.replace('.', ' ').toUpperCase()}`,
        notification.message,
        JSON.stringify({ 
          priority: randomChoice(['low', 'medium', 'high']),
          category: randomChoice(['invoice', 'payment', 'system']),
          amount: Math.floor(Math.random() * 5000) + 100
        }),
        createdAt
      ]);
      
    } catch (error) {
      console.error(`   ❌ Error creating notification ${i + 1}:`, error.message);
    }
  }
  
  console.log(`   ✅ Created 30 demo notifications`);
}

async function generateSummaryReport() {
  console.log('\n📊 DEMO DATA SUMMARY');
  console.log('=' .repeat(50));
  
  try {
    // Users summary
    const usersResult = await pool.query('SELECT COUNT(*) as count FROM users');
    console.log(`👥 Users: ${usersResult.rows[0].count}`);
    
    // Invoices summary
    const invoicesResult = await pool.query(`
      SELECT 
        COUNT(*) as total,
        COUNT(CASE WHEN status = 'paid' THEN 1 END) as paid,
        COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending,
        COUNT(CASE WHEN status = 'overdue' THEN 1 END) as overdue,
        SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END) as revenue
      FROM invoices
    `);
    
    const invoiceStats = invoicesResult.rows[0];
    console.log(`📋 Invoices: ${invoiceStats.total} total`);
    console.log(`   ✅ Paid: ${invoiceStats.paid}`);
    console.log(`   ⏳ Pending: ${invoiceStats.pending}`);
    console.log(`   ⚠️  Overdue: ${invoiceStats.overdue}`);
    console.log(`   💰 Revenue: $${parseFloat(invoiceStats.revenue || 0).toFixed(2)}`);
    
    // Analytics summary
    const analyticsResult = await pool.query('SELECT COUNT(*) as count FROM analytics_events');
    console.log(`📈 Analytics Events: ${analyticsResult.rows[0].count}`);
    
    // Notifications summary
    const notificationsResult = await pool.query('SELECT COUNT(*) as count FROM notifications');
    console.log(`🔔 Notifications: ${notificationsResult.rows[0].count}`);
    
    console.log('\n🎉 Demo data creation completed successfully!');
    console.log('🌐 Visit http://localhost:3000 to explore the demo');
    console.log('📊 Analytics: http://localhost:7100');
    console.log('🔧 Kafka UI: http://localhost:8080');
    
  } catch (error) {
    console.error('❌ Error generating summary:', error.message);
  }
}

async function main() {
  console.log('🚀 Starting Demo Data Generation');
  console.log('================================\n');
  
  try {
    // Test database connection
    await pool.query('SELECT NOW()');
    console.log('✅ Database connection successful\n');
    
    // Create demo data
    await createDemoUsers();
    
    const users = await getAllUsers();
    console.log(`📋 Found ${users.length} users for invoice generation\n`);
    
    await createDemoInvoices(users);
    await createDemoNotifications(users);
    
    await generateSummaryReport();
    
  } catch (error) {
    console.error('❌ Fatal error:', error.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

// Handle graceful shutdown
process.on('SIGINT', async () => {
  console.log('\n⏹️  Shutting down gracefully...');
  await pool.end();
  process.exit(0);
});

// Run the script
main().catch(console.error);