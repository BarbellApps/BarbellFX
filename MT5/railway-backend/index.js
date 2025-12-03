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

// Health check
app.get('/', (req, res) => {
  res.json({ 
    status: 'BarbellFX Signal API running',
    version: '1.0.0',
    endpoints: {
      'GET /signal': 'Get current signal',
      'POST /signal': 'Set new signal',
      'DELETE /signal': 'Clear signal'
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

