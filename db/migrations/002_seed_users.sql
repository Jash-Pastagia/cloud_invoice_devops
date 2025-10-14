-- Migration: Seed demo users
-- Note: This script creates users with placeholder passwords
-- Run the Node.js seed script (scripts/seed_users.js) to create users with properly hashed passwords

-- This SQL is provided for reference, but use the Node.js script for actual seeding
-- The Node.js script will use bcrypt to hash passwords properly

-- Demo users to be created by scripts/seed_users.js:
-- 1. Username: demo, Password: demo123, Full Name: Demo User
-- 2. Username: user2, Password: user2123, Full Name: User Two

-- If you need to manually create users with plain passwords (NOT RECOMMENDED for production):
-- INSERT INTO users (id, username, password_hash, full_name, email) VALUES 
-- ('demo-user-id', 'demo', 'REPLACE_WITH_BCRYPT_HASH', 'Demo User', 'demo@example.com'),
-- ('user2-user-id', 'user2', 'REPLACE_WITH_BCRYPT_HASH', 'User Two', 'user2@example.com')
-- ON CONFLICT (username) DO NOTHING;

-- For development only - NEVER use plain passwords in production
-- This is commented out intentionally - use the Node.js seed script instead
/*
INSERT INTO users (id, username, password_hash, full_name, email) VALUES 
('demo-user-id', 'demo', 'demo123', 'Demo User', 'demo@example.com'),
('user2-user-id', 'user2', 'user2123', 'User Two', 'user2@example.com')
ON CONFLICT (username) DO NOTHING;
*/