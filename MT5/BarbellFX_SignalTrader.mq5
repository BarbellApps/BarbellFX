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
   
   // Check signal expiry
   if(SignalExpiryMinutes > 0 && currentSignal.timestamp != "") {
      datetime signalTime = StringToTime(currentSignal.timestamp);
      if(TimeCurrent() - signalTime > SignalExpiryMinutes * 60) {
         Print("Signal expired");
         ResetSignal();
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

