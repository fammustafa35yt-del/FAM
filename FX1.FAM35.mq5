//+------------------------------------------------------------------+
//|                                                    FX1.FAM35.mq5  |
//|        Elliott-Wave Gold (XAU) Expert Advisor for MetaTrader 5    |
//|                                                                   |
//|  Features:                                                        |
//|   - Works on every gold symbol naming (XAUUSD, GOLD, XAUUSDm ...) |
//|   - Elliott-Wave style structural analysis (swing/pivot engine)   |
//|   - Fast trend detection + adaptive bias (chart TF + higher TF)   |
//|   - Money / risk management (risk % of balance or fixed lot)      |
//|   - Works on every timeframe                                      |
//|   - Scalp + Swing trade styles (user selectable)                  |
//|   - 1:3 Risk/Reward with 3 staged take-profits (1R / 2R / 3R)     |
//|   - Partial profit booking at every stage of the 1/3 split        |
//|   - No random entries: multi-confluence "studied" entries only    |
//|   - Closes the trade when the market trend reverses               |
//|   - Trailing stop-loss that follows the trade                     |
//|   - Personal control: Scalp / Swing / Both                        |
//|   - Personal control: Up / Down / Both                            |
//|   - On-chart dashboard (status, trades, wins, losses, P/L)        |
//+------------------------------------------------------------------+
#property copyright "FX1.FAM35"
#property version   "1.00"
#property description "FX1.FAM35 - Gold Elliott-Wave EA: Scalp/Swing, 1:3 RR, staged TPs, trailing SL, trend-reversal exit, dashboard."

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//==================== ENUMS ====================
enum ENUM_BOT_STYLE
  {
   STYLE_SCALP = 0,   // Scalp only / سكالب فقط
   STYLE_SWING = 1,   // Swing only / سوينغ فقط
   STYLE_BOTH  = 2    // Scalp + Swing / كلاهما
  };

enum ENUM_BOT_DIRECTION
  {
   DIR_BUY  = 0,   // Buy only (Up) / صعود فقط
   DIR_SELL = 1,   // Sell only (Down) / هبوط فقط
   DIR_BOTH = 2    // Both / كلاهما
  };

enum ENUM_MM_MODE
  {
   MM_FIXED_LOT    = 0, // Fixed lot / حجم ثابت
   MM_RISK_PERCENT = 1  // Risk % of balance / نسبة مخاطرة من الرصيد
  };

//==================== INPUTS ====================
input group             "=== General / عام ==="
input long              InpMagic           = 350035;     // Magic number
input string            InpForceSymbol     = "";         // Force symbol (empty = chart symbol)
input bool              InpTradingEnabled  = true;       // Enable trading on start

input group             "=== Personal Control / تحكم شخصي ==="
input ENUM_BOT_STYLE    InpStyle           = STYLE_BOTH; // Trade style: Scalp / Swing / Both
input ENUM_BOT_DIRECTION InpDirection      = DIR_BOTH;   // Direction: Up / Down / Both

input group             "=== Money Management / إدارة رأس المال ==="
input ENUM_MM_MODE      InpMMMode          = MM_RISK_PERCENT; // Lot mode
input double            InpRiskPercent     = 1.0;        // Risk % per trade (of balance)
input double            InpFixedLot        = 0.10;       // Fixed lot (when fixed mode)
input double            InpMaxLot          = 5.0;        // Max lot cap
input int               InpMaxPositions    = 2;          // Max open positions for this symbol
input double            InpMaxSpreadPoints = 60;         // Max allowed spread (points), 0 = ignore
input double            InpMaxDailyLossPct = 0.0;        // Stop trading if daily loss >= % (0=off)

input group             "=== Risk / Reward & Targets ==="
input double            InpRR              = 3.0;        // Reward:Risk (final target = this * R)
input bool              InpUsePartialTPs   = true;       // Book profit at each 1/3 stage
input double            InpTP1_R           = 1.0;        // TP1 distance in R
input double            InpTP2_R           = 2.0;        // TP2 distance in R
input double            InpClosePct1       = 33.0;       // % of position to close at TP1
input double            InpClosePct2       = 33.0;       // % of position to close at TP2

input group             "=== Stop Loss / Trailing ==="
input bool              InpMoveBE          = true;       // Move SL to break-even after TP1
input double            InpBreakevenLockPts= 20;         // Extra lock at BE (points)
input bool              InpUseTrailing     = true;       // Trailing stop follows the trade
input double            InpTrailStartR     = 1.0;        // Start trailing after profit >= R
input double            InpTrailATRMult    = 2.0;        // Trailing distance = ATR * mult
input bool              InpCloseOnReversal = true;       // Close trade on trend reversal

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
input int               InpMaxPullbackBars = 25;         // Max bars since pullback pivot (entry freshness)
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
string g_botName = "FX1.FAM35";

// runtime-changeable control state (can be toggled from the panel buttons)
ENUM_BOT_STYLE     g_style;
ENUM_BOT_DIRECTION g_direction;
bool               g_paused = false;

// indicator handles
int h_fast=-1, h_slow=-1, h_trend=-1, h_adx=-1, h_rsi=-1, h_atr=-1, h_emaHTF=-1;

// symbol meta
double g_point, g_tickSize, g_tickValue, g_volMin, g_volMax, g_volStep, g_stopLevelPts;
int    g_digits, g_volDigits;

datetime g_lastBarTime = 0;

// per-position management state
struct SPosState
  {
   ulong  ticket;
   double initVolume;
   double entry;
   double risk;     // 1R in price
   int    dir;      // +1 buy, -1 sell
   int    stage;    // 0=none, 1=TP1 done, 2=TP2 done
   bool   beDone;
  };
SPosState g_pos[];

// cached statistics for the dashboard
struct SStats
  {
   int    openCount;
   int    closedTrades;
   int    wins;
   int    losses;
   double grossProfit;
   double grossLoss;     // stored as positive number
   double netClosed;
   double floating;
   double todayPL;
  };
SStats g_stats;
datetime g_statsLastCalc = 0;

string g_panelPrefix = "FAM35_";

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

// copy a single indicator value at "shift"
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
      Print("FX1.FAM35: cannot select symbol ",g_sym);
      return(INIT_FAILED);
     }

   if(!LooksLikeGold(g_sym))
      Print("FX1.FAM35: WARNING - '",g_sym,"' does not look like a gold symbol. The EA is tuned for gold (XAU).");

   // control state
   g_style     = InpStyle;
   g_direction = InpDirection;
   g_paused    = !InpTradingEnabled;

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

   // indicator handles on chart TF
   h_fast  = iMA(g_sym,_Period,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);
   h_slow  = iMA(g_sym,_Period,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);
   h_trend = iMA(g_sym,_Period,InpTrendEMA,0,MODE_EMA,PRICE_CLOSE);
   h_adx   = iADX(g_sym,_Period,InpADXPeriod);
   h_rsi   = iRSI(g_sym,_Period,InpRSIPeriod,PRICE_CLOSE);
   h_atr   = iATR(g_sym,_Period,InpATRPeriod);
   // higher TF for swing bias
   h_emaHTF= iMA(g_sym,InpSwingTF,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);

   if(h_fast==INVALID_HANDLE || h_slow==INVALID_HANDLE || h_trend==INVALID_HANDLE ||
      h_adx==INVALID_HANDLE  || h_rsi==INVALID_HANDLE  || h_atr==INVALID_HANDLE   ||
      h_emaHTF==INVALID_HANDLE)
     {
      Print("FX1.FAM35: failed to create indicator handles");
      return(INIT_FAILED);
     }

   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetMarginMode();
   g_trade.SetTypeFillingBySymbol(g_sym);
   g_trade.SetDeviationInPoints(30);

   RebuildPositionStates();

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
   // always manage open positions (every tick)
   ManageOpenPositions();

   // entries only once per finished bar (studied, not random)
   datetime bt = (datetime)SeriesInfoInteger(g_sym,_Period,SERIES_LASTBAR_DATE);
   if(bt==g_lastBarTime) return;
   g_lastBarTime = bt;

   if(g_paused) return;
   if(IsDailyLossLimitHit()) return;

   CheckForEntry();
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
//| Trend detection                                                  |
//|  returns +1 up, -1 down, 0 range (chart TF)                      |
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

//  higher-TF bias for swing
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
//|  Finds the most recent confirmed swing high or low.              |
//|  Returns true and fills price + shift (bar index, 0=current).    |
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

//  Confirms Elliott-style structure: sequence of higher-lows (up) or lower-highs (down)
//  using the last two same-type pivots. Returns +1/-1/0.
int WaveStructureBias(int frac,int lookback)
  {
   // find last two swing lows and last two swing highs
   double l1,l2,h1,h2; int sl1,sl2,sh1,sh2;
   bool gl1 = FindLastSwing(false,frac,lookback,l1,sl1);
   bool gh1 = FindLastSwing(true ,frac,lookback,h1,sh1);
   if(!gl1 || !gh1) return(0);

   // search for the previous low (older than sl1)
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

   bool hl = (l1>l2);   // higher low
   bool hh = (h1>h2);   // higher high
   bool ll = (l1<l2);   // lower low
   bool lh = (h1<h2);   // lower high

   if(hl && hh) return(1);
   if(ll && lh) return(-1);
   return(0);
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
   int waveT  = WaveStructureBias(frac,InpPivotLookback);
   if(chartT==0) return(0);
   if(waveT!=0 && waveT!=chartT) return(0);     // structure must agree with trend

   // swing also needs higher-TF agreement
   if(swingProfile)
     {
      int htf = HTFTrend();
      if(htf!=0 && htf!=chartT) return(0);
     }

   double ask = SymbolInfoDouble(g_sym,SYMBOL_ASK);
   double bid = SymbolInfoDouble(g_sym,SYMBOL_BID);

   if(chartT>0)   // ----- BUY setup (looking for end of a pullback / wave start) -----
     {
      if(IsBuyBlocked()) return(0);
      double swingLow; int shift;
      if(!FindLastSwing(false,frac,InpPivotLookback,swingLow,shift)) return(0);
      if(shift>InpMaxPullbackBars) return(0);            // entry must be fresh
      double close1 = iClose(g_sym,_Period,1);
      if(close1 <= swingLow) return(0);                   // price must hold above pullback low
      if(rsi <= 50.0 || rsi >= 78.0) return(0);           // momentum turning up, not overbought

      entry = ask;
      sl    = NormalizePrice(swingLow - atr*InpSLBufferATR);
      double risk = entry - sl;
      if(risk <= 0) return(0);
      if(risk > atr*InpMaxRiskATR) return(0);             // reject oversized stop
      return(1);
     }
   else           // ----- SELL setup -----
     {
      if(IsSellBlocked()) return(0);
      double swingHigh; int shift;
      if(!FindLastSwing(true,frac,InpPivotLookback,swingHigh,shift)) return(0);
      if(shift>InpMaxPullbackBars) return(0);
      double close1 = iClose(g_sym,_Period,1);
      if(close1 >= swingHigh) return(0);
      if(rsi >= 50.0 || rsi <= 22.0) return(0);

      entry = bid;
      sl    = NormalizePrice(swingHigh + atr*InpSLBufferATR);
      double risk = sl - entry;
      if(risk <= 0) return(0);
      if(risk > atr*InpMaxRiskATR) return(0);
      return(-1);
     }
  }

bool IsBuyBlocked()  { return(g_direction==DIR_SELL); }
bool IsSellBlocked() { return(g_direction==DIR_BUY);  }

//+------------------------------------------------------------------+
//| Entry orchestration                                              |
//+------------------------------------------------------------------+
void CheckForEntry()
  {
   if(CountOurPositions() >= InpMaxPositions) return;
   if(!SpreadOK()) return;

   int dir=0; double entry=0, sl=0;

   // priority: swing first when allowed (cleaner structure), then scalp
   if(g_style==STYLE_SWING || g_style==STYLE_BOTH)
      dir = ComputeSignal(true,entry,sl);

   if(dir==0 && (g_style==STYLE_SCALP || g_style==STYLE_BOTH))
      dir = ComputeSignal(false,entry,sl);

   if(dir==0) return;

   double risk = MathAbs(entry-sl);
   if(risk<=0) return;

   double lot = CalcLot(risk);
   if(lot<=0) return;

   double tp = (dir>0) ? entry + risk*InpRR : entry - risk*InpRR;
   sl = NormalizePrice(sl);
   tp = NormalizePrice(tp);

   bool ok=false;
   if(dir>0) ok = g_trade.Buy(lot,g_sym,0.0,sl,tp,g_botName);
   else      ok = g_trade.Sell(lot,g_sym,0.0,sl,tp,g_botName);

   if(ok)
     {
      // resolve the resulting position ticket and record its real open price/volume
      ulong posTicket = FindRecentPositionTicket();
      double recVol   = lot;
      double recEntry = entry;
      if(posTicket>0 && PositionSelectByTicket(posTicket))
        {
         recVol   = PositionGetDouble(POSITION_VOLUME);
         recEntry = PositionGetDouble(POSITION_PRICE_OPEN);
        }
      AddPositionState(posTicket, recVol, recEntry, risk, dir);
      PrintFormat("%s ENTRY %s lot=%.2f entry=%.*f sl=%.*f tp=%.*f R=%.*f",
                  g_botName,(dir>0?"BUY":"SELL"),lot,g_digits,entry,g_digits,sl,g_digits,tp,g_digits,risk);
     }
   else
      PrintFormat("%s order failed: %d %s",g_botName,g_trade.ResultRetcode(),g_trade.ResultRetcodeDescription());
  }

double PositionGetVolume(ulong ticket)
  {
   if(PositionSelectByTicket(ticket)) return(PositionGetDouble(POSITION_VOLUME));
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
//| Money management                                                 |
//+------------------------------------------------------------------+
double CalcLot(double riskPrice)
  {
   double lot;
   if(InpMMMode==MM_FIXED_LOT)
      lot = InpFixedLot;
   else
     {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskMoney = balance * InpRiskPercent/100.0;
      double ticksAtRisk = riskPrice / g_tickSize;
      double lossPerLot  = ticksAtRisk * g_tickValue;
      if(lossPerLot<=0) return(0);
      lot = riskMoney / lossPerLot;
     }
   lot = NormalizeVolumeDown(lot);
   if(lot < g_volMin) lot = g_volMin;
   if(lot > g_volMax) lot = g_volMax;
   if(lot > InpMaxLot) lot = NormalizeVolumeDown(InpMaxLot);
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
//| Position state tracking                                          |
//+------------------------------------------------------------------+
int FindState(ulong ticket)
  {
   for(int i=0;i<ArraySize(g_pos);i++) if(g_pos[i].ticket==ticket) return(i);
   return(-1);
  }

void AddPositionState(ulong ticket,double vol,double entry,double risk,int dir)
  {
   if(ticket==0) return;
   if(FindState(ticket)>=0) return;
   int n=ArraySize(g_pos);
   ArrayResize(g_pos,n+1);
   g_pos[n].ticket=ticket;
   g_pos[n].initVolume=vol;
   g_pos[n].entry=entry;
   g_pos[n].risk=risk;
   g_pos[n].dir=dir;
   g_pos[n].stage=0;
   g_pos[n].beDone=false;
  }

void RemoveStateAt(int idx)
  {
   int n=ArraySize(g_pos);
   if(idx<0 || idx>=n) return;
   for(int i=idx;i<n-1;i++) g_pos[i]=g_pos[i+1];
   ArrayResize(g_pos,n-1);
  }

// rebuild state from open positions (e.g. after restart)
void RebuildPositionStates()
  {
   ArrayResize(g_pos,0);
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong t=PositionGetTicket(i);
      if(t==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=g_sym) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double vol   = PositionGetDouble(POSITION_VOLUME);
      int dir = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
      double risk = (sl>0)? MathAbs(entry-sl) : 0;
      AddPositionState(t,vol,entry,risk,dir);
     }
  }

//+------------------------------------------------------------------+
//| Manage all open positions (partial TP, BE, trailing, reversal)  |
//+------------------------------------------------------------------+
void ManageOpenPositions()
  {
   int chartT = ChartTrend();
   double atr = IndVal(h_atr,0,1);

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong t=PositionGetTicket(i);
      if(t==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=g_sym) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;

      int dir = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL = PositionGetDouble(POSITION_SL);
      double curTP = PositionGetDouble(POSITION_TP);
      double vol   = PositionGetDouble(POSITION_VOLUME);

      int si = FindState(t);
      if(si<0)
        {
         double risk = (curSL>0)? MathAbs(entry-curSL):0;
         AddPositionState(t,vol,entry,risk,dir);
         si = FindState(t);
        }
      if(si<0) continue;
      if(g_pos[si].risk<=0 && curSL>0) g_pos[si].risk=MathAbs(entry-curSL);
      double R = g_pos[si].risk;

      double price = (dir>0)? SymbolInfoDouble(g_sym,SYMBOL_BID) : SymbolInfoDouble(g_sym,SYMBOL_ASK);
      double rMult = (R>0)? ((price-entry)*dir)/R : 0;

      // ----- close on trend reversal -----
      if(InpCloseOnReversal && chartT!=0 && chartT!=dir)
        {
         g_trade.PositionClose(t);
         RemoveStateAt(si);
         continue;
        }

      // ----- staged partial take profits (1/3 booking) -----
      if(InpUsePartialTPs && R>0)
        {
         double third1 = NormalizeVolumeDown(g_pos[si].initVolume*InpClosePct1/100.0);
         double third2 = NormalizeVolumeDown(g_pos[si].initVolume*InpClosePct2/100.0);

         if(g_pos[si].stage<1 && rMult>=InpTP1_R)
           {
            if(third1>=g_volMin && (vol-third1)>=g_volMin)
               g_trade.PositionClosePartial(t,third1);
            g_pos[si].stage=1;
            // move SL to break-even
            if(InpMoveBE)
              {
               double be = entry + dir*InpBreakevenLockPts*g_point;
               ModifySLTP(t,dir,NormalizePrice(be),curTP);
               g_pos[si].beDone=true;
              }
            continue;
           }
         if(g_pos[si].stage<2 && rMult>=InpTP2_R)
           {
            vol = PositionGetVolume(t);
            if(third2>=g_volMin && (vol-third2)>=g_volMin)
               g_trade.PositionClosePartial(t,third2);
            g_pos[si].stage=2;
            // lock SL at TP1 (1R)
            double lock = entry + dir*R*InpTP1_R;
            ModifySLTP(t,dir,NormalizePrice(lock),curTP);
            continue;
           }
        }

      // ----- break-even even when partials are off -----
      if(InpMoveBE && !g_pos[si].beDone && R>0 && rMult>=InpTP1_R)
        {
         double be = entry + dir*InpBreakevenLockPts*g_point;
         if(ModifySLTP(t,dir,NormalizePrice(be),curTP)) g_pos[si].beDone=true;
        }

      // ----- trailing stop (follows the trade) -----
      if(InpUseTrailing && atr>0 && R>0 && rMult>=InpTrailStartR)
        {
         double trail = atr*InpTrailATRMult;
         double newSL = (dir>0)? price-trail : price+trail;
         newSL = NormalizePrice(newSL);
         double minDist = g_stopLevelPts*g_point;
         bool improves = (dir>0)? (curSL<=0 || newSL>curSL) : (curSL<=0 || newSL<curSL);
         bool farEnough= (dir>0)? (price-newSL>=minDist) : (newSL-price>=minDist);
         // never trail below break-even
         bool beyondBE = (dir>0)? (newSL>=entry) : (newSL<=entry);
         if(improves && farEnough && beyondBE)
            ModifySLTP(t,dir,newSL,curTP);
        }
     }

   // prune state entries whose positions no longer exist
   for(int i=ArraySize(g_pos)-1;i>=0;i--)
      if(!PositionSelectByTicket(g_pos[i].ticket)) RemoveStateAt(i);
  }

bool ModifySLTP(ulong ticket,int dir,double sl,double tp)
  {
   if(!PositionSelectByTicket(ticket)) return(false);
   double curSL=PositionGetDouble(POSITION_SL);
   double curTP=PositionGetDouble(POSITION_TP);
   if(MathAbs(curSL-sl)<g_point*0.5 && MathAbs(curTP-tp)<g_point*0.5) return(false);
   return(g_trade.PositionModify(ticket,sl,tp));
  }

//+------------------------------------------------------------------+
//| Statistics for dashboard                                         |
//+------------------------------------------------------------------+
void CalcStats()
  {
   // floating + open count
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
   g_stats.openCount=open;
   g_stats.floating=floating;

   // closed history
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
   g_statsLastCalc=TimeCurrent();
  }

//+------------------------------------------------------------------+
//| Dashboard panel                                                  |
//+------------------------------------------------------------------+
#define PANEL_W 250
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
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);
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
   int h = rows*ROW_H + 14;
   RectLabel(g_panelPrefix+"bg",x-6,y-6,PANEL_W,h,InpPanelBg,clrSlateGray);
   // title bar
   RectLabel(g_panelPrefix+"title",x-6,y-6,PANEL_W,ROW_H+6,C'10,40,80',clrSlateGray);

   // control buttons (bottom, just under the stats rows)
   int by = y + 13*ROW_H + 8;
   Button(g_panelPrefix+"btnStyle",x,    by,74,18,"Style",  C'40,60,90',clrWhite);
   Button(g_panelPrefix+"btnDir",  x+78, by,74,18,"Dir",    C'40,60,90',clrWhite);
   Button(g_panelPrefix+"btnPause",x+156,by,72,18,"Pause",  C'90,40,40',clrWhite);

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
string DirText()
  {
   switch(g_direction){
      case DIR_BUY:  return("UP/BUY");
      case DIR_SELL: return("DOWN/SELL");
      default:       return("BOTH");
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
   TextLabel(g_panelPrefix+"r_mode",x,y+r*ROW_H,"Style    : "+StyleText()+"   Dir: "+DirText(),clrAqua,fs); r++;

   int ct=ChartTrend(); int ht=HTFTrend();
   color tClr = ct>0?clrLime:(ct<0?clrTomato:clrSilver);
   TextLabel(g_panelPrefix+"r_trend",x,y+r*ROW_H,"Trend    : "+TrendText(ct)+"  (HTF "+TrendText(ht)+")",tClr,fs); r++;

   TextLabel(g_panelPrefix+"r_open",x,y+r*ROW_H,StringFormat("Open Pos : %d / %d",g_stats.openCount,InpMaxPositions),val,fs); r++;
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

   // refresh button captions / colors
   ObjectSetString(0,g_panelPrefix+"btnStyle",OBJPROP_TEXT,StyleText());
   ObjectSetString(0,g_panelPrefix+"btnDir",  OBJPROP_TEXT,DirText());
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
     {
      g_style = (ENUM_BOT_STYLE)(((int)g_style+1)%3);
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      UpdatePanel();
     }
   else if(sparam==g_panelPrefix+"btnDir")
     {
      g_direction = (ENUM_BOT_DIRECTION)(((int)g_direction+1)%3);
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      UpdatePanel();
     }
   else if(sparam==g_panelPrefix+"btnPause")
     {
      g_paused = !g_paused;
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      UpdatePanel();
     }
  }
//+------------------------------------------------------------------+
