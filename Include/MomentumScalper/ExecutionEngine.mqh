#ifndef MOMENTUM_SCALPER_EXECUTION_ENGINE_MQH
#define MOMENTUM_SCALPER_EXECUTION_ENGINE_MQH

class MSExecutionEngine
  {
private:
   string m_symbol;
   ulong m_magic;
   int m_deviation;
   int m_retry_count;
   bool m_pending;
   datetime m_pending_since;
   ulong m_pending_order;
   ulong m_close_pending_ticket;
   ulong m_close_pending_order;
   datetime m_close_pending_since;
   MSLogger *m_log;

   ENUM_ORDER_TYPE_FILLING FillingMode(void) const
     {
      long modes=SymbolInfoInteger(m_symbol,SYMBOL_FILLING_MODE);
      if((modes & SYMBOL_FILLING_IOC)==SYMBOL_FILLING_IOC) return ORDER_FILLING_IOC;
      if((modes & SYMBOL_FILLING_FOK)==SYMBOL_FILLING_FOK) return ORDER_FILLING_FOK;
      return ORDER_FILLING_RETURN;
     }
   bool TradePermissions(const int direction,string &reason) const
     {
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
         !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
        { reason="terminal, EA, or account trading permission disabled"; return false; }
      long mode=SymbolInfoInteger(m_symbol,SYMBOL_TRADE_MODE);
      if(mode==SYMBOL_TRADE_MODE_DISABLED || mode==SYMBOL_TRADE_MODE_CLOSEONLY)
        { reason="symbol trading mode does not allow new entries"; return false; }
      if(direction>0 && mode==SYMBOL_TRADE_MODE_SHORTONLY) { reason="symbol permits sell orders only"; return false; }
      if(direction<0 && mode==SYMBOL_TRADE_MODE_LONGONLY) { reason="symbol permits buy orders only"; return false; }
      reason=""; return true;
     }
   bool IsRecoverable(const uint code) const
     { return (code==TRADE_RETCODE_REQUOTE || code==TRADE_RETCODE_PRICE_CHANGED || code==TRADE_RETCODE_PRICE_OFF); }
   bool Send(const MqlTradeRequest &request,MqlTradeResult &result,const string label)
     {
      ZeroMemory(result);
      bool sent=OrderSend(request,result);
      string info=StringFormat("label=%s sent=%s retcode=%u order=%I64u deal=%I64u price=%.5f volume=%.2f comment=%s",
                               label,(sent?"true":"false"),result.retcode,result.order,result.deal,result.price,result.volume,result.comment);
      m_log.Write(1,"ORDER_RESULT",info);
      return sent;
     }
public:
   MSExecutionEngine(void)
     { m_symbol=""; m_magic=0; m_deviation=20; m_retry_count=1; m_pending=false; m_pending_since=0; m_pending_order=0; m_close_pending_ticket=0; m_close_pending_order=0; m_close_pending_since=0; m_log=NULL; }
   void Init(const string symbol,const ulong magic,const int deviation,const int retries,MSLogger &logger)
     {
      m_symbol=symbol; m_magic=magic; m_deviation=deviation; m_retry_count=MathMax(0,MathMin(retries,3)); m_log=GetPointer(logger);
     }
   bool HasPending(void) const { return m_pending; }
   bool HasPendingClose(const ulong ticket) const { return m_close_pending_ticket==ticket; }
   int ManagedPositionCount(void) const
     {
      int n=0;
      for(int i=0;i<PositionsTotal();i++)
        {
         ulong ticket=PositionGetTicket(i); if(ticket==0) continue;
         if(PositionGetString(POSITION_SYMBOL)==m_symbol && PositionGetInteger(POSITION_MAGIC)==(long)m_magic) n++;
        }
      return n;
     }
   bool HasAnySymbolPosition(void) const
     {
      for(int i=0;i<PositionsTotal();i++)
        { ulong ticket=PositionGetTicket(i); if(ticket>0 && PositionGetString(POSITION_SYMBOL)==m_symbol) return true; }
      return false;
     }
   bool Enter(const int direction,const double volume,const double stop_pips,const double target_pips,const double pip,const double estimated_risk,const int maximum_positions)
     {
      string reason;
      if(m_pending) { m_log.Write(1,"ENTRY_REJECT","execution already pending"); return false; }
      if(!TradePermissions(direction,reason)) { m_log.Write(0,"ENTRY_REJECT",reason); return false; }
      if(MSPositionLimitReached(ManagedPositionCount(),maximum_positions)) { m_log.Write(1,"ENTRY_REJECT","EA position limit reached"); return false; }
      // On netting accounts, any existing position would be merged or reduced by a new deal.
      if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && HasAnySymbolPosition())
        { m_log.Write(0,"ENTRY_REJECT","netting account has an existing symbol position; refusing to alter unrelated exposure"); return false; }
      if(volume<=0 || pip<=0) { m_log.Write(0,"ENTRY_REJECT","invalid volume or pip size"); return false; }
      for(int attempt=0;attempt<=m_retry_count;attempt++)
        {
         MqlTick tick; if(!SymbolInfoTick(m_symbol,tick) || tick.bid<=0 || tick.ask<=0 || tick.ask<tick.bid)
           { m_log.Write(0,"ENTRY_REJECT","invalid quote at submission"); return false; }
         double point=SymbolInfoDouble(m_symbol,SYMBOL_POINT);
         int digits=(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS);
         int min_distance=(int)MathMax(SymbolInfoInteger(m_symbol,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(m_symbol,SYMBOL_TRADE_FREEZE_LEVEL));
         double distance=stop_pips*pip;
         double tp_distance=target_pips*pip;
         if(distance<(min_distance+1)*point || tp_distance<(min_distance+1)*point)
           { m_log.Write(0,"ENTRY_REJECT",StringFormat("configured SL/TP violates broker stop/freeze distance required=%d points",min_distance+1)); return false; }
         double price=(direction>0 ? tick.ask : tick.bid);
         double sl=NormalizeDouble((direction>0 ? price-distance : price+distance),digits);
         double tp=NormalizeDouble((direction>0 ? price+tp_distance : price-tp_distance),digits);
         ENUM_ORDER_TYPE type=(direction>0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
         double margin=0;
         if(!OrderCalcMargin(type,m_symbol,volume,price,margin)) { m_log.Write(0,"ENTRY_REJECT","OrderCalcMargin failed"); return false; }
         if(margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE)) { m_log.Write(0,"ENTRY_REJECT",StringFormat("insufficient free margin required=%.2f free=%.2f",margin,AccountInfoDouble(ACCOUNT_MARGIN_FREE))); return false; }
         MqlTradeRequest req; MqlTradeCheckResult check; MqlTradeResult result;
         ZeroMemory(req); ZeroMemory(check); ZeroMemory(result);
         req.action=TRADE_ACTION_DEAL; req.symbol=m_symbol; req.magic=m_magic; req.volume=volume; req.type=type;
         req.price=price; req.sl=sl; req.tp=tp; req.deviation=m_deviation; req.type_filling=FillingMode(); req.type_time=ORDER_TIME_GTC;
         if(!OrderCheck(req,check) || (check.retcode!=TRADE_RETCODE_DONE && check.retcode!=0))
           { m_log.Write(0,"ENTRY_REJECT",StringFormat("OrderCheck retcode=%u comment=%s",check.retcode,check.comment)); return false; }
         m_log.Write(1,"ORDER_REQUEST",StringFormat("side=%s volume=%.2f requested=%.5f sl=%.5f tp=%.5f est_risk=%.2f margin=%.2f attempt=%d",
                           direction>0?"BUY":"SELL",volume,price,sl,tp,estimated_risk,margin,attempt+1));
         bool sent=Send(req,result,"entry");
         if(sent && (result.retcode==TRADE_RETCODE_DONE || result.retcode==TRADE_RETCODE_DONE_PARTIAL))
           {
            double point=SymbolInfoDouble(m_symbol,SYMBOL_POINT);
            double pip=MSPipFromPoint((int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS),point);
            double slip=(pip>0 ? (result.price-req.price)/pip*(direction>0?1.0:-1.0) : 0.0);
            m_log.Write(0,"ENTRY_FILL",StringFormat("confirmed retcode=%u deal=%I64u order=%I64u fill_price=%.5f fill_volume=%.2f slippage=%.3f pips",result.retcode,result.deal,result.order,result.price,result.volume,slip));
            if(ManagedPositionCount()==0)
              { m_pending=true; m_pending_since=TimeTradeServer(); m_pending_order=result.order; }
            else { m_pending=false; m_pending_order=0; }
            return true;
           }
         if(sent && result.retcode==TRADE_RETCODE_PLACED)
           { m_pending=true; m_pending_since=TimeTradeServer(); m_pending_order=result.order; m_log.Write(0,"ENTRY_PENDING",StringFormat("order=%I64u awaiting transaction confirmation",result.order)); return true; }
         if(!IsRecoverable(result.retcode) || attempt>=m_retry_count) break;
        }
      m_log.Write(0,"ENTRY_REJECT","order not filled; no further retry");
      m_pending=false; return false;
     }
   bool Close(const ulong ticket,const string why)
     {
      if(ticket==0) return false;
      if(m_close_pending_ticket==ticket) return false;
      if(!PositionSelectByTicket(ticket)) return true;
      if(PositionGetString(POSITION_SYMBOL)!=m_symbol || PositionGetInteger(POSITION_MAGIC)!=(long)m_magic) return false;
      MqlTick tick; if(!SymbolInfoTick(m_symbol,tick) || tick.bid<=0 || tick.ask<=0) { m_log.Write(0,"EXIT_REJECT","invalid quote for close"); return false; }
      ENUM_POSITION_TYPE side=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double volume=PositionGetDouble(POSITION_VOLUME);
      MqlTradeRequest req; MqlTradeResult result; ZeroMemory(req); ZeroMemory(result);
      req.action=TRADE_ACTION_DEAL; req.position=ticket; req.symbol=m_symbol; req.magic=m_magic; req.volume=volume;
      req.type=(side==POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY);
      req.price=(side==POSITION_TYPE_BUY ? tick.bid : tick.ask); req.deviation=m_deviation; req.type_filling=FillingMode();
      MqlTradeCheckResult check; ZeroMemory(check);
      if(!OrderCheck(req,check) || (check.retcode!=TRADE_RETCODE_DONE && check.retcode!=0))
        {
         m_close_pending_ticket=ticket; m_close_pending_order=0; m_close_pending_since=TimeTradeServer();
         m_log.Write(0,"EXIT_REJECT",StringFormat("OrderCheck retcode=%u comment=%s",check.retcode,check.comment)); return false;
        }
      m_log.Write(1,"EXIT_REQUEST",StringFormat("ticket=%I64u reason=%s volume=%.2f price=%.5f",ticket,why,volume,req.price));
      bool sent=Send(req,result,"exit");
      if(sent && (result.retcode==TRADE_RETCODE_DONE || result.retcode==TRADE_RETCODE_DONE_PARTIAL))
        {
         double pip=MSPipFromPoint((int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS),SymbolInfoDouble(m_symbol,SYMBOL_POINT));
         double slip=(pip>0 ? (side==POSITION_TYPE_BUY ? req.price-result.price : result.price-req.price)/pip : 0.0);
         m_log.Write(0,"EXIT_FILL",StringFormat("ticket=%I64u fill_price=%.5f fill_volume=%.2f slippage=%.3f pips retcode=%u",ticket,result.price,result.volume,slip,result.retcode));
         m_close_pending_ticket=ticket; m_close_pending_order=result.order; m_close_pending_since=TimeTradeServer(); return true;
        }
      if(sent && result.retcode==TRADE_RETCODE_PLACED)
        { m_close_pending_ticket=ticket; m_close_pending_order=result.order; m_close_pending_since=TimeTradeServer(); return true; }
      m_close_pending_ticket=ticket; m_close_pending_order=0; m_close_pending_since=TimeTradeServer();
      m_log.Write(0,"EXIT_REJECT",StringFormat("ticket=%I64u retcode=%u; retry gated for five seconds",ticket,result.retcode)); return false;
     }
   void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
     {
      if(trans.type==TRADE_TRANSACTION_DEAL_ADD && trans.deal>0)
        {
         if(HistoryDealSelect(trans.deal) && HistoryDealGetInteger(trans.deal,DEAL_MAGIC)==(long)m_magic && HistoryDealGetString(trans.deal,DEAL_SYMBOL)==m_symbol)
           {
            ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
            if(entry==DEAL_ENTRY_IN || entry==DEAL_ENTRY_INOUT) { m_pending=false; m_pending_order=0; }
            if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY)
              {
               m_close_pending_ticket=0; m_close_pending_order=0; m_close_pending_since=0;
               m_log.Write(1,"CLOSE_DEAL",StringFormat("deal=%I64u price=%.5f volume=%.2f pnl=%.2f",trans.deal,HistoryDealGetDouble(trans.deal,DEAL_PRICE),HistoryDealGetDouble(trans.deal,DEAL_VOLUME),HistoryDealGetDouble(trans.deal,DEAL_PROFIT)));
              }
           }
        }
      if(m_pending && TimeTradeServer()-m_pending_since>10 && ManagedPositionCount()==0 &&
         (m_pending_order==0 || !OrderSelect(m_pending_order)))
        { m_log.Write(0,"PENDING_TIMEOUT","accepted order is no longer active and no EA position exists; clearing execution latch"); m_pending=false; m_pending_order=0; }
     }
   void RefreshPending(void)
     {
      if(m_close_pending_ticket>0 && !PositionSelectByTicket(m_close_pending_ticket)) { m_close_pending_ticket=0; m_close_pending_order=0; m_close_pending_since=0; }
      if(m_close_pending_ticket>0 && TimeTradeServer()-m_close_pending_since>5 && (m_close_pending_order==0 || !OrderSelect(m_close_pending_order)))
        { m_close_pending_ticket=0; m_close_pending_order=0; m_close_pending_since=0; }
      if(m_pending && TimeTradeServer()-m_pending_since>10 && ManagedPositionCount()==0 &&
         (m_pending_order==0 || !OrderSelect(m_pending_order))) { m_pending=false; m_pending_order=0; }
     }
  };

#endif
