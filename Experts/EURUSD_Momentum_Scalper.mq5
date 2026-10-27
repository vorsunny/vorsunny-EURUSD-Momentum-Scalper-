#property strict
#property version   "1.00"
#property description "Tick momentum scalper with independent risk, execution, and position controls. Demo only by default."

#include <MomentumScalper/Types.mqh>
#include <MomentumScalper/Logger.mqh>
#include <MomentumScalper/SignalEngine.mqh>
#include <MomentumScalper/RiskManager.mqh>
#include <MomentumScalper/ExecutionEngine.mqh>
#include <MomentumScalper/PositionManager.mqh>

input int      InpTickWindow=30;
input double   InpMomentumThresholdPips=1.5;
input double   InpStopLossPips=5.0;
input double   InpTakeProfitPips=7.5;
input int      InpMaximumHoldingSeconds=60;
input double   InpMaximumSpreadPips=1.0;
input int      InpMinimumSecondsBetweenEntries=30;
input double   InpRiskPercent=0.10;
input double   InpMaximumDailyLossPercent=1.0;
input int      InpMaximumSimultaneousPositions=1;
input int      InpMaximumTradesPerDay=30;
input int      InpMinimumTicksPerMinute=10;
input double   InpMaximumWindowRangePips=8.0;
input double   InpMaximumSingleTickJumpPips=5.0;
input int      InpStaleQuoteSeconds=3;
input bool     InpSessionFilterEnabled=false;
input int      InpSessionStartHour=0;
input int      InpSessionStartMinute=0;
input int      InpSessionEndHour=23;
input int      InpSessionEndMinute=59;
input int      InpMaximumDeviationPoints=20;
input int      InpRecoverableRetryCount=1;
input bool     InpClosePositionsOnDailyLoss=true;
input bool     InpBreakEvenEnabled=false;
input double   InpBreakEvenTriggerPips=3.0;
input bool     InpTrailingStopEnabled=false;
input double   InpTrailingDistancePips=3.0;
input ulong    InpMagicNumber=26010271;
input int      InpLoggingLevel=1; // 0 errors/decisions, 1 operational, 2 diagnostic
input bool     InpCsvLogging=true;
input bool     InpDemoAccountOnly=true;
input bool     InpRequireEURUSD=true;

MSConfig g_cfg;
MSLogger g_log;
MSSignalEngine g_signal;
MSRiskManager g_risk;
MSExecutionEngine g_execution;
MSPositionManager g_positions;
double g_pip=0.0001;
string g_cooldown_key="";

void BuildConfig(void)
  {
   g_cfg.tick_window=InpTickWindow; g_cfg.momentum_pips=InpMomentumThresholdPips;
   g_cfg.stop_pips=InpStopLossPips; g_cfg.target_pips=InpTakeProfitPips;
   g_cfg.max_hold_seconds=InpMaximumHoldingSeconds; g_cfg.max_spread_pips=InpMaximumSpreadPips;
   g_cfg.cooldown_seconds=InpMinimumSecondsBetweenEntries; g_cfg.risk_percent=InpRiskPercent;
   g_cfg.daily_loss_percent=InpMaximumDailyLossPercent; g_cfg.max_positions=InpMaximumSimultaneousPositions;
   g_cfg.max_trades_day=InpMaximumTradesPerDay; g_cfg.min_ticks_per_minute=InpMinimumTicksPerMinute;
   g_cfg.max_window_range_pips=InpMaximumWindowRangePips; g_cfg.max_jump_pips=InpMaximumSingleTickJumpPips;
   g_cfg.stale_quote_seconds=InpStaleQuoteSeconds; g_cfg.session_filter_enabled=InpSessionFilterEnabled;
   g_cfg.session_start_hour=InpSessionStartHour; g_cfg.session_start_minute=InpSessionStartMinute;
   g_cfg.session_end_hour=InpSessionEndHour; g_cfg.session_end_minute=InpSessionEndMinute;
   g_cfg.max_deviation_points=InpMaximumDeviationPoints; g_cfg.retry_count=InpRecoverableRetryCount;
   g_cfg.close_on_daily_loss=InpClosePositionsOnDailyLoss; g_cfg.break_even_enabled=InpBreakEvenEnabled;
   g_cfg.break_even_trigger_pips=InpBreakEvenTriggerPips; g_cfg.trailing_enabled=InpTrailingStopEnabled;
   g_cfg.trailing_distance_pips=InpTrailingDistancePips; g_cfg.magic=InpMagicNumber;
   g_cfg.log_level=InpLoggingLevel; g_cfg.csv_log=InpCsvLogging;
   g_cfg.demo_only=InpDemoAccountOnly; g_cfg.require_eurusd=InpRequireEURUSD;
  }

double PipSize(const string symbol)
  {
   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   return MSPipFromPoint(digits,point);
  }

bool SessionAllowed(const datetime when)
  {
   if(!g_cfg.session_filter_enabled) return true;
   MqlDateTime dt; TimeToStruct(when,dt);
   int now=dt.hour*60+dt.min;
   int start=g_cfg.session_start_hour*60+g_cfg.session_start_minute;
   int finish=g_cfg.session_end_hour*60+g_cfg.session_end_minute;
   if(start==finish) return true;
   if(start<finish) return now>=start && now<finish;
   return now>=start || now<finish;
  }

bool CooldownAllowed(string &reason)
  {
   reason="";
   if(g_cfg.cooldown_seconds<=0 || !GlobalVariableCheck(g_cooldown_key)) return true;
   datetime last=(datetime)GlobalVariableGet(g_cooldown_key);
   datetime now=TimeTradeServer();
   if(!MSCooldownElapsed(last,now,g_cfg.cooldown_seconds))
     {
      int remaining=g_cfg.cooldown_seconds-(int)(now-last);
      reason=StringFormat("entry cooldown (%d seconds remain)",remaining);
      return false;
     }
   return true;
  }

void ManagePositions(void)
  {
   double pnl=0; string reason;
   g_risk.CanTrade(g_cfg.max_trades_day,pnl,reason);
   g_positions.Manage(g_cfg,g_pip,g_execution,g_risk.IsLocked());
  }

int OnInit(void)
  {
   BuildConfig();
   string symbol=_Symbol;
   g_log.Init(g_cfg.log_level,g_cfg.csv_log,g_cfg.magic,_Symbol);
   if(g_cfg.demo_only && (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO)
     { g_log.Write(0,"INIT_REJECT","demo-account-only protection is enabled; account is not a demo account"); return INIT_FAILED; }
   if(g_cfg.require_eurusd && StringFind(symbol,"EURUSD")!=0)
     { g_log.Write(0,"INIT_REJECT","attach to EURUSD or a broker suffix symbol beginning EURUSD"); return INIT_FAILED; }
   if(g_cfg.tick_window<2 || g_cfg.tick_window>512 || g_cfg.stop_pips<=0 || g_cfg.target_pips<=0 ||
      g_cfg.risk_percent<=0 || g_cfg.risk_percent>100 || g_cfg.daily_loss_percent<0 ||
      g_cfg.max_positions<1 || g_cfg.max_positions>10 || g_cfg.max_trades_day<1 || g_cfg.stale_quote_seconds<1 ||
      g_cfg.momentum_pips<=0 || g_cfg.max_spread_pips<0 || g_cfg.cooldown_seconds<0 ||
      g_cfg.max_hold_seconds<0 || g_cfg.min_ticks_per_minute<0 || g_cfg.min_ticks_per_minute>512 ||
      g_cfg.max_window_range_pips<0 || g_cfg.max_jump_pips<0 || g_cfg.retry_count<0 || g_cfg.retry_count>3 ||
      g_cfg.max_deviation_points<0 || g_cfg.log_level<0 || g_cfg.log_level>2 ||
      g_cfg.break_even_trigger_pips<0 || g_cfg.trailing_distance_pips<0 ||
      g_cfg.session_start_hour<0 || g_cfg.session_start_hour>23 ||
      g_cfg.session_end_hour<0 || g_cfg.session_end_hour>23 || g_cfg.session_start_minute<0 ||
      g_cfg.session_start_minute>59 || g_cfg.session_end_minute<0 || g_cfg.session_end_minute>59)
     { g_log.Write(0,"INIT_REJECT","one or more inputs are outside supported safe ranges"); return INIT_PARAMETERS_INCORRECT; }
   g_pip=PipSize(symbol);
   if(g_pip<=0 || !SymbolSelect(symbol,true)) { g_log.Write(0,"INIT_REJECT","symbol properties unavailable"); return INIT_FAILED; }
   if(!g_signal.Init(g_cfg.tick_window,g_cfg.momentum_pips,g_pip,g_cfg.max_window_range_pips,g_cfg.max_jump_pips,g_cfg.min_ticks_per_minute))
     { g_log.Write(0,"INIT_REJECT","signal engine configuration invalid"); return INIT_PARAMETERS_INCORRECT; }
   if(!g_risk.Init(symbol,g_cfg.magic,g_cfg.daily_loss_percent,g_log))
     { g_log.Write(0,"INIT_REJECT","daily risk state could not be restored or persisted"); return INIT_FAILED; }
   g_execution.Init(symbol,g_cfg.magic,g_cfg.max_deviation_points,g_cfg.retry_count,g_log);
   g_positions.Init(symbol,g_cfg.magic,g_cfg.max_deviation_points,g_log);
   g_cooldown_key="MS_COOL_"+IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+"_"+IntegerToString((long)g_cfg.magic)+"_"+StringSubstr(symbol,0,16);
   StringReplace(g_cooldown_key,".","_");
   EventSetTimer(1);
   g_log.Write(1,"INITIALIZED",StringFormat("symbol=%s digits=%d pip=%.10f magic=%I64u account_mode=%d daily_risk_scope=ACCOUNT_WIDE",
                    symbol,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS),g_pip,g_cfg.magic,(int)AccountInfoInteger(ACCOUNT_MARGIN_MODE)));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_log.Write(1,"DEINITIALIZED",StringFormat("reason=%d",reason));
   g_log.Close();
  }

void OnTimer(void)
  {
   ManagePositions();
  }

void OnTick(void)
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0 || tick.ask<=0 || tick.ask<tick.bid)
     { g_log.Write(2,"FILTER","invalid quote"); return; }
   datetime now=TimeTradeServer();
   if(tick.time<=0 || now-tick.time>g_cfg.stale_quote_seconds || tick.time-now>2)
     { g_log.Write(2,"FILTER","stale or future quote"); return; }
   double spread=(tick.ask-tick.bid)/g_pip;
   if(g_cfg.max_spread_pips>0 && spread>g_cfg.max_spread_pips)
     { g_log.Write(2,"FILTER",StringFormat("spread=%.2f pips limit=%.2f",spread,g_cfg.max_spread_pips)); return; }
   if(!SessionAllowed(now)) { g_log.Write(2,"FILTER","outside configured broker-server session"); return; }

   MSSignal signal; string signal_reason;
   if(!g_signal.AddTick(tick.bid,tick.ask,tick.time,g_cfg.max_spread_pips,signal,signal_reason))
     { g_log.Write(1,"FILTER",signal_reason); return; }
   if(signal.direction==0)
     { if(signal_reason!="") g_log.Write(2,"FILTER",signal_reason); return; }

   g_log.Write(1,"SIGNAL",StringFormat("time=%s side=%s momentum=%.3f pips bid=%.5f ask=%.5f spread=%.3f pips",
                 TimeToString(signal.time,TIME_DATE|TIME_SECONDS),signal.direction>0?"BUY":"SELL",signal.momentum_pips,tick.bid,tick.ask,spread));
   g_signal.Consume(signal.direction);
   double daily_pnl=0; string reason;
   if(!g_risk.CanTrade(g_cfg.max_trades_day,daily_pnl,reason))
     { g_log.Write(0,"ENTRY_REJECT",StringFormat("reason=%s daily_pnl=%.2f",reason,daily_pnl)); return; }
   if(g_execution.HasPending()) { g_log.Write(2,"ENTRY_REJECT","execution awaiting server confirmation"); return; }
   if(MSPositionLimitReached(g_execution.ManagedPositionCount(),g_cfg.max_positions)) { g_log.Write(2,"ENTRY_REJECT","maximum EA position count reached"); return; }
   if(!CooldownAllowed(reason)) { g_log.Write(1,"ENTRY_REJECT",reason); return; }
   double entry=(signal.direction>0 ? tick.ask : tick.bid);
   double stop=(signal.direction>0 ? entry-g_cfg.stop_pips*g_pip : entry+g_cfg.stop_pips*g_pip);
   double estimated_risk=0;
   double volume=g_risk.CalculateVolume(_Symbol,signal.direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,entry,stop,g_cfg.risk_percent,estimated_risk,reason);
   if(volume<=0) { g_log.Write(0,"ENTRY_REJECT",StringFormat("sizing: %s",reason)); return; }
   if(!GlobalVariableSet(g_cooldown_key,(double)now))
     { g_log.Write(0,"ENTRY_REJECT","could not persist cooldown state; refusing to submit order"); return; }
   GlobalVariablesFlush();
   g_execution.Enter(signal.direction,volume,g_cfg.stop_pips,g_cfg.target_pips,g_pip,estimated_risk,g_cfg.max_positions);
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   g_execution.OnTradeTransaction(trans,request,result);
  }
