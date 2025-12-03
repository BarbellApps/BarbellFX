from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
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
    latest_signal = signal.dict()
    print(f"=== NEW SIGNAL RECEIVED ===")
    print(latest_signal)
    print(f"===========================")
    return {"status": "received", "signal": latest_signal}

@app.get("/signal")
def get_signal():
    return latest_signal
