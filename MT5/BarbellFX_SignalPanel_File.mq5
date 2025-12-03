//+------------------------------------------------------------------+
//|                                    BarbellFX_SignalPanel_File.mq5|
//|                                    Reads signals from local file |
//|                                    No WebRequest needed!         |
//+------------------------------------------------------------------+
#property copyright "BarbellFX"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

//--- Input parameters
input string   SignalFile = "barbellfx_signal.txt";  // Signal file in MQL5/Files/
input int      RefreshSeconds = 5;                    // Refresh interval
input color    PanelBg = clrBlack;
input color    PanelBorder = clrGold;
input color    TextColor = clrWhite;
input int      PanelX = 20;
input int      PanelY = 50;

//--- Signal data
string signalPair = "";
string signalAction = "";
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
datetime lastUpdate = 0;
datetime lastFileRead = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   Print("BarbellFX Signal Panel (File Mode) Started");
   Print("Reading signals from: MQL5/Files/", SignalFile);
   
   // Create panel objects
   CreatePanel();
   
   EventSetTimer(RefreshSeconds);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, "BBFX_");
}

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
                const int &spread[])
{
   return(rates_total);
}

//+------------------------------------------------------------------+
void OnTimer()
{
   ReadSignalFile();
   UpdatePanel();
}

//+------------------------------------------------------------------+
void ReadSignalFile()
{
   int handle = FileOpen(SignalFile, FILE_READ|FILE_TXT|FILE_ANSI);
   
   if(handle == INVALID_HANDLE) {
      hasSignal = false;
      return;
   }
   
   string content = "";
   while(!FileIsEnding(handle)) {
      content += FileReadString(handle) + "\n";
   }
   FileClose(handle);
   
   // Parse JSON-like content
   if(StringLen(content) < 10) {
      hasSignal = false;
      return;
   }
   
   // Simple parsing (expects format: pair,action,entry_min,entry_max,sl,tp1,tp2,tp_full,confidence,setup,timestamp)
   string parts[];
   int count = StringSplit(content, ',', parts);
   
   if(count >= 10) {
      signalPair = parts[0];
      signalAction = parts[1];
      signalEntryMin = StringToDouble(parts[2]);
      signalEntryMax = StringToDouble(parts[3]);
      signalSL = StringToDouble(parts[4]);
      signalTP1 = StringToDouble(parts[5]);
      signalTP2 = StringToDouble(parts[6]);
      signalTPFull = StringToDouble(parts[7]);
      signalConfidence = StringToDouble(parts[8]);
      signalSetup = parts[9];
      if(count > 10) signalTimestamp = parts[10];
      
      hasSignal = true;
      lastUpdate = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
void CreatePanel()
{
   // Background
   ObjectCreate(0, "BBFX_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_XDISTANCE, PanelX);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_YDISTANCE, PanelY);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_XSIZE, 280);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_YSIZE, 200);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_BGCOLOR, PanelBg);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_BORDER_COLOR, PanelBorder);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "BBFX_BG", OBJPROP_BACK, false);
   
   // Title
   CreateLabel("BBFX_Title", PanelX + 10, PanelY + 10, "◇ BARBELLFX SIGNAL", clrGold, 12);
   
   // Status
   CreateLabel("BBFX_Status", PanelX + 10, PanelY + 35, "Waiting for signal...", clrGray, 9);
   
   // Signal info labels
   CreateLabel("BBFX_Pair", PanelX + 10, PanelY + 60, "", TextColor, 10);
   CreateLabel("BBFX_Action", PanelX + 10, PanelY + 80, "", TextColor, 10);
   CreateLabel("BBFX_Entry", PanelX + 10, PanelY + 100, "", TextColor, 9);
   CreateLabel("BBFX_SL", PanelX + 10, PanelY + 120, "", clrRed, 9);
   CreateLabel("BBFX_TP", PanelX + 10, PanelY + 140, "", clrLime, 9);
   CreateLabel("BBFX_Conf", PanelX + 10, PanelY + 160, "", clrAqua, 9);
   CreateLabel("BBFX_Time", PanelX + 10, PanelY + 180, "", clrGray, 8);
}

//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int size)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

//+------------------------------------------------------------------+
void UpdatePanel()
{
   if(!hasSignal) {
      ObjectSetString(0, "BBFX_Status", OBJPROP_TEXT, "⬜ No Active Signal");
      ObjectSetInteger(0, "BBFX_Status", OBJPROP_COLOR, clrGray);
      ObjectSetString(0, "BBFX_Pair", OBJPROP_TEXT, "Reading: MQL5/Files/" + SignalFile);
      ObjectSetString(0, "BBFX_Action", OBJPROP_TEXT, "");
      ObjectSetString(0, "BBFX_Entry", OBJPROP_TEXT, "");
      ObjectSetString(0, "BBFX_SL", OBJPROP_TEXT, "");
      ObjectSetString(0, "BBFX_TP", OBJPROP_TEXT, "");
      ObjectSetString(0, "BBFX_Conf", OBJPROP_TEXT, "");
      ObjectSetString(0, "BBFX_Time", OBJPROP_TEXT, "");
      return;
   }
   
   // Update status
   ObjectSetString(0, "BBFX_Status", OBJPROP_TEXT, "🟢 SIGNAL ACTIVE");
   ObjectSetInteger(0, "BBFX_Status", OBJPROP_COLOR, clrLime);
   
   // Action color
   color actionColor = (signalAction == "BUY") ? clrLime : clrRed;
   
   // Update labels
   ObjectSetString(0, "BBFX_Pair", OBJPROP_TEXT, signalPair);
   ObjectSetInteger(0, "BBFX_Pair", OBJPROP_FONTSIZE, 14);
   
   ObjectSetString(0, "BBFX_Action", OBJPROP_TEXT, signalAction);
   ObjectSetInteger(0, "BBFX_Action", OBJPROP_COLOR, actionColor);
   ObjectSetInteger(0, "BBFX_Action", OBJPROP_FONTSIZE, 16);
   
   ObjectSetString(0, "BBFX_Entry", OBJPROP_TEXT, "Entry: " + DoubleToString(signalEntryMin, 5) + " - " + DoubleToString(signalEntryMax, 5));
   ObjectSetString(0, "BBFX_SL", OBJPROP_TEXT, "SL: " + DoubleToString(signalSL, 5));
   ObjectSetString(0, "BBFX_TP", OBJPROP_TEXT, "TP1: " + DoubleToString(signalTP1, 5) + " | Full: " + DoubleToString(signalTPFull, 5));
   ObjectSetString(0, "BBFX_Conf", OBJPROP_TEXT, "Confidence: " + DoubleToString(signalConfidence * 100, 0) + "%");
   ObjectSetString(0, "BBFX_Time", OBJPROP_TEXT, "Signal: " + signalTimestamp);
   
   // Draw levels if on matching symbol
   if(StringFind(Symbol(), signalPair) >= 0 || StringFind(signalPair, Symbol()) >= 0) {
      DrawLevels();
   }
}

//+------------------------------------------------------------------+
void DrawLevels()
{
   // Entry zone
   ObjectDelete(0, "BBFX_EntryZone");
   ObjectCreate(0, "BBFX_EntryZone", OBJ_RECTANGLE, 0, 
                TimeCurrent() - 100 * PeriodSeconds(), signalEntryMin,
                TimeCurrent() + 50 * PeriodSeconds(), signalEntryMax);
   ObjectSetInteger(0, "BBFX_EntryZone", OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, "BBFX_EntryZone", OBJPROP_FILL, true);
   ObjectSetInteger(0, "BBFX_EntryZone", OBJPROP_BACK, true);
   
   // SL line
   ObjectDelete(0, "BBFX_SL_Line");
   ObjectCreate(0, "BBFX_SL_Line", OBJ_HLINE, 0, 0, signalSL);
   ObjectSetInteger(0, "BBFX_SL_Line", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, "BBFX_SL_Line", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, "BBFX_SL_Line", OBJPROP_WIDTH, 2);
   
   // TP lines
   ObjectDelete(0, "BBFX_TP1_Line");
   ObjectCreate(0, "BBFX_TP1_Line", OBJ_HLINE, 0, 0, signalTP1);
   ObjectSetInteger(0, "BBFX_TP1_Line", OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, "BBFX_TP1_Line", OBJPROP_STYLE, STYLE_DOT);
   
   ObjectDelete(0, "BBFX_TPFull_Line");
   ObjectCreate(0, "BBFX_TPFull_Line", OBJ_HLINE, 0, 0, signalTPFull);
   ObjectSetInteger(0, "BBFX_TPFull_Line", OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, "BBFX_TPFull_Line", OBJPROP_WIDTH, 2);
}
//+------------------------------------------------------------------+

