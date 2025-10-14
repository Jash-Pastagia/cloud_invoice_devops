# Cloud Invoice DevOps - User Seeding Script

This script creates demo users in the PostgreSQL database with properly hashed passwords using bcrypt.

## Prerequisites

1. PostgreSQL database running (via Docker Compose or local installation)
2. Node.js installed
3. Database accessible with the configured credentials

## Usage

### Method 1: Direct execution (recommended)

```bash
# Navigate to the scripts directory
cd scripts

# Install dependencies
npm install

# Run the seeding script
npm run seed-users
```

### Method 2: With environment variables

```bash
# Set custom database connection (optional)
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=invoicedb
export DB_USER=postgres
export DB_PASSWORD=postgres

# Run the script
node seed_users.js
```

### Method 3: Using Docker Compose services

```bash
# From the project root, ensure services are running
docker compose up -d postgres

# Wait a few seconds for postgres to be ready, then run seeding
cd scripts
npm install
npm run seed-users
```

## Created Users

The script creates the following demo users:

| Username | Password | Full Name | Email | User ID |
|----------|----------|-----------|-------|---------|
| `demo` | `demo123` | Demo User | demo@example.com | demo-user-id |
| `user2` | `user2123` | User Two | user2@example.com | user2-user-id |

## What the Script Does

1. **Connects to PostgreSQL**: Uses the configured database connection
2. **Creates Users Table**: Ensures the users table exists with proper schema
3. **Clears Demo Users**: Removes existing demo users (if any) to prevent conflicts
4. **Hashes Passwords**: Uses bcrypt with 12 salt rounds for secure password storage
5. **Creates Users**: Inserts the demo users with proper IDs for consistent referencing
6. **Verifies Creation**: Checks that users were created successfully

## Password Security

- Passwords are hashed using bcrypt with 12 salt rounds
- Plain text passwords are never stored in the database
- Each password hash is unique even for identical passwords

## Database Schema

The users table has the following structure:

```sql
CREATE TABLE users (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  username VARCHAR(50) UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  full_name VARCHAR(100),
  email VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Troubleshooting

### Connection Issues

If you get connection errors:

1. Ensure PostgreSQL is running
2. Check your environment variables match your database configuration
3. Verify the database `invoicedb` exists
4. Check firewall settings if using remote database

### Permission Issues

If you get permission errors:

1. Ensure the database user has CREATE and INSERT permissions
2. Check that the database user can connect to the specified database

### Existing User Conflicts

The script handles existing users by updating them with new password hashes. If you want to preserve existing users, comment out the DELETE statement in the script.

## Integration with Main Application

After running this script:

1. Start your application services (auth-service, invoice-service, etc.)
2. Navigate to the frontend at http://localhost:3000
3. Use the demo credentials to log in:
   - Username: `demo`, Password: `demo123`
   - Username: `user2`, Password: `user2123`

## Security Notes

⚠️ **Important**: These are demo credentials for development only. In production:

1. Use strong, unique passwords
2. Enable additional authentication measures
3. Consider multi-factor authentication
4. Regularly rotate passwords
5. Monitor access logs