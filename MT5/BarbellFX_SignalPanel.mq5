//+------------------------------------------------------------------+
//|                                         BarbellFX_SignalPanel.mq5 |
//|                                   Copyright 2024, BarbellFX       |
//|                 Displays pending signals from API on chart        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, BarbellFX"
#property link      "https://barbellfx.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input string   API_URL = "https://web-production-0617.up.railway.app/signal";
input int      RefreshSeconds = 10;
input int      PanelX = 20;
input int      PanelY = 50;
input color    PanelBgColor = clrBlack;
input color    BuyColor = clrLime;
input color    SellColor = clrRed;
input color    TextColor = clrWhite;
input color    GoldColor = clrGold;
input bool     ShowEntryZone = true;
input bool     ShowLevels = true;

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
datetime lastFetch = 0;
string signalPair = "";
string signalDirection = "";
double signalEntryMin = 0;
double signalEntryMax = 0;
double signalSL = 0;
double signalTP1 = 0;
double signalTP2 = 0;
double signalTPFull = 0;
double signalConfidence = 0;
string signalSetup = "";
string signalTimestamp = "";
bool hasSignal = false;

// Object names
string PREFIX = "BFX_";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit() {
   Print("BarbellFX Signal Panel Started");
   Print("Add URL to allowed list: Tools -> Options -> Expert Advisors");
   Print("URL: ", API_URL);
   
   // Initial fetch
   FetchSignal();
   
   // Set timer for refresh
   EventSetTimer(RefreshSeconds);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   EventKillTimer();
   DeleteAllObjects();
}

//+------------------------------------------------------------------+
//| Timer function                                                    |
//+------------------------------------------------------------------+
void OnTimer() {
   FetchSignal();
   DrawPanel();
   DrawLevels();
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                               |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {
   
   DrawPanel();
   DrawLevels();
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Fetch signal from API                                             |
//+------------------------------------------------------------------+
void FetchSignal() {
   string headers = "Content-Type: application/json\r\n";
   char post[];
   char result[];
   string result_headers;
   
   int res = WebRequest(
      "GET",
      API_URL,
      headers,
      5000,
      post,
      result,
      result_headers
   );
   
   if(res == -1) {
      int error = GetLastError();
      if(error == 4014) {
         Print("WebRequest not allowed - add URL to allowed list");
      }
      hasSignal = false;
      return;
   }
   
   if(res != 200) {
      hasSignal = false;
      return;
   }
   
   string response = CharArrayToString(result);
   ParseSignal(response);
   lastFetch = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Parse JSON signal                                                 |
//+------------------------------------------------------------------+
void ParseSignal(string json) {
   signalPair = GetJsonString(json, "pair");
   signalDirection = GetJsonString(json, "action");
   if(signalDirection == "") signalDirection = GetJsonString(json, "direction");
   
   signalEntryMin = GetJsonDouble(json, "entry_min");
   signalEntryMax = GetJsonDouble(json, "entry_max");
   signalSL = GetJsonDouble(json, "stop_loss");
   signalTP1 = GetJsonDouble(json, "tp1");
   signalTP2 = GetJsonDouble(json, "tp2");
   signalTPFull = GetJsonDouble(json, "tp_full");
   signalConfidence = GetJsonDouble(json, "confidence");
   signalSetup = GetJsonString(json, "setup");
   signalTimestamp = GetJsonString(json, "timestamp");
   
   hasSignal = (signalPair != "" && signalDirection != "" && signalEntryMin > 0);
   
   if(hasSignal) {
      StringToUpper(signalDirection);
   }
}

//+------------------------------------------------------------------+
//| Draw info panel on chart                                          |
//+------------------------------------------------------------------+
void DrawPanel() {
   int x = PanelX;
   int y = PanelY;
   int panelWidth = 280;
   int lineHeight = 18;
   
   // Background
   CreateRectangle(PREFIX + "BG", x-10, y-10, panelWidth+20, 320, PanelBgColor);
   
   // Header
   CreateLabel(PREFIX + "Header", x, y, "🔶 BARBELLFX SIGNAL", GoldColor, 12, true);
   y += lineHeight + 10;
   
   // Divider
   CreateLabel(PREFIX + "Div1", x, y, "━━━━━━━━━━━━━━━━━━━━━━━━━━", GoldColor, 8, false);
   y += lineHeight;
   
   if(!hasSignal) {
      CreateLabel(PREFIX + "NoSignal", x, y + 40, "📭 No Active Signal", TextColor, 10, false);
      CreateLabel(PREFIX + "Waiting", x, y + 60, "Waiting for GPT signal...", clrGray, 9, false);
      
      // Hide level lines
      ObjectDelete(0, PREFIX + "EntryZone");
      ObjectDelete(0, PREFIX + "SL_Line");
      ObjectDelete(0, PREFIX + "TP1_Line");
      ObjectDelete(0, PREFIX + "TP2_Line");
      ObjectDelete(0, PREFIX + "TPFull_Line");
      return;
   }
   
   // Direction
   bool isBuy = (signalDirection == "BUY");
   color dirColor = isBuy ? BuyColor : SellColor;
   
   CreateLabel(PREFIX + "Pair", x, y, signalPair, TextColor, 11, true);
   y += lineHeight;
   
   CreateLabel(PREFIX + "Direction", x, y, signalDirection, dirColor, 16, true);
   y += lineHeight + 15;
   
   // Entry Zone
   CreateLabel(PREFIX + "EntryLabel", x, y, "Entry Zone:", clrGray, 9, false);
   y += lineHeight;
   CreateLabel(PREFIX + "EntryValue", x, y, DoubleToString(signalEntryMin, _Digits) + " - " + DoubleToString(signalEntryMax, _Digits), GoldColor, 10, true);
   y += lineHeight + 10;
   
   // SL
   CreateLabel(PREFIX + "SLLabel", x, y, "Stop Loss:", clrGray, 9, false);
   CreateLabel(PREFIX + "SLValue", x + 100, y, DoubleToString(signalSL, _Digits), SellColor, 10, true);
   y += lineHeight;
   
   // TP1
   CreateLabel(PREFIX + "TP1Label", x, y, "TP1 (50%):", clrGray, 9, false);
   CreateLabel(PREFIX + "TP1Value", x + 100, y, DoubleToString(signalTP1, _Digits), BuyColor, 10, false);
   y += lineHeight;
   
   // TP2
   CreateLabel(PREFIX + "TP2Label", x, y, "TP2 (30%):", clrGray, 9, false);
   CreateLabel(PREFIX + "TP2Value", x + 100, y, DoubleToString(signalTP2, _Digits), BuyColor, 10, false);
   y += lineHeight;
   
   // Full TP
   CreateLabel(PREFIX + "TPFullLabel", x, y, "Full TP:", clrGray, 9, false);
   CreateLabel(PREFIX + "TPFullValue", x + 100, y, DoubleToString(signalTPFull, _Digits), BuyColor, 10, true);
   y += lineHeight + 10;
   
   // Divider
   CreateLabel(PREFIX + "Div2", x, y, "━━━━━━━━━━━━━━━━━━━━━━━━━━", GoldColor, 8, false);
   y += lineHeight;
   
   // Confidence
   double conf = signalConfidence <= 1 ? signalConfidence * 100 : signalConfidence;
   CreateLabel(PREFIX + "ConfLabel", x, y, "Confidence:", clrGray, 9, false);
   CreateLabel(PREFIX + "ConfValue", x + 100, y, DoubleToString(conf, 0) + "%", GoldColor, 10, true);
   y += lineHeight;
   
   // R:R
   double entryMid = (signalEntryMin + signalEntryMax) / 2;
   double risk = MathAbs(entryMid - signalSL);
   double reward = MathAbs(signalTPFull - entryMid);
   double rr = risk > 0 ? reward / risk : 0;
   CreateLabel(PREFIX + "RRLabel", x, y, "Risk:Reward:", clrGray, 9, false);
   CreateLabel(PREFIX + "RRValue", x + 100, y, "1:" + DoubleToString(rr, 1), BuyColor, 10, true);
   y += lineHeight + 10;
   
   // Setup
   if(signalSetup != "") {
      CreateLabel(PREFIX + "SetupLabel", x, y, "Setup:", clrGray, 9, false);
      y += lineHeight;
      string setup = StringLen(signalSetup) > 35 ? StringSubstr(signalSetup, 0, 35) + "..." : signalSetup;
      CreateLabel(PREFIX + "SetupValue", x, y, setup, TextColor, 9, false);
      y += lineHeight;
   }
   
   // Status
   y += 10;
   bool symbolMatch = SymbolMatches(signalPair, Symbol());
   double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   bool priceInZone = (currentPrice >= signalEntryMin && currentPrice <= signalEntryMax);
   
   color statusColor = (symbolMatch && priceInZone) ? BuyColor : (symbolMatch ? GoldColor : SellColor);
   string statusText = symbolMatch ? (priceInZone ? "✓ READY TO TRADE" : "⏳ Waiting for entry") : "✗ Wrong symbol";
   
   CreateLabel(PREFIX + "Status", x, y, statusText, statusColor, 10, true);
}

//+------------------------------------------------------------------+
//| Draw entry zone and levels on chart                               |
//+------------------------------------------------------------------+
void DrawLevels() {
   if(!hasSignal || !ShowLevels) return;
   if(!SymbolMatches(signalPair, Symbol())) return;
   
   datetime timeStart = iTime(Symbol(), PERIOD_CURRENT, 100);
   datetime timeEnd = iTime(Symbol(), PERIOD_CURRENT, 0) + PeriodSeconds() * 20;
   
   bool isBuy = (signalDirection == "BUY");
   
   // Entry Zone Rectangle
   if(ShowEntryZone) {
      ObjectDelete(0, PREFIX + "EntryZone");
      ObjectCreate(0, PREFIX + "EntryZone", OBJ_RECTANGLE, 0, timeStart, signalEntryMax, timeEnd, signalEntryMin);
      ObjectSetInteger(0, PREFIX + "EntryZone", OBJPROP_COLOR, GoldColor);
      ObjectSetInteger(0, PREFIX + "EntryZone", OBJPROP_FILL, true);
      ObjectSetInteger(0, PREFIX + "EntryZone", OBJPROP_BACK, true);
      ObjectSetInteger(0, PREFIX + "EntryZone", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, PREFIX + "EntryZone", OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, PREFIX + "EntryZone", OBJPROP_SELECTABLE, false);
      // Set transparency
      color zoneColor = isBuy ? BuyColor : SellColor;
      ObjectSetInteger(0, PREFIX + "EntryZone", OBJPROP_COLOR, zoneColor);
   }
   
   // SL Line
   ObjectDelete(0, PREFIX + "SL_Line");
   ObjectCreate(0, PREFIX + "SL_Line", OBJ_TREND, 0, timeStart, signalSL, timeEnd, signalSL);
   ObjectSetInteger(0, PREFIX + "SL_Line", OBJPROP_COLOR, SellColor);
   ObjectSetInteger(0, PREFIX + "SL_Line", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, PREFIX + "SL_Line", OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, PREFIX + "SL_Line", OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, PREFIX + "SL_Line", OBJPROP_SELECTABLE, false);
   
   // TP1 Line
   ObjectDelete(0, PREFIX + "TP1_Line");
   ObjectCreate(0, PREFIX + "TP1_Line", OBJ_TREND, 0, timeStart, signalTP1, timeEnd, signalTP1);
   ObjectSetInteger(0, PREFIX + "TP1_Line", OBJPROP_COLOR, BuyColor);
   ObjectSetInteger(0, PREFIX + "TP1_Line", OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, PREFIX + "TP1_Line", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, PREFIX + "TP1_Line", OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, PREFIX + "TP1_Line", OBJPROP_SELECTABLE, false);
   
   // TP2 Line
   ObjectDelete(0, PREFIX + "TP2_Line");
   ObjectCreate(0, PREFIX + "TP2_Line", OBJ_TREND, 0, timeStart, signalTP2, timeEnd, signalTP2);
   ObjectSetInteger(0, PREFIX + "TP2_Line", OBJPROP_COLOR, BuyColor);
   ObjectSetInteger(0, PREFIX + "TP2_Line", OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, PREFIX + "TP2_Line", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, PREFIX + "TP2_Line", OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, PREFIX + "TP2_Line", OBJPROP_SELECTABLE, false);
   
   // Full TP Line
   ObjectDelete(0, PREFIX + "TPFull_Line");
   ObjectCreate(0, PREFIX + "TPFull_Line", OBJ_TREND, 0, timeStart, signalTPFull, timeEnd, signalTPFull);
   ObjectSetInteger(0, PREFIX + "TPFull_Line", OBJPROP_COLOR, BuyColor);
   ObjectSetInteger(0, PREFIX + "TPFull_Line", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, PREFIX + "TPFull_Line", OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, PREFIX + "TPFull_Line", OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, PREFIX + "TPFull_Line", OBJPROP_SELECTABLE, false);
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Helper: Create label                                              |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int fontSize, bool bold) {
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
//| Helper: Create rectangle                                          |
//+------------------------------------------------------------------+
void CreateRectangle(string name, int x, int y, int width, int height, color clr) {
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Delete all objects                                                |
//+------------------------------------------------------------------+
void DeleteAllObjects() {
   ObjectsDeleteAll(0, PREFIX);
}

//+------------------------------------------------------------------+
//| Check if symbols match                                            |
//+------------------------------------------------------------------+
bool SymbolMatches(string sym1, string sym2) {
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
   
   int startPos = colonPos + 1;
   while(startPos < StringLen(json) && 
         (StringGetCharacter(json, startPos) == ' ' || 
          StringGetCharacter(json, startPos) == '"')) {
      startPos++;
   }
   
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

