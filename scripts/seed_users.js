const { Pool } = require('pg');
const bcrypt = require('bcrypt');

// Database configuration
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'invoicedb',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
});

// Demo users to create
const demoUsers = [
  {
    id: 'demo-user-id',
    username: 'demo',
    password: 'demo123',
    fullName: 'Demo User',
    email: 'demo@example.com'
  },
  {
    id: 'user2-user-id',
    username: 'user2',
    password: 'user2123',
    fullName: 'User Two',
    email: 'user2@example.com'
  }
];

async function seedUsers() {
  const client = await pool.connect();
  
  try {
    console.log('🌱 Starting user seeding process...');
    
    // Check if users table exists and create if not
    await client.query(`
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
    
    console.log('✅ Users table ready');
    
    // Clear existing demo users (optional - comment out if you want to keep existing data)
    await client.query(
      'DELETE FROM users WHERE username IN ($1, $2)',
      ['demo', 'user2']
    );
    console.log('🗑️  Cleared existing demo users');
    
    // Create demo users
    for (const user of demoUsers) {
      console.log(`Creating user: ${user.username}...`);
      
      // Hash password with bcrypt
      const saltRounds = 12;
      const passwordHash = await bcrypt.hash(user.password, saltRounds);
      
      const result = await client.query(`
        INSERT INTO users (id, username, password_hash, full_name, email)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (username) DO UPDATE SET
          password_hash = EXCLUDED.password_hash,
          full_name = EXCLUDED.full_name,
          email = EXCLUDED.email,
          updated_at = NOW()
        RETURNING id, username, full_name, email, created_at
      `, [user.id, user.username, passwordHash, user.fullName, user.email]);
      
      const createdUser = result.rows[0];
      console.log(`✅ Created user: ${createdUser.username} (${createdUser.full_name})`);
      console.log(`   ID: ${createdUser.id}`);
      console.log(`   Email: ${createdUser.email}`);
      console.log(`   Created: ${createdUser.created_at}`);
      console.log('');
    }
    
    // Verify users were created
    const userCount = await client.query('SELECT COUNT(*) FROM users');
    console.log(`📊 Total users in database: ${userCount.rows[0].count}`);
    
    // List all users
    const allUsers = await client.query(
      'SELECT id, username, full_name, email, created_at FROM users ORDER BY created_at'
    );
    
    console.log('\n👥 All users in database:');
    allUsers.rows.forEach((user, index) => {
      console.log(`${index + 1}. ${user.username} (${user.full_name}) - ${user.email}`);
      console.log(`   ID: ${user.id}`);
    });
    
    console.log('\n🎉 User seeding completed successfully!');
    console.log('\n📝 Login credentials:');
    console.log('   Username: demo     | Password: demo123');
    console.log('   Username: user2    | Password: user2123');
    console.log('\n🔗 You can now use these credentials in the frontend at http://localhost:3000');
    
  } catch (error) {
    console.error('❌ Error seeding users:', error);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

// Run the seeding function
if (require.main === module) {
  seedUsers().catch(console.error);
}

module.exports = { seedUsers };