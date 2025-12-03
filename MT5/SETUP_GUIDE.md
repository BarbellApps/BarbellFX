# BarbellFX MT5 Signal Trader - Setup Guide

## 🚀 Complete Automated Trading System

This system automatically executes trades from your BarbellFX GPT signals.

```
GPT Analysis → Railway API → MT5 EA → Auto Trade Execution
```

---

## 📦 Components

| Component | Location | Purpose |
|-----------|----------|---------|
| **MT5 EA** | `BarbellFX_SignalTrader.mq5` | Fetches signals & executes trades |
| **Railway Backend** | `railway-backend/` | Stores signals from GPT |
| **GPT Action** | Already configured | Sends signals to Railway |

---

## 🔧 Step 1: Deploy Railway Backend

### If you already have Railway running:
Your API is already at: `https://web-production-0617.up.railway.app`

### To deploy fresh or update:

1. Go to [Railway.app](https://railway.app)
2. Create new project or open existing
3. Connect GitHub or deploy directly
4. Upload the `railway-backend/` folder contents
5. Railway will auto-deploy

---

## 🔧 Step 2: Install MT5 EA

### 2.1 Copy EA File

1. Open MetaTrader 5
2. Click **File → Open Data Folder**
3. Navigate to `MQL5/Experts/`
4. Copy `BarbellFX_SignalTrader.mq5` into this folder

### 2.2 Compile the EA

1. In MT5, press **F4** to open MetaEditor
2. Click **File → Open** and select `BarbellFX_SignalTrader.mq5`
3. Press **F7** or click **Compile**
4. Check for 0 errors in the output

### 2.3 Allow Web Requests (CRITICAL!)

1. In MT5, go to **Tools → Options**
2. Click **Expert Advisors** tab
3. ✅ Check **Allow WebRequest for listed URL**
4. Click **Add** and enter: `https://web-production-0617.up.railway.app`
5. Click **OK**

![WebRequest Settings](https://i.imgur.com/example.png)

---

## 🔧 Step 3: Attach EA to Chart

1. Open a chart (e.g., XAUUSD)
2. In **Navigator** panel (Ctrl+N), find **Expert Advisors**
3. Drag **BarbellFX_SignalTrader** onto the chart
4. Configure settings (see below)
5. Click **OK**
6. Make sure **AutoTrading** is enabled (button in toolbar)

---

## ⚙️ EA Settings

### API Settings
| Setting | Default | Description |
|---------|---------|-------------|
| API_URL | `https://web-production-0617.up.railway.app/signal` | Your Railway API URL |
| FetchIntervalSeconds | 10 | How often to check for signals |
| API_Timeout | 5000 | Request timeout (ms) |

### Risk Management
| Setting | Default | Description |
|---------|---------|-------------|
| RiskPercent | 1.0 | Risk per trade (% of balance) |
| MaxLotSize | 1.0 | Maximum lot size allowed |
| MinLotSize | 0.01 | Minimum lot size |
| MaxOpenTrades | 3 | Maximum simultaneous trades |
| MaxSpreadPoints | 30 | Skip if spread exceeds this |

### Take Profit Management
| Setting | Default | Description |
|---------|---------|-------------|
| UsePartialClose | true | Close portions at TP levels |
| TP1_ClosePercent | 50 | % to close at TP1 |
| TP2_ClosePercent | 30 | % to close at TP2 |
| MoveToBreakeven | true | Move SL to entry after TP1 |
| BreakevenPlusPoints | 10 | Points above entry for BE |

### Trade Filters
| Setting | Default | Description |
|---------|---------|-------------|
| TradeOnlyOnSymbol | true | Only trade on attached chart symbol |
| SignalExpiryMinutes | 30 | Ignore signals older than this |
| AllowBuy | true | Allow BUY signals |
| AllowSell | true | Allow SELL signals |

### Session Filter
| Setting | Default | Description |
|---------|---------|-------------|
| UseSessionFilter | false | Only trade during specific hours |
| SessionStartHour | 8 | Start hour (server time) |
| SessionEndHour | 20 | End hour (server time) |

---

## 🧪 Step 4: Test the System

### 4.1 Test API Connection

1. Look at the **Experts** tab in MT5 (Ctrl+T, then click Experts tab)
2. You should see: `BarbellFX Signal Trader EA Started`
3. If you see `WebRequest not allowed`, go back to Step 2.3

### 4.2 Send a Test Signal

Ask your GPT: *"Give me a test signal for XAUUSD"*

Or test with curl:
```bash
curl -X POST https://web-production-0617.up.railway.app/signal \
  -H "Content-Type: application/json" \
  -d '{
    "pair": "XAUUSD",
    "action": "BUY",
    "entry_min": 2650.00,
    "entry_max": 2655.00,
    "stop_loss": 2640.00,
    "tp1": 2665.00,
    "tp2": 2675.00,
    "tp_full": 2690.00,
    "confidence": 0.85,
    "setup": "Test Signal"
  }'
```

### 4.3 Check EA Response

In the Experts tab, you should see:
```
=== NEW SIGNAL RECEIVED ===
Pair: XAUUSD
Direction: BUY
Entry: 2650.00 - 2655.00
...
```

---

## 🔄 How It Works

1. **GPT sends signal** → Railway API receives and stores
2. **EA polls API** every X seconds
3. **EA validates signal**:
   - Correct symbol?
   - Fresh timestamp?
   - Price in entry zone?
   - Spread acceptable?
4. **EA calculates lot size** based on risk %
5. **EA places trade** with SL/TP
6. **EA manages trade** (breakeven, partial close)

---

## ⚠️ Important Notes

### DO Before Going Live:
- ✅ Test on **demo account** first
- ✅ Verify API connection works
- ✅ Check lot sizes are correct
- ✅ Confirm SL/TP levels are valid

### Risk Warning:
- Start with **small risk %** (0.5-1%)
- Use **demo account** until confident
- Monitor trades initially
- Set **MaxOpenTrades** limit

---

## 🐛 Troubleshooting

### "WebRequest not allowed"
→ Add URL to allowed list: Tools → Options → Expert Advisors

### "Symbol not found"
→ Your broker uses different symbol name. Check your broker's symbol list.

### EA not trading
1. Check AutoTrading is ON (button in toolbar)
2. Check if price is in entry zone
3. Check spread isn't too high
4. Check signal isn't expired

### No signals appearing
1. Verify Railway API is running
2. Check API URL is correct
3. Test with curl command above

---

## 📞 Support

Need help? Check:
1. MT5 Experts tab for error messages
2. Railway logs for API issues
3. GPT conversation for signal format

---

## 📁 Files Included

```
MT5/
├── BarbellFX_SignalTrader.mq5    # Main EA file
├── railway-backend/
│   ├── index.js                   # API server
│   └── package.json               # Dependencies
└── SETUP_GUIDE.md                 # This file
```

Happy Trading! 🚀

