#ifndef MOMENTUM_SCALPER_TYPES_MQH
#define MOMENTUM_SCALPER_TYPES_MQH

double MSPipFromPoint(const int digits,const double point)
  {
   if(point<=0) return 0.0;
   return ((digits==3 || digits==5) ? point*10.0 : point);
  }

double MSFloorVolume(const double raw,const double step,const double minimum,const double maximum)
  {
   if(raw<=0 || step<=0 || minimum<=0 || maximum<minimum) return 0.0;
   double capped=MathMin(raw,maximum);
   double volume=MathFloor((capped+1e-12)/step)*step;
   int digits=0; double scaled=step;
   while(digits<8 && MathAbs(scaled-MathRound(scaled))>1e-8) { scaled*=10.0; digits++; }
   volume=NormalizeDouble(volume,digits);
   if(volume<minimum-1e-10) return 0.0;
   return volume;
  }

double MSVolumeForRiskBudget(const double budget,const double loss_per_lot,const double step,const double minimum,const double maximum,double &risk)
  {
   risk=0.0;
   if(budget<=0 || loss_per_lot<=0) return 0.0;
   double volume=MSFloorVolume(budget/loss_per_lot,step,minimum,maximum);
   if(volume<=0) return 0.0;
   risk=volume*loss_per_lot;
   if(risk>budget+0.01) { risk=0.0; return 0.0; }
   return volume;
  }

bool MSDailyLossBreached(const double pnl,const double limit_money)
  { return limit_money>0.0 && pnl<=-limit_money; }

bool MSCooldownElapsed(const datetime last_entry,const datetime now,const int cooldown_seconds)
  { return cooldown_seconds<=0 || now-last_entry>=cooldown_seconds; }

bool MSPositionLimitReached(const int current_positions,const int maximum_positions)
  { return maximum_positions>0 && current_positions>=maximum_positions; }

int MSBrokerDayId(const datetime when)
  { MqlDateTime dt; TimeToStruct(when,dt); return dt.year*10000+dt.mon*100+dt.day; }

struct MSConfig
  {
   int      tick_window;
   double   momentum_pips;
   double   stop_pips;
   double   target_pips;
   int      max_hold_seconds;
   double   max_spread_pips;
   int      cooldown_seconds;
   double   risk_percent;
   double   daily_loss_percent;
   int      max_positions;
   int      max_trades_day;
   int      min_ticks_per_minute;
   double   max_window_range_pips;
   int      session_start_hour;
   int      session_start_minute;
   int      session_end_hour;
   int      session_end_minute;
   int      stale_quote_seconds;
   double   max_jump_pips;
   int      max_deviation_points;
   int      retry_count;
   bool     close_on_daily_loss;
   bool     break_even_enabled;
   double   break_even_trigger_pips;
   bool     trailing_enabled;
   double   trailing_distance_pips;
   ulong    magic;
   int      log_level;
   bool     csv_log;
   bool     session_filter_enabled;
   bool     demo_only;
   bool     require_eurusd;
  };

struct MSSignal
  {
   int      direction; // 1 buy, -1 sell, 0 none
   double   momentum_pips;
   double   bid;
   double   ask;
   double   spread_pips;
   datetime time;
  };

#endif
