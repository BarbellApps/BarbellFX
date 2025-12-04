//+------------------------------------------------------------------+
//|                                        BarbellFX_SignalTrader.mq5 |
//|                                   Copyright 2024, BarbellFX       |
//|                     Auto-trades signals from BarbellFX GPT API    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, BarbellFX"
#property link      "https://barbellfx.com"
#property version   "2.00"
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

// Dashboard Display Settings
input group "=== Dashboard Settings ==="
input int      PanelX = 20;                   // Panel X position
input int      PanelY = 50;                   // Panel Y position
input int      PanelWidth = 350;              // Panel width
input int      FontSizeTitle = 13;            // Title font size
input int      FontSizeHeader = 12;           // Header font size
input int      FontSizeNormal = 10;           // Normal text size
input int      LineSpacing = 20;              // Line spacing
input bool     ShowLotSize = true;            // Show calculated lot size
input bool     ShowMoneyInfo = true;          // Show TP/SL in money on chart
input bool     ShowPipsInfo = true;           // Show TP/SL in pips on chart
input int      ChartLabelFontSize = 9;        // Chart label font size (TP/SL info)
input int      LabelOffsetPips = 10;          // Label offset above line (pips)

// Chart Lines Settings
input group "=== Chart Lines Settings ==="
input color    EntryZoneColor = clrGold;      // Entry zone color
input bool     ShowEntryZone = true;          // Show entry zone rectangle
input color    SLLineColor = clrRed;          // Stop Loss line color
input int      SLLineWidth = 2;               // Stop Loss line width
input ENUM_LINE_STYLE SLLineStyle = STYLE_SOLID;  // Stop Loss line style
input color    TP1LineColor = clrLime;       // TP1 line color
input int      TP1LineWidth = 1;              // TP1 line width
input ENUM_LINE_STYLE TP1LineStyle = STYLE_DASH;  // TP1 line style
input color    TPFullLineColor = clrLime;     // Full TP line color
input int      TPFullLineWidth = 2;           // Full TP line width
input ENUM_LINE_STYLE TPFullLineStyle = STYLE_SOLID;  // Full TP line style
input color    LimitOrderLineColor = clrAqua; // Limit order line color
input int      LimitOrderLineWidth = 2;       // Limit order line width
input ENUM_LINE_STYLE LimitOrderLineStyle = STYLE_DOT;  // Limit order line style
input bool     ShowLimitOrderLine = true;     // Show limit order price line

// Order Type
input group "=== Order Settings ==="
input bool     UseLimitOrders = false;        // Use limit orders instead of market
input int      LimitOrderSlippage = 5;        // Limit order slippage (points)

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
CTrade         trade;
CPositionInfo  positionInfo;
COrderInfo     orderInfo;
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
   
   // Don't reset signal - keep current one if it exists
   // This prevents signal loss when changing settings or timeframe
   if(!currentSignal.valid) {
      Print("No active signal - fetching from API...");
   } else {
      Print("Keeping current signal: ", currentSignal.pair, " ", currentSignal.direction);
   }
   
   initialized = true;
   
   // Fetch new signal (will update if valid, otherwise keep current)
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
   int x = PanelX;
   int y = PanelY;
   int lineHeight = LineSpacing;
   
   // Calculate panel height based on content
   int panelHeight = currentSignal.valid ? 380 : 100;
   
   // Background
   ObjectDelete(0, "BBFX_BG");
   ObjectCreate(0, "BBFX_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_XDISTANCE, x - 10);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_YDISTANCE, y - 10);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_XSIZE, PanelWidth);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_YSIZE, panelHeight);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_BACK, false);
   
   // Header
   DrawLabel("BBFX_Header", x, y, "◆ BARBELLFX SIGNAL", clrGold, FontSizeTitle, true);
   y += lineHeight + 5;
   
   DrawLabel("BBFX_Divider", x, y, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", clrGold, FontSizeNormal - 2, false);
   y += lineHeight;
   
   if(!currentSignal.valid) {
      DrawLabel("BBFX_NoSignal", x, y, "⬜ No Active Signal", clrGray, FontSizeNormal, false);
      y += lineHeight;
      DrawLabel("BBFX_Waiting", x, y, "Waiting for GPT signal...", clrDimGray, FontSizeNormal - 1, false);
      // Hide other objects
      ObjectDelete(0, "BBFX_Pair");
      ObjectDelete(0, "BBFX_Dir");
      ObjectDelete(0, "BBFX_Entry");
      ObjectDelete(0, "BBFX_SL");
      ObjectDelete(0, "BBFX_TP");
      ObjectDelete(0, "BBFX_Conf");
      ObjectDelete(0, "BBFX_Status");
      ObjectDelete(0, "BBFX_LotSize");
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
   
   DrawLabel("BBFX_Pair", x, y, currentSignal.pair, clrWhite, FontSizeHeader, true);
   y += lineHeight;
   
   DrawLabel("BBFX_Dir", x, y, currentSignal.direction, dirColor, FontSizeHeader + 4, true);
   y += lineHeight + 10;
   
   DrawLabel("BBFX_EntryLbl", x, y, "Entry Zone:", clrGray, FontSizeNormal, false);
   y += lineHeight;
   DrawLabel("BBFX_Entry", x, y, DoubleToString(currentSignal.entry_min, _Digits) + " - " + DoubleToString(currentSignal.entry_max, _Digits), clrGold, FontSizeNormal, true);
   y += lineHeight + 5;
   
   DrawLabel("BBFX_SLLbl", x, y, "Stop Loss:", clrGray, FontSizeNormal, false);
   DrawLabel("BBFX_SL", x + PanelWidth/2, y, DoubleToString(currentSignal.stop_loss, _Digits), clrRed, FontSizeNormal, true);
   y += lineHeight;
   
   DrawLabel("BBFX_TP1Lbl", x, y, "TP1 (50%):", clrGray, FontSizeNormal, false);
   DrawLabel("BBFX_TP1", x + PanelWidth/2, y, DoubleToString(currentSignal.tp1, _Digits), clrLime, FontSizeNormal, false);
   y += lineHeight;
   
   DrawLabel("BBFX_TPFullLbl", x, y, "Full TP:", clrGray, FontSizeNormal, false);
   DrawLabel("BBFX_TPFull", x + PanelWidth/2, y, DoubleToString(currentSignal.tp_full, _Digits), clrLime, FontSizeNormal, true);
   y += lineHeight + 5;
   
   // Calculate and show lot size
   if(ShowLotSize && SymbolMatches(currentSignal.pair, Symbol())) {
      double entryMid = (currentSignal.entry_min + currentSignal.entry_max) / 2;
      double lotSize = CalculateLotSize(Symbol(), currentSignal.stop_loss, isBuy);
      if(lotSize > 0) {
         DrawLabel("BBFX_LotSizeLbl", x, y, "Lot Size:", clrGray, FontSizeNormal, false);
         DrawLabel("BBFX_LotSize", x + PanelWidth/2, y, DoubleToString(lotSize, 2) + " lots", clrAqua, FontSizeNormal, true);
         y += lineHeight;
      }
   }
   
   // Confidence & R:R
   double conf = currentSignal.confidence < 1 ? currentSignal.confidence * 100 : currentSignal.confidence;
   DrawLabel("BBFX_ConfLbl", x, y, "Confidence:", clrGray, FontSizeNormal, false);
   DrawLabel("BBFX_Conf", x + PanelWidth/2, y, DoubleToString(conf, 0) + "%", clrGold, FontSizeNormal, true);
   y += lineHeight;
   
   double entryMid = (currentSignal.entry_min + currentSignal.entry_max) / 2;
   double risk = MathAbs(entryMid - currentSignal.stop_loss);
   double reward = MathAbs(currentSignal.tp_full - entryMid);
   double rr = risk > 0 ? reward / risk : 0;
   DrawLabel("BBFX_RRLbl", x, y, "Risk:Reward:", clrGray, FontSizeNormal, false);
   DrawLabel("BBFX_RR", x + PanelWidth/2, y, "1:" + DoubleToString(rr, 1), clrLime, FontSizeNormal, true);
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
   
   DrawLabel("BBFX_Status", x, y, statusText, statusColor, FontSizeNormal, true);
   
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
   // Validate signal before drawing
   if(!currentSignal.valid || currentSignal.entry_min <= 0 || currentSignal.entry_max <= 0) {
      // Clear all objects if signal is invalid
      ObjectDelete(0, "BBFX_EntryZone");
      ObjectDelete(0, "BBFX_LimitOrderLine");
      ObjectDelete(0, "BBFX_LimitOrderLabel");
      ObjectDelete(0, "BBFX_SLLine");
      ObjectDelete(0, "BBFX_SLLabel");
      ObjectDelete(0, "BBFX_TP1Line");
      ObjectDelete(0, "BBFX_TP1Label");
      ObjectDelete(0, "BBFX_TPFullLine");
      ObjectDelete(0, "BBFX_TPFullLabel");
      return;
   }
   
   datetime timeStart = iTime(Symbol(), PERIOD_CURRENT, 50);
   datetime timeEnd = iTime(Symbol(), PERIOD_CURRENT, 0) + PeriodSeconds() * 20;
   
   bool isBuy = (currentSignal.direction == "BUY");
   double entryMid = (currentSignal.entry_min + currentSignal.entry_max) / 2;
   
   // Calculate lot size for money display
   double lotSize = CalculateLotSize(Symbol(), currentSignal.stop_loss, isBuy);
   
   // Calculate pips
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   double pipValue = (digits == 3 || digits == 5) ? point * 10 : point;
   
   // Entry Zone
   if(ShowEntryZone) {
      ObjectDelete(0, "BBFX_EntryZone");
      ObjectCreate(0, "BBFX_EntryZone", OBJ_RECTANGLE, 0, timeStart, currentSignal.entry_min, timeEnd, currentSignal.entry_max);
      ObjectSetInteger(0, "BBFX_EntryZone", OBJPROP_COLOR, EntryZoneColor);
      ObjectSetInteger(0, "BBFX_EntryZone", OBJPROP_FILL, true);
      ObjectSetInteger(0, "BBFX_EntryZone", OBJPROP_BACK, true);
   } else {
      ObjectDelete(0, "BBFX_EntryZone");
   }
   
   // Limit Order Price Line (if using limit orders)
   if(UseLimitOrders && ShowLimitOrderLine && currentSignal.valid) {
      double limitPrice = 0;
      
      if(isBuy) {
         limitPrice = NormalizeDouble(currentSignal.entry_min - (LimitOrderSlippage * point), digits);
      } else {
         limitPrice = NormalizeDouble(currentSignal.entry_max + (LimitOrderSlippage * point), digits);
      }
      
      // Validate limit price
      if(limitPrice > 0) {
         ObjectDelete(0, "BBFX_LimitOrderLine");
         ObjectCreate(0, "BBFX_LimitOrderLine", OBJ_HLINE, 0, 0, limitPrice);
         ObjectSetInteger(0, "BBFX_LimitOrderLine", OBJPROP_COLOR, LimitOrderLineColor);
         ObjectSetInteger(0, "BBFX_LimitOrderLine", OBJPROP_WIDTH, LimitOrderLineWidth);
         ObjectSetInteger(0, "BBFX_LimitOrderLine", OBJPROP_STYLE, LimitOrderLineStyle);
         
         // Label for limit order price
         double labelOffset = LabelOffsetPips * pipValue;
         double labelPrice = limitPrice + (isBuy ? labelOffset : -labelOffset);
         
         ObjectDelete(0, "BBFX_LimitOrderLabel");
         ObjectCreate(0, "BBFX_LimitOrderLabel", OBJ_TEXT, 0, timeEnd, labelPrice);
         ObjectSetString(0, "BBFX_LimitOrderLabel", OBJPROP_TEXT, "LIMIT: " + DoubleToString(limitPrice, _Digits));
         ObjectSetInteger(0, "BBFX_LimitOrderLabel", OBJPROP_COLOR, LimitOrderLineColor);
         ObjectSetInteger(0, "BBFX_LimitOrderLabel", OBJPROP_FONTSIZE, ChartLabelFontSize);
         ObjectSetInteger(0, "BBFX_LimitOrderLabel", OBJPROP_ANCHOR, ANCHOR_LEFT);
      } else {
         ObjectDelete(0, "BBFX_LimitOrderLine");
         ObjectDelete(0, "BBFX_LimitOrderLabel");
      }
   } else {
      ObjectDelete(0, "BBFX_LimitOrderLine");
      ObjectDelete(0, "BBFX_LimitOrderLabel");
   }
   
   // SL Line with info
   ObjectDelete(0, "BBFX_SLLine");
   ObjectCreate(0, "BBFX_SLLine", OBJ_HLINE, 0, 0, currentSignal.stop_loss);
   ObjectSetInteger(0, "BBFX_SLLine", OBJPROP_COLOR, SLLineColor);
   ObjectSetInteger(0, "BBFX_SLLine", OBJPROP_WIDTH, SLLineWidth);
   ObjectSetInteger(0, "BBFX_SLLine", OBJPROP_STYLE, SLLineStyle);
   
   // SL Label with pips and money (positioned ABOVE the line)
   if(ShowPipsInfo || ShowMoneyInfo) {
      double slDistance = MathAbs(entryMid - currentSignal.stop_loss);
      double slPips = slDistance / pipValue;
      
      string slText = "SL: " + DoubleToString(currentSignal.stop_loss, _Digits);
      if(ShowPipsInfo) slText += " | " + DoubleToString(slPips, 1) + " pips";
      if(ShowMoneyInfo && lotSize > 0) {
         double slMoney = CalculateMoneyAtPrice(Symbol(), lotSize, entryMid, currentSignal.stop_loss, isBuy);
         slText += " | $" + DoubleToString(MathAbs(slMoney), 2);
      }
      
      // Position label ABOVE the line (add offset in price)
      double labelOffset = LabelOffsetPips * pipValue;
      double slLabelPrice = currentSignal.stop_loss + labelOffset;
      
      ObjectDelete(0, "BBFX_SLLabel");
      ObjectCreate(0, "BBFX_SLLabel", OBJ_TEXT, 0, timeEnd, slLabelPrice);
      ObjectSetString(0, "BBFX_SLLabel", OBJPROP_TEXT, slText);
      ObjectSetInteger(0, "BBFX_SLLabel", OBJPROP_COLOR, SLLineColor);
      ObjectSetInteger(0, "BBFX_SLLabel", OBJPROP_FONTSIZE, ChartLabelFontSize);
      ObjectSetInteger(0, "BBFX_SLLabel", OBJPROP_ANCHOR, ANCHOR_LEFT);
   }
   
   // TP1 Line
   ObjectDelete(0, "BBFX_TP1Line");
   ObjectCreate(0, "BBFX_TP1Line", OBJ_HLINE, 0, 0, currentSignal.tp1);
   ObjectSetInteger(0, "BBFX_TP1Line", OBJPROP_COLOR, TP1LineColor);
   ObjectSetInteger(0, "BBFX_TP1Line", OBJPROP_WIDTH, TP1LineWidth);
   ObjectSetInteger(0, "BBFX_TP1Line", OBJPROP_STYLE, TP1LineStyle);
   
   // TP1 Label (positioned ABOVE the line)
   if(ShowPipsInfo || ShowMoneyInfo) {
      double tp1Distance = MathAbs(currentSignal.tp1 - entryMid);
      double tp1Pips = tp1Distance / pipValue;
      
      string tp1Text = "TP1: " + DoubleToString(currentSignal.tp1, _Digits);
      if(ShowPipsInfo) tp1Text += " | " + DoubleToString(tp1Pips, 1) + " pips";
      if(ShowMoneyInfo && lotSize > 0) {
         double tp1Money = CalculateMoneyAtPrice(Symbol(), lotSize * TP1_ClosePercent / 100, entryMid, currentSignal.tp1, isBuy);
         tp1Text += " | $" + DoubleToString(tp1Money, 2);
      }
      
      // Position label ABOVE the line (add offset in price)
      double labelOffset = LabelOffsetPips * pipValue;
      double tp1LabelPrice = currentSignal.tp1 + labelOffset;
      
      ObjectDelete(0, "BBFX_TP1Label");
      ObjectCreate(0, "BBFX_TP1Label", OBJ_TEXT, 0, timeEnd, tp1LabelPrice);
      ObjectSetString(0, "BBFX_TP1Label", OBJPROP_TEXT, tp1Text);
      ObjectSetInteger(0, "BBFX_TP1Label", OBJPROP_COLOR, TP1LineColor);
      ObjectSetInteger(0, "BBFX_TP1Label", OBJPROP_FONTSIZE, ChartLabelFontSize);
      ObjectSetInteger(0, "BBFX_TP1Label", OBJPROP_ANCHOR, ANCHOR_LEFT);
   }
   
   // Full TP Line with info
   ObjectDelete(0, "BBFX_TPFullLine");
   ObjectCreate(0, "BBFX_TPFullLine", OBJ_HLINE, 0, 0, currentSignal.tp_full);
   ObjectSetInteger(0, "BBFX_TPFullLine", OBJPROP_COLOR, TPFullLineColor);
   ObjectSetInteger(0, "BBFX_TPFullLine", OBJPROP_WIDTH, TPFullLineWidth);
   ObjectSetInteger(0, "BBFX_TPFullLine", OBJPROP_STYLE, TPFullLineStyle);
   
   // Full TP Label (positioned ABOVE the line)
   if(ShowPipsInfo || ShowMoneyInfo) {
      double tpFullDistance = MathAbs(currentSignal.tp_full - entryMid);
      double tpFullPips = tpFullDistance / pipValue;
      
      string tpFullText = "TP Full: " + DoubleToString(currentSignal.tp_full, _Digits);
      if(ShowPipsInfo) tpFullText += " | " + DoubleToString(tpFullPips, 1) + " pips";
      if(ShowMoneyInfo && lotSize > 0) {
         double tpFullMoney = CalculateMoneyAtPrice(Symbol(), lotSize, entryMid, currentSignal.tp_full, isBuy);
         tpFullText += " | $" + DoubleToString(tpFullMoney, 2);
      }
      
      // Position label ABOVE the line (add offset in price)
      double labelOffset = LabelOffsetPips * pipValue;
      double tpFullLabelPrice = currentSignal.tp_full + labelOffset;
      
      ObjectDelete(0, "BBFX_TPFullLabel");
      ObjectCreate(0, "BBFX_TPFullLabel", OBJ_TEXT, 0, timeEnd, tpFullLabelPrice);
      ObjectSetString(0, "BBFX_TPFullLabel", OBJPROP_TEXT, tpFullText);
      ObjectSetInteger(0, "BBFX_TPFullLabel", OBJPROP_COLOR, TPFullLineColor);
      ObjectSetInteger(0, "BBFX_TPFullLabel", OBJPROP_FONTSIZE, ChartLabelFontSize);
      ObjectSetInteger(0, "BBFX_TPFullLabel", OBJPROP_ANCHOR, ANCHOR_LEFT);
   }
}

//+------------------------------------------------------------------+
//| Calculate money at price level                                    |
//+------------------------------------------------------------------+
double CalculateMoneyAtPrice(string symbol, double lots, double entryPrice, double exitPrice, bool isBuy) {
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   if(tickSize == 0 || tickValue == 0 || point == 0) return 0;
   
   double priceDiff = MathAbs(exitPrice - entryPrice);
   double ticks = priceDiff / tickSize;
   double profit = ticks * tickValue * lots;
   
   // Adjust for buy/sell direction
   if((isBuy && exitPrice < entryPrice) || (!isBuy && exitPrice > entryPrice)) {
      profit = -profit;
   }
   
   return profit;
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
   
   // Update visual panel (always try to draw, even if signal invalid)
   // DrawPanel will call DrawLevels if symbol matches
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
   } else {
      // API returned empty/invalid signal - keep current signal if it exists
      if(currentSignal.valid) {
         Print("API returned empty signal - keeping current signal: ", currentSignal.pair, " ", currentSignal.direction);
      }
      // Don't update currentSignal - keep the existing one
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
   
   // Check price position relative to entry zone
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double currentPrice = isBuy ? ask : bid;
   bool priceInZone = (currentPrice >= currentSignal.entry_min && currentPrice <= currentSignal.entry_max);
   
   // For market orders: only place when price is in entry zone
   // For limit orders: place immediately (order will execute when price reaches zone)
   if(!UseLimitOrders && !priceInZone) {
      // Market order: price not in entry zone - wait
      return;
   }
   
   // For limit orders: check if we already have a pending order for this signal
   if(UseLimitOrders) {
      Print("=== PROCESSING LIMIT ORDER ===");
      Print("Symbol: ", symbol);
      Print("Direction: ", isBuy ? "BUY" : "SELL");
      Print("Entry Zone: ", currentSignal.entry_min, " - ", currentSignal.entry_max);
      Print("Current Price: ", currentPrice);
      
      if(HasPendingOrder(symbol, isBuy)) {
         Print("Pending limit order already exists for this signal");
         return;
      }
      Print("No pending order found - proceeding to place limit order...");
   }
   
   // Calculate lot size
   double lotSize = CalculateLotSize(symbol, currentSignal.stop_loss, isBuy);
   if(lotSize <= 0) {
      Print("Invalid lot size calculated");
      return;
   }
   
   Print("Calculated lot size: ", lotSize);
   
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
   
   // Get symbol properties
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   // Calculate pip value (for 3/5 digit pairs, pip = point * 10)
   double pipSize = (digits == 3 || digits == 5) ? point * 10 : point;
   
   // Calculate pip value per lot (money per pip per lot)
   // For Gold: 1 lot = $10 per pip
   // For Forex: depends on the pair and account currency
   double pipValuePerLot = 0;
   
   // Check if it's Gold
   string symbolUpper = symbol;
   StringToUpper(symbolUpper);
   bool isGold = StringFind(symbolUpper, "XAU") >= 0 || StringFind(symbolUpper, "GOLD") >= 0;
   
   if(isGold) {
      // Gold: 1 lot = $10 per pip (standard)
      pipValuePerLot = 10.0;
   } else {
      // For forex pairs, calculate based on tick value
      // pipValuePerLot = tickValue * (pipSize / tickSize)
      if(tickSize > 0) {
         pipValuePerLot = tickValue * (pipSize / tickSize);
      } else {
         pipValuePerLot = 0;
      }
   }
   
   if(pipValuePerLot <= 0) {
      Print("Invalid pip value per lot for symbol: ", symbol);
      return 0;
   }
   
   // Calculate pips in SL distance
   double slPips = slDistance / pipSize;
   
   // Calculate lot size: Risk Amount / (SL Pips * Pip Value Per Lot)
   double lotSize = riskAmount / (slPips * pipValuePerLot);
   
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
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   double price;
   
   if(UseLimitOrders) {
      // For limit orders:
      // BUY limit: place at entry_min (or slightly below) - we buy when price drops to this level
      // SELL limit: place at entry_max (or slightly above) - we sell when price rises to this level
      if(isBuy) {
         // BUY limit: place at entry_min, adjusted down by slippage
         price = NormalizeDouble(currentSignal.entry_min - (LimitOrderSlippage * point), digits);
         Print("BUY Limit Order - Entry Min: ", currentSignal.entry_min, ", Limit Price: ", price);
      } else {
         // SELL limit: place at entry_max, adjusted up by slippage
         price = NormalizeDouble(currentSignal.entry_max + (LimitOrderSlippage * point), digits);
         Print("SELL Limit Order - Entry Max: ", currentSignal.entry_max, ", Limit Price: ", price);
      }
      
      // Validate limit order price
      double currentBid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double currentAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
      
      if(isBuy && price >= currentAsk) {
         Print("WARNING: BUY limit price (", price, ") >= current Ask (", currentAsk, "). Adjusting to entry_min.");
         price = NormalizeDouble(currentSignal.entry_min, digits);
      }
      if(!isBuy && price <= currentBid) {
         Print("WARNING: SELL limit price (", price, ") <= current Bid (", currentBid, "). Adjusting to entry_max.");
         price = NormalizeDouble(currentSignal.entry_max, digits);
      }
   } else {
      // Use market order at current price
      price = isBuy ? 
         SymbolInfoDouble(symbol, SYMBOL_ASK) : 
         SymbolInfoDouble(symbol, SYMBOL_BID);
      price = NormalizeDouble(price, digits);
   }
   
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
   
   string comment = "BarbellFX|" + currentSignal.setup;
   if(StringLen(comment) > 31) comment = StringSubstr(comment, 0, 31);
   
   bool success = false;
   
   if(UseLimitOrders) {
      // Validate price before placing order
      if(price <= 0) {
         Print("ERROR: Invalid limit order price: ", price);
         return;
      }
      
      Print("Placing limit order - Price: ", price, ", SL: ", sl, ", TP: ", tp, ", Lots: ", lots);
      
      if(isBuy) {
         // BUY Limit: price must be below current Ask
         double currentAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
         if(price >= currentAsk) {
            Print("ERROR: BUY limit price (", price, ") must be below current Ask (", currentAsk, ")");
            Print("Adjusting limit price to entry_min");
            price = NormalizeDouble(currentSignal.entry_min, digits);
            if(price >= currentAsk) {
               Print("ERROR: Even entry_min (", price, ") is >= Ask. Cannot place BUY limit.");
               return;
            }
         }
         // Use ORDER_TIME_GTC (Good Till Canceled) - order stays until filled or manually deleted
         success = trade.BuyLimit(lots, price, symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
      } else {
         // SELL Limit: price must be above current Bid
         double currentBid = SymbolInfoDouble(symbol, SYMBOL_BID);
         if(price <= currentBid) {
            Print("ERROR: SELL limit price (", price, ") must be above current Bid (", currentBid, ")");
            Print("Adjusting limit price to entry_max");
            price = NormalizeDouble(currentSignal.entry_max, digits);
            if(price <= currentBid) {
               Print("ERROR: Even entry_max (", price, ") is <= Bid. Cannot place SELL limit.");
               return;
            }
         }
         // Use ORDER_TIME_GTC (Good Till Canceled) - order stays until filled or manually deleted
         success = trade.SellLimit(lots, price, symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
      }
   } else {
      // Place market order
      if(isBuy) {
         success = trade.Buy(lots, symbol, price, sl, tp, comment);
      } else {
         success = trade.Sell(lots, symbol, price, sl, tp, comment);
      }
   }
   
   if(success) {
      Print("=== TRADE OPENED ===");
      Print("Symbol: ", symbol);
      Print("Type: ", UseLimitOrders ? "LIMIT" : "MARKET");
      Print("Direction: ", isBuy ? "BUY" : "SELL");
      Print("Lots: ", lots);
      Print("Price: ", price);
      Print("SL: ", sl);
      Print("TP: ", tp);
      Print("====================");
      
      // For market orders: reset signal immediately (trade is executed)
      // For limit orders: keep signal active (order is pending, signal should stay visible)
      if(!UseLimitOrders) {
         ResetSignal();
      } else {
         Print("Limit order placed - keeping signal active until order executes");
      }
   } else {
      int errorCode = trade.ResultRetcode();
      string errorDesc = trade.ResultRetcodeDescription();
      Print("========================================");
      Print("TRADE FAILED!");
      Print("Error Code: ", errorCode);
      Print("Error Description: ", errorDesc);
      Print("Symbol: ", symbol);
      Print("Type: ", UseLimitOrders ? "LIMIT" : "MARKET");
      Print("Direction: ", isBuy ? "BUY" : "SELL");
      Print("Price: ", price);
      Print("Lots: ", lots);
      Print("========================================");
      
      // Don't reset signal on failure - keep it visible so user can see the issue
      // Signal will be cleared when a new signal arrives or manually
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

//+------------------------------------------------------------------+
//| Check if pending order exists for symbol and direction            |
//+------------------------------------------------------------------+
bool HasPendingOrder(string symbol, bool isBuy) {
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(orderInfo.SelectByIndex(i)) {
         if(orderInfo.Magic() == MagicNumber) {
            if(SymbolMatches(orderInfo.Symbol(), symbol)) {
               ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)orderInfo.OrderType();
               // Check if it's a limit order matching our direction
               if(isBuy && (orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP)) {
                  Print("Found existing BUY limit order: Ticket ", orderInfo.Ticket(), " at price ", orderInfo.PriceOpen());
                  return true;
               }
               if(!isBuy && (orderType == ORDER_TYPE_SELL_LIMIT || orderType == ORDER_TYPE_SELL_STOP)) {
                  Print("Found existing SELL limit order: Ticket ", orderInfo.Ticket(), " at price ", orderInfo.PriceOpen());
                  return true;
               }
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

