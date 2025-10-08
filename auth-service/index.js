const express = require('express');
const bodyParser = require('body-parser');
const jwt = require('jsonwebtoken');

const app = express();
app.use(bodyParser.json());

const JWT_SECRET = process.env.JWT_SECRET || 'supersecretdevops';

// Hardcoded demo user (for mini-project)
const demoUser = {
  id: "u1",
  username: "demo",
  password: "demo123",
  name: "Demo User"
};

app.post('/login', (req, res) => {
  const { username, password } = req.body;
  if (username === demoUser.username && password === demoUser.password) {
    const token = jwt.sign({ id: demoUser.id, username: demoUser.username }, JWT_SECRET, { expiresIn: '8h' });
    return res.json({ token });
  }
  return res.status(401).json({ message: "Invalid credentials" });
});

app.get('/', (req, res) => res.json({ service: 'auth', status: 'ok' }));

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => console.log(`Auth service running on ${PORT}`));
