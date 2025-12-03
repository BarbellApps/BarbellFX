// BarbellFX Signal Injector - Background Service Worker

const DEFAULT_API_URL = 'https://web-production-0617.up.railway.app/signal';
const DEFAULT_INTERVAL = 60; // seconds

// Initialize on install
chrome.runtime.onInstalled.addListener(async () => {
  console.log('BarbellFX Signal Injector installed');
  
  // Set default settings
  await chrome.storage.local.set({
    apiUrl: DEFAULT_API_URL,
    refreshInterval: DEFAULT_INTERVAL,
    autoFetch: true,
    isConnected: false
  });
  
  // Create initial alarm
  setupAlarm(DEFAULT_INTERVAL);
});

// Setup alarm for periodic fetching
function setupAlarm(intervalSeconds) {
  chrome.alarms.clear('fetchSignal');
  chrome.alarms.create('fetchSignal', {
    delayInMinutes: intervalSeconds / 60,
    periodInMinutes: intervalSeconds / 60
  });
  console.log(`Alarm set for every ${intervalSeconds} seconds`);
}

// Handle alarm
chrome.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name === 'fetchSignal') {
    await fetchAndBroadcast();
  }
});

// Fetch signal and broadcast to all tabs/popup
async function fetchAndBroadcast() {
  const settings = await chrome.storage.local.get(['apiUrl', 'autoFetch']);
  
  if (!settings.autoFetch) return;
  
  const apiUrl = settings.apiUrl || DEFAULT_API_URL;
  
  try {
    const response = await fetch(apiUrl, {
      method: 'GET',
      headers: { 'Accept': 'application/json' }
    });
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    
    const data = await response.json();
    const signal = normalizeSignal(data);
    
    // Save to storage
    await chrome.storage.local.set({
      lastSignal: signal,
      lastFetch: Date.now(),
      isConnected: true
    });
    
    // Broadcast to popup if open
    chrome.runtime.sendMessage({
      action: 'signalUpdated',
      signal: signal
    }).catch(() => {
      // Popup not open, ignore
    });
    
    // Broadcast to TradingView tabs
    const tabs = await chrome.tabs.query({ url: '*://*.tradingview.com/*' });
    for (const tab of tabs) {
      chrome.tabs.sendMessage(tab.id, {
        action: 'signalUpdated',
        signal: signal
      }).catch(() => {
        // Tab not ready, ignore
      });
    }
    
    console.log('Signal fetched and broadcast:', signal);
    
  } catch (error) {
    console.error('Background fetch error:', error);
    await chrome.storage.local.set({ isConnected: false });
  }
}

// Normalize signal data
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

// Handle messages from popup
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'updateInterval') {
    setupAlarm(message.interval);
    sendResponse({ success: true });
  }
  
  if (message.action === 'fetchNow') {
    fetchAndBroadcast().then(() => {
      sendResponse({ success: true });
    }).catch(error => {
      sendResponse({ success: false, error: error.message });
    });
    return true; // Keep channel open for async response
  }
  
  return false;
});

// Start initial fetch
chrome.runtime.onStartup.addListener(async () => {
  const settings = await chrome.storage.local.get(['refreshInterval']);
  setupAlarm(settings.refreshInterval || DEFAULT_INTERVAL);
  await fetchAndBroadcast();
});

