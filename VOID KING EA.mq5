//+------------------------------------------------------------------+
//|                                                 VOID KING EA.mq5 |
//|                                     Copyright 2026, CYCLONE POSH |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, CYCLONE POSH"
#property link      "https://www.mql5.com"
#property version   "1.02"
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
input double             Signal_StopLevel             = 500.0;                  // Stop Loss level (in points)
input double             Signal_TakeLevel             = 750.0;                  // Take Profit level (in points)
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

//--- Dashboard Settings
input bool               Show_Dashboard               = true;                   // Show Trading Dashboard
input ENUM_BASE_CORNER   Dashboard_Corner             = CORNER_RIGHT_UPPER;     // Dashboard position
input int                Dashboard_OffsetX             = 10;                    // Dashboard X offset
input int                Dashboard_OffsetY             = 30;                    // Dashboard Y offset
input color              Dashboard_BackColor          = clrDarkBlue;            // Dashboard background
input color              Dashboard_TextColor          = clrWhiteSmoke;          // Dashboard text color
input int                Dashboard_FontSize           = 9;                      // Font size

//+------------------------------------------------------------------+
//| Global expert object                                             |
//+------------------------------------------------------------------+
CExpert ExtExpert;

//--- Dashboard variables
struct DashboardInfo {
   int total_trades;
   int winning_trades;
   int losing_trades;
   double total_profit;
   double account_balance;
   double account_equity;
   double free_margin;
   string last_trade_signal;
   datetime last_trade_time;
   double win_rate;
};

DashboardInfo dashboard_data;

//+------------------------------------------------------------------+
//| Dashboard Drawing Function                                       |
//+------------------------------------------------------------------+
void DrawDashboard()
  {
   if(!Show_Dashboard) return;
   
   // Update dashboard data
   UpdateDashboardData();
   
   // Create background rectangle
   string bg_name = "VK_Dashboard_BG";
   if(ObjectFind(0, bg_name) == -1)
     {
      ObjectCreate(0, bg_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bg_name, OBJPROP_CORNER, Dashboard_Corner);
      ObjectSetInteger(0, bg_name, OBJPROP_XDISTANCE, Dashboard_OffsetX);
      ObjectSetInteger(0, bg_name, OBJPROP_YDISTANCE, Dashboard_OffsetY);
      ObjectSetInteger(0, bg_name, OBJPROP_XSIZE, 280);
      ObjectSetInteger(0, bg_name, OBJPROP_YSIZE, 280);
      ObjectSetInteger(0, bg_name, OBJPROP_BGCOLOR, Dashboard_BackColor);
      ObjectSetInteger(0, bg_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bg_name, OBJPROP_BORDER_COLOR, clrGold);
      ObjectSetInteger(0, bg_name, OBJPROP_BORDER_WIDTH, 2);
     }
   
   // Title
   DrawLabel("VK_Title", 0, 12, "◆ VOID KING EA - Dashboard ◆", Dashboard_TextColor, Dashboard_FontSize + 1);
   
   // Separator
   DrawLabel("VK_Sep1", 1, 22, "════════════════════════", clrGold, Dashboard_FontSize - 1);
   
   // Account Info
   DrawLabel("VK_Account", 2, 32, StringFormat("Account: %.2f USD", dashboard_data.account_balance), Dashboard_TextColor, Dashboard_FontSize);
   DrawLabel("VK_Equity", 3, 42, StringFormat("Equity: %.2f USD", dashboard_data.account_equity), clrLimeGreen, Dashboard_FontSize);
   DrawLabel("VK_Margin", 4, 52, StringFormat("Free Margin: %.2f", dashboard_data.free_margin), clrCyan, Dashboard_FontSize);
   
   // Separator
   DrawLabel("VK_Sep2", 5, 62, "════════════════════════", clrGold, Dashboard_FontSize - 1);
   
   // Trade Statistics
   color win_color = (dashboard_data.win_rate >= 50) ? clrLimeGreen : clrOrange;
   DrawLabel("VK_TotalTrades", 6, 72, StringFormat("Total Trades: %d", dashboard_data.total_trades), Dashboard_TextColor, Dashboard_FontSize);
   DrawLabel("VK_Winning", 7, 82, StringFormat("Win: %d | Loss: %d", dashboard_data.winning_trades, dashboard_data.losing_trades), win_color, Dashboard_FontSize);
   DrawLabel("VK_WinRate", 8, 92, StringFormat("Win Rate: %.2f%%", dashboard_data.win_rate), win_color, Dashboard_FontSize);
   DrawLabel("VK_Profit", 9, 102, StringFormat("P/L: %.2f USD", dashboard_data.total_profit), (dashboard_data.total_profit >= 0) ? clrLimeGreen : clrOrange, Dashboard_FontSize);
   
   // Separator
   DrawLabel("VK_Sep3", 10, 112, "════════════════════════", clrGold, Dashboard_FontSize - 1);
   
   // Signal Info
   DrawLabel("VK_Signal", 11, 122, StringFormat("Last Signal: %s", dashboard_data.last_trade_signal), clrYellow, Dashboard_FontSize);
   DrawLabel("VK_SignalTime", 12, 132, TimeToString(dashboard_data.last_trade_time, TIME_DATE|TIME_MINUTES), clrYellow, Dashboard_FontSize - 1);
   
   // Separator
   DrawLabel("VK_Sep4", 13, 142, "════════════════════════", clrGold, Dashboard_FontSize - 1);
   
   // Market Info
   DrawLabel("VK_Symbol", 14, 152, StringFormat("Symbol: %s | TF: %s", Symbol(), EnumToString(Period())), Dashboard_TextColor, Dashboard_FontSize - 1);
   DrawLabel("VK_Bid", 15, 162, StringFormat("Bid: %.5f | Ask: %.5f", SymbolInfoDouble(Symbol(), SYMBOL_BID), SymbolInfoDouble(Symbol(), SYMBOL_ASK)), Dashboard_TextColor, Dashboard_FontSize - 1);
   
   // Status
   string status = (ExtExpert.Enabled()) ? "RUNNING ▶" : "STOPPED ⏹";
   color status_color = (ExtExpert.Enabled()) ? clrLimeGreen : clrOrange;
   DrawLabel("VK_Status", 16, 172, status, status_color, Dashboard_FontSize);
  }

//+------------------------------------------------------------------+
//| Helper function to draw labels                                   |
//+------------------------------------------------------------------+
void DrawLabel(string name, int row, int y_offset, string text, color text_color, int font_size)
  {
   if(ObjectFind(0, name) == -1)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
     }
   
   ObjectSetInteger(0, name, OBJPROP_CORNER, Dashboard_Corner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, Dashboard_OffsetX + 10);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, Dashboard_OffsetY + y_offset);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
  }

//+------------------------------------------------------------------+
//| Update Dashboard Data Function                                   |
//+------------------------------------------------------------------+
void UpdateDashboardData()
  {
   dashboard_data.account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   dashboard_data.account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   dashboard_data.free_margin = AccountInfoDouble(ACCOUNT_FREEMARGIN);
   dashboard_data.total_profit = 0;
   dashboard_data.total_trades = 0;
   dashboard_data.winning_trades = 0;
   dashboard_data.losing_trades = 0;
   dashboard_data.win_rate = 0;
   
   // Count trades from order history
   int total_deals = HistoryDealsTotal();
   for(int i = 0; i < total_deals; i++)
     {
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket <= 0) continue;
      
      ulong deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
      if(deal_magic != Expert_MagicNumber) continue;
      
      ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
      double deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
      double deal_commission = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
      
      if(deal_type == DEAL_BUY || deal_type == DEAL_SELL)
        {
         dashboard_data.total_trades++;
         dashboard_data.total_profit += deal_profit + deal_commission;
         
         if(deal_profit > 0)
            dashboard_data.winning_trades++;
         else if(deal_profit < 0)
            dashboard_data.losing_trades++;
        }
     }
   
   if(dashboard_data.total_trades > 0)
      dashboard_data.win_rate = (double)dashboard_data.winning_trades / dashboard_data.total_trades * 100;
   
   dashboard_data.last_trade_signal = "READY";
   dashboard_data.last_trade_time = TimeCurrent();
  }

//+------------------------------------------------------------------+
//| Create Trade Comment Function                                    |
//+------------------------------------------------------------------+
string CreateTradeComment(int signal_type)
  {
   string comment = "VOID KING EA v1.02 | ";
   comment += "Magic:" + IntegerToString(Expert_MagicNumber) + " | ";
   comment += "Signal:" + (signal_type > 0 ? "BUY" : "SELL") + " | ";
   comment += "Symbol:" + Symbol() + " | ";
   comment += "TF:" + EnumToString(Period()) + " | ";
   comment += "Time:" + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + " | ";
   comment += "Threshold:" + IntegerToString(Signal_ThresholdOpen) + " | ";
   comment += "SL:" + DoubleToString(Signal_StopLevel, 0) + "pts | ";
   comment += "TP:" + DoubleToString(Signal_TakeLevel, 0) + "pts";
   
   return comment;
  }

//+------------------------------------------------------------------+
//| Get Signal Type Function                                         |
//+------------------------------------------------------------------+
int GetSignalType()
  {
   // Determine signal direction based on indicator values
   // BUY = 1, SELL = -1, NO SIGNAL = 0
   double stoch_main = iStochastic(Symbol(), Period(), Signal_Stoch_PeriodK, Signal_Stoch_PeriodD, Signal_Stoch_PeriodSlow, Signal_Stoch_Applied, MODE_MAIN, 0);
   double envelope_upper = iEnvelopes(Symbol(), Period(), Signal_Envelopes_PeriodMA, Signal_Envelopes_Shift, Signal_Envelopes_Method, Signal_Envelopes_Applied, Signal_Envelopes_Deviation, MODE_UPPER, 0);
   double envelope_lower = iEnvelopes(Symbol(), Period(), Signal_Envelopes_PeriodMA, Signal_Envelopes_Shift, Signal_Envelopes_Method, Signal_Envelopes_Applied, Signal_Envelopes_Deviation, MODE_LOWER, 0);
   
   double close_price = iClose(Symbol(), Period(), 0);
   
   // Simple signal logic
   if(stoch_main < 20 && close_price < envelope_lower)
      return 1;  // BUY signal
   else if(stoch_main > 80 && close_price > envelope_upper)
      return -1; // SELL signal
   
   return 0;  // No signal
  }

//+------------------------------------------------------------------+
//| Clean Dashboard Function                                         |
//+------------------------------------------------------------------+
void CleanDashboard()
  {
   for(int i = 0; i < 20; i++)
     {
      ObjectDelete(0, "VK_" + IntegerToString(i));
      ObjectDelete(0, "VK_" + EnumToString(Period()));
      ObjectDelete(0, "VK_Title");
      ObjectDelete(0, "VK_Dashboard_BG");
     }
  }

//+------------------------------------------------------------------+
//| Initialization function of the expert                            |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Initializing expert
   if(!ExtExpert.Init(Symbol(),Period(),Expert_EveryTick,Expert_MagicNumber))
     {
      //--- failed
      printf(__FUNCTION__+": error initializing expert");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }

//--- Creating signal
   CExpertSignal *signal=new CExpertSignal;
   if(signal==NULL)
     {
      //--- failed
      printf(__FUNCTION__+": error creating signal");
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
   CSignalStoch *filter0=new CSignalStoch;
   if(filter0==NULL)
     {
      //--- failed
      printf(__FUNCTION__+": error creating Stochastic filter");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }
   signal.AddFilter(filter0);

//--- Set Stochastic filter parameters
   filter0.PeriodK(Signal_Stoch_PeriodK);
   filter0.PeriodD(Signal_Stoch_PeriodD);
   filter0.PeriodSlow(Signal_Stoch_PeriodSlow);
   filter0.Applied(Signal_Stoch_Applied);
   filter0.Weight(Signal_Stoch_Weight);

//--- Creating Envelopes filter
   CSignalEnvelopes *filter1=new CSignalEnvelopes;
   if(filter1==NULL)
     {
      //--- failed
      printf(__FUNCTION__+": error creating Envelopes filter");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }
   signal.AddFilter(filter1);

//--- Set Envelopes filter parameters
   filter1.PeriodMA(Signal_Envelopes_PeriodMA);
   filter1.Shift(Signal_Envelopes_Shift);
   filter1.Method(Signal_Envelopes_Method);
   filter1.Applied(Signal_Envelopes_Applied);
   filter1.Deviation(Signal_Envelopes_Deviation);
   filter1.Weight(Signal_Envelopes_Weight);

//--- Creating Intraday Time Filter
   CSignalITF *filter2=new CSignalITF;
   if(filter2==NULL)
     {
      //--- failed
      printf(__FUNCTION__+": error creating ITF filter");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }
   signal.AddFilter(filter2);

//--- Set ITF parameters
   filter2.GoodHourOfDay(Signal_ITF_GoodHourOfDay);
   filter2.BadHoursOfDay(Signal_ITF_BadHoursOfDay);
   filter2.GoodDayOfWeek(Signal_ITF_GoodDayOfWeek);
   filter2.BadDaysOfWeek(Signal_ITF_BadDaysOfWeek);
   filter2.Weight(Signal_ITF_Weight);

//--- Creation of trailing object
   CTrailingPSAR *trailing=new CTrailingPSAR;
   if(trailing==NULL)
     {
      //--- failed
      printf(__FUNCTION__+": error creating trailing object");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }

//--- Add trailing to expert (will be deleted automatically)
   if(!ExtExpert.InitTrailing(trailing))
     {
      //--- failed
      printf(__FUNCTION__+": error initializing trailing");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }

//--- Set trailing parameters
   trailing.Step(Trailing_ParabolicSAR_Step);
   trailing.Maximum(Trailing_ParabolicSAR_Maximum);

//--- Creation of money management object
   CMoneyFixedLot *money=new CMoneyFixedLot;
   if(money==NULL)
     {
      //--- failed
      printf(__FUNCTION__+": error creating money management object");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }

//--- Add money to expert (will be deleted automatically)
   if(!ExtExpert.InitMoney(money))
     {
      //--- failed
      printf(__FUNCTION__+": error initializing money management");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }

//--- Set money management parameters
   money.Percent(Money_FixLot_Percent);
   money.Lots(Money_FixLot_Lots);

//--- Check all trading objects parameters
   if(!ExtExpert.ValidationSettings())
     {
      //--- failed
      printf(__FUNCTION__+": validation failed");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }

//--- Tuning of all necessary indicators
   if(!ExtExpert.InitIndicators())
     {
      //--- failed
      printf(__FUNCTION__+": error initializing indicators");
      ExtExpert.Deinit();
      return(INIT_FAILED);
     }

//--- Initialize dashboard
   DrawDashboard();

//--- ok
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitialization function of the expert                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ExtExpert.Deinit();
   CleanDashboard();
  }

//+------------------------------------------------------------------+
//| "Tick" event handler function                                    |
//+------------------------------------------------------------------+
void OnTick()
  {
   ExtExpert.OnTick();
   
   // Update dashboard every tick
   if(Show_Dashboard)
      DrawDashboard();
  }

//+------------------------------------------------------------------+
//| "Trade" event handler function                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
   ExtExpert.OnTrade();
   
   // Log trade information
   int signal_type = GetSignalType();
   string trade_comment = CreateTradeComment(signal_type);
   
   // Print to Journal
   PrintFormat("Trade executed: %s", trade_comment);
  }

//+------------------------------------------------------------------+
//| "Timer" event handler function                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   ExtExpert.OnTimer();
  }

//+------------------------------------------------------------------+
