// scripts/create-topics.js
// Usage:
//   KAFKA_BROKERS=localhost:29092 node scripts/create-topics.js

const { Kafka } = require('kafkajs');

const BROKERS = (process.env.KAFKA_BROKERS || 'localhost:29092').split(',');
const CLIENT_ID = process.env.KAFKA_ADMIN_CLIENT_ID || 'cloud-invoice-admin';
const RETRY_ATTEMPTS = Number(process.env.KAFKA_ADMIN_RETRIES || 12); // retry up to ~60s
const RETRY_DELAY_MS = Number(process.env.KAFKA_ADMIN_RETRY_DELAY_MS || 5000);

// topics to ensure exist
const TOPICS = [
  'invoice.created',
  'invoice.updated',
  'invoice.paid',
  'payment.initiated',
  'payment.processed',
  'user.logged_in',
  'notification.sent',
  'test.events'
];

const kafka = new Kafka({ clientId: CLIENT_ID, brokers: BROKERS });

async function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function connectAdminWithRetry(admin) {
  for (let attempt = 1; attempt <= RETRY_ATTEMPTS; attempt++) {
    try {
      console.log(`Attempt ${attempt} to connect to Kafka brokers [${BROKERS.join(',')}]...`);
      await admin.connect();
      console.log('Kafka admin connected.');
      return;
    } catch (err) {
      console.warn(`Kafka admin connect attempt ${attempt} failed: ${err.message || err}. Retrying in ${RETRY_DELAY_MS}ms`);
      if (attempt === RETRY_ATTEMPTS) throw err;
      await wait(RETRY_DELAY_MS);
    }
  }
}

async function topicExists(admin, topic) {
  try {
    const metadata = await admin.fetchTopicMetadata({ topics: [topic] });
    if (!metadata || !metadata.topics) return false;
    const t = metadata.topics.find((x) => x.name === topic);
    return !!(t && t.partitions && t.partitions.length > 0);
  } catch (err) {
    // sometimes fetchTopicMetadata throws if topic not found; treat as not existing
    return false;
  }
}

async function ensureTopics() {
  const admin = kafka.admin();
  try {
    await connectAdminWithRetry(admin);

    for (const topic of TOPICS) {
      const exists = await topicExists(admin, topic);
      if (exists) {
        console.log(`Topic exists: ${topic}`);
        continue;
      }

      console.log(`Creating topic: ${topic}`);
      const created = await admin.createTopics({
        topics: [{ topic, numPartitions: 1, replicationFactor: 1 }],
        waitForLeaders: true
      });

      if (created) {
        console.log(`Created topic: ${topic}`);
      } else {
        console.warn(`createTopics returned false for ${topic} (may already exist)`);
      }
    }
  } finally {
    try {
      await admin.disconnect();
    } catch (e) {
      // ignore
    }
  }
}

ensureTopics()
  .then(() => {
    console.log('All topics ensured.');
    process.exit(0);
  })
  .catch((err) => {
    console.error('Failed to ensure topics:', err);
    process.exit(2);
  });
