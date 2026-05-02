const express = require('express');
const path = require('path');
const { calculate } = require('./calculator');

const app = express();
const PORT = process.env.PORT || 3000;
const VERSION = process.env.APP_VERSION || '1.0.0';

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, 'public')));

app.post('/calculate', (req, res) => {
  const { a, b, op } = req.body;

  if (a === undefined || b === undefined || !op) {
    return res.status(400).json({ error: 'Missing parameters: a, b, op required' });
  }

  const numA = parseFloat(a);
  const numB = parseFloat(b);

  if (isNaN(numA) || isNaN(numB)) {
    return res.status(400).json({ error: 'a and b must be valid numbers' });
  }

  try {
    const result = calculate(numA, numB, op);
    return res.json({
      result,
      expression: `${numA} ${op} ${numB} = ${result}`
    });
  } catch (err) {
    return res.status(400).json({ error: err.message });
  }
});

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    version: VERSION,
    uptime: Math.floor(process.uptime()),
    timestamp: new Date().toISOString()
  });
});

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`\n  Calculator v${VERSION} is running\n`);
    console.log(`  Local:   http://localhost:${PORT}`);
    console.log(`  Health:  http://localhost:${PORT}/health\n`);
  });
}

module.exports = app;
