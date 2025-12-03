#!/bin/bash
cd "$(dirname "$0")"
echo "🔶 BarbellFX Dashboard Starting..."
echo ""
echo "Opening dashboard at: http://localhost:8080"
echo "Press Ctrl+C to stop"
echo ""
open http://localhost:8080
python3 -m http.server 8080

