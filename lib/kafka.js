// lib/kafka.js
// Robust kafkajs wrapper for Node 24 + kafkajs v2.x
const { Kafka, logLevel, Partitioners } = require('kafkajs');

const DEFAULT_BROKERS = (process.env.KAFKA_BROKERS || 'kafka:9092').split(',');
const CLIENT_ID = process.env.KAFKA_CLIENT_ID || 'cloud-invoice';
const CONNECT_TIMEOUT = Number(process.env.KAFKA_CONNECT_TIMEOUT_MS || 30000);
const REQUEST_TIMEOUT = Number(process.env.KAFKA_REQUEST_TIMEOUT_MS || 30000);
const RETRY = {
  retries: 8,
  initialRetryTime: 300,
  factor: 2,
  multiplier: 1,
};

// Lazy initialization - create Kafka instance only when needed
let kafka = null;

function getKafkaInstance() {
  if (!kafka) {
    // Re-read environment variable at runtime for K8s secret updates
    const brokers = (process.env.KAFKA_BROKERS || 'kafka:9092').split(',');
    console.log(`[lib/kafka] Initializing Kafka with brokers: ${brokers.join(',')}`);
    
    kafka = new Kafka({
      clientId: CLIENT_ID,
      brokers: brokers,
      logLevel: logLevel.INFO,
      requestTimeout: REQUEST_TIMEOUT,
      retry: RETRY,
    });
  }
  return kafka;
}

async function waitForBroker(timeoutMs = CONNECT_TIMEOUT) {
  const start = Date.now();
  const kafka = getKafkaInstance();
  const admin = kafka.admin();
  try {
    await admin.connect();
    await admin.disconnect();
    return true;
  } catch (err) {
    // retry until timeout
    const retryDelay = 500;
    while (Date.now() - start < timeoutMs) {
      try {
        await new Promise(r => setTimeout(r, retryDelay));
        await admin.connect();
        await admin.disconnect();
        return true;
      } catch (e) {
        // continue retrying
      }
    }
    const brokers = (process.env.KAFKA_BROKERS || 'kafka:9092');
    throw new Error(`Kafka broker not reachable after ${timeoutMs}ms (brokers=${brokers}). Last error: ${err.message}`);
  }
}

async function createProducer(opts = {}) {
  const kafka = getKafkaInstance();
  // Use legacy partitioner to retain old behavior and silence warning (or set env KAFKAJS_NO_PARTITIONER_WARNING=1)
  const producer = kafka.producer({
    createPartitioner: opts.createPartitioner || Partitioners.LegacyPartitioner,
  });

  // Try to connect with retries
  const start = Date.now();
  const timeout = Number(opts.timeoutMs || CONNECT_TIMEOUT);
  while (Date.now() - start < timeout) {
    try {
      await producer.connect();
      return {
        send: async ({ topic, messages }) => {
          // messages: [{ key?, value }]
          return producer.send({ topic, messages });
        },
        disconnect: async () => producer.disconnect(),
        raw: producer,
      };
    } catch (err) {
      // wait and retry
      const wait = 500;
      await new Promise(r => setTimeout(r, wait));
    }
  }
  throw new Error(`Failed to connect producer within ${timeout}ms`);
}

async function createConsumer({ groupId, topics = [], eachMessage, fromBeginning = false, opts = {} }) {
  const kafka = getKafkaInstance();
  const consumer = kafka.consumer({ groupId, ...opts });
  await consumer.connect();
  for (const t of topics) {
    await consumer.subscribe({ topic: t, fromBeginning });
  }
  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      try {
        const value = message.value ? message.value.toString() : null;
        await eachMessage({ topic, partition, message: value, rawMessage: message });
      } catch (err) {
        console.error('Kafka consumer handler error', err);
        // do not crash the consumer; consider DLQ strategy later
      }
    },
  });
  return {
    disconnect: async () => consumer.disconnect(),
    raw: consumer,
  };
}

async function createAdmin() {
  const kafka = getKafkaInstance();
  const admin = kafka.admin();
  await admin.connect();
  return {
    raw: admin,
    disconnect: async () => admin.disconnect(),
    createTopics: async (topics = []) => admin.createTopics({ topics }),
    listTopics: async () => admin.listTopics(),
  };
}

module.exports = {
  kafka: getKafkaInstance(),  // Export function result for backward compatibility
  DEFAULT_BROKERS,
  waitForBroker,
  createProducer,
  createConsumer,
  createAdmin,
};
