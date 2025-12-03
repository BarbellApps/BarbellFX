// BarbellFX Signal Injector - Content Script
// Runs on TradingView pages to inject signals into indicator inputs

console.log('BarbellFX Signal Injector loaded on TradingView');

let currentSignal = null;
let injectionInProgress = false;

// Listen for messages from popup/background
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  // Ping check - respond immediately to confirm content script is loaded
  if (message.action === 'ping') {
    sendResponse({ status: 'pong', loaded: true });
    return false;
  }
  
  if (message.action === 'injectSignal') {
    currentSignal = message.signal;
    injectSignalToIndicator(message.signal)
      .then(() => sendResponse({ success: true }))
      .catch(error => sendResponse({ success: false, error: error.message }));
    return true; // Keep channel open for async response
  }
  
  if (message.action === 'signalUpdated') {
    currentSignal = message.signal;
    // Optional: Auto-inject on update
    // injectSignalToIndicator(message.signal);
    console.log('Signal updated:', message.signal);
  }
  
  return false;
});

// Main injection function
async function injectSignalToIndicator(signal) {
  if (injectionInProgress) {
    throw new Error('Injection already in progress');
  }
  
  injectionInProgress = true;
  
  try {
    console.log('Starting signal injection:', signal);
    
    // Always show the notification with signal values
    showSignalPanel(signal);
    
    // Store signal for reference
    localStorage.setItem('barbellfx_current_signal', JSON.stringify(signal));
    
    console.log('Signal displayed on chart');
    
  } finally {
    injectionInProgress = false;
  }
}

// Open indicator settings dialog
async function openIndicatorSettings() {
  // Look for BarbellFX indicator in the legend
  const legendItems = document.querySelectorAll('[data-name="legend-source-item"]');
  
  for (const item of legendItems) {
    const titleEl = item.querySelector('[class*="sourceTitleBody"]') || 
                    item.querySelector('[class*="title"]');
    
    if (titleEl && titleEl.textContent.includes('BarbellFX')) {
      console.log('Found BarbellFX indicator');
      
      // Find and click settings button
      const settingsBtn = item.querySelector('[data-name="legend-settings-action"]') ||
                         item.querySelector('button[aria-label*="Settings"]') ||
                         item.querySelector('[class*="settings"]');
      
      if (settingsBtn) {
        settingsBtn.click();
        return true;
      }
      
      // Try double-click on the item itself
      item.dispatchEvent(new MouseEvent('dblclick', { bubbles: true }));
      return true;
    }
  }
  
  // Alternative: Look in the objects tree
  const treeItems = document.querySelectorAll('[class*="itemRow"]');
  for (const item of treeItems) {
    if (item.textContent.includes('BarbellFX')) {
      item.dispatchEvent(new MouseEvent('dblclick', { bubbles: true }));
      return true;
    }
  }
  
  return false;
}

// Fill input fields in the settings dialog
async function fillInputFields(signal) {
  const dialog = document.querySelector('[data-dialog-name="Indicator Properties"]') ||
                document.querySelector('[class*="dialog"]') ||
                document.querySelector('[data-name="indicator-properties-dialog"]');
  
  if (!dialog) {
    console.log('Settings dialog not found, trying to find inputs directly');
  }
  
  const container = dialog || document;
  
  // Map of input labels to signal values
  const inputMappings = [
    { label: 'LIVE: Active', value: 'true', type: 'checkbox' },
    { label: 'LIVE: Pair', value: signal.pair, type: 'text' },
    { label: 'LIVE: Direction', value: signal.direction, type: 'select' },
    { label: 'LIVE: Entry Min', value: signal.entry_min, type: 'number' },
    { label: 'LIVE: Entry Max', value: signal.entry_max, type: 'number' },
    { label: 'LIVE: Stop Loss', value: signal.stop_loss, type: 'number' },
    { label: 'LIVE: TP1', value: signal.tp1, type: 'number' },
    { label: 'LIVE: TP2', value: signal.tp2, type: 'number' },
    { label: 'LIVE: Full TP', value: signal.tp_full, type: 'number' },
    { label: 'LIVE: Confidence', value: signal.confidence, type: 'number' },
    { label: 'LIVE: Setup', value: signal.setup, type: 'text' },
    { label: 'LIVE: Timestamp', value: signal.timestamp || new Date().toISOString(), type: 'text' }
  ];
  
  for (const mapping of inputMappings) {
    await setInputValue(container, mapping.label, mapping.value, mapping.type);
    await wait(100);
  }
}

// Set value for a specific input
async function setInputValue(container, label, value, type) {
  // Find the row containing this label
  const rows = container.querySelectorAll('[class*="cell"]') || 
               container.querySelectorAll('[class*="row"]') ||
               container.querySelectorAll('div');
  
  for (const row of rows) {
    const labelEl = row.querySelector('[class*="label"]') || 
                   row.querySelector('span') ||
                   row;
    
    if (labelEl && labelEl.textContent && labelEl.textContent.includes(label)) {
      console.log(`Found input for: ${label}`);
      
      if (type === 'checkbox') {
        const checkbox = row.querySelector('input[type="checkbox"]') ||
                        row.querySelector('[class*="switcher"]') ||
                        row.querySelector('[role="checkbox"]');
        
        if (checkbox) {
          const isChecked = checkbox.checked || checkbox.getAttribute('aria-checked') === 'true';
          const shouldBeChecked = value === 'true' || value === true;
          
          if (isChecked !== shouldBeChecked) {
            checkbox.click();
          }
        }
        return;
      }
      
      if (type === 'select') {
        const select = row.querySelector('select') ||
                      row.querySelector('[class*="dropdown"]') ||
                      row.querySelector('[role="listbox"]');
        
        if (select) {
          // Click to open dropdown
          select.click();
          await wait(200);
          
          // Find and click the option
          const options = document.querySelectorAll('[class*="menuItem"]') ||
                         document.querySelectorAll('[role="option"]');
          
          for (const opt of options) {
            if (opt.textContent.includes(value)) {
              opt.click();
              break;
            }
          }
        }
        return;
      }
      
      // Text or number input
      const input = row.querySelector('input[type="text"]') ||
                   row.querySelector('input[type="number"]') ||
                   row.querySelector('input') ||
                   row.querySelector('[contenteditable="true"]');
      
      if (input) {
        // Clear and set new value
        input.focus();
        input.select && input.select();
        
        // Use native input value setter to trigger React updates
        const nativeInputValueSetter = Object.getOwnPropertyDescriptor(
          window.HTMLInputElement.prototype, 'value'
        ).set;
        
        nativeInputValueSetter.call(input, String(value));
        
        // Dispatch events
        input.dispatchEvent(new Event('input', { bubbles: true }));
        input.dispatchEvent(new Event('change', { bubbles: true }));
        input.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true }));
        
        return;
      }
    }
  }
  
  console.log(`Input not found for: ${label}`);
}

// Close settings dialog
async function closeSettings() {
  // Look for OK/Apply button
  const buttons = document.querySelectorAll('button');
  
  for (const btn of buttons) {
    const text = btn.textContent.toLowerCase();
    if (text === 'ok' || text === 'apply' || text.includes('ok')) {
      btn.click();
      return;
    }
  }
  
  // Try close button
  const closeBtn = document.querySelector('[data-name="close"]') ||
                  document.querySelector('[aria-label="Close"]') ||
                  document.querySelector('[class*="close"]');
  
  if (closeBtn) {
    closeBtn.click();
  }
}

// Keyboard shortcut method as fallback
async function tryKeyboardMethod(signal) {
  // This is a fallback - may not work on all setups
  console.log('Keyboard method not fully implemented - please open settings manually');
  
  // Store signal for manual application
  localStorage.setItem('barbellfx_pending_signal', JSON.stringify(signal));
  
  // Show notification
  showNotification(signal);
}

// Show signal panel on chart - stays visible until closed
function showSignalPanel(signal) {
  // Remove existing panel
  const existing = document.getElementById('barbellfx-signal-panel');
  if (existing) existing.remove();
  
  const dirColor = signal.direction === 'BUY' ? '#00ff88' : '#ff4466';
  const dirBg = signal.direction === 'BUY' ? 'rgba(0, 255, 136, 0.1)' : 'rgba(255, 68, 102, 0.1)';
  
  const panel = document.createElement('div');
  panel.id = 'barbellfx-signal-panel';
  panel.innerHTML = `
    <div style="
      position: fixed;
      top: 80px;
      right: 20px;
      background: linear-gradient(145deg, #1a1a2e 0%, #0d1421 100%);
      border: 2px solid #FFD700;
      border-radius: 16px;
      padding: 0;
      z-index: 999999;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      color: white;
      box-shadow: 0 12px 48px rgba(0,0,0,0.5), 0 0 0 1px rgba(255,215,0,0.2);
      width: 340px;
      overflow: hidden;
    ">
      <!-- Header -->
      <div style="
        background: linear-gradient(90deg, #FFD700 0%, #FFA500 100%);
        padding: 12px 16px;
        display: flex;
        justify-content: space-between;
        align-items: center;
      ">
        <span style="color: #000; font-weight: 700; font-size: 14px;">🔶 BarbellFX LIVE Signal</span>
        <button id="barbellfx-close" style="
          background: rgba(0,0,0,0.2);
          border: none;
          color: #000;
          cursor: pointer;
          font-size: 16px;
          width: 24px;
          height: 24px;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
        ">×</button>
      </div>
      
      <!-- Direction Badge -->
      <div style="
        background: ${dirBg};
        border-bottom: 1px solid rgba(255,255,255,0.1);
        padding: 12px 16px;
        text-align: center;
      ">
        <span style="
          color: ${dirColor};
          font-size: 24px;
          font-weight: 800;
          letter-spacing: 2px;
        ">${signal.direction} ${signal.pair}</span>
      </div>
      
      <!-- Signal Details -->
      <div style="padding: 16px;">
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 16px;">
          <div style="background: rgba(255,255,255,0.05); padding: 10px; border-radius: 8px;">
            <div style="color: #888; font-size: 10px; text-transform: uppercase; margin-bottom: 4px;">Entry Min</div>
            <div style="color: #fff; font-size: 14px; font-weight: 600;" id="copy-entry-min">${signal.entry_min}</div>
          </div>
          <div style="background: rgba(255,255,255,0.05); padding: 10px; border-radius: 8px;">
            <div style="color: #888; font-size: 10px; text-transform: uppercase; margin-bottom: 4px;">Entry Max</div>
            <div style="color: #fff; font-size: 14px; font-weight: 600;" id="copy-entry-max">${signal.entry_max}</div>
          </div>
        </div>
        
        <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 8px; margin-bottom: 16px;">
          <div style="background: rgba(255,68,68,0.1); padding: 10px; border-radius: 8px; border: 1px solid rgba(255,68,68,0.3);">
            <div style="color: #ff6666; font-size: 10px; text-transform: uppercase; margin-bottom: 4px;">Stop Loss</div>
            <div style="color: #ff4444; font-size: 13px; font-weight: 600;">${signal.stop_loss}</div>
          </div>
          <div style="background: rgba(0,255,136,0.1); padding: 10px; border-radius: 8px; border: 1px solid rgba(0,255,136,0.3);">
            <div style="color: #66ff99; font-size: 10px; text-transform: uppercase; margin-bottom: 4px;">TP1</div>
            <div style="color: #00ff88; font-size: 13px; font-weight: 600;">${signal.tp1}</div>
          </div>
          <div style="background: rgba(0,255,136,0.1); padding: 10px; border-radius: 8px; border: 1px solid rgba(0,255,136,0.3);">
            <div style="color: #66ff99; font-size: 10px; text-transform: uppercase; margin-bottom: 4px;">Full TP</div>
            <div style="color: #00ff88; font-size: 13px; font-weight: 600;">${signal.tp_full}</div>
          </div>
        </div>
        
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 16px;">
          <div style="background: rgba(255,255,255,0.05); padding: 10px; border-radius: 8px;">
            <div style="color: #888; font-size: 10px; text-transform: uppercase; margin-bottom: 4px;">TP2</div>
            <div style="color: #fff; font-size: 14px; font-weight: 600;">${signal.tp2}</div>
          </div>
          <div style="background: rgba(255,215,0,0.1); padding: 10px; border-radius: 8px; border: 1px solid rgba(255,215,0,0.3);">
            <div style="color: #FFD700; font-size: 10px; text-transform: uppercase; margin-bottom: 4px;">Confidence</div>
            <div style="color: #FFD700; font-size: 14px; font-weight: 600;">${signal.confidence}%</div>
          </div>
        </div>
        
        ${signal.setup ? `
        <div style="background: rgba(255,255,255,0.03); padding: 10px; border-radius: 8px; margin-bottom: 12px;">
          <div style="color: #888; font-size: 10px; text-transform: uppercase; margin-bottom: 4px;">Setup</div>
          <div style="color: #ccc; font-size: 12px;">${signal.setup}</div>
        </div>
        ` : ''}
        
        <div style="color: #666; font-size: 10px; text-align: center;">
          ${signal.timestamp ? new Date(signal.timestamp).toLocaleString() : 'Just now'}
        </div>
      </div>
      
      <!-- Instructions -->
      <div style="
        background: rgba(255,215,0,0.1);
        border-top: 1px solid rgba(255,215,0,0.2);
        padding: 12px 16px;
      ">
        <button id="barbellfx-copy" style="
          width: 100%;
          padding: 10px;
          background: linear-gradient(90deg, #FFD700 0%, #FFA500 100%);
          border: none;
          border-radius: 8px;
          color: #000;
          font-weight: 700;
          font-size: 12px;
          cursor: pointer;
          margin-bottom: 8px;
          transition: all 0.2s;
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 8px;
        " onmouseover="this.style.transform='scale(1.02)'" onmouseout="this.style.transform='scale(1)'">
          📋 Copy Signal Details
        </button>
        <div style="color: #FFD700; font-size: 10px; text-align: center; opacity: 0.8;">
          Double-click indicator → Enter values in LIVE SIGNAL inputs
        </div>
      </div>
    </div>
  `;
  
  document.body.appendChild(panel);
  
  // Close button
  document.getElementById('barbellfx-close').addEventListener('click', () => {
    panel.remove();
  });
  
  // Copy button
  document.getElementById('barbellfx-copy').addEventListener('click', async () => {
    await copySignalDetails(signal);
  });
  
  // Make panel draggable
  makeDraggable(panel.firstElementChild);
}

// Make element draggable
function makeDraggable(element) {
  let pos1 = 0, pos2 = 0, pos3 = 0, pos4 = 0;
  const header = element.querySelector('div');
  if (header) {
    header.style.cursor = 'move';
    header.onmousedown = dragMouseDown;
  }
  
  function dragMouseDown(e) {
    if (e.target.tagName === 'BUTTON') return;
    e.preventDefault();
    pos3 = e.clientX;
    pos4 = e.clientY;
    document.onmouseup = closeDragElement;
    document.onmousemove = elementDrag;
  }
  
  function elementDrag(e) {
    e.preventDefault();
    pos1 = pos3 - e.clientX;
    pos2 = pos4 - e.clientY;
    pos3 = e.clientX;
    pos4 = e.clientY;
    element.style.top = (element.offsetTop - pos2) + "px";
    element.style.left = (element.offsetLeft - pos1) + "px";
    element.style.right = "auto";
  }
  
  function closeDragElement() {
    document.onmouseup = null;
    document.onmousemove = null;
  }
}

// Legacy notification function (kept for compatibility)
function showNotification(signal) {
  showSignalPanel(signal);
}

// Copy signal details to clipboard
async function copySignalDetails(signal) {
  try {
    // Format signal details
    const signalText = formatSignalForCopy(signal);
    
    // Copy to clipboard
    await navigator.clipboard.writeText(signalText);
    
    // Show success feedback
    const copyBtn = document.getElementById('barbellfx-copy');
    const originalText = copyBtn.innerHTML;
    copyBtn.innerHTML = '✓ Copied!';
    copyBtn.style.background = 'linear-gradient(90deg, #00ff88 0%, #00cc66 100%)';
    
    // Reset button after 2 seconds
    setTimeout(() => {
      copyBtn.innerHTML = originalText;
      copyBtn.style.background = 'linear-gradient(90deg, #FFD700 0%, #FFA500 100%)';
    }, 2000);
    
    console.log('Signal details copied to clipboard');
    
  } catch (error) {
    console.error('Copy error:', error);
    
    // Fallback: try using execCommand
    try {
      const textarea = document.createElement('textarea');
      textarea.value = formatSignalForCopy(signal);
      textarea.style.position = 'fixed';
      textarea.style.opacity = '0';
      textarea.style.left = '-9999px';
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand('copy');
      document.body.removeChild(textarea);
      
      const copyBtn = document.getElementById('barbellfx-copy');
      const originalText = copyBtn.innerHTML;
      copyBtn.innerHTML = '✓ Copied!';
      copyBtn.style.background = 'linear-gradient(90deg, #00ff88 0%, #00cc66 100%)';
      
      setTimeout(() => {
        copyBtn.innerHTML = originalText;
        copyBtn.style.background = 'linear-gradient(90deg, #FFD700 0%, #FFA500 100%)';
      }, 2000);
      
    } catch (fallbackError) {
      console.error('Fallback copy failed:', fallbackError);
      alert('Failed to copy. Please try again.');
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
  
  const conf = typeof signal.confidence === 'number' ? signal.confidence.toFixed(0) : signal.confidence;
  text += `📊 Confidence: ${conf}%\n\n`;
  
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

// Utility: wait
function wait(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Initialize
(async function init() {
  // Load any pending signal from storage
  const result = await chrome.storage.local.get(['lastSignal']);
  if (result.lastSignal) {
    currentSignal = result.lastSignal;
    console.log('Loaded cached signal:', currentSignal);
  }
})();

