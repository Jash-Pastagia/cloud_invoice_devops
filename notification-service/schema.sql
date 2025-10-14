-- notification-service/schema.sql
-- Database schema for notifications table
-- This table stores all notification events consumed from Kafka

CREATE TABLE IF NOT EXISTS notifications (
  id TEXT PRIMARY KEY,
  event_type TEXT,
  invoice_id TEXT,
  payload JSONB,
  meta JSONB,
  received_at TIMESTAMPTZ,
  source_topic TEXT
);

-- Optional indexes for better query performance
-- CREATE INDEX IF NOT EXISTS idx_notifications_received_at ON notifications (received_at DESC);
-- CREATE INDEX IF NOT EXISTS idx_notifications_event_type ON notifications (event_type);
-- CREATE INDEX IF NOT EXISTS idx_notifications_invoice_id ON notifications (invoice_id) WHERE invoice_id IS NOT NULL;

-- Migration notes:
-- This CREATE TABLE IF NOT EXISTS statement is safe to run on startup.
-- If the table already exists, it will not be modified.
-- If you need to add columns or modify the schema in the future, 
-- you should use ALTER TABLE statements instead.