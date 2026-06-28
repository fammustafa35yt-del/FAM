//+------------------------------------------------------------------+
//|                                                 FX.FAM35PRO.mq5    |
//|        FX.FAM35PRO - Elliott-Wave Gold (XAU) Expert Advisor (MT5)  |
//|                                                                   |
//|  Built to spec:                                                   |
//|   - Works on every gold symbol naming (XAUUSD, GOLD, XAUUSDm ...) |
//|   - Elliott-Wave style structural analysis (swing/pivot engine)   |
//|   - Fast trend detection + adaptive bias (chart TF + higher TF)   |
//|   - Money / risk management (fixed lot per leg OR risk %)         |
//|   - Works on every timeframe                                      |
//|   - Scalp + Swing trade styles (user selectable, live)            |
//|   - 1/3 staged entry: opens THREE legs (e.g. 0.01 x3)             |
//|       * shared stop (e.g. 50 pips)                                |
//|       * TP1 / TP2 / TP3 (e.g. 100 / 200 / 300 pips)              |
//|       * profit is locked forward as each target is reached        |
//|   - No random entries: multi-confluence "studied" entries only    |
//|   - Reverses: closes on trend flip and re-enters the new side     |
//|   - Trailing stop-loss that follows the trade                     |
//|   - Personal control: Scalp / Swing / Both                        |
//|   - Personal control: trend focus Up / Down / Both                |
//|   - Personal control: take Buy / Sell / Both                      |
//|   - On-chart dashboard (status, trades, wins, losses, P/L)        |
//+------------------------------------------------------------------+
#property copyright "FX.FAM35PRO"
#property version   "2.00"
#property description "FX.FAM35PRO - Gold Elliott-Wave EA: Scalp/Swing, 3-leg staged entries (1/3), shared SL + TP1/TP2/TP3, forward profit lock, trailing SL, reversal flip, dashboard."

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//==================== ENUMS ====================
enum ENUM_BOT_STYLE
  {
   STYLE_SCALP = 0,   // Scalp only / سكالب فقط
   STYLE_SWING = 1,   // Swing only / سوينغ فقط
   STYLE_BOTH  = 2    // Scalp + Swing / كلاهما
  };

enum ENUM_TREND_FOCUS
  {
   FOCUS_UP   = 0,    // Up trend only / صعود فقط
   FOCUS_DOWN = 1,    // Down trend only / هبوط فقط
   FOCUS_BOTH = 2     // Both / كلاهما
  };

enum ENUM_ORDER_SIDE
  {
   SIDE_BUY  = 0,     // Buy only / شراء فقط
   SIDE_SELL = 1,     // Sell only / بيع فقط
   SIDE_BOTH = 2      // Both / كلاهما
  };

enum ENUM_MM_MODE
  {
   MM_FIXED_LOT    = 0, // Fixed lot per leg / حجم ثابت لكل رجل
   MM_RISK_PERCENT = 1  // Risk % of balance (split over 3 legs) / نسبة مخاطرة
  };

//==================== INPUTS ====================
input group             "=== General / عام ==="
input long              InpMagic           = 350035;     // Magic number
input string            InpForceSymbol     = "";         // Force symbol (empty = chart symbol)
input bool              InpTradingEnabled  = true;       // Enable trading on start

input group             "=== Personal Control / تحكم شخصي ==="
input ENUM_BOT_STYLE    InpStyle           = STYLE_BOTH; // Style: Scalp / Swing / Both
input ENUM_TREND_FOCUS  InpTrendFocus      = FOCUS_BOTH; // Trend focus: Up / Down / Both
input ENUM_ORDER_SIDE   InpOrderSide       = SIDE_BOTH;  // Take orders: Buy / Sell / Both
input bool              InpCloseOnControlChange = true;  // Close trades that violate focus/side

input group             "=== 3-Leg Staged Entry (1/3) / دخول ثلاثي ==="
input double            InpLegLot          = 0.01;       // Lot per leg (entered 3 times)
input int               InpLegsPerTrade    = 3;          // Number of legs per trade (default 3)
input int               InpMaxTradeGroups  = 1;          // Max concurrent trade groups (3 legs each)
input bool              InpUseStructureSL  = true;       // SL/targets from market structure (R-multiples)
input double            InpPointsPerPip    = 10;         // Points per "pip" for gold (50 pips=500 pts)

input group             "=== Targets (R-multiples when structure SL) ==="
input double            InpTP1_R           = 2.0;        // TP1 distance in R (leg 1)
input double            InpTP2_R           = 4.0;        // TP2 distance in R (leg 2)
input double            InpTP3_R           = 6.0;        // TP3 distance in R (leg 3)

input group             "=== Targets (fixed pips when structure SL = false) ==="
input double            InpSLPips          = 50;         // Shared Stop Loss (pips)
input double            InpTP1Pips         = 100;        // TP1 (pips)  - leg 1
input double            InpTP2Pips         = 200;        // TP2 (pips)  - leg 2
input double            InpTP3Pips         = 300;        // TP3 (pips)  - leg 3

input group             "=== Money Management / إدارة رأس المال ==="
input ENUM_MM_MODE      InpMMMode          = MM_FIXED_LOT;   // Lot mode (per leg)
input double            InpRiskPercent     = 1.5;        // Total risk % over the 3 legs (risk mode)
input double            InpMaxLotPerLeg    = 5.0;        // Max lot per leg cap
input double            InpMaxSpreadPoints = 60;         // Max allowed spread (points), 0 = ignore
input double            InpMaxDailyLossPct = 0.0;        // Stop trading if daily loss >= % (0=off)

input group             "=== Stop Loss / Trailing / إدارة الوقف ==="
input bool              InpLockProfitSteps = true;       // Move SL forward as each target hits
input double            InpBELockPips      = 2;          // Extra lock beyond break-even (pips)
input bool              InpUseTrailing     = true;       // Trailing stop follows the trade
input double            InpTrailStartR     = 1.0;        // Start trailing after profit >= R
input double            InpTrailATRMult    = 2.0;        // Trailing distance = ATR * mult
input bool              InpCloseOnReversal = true;       // Close trade on trend reversal
input bool              InpReenterOnReversal = true;     // After reversal close, enter the new side

input group             "=== Strategy / Wave Engine ==="
input ENUM_TIMEFRAMES   InpSwingTF         = PERIOD_H4;  // Higher TF for swing trend bias
input int               InpFastEMA         = 21;         // Fast EMA
input int               InpSlowEMA         = 50;         // Slow EMA
input int               InpTrendEMA        = 200;        // Trend filter EMA
input int               InpADXPeriod       = 14;         // ADX period
input double            InpADXMinScalp     = 18.0;       // Min ADX for scalp
input double            InpADXMinSwing     = 22.0;       // Min ADX for swing
input int               InpRSIPeriod       = 14;         // RSI period
input int               InpATRPeriod       = 14;         // ATR period
input int               InpFractalScalp    = 2;          // Pivot half-width (scalp)
input int               InpFractalSwing    = 3;          // Pivot half-width (swing)
input int               InpPivotLookback   = 120;        // Bars to scan for pivots
input int               InpMaxPullbackBars = 25;         // Max bars since pullback pivot (freshness)
input double            InpSLBufferATR     = 0.5;        // SL buffer beyond pivot = ATR * this
input double            InpMaxRiskATR      = 6.0;        // Reject signal if R > ATR * this

input group             "=== Dashboard / لوحة المعلومات ==="
input bool              InpShowPanel       = true;       // Show dashboard panel
input int               InpPanelX          = 15;         // Panel X (px from left)
input int               InpPanelY          = 25;         // Panel Y (px from top)
input color             InpPanelBg         = C'18,22,33';// Panel background
input color             InpTextColor       = clrWhite;   // Default text color
input int               InpFontSize        = 9;          // Font size

//==================== GLOBALS ====================
CTrade        g_trade;
CPositionInfo g_posinfo;

string g_sym;                 // working symbol
string g_botName = "FX.FAM35PRO";

// runtime-changeable control state (toggled from the panel buttons)
ENUM_BOT_STYLE     g_style;
ENUM_TREND_FOCUS   g_focus;
ENUM_ORDER_SIDE    g_side;
bool               g_paused = false;

// indicator handles
int h_fast=-1, h_slow=-1, h_trend=-1, h_adx=-1, h_rsi=-1, h_atr=-1, h_emaHTF=-1;

// symbol meta
double g_point, g_tickSize, g_tickValue, g_volMin, g_volMax, g_volStep, g_stopLevelPts;
int    g_digits, g_volDigits;
double g_pip;                 // price value of one "pip"

datetime g_lastBarTime = 0;
long     g_groupSeq = 0;      // increasing id for trade groups

//==================== TRADE GROUP STATE ====================
struct SLeg
  {
   ulong  ticket;
   int    targetIdx;   // 0,1,2 -> TP1,TP2,TP3
   double tp;
   bool   closed;
  };

struct SGroup
  {
   long   id;
   int    dir;          // +1 buy, -1 sell
   double entry;
   double slPrice;      // original shared stop
   double R;            // 1R risk distance (price)
   double tp[3];        // target prices
   SLeg   legs[];       // open legs
   int    profitClosed; // count of legs closed in profit (advances the lock)
  };
SGroup g_groups[];

// cached statistics for the dashboard
struct SStats
  {
   int    openLegs;
   int    openGroups;
   int    closedTrades;  // closed legs (deals out)
   int    wins;
   int    losses;
   double grossProfit;
   double grossLoss;     // stored as positive number
   double netClosed;
   double floating;
   double todayPL;
  };
SStats g_stats;

string g_panelPrefix = "FAM35PRO_";

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
int VolumeDigitsFromStep(double step)
  {
   int d=0; double s=step;
   while(s < 1.0 && d < 8){ s*=10.0; d++; }
   return(d);
  }

double NormalizeVolumeDown(double vol)
  {
   if(g_volStep<=0) return(vol);
   double v = MathFloor(vol/g_volStep)*g_volStep;
   return(NormalizeDouble(v, g_volDigits));
  }

double NormalizePrice(double price)
  {
   return(NormalizeDouble(price, g_digits));
  }

double IndVal(int handle,int buffer,int shift)
  {
   if(handle==INVALID_HANDLE || handle<0) return(0.0);
   double b[];
   if(CopyBuffer(handle,buffer,shift,1,b)<=0) return(0.0);
   return(b[0]);
  }

bool LooksLikeGold(const string s)
  {
   string u=s; StringToUpper(u);
   return(StringFind(u,"XAU")>=0 || StringFind(u,"GOLD")>=0);
  }

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_sym = (StringLen(InpForceSymbol)>0 ? InpForceSymbol : _Symbol);

   if(!SymbolSelect(g_sym,true))
     {
      Print(g_botName,": cannot select symbol ",g_sym);
      return(INIT_FAILED);
     }

   if(!LooksLikeGold(g_sym))
      Print(g_botName,": WARNING - '",g_sym,"' does not look like a gold symbol. The EA is tuned for gold (XAU).");

   // control state
   g_style  = InpStyle;
   g_focus  = InpTrendFocus;
   g_side   = InpOrderSide;
   g_paused = !InpTradingEnabled;

   // symbol meta
   g_point     = SymbolInfoDouble(g_sym,SYMBOL_POINT);
   g_digits    = (int)SymbolInfoInteger(g_sym,SYMBOL_DIGITS);
   g_tickSize  = SymbolInfoDouble(g_sym,SYMBOL_TRADE_TICK_SIZE);
   g_tickValue = SymbolInfoDouble(g_sym,SYMBOL_TRADE_TICK_VALUE);
   g_volMin    = SymbolInfoDouble(g_sym,SYMBOL_VOLUME_MIN);
   g_volMax    = SymbolInfoDouble(g_sym,SYMBOL_VOLUME_MAX);
   g_volStep   = SymbolInfoDouble(g_sym,SYMBOL_VOLUME_STEP);
   g_volDigits = VolumeDigitsFromStep(g_volStep);
   g_stopLevelPts = (double)SymbolInfoInteger(g_sym,SYMBOL_TRADE_STOPS_LEVEL);
   if(g_tickSize<=0) g_tickSize=g_point;
   g_pip = (InpPointsPerPip>0 ? InpPointsPerPip : 10.0) * g_point;

   // indicator handles on chart TF
   h_fast  = iMA(g_sym,_Period,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);
   h_slow  = iMA(g_sym,_Period,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);
   h_trend = iMA(g_sym,_Period,InpTrendEMA,0,MODE_EMA,PRICE_CLOSE);
   h_adx   = iADX(g_sym,_Period,InpADXPeriod);
   h_rsi   = iRSI(g_sym,_Period,InpRSIPeriod,PRICE_CLOSE);
   h_atr   = iATR(g_sym,_Period,InpATRPeriod);
   h_emaHTF= iMA(g_sym,InpSwingTF,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);

   if(h_fast==INVALID_HANDLE || h_slow==INVALID_HANDLE || h_trend==INVALID_HANDLE ||
      h_adx==INVALID_HANDLE  || h_rsi==INVALID_HANDLE  || h_atr==INVALID_HANDLE   ||
      h_emaHTF==INVALID_HANDLE)
     {
      Print(g_botName,": failed to create indicator handles");
      return(INIT_FAILED);
     }

   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetMarginMode();
   g_trade.SetTypeFillingBySymbol(g_sym);
   g_trade.SetDeviationInPoints(30);

   // The 3-leg model needs a HEDGING account: in NETTING mode the three legs
   // merge into one position with a single TP, so staged targets won't work.
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      Print(g_botName,": WARNING - account is NETTING. The 3-leg staged entry needs a HEDGING account; "
            "legs will merge into one position. Use a hedging account or set InpLegsPerTrade=1.");

   RebuildGroupsFromOpenPositions();

   if(InpShowPanel) CreatePanel();
   EventSetTimer(1);

   Print(g_botName," initialized on ",g_sym," / ",EnumToString((ENUM_TIMEFRAMES)_Period));
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(h_fast!=INVALID_HANDLE)  IndicatorRelease(h_fast);
   if(h_slow!=INVALID_HANDLE)  IndicatorRelease(h_slow);
   if(h_trend!=INVALID_HANDLE) IndicatorRelease(h_trend);
   if(h_adx!=INVALID_HANDLE)   IndicatorRelease(h_adx);
   if(h_rsi!=INVALID_HANDLE)   IndicatorRelease(h_rsi);
   if(h_atr!=INVALID_HANDLE)   IndicatorRelease(h_atr);
   if(h_emaHTF!=INVALID_HANDLE)IndicatorRelease(h_emaHTF);
   ObjectsDeleteAll(0,g_panelPrefix);
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   // manage open groups every tick (locks, trailing, reversal)
   ManageGroups();

   // entries evaluated once per finished bar (studied, not random)
   datetime bt = (datetime)SeriesInfoInteger(g_sym,_Period,SERIES_LASTBAR_DATE);
   if(bt==g_lastBarTime) return;
   g_lastBarTime = bt;

   if(g_paused) return;
   if(IsDailyLossLimitHit()) return;

   TryOpenNewGroup();
  }

//+------------------------------------------------------------------+
//| OnTimer - refresh dashboard                                      |
//+------------------------------------------------------------------+
void OnTimer()
  {
   CalcStats();
   if(InpShowPanel) UpdatePanel();
  }

//+------------------------------------------------------------------+
//| Trend detection  (+1 up, -1 down, 0 range) on chart TF          |
//+------------------------------------------------------------------+
int ChartTrend()
  {
   double fast = IndVal(h_fast,0,1);
   double slow = IndVal(h_slow,0,1);
   double trend= IndVal(h_trend,0,1);
   double fastPrev = IndVal(h_fast,0,3);
   double close = iClose(g_sym,_Period,1);
   if(fast==0 || slow==0) return(0);

   bool up   = (fast>slow) && (close>slow) && (fast>=fastPrev) && (close>=trend || trend==0);
   bool down = (fast<slow) && (close<slow) && (fast<=fastPrev) && (close<=trend || trend==0);
   if(up)   return(1);
   if(down) return(-1);
   return(0);
  }

int HTFTrend()
  {
   double ema = IndVal(h_emaHTF,0,1);
   double close = iClose(g_sym,InpSwingTF,1);
   if(ema==0) return(0);
   if(close>ema) return(1);
   if(close<ema) return(-1);
   return(0);
  }

//+------------------------------------------------------------------+
//| Pivot / swing engine (Elliott-Wave structure)                   |
//+------------------------------------------------------------------+
bool FindLastSwing(bool wantHigh,int frac,int lookback,double &price,int &shift)
  {
   int total = MathMin(lookback, Bars(g_sym,_Period)-frac-1);
   for(int i=frac; i<=total; i++)
     {
      bool ok=true;
      if(wantHigh)
        {
         double h = iHigh(g_sym,_Period,i);
         for(int j=1;j<=frac && ok;j++)
            if(iHigh(g_sym,_Period,i-j) >= h || iHigh(g_sym,_Period,i+j) >= h) ok=false;
         if(ok){ price=h; shift=i; return(true); }
        }
      else
        {
         double l = iLow(g_sym,_Period,i);
         for(int j=1;j<=frac && ok;j++)
            if(iLow(g_sym,_Period,i-j) <= l || iLow(g_sym,_Period,i+j) <= l) ok=false;
         if(ok){ price=l; shift=i; return(true); }
        }
     }
   return(false);
  }

//  Confirms Elliott-style structure (HH+HL up / LH+LL down). Returns +1/-1/0.
int WaveStructureBias(int frac,int lookback)
  {
   double l1,l2,h1,h2; int sl1,sl2,sh1,sh2;
   bool gl1 = FindLastSwing(false,frac,lookback,l1,sl1);
   bool gh1 = FindLastSwing(true ,frac,lookback,h1,sh1);
   if(!gl1 || !gh1) return(0);

   bool gl2=false; l2=0; sl2=0;
   for(int i=sl1+frac+1;i<=lookback && i<=Bars(g_sym,_Period)-frac-1;i++)
     {
      double l=iLow(g_sym,_Period,i); bool ok=true;
      for(int j=1;j<=frac && ok;j++) if(iLow(g_sym,_Period,i-j)<=l || iLow(g_sym,_Period,i+j)<=l) ok=false;
      if(ok){ l2=l; sl2=i; gl2=true; break; }
     }
   bool gh2=false; h2=0; sh2=0;
   for(int i=sh1+frac+1;i<=lookback && i<=Bars(g_sym,_Period)-frac-1;i++)
     {
      double h=iHigh(g_sym,_Period,i); bool ok=true;
      for(int j=1;j<=frac && ok;j++) if(iHigh(g_sym,_Period,i-j)>=h || iHigh(g_sym,_Period,i+j)>=h) ok=false;
      if(ok){ h2=h; sh2=i; gh2=true; break; }
     }
   if(!gl2 || !gh2) return(0);

   bool hl = (l1>l2), hh = (h1>h2), ll = (l1<l2), lh = (h1<h2);
   if(hl && hh) return(1);
   if(ll && lh) return(-1);
   return(0);
  }

//+------------------------------------------------------------------+
//| Personal control gates                                           |
//+------------------------------------------------------------------+
bool FocusAllows(int trend)
  {
   if(g_focus==FOCUS_BOTH) return(true);
   if(g_focus==FOCUS_UP)   return(trend>0);
   if(g_focus==FOCUS_DOWN) return(trend<0);
   return(true);
  }
bool SideAllows(int dir)
  {
   if(g_side==SIDE_BOTH) return(true);
   if(g_side==SIDE_BUY)  return(dir>0);
   if(g_side==SIDE_SELL) return(dir<0);
   return(true);
  }

//+------------------------------------------------------------------+
//| Signal generation for one profile (scalp/swing)                 |
//|  Returns +1 buy / -1 sell / 0 none and fills entry + sl.         |
//+------------------------------------------------------------------+
int ComputeSignal(bool swingProfile,double &entry,double &sl)
  {
   int    frac    = swingProfile ? InpFractalSwing : InpFractalScalp;
   double adxMin  = swingProfile ? InpADXMinSwing  : InpADXMinScalp;

   double adx = IndVal(h_adx,0,1);
   double atr = IndVal(h_atr,0,1);
   double rsi = IndVal(h_rsi,0,1);
   if(atr<=0) return(0);
   if(adx < adxMin) return(0);                 // trend must be strong enough (no chop)

   int chartT = ChartTrend();
   if(chartT==0) return(0);
   if(!FocusAllows(chartT)) return(0);          // personal trend-focus gate

   int waveT  = WaveStructureBias(frac,InpPivotLookback);
   if(waveT!=0 && waveT!=chartT) return(0);     // structure must agree with trend

   if(swingProfile)                             // swing needs higher-TF agreement
     {
      int htf = HTFTrend();
      if(htf!=0 && htf!=chartT) return(0);
     }

   double ask = SymbolInfoDouble(g_sym,SYMBOL_ASK);
   double bid = SymbolInfoDouble(g_sym,SYMBOL_BID);

   if(chartT>0)   // ----- BUY setup (end of a pullback / start of impulse) -----
     {
      if(!SideAllows(1)) return(0);
      double swingLow; int shift;
      if(!FindLastSwing(false,frac,InpPivotLookback,swingLow,shift)) return(0);
      if(shift>InpMaxPullbackBars) return(0);            // entry must be fresh
      double close1 = iClose(g_sym,_Period,1);
      if(close1 <= swingLow) return(0);                   // price holds above pullback low
      if(rsi <= 50.0 || rsi >= 78.0) return(0);           // momentum up, not overbought

      entry = ask;
      if(InpUseStructureSL)
        {
         sl = NormalizePrice(swingLow - atr*InpSLBufferATR);
         double risk = entry - sl;
         if(risk <= 0) return(0);
         if(risk > atr*InpMaxRiskATR) return(0);          // reject oversized stop
        }
      else
        {
         sl = NormalizePrice(entry - InpSLPips*g_pip);
        }
      return(1);
     }
   else           // ----- SELL setup -----
     {
      if(!SideAllows(-1)) return(0);
      double swingHigh; int shift;
      if(!FindLastSwing(true,frac,InpPivotLookback,swingHigh,shift)) return(0);
      if(shift>InpMaxPullbackBars) return(0);
      double close1 = iClose(g_sym,_Period,1);
      if(close1 >= swingHigh) return(0);
      if(rsi >= 50.0 || rsi <= 22.0) return(0);

      entry = bid;
      if(InpUseStructureSL)
        {
         sl = NormalizePrice(swingHigh + atr*InpSLBufferATR);
         double risk = sl - entry;
         if(risk <= 0) return(0);
         if(risk > atr*InpMaxRiskATR) return(0);
        }
      else
        {
         sl = NormalizePrice(entry + InpSLPips*g_pip);
        }
      return(-1);
     }
  }

//+------------------------------------------------------------------+
//| Build the 3 target prices for a direction                        |
//+------------------------------------------------------------------+
void BuildTargets(int dir,double entry,double R,double &tp[])
  {
   ArrayResize(tp,3);
   if(InpUseStructureSL)
     {
      tp[0] = entry + dir*R*InpTP1_R;
      tp[1] = entry + dir*R*InpTP2_R;
      tp[2] = entry + dir*R*InpTP3_R;
     }
   else
     {
      tp[0] = entry + dir*InpTP1Pips*g_pip;
      tp[1] = entry + dir*InpTP2Pips*g_pip;
      tp[2] = entry + dir*InpTP3Pips*g_pip;
     }
   for(int i=0;i<3;i++) tp[i]=NormalizePrice(tp[i]);
  }

//+------------------------------------------------------------------+
//| Money management - lot per leg                                   |
//+------------------------------------------------------------------+
double CalcLegLot(double riskPrice,int legs)
  {
   double lot;
   if(InpMMMode==MM_FIXED_LOT || riskPrice<=0)
      lot = InpLegLot;
   else
     {
      double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskMoney  = balance * InpRiskPercent/100.0 / MathMax(1,legs);
      double ticksAtRisk= riskPrice / g_tickSize;
      double lossPerLot = ticksAtRisk * g_tickValue;
      if(lossPerLot<=0) return(InpLegLot);
      lot = riskMoney / lossPerLot;
     }
   lot = NormalizeVolumeDown(lot);
   if(lot < g_volMin) lot = g_volMin;
   if(lot > g_volMax) lot = g_volMax;
   if(lot > InpMaxLotPerLeg) lot = NormalizeVolumeDown(InpMaxLotPerLeg);
   return(lot);
  }

bool SpreadOK()
  {
   if(InpMaxSpreadPoints<=0) return(true);
   double spread = (SymbolInfoDouble(g_sym,SYMBOL_ASK)-SymbolInfoDouble(g_sym,SYMBOL_BID))/g_point;
   return(spread <= InpMaxSpreadPoints);
  }

int CountOurPositions()
  {
   int c=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong t=PositionGetTicket(i);
      if(t==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==g_sym && PositionGetInteger(POSITION_MAGIC)==InpMagic) c++;
     }
   return(c);
  }

//+------------------------------------------------------------------+
//| Entry orchestration - opens a 3-leg group                        |
//+------------------------------------------------------------------+
void TryOpenNewGroup()
  {
   if(ArraySize(g_groups) >= InpMaxTradeGroups) return;
   if(!SpreadOK()) return;

   int dir=0; double entry=0, sl=0;

   // priority: swing first when allowed (cleaner structure), then scalp
   if(g_style==STYLE_SWING || g_style==STYLE_BOTH)
      dir = ComputeSignal(true,entry,sl);
   if(dir==0 && (g_style==STYLE_SCALP || g_style==STYLE_BOTH))
      dir = ComputeSignal(false,entry,sl);
   if(dir==0) return;

   OpenGroup(dir,entry,sl);
  }

//  open a fresh group of N legs sharing one SL with TP1/TP2/TP3
bool OpenGroup(int dir,double entry,double sl)
  {
   double R = MathAbs(entry-sl);
   if(R<=0) return(false);

   int legs = InpLegsPerTrade; if(legs<1) legs=1; if(legs>3) legs=3;
   double legLot = CalcLegLot(R,legs);
   if(legLot<=0) return(false);

   double tp[]; BuildTargets(dir,entry,R,tp);
   sl = NormalizePrice(sl);

   // create the group record first
   int gi = ArraySize(g_groups);
   ArrayResize(g_groups,gi+1);
   g_groups[gi].id    = ++g_groupSeq;
   g_groups[gi].dir   = dir;
   g_groups[gi].entry = entry;
   g_groups[gi].slPrice = sl;
   g_groups[gi].R     = R;
   g_groups[gi].tp[0] = tp[0];
   g_groups[gi].tp[1] = tp[1];
   g_groups[gi].tp[2] = tp[2];
   g_groups[gi].profitClosed = 0;
   ArrayResize(g_groups[gi].legs,0);

   int opened=0;
   for(int i=0;i<legs;i++)
     {
      int targetIdx = (i<3? i : 2);            // extra legs (if any) ride TP3
      double legTP  = tp[targetIdx];
      string cmt    = StringFormat("%s#%d L%d",g_botName,(int)g_groups[gi].id,i+1);

      bool ok=false;
      if(dir>0) ok = g_trade.Buy(legLot,g_sym,0.0,sl,legTP,cmt);
      else      ok = g_trade.Sell(legLot,g_sym,0.0,sl,legTP,cmt);

      if(ok)
        {
         ulong tk = PositionTicketFromDeal();
         if(tk==0) tk = FindRecentPositionTicket();
         int li = ArraySize(g_groups[gi].legs);
         ArrayResize(g_groups[gi].legs,li+1);
         g_groups[gi].legs[li].ticket    = tk;
         g_groups[gi].legs[li].targetIdx = targetIdx;
         g_groups[gi].legs[li].tp        = legTP;
         g_groups[gi].legs[li].closed    = false;
         opened++;
        }
      else
         PrintFormat("%s leg %d failed: %d %s",g_botName,i+1,
                     g_trade.ResultRetcode(),g_trade.ResultRetcodeDescription());
     }

   if(opened==0)
     {
      ArrayResize(g_groups,gi);   // roll back empty group
      return(false);
     }

   PrintFormat("%s ENTRY %s legs=%d lot=%.2f entry=%.*f sl=%.*f TP=[%.*f/%.*f/%.*f] R=%.*f",
               g_botName,(dir>0?"BUY":"SELL"),opened,legLot,
               g_digits,entry,g_digits,sl,
               g_digits,tp[0],g_digits,tp[1],g_digits,tp[2],g_digits,R);
   return(true);
  }

//  resolve the position ticket created by the most recent deal of this EA
ulong PositionTicketFromDeal()
  {
   ulong deal = g_trade.ResultDeal();
   if(deal==0) return(0);
   if(HistoryDealSelect(deal))
     {
      long posid = (long)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
      if(posid>0 && PositionSelectByTicket((ulong)posid)) return((ulong)posid);
     }
   return(0);
  }

ulong FindRecentPositionTicket()
  {
   ulong best=0; datetime bestTime=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong t=PositionGetTicket(i);
      if(t==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=g_sym) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      datetime pt=(datetime)PositionGetInteger(POSITION_TIME);
      if(pt>=bestTime){ bestTime=pt; best=t; }
     }
   return(best);
  }

//+------------------------------------------------------------------+
//| Was a (now closed) leg position profitable?                      |
//+------------------------------------------------------------------+
bool LegClosedInProfit(ulong posTicket)
  {
   if(!HistorySelectByPosition(posTicket)) return(false);
   double pl=0; int deals=HistoryDealsTotal();
   for(int i=0;i<deals;i++)
     {
      ulong d=HistoryDealGetTicket(i);
      if(d==0) continue;
      if((long)HistoryDealGetInteger(d,DEAL_POSITION_ID)!=(long)posTicket) continue;
      if(HistoryDealGetInteger(d,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
      pl += HistoryDealGetDouble(d,DEAL_PROFIT)
           +HistoryDealGetDouble(d,DEAL_SWAP)
           +HistoryDealGetDouble(d,DEAL_COMMISSION);
     }
   return(pl>=0);
  }

//+------------------------------------------------------------------+
//| Rebuild groups from already-open positions (after restart)       |
//+------------------------------------------------------------------+
void RebuildGroupsFromOpenPositions()
  {
   ArrayResize(g_groups,0);
   // one synthetic group per direction, grouping current open legs
   for(int side=0; side<2; side++)
     {
      int dir = (side==0? 1 : -1);
      double entrySum=0, sl=0; int n=0;
      ulong tickets[]; ArrayResize(tickets,0);
      for(int i=PositionsTotal()-1;i>=0;i--)
        {
         ulong t=PositionGetTicket(i);
         if(t==0) continue;
         if(PositionGetString(POSITION_SYMBOL)!=g_sym) continue;
         if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
         int pdir=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
         if(pdir!=dir) continue;
         entrySum += PositionGetDouble(POSITION_PRICE_OPEN);
         if(sl==0) sl = PositionGetDouble(POSITION_SL);
         int k=ArraySize(tickets); ArrayResize(tickets,k+1); tickets[k]=t;
         n++;
        }
      if(n==0) continue;
      double entry = entrySum/n;
      double R = (sl>0? MathAbs(entry-sl) : InpSLPips*g_pip);

      int gi=ArraySize(g_groups); ArrayResize(g_groups,gi+1);
      g_groups[gi].id=++g_groupSeq;
      g_groups[gi].dir=dir;
      g_groups[gi].entry=entry;
      g_groups[gi].slPrice=(sl>0?sl:NormalizePrice(entry-dir*R));
      g_groups[gi].R=R;
      double tp[]; BuildTargets(dir,entry,R,tp);
      g_groups[gi].tp[0]=tp[0]; g_groups[gi].tp[1]=tp[1]; g_groups[gi].tp[2]=tp[2];
      g_groups[gi].profitClosed=0;
      ArrayResize(g_groups[gi].legs,n);
      for(int k=0;k<n;k++)
        {
         g_groups[gi].legs[k].ticket=tickets[k];
         g_groups[gi].legs[k].targetIdx=(k<3?k:2);
         double ltp=0; if(PositionSelectByTicket(tickets[k])) ltp=PositionGetDouble(POSITION_TP);
         g_groups[gi].legs[k].tp=ltp;
         g_groups[gi].legs[k].closed=false;
        }
     }
  }

//+------------------------------------------------------------------+
//| Manage all groups: detect target hits, lock, trail, reverse      |
//+------------------------------------------------------------------+
void ManageGroups()
  {
   int chartT = ChartTrend();
   double atr  = IndVal(h_atr,0,1);
   double bid  = SymbolInfoDouble(g_sym,SYMBOL_BID);
   double ask  = SymbolInfoDouble(g_sym,SYMBOL_ASK);

   for(int gi=ArraySize(g_groups)-1; gi>=0; gi--)
     {
      int dir = g_groups[gi].dir;
      double entry = g_groups[gi].entry;
      double R = g_groups[gi].R;

      // detect newly closed legs and how many closed in profit
      int openLegs=0;
      for(int li=0; li<ArraySize(g_groups[gi].legs); li++)
        {
         if(g_groups[gi].legs[li].closed) continue;
         ulong tk = g_groups[gi].legs[li].ticket;
         if(tk==0 || !PositionSelectByTicket(tk))
           {
            g_groups[gi].legs[li].closed = true;
            if(LegClosedInProfit(tk)) g_groups[gi].profitClosed++;
           }
         else
            openLegs++;
        }

      if(openLegs==0){ RemoveGroup(gi); continue; }

      // ----- personal control change: close violating group -----
      if(InpCloseOnControlChange && (!SideAllows(dir) || !FocusAllows(dir)))
        {
         CloseGroup(gi);
         RemoveGroup(gi);
         continue;
        }

      // ----- close on trend reversal, then re-enter the new side -----
      if(InpCloseOnReversal && chartT!=0 && chartT!=dir)
        {
         CloseGroup(gi);
         RemoveGroup(gi);
         if(InpReenterOnReversal && !g_paused && !IsDailyLossLimitHit())
            TryOpenNewGroup();
         continue;
        }

      // ----- forward profit lock as targets are reached -----
      double lockSL = 0; bool haveLock=false;
      if(InpLockProfitSteps && R>0)
        {
         if(g_groups[gi].profitClosed>=1){ lockSL = entry + dir*InpBELockPips*g_pip; haveLock=true; }
         if(g_groups[gi].profitClosed>=2){ lockSL = entry + dir*R*InpTP1_R;          haveLock=true; }
        }

      double price = (dir>0? bid : ask);
      double rMult = (R>0? ((price-entry)*dir)/R : 0);

      // ----- apply lock + trailing to each still-open leg -----
      for(int li=0; li<ArraySize(g_groups[gi].legs); li++)
        {
         if(g_groups[gi].legs[li].closed) continue;
         ulong tk = g_groups[gi].legs[li].ticket;
         if(!PositionSelectByTicket(tk)) continue;

         double curSL = PositionGetDouble(POSITION_SL);
         double curTP = PositionGetDouble(POSITION_TP);
         double desired = curSL;

         if(haveLock) desired = BetterSL(dir,desired,lockSL);

         if(InpUseTrailing && atr>0 && R>0 && rMult>=InpTrailStartR)
           {
            double trail = atr*InpTrailATRMult;
            double newSL = (dir>0? price-trail : price+trail);
            // never trail past break-even into loss
            bool beyondBE = (dir>0? newSL>=entry : newSL<=entry);
            if(beyondBE) desired = BetterSL(dir,desired,newSL);
           }

         desired = NormalizePrice(desired);

         // respect broker minimum stop distance
         double minDist = g_stopLevelPts*g_point;
         bool farEnough = (dir>0? (price-desired>=minDist) : (desired-price>=minDist));
         bool improves  = (curSL<=0) || (dir>0? desired>curSL+g_point*0.5 : desired<curSL-g_point*0.5);

         if(improves && farEnough)
            g_trade.PositionModify(tk,desired,curTP);
        }
     }
  }

//  pick the more protective SL for a direction
double BetterSL(int dir,double a,double b)
  {
   if(a<=0) return(b);
   if(b<=0) return(a);
   return(dir>0 ? MathMax(a,b) : MathMin(a,b));
  }

void CloseGroup(int gi)
  {
   if(gi<0 || gi>=ArraySize(g_groups)) return;
   for(int li=0; li<ArraySize(g_groups[gi].legs); li++)
     {
      if(g_groups[gi].legs[li].closed) continue;
      ulong tk=g_groups[gi].legs[li].ticket;
      if(tk!=0 && PositionSelectByTicket(tk))
         g_trade.PositionClose(tk);
     }
  }

void RemoveGroup(int gi)
  {
   int n=ArraySize(g_groups);
   if(gi<0 || gi>=n) return;
   for(int i=gi;i<n-1;i++) g_groups[i]=g_groups[i+1];
   ArrayResize(g_groups,n-1);
  }

//+------------------------------------------------------------------+
//| Daily loss guard                                                 |
//+------------------------------------------------------------------+
bool IsDailyLossLimitHit()
  {
   if(InpMaxDailyLossPct<=0) return(false);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance<=0) return(false);
   double lossPct = (g_stats.todayPL<0 ? -g_stats.todayPL/balance*100.0 : 0.0);
   return(lossPct >= InpMaxDailyLossPct);
  }

//+------------------------------------------------------------------+
//| Statistics for dashboard                                         |
//+------------------------------------------------------------------+
void CalcStats()
  {
   double floating=0; int open=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong t=PositionGetTicket(i);
      if(t==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=g_sym) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      floating += PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      open++;
     }
   g_stats.openLegs   = open;
   g_stats.openGroups = ArraySize(g_groups);
   g_stats.floating   = floating;

   int wins=0,losses=0,trades=0; double gp=0,gl=0,today=0;
   datetime dayStart = (datetime)(TimeCurrent()-(TimeCurrent()%86400));
   if(HistorySelect(0,TimeCurrent()))
     {
      int deals=HistoryDealsTotal();
      for(int i=0;i<deals;i++)
        {
         ulong d=HistoryDealGetTicket(i);
         if(d==0) continue;
         if(HistoryDealGetString(d,DEAL_SYMBOL)!=g_sym) continue;
         if(HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagic) continue;
         if(HistoryDealGetInteger(d,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
         double pl = HistoryDealGetDouble(d,DEAL_PROFIT)
                    +HistoryDealGetDouble(d,DEAL_SWAP)
                    +HistoryDealGetDouble(d,DEAL_COMMISSION);
         trades++;
         if(pl>=0){ wins++; gp+=pl; } else { losses++; gl+=-pl; }
         datetime dt=(datetime)HistoryDealGetInteger(d,DEAL_TIME);
         if(dt>=dayStart) today+=pl;
        }
     }
   g_stats.closedTrades=trades;
   g_stats.wins=wins;
   g_stats.losses=losses;
   g_stats.grossProfit=gp;
   g_stats.grossLoss=gl;
   g_stats.netClosed=gp-gl;
   g_stats.todayPL=today;
  }

//+------------------------------------------------------------------+
//| Dashboard panel                                                  |
//+------------------------------------------------------------------+
#define PANEL_W 262
#define ROW_H   18

void RectLabel(string name,int x,int y,int w,int h,color bg,color border)
  {
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_COLOR,border);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

void TextLabel(string name,int x,int y,string text,color clr,int fontsize,string font="Consolas")
  {
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,font);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontsize);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

void Button(string name,int x,int y,int w,int h,string text,color bg,color clr)
  {
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_STATE,false);
  }

void CreatePanel()
  {
   int x=InpPanelX, y=InpPanelY;
   int rows=15;
   int h = rows*ROW_H + 16;
   RectLabel(g_panelPrefix+"bg",x-6,y-6,PANEL_W,h,InpPanelBg,clrSlateGray);
   RectLabel(g_panelPrefix+"title",x-6,y-6,PANEL_W,ROW_H+6,C'10,40,80',clrSlateGray);

   int by = y + 14*ROW_H + 8;
   Button(g_panelPrefix+"btnStyle",x,     by,58,18,"Style", C'40,60,90',clrWhite);
   Button(g_panelPrefix+"btnFocus",x+60,  by,58,18,"Focus", C'40,60,90',clrWhite);
   Button(g_panelPrefix+"btnSide", x+120, by,58,18,"Side",  C'40,60,90',clrWhite);
   Button(g_panelPrefix+"btnPause",x+180, by,66,18,"Pause", C'90,40,40',clrWhite);

   UpdatePanel();
  }

string StyleText()
  {
   switch(g_style){
      case STYLE_SCALP: return("SCALP");
      case STYLE_SWING: return("SWING");
      default:          return("BOTH");
   }
  }
string FocusText()
  {
   switch(g_focus){
      case FOCUS_UP:   return("UP");
      case FOCUS_DOWN: return("DOWN");
      default:         return("BOTH");
   }
  }
string SideText()
  {
   switch(g_side){
      case SIDE_BUY:  return("BUY");
      case SIDE_SELL: return("SELL");
      default:        return("BOTH");
   }
  }
string TrendText(int t){ return(t>0?"UP":(t<0?"DOWN":"RANGE")); }

void UpdatePanel()
  {
   if(!InpShowPanel) return;
   int x=InpPanelX, y=InpPanelY;
   int r=0;
   int fs=InpFontSize;
   color val=InpTextColor;

   TextLabel(g_panelPrefix+"r_title",x,y+r*ROW_H,"  "+g_botName+"  -  GOLD EA",clrGold,fs+1); r++;

   color stClr = g_paused?clrTomato:clrLime;
   TextLabel(g_panelPrefix+"r_status",x,y+r*ROW_H,"Status   : "+(g_paused?"PAUSED":"RUNNING"),stClr,fs); r++;
   TextLabel(g_panelPrefix+"r_sym",x,y+r*ROW_H,"Symbol   : "+g_sym+"  "+EnumToString((ENUM_TIMEFRAMES)_Period),val,fs); r++;
   TextLabel(g_panelPrefix+"r_mode",x,y+r*ROW_H,"Style "+StyleText()+"  Focus "+FocusText()+"  Side "+SideText(),clrAqua,fs); r++;
   TextLabel(g_panelPrefix+"r_legs",x,y+r*ROW_H,StringFormat("Plan     : %d legs x %.2f  TP %d/%d/%d",
             InpLegsPerTrade,InpLegLot,(int)InpTP1Pips,(int)InpTP2Pips,(int)InpTP3Pips),val,fs); r++;

   int ct=ChartTrend(); int ht=HTFTrend();
   color tClr = ct>0?clrLime:(ct<0?clrTomato:clrSilver);
   TextLabel(g_panelPrefix+"r_trend",x,y+r*ROW_H,"Trend    : "+TrendText(ct)+"  (HTF "+TrendText(ht)+")",tClr,fs); r++;

   TextLabel(g_panelPrefix+"r_open",x,y+r*ROW_H,StringFormat("Open     : %d legs / %d grp",g_stats.openLegs,g_stats.openGroups),val,fs); r++;
   TextLabel(g_panelPrefix+"r_trades",x,y+r*ROW_H,StringFormat("Trades   : %d",g_stats.closedTrades),val,fs); r++;

   double wr = (g_stats.closedTrades>0)? (double)g_stats.wins/g_stats.closedTrades*100.0 : 0.0;
   TextLabel(g_panelPrefix+"r_wins",x,y+r*ROW_H,StringFormat("Wins     : %d   (%.1f%%)",g_stats.wins,wr),clrLime,fs); r++;
   TextLabel(g_panelPrefix+"r_loss",x,y+r*ROW_H,StringFormat("Losses   : %d",g_stats.losses),clrTomato,fs); r++;

   string cc=AccountInfoString(ACCOUNT_CURRENCY);
   TextLabel(g_panelPrefix+"r_gp",x,y+r*ROW_H,StringFormat("Profit   : %.2f %s",g_stats.grossProfit,cc),clrLime,fs); r++;
   TextLabel(g_panelPrefix+"r_gl",x,y+r*ROW_H,StringFormat("Loss     : %.2f %s",g_stats.grossLoss,cc),clrTomato,fs); r++;

   color netClr = g_stats.netClosed>=0?clrLime:clrTomato;
   TextLabel(g_panelPrefix+"r_net",x,y+r*ROW_H,StringFormat("Net P/L  : %.2f %s",g_stats.netClosed,cc),netClr,fs); r++;

   color flClr = g_stats.floating>=0?clrLime:clrTomato;
   TextLabel(g_panelPrefix+"r_float",x,y+r*ROW_H,StringFormat("Floating : %.2f %s",g_stats.floating,cc),flClr,fs); r++;

   ObjectSetString(0,g_panelPrefix+"btnStyle",OBJPROP_TEXT,StyleText());
   ObjectSetString(0,g_panelPrefix+"btnFocus",OBJPROP_TEXT,FocusText());
   ObjectSetString(0,g_panelPrefix+"btnSide", OBJPROP_TEXT,SideText());
   ObjectSetString(0,g_panelPrefix+"btnPause",OBJPROP_TEXT,(g_paused?"RESUME":"PAUSE"));
   ObjectSetInteger(0,g_panelPrefix+"btnPause",OBJPROP_BGCOLOR,(g_paused?C'40,90,40':C'90,40,40'));

   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Chart events (panel buttons = personal control)                 |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(id!=CHARTEVENT_OBJECT_CLICK) return;

   if(sparam==g_panelPrefix+"btnStyle")
      g_style = (ENUM_BOT_STYLE)(((int)g_style+1)%3);
   else if(sparam==g_panelPrefix+"btnFocus")
      g_focus = (ENUM_TREND_FOCUS)(((int)g_focus+1)%3);
   else if(sparam==g_panelPrefix+"btnSide")
      g_side = (ENUM_ORDER_SIDE)(((int)g_side+1)%3);
   else if(sparam==g_panelPrefix+"btnPause")
      g_paused = !g_paused;
   else
      return;

   ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
   UpdatePanel();
  }
//+------------------------------------------------------------------+
