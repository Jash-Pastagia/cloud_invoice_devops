-- analytics-service/schema.sql
-- Database schema for analytics events storage
-- This schema creates a dedicated analytics namespace with optimized event storage

-- Create analytics schema
CREATE SCHEMA IF NOT EXISTS analytics;

-- Create events table for storing all analytics events
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

-- Indexes to support quick aggregation queries
CREATE INDEX IF NOT EXISTS idx_events_event_type_ts ON analytics.events(event_type, event_ts DESC);
CREATE INDEX IF NOT EXISTS idx_events_received_at ON analytics.events(received_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_source ON analytics.events(source) WHERE source IS NOT NULL;

-- Additional performance indexes for common queries
CREATE INDEX IF NOT EXISTS idx_events_event_ts_desc ON analytics.events(event_ts DESC);
CREATE INDEX IF NOT EXISTS idx_events_type_received ON analytics.events(event_type, received_at DESC);

-- Comments for documentation
COMMENT ON SCHEMA analytics IS 'Analytics data storage for event tracking and metrics';
COMMENT ON TABLE analytics.events IS 'Stores all consumed events from Kafka for analytics and metrics generation';
COMMENT ON COLUMN analytics.events.id IS 'Unique event identifier, preferably trace_id from event metadata';
COMMENT ON COLUMN analytics.events.event_type IS 'Type of event (e.g., invoice.created, payment.processed)';
COMMENT ON COLUMN analytics.events.event_ts IS 'Original timestamp of the event';
COMMENT ON COLUMN analytics.events.payload IS 'Event payload data as JSONB for flexible querying';
COMMENT ON COLUMN analytics.events.meta IS 'Event metadata as JSONB';
COMMENT ON COLUMN analytics.events.source IS 'Source service that generated the event';
COMMENT ON COLUMN analytics.events.received_at IS 'Timestamp when event was received by analytics service';
COMMENT ON COLUMN analytics.events.raw IS 'Raw message string for debugging purposes';