const express = require('express');
const bodyParser = require('body-parser');
const fs = require('fs');
const path = require('path');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(bodyParser.json());

const DB_FILE = path.join(__dirname, 'db.json');
const JWT_SECRET = process.env.JWT_SECRET || 'supersecretdevops';

// helper functions
function readDB() {
  try {
    const raw = fs.readFileSync(DB_FILE, 'utf8');
    return JSON.parse(raw);
  } catch (err) {
    return { invoices: [] };
  }
}
function writeDB(obj) {
  fs.writeFileSync(DB_FILE, JSON.stringify(obj, null, 2), 'utf8');
}

// simple JWT middleware
function authMiddleware(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith('Bearer ')) return res.status(401).json({ message: 'Missing token' });
  const token = auth.slice(7);
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch (e) {
    return res.status(401).json({ message: 'Invalid token' });
  }
}

app.get('/', (req, res) => res.json({ service: 'invoice', status: 'ok' }));

app.post('/invoices', authMiddleware, (req, res) => {
  const { customer, items = [], dueDate } = req.body;
  if (!customer || !items.length) return res.status(400).json({ message: 'customer and items required' });

  const db = readDB();
  const invoice = {
    id: uuidv4(),
    customer,
    items,
    dueDate: dueDate || null,
    status: 'unpaid',
    createdAt: new Date().toISOString()
  };
  db.invoices.push(invoice);
  writeDB(db);
  res.status(201).json(invoice);
});

app.get('/invoices', authMiddleware, (req, res) => {
  const db = readDB();
  res.json(db.invoices);
});

app.get('/invoices/:id', authMiddleware, (req, res) => {
  const db = readDB();
  const inv = db.invoices.find(i => i.id === req.params.id);
  if (!inv) return res.status(404).json({ message: 'Not found' });
  res.json(inv);
});

app.patch('/invoices/:id/pay', authMiddleware, (req, res) => {
  const db = readDB();
  const inv = db.invoices.find(i => i.id === req.params.id);
  if (!inv) return res.status(404).json({ message: 'Not found' });
  inv.status = 'paid';
  inv.paidAt = new Date().toISOString();
  writeDB(db);
  res.json(inv);
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Invoice service running on ${PORT}`));
