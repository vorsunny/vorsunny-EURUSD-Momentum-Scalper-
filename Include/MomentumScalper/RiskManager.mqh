#ifndef MOMENTUM_SCALPER_RISK_MANAGER_MQH
#define MOMENTUM_SCALPER_RISK_MANAGER_MQH

class MSRiskManager
  {
private:
   string m_key;
   string m_symbol;
   ulong m_magic;
   double m_daily_limit_pct;
   double m_day_start_equity;
   int m_day_id;
   bool m_locked;
   bool m_history_ok;
   MSLogger *m_log;

   datetime DayStart(const datetime when) const
     { MqlDateTime dt; TimeToStruct(when,dt); dt.hour=0; dt.min=0; dt.sec=0; return StructToTime(dt); }
   int DayId(const datetime when) const
     { return MSBrokerDayId(when); }
   bool Save(void)
     {
      bool ok=true;
      if(!GlobalVariableSet(m_key+"_day",(double)m_day_id)) ok=false;
      if(!GlobalVariableSet(m_key+"_equity",m_day_start_equity)) ok=false;
      if(!GlobalVariableSet(m_key+"_lock",(m_locked ? 1.0 : 0.0))) ok=false;
      if(ok) GlobalVariablesFlush();
      return ok;
     }

public:
   MSRiskManager(void) { m_key=""; m_symbol=""; m_magic=0; m_daily_limit_pct=1.0; m_day_start_equity=0; m_day_id=0; m_locked=false; m_history_ok=true; m_log=NULL; }
   bool Init(const string symbol,const ulong magic,const double daily_limit_pct,MSLogger &logger)
     {
      m_symbol=symbol; m_magic=magic; m_daily_limit_pct=daily_limit_pct; m_history_ok=true; m_log=GetPointer(logger);
      m_key="MS_"+IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+"_"+IntegerToString((long)magic)+"_"+StringSubstr(symbol,0,16);
      StringReplace(m_key,".","_"); StringReplace(m_key,"-","_");
      datetime now=TimeTradeServer(); int day=DayId(now);
      if(GlobalVariableCheck(m_key+"_day") && (int)GlobalVariableGet(m_key+"_day")==day)
        {
         if(!GlobalVariableCheck(m_key+"_equity") || !GlobalVariableCheck(m_key+"_lock")) return false;
         m_day_id=day; m_day_start_equity=GlobalVariableGet(m_key+"_equity");
         m_locked=(GlobalVariableGet(m_key+"_lock")>0.5);
         if(m_day_start_equity<=0) return false;
        }
      else
        {
         m_day_id=day; m_day_start_equity=AccountInfoDouble(ACCOUNT_EQUITY); m_locked=false;
         if(m_day_start_equity<=0 || !Save()) return false;
        }
      return true;
     }
   void RefreshDay(void)
     {
      datetime now=TimeTradeServer(); int day=DayId(now);
      if(day!=m_day_id)
        {
         m_day_id=day; m_day_start_equity=AccountInfoDouble(ACCOUNT_EQUITY); m_locked=false;
         if(m_day_start_equity<=0 || !Save()) m_history_ok=false;
         m_log.Write(1,"RISK_RESET",StringFormat("broker_day=%d start_equity=%.2f",m_day_id,m_day_start_equity));
        }
     }
   double DailyPnL(void)
     {
      RefreshDay(); datetime from=DayStart(TimeTradeServer());
      if(!HistorySelect(from,TimeTradeServer())) { m_history_ok=false; return 0.0; }
      m_history_ok=true;
      double pnl=0.0; int total=HistoryDealsTotal();
      for(int i=0;i<total;i++)
        {
         ulong ticket=HistoryDealGetTicket(i); if(ticket==0) continue;
         ENUM_DEAL_TYPE type=(ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket,DEAL_TYPE);
         if(type==DEAL_TYPE_BUY || type==DEAL_TYPE_SELL)
           pnl+=HistoryDealGetDouble(ticket,DEAL_PROFIT)+HistoryDealGetDouble(ticket,DEAL_SWAP)+HistoryDealGetDouble(ticket,DEAL_COMMISSION)+HistoryDealGetDouble(ticket,DEAL_FEE);
         else if(type==DEAL_TYPE_COMMISSION || type==DEAL_TYPE_COMMISSION_DAILY || type==DEAL_TYPE_COMMISSION_MONTHLY ||
                 type==DEAL_TYPE_COMMISSION_AGENT_DAILY || type==DEAL_TYPE_COMMISSION_AGENT_MONTHLY || type==DEAL_TYPE_CHARGE || type==DEAL_TYPE_INTEREST)
           pnl+=HistoryDealGetDouble(ticket,DEAL_PROFIT)+HistoryDealGetDouble(ticket,DEAL_COMMISSION)+HistoryDealGetDouble(ticket,DEAL_FEE);
        }
      for(int i=0;i<PositionsTotal();i++)
        {
         ulong ticket=PositionGetTicket(i); if(ticket==0) continue;
         pnl+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
        }
      return pnl;
     }
   int TradesToday(void)
     {
      RefreshDay(); datetime from=DayStart(TimeTradeServer());
      if(!HistorySelect(from,TimeTradeServer())) { m_history_ok=false; return 0; }
      m_history_ok=true;
      int count=0; int total=HistoryDealsTotal();
      for(int i=0;i<total;i++)
        {
         ulong ticket=HistoryDealGetTicket(i); if(ticket==0) continue;
         if(HistoryDealGetInteger(ticket,DEAL_MAGIC)!=(long)m_magic) continue;
         if(HistoryDealGetString(ticket,DEAL_SYMBOL)!=m_symbol) continue;
         ENUM_DEAL_TYPE type=(ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket,DEAL_TYPE);
         ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket,DEAL_ENTRY);
         if((type==DEAL_TYPE_BUY || type==DEAL_TYPE_SELL) && (entry==DEAL_ENTRY_IN || entry==DEAL_ENTRY_INOUT)) count++;
        }
      return count;
     }
   bool CanTrade(const int max_trades,double &pnl,string &reason)
     {
      RefreshDay(); pnl=DailyPnL();
      if(!m_history_ok) { reason="broker history unavailable; entries disabled"; return false; }
      if(m_locked) { reason="daily loss circuit breaker locked"; return false; }
      double limit=m_day_start_equity*m_daily_limit_pct/100.0;
      if(MSDailyLossBreached(pnl,limit))
        {
         m_locked=true;
         if(!Save()) m_history_ok=false;
         reason="daily loss limit breached";
         m_log.Write(0,"RISK_LOCK",StringFormat("daily_pnl=%.2f limit=%.2f state_saved=%s",pnl,limit,(m_history_ok?"true":"false")));
         return false;
        }
      int trades=TradesToday();
      if(!m_history_ok) { reason="broker trade history unavailable; entries disabled"; return false; }
      if(max_trades>0 && trades>=max_trades) { reason="maximum trades per broker day"; return false; }
      reason=""; return true;
     }
   bool IsLocked(void) const { return m_locked; }
   double DailyLimitMoney(void) const { return m_day_start_equity*m_daily_limit_pct/100.0; }
   double CalculateVolume(const string symbol,const ENUM_ORDER_TYPE type,const double entry,const double stop,const double risk_pct,double &estimated_risk,string &reason)
     {
      estimated_risk=0; reason="";
      double equity=AccountInfoDouble(ACCOUNT_EQUITY), budget=equity*risk_pct/100.0;
      if(budget<=0 || entry<=0 || stop<=0) { reason="invalid sizing inputs"; return 0; }
      double one_lot=0;
      if(!OrderCalcProfit(type,symbol,1.0,entry,stop,one_lot)) { reason="OrderCalcProfit failed"; return 0; }
      double loss_per_lot=MathAbs(one_lot);
      if(loss_per_lot<=0) { reason="invalid calculated stop loss"; return 0; }
      double step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
      double minimum=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
      double maximum=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
      if(step<=0 || minimum<=0 || maximum<minimum) { reason="invalid broker volume specification"; return 0; }
      double volume=MSVolumeForRiskBudget(budget,loss_per_lot,step,minimum,maximum,estimated_risk);
      if(volume<=0) { reason=StringFormat("risk budget %.2f cannot support broker minimum volume %.2f",budget,minimum); return 0; }
      return volume;
     }
  };

#endif
