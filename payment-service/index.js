const express = require('express');
const bodyParser = require('body-parser');
const jwt = require('jsonwebtoken');
const fetch = require('node-fetch');

const app = express();
app.use(bodyParser.json());

const JWT_SECRET = process.env.JWT_SECRET || 'supersecretdevops';
const INVOICE_URL = process.env.INVOICE_URL || 'http://invoice-service:5000';

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

app.get('/', (req, res) => res.json({ service: 'payment', status: 'ok' }));

// Mock payment endpoint: accepts invoiceId and marks invoice paid by calling invoice-service
app.post('/payments', authMiddleware, async (req, res) => {
  const { invoiceId, amount } = req.body;
  if (!invoiceId) return res.status(400).json({ message: 'invoiceId required' });

  // In real world: talk to payment gateway. Here we simply mark invoice paid:
  try {
    const resp = await fetch(`${INVOICE_URL}/invoices/${invoiceId}/pay`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': req.headers.authorization
      }
    });

    if (!resp.ok) {
      const text = await resp.text();
      return res.status(502).json({ message: 'Failed to update invoice', details: text });
    }
    const updatedInvoice = await resp.json();
    return res.json({ message: 'Payment processed (mock)', invoice: updatedInvoice, amount: amount || null });
  } catch (err) {
    return res.status(500).json({ message: 'Error contacting invoice service', error: err.message });
  }
});

const PORT = process.env.PORT || 6000;
app.listen(PORT, () => console.log(`Payment service running on ${PORT}`));
