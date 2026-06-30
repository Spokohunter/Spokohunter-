//+------------------------------------------------------------------+
//|                                                 VOID KING EA.mq5 |
//|                                     Copyright 2026, CYCLONE POSH |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, CYCLONE POSH"
#property link      "https://www.mql5.com"
#property version   "1.03"
//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <Expert\Expert.mqh>
//--- available signals
#include <Expert\Signal\SignalStoch.mqh>
#include <Expert\Signal\SignalEnvelopes.mqh>
#include <Expert\Signal\SignalITF.mqh>
//--- available trailing
#include <Expert\Trailing\TrailingParabolicSAR.mqh>
//--- available money management
#include <Expert\Money\MoneyFixedLot.mqh>
//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
//--- inputs for expert
input string             Expert_Title                 = "VOID KING EA";         // Document name
ulong                    Expert_MagicNumber           = -1962608922;            // Magic Number
bool                     Expert_EveryTick             = false;                  // Trade on every tick

//--- inputs for main signal
input int                Signal_ThresholdOpen         = 25;                     // Signal threshold value to open [0...100]
input int                Signal_ThresholdClose        = 15;                     // Signal threshold value to close [0...100]
input double             Signal_PriceLevel            = 0.0;                    // Price level to execute a deal
input double             Signal_StopLevel             = 1500.0;                 // Stop Loss level (in points)
input double             Signal_TakeLevel             = 1750.0;                 // Take Profit level (in points)
input int                Signal_Expiration            = 4;                      // Expiration of pending orders (in bars)

//--- inputs for Stochastic signal
input int                Signal_Stoch_PeriodK         = 14;                     // Stochastic K-period
input int                Signal_Stoch_PeriodD         = 3;                      // Stochastic D-period
input int                Signal_Stoch_PeriodSlow      = 3;                      // Stochastic Period of slowing
input ENUM_STO_PRICE     Signal_Stoch_Applied         = STO_LOWHIGH;            // Stochastic Prices to apply
input double             Signal_Stoch_Weight          = 0.45;                   // Stochastic Weight [0...1.0]

//--- inputs for Envelopes signal
input int                Signal_Envelopes_PeriodMA    = 20;                     // Envelopes Period of averaging
input int                Signal_Envelopes_Shift       = 0;                      // Envelopes Time shift
input ENUM_MA_METHOD     Signal_Envelopes_Method      = MODE_EMA;               // Envelopes Method of averaging
input ENUM_APPLIED_PRICE Signal_Envelopes_Applied     = PRICE_CLOSE;            // Envelopes Prices series
input double             Signal_Envelopes_Deviation   = 0.25;                   // Envelopes Deviation
input double             Signal_Envelopes_Weight      = 0.35;                   // Envelopes Weight [0...1.0]

//--- inputs for Intraday Time Filter signal
input int                Signal_ITF_GoodHourOfDay     = -1;                     // ITF Good hour (-1=all)
input int                Signal_ITF_BadHoursOfDay     = 0;                      // ITF Bad hours (bit-map)
input int                Signal_ITF_GoodDayOfWeek     = -1;                     // ITF Good day of week (-1=all)
input int                Signal_ITF_BadDaysOfWeek     = 0;                      // ITF Bad days of week (bit-map)
input double             Signal_ITF_Weight            = 0.20;                   // ITF Weight [0...1.0]

//--- inputs for trailing
input double             Trailing_ParabolicSAR_Step   = 0.02;                   // Parabolic SAR Speed increment
input double             Trailing_ParabolicSAR_Maximum= 0.2;                    // Parabolic SAR Maximum rate

//--- inputs for money management
input double             Money_FixLot_Percent         = 10.0;                   // Percent of account
input double             Money_FixLot_Lots            = 0.01;                   // Fixed volume

//--- SMC Settings
input bool               Use_SMC                      = true;                   // Enable SMC (Smart Money Concepts)
input int                SMC_LookbackPeriod           = 20;                     // SMC Lookback period for structure
input double             SMC_BreakoutThreshold        = 1.5;                    // SMC Breakout threshold (ATR multiplier)
input bool               Show_SMC_Levels              = true;                   // Show SMC levels on chart
input bool               Show_Dashboard               = true;                   // Show Trading Dashboard

//+------------------------------------------------------------------+
//| SMC Structure Detection Class                                    |
//+------------------------------------------------------------------+
class CSMC
  {
private:
   int               m_lookback;
   double            m_swing_high;
   double            m_swing_low;
   int               m_swing_high_bar;
   int               m_swing_low_bar;
   double            m_resistance;
   double            m_support;
   bool              m_bullish_structure;
   bool              m_bearish_structure;

public:
                     CSMC(int lookback = 20) : m_lookback(lookback), m_swing_high(0), m_swing_low(0), 
                           m_swing_high_bar(0), m_swing_low_bar(0), m_resistance(0), m_support(0),
                           m_bullish_structure(false), m_bearish_structure(false) {}
                    ~CSMC(void) {}

   void              Update(void)
     {
      // Detect swing highs and lows
      DetectSwings();
      
      // Detect break of structure
      DetectStructureBreak();
     }

   void              DetectSwings(void)
     {
      m_swing_high = iHigh(Symbol(), Period(), 0);
      m_swing_low = iLow(Symbol(), Period(), 0);
      
      for(int i = 1; i < m_lookback; i++)
        {
         double high = iHigh(Symbol(), Period(), i);
         double low = iLow(Symbol(), Period(), i);
         
         if(high > m_swing_high)
           {
            m_swing_high = high;
            m_swing_high_bar = i;
           }
         if(low < m_swing_low)
           {
            m_swing_low = low;
            m_swing_low_bar = i;
           }
        }
      
      m_resistance = m_swing_high;
      m_support = m_swing_low;
     }

   void              DetectStructureBreak(void)
     {
      double close = iClose(Symbol(), Period(), 0);
      double prev_close = iClose(Symbol(), Period(), 1);
      
      // Bullish structure break: price closes above previous resistance
      if(close > m_resistance && prev_close <= m_resistance)
        {
         m_bullish_structure = true;
         m_bearish_structure = false;
        }
      // Bearish structure break: price closes below previous support
      else if(close < m_support && prev_close >= m_support)
        {
         m_bearish_structure = true;
         m_bullish_structure = false;
        }
      else
        {
         m_bullish_structure = false;
         m_bearish_structure = false;
        }
     }

   double            GetResistance(void) const { return m_resistance; }
   double            GetSupport(void) const { return m_support; }
   bool              IsBullishStructure(void) const { return m_bullish_structure; }
   bool              IsBearishStructure(void) const { return m_bearish_structure; }
   int               GetSwingHighBar(void) const { return m_swing_high_bar; }
   int               GetSwingLowBar(void) const { return m_swing_low_bar; }
  };

//+------------------------------------------------------------------+
//| Dashboard Panel Class                                            |
//+------------------------------------------------------------------+
class CDashboard
  {
private:
   string            m_prefix;
   int               m_x;
   int               m_y;
   int               m_width;
   int               m_height;
   color             m_bg_color;
   color             m_border_color;
   color             m_text_color;
   color             m_title_color;
   int               m_font_size;
   string            m_font_name;

   void              CreateObject(string name, ENUM_OBJECT type)
     {
      if(ObjectFind(0, name) < 0)
        {
         ObjectCreate(0, name, type, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        }
     }

public:
                     CDashboard(void)
     {
      m_prefix       = "VK_DB_";
      m_x            = 15;
      m_y            = 15;
      m_width        = 320;
      m_height       = 200;
      m_bg_color     = C'20,20,20';       // Dark charcoal background
      m_border_color = C'64,64,64';       // Slate gray border
      m_text_color   = C'210,210,210';    // Soft white text
      m_title_color  = C'0,229,188';      // Neon Teal title
      m_font_size    = 8;
      m_font_name    = "Consolas";        // Monospace text
     }
                    ~CDashboard(void) { Destroy(); }

   void              Create(void)
     {
      string bg_name = m_prefix + "BG";
      CreateObject(bg_name, OBJ_RECTANGLE_LABEL);
      ObjectSetInteger(0, bg_name, OBJPROP_XSIZE, m_width);
      ObjectSetInteger(0, bg_name, OBJPROP_YSIZE, m_height);
      ObjectSetInteger(0, bg_name, OBJPROP_XDISTANCE, m_x);
      ObjectSetInteger(0, bg_name, OBJPROP_YDISTANCE, m_y);
      ObjectSetInteger(0, bg_name, OBJPROP_BGCOLOR, m_bg_color);
      ObjectSetInteger(0, bg_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bg_name, OBJPROP_COLOR, m_border_color);
      
      // Title
      SetLabel("Title", "═══ VOID KING EA v1.03 ═══", m_x + 10, m_y + 8, m_title_color, 9, true);
      
      // Separator Line
      SetLabel("Sep1", "─────────────────────────────", m_x + 10, m_y + 22, C'80,80,80', 8, false);
     }

   void              SetLabel(string name, string text, int x, int y, color clr, int font_size=8, bool bold=false)
     {
      string obj_name = m_prefix + name;
      CreateObject(obj_name, OBJ_LABEL);
      ObjectSetString(0, obj_name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, font_size);
      ObjectSetString(0, obj_name, OBJPROP_FONT, m_font_name + (bold ? " Bold" : ""));
     }

   void              Update(ulong magic, CSMC &smc)
     {
      if(!Show_Dashboard) return;
      
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
      double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      double spread  = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
      
      int buy_pos = 0, sell_pos = 0;
      double total_profit = 0.0;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         if(PositionGetSymbol(i) == Symbol())
           {
            if(PositionGetInteger(POSITION_MAGIC) == magic)
              {
               long type = PositionGetInteger(POSITION_TYPE);
               if(type == POSITION_TYPE_BUY) buy_pos++;
               else if(type == POSITION_TYPE_SELL) sell_pos++;
               total_profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
              }
           }
        }
      
      int row = m_y + 36;
      int spacing = 14;
      
      SetLabel("Row_Bal", "Balance:  " + DoubleToString(balance, 2), m_x + 10, row, m_text_color, 8);
      row += spacing;
      SetLabel("Row_Eq", "Equity:   " + DoubleToString(equity, 2), m_x + 10, row, m_text_color, 8);
      row += spacing;
      SetLabel("Row_Margin", "F.Margin: " + DoubleToString(free_margin, 2), m_x + 10, row, m_text_color, 8);
      row += spacing;
      SetLabel("Row_Spread", "Spread:   " + DoubleToString(spread, 1) + " pts", m_x + 10, row, m_text_color, 8);
      row += spacing;
      SetLabel("Row_Positions", "Positions: " + IntegerToString(buy_pos) + "B | " + IntegerToString(sell_pos) + "S", m_x + 10, row, m_text_color, 8);
      row += spacing + 2;
      
      color profit_clr = (total_profit > 0.01) ? C'0,255,127' : (total_profit < -0.01 ? C'255,99,71' : m_text_color);
      string prof_sign = (total_profit > 0.01) ? "+" : "";
      SetLabel("Row_Profit", "Net PnL: " + prof_sign + DoubleToString(total_profit, 2), m_x + 10, row, profit_clr, 8, true);
      row += spacing + 4;
      
      // SMC Data
      SetLabel("Sep2", "─────────────────────────────", m_x + 10, row, C'80,80,80', 8, false);
      row += spacing;
      SetLabel("Row_Res", "Resistance: " + DoubleToString(smc.GetResistance(), 5), m_x + 10, row, C'255,99,71', 8);
      row += spacing;
      SetLabel("Row_Sup", "Support:    " + DoubleToString(smc.GetSupport(), 5), m_x + 10, row, C'0,200,255', 8);
      row += spacing;
      
      string smc_status = "SMC: ";
      color smc_clr = m_text_color;
      if(smc.IsBullishStructure())
        {
         smc_status += "↑ BULLISH";
         smc_clr = C'0,255,127';
        }
      else if(smc.IsBearishStructure())
        {
         smc_status += "↓ BEARISH";
         smc_clr = C'255,99,71';
        }
      else
        {
         smc_status += "NEUTRAL";
         smc_clr = C'255,255,0';
        }
      SetLabel("Row_SMC", smc_status, m_x + 10, row, smc_clr, 8, true);
      
      ChartRedraw(0);
     }

   void              Destroy(void)
     {
      ObjectsDeleteAll(0, m_prefix);
      ChartRedraw(0);
     }
  };

//+------------------------------------------------------------------+
//| Custom Expert Advisor subclass with custom trade comments        |
//+------------------------------------------------------------------+
class CVoidKingExpert : public CExpert
  {
public:
   virtual bool      OpenLong(double price, double sl, double tp) override
     {
      if(price == EMPTY_VALUE) return(false);
      double lot = LotOpenLong(price, sl);
      if(lot == 0.0) return(false);
      if(m_trade == NULL) return(false);
      return(m_trade.Buy(lot, price, sl, tp, "VOID KING EA | BUY | Magic: " + IntegerToString((int)Expert_MagicNumber)));
     }

   virtual bool      OpenShort(double price, double sl, double tp) override
     {
      if(price == EMPTY_VALUE) return(false);
      double lot = LotOpenShort(price, sl);
      if(lot == 0.0) return(false);
      if(m_trade == NULL) return(false);
      return(m_trade.Sell(lot, price, sl, tp, "VOID KING EA | SELL | Magic: " + IntegerToString((int)Expert_MagicNumber)));
     }
  };

//+------------------------------------------------------------------+
//| Global expert, dashboard and SMC objects                         |
//+------------------------------------------------------------------+
CVoidKingExpert ExtExpert;
CDashboard      G_Dashboard;
CSMC            G_SMC(SMC_LookbackPeriod);

//+------------------------------------------------------------------+
//| Initialization function of the expert                            |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Initializing expert
   if(!ExtExpert.Init(Symbol(), Period(), Expert_EveryTick, Expert_MagicNumber))
     {
      printf(__FUNCTION__ + ": error initializing expert");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }

//--- Creating signal
   CExpertSignal *signal = new CExpertSignal;
   if(signal == NULL)
     {
      printf(__FUNCTION__ + ": error creating signal");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }

//--- Initialize signal parameters
   ExtExpert.InitSignal(signal);
   signal.ThresholdOpen(Signal_ThresholdOpen);
   signal.ThresholdClose(Signal_ThresholdClose);
   signal.PriceLevel(Signal_PriceLevel);
   signal.StopLevel(Signal_StopLevel);
   signal.TakeLevel(Signal_TakeLevel);
   signal.Expiration(Signal_Expiration);

//--- Creating Stochastic filter
   CSignalStoch *filter0 = new CSignalStoch;
   if(filter0 == NULL)
     {
      printf(__FUNCTION__ + ": error creating Stochastic filter");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }
   signal.AddFilter(filter0);

   filter0.PeriodK(Signal_Stoch_PeriodK);
   filter0.PeriodD(Signal_Stoch_PeriodD);
   filter0.PeriodSlow(Signal_Stoch_PeriodSlow);
   filter0.Applied(Signal_Stoch_Applied);
   filter0.Weight(Signal_Stoch_Weight);

//--- Creating Envelopes filter
   CSignalEnvelopes *filter1 = new CSignalEnvelopes;
   if(filter1 == NULL)
     {
      printf(__FUNCTION__ + ": error creating Envelopes filter");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }
   signal.AddFilter(filter1);

   filter1.PeriodMA(Signal_Envelopes_PeriodMA);
   filter1.Shift(Signal_Envelopes_Shift);
   filter1.Method(Signal_Envelopes_Method);
   filter1.Applied(Signal_Envelopes_Applied);
   filter1.Deviation(Signal_Envelopes_Deviation);
   filter1.Weight(Signal_Envelopes_Weight);

//--- Creating Intraday Time Filter
   CSignalITF *filter2 = new CSignalITF;
   if(filter2 == NULL)
     {
      printf(__FUNCTION__ + ": error creating ITF filter");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }
   signal.AddFilter(filter2);

   filter2.GoodHourOfDay(Signal_ITF_GoodHourOfDay);
   filter2.BadHoursOfDay(Signal_ITF_BadHoursOfDay);
   filter2.GoodDayOfWeek(Signal_ITF_GoodDayOfWeek);
   filter2.BadDaysOfWeek(Signal_ITF_BadDaysOfWeek);
   filter2.Weight(Signal_ITF_Weight);

//--- Creation of trailing object
   CTrailingPSAR *trailing = new CTrailingPSAR;
   if(trailing == NULL)
     {
      printf(__FUNCTION__ + ": error creating trailing object");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }

   if(!ExtExpert.InitTrailing(trailing))
     {
      printf(__FUNCTION__ + ": error initializing trailing");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }

   trailing.Step(Trailing_ParabolicSAR_Step);
   trailing.Maximum(Trailing_ParabolicSAR_Maximum);

//--- Creation of money management object
   CMoneyFixedLot *money = new CMoneyFixedLot;
   if(money == NULL)
     {
      printf(__FUNCTION__ + ": error creating money management object");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }

   if(!ExtExpert.InitMoney(money))
     {
      printf(__FUNCTION__ + ": error initializing money management");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }

   money.Percent(Money_FixLot_Percent);
   money.Lots(Money_FixLot_Lots);

//--- Check all trading objects parameters
   if(!ExtExpert.ValidationSettings())
     {
      printf(__FUNCTION__ + ": validation failed");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }

//--- Tuning of all necessary indicators
   if(!ExtExpert.InitIndicators())
     {
      printf(__FUNCTION__ + ": error initializing indicators");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }

//--- Initialize and draw Dashboard panel
   G_Dashboard.Create();
   EventSetTimer(1); // Set timer update interval to 1 second

//--- ok
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitialization function of the expert                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ExtExpert.Deinit();
   G_Dashboard.Destroy();
   EventKillTimer();
  }

//+------------------------------------------------------------------+
//| "Tick" event handler function                                    |
//+------------------------------------------------------------------+
void OnTick()
  {
   ExtExpert.OnTick();
   
   if(Use_SMC)
     {
      G_SMC.Update();
     }
   
   G_Dashboard.Update(Expert_MagicNumber, G_SMC);
  }

//+------------------------------------------------------------------+
//| "Trade" event handler function                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
   ExtExpert.OnTrade();
   G_Dashboard.Update(Expert_MagicNumber, G_SMC);
  }

//+------------------------------------------------------------------+
//| "Timer" event handler function                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   ExtExpert.OnTimer();
   G_Dashboard.Update(Expert_MagicNumber, G_SMC);
  }

//+------------------------------------------------------------------+
