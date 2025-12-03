from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from typing import Optional

app = FastAPI(title="BarbellFX Signal API")

# Enable CORS for all origins (required for dashboard and browser access)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

latest_signal = {
    "pair": "",
    "action": "",
    "entry_min": 0,
    "entry_max": 0,
    "stop_loss": 0,
    "tp1": 0,
    "tp2": 0,
    "tp_full": 0,
    "confidence": 0,
    "setup": "",
    "timestamp": None
}

class Signal(BaseModel):
    pair: str
    action: str
    entry_min: float
    entry_max: float
    stop_loss: float
    tp1: float
    tp2: float
    tp_full: float
    confidence: float
    setup: str
    timestamp: str

@app.get("/")
def root():
    return {
        "status": "BarbellFX Signal API running",
        "version": "1.0.0",
        "endpoints": {
            "GET /signal": "Get current signal",
            "POST /signal": "Set new signal"
        },
        "currentSignal": latest_signal
    }

@app.post("/signal")
def receive_signal(signal: Signal):
    global latest_signal
    
    # Extract prices
    entry_min = signal.entry_min
    entry_max = signal.entry_max
    stop_loss = signal.stop_loss
    tp1 = signal.tp1
    tp2 = signal.tp2
    tp_full = signal.tp_full
    
    # Normalize Gold (XAUUSD) prices - if prices are < 100, multiply by 1000
    pair_upper = (signal.pair or "").upper()
    is_gold = "XAU" in pair_upper or "GOLD" in pair_upper
    
    if is_gold:
        # Check if prices need conversion (if any price is < 100, assume wrong format)
        prices = [p for p in [entry_min, entry_max, stop_loss, tp1, tp2, tp_full] if p > 0]
        needs_conversion = len(prices) > 0 and any(p < 100 for p in prices)
        
        if needs_conversion:
            entry_min = entry_min * 1000
            entry_max = entry_max * 1000
            stop_loss = stop_loss * 1000
            tp1 = tp1 * 1000
            tp2 = tp2 * 1000
            tp_full = tp_full * 1000
            print("Gold prices normalized (multiplied by 1000)")
    
    latest_signal = {
        "pair": signal.pair,
        "action": signal.action,
        "entry_min": entry_min,
        "entry_max": entry_max,
        "stop_loss": stop_loss,
        "tp1": tp1,
        "tp2": tp2,
        "tp_full": tp_full,
        "confidence": signal.confidence,
        "setup": signal.setup,
        "timestamp": signal.timestamp
    }
    
    print(f"=== NEW SIGNAL RECEIVED ===")
    print(latest_signal)
    print(f"===========================")
    return {"status": "received", "signal": latest_signal}

@app.get("/signal")
def get_signal():
    return latest_signal

@app.get("/privacy", response_class=HTMLResponse)
def privacy_policy():
    return """
<!DOCTYPE html>
<html>
<head>
  <title>BarbellFX - Privacy Policy</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; line-height: 1.6; background: #1a1a2e; color: #eee; }
    h1 { color: #ffd700; }
    h2 { color: #ffd700; margin-top: 30px; }
    a { color: #4da6ff; }
  </style>
</head>
<body>
  <h1>🔒 BarbellFX Privacy Policy</h1>
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
    """

@app.get("/terms", response_class=HTMLResponse)
def terms_of_service():
    return """
<!DOCTYPE html>
<html>
<head>
  <title>BarbellFX - Terms of Service</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; line-height: 1.6; background: #1a1a2e; color: #eee; }
    h1 { color: #ffd700; }
    h2 { color: #ffd700; margin-top: 30px; }
    strong { color: #ff6b6b; }
  </style>
</head>
<body>
  <h1>📜 BarbellFX Terms of Service</h1>
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
    """
