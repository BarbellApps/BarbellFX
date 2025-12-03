# BarbellFX Signal Injector - Chrome Extension

A Chrome extension that fetches trading signals from the BarbellFX GPT API and injects them into TradingView indicators.

## Features

- 🔄 **Auto-fetch signals** from your API endpoint
- 💉 **Inject signals** directly into TradingView indicator inputs
- ⏰ **Configurable refresh intervals** (10s, 30s, 1m, 5m)
- 📊 **Signal preview** in the popup
- 🔔 **On-chart notifications** when signals arrive

## Installation

### Step 1: Add Icon Images
Before loading the extension, you need to create icon images:

1. Create a 16x16 PNG icon at `icons/icon16.png`
2. Create a 48x48 PNG icon at `icons/icon48.png`
3. Create a 128x128 PNG icon at `icons/icon128.png`

You can use any icon or create one with the gold diamond theme. You can also use online tools like https://icon-generator.net/ to create the icons.

**Quick option:** Remove the icon references from `manifest.json` to test without icons.

### Step 2: Load Extension in Chrome

1. Open Chrome and go to `chrome://extensions/`
2. Enable **Developer mode** (toggle in top right)
3. Click **Load unpacked**
4. Select this `chrome-extension` folder
5. The extension should appear in your toolbar

### Step 3: Configure

1. Click the BarbellFX extension icon
2. Enter your API URL (default: `https://web-production-0617.up.railway.app/signal`)
3. Select refresh interval
4. Click **Fetch Now** to test

## Usage

### On TradingView:

1. Add the **BarbellFX Multi-Signal Dashboard + LIVE** indicator to your chart
2. Open the extension popup
3. Click **Fetch Now** to get the latest signal
4. Click **Inject Signal** to push values into the indicator

### Expected API Response Format:

```json
{
  "pair": "XAUUSD",
  "action": "SELL",
  "entry_min": 3120.5,
  "entry_max": 3122.0,
  "stop_loss": 3128.0,
  "tp1": 3115.5,
  "tp2": 3112.0,
  "tp_full": 3108.0,
  "confidence": 0.82,
  "setup": "NY ORB + Liquidity Sweep"
}
```

The extension handles various field name formats (camelCase, snake_case, etc.)

## Troubleshooting

### Signal not injecting?

TradingView's DOM is complex and changes frequently. If auto-injection fails:

1. A notification will appear on the chart with signal details
2. Manually open indicator settings (double-click the indicator in legend)
3. Enter the LIVE SIGNAL values from the notification

### API not connecting?

1. Check that your API endpoint is correct
2. Ensure the API returns valid JSON
3. Check CORS settings on your server (should allow requests from tradingview.com)

## Files

| File | Description |
|------|-------------|
| `manifest.json` | Extension configuration |
| `popup.html/js` | Extension popup UI |
| `background.js` | Background service worker for auto-fetching |
| `content.js` | Script that runs on TradingView pages |
| `styles.css` | Styles for on-page notifications |

## Development

To modify the extension:

1. Make changes to the files
2. Go to `chrome://extensions/`
3. Click the refresh icon on the extension card
4. Reload TradingView

## Security Note

This extension only:
- Reads from your specified API
- Modifies TradingView indicator inputs
- Stores settings locally

It does NOT:
- Send your data anywhere
- Access other websites
- Store sensitive information

