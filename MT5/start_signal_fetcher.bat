@echo off
title BarbellFX Signal Fetcher
echo ================================================
echo BarbellFX Signal Fetcher
echo ================================================
echo.
echo This fetches signals from Railway API and writes
echo them to a file that MT5 can read.
echo No WebRequest needed!
echo.
echo ================================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Python is not installed!
    echo Please install Python from https://python.org
    pause
    exit /b 1
)

REM Install requests if needed
pip show requests >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing requests module...
    pip install requests
)

REM Run the fetcher
python signal_fetcher.py

pause

