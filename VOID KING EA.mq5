//+------------------------------------------------------------------+
//|                                                 VOID KING EA.mq5 |
//|                                     Copyright 2026, CYCLONE POSH |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, CYCLONE POSH"
#property link      "https://www.mql5.com"
#property version   "1.01"
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

//+------------------------------------------------------------------+
//| Global expert object                                             |
//+------------------------------------------------------------------+
CExpert ExtExpert;

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

//--- ok
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitialization function of the expert                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ExtExpert.Deinit();
  }

//+------------------------------------------------------------------+
//| "Tick" event handler function                                    |
//+------------------------------------------------------------------+
void OnTick()
  {
   ExtExpert.OnTick();
  }

//+------------------------------------------------------------------+
//| "Trade" event handler function                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
   ExtExpert.OnTrade();
  }

//+------------------------------------------------------------------+
//| "Timer" event handler function                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   ExtExpert.OnTimer();
  }

//+------------------------------------------------------------------+
