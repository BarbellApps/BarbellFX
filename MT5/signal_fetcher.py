#!/usr/bin/env python3
"""
BarbellFX Signal Fetcher
Fetches signals from Railway API and writes to MT5 Files folder
Run this in background - no WebRequest needed in MT5!
"""

import requests
import time
import os
import sys

# Configuration
API_URL = "https://web-production-0617.up.railway.app/signal"
REFRESH_INTERVAL = 5  # seconds

# Auto-detect MT5 Files folder
def find_mt5_files_folder():
    possible_paths = [
        os.path.expanduser("~/AppData/Roaming/MetaQuotes/Terminal"),  # Windows
        os.path.expanduser("~/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files"),  # Linux/Wine
        "/Applications/MetaTrader 5.app/Contents/Resources/MQL5/Files",  # Mac
    ]
    
    # For Windows, find the actual terminal folder
    if sys.platform == 'win32':
        base = os.path.expanduser("~/AppData/Roaming/MetaQuotes/Terminal")
        if os.path.exists(base):
            for folder in os.listdir(base):
                files_path = os.path.join(base, folder, "MQL5", "Files")
                if os.path.exists(files_path):
                    return files_path
    
    for path in possible_paths:
        if os.path.exists(path):
            return path
    
    return None

def fetch_signal():
    try:
        response = requests.get(API_URL, timeout=10)
        if response.status_code == 200:
            return response.json()
    except Exception as e:
        print(f"Error fetching signal: {e}")
    return None

def write_signal_file(signal, filepath):
    if not signal or not signal.get('pair'):
        # Write empty file to indicate no signal
        with open(filepath, 'w') as f:
            f.write("")
        return
    
    # Write CSV format: pair,action,entry_min,entry_max,sl,tp1,tp2,tp_full,confidence,setup,timestamp
    line = f"{signal.get('pair', '')},{signal.get('action', '')},{signal.get('entry_min', 0)},{signal.get('entry_max', 0)},{signal.get('stop_loss', 0)},{signal.get('tp1', 0)},{signal.get('tp2', 0)},{signal.get('tp_full', 0)},{signal.get('confidence', 0)},{signal.get('setup', '').replace(',', ';')},{signal.get('timestamp', '')}"
    
    with open(filepath, 'w') as f:
        f.write(line)
    
    print(f"[{time.strftime('%H:%M:%S')}] Signal updated: {signal.get('pair')} {signal.get('action')}")

def main():
    print("=" * 50)
    print("BarbellFX Signal Fetcher")
    print("=" * 50)
    
    # Find MT5 Files folder
    mt5_files = find_mt5_files_folder()
    
    if mt5_files:
        filepath = os.path.join(mt5_files, "barbellfx_signal.txt")
        print(f"MT5 Files folder found: {mt5_files}")
    else:
        # Use current directory as fallback
        filepath = "barbellfx_signal.txt"
        print("MT5 Files folder not found automatically.")
        print(f"Writing to: {os.path.abspath(filepath)}")
        print("")
        print("MANUAL SETUP:")
        print("1. Find your MT5 Data Folder: File -> Open Data Folder")
        print("2. Go to MQL5/Files/")
        print("3. Copy barbellfx_signal.txt there")
        print("")
    
    print(f"Signal file: {filepath}")
    print(f"Refresh interval: {REFRESH_INTERVAL}s")
    print(f"API: {API_URL}")
    print("=" * 50)
    print("Running... Press Ctrl+C to stop")
    print("")
    
    while True:
        signal = fetch_signal()
        write_signal_file(signal, filepath)
        time.sleep(REFRESH_INTERVAL)

if __name__ == "__main__":
    main()

