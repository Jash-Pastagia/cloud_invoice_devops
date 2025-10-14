const express = require('express');
const bodyParser = require('body-parser');
const jwt = require('jsonwebtoken');
const axios = require('axios');
const { v4: uuidv4 } = require('uuid');
const cors = require('cors');

const app = express();

// Enable CORS for frontend
app.use(cors({
  origin: 'http://localhost:3000',
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

app.use(bodyParser.json());

const JWT_SECRET = process.env.JWT_SECRET || 'supersecretdevops';
const INVOICE_URL = process.env.INVOICE_URL || 'http://invoice-service:5050';

// JWT authentication middleware
function authMiddleware(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'Access token required' });
  }
  
  const token = auth.slice(7);
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (e) {
    return res.status(401).json({ message: 'Invalid or expired token' });
  }
}

async function publishEvent(eventType, data, source = 'payment-service') {
  try {
    const { createProducer } = require('../lib/kafka');
    const { createEvent } = require('../lib/events');
    const producer = await createProducer();
    const evt = createEvent(eventType, data, source);
    await producer.send({ 
      topic: eventType, 
      messages: [{ value: JSON.stringify(evt) }] 
    });
    await producer.disconnect();
    console.log(`[Kafka] Published ${eventType} event`);
  } catch (err) {
    console.error(`[Kafka] Failed to publish ${eventType} event:`, err);
  }
}

// Health check
app.get('/', (req, res) => res.json({ service: 'payment', status: 'ok', version: '2.0.0' }));

// GET /payments endpoint to return empty array for now (could be enhanced to return payment history)
app.get('/payments', authMiddleware, (req, res) => {
  res.json([]);
});

// Process payment endpoint
app.post('/payments', authMiddleware, async (req, res) => {
  try {
    const { invoiceId, amount } = req.body;
    
    if (!invoiceId) {
      return res.status(400).json({ message: 'Invoice ID is required' });
    }

    const paymentId = uuidv4();
    const requestedAt = new Date().toISOString();

    // Publish payment.initiated event immediately (non-blocking)
    setImmediate(() => {
      publishEvent('payment.initiated', { 
        paymentId, 
        invoiceId, 
        amount, 
        userId: req.user.userId,
        requestedAt 
      });
    });

    // First, verify the invoice exists and user has permission to pay it
    try {
      const invoiceResponse = await axios.get(`${INVOICE_URL}/invoices/${invoiceId}`, {
        headers: {
          'Authorization': req.headers.authorization
        }
      });

      const invoice = invoiceResponse.data;

      // Verify the user is the assignee (only assignee can pay)
      if (invoice.assignee_id !== req.user.userId) {
        return res.status(403).json({ 
          message: 'Only the assigned user can pay this invoice' 
        });
      }

      // Check if already paid
      if (invoice.status === 'paid') {
        return res.status(400).json({ message: 'Invoice is already paid' });
      }

      // In real world: talk to payment gateway. Here we simply mark invoice paid:
      const payResponse = await axios.patch(`${INVOICE_URL}/invoices/${invoiceId}/pay`, {}, {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': req.headers.authorization
        }
      });

      const processedAt = new Date().toISOString();
      const updatedInvoice = payResponse.data;

      // Publish payment.processed with success status
      setImmediate(() => {
        publishEvent('payment.processed', { 
          paymentId, 
          invoiceId, 
          amount: updatedInvoice.total_amount, 
          status: 'success',
          userId: req.user.userId,
          processedAt 
        });
      });

      return res.json({ 
        message: 'Payment processed successfully', 
        paymentId,
        invoice: updatedInvoice,
        amount: updatedInvoice.total_amount
      });

    } catch (invoiceError) {
      const processedAt = new Date().toISOString();
      
      let errorMessage = 'Failed to process payment';
      let statusCode = 500;
      
      if (invoiceError.response) {
        statusCode = invoiceError.response.status;
        errorMessage = invoiceError.response.data?.message || errorMessage;
      }

      // Publish payment.processed with failure status
      setImmediate(() => {
        publishEvent('payment.processed', { 
          paymentId, 
          invoiceId, 
          amount, 
          status: 'failed',
          error: errorMessage,
          userId: req.user.userId,
          processedAt 
        });
      });

      return res.status(statusCode).json({ 
        message: errorMessage,
        paymentId
      });
    }

  } catch (error) {
    console.error('Payment processing error:', error);
    res.status(500).json({ message: 'Internal server error during payment processing' });
  }
});

const PORT = process.env.PORT || 6060; // Changed to browser-safe port
app.listen(PORT, () => {
  console.log(`✅ Payment service running on port ${PORT}`);
});
