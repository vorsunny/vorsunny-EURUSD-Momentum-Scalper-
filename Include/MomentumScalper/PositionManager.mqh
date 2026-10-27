#ifndef MOMENTUM_SCALPER_POSITION_MANAGER_MQH
#define MOMENTUM_SCALPER_POSITION_MANAGER_MQH

class MSPositionManager
  {
private:
   string m_symbol;
   ulong m_magic;
   int m_deviation;
   datetime m_tracked_opened;
   ulong m_tracked_identifier;
   bool m_had_position;
   MSLogger *m_log;
   bool ModifyStops(const ulong ticket,const double sl,const double tp,const string reason)
     {
      MqlTradeRequest req; MqlTradeResult result; ZeroMemory(req); ZeroMemory(result);
      req.action=TRADE_ACTION_SLTP; req.position=ticket; req.symbol=m_symbol; req.magic=m_magic; req.sl=sl; req.tp=tp;
      bool sent=OrderSend(req,result);
      m_log.Write(1,"STOP_UPDATE",StringFormat("ticket=%I64u reason=%s sent=%s retcode=%u sl=%.5f tp=%.5f",ticket,reason,(sent?"true":"false"),result.retcode,sl,tp));
      return sent && result.retcode==TRADE_RETCODE_DONE;
     }
public:
   MSPositionManager(void) { m_symbol=""; m_magic=0; m_deviation=20; m_tracked_opened=0; m_tracked_identifier=0; m_had_position=false; m_log=NULL; }
   void Init(const string symbol,const ulong magic,const int deviation,MSLogger &logger)
     { m_symbol=symbol; m_magic=magic; m_deviation=deviation; m_tracked_opened=0; m_tracked_identifier=0; m_had_position=false; m_log=GetPointer(logger); }
   void Manage(const MSConfig &cfg,const double pip,MSExecutionEngine &execution,const bool daily_locked)
     {
      execution.RefreshPending();
      bool found_managed=false;
      for(int i=PositionsTotal()-1;i>=0;i--)
        {
         ulong ticket=PositionGetTicket(i); if(ticket==0) continue;
         if(PositionGetString(POSITION_SYMBOL)!=m_symbol || PositionGetInteger(POSITION_MAGIC)!=(long)m_magic) continue;
         found_managed=true;
         datetime opened=(datetime)PositionGetInteger(POSITION_TIME);
         ulong identifier=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
         if(!m_had_position || identifier!=m_tracked_identifier)
           { m_tracked_opened=opened; m_tracked_identifier=identifier; m_had_position=true; }
         int duration=(int)(TimeTradeServer()-opened);
         if(cfg.max_hold_seconds>0 && duration>=cfg.max_hold_seconds)
           { execution.Close(ticket,"maximum holding time"); continue; }
         if(daily_locked && cfg.close_on_daily_loss)
           { execution.Close(ticket,"daily loss circuit breaker"); continue; }
         if((!cfg.break_even_enabled && !cfg.trailing_enabled) || pip<=0) continue;
         MqlTick tick; if(!SymbolInfoTick(m_symbol,tick)) continue;
         ENUM_POSITION_TYPE side=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double entry=PositionGetDouble(POSITION_PRICE_OPEN), old_sl=PositionGetDouble(POSITION_SL), tp=PositionGetDouble(POSITION_TP);
         double current=(side==POSITION_TYPE_BUY ? tick.bid : tick.ask);
         double profit_pips=(side==POSITION_TYPE_BUY ? current-entry : entry-current)/pip;
         double proposed=old_sl;
         if(cfg.break_even_enabled && profit_pips>=cfg.break_even_trigger_pips)
           {
            double be=entry;
            if(side==POSITION_TYPE_BUY && (proposed==0 || be>proposed)) proposed=be;
            if(side==POSITION_TYPE_SELL && (proposed==0 || be<proposed)) proposed=be;
           }
         if(cfg.trailing_enabled && cfg.trailing_distance_pips>0 && profit_pips>cfg.trailing_distance_pips)
           {
            double trail=(side==POSITION_TYPE_BUY ? current-cfg.trailing_distance_pips*pip : current+cfg.trailing_distance_pips*pip);
            if(side==POSITION_TYPE_BUY && (proposed==0 || trail>proposed)) proposed=trail;
            if(side==POSITION_TYPE_SELL && (proposed==0 || trail<proposed)) proposed=trail;
           }
         int digits=(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS); double point=SymbolInfoDouble(m_symbol,SYMBOL_POINT);
         proposed=NormalizeDouble(proposed,digits);
         if(proposed>0 && MathAbs(proposed-old_sl)>point*0.5)
           {
            int min_level=(int)MathMax(SymbolInfoInteger(m_symbol,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(m_symbol,SYMBOL_TRADE_FREEZE_LEVEL));
            double min_distance=min_level*point;
            bool valid=(side==POSITION_TYPE_BUY ? proposed<tick.bid-min_distance : proposed>tick.ask+min_distance);
            if(valid) ModifyStops(ticket,proposed,tp,(cfg.trailing_enabled?"trailing":"break_even"));
           }
        }
      if(!found_managed && m_had_position)
        {
         int duration=(int)(TimeTradeServer()-m_tracked_opened);
         m_log.Write(1,"POSITION_CLOSED",StringFormat("identifier=%I64u duration_seconds=%d",m_tracked_identifier,duration));
         m_had_position=false; m_tracked_opened=0; m_tracked_identifier=0;
        }
     }
  };

#endif
