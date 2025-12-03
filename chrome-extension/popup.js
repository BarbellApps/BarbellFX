// BarbellFX Signal Injector - Popup Script

const DEFAULT_API_URL = 'https://web-production-0617.up.railway.app/signal';

let currentSignal = null;

// Initialize popup
document.addEventListener('DOMContentLoaded', async () => {
  await loadSettings();
  await loadLatestSignal();
  setupEventListeners();
  updateUI();
  await checkConnection();
});

// Check connection to TradingView
async function checkConnection() {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    
    if (!tab || !tab.url || !tab.url.includes('tradingview.com')) {
      updateConnectionStatus(false);
      document.getElementById('statusText').textContent = 'Open TradingView';
      return;
    }
    
    const isLoaded = await isContentScriptLoaded(tab.id);
    
    if (isLoaded) {
      updateConnectionStatus(true);
      document.getElementById('helpText').style.display = 'none';
    } else {
      updateConnectionStatus(false);
      document.getElementById('statusText').textContent = 'Refresh Needed';
      document.getElementById('helpText').style.display = 'block';
    }
  } catch (e) {
    updateConnectionStatus(false);
  }
}

// Load saved settings
async function loadSettings() {
  const result = await chrome.storage.local.get(['apiUrl', 'refreshInterval', 'lastSignal', 'lastFetch']);
  
  document.getElementById('apiUrl').value = result.apiUrl || DEFAULT_API_URL;
  
  const interval = result.refreshInterval || 60;
  document.querySelectorAll('.interval-btn').forEach(btn => {
    btn.classList.toggle('active', parseInt(btn.dataset.interval) === interval);
  });
  
  if (result.lastSignal) {
    currentSignal = result.lastSignal;
    displaySignal(currentSignal);
  }
  
  if (result.lastFetch) {
    document.getElementById('lastUpdate').textContent = `Last: ${formatTime(result.lastFetch)}`;
  }
}

// Load latest signal from storage
async function loadLatestSignal() {
  const result = await chrome.storage.local.get(['lastSignal', 'isConnected']);
  
  if (result.lastSignal) {
    currentSignal = result.lastSignal;
    displaySignal(currentSignal);
  }
  
  updateConnectionStatus(result.isConnected || false);
}

// Setup event listeners
function setupEventListeners() {
  // API URL change
  document.getElementById('apiUrl').addEventListener('change', async (e) => {
    await chrome.storage.local.set({ apiUrl: e.target.value });
    addLog('API URL updated');
  });
  
  // Interval buttons
  document.querySelectorAll('.interval-btn').forEach(btn => {
    btn.addEventListener('click', async () => {
      const interval = parseInt(btn.dataset.interval);
      document.querySelectorAll('.interval-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      await chrome.storage.local.set({ refreshInterval: interval });
      
      // Update alarm
      chrome.runtime.sendMessage({ action: 'updateInterval', interval });
      addLog(`Refresh interval set to ${interval}s`);
    });
  });
  
  // Fetch button
  document.getElementById('fetchBtn').addEventListener('click', async () => {
    await fetchSignal();
  });
  
  // Inject button
  document.getElementById('injectBtn').addEventListener('click', async () => {
    await injectSignal();
  });
  
  // Copy button
  document.getElementById('copyBtn').addEventListener('click', async () => {
    await copySignalToClipboard();
  });
  
  // Refresh page button
  document.getElementById('refreshPageBtn').addEventListener('click', async () => {
    try {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      if (tab && tab.url && tab.url.includes('tradingview.com')) {
        await chrome.tabs.reload(tab.id);
        addLog('TradingView page refreshed! Wait a moment then try again.', 'success');
        document.getElementById('helpText').style.display = 'none';
      } else {
        addLog('Please open TradingView first', 'error');
      }
    } catch (error) {
      addLog('Could not refresh page', 'error');
    }
  });
}

// Fetch signal from API
async function fetchSignal() {
  const apiUrl = document.getElementById('apiUrl').value || DEFAULT_API_URL;
  const fetchBtn = document.getElementById('fetchBtn');
  
  fetchBtn.disabled = true;
  fetchBtn.textContent = 'Fetching...';
  addLog('Fetching signal...');
  
  try {
    const response = await fetch(apiUrl, {
      method: 'GET',
      headers: {
        'Accept': 'application/json'
      }
    });
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    
    const data = await response.json();
    currentSignal = normalizeSignal(data);
    
    // Save to storage
    await chrome.storage.local.set({
      lastSignal: currentSignal,
      lastFetch: Date.now(),
      isConnected: true
    });
    
    displaySignal(currentSignal);
    updateConnectionStatus(true);
    document.getElementById('lastUpdate').textContent = `Last: ${formatTime(Date.now())}`;
    addLog('Signal fetched successfully', 'success');
    
  } catch (error) {
    console.error('Fetch error:', error);
    addLog(`Fetch failed: ${error.message}`, 'error');
    updateConnectionStatus(false);
  } finally {
    fetchBtn.disabled = false;
    fetchBtn.textContent = 'Fetch Now';
  }
}

// Normalize signal data (handle different API formats)
function normalizeSignal(data) {
  // Handle confidence - if <= 1, multiply by 100, otherwise use as-is
  let conf = parseFloat(data.confidence || data.conf || 0);
  if (conf > 0 && conf <= 1) {
    conf = conf * 100;
  }
  
  return {
    pair: data.pair || data.symbol || 'UNKNOWN',
    direction: (data.action || data.direction || data.side || 'BUY').toUpperCase(),
    entry_min: parseFloat(data.entry_min || data.entryMin || data.entry || 0),
    entry_max: parseFloat(data.entry_max || data.entryMax || data.entry || 0),
    stop_loss: parseFloat(data.stop_loss || data.stopLoss || data.sl || 0),
    tp1: parseFloat(data.tp1 || data.takeProfit1 || 0),
    tp2: parseFloat(data.tp2 || data.takeProfit2 || 0),
    tp_full: parseFloat(data.tp_full || data.tpFull || data.tp3 || data.takeProfit || 0),
    confidence: conf,
    setup: data.setup || data.reason || data.description || '',
    timestamp: data.timestamp || new Date().toISOString()
  };
}

// Display signal in popup
function displaySignal(signal) {
  const copyBtn = document.getElementById('copyBtn');
  
  if (!signal) {
    copyBtn.disabled = true;
    copyBtn.style.opacity = '0.5';
    return;
  }
  
  copyBtn.disabled = false;
  copyBtn.style.opacity = '1';
  
  document.getElementById('sigPair').textContent = signal.pair;
  
  const dirEl = document.getElementById('sigDir');
  dirEl.textContent = signal.direction;
  dirEl.className = `signal-value ${signal.direction.toLowerCase()}`;
  
  document.getElementById('sigEntry').textContent = `${signal.entry_min} - ${signal.entry_max}`;
  document.getElementById('sigSL').textContent = signal.stop_loss;
  document.getElementById('sigTP').textContent = `${signal.tp1} / ${signal.tp2} / ${signal.tp_full}`;
  document.getElementById('sigConf').textContent = `${signal.confidence.toFixed(0)}%`;
  document.getElementById('sigSetup').textContent = signal.setup || '--';
  
  // Format and display timestamp
  if (signal.timestamp) {
    try {
      const date = new Date(signal.timestamp);
      document.getElementById('sigTime').textContent = date.toLocaleString();
    } catch (e) {
      document.getElementById('sigTime').textContent = signal.timestamp;
    }
  } else {
    document.getElementById('sigTime').textContent = '--';
  }
}

// Copy signal details to clipboard
async function copySignalToClipboard() {
  if (!currentSignal) {
    addLog('No signal to copy', 'error');
    return;
  }
  
  try {
    // Format signal details
    const signalText = formatSignalForCopy(currentSignal);
    
    // Copy to clipboard
    await navigator.clipboard.writeText(signalText);
    
    // Show success feedback
    const copyBtn = document.getElementById('copyBtn');
    const originalText = copyBtn.textContent;
    copyBtn.textContent = '✓ Copied!';
    copyBtn.style.background = '#44ff44';
    copyBtn.style.color = '#000';
    
    addLog('Signal details copied to clipboard!', 'success');
    
    // Reset button after 2 seconds
    setTimeout(() => {
      copyBtn.textContent = originalText;
      copyBtn.style.background = '';
      copyBtn.style.color = '';
    }, 2000);
    
  } catch (error) {
    console.error('Copy error:', error);
    addLog('Failed to copy: ' + error.message, 'error');
    
    // Fallback: try using execCommand
    try {
      const textarea = document.createElement('textarea');
      textarea.value = formatSignalForCopy(currentSignal);
      textarea.style.position = 'fixed';
      textarea.style.opacity = '0';
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand('copy');
      document.body.removeChild(textarea);
      addLog('Signal details copied (fallback method)', 'success');
    } catch (fallbackError) {
      addLog('Copy failed: ' + fallbackError.message, 'error');
    }
  }
}

// Format signal as text for copying
function formatSignalForCopy(signal) {
  let text = '═══════════════════════════════════════\n';
  text += '🔶 BARBELLFX TRADING SIGNAL\n';
  text += '═══════════════════════════════════════\n\n';
  
  text += `📊 Pair: ${signal.pair}\n`;
  text += `📈 Direction: ${signal.direction}\n\n`;
  
  text += `💰 Entry Zone:\n`;
  text += `   Min: ${signal.entry_min}\n`;
  text += `   Max: ${signal.entry_max}\n\n`;
  
  text += `🛑 Stop Loss: ${signal.stop_loss}\n\n`;
  
  text += `🎯 Take Profit Levels:\n`;
  text += `   TP1 (50%): ${signal.tp1}\n`;
  text += `   TP2 (30%): ${signal.tp2}\n`;
  text += `   Full TP (20%): ${signal.tp_full}\n\n`;
  
  text += `📊 Confidence: ${signal.confidence.toFixed(0)}%\n\n`;
  
  if (signal.setup) {
    text += `📝 Setup:\n${signal.setup}\n\n`;
  }
  
  if (signal.timestamp) {
    try {
      const date = new Date(signal.timestamp);
      text += `🕐 Timestamp: ${date.toLocaleString()}\n`;
    } catch (e) {
      text += `🕐 Timestamp: ${signal.timestamp}\n`;
    }
  }
  
  text += '\n═══════════════════════════════════════\n';
  text += 'Generated by BarbellFX Signal Injector\n';
  text += '═══════════════════════════════════════';
  
  return text;
}

// Check if content script is loaded
async function isContentScriptLoaded(tabId) {
  try {
    const response = await chrome.tabs.sendMessage(tabId, { action: 'ping' });
    return response && response.status === 'pong';
  } catch (e) {
    return false;
  }
}

// Inject signal into TradingView
async function injectSignal() {
  if (!currentSignal) {
    addLog('No signal to inject', 'error');
    return;
  }
  
  const injectBtn = document.getElementById('injectBtn');
  injectBtn.disabled = true;
  injectBtn.textContent = 'Checking...';
  
  try {
    // Get current tab
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    
    if (!tab || !tab.url) {
      addLog('Cannot access current tab', 'error');
      document.getElementById('helpText').style.display = 'block';
      return;
    }
    
    if (!tab.url.includes('tradingview.com')) {
      addLog('Not on TradingView! Open TradingView first.', 'error');
      return;
    }
    
    // Check if content script is loaded
    injectBtn.textContent = 'Connecting...';
    const isLoaded = await isContentScriptLoaded(tab.id);
    
    if (!isLoaded) {
      addLog('Content script not loaded. Refresh TradingView!', 'error');
      document.getElementById('helpText').style.display = 'block';
      return;
    }
    
    // Content script is loaded, send the signal
    injectBtn.textContent = 'Injecting...';
    addLog('Connected! Injecting signal...', 'info');
    
    const response = await chrome.tabs.sendMessage(tab.id, {
      action: 'injectSignal',
      signal: currentSignal
    });
    
    if (response && response.success) {
      addLog('Signal injected successfully!', 'success');
      document.getElementById('helpText').style.display = 'none';
    } else {
      addLog(response?.error || 'Injection failed - check indicator settings', 'error');
    }
    
  } catch (error) {
    console.error('Inject error:', error);
    addLog('Connection failed - refresh TradingView!', 'error');
    document.getElementById('helpText').style.display = 'block';
  } finally {
    injectBtn.disabled = false;
    injectBtn.textContent = 'Inject Signal';
  }
}

// Update connection status UI
function updateConnectionStatus(connected) {
  const dot = document.getElementById('statusDot');
  const text = document.getElementById('statusText');
  
  if (connected) {
    dot.classList.add('connected');
    text.textContent = 'Connected';
  } else {
    dot.classList.remove('connected');
    text.textContent = 'Disconnected';
  }
}

// Update general UI
function updateUI() {
  // Enable/disable inject button based on signal
  document.getElementById('injectBtn').disabled = !currentSignal;
}

// Add log entry
function addLog(message, type = 'info') {
  const logEntries = document.getElementById('logEntries');
  const entry = document.createElement('div');
  entry.className = `log-entry ${type}`;
  entry.textContent = `[${formatTime(Date.now())}] ${message}`;
  logEntries.insertBefore(entry, logEntries.firstChild);
  
  // Keep only last 20 entries
  while (logEntries.children.length > 20) {
    logEntries.removeChild(logEntries.lastChild);
  }
}

// Format timestamp
function formatTime(timestamp) {
  const date = new Date(timestamp);
  return date.toLocaleTimeString('en-US', { hour12: false });
}

// Listen for messages from background script
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'signalUpdated') {
    currentSignal = message.signal;
    displaySignal(currentSignal);
    updateConnectionStatus(true);
    document.getElementById('lastUpdate').textContent = `Last: ${formatTime(Date.now())}`;
    addLog('Signal auto-updated', 'success');
  }
});

