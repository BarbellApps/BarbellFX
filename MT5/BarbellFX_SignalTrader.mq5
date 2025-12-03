//+------------------------------------------------------------------+
//|                                        BarbellFX_SignalTrader.mq5 |
//|                                   Copyright 2024, BarbellFX       |
//|                     Auto-trades signals from BarbellFX GPT API    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, BarbellFX"
#property link      "https://barbellfx.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+

// API Settings
input string   API_URL = "https://web-production-0617.up.railway.app/signal";  // Signal API URL
input int      FetchIntervalSeconds = 10;     // Fetch interval (seconds)
input int      API_Timeout = 5000;            // API timeout (ms)

// Risk Management
input double   RiskPercent = 1.0;             // Risk per trade (%)
input double   MaxLotSize = 1.0;              // Maximum lot size
input double   MinLotSize = 0.01;             // Minimum lot size
input int      MaxOpenTrades = 3;             // Maximum open trades
input int      MaxSpreadPoints = 30;          // Maximum spread (points)

// Take Profit Management
input bool     UsePartialClose = true;        // Use partial close at TPs
input double   TP1_ClosePercent = 50.0;       // Close % at TP1
input double   TP2_ClosePercent = 30.0;       // Close % at TP2
input bool     MoveToBreakeven = true;        // Move SL to breakeven after TP1
input int      BreakevenPlusPoints = 10;      // Points above breakeven

// Trade Filters
input bool     TradeOnlyOnSymbol = true;      // Only trade on current chart symbol
input int      SignalExpiryMinutes = 30;      // Signal expiry time (minutes)
input bool     AllowBuy = true;               // Allow BUY signals
input bool     AllowSell = true;              // Allow SELL signals

// Session Filter
input bool     UseSessionFilter = false;      // Use session filter
input int      SessionStartHour = 8;          // Session start (hour)
input int      SessionEndHour = 20;           // Session end (hour)

// Magic Number
input int      MagicNumber = 123456;          // Magic number for trades

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
CTrade         trade;
CPositionInfo  positionInfo;
datetime       lastFetchTime = 0;
datetime       signalReceiveTime = 0;  // When we received the current signal
string         lastSignalId = "";
bool           initialized = false;

// Signal structure
struct SignalData {
   string   pair;
   string   direction;
   double   entry_min;
   double   entry_max;
   double   stop_loss;
   double   tp1;
   double   tp2;
   double   tp_full;
   double   confidence;
   string   setup;
   string   timestamp;
   bool     valid;
};

SignalData currentSignal;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
   // Set magic number
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   
   // Reset signal
   ResetSignal();
   
   // Check if WebRequest is allowed
   Print("==============================================");
   Print("BarbellFX Signal Trader EA Started");
   Print("API URL: ", API_URL);
   Print("Risk per trade: ", RiskPercent, "%");
   Print("Fetch interval: ", FetchIntervalSeconds, " seconds");
   Print("==============================================");
   Print("");
   Print("IMPORTANT: Add this URL to allowed list:");
   Print("Tools -> Options -> Expert Advisors -> Allow WebRequest for listed URL");
   Print("Add: ", API_URL);
   Print("");
   
   initialized = true;
   
   // Initial fetch
   FetchSignal();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   Print("BarbellFX Signal Trader EA Stopped");
   // Clean up panel objects
   ObjectsDeleteAll(0, "BBFX_");
}

//+------------------------------------------------------------------+
//| Draw visual panel on chart                                        |
//+------------------------------------------------------------------+
void DrawPanel() {
   int x = 20;
   int y = 50;
   int panelWidth = 300;
   int lineHeight = 18;
   
   // Background
   ObjectDelete(0, "BBFX_BG");
   ObjectCreate(0, "BBFX_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_XDISTANCE, x - 10);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_YDISTANCE, y - 10);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_XSIZE, panelWidth);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_YSIZE, currentSignal.valid ? 280 : 120);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_BACK, false);
   
   // Header
   DrawLabel("BBFX_Header", x, y, "◆ BARBELLFX SIGNAL", clrGold, 11, true);
   y += lineHeight + 5;
   
   DrawLabel("BBFX_Divider", x, y, "━━━━━━━━━━━━━━━━━━━━━━━━", clrGold, 8, false);
   y += lineHeight;
   
   if(!currentSignal.valid) {
      DrawLabel("BBFX_NoSignal", x, y, "⬜ No Active Signal", clrGray, 10, false);
      y += lineHeight;
      DrawLabel("BBFX_Waiting", x, y, "Waiting for GPT signal...", clrDimGray, 9, false);
      // Hide other objects
      ObjectDelete(0, "BBFX_Pair");
      ObjectDelete(0, "BBFX_Dir");
      ObjectDelete(0, "BBFX_Entry");
      ObjectDelete(0, "BBFX_SL");
      ObjectDelete(0, "BBFX_TP");
      ObjectDelete(0, "BBFX_Conf");
      ObjectDelete(0, "BBFX_Status");
      ObjectDelete(0, "BBFX_EntryZone");
      ObjectDelete(0, "BBFX_SLLine");
      ObjectDelete(0, "BBFX_TP1Line");
      ObjectDelete(0, "BBFX_TPFullLine");
      ChartRedraw();
      return;
   }
   
   // Signal Details
   bool isBuy = (currentSignal.direction == "BUY");
   color dirColor = isBuy ? clrLime : clrRed;
   
   DrawLabel("BBFX_Pair", x, y, currentSignal.pair, clrWhite, 12, true);
   y += lineHeight;
   
   DrawLabel("BBFX_Dir", x, y, currentSignal.direction, dirColor, 16, true);
   y += lineHeight + 10;
   
   DrawLabel("BBFX_EntryLbl", x, y, "Entry Zone:", clrGray, 9, false);
   y += lineHeight;
   DrawLabel("BBFX_Entry", x, y, DoubleToString(currentSignal.entry_min, _Digits) + " - " + DoubleToString(currentSignal.entry_max, _Digits), clrGold, 10, true);
   y += lineHeight + 5;
   
   DrawLabel("BBFX_SLLbl", x, y, "Stop Loss:", clrGray, 9, false);
   DrawLabel("BBFX_SL", x + 100, y, DoubleToString(currentSignal.stop_loss, _Digits), clrRed, 10, true);
   y += lineHeight;
   
   DrawLabel("BBFX_TP1Lbl", x, y, "TP1 (50%):", clrGray, 9, false);
   DrawLabel("BBFX_TP1", x + 100, y, DoubleToString(currentSignal.tp1, _Digits), clrLime, 10, false);
   y += lineHeight;
   
   DrawLabel("BBFX_TPFullLbl", x, y, "Full TP:", clrGray, 9, false);
   DrawLabel("BBFX_TPFull", x + 100, y, DoubleToString(currentSignal.tp_full, _Digits), clrLime, 10, true);
   y += lineHeight + 5;
   
   // Confidence & R:R
   double conf = currentSignal.confidence < 1 ? currentSignal.confidence * 100 : currentSignal.confidence;
   DrawLabel("BBFX_ConfLbl", x, y, "Confidence:", clrGray, 9, false);
   DrawLabel("BBFX_Conf", x + 100, y, DoubleToString(conf, 0) + "%", clrGold, 10, true);
   y += lineHeight;
   
   double entryMid = (currentSignal.entry_min + currentSignal.entry_max) / 2;
   double risk = MathAbs(entryMid - currentSignal.stop_loss);
   double reward = MathAbs(currentSignal.tp_full - entryMid);
   double rr = risk > 0 ? reward / risk : 0;
   DrawLabel("BBFX_RRLbl", x, y, "Risk:Reward:", clrGray, 9, false);
   DrawLabel("BBFX_RR", x + 100, y, "1:" + DoubleToString(rr, 1), clrLime, 10, true);
   y += lineHeight + 10;
   
   // Status
   bool symbolMatch = SymbolMatches(currentSignal.pair, Symbol());
   double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   bool priceInZone = (currentPrice >= currentSignal.entry_min && currentPrice <= currentSignal.entry_max);
   
   string statusText;
   color statusColor;
   if(!symbolMatch) {
      statusText = "✗ Wrong Symbol (Need " + currentSignal.pair + ")";
      statusColor = clrRed;
   } else if(priceInZone) {
      statusText = "✓ READY - Price in Entry Zone!";
      statusColor = clrLime;
   } else {
      statusText = "⏳ Waiting for price in zone";
      statusColor = clrGold;
   }
   
   DrawLabel("BBFX_Status", x, y, statusText, statusColor, 9, true);
   
   // Draw levels on chart if symbol matches
   if(symbolMatch) {
      DrawLevels();
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Draw label helper                                                  |
//+------------------------------------------------------------------+
void DrawLabel(string name, int x, int y, string text, color clr, int fontSize, bool bold) {
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Draw entry zone and SL/TP levels on chart                         |
//+------------------------------------------------------------------+
void DrawLevels() {
   datetime timeStart = iTime(Symbol(), PERIOD_CURRENT, 50);
   datetime timeEnd = iTime(Symbol(), PERIOD_CURRENT, 0) + PeriodSeconds() * 20;
   
   bool isBuy = (currentSignal.direction == "BUY");
   color zoneColor = isBuy ? clrLime : clrRed;
   
   // Entry Zone
   ObjectDelete(0, "BBFX_EntryZone");
   ObjectCreate(0, "BBFX_EntryZone", OBJ_RECTANGLE, 0, timeStart, currentSignal.entry_min, timeEnd, currentSignal.entry_max);
   ObjectSetInteger(0, "BBFX_EntryZone", OBJPROP_COLOR, zoneColor);
   ObjectSetInteger(0, "BBFX_EntryZone", OBJPROP_FILL, true);
   ObjectSetInteger(0, "BBFX_EntryZone", OBJPROP_BACK, true);
   
   // SL Line
   ObjectDelete(0, "BBFX_SLLine");
   ObjectCreate(0, "BBFX_SLLine", OBJ_HLINE, 0, 0, currentSignal.stop_loss);
   ObjectSetInteger(0, "BBFX_SLLine", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, "BBFX_SLLine", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, "BBFX_SLLine", OBJPROP_STYLE, STYLE_SOLID);
   
   // TP1 Line
   ObjectDelete(0, "BBFX_TP1Line");
   ObjectCreate(0, "BBFX_TP1Line", OBJ_HLINE, 0, 0, currentSignal.tp1);
   ObjectSetInteger(0, "BBFX_TP1Line", OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, "BBFX_TP1Line", OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, "BBFX_TP1Line", OBJPROP_STYLE, STYLE_DASH);
   
   // Full TP Line
   ObjectDelete(0, "BBFX_TPFullLine");
   ObjectCreate(0, "BBFX_TPFullLine", OBJ_HLINE, 0, 0, currentSignal.tp_full);
   ObjectSetInteger(0, "BBFX_TPFullLine", OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, "BBFX_TPFullLine", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, "BBFX_TPFullLine", OBJPROP_STYLE, STYLE_SOLID);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
   if(!initialized) return;
   
   // Check if it's time to fetch new signal
   if(TimeCurrent() - lastFetchTime >= FetchIntervalSeconds) {
      FetchSignal();
      lastFetchTime = TimeCurrent();
   }
   
   // Update visual panel
   DrawPanel();
   
   // Process current signal
   if(currentSignal.valid) {
      ProcessSignal();
   }
   
   // Manage open positions (partial close, breakeven)
   ManagePositions();
}

//+------------------------------------------------------------------+
//| Fetch signal from API                                             |
//+------------------------------------------------------------------+
void FetchSignal() {
   char post[];
   char result[];
   string result_headers;
   
   ResetLastError();
   
   // Use minimal headers - some MT5 versions are picky
   int res = WebRequest(
      "GET",
      API_URL,
      "",           // Empty headers
      API_Timeout,
      post,
      result,
      result_headers
   );
   
   int error = GetLastError();
   
   if(res == -1) {
      if(error == 4014) {
         Print("========================================");
         Print("ERROR 4014: WebRequest blocked by MT5");
         Print("----------------------------------------");
         Print("SOLUTION:");
         Print("1. Go to: Tools -> Options");
         Print("2. Click: Expert Advisors tab");
         Print("3. CHECK: Allow WebRequest for listed URL");
         Print("4. ADD this URL:");
         Print("   https://web-production-0617.up.railway.app");
         Print("5. Click OK then RESTART MT5!");
         Print("========================================");
      } else {
         Print("WebRequest error: ", error);
      }
      return;
   }
   
   if(res != 200) {
      Print("API returned HTTP ", res);
      return;
   }
   
   string response = CharArrayToString(result);
   Print("Signal fetched successfully");
   ParseSignal(response);
}

//+------------------------------------------------------------------+
//| Parse JSON signal                                                 |
//+------------------------------------------------------------------+
void ParseSignal(string json) {
   // Simple JSON parsing (MQL5 doesn't have native JSON)
   SignalData signal;
   signal.valid = false;
   
   signal.pair = GetJsonString(json, "pair");
   signal.direction = GetJsonString(json, "action");
   if(signal.direction == "") signal.direction = GetJsonString(json, "direction");
   
   signal.entry_min = GetJsonDouble(json, "entry_min");
   signal.entry_max = GetJsonDouble(json, "entry_max");
   signal.stop_loss = GetJsonDouble(json, "stop_loss");
   signal.tp1 = GetJsonDouble(json, "tp1");
   signal.tp2 = GetJsonDouble(json, "tp2");
   signal.tp_full = GetJsonDouble(json, "tp_full");
   signal.confidence = GetJsonDouble(json, "confidence");
   signal.setup = GetJsonString(json, "setup");
   signal.timestamp = GetJsonString(json, "timestamp");
   
   // Validate signal
   if(signal.pair != "" && signal.direction != "" && signal.entry_min > 0) {
      signal.valid = true;
      
      // Create unique signal ID
      string signalId = signal.pair + "_" + signal.direction + "_" + 
                        DoubleToString(signal.entry_min, 2) + "_" + signal.timestamp;
      
      // Check if this is a new signal
      if(signalId != lastSignalId) {
         Print("=== NEW SIGNAL RECEIVED ===");
         Print("Pair: ", signal.pair);
         Print("Direction: ", signal.direction);
         Print("Entry: ", signal.entry_min, " - ", signal.entry_max);
         Print("SL: ", signal.stop_loss);
         Print("TP1: ", signal.tp1, " | TP2: ", signal.tp2, " | Full: ", signal.tp_full);
         Print("Confidence: ", signal.confidence * 100, "%");
         Print("Setup: ", signal.setup);
         Print("============================");
         
         lastSignalId = signalId;
         signalReceiveTime = TimeCurrent();  // Mark when we received this signal
         currentSignal = signal;
      }
   }
}

//+------------------------------------------------------------------+
//| Process signal and place trade                                    |
//+------------------------------------------------------------------+
void ProcessSignal() {
   if(!currentSignal.valid) return;
   
   // Check if we already have a position for this signal
   if(HasOpenPosition(currentSignal.pair)) {
      return;
   }
   
   // Check maximum open trades
   if(CountOpenPositions() >= MaxOpenTrades) {
      Print("Max open trades reached (", MaxOpenTrades, ")");
      return;
   }
   
   // Check symbol match
   string symbol = currentSignal.pair;
   if(TradeOnlyOnSymbol) {
      if(!SymbolMatches(symbol, Symbol())) {
         return; // Silent - only trade on matching chart
      }
   }
   
   // Check if symbol exists
   if(!SymbolSelect(symbol, true)) {
      Print("Symbol not found: ", symbol);
      return;
   }
   
   // Check direction filter
   bool isBuy = (StringFind(currentSignal.direction, "BUY") >= 0);
   if(isBuy && !AllowBuy) return;
   if(!isBuy && !AllowSell) return;
   
   // Check session filter
   if(UseSessionFilter) {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.hour < SessionStartHour || dt.hour >= SessionEndHour) {
         return;
      }
   }
   
   // Check signal expiry - use signal receive time instead of API timestamp
   if(SignalExpiryMinutes > 0 && signalReceiveTime > 0) {
      if(TimeCurrent() - signalReceiveTime > SignalExpiryMinutes * 60) {
         Print("Signal expired after ", SignalExpiryMinutes, " minutes");
         ResetSignal();
         signalReceiveTime = 0;
         return;
      }
   }
   
   // Check spread
   double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(spread > MaxSpreadPoints) {
      Print("Spread too high: ", spread, " > ", MaxSpreadPoints);
      return;
   }
   
   // Check if price is in entry zone
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double currentPrice = isBuy ? ask : bid;
   
   if(currentPrice < currentSignal.entry_min || currentPrice > currentSignal.entry_max) {
      // Price not in entry zone - wait
      return;
   }
   
   // Calculate lot size
   double lotSize = CalculateLotSize(symbol, currentSignal.stop_loss, isBuy);
   if(lotSize <= 0) {
      Print("Invalid lot size calculated");
      return;
   }
   
   // Place trade
   PlaceTrade(symbol, isBuy, lotSize, currentSignal.stop_loss, currentSignal.tp_full);
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                  |
//+------------------------------------------------------------------+
double CalculateLotSize(string symbol, double stopLoss, bool isBuy) {
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (RiskPercent / 100.0);
   
   double currentPrice = isBuy ? 
      SymbolInfoDouble(symbol, SYMBOL_ASK) : 
      SymbolInfoDouble(symbol, SYMBOL_BID);
   
   double slDistance = MathAbs(currentPrice - stopLoss);
   
   if(slDistance <= 0) {
      Print("Invalid SL distance");
      return 0;
   }
   
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double pointValue = tickValue / tickSize;
   
   double lotSize = riskAmount / (slDistance * pointValue);
   
   // Apply limits
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathMax(lotSize, minLot);
   lotSize = MathMin(lotSize, maxLot);
   lotSize = MathMin(lotSize, MaxLotSize);
   lotSize = MathMax(lotSize, MinLotSize);
   
   // Round to lot step
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Place trade                                                       |
//+------------------------------------------------------------------+
void PlaceTrade(string symbol, bool isBuy, double lots, double sl, double tp) {
   double price = isBuy ? 
      SymbolInfoDouble(symbol, SYMBOL_ASK) : 
      SymbolInfoDouble(symbol, SYMBOL_BID);
   
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   price = NormalizeDouble(price, digits);
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
   
   string comment = "BarbellFX|" + currentSignal.setup;
   if(StringLen(comment) > 31) comment = StringSubstr(comment, 0, 31);
   
   bool success;
   if(isBuy) {
      success = trade.Buy(lots, symbol, price, sl, tp, comment);
   } else {
      success = trade.Sell(lots, symbol, price, sl, tp, comment);
   }
   
   if(success) {
      Print("=== TRADE OPENED ===");
      Print("Symbol: ", symbol);
      Print("Direction: ", isBuy ? "BUY" : "SELL");
      Print("Lots: ", lots);
      Print("Price: ", price);
      Print("SL: ", sl);
      Print("TP: ", tp);
      Print("====================");
      
      // Mark signal as processed
      ResetSignal();
   } else {
      Print("Trade failed: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Manage open positions (partial close, breakeven)                  |
//+------------------------------------------------------------------+
void ManagePositions() {
   if(!UsePartialClose && !MoveToBreakeven) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(!positionInfo.SelectByIndex(i)) continue;
      if(positionInfo.Magic() != MagicNumber) continue;
      
      string symbol = positionInfo.Symbol();
      double openPrice = positionInfo.PriceOpen();
      double currentPrice = positionInfo.PriceCurrent();
      double sl = positionInfo.StopLoss();
      double tp = positionInfo.TakeProfit();
      double volume = positionInfo.Volume();
      ulong ticket = positionInfo.Ticket();
      ENUM_POSITION_TYPE posType = positionInfo.PositionType();
      bool isBuy = (posType == POSITION_TYPE_BUY);
      
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      // Calculate profit in points
      double profitPoints = isBuy ? 
         (currentPrice - openPrice) / point :
         (openPrice - currentPrice) / point;
      
      // Check for breakeven
      if(MoveToBreakeven && profitPoints > BreakevenPlusPoints * 2) {
         double newSL = isBuy ? 
            openPrice + BreakevenPlusPoints * point :
            openPrice - BreakevenPlusPoints * point;
         newSL = NormalizeDouble(newSL, digits);
         
         bool shouldMove = isBuy ? (newSL > sl) : (newSL < sl || sl == 0);
         
         if(shouldMove) {
            if(trade.PositionModify(ticket, newSL, tp)) {
               Print("Moved to breakeven: ", symbol, " SL=", newSL);
            }
         }
      }
      
      // Partial close logic would require tracking which TPs have been hit
      // This is a simplified version - full implementation would need database/file storage
   }
}

//+------------------------------------------------------------------+
//| Helper Functions                                                  |
//+------------------------------------------------------------------+

void ResetSignal() {
   currentSignal.valid = false;
   currentSignal.pair = "";
   currentSignal.direction = "";
}

bool HasOpenPosition(string pair) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(positionInfo.SelectByIndex(i)) {
         if(positionInfo.Magic() == MagicNumber) {
            if(SymbolMatches(positionInfo.Symbol(), pair)) {
               return true;
            }
         }
      }
   }
   return false;
}

int CountOpenPositions() {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(positionInfo.SelectByIndex(i)) {
         if(positionInfo.Magic() == MagicNumber) {
            count++;
         }
      }
   }
   return count;
}

bool SymbolMatches(string sym1, string sym2) {
   // Normalize symbols (remove suffixes like .raw, .pro, etc.)
   string s1 = StringSubstr(sym1, 0, 6);
   string s2 = StringSubstr(sym2, 0, 6);
   StringToUpper(s1);
   StringToUpper(s2);
   return (s1 == s2);
}

//+------------------------------------------------------------------+
//| JSON Parsing Helpers                                              |
//+------------------------------------------------------------------+

string GetJsonString(string json, string key) {
   string searchKey = "\"" + key + "\"";
   int keyPos = StringFind(json, searchKey);
   if(keyPos < 0) return "";
   
   int colonPos = StringFind(json, ":", keyPos);
   if(colonPos < 0) return "";
   
   int startPos = StringFind(json, "\"", colonPos + 1);
   if(startPos < 0) return "";
   
   int endPos = StringFind(json, "\"", startPos + 1);
   if(endPos < 0) return "";
   
   return StringSubstr(json, startPos + 1, endPos - startPos - 1);
}

double GetJsonDouble(string json, string key) {
   string searchKey = "\"" + key + "\"";
   int keyPos = StringFind(json, searchKey);
   if(keyPos < 0) return 0;
   
   int colonPos = StringFind(json, ":", keyPos);
   if(colonPos < 0) return 0;
   
   // Find the start of the number
   int startPos = colonPos + 1;
   while(startPos < StringLen(json) && 
         (StringGetCharacter(json, startPos) == ' ' || 
          StringGetCharacter(json, startPos) == '"')) {
      startPos++;
   }
   
   // Find the end of the number
   int endPos = startPos;
   while(endPos < StringLen(json)) {
      ushort ch = StringGetCharacter(json, endPos);
      if((ch >= '0' && ch <= '9') || ch == '.' || ch == '-') {
         endPos++;
      } else {
         break;
      }
   }
   
   string numStr = StringSubstr(json, startPos, endPos - startPos);
   return StringToDouble(numStr);
}
//+------------------------------------------------------------------+

