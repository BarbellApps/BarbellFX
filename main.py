from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

latest_signal = None

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

@app.post("/signal")
def receive_signal(signal: Signal):
    global latest_signal
    latest_signal = signal
    return {"status": "received"}

@app.get("/signal")
def get_signal():
    return latest_signal or {"error": "no signal yet"}