const express = require('express');
const bodyParser = require('body-parser');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const cors = require('cors');
const db = require('./db');

const app = express();

// Enable CORS for frontend
app.use(cors({
  origin: 'http://localhost:3000',
  credentials: true,
  methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

app.use(bodyParser.json());

const JWT_SECRET = process.env.JWT_SECRET || 'supersecretdevops';

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

// Validation helpers
function validateItems(items) {
  if (!Array.isArray(items) || items.length === 0) {
    return { valid: false, message: 'Items must be a non-empty array' };
  }

  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    
    if (!item.desc || typeof item.desc !== 'string' || item.desc.trim() === '') {
      return { valid: false, message: `Item ${i + 1}: Description is required` };
    }
    
    const qty = parseFloat(item.qty);
    if (isNaN(qty) || qty <= 0) {
      return { valid: false, message: `Item ${i + 1}: Quantity must be greater than 0` };
    }
    
    const price = parseFloat(item.price);
    if (isNaN(price) || price < 0) {
      return { valid: false, message: `Item ${i + 1}: Price must be 0 or greater` };
    }
  }

  return { valid: true };
}

async function publishEvent(eventType, data, source = 'invoice-service') {
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
app.get('/', (req, res) => res.json({ service: 'invoice', status: 'ok', version: '2.0.0' }));

// Create invoice endpoint
app.post('/invoices', authMiddleware, async (req, res) => {
  try {
    const { customer, items = [], dueDate, assigneeId } = req.body;
    
    // Validate required fields
    if (!customer) {
      return res.status(400).json({ message: 'Customer information is required' });
    }
    
    if (!assigneeId) {
      return res.status(400).json({ message: 'Assignee ID is required' });
    }
    
    // Validate items
    const itemValidation = validateItems(items);
    if (!itemValidation.valid) {
      return res.status(400).json({ message: itemValidation.message });
    }
    
    // Validate due date
    if (!dueDate) {
      return res.status(400).json({ message: 'Due date is required' });
    }
    
    // Standardize items format
    const standardizedItems = items.map(item => ({
      desc: item.desc.trim(),
      qty: parseFloat(item.qty),
      price: parseFloat(item.price)
    }));
    
    // Ensure assignee exists
    const assigneeExists = await db.userExists(assigneeId);
    if (!assigneeExists) {
      return res.status(400).json({ message: 'Assignee user not found' });
    }

    // Create invoice in database
    let invoice;
    try {
      invoice = await db.createInvoice({
        creatorId: req.user.userId,
        assigneeId: assigneeId,
        customer: typeof customer === 'string' ? { name: customer } : customer,
        items: standardizedItems,
        dueDate: dueDate
      });
    } catch (dbErr) {
      // Handle foreign key violations gracefully
      if (dbErr && dbErr.code === '23503') { // foreign key violation
        console.error('Create invoice FK error:', dbErr.detail || dbErr.message);
        return res.status(400).json({ message: 'Invalid foreign key reference' });
      }
      throw dbErr;
    }
    
    res.status(201).json(invoice);
    
    // Publish event asynchronously
    setImmediate(() => {
      publishEvent('invoice.created', {
        id: invoice.id,
        creator_id: invoice.creator_id,
        assignee_id: invoice.assignee_id,
        total_amount: invoice.total_amount
      });
    });
    
  } catch (error) {
    console.error('Create invoice error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

// Get invoices with filtering
app.get('/invoices', authMiddleware, async (req, res) => {
  try {
    const { filter = 'created', page = 1, limit = 100 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);
    
    let invoices;
    
    switch (filter) {
      case 'assigned':
        invoices = await db.getInvoicesAssignedTo(req.user.userId, parseInt(limit), offset);
        break;
      case 'all':
        invoices = await db.getAllInvoicesForUser(req.user.userId, parseInt(limit), offset);
        break;
      case 'created':
      default:
        invoices = await db.getInvoicesByCreator(req.user.userId, parseInt(limit), offset);
        break;
    }
    
    res.json(invoices);
    
  } catch (error) {
    console.error('Get invoices error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

// Get single invoice
app.get('/invoices/:id', authMiddleware, async (req, res) => {
  try {
    const invoice = await db.getInvoiceById(req.params.id);
    
    if (!invoice) {
      return res.status(404).json({ message: 'Invoice not found' });
    }
    
    // Check if user has access to this invoice
    if (invoice.creator_id !== req.user.userId && invoice.assignee_id !== req.user.userId) {
      return res.status(403).json({ message: 'Access denied' });
    }
    
    res.json(invoice);
    
  } catch (error) {
    console.error('Get invoice error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

// Pay invoice endpoint
app.patch('/invoices/:id/pay', authMiddleware, async (req, res) => {
  try {
    const invoiceId = req.params.id;
    const userId = req.user.userId;
    
    // Get invoice to verify permissions
    const invoice = await db.getInvoiceById(invoiceId);
    
    if (!invoice) {
      return res.status(404).json({ message: 'Invoice not found' });
    }
    
    // Only the assignee can pay the invoice
    if (invoice.assignee_id !== userId) {
      return res.status(403).json({ 
        message: 'Only the assigned user can pay this invoice' 
      });
    }
    
    // Check if already paid
    if (invoice.status === 'paid') {
      return res.status(400).json({ message: 'Invoice is already paid' });
    }
    
    // Mark as paid
    const updatedInvoice = await db.markPaid(invoiceId, userId);
    
    res.json(updatedInvoice);
    
    // Publish event asynchronously
    setImmediate(() => {
      publishEvent('invoice.paid', {
        id: updatedInvoice.id,
        assignee_id: updatedInvoice.assignee_id,
        total_amount: updatedInvoice.total_amount,
        paid_at: updatedInvoice.paid_at
      });
    });
    
  } catch (error) {
    console.error('Pay invoice error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

// Get invoice statistics
app.get('/users/:userId/stats', authMiddleware, async (req, res) => {
  try {
    // Only allow users to see their own stats
    if (req.params.userId !== req.user.userId) {
      return res.status(403).json({ message: 'Access denied' });
    }
    
    const stats = await db.getInvoiceStats(req.user.userId);
    res.json(stats);
    
  } catch (error) {
    console.error('Get stats error:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});

// Initialize database and start server
async function startServer() {
  try {
    await db.init();
    const PORT = process.env.PORT || 5050;
    app.listen(PORT, () => {
      console.log(`✅ Invoice service running on port ${PORT}`);
    });
  } catch (error) {
    console.error('❌ Failed to start invoice service:', error);
    process.exit(1);
  }
}

startServer();
