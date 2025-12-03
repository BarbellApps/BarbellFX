// BarbellFX Signal API - Railway Backend
// Receives signals from GPT, serves to MT5 EA and Dashboard

const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

// Enable CORS for ALL origins (required for dashboard and browser access)
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Accept', 'Origin', 'X-Requested-With']
}));

// Handle preflight OPTIONS requests
app.options('*', cors());

app.use(express.json());

// Store the latest signal in memory
let currentSignal = {
  pair: "",
  action: "",
  entry_min: 0,
  entry_max: 0,
  stop_loss: 0,
  tp1: 0,
  tp2: 0,
  tp_full: 0,
  confidence: 0,
  setup: "",
  timestamp: null
};

// Request logging
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// GET /signal - MT5 EA and Chrome extension fetch this
app.get('/signal', (req, res) => {
  res.json(currentSignal);
});

// POST /signal - GPT sends signals here
app.post('/signal', (req, res) => {
  const { 
    pair, 
    action, 
    direction,
    entry_min, 
    entry_max, 
    stop_loss, 
    tp1, 
    tp2, 
    tp_full, 
    confidence, 
    setup,
    timestamp 
  } = req.body;
  
  // Normalize direction field
  const signalDirection = action || direction || '';
  
  currentSignal = {
    pair: pair || currentSignal.pair,
    action: signalDirection.toUpperCase(),
    entry_min: parseFloat(entry_min) || 0,
    entry_max: parseFloat(entry_max) || 0,
    stop_loss: parseFloat(stop_loss) || 0,
    tp1: parseFloat(tp1) || 0,
    tp2: parseFloat(tp2) || 0,
    tp_full: parseFloat(tp_full) || 0,
    confidence: parseFloat(confidence) || 0,
    setup: setup || "",
    timestamp: timestamp || new Date().toISOString()
  };
  
  console.log('=== NEW SIGNAL RECEIVED ===');
  console.log(JSON.stringify(currentSignal, null, 2));
  console.log('===========================');
  
  res.json({ 
    success: true, 
    message: 'Signal saved',
    signal: currentSignal 
  });
});

// DELETE /signal - Clear current signal
app.delete('/signal', (req, res) => {
  currentSignal = {
    pair: "",
    action: "",
    entry_min: 0,
    entry_max: 0,
    stop_loss: 0,
    tp1: 0,
    tp2: 0,
    tp_full: 0,
    confidence: 0,
    setup: "",
    timestamp: null
  };
  
  console.log('Signal cleared');
  res.json({ success: true, message: 'Signal cleared' });
});

// Privacy Policy (required for ChatGPT Actions)
app.get('/privacy', (req, res) => {
  res.send(`
<!DOCTYPE html>
<html>
<head>
  <title>BarbellFX - Privacy Policy</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; line-height: 1.6; }
    h1 { color: #333; }
    h2 { color: #666; margin-top: 30px; }
  </style>
</head>
<body>
  <h1>BarbellFX Privacy Policy</h1>
  <p><strong>Last updated:</strong> December 2024</p>
  
  <h2>1. Introduction</h2>
  <p>BarbellFX ("we", "our", or "us") operates a trading signal service. This privacy policy explains how we handle information when you use our service.</p>
  
  <h2>2. Information We Collect</h2>
  <p>Our service processes trading signals that include:</p>
  <ul>
    <li>Currency pair information (e.g., EURUSD, GBPUSD)</li>
    <li>Trade direction (BUY/SELL)</li>
    <li>Price levels (entry, stop loss, take profit)</li>
    <li>Signal timestamps</li>
  </ul>
  <p>We do not collect personal information, account details, or trading account credentials.</p>
  
  <h2>3. How We Use Information</h2>
  <p>Trading signals are temporarily stored in memory to relay between the GPT interface and trading platforms. Signals are not permanently stored or shared with third parties.</p>
  
  <h2>4. Data Retention</h2>
  <p>Signals are stored in memory only and are cleared when the server restarts or when new signals are received. We do not maintain permanent records of trading signals.</p>
  
  <h2>5. Third Party Services</h2>
  <p>Our API is hosted on Railway.app. Please refer to their privacy policy for information about infrastructure-level data handling.</p>
  
  <h2>6. Contact</h2>
  <p>For questions about this privacy policy, please contact us through the BarbellFX platform.</p>
</body>
</html>
  `);
});

// Terms of Service
app.get('/terms', (req, res) => {
  res.send(`
<!DOCTYPE html>
<html>
<head>
  <title>BarbellFX - Terms of Service</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; line-height: 1.6; }
    h1 { color: #333; }
    h2 { color: #666; margin-top: 30px; }
  </style>
</head>
<body>
  <h1>BarbellFX Terms of Service</h1>
  <p><strong>Last updated:</strong> December 2024</p>
  
  <h2>1. Service Description</h2>
  <p>BarbellFX provides trading signal relay services for educational and informational purposes only.</p>
  
  <h2>2. Disclaimer</h2>
  <p><strong>IMPORTANT:</strong> Trading forex and other financial instruments involves substantial risk of loss. Past performance is not indicative of future results. The signals provided are for informational purposes only and should not be considered financial advice.</p>
  
  <h2>3. No Guarantee</h2>
  <p>We make no guarantees about the accuracy, completeness, or profitability of any trading signals provided through this service.</p>
  
  <h2>4. User Responsibility</h2>
  <p>Users are solely responsible for their trading decisions and any resulting profits or losses. Always use proper risk management.</p>
  
  <h2>5. Limitation of Liability</h2>
  <p>BarbellFX shall not be liable for any direct, indirect, incidental, or consequential damages arising from the use of this service.</p>
</body>
</html>
  `);
});

// Health check
app.get('/', (req, res) => {
  res.json({ 
    status: 'BarbellFX Signal API running',
    version: '1.0.0',
    endpoints: {
      'GET /signal': 'Get current signal',
      'POST /signal': 'Set new signal',
      'DELETE /signal': 'Clear signal',
      'GET /privacy': 'Privacy policy',
      'GET /terms': 'Terms of service'
    },
    currentSignal: currentSignal
  });
});

// Start server
app.listen(PORT, () => {
  console.log('===========================================');
  console.log(`BarbellFX Signal API running on port ${PORT}`);
  console.log('===========================================');
  console.log('');
  console.log('Endpoints:');
  console.log(`  GET  /signal - Get current signal`);
  console.log(`  POST /signal - Set new signal (from GPT)`);
  console.log('');
});

