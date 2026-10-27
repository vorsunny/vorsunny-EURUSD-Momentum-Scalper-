#ifndef MOMENTUM_SCALPER_SIGNAL_ENGINE_MQH
#define MOMENTUM_SCALPER_SIGNAL_ENGINE_MQH

class MSSignalEngine
  {
private:
   double m_mid[512];
   datetime m_time[512];
   int m_capacity;
   int m_head;
   int m_count;
   int m_window;
   int m_latched_direction;
   double m_threshold;
   double m_max_range;
   double m_max_jump;
   int m_min_ticks_minute;
   double m_pip;

   int Physical(const int logical) const
     { return (m_head+logical)%m_capacity; }

public:
   MSSignalEngine(void)
     { m_capacity=512; m_head=0; m_count=0; m_window=30; m_latched_direction=0; m_threshold=1.5; m_max_range=0; m_max_jump=0; m_min_ticks_minute=0; m_pip=0.0001; }
   bool Init(const int window,const double threshold,const double pip,const double max_range,const double max_jump,const int min_ticks_minute)
     {
      if(window<2 || window>512 || pip<=0 || threshold<=0) return false;
      m_window=window; m_threshold=threshold; m_pip=pip; m_max_range=max_range;
      m_max_jump=max_jump; m_min_ticks_minute=min_ticks_minute;
      ArrayInitialize(m_mid,0.0); ArrayInitialize(m_time,0);
      m_head=0; m_count=0; m_latched_direction=0;
      return true;
     }
   int Count(void) const { return m_count; }
   void Consume(const int direction) { if(direction==1 || direction==-1) m_latched_direction=direction; }
   bool AddTick(const double bid,const double ask,const datetime stamp,const double max_spread,MSSignal &out,string &reason)
     {
      reason=""; out.direction=0;
      if(bid<=0 || ask<=0 || ask<bid || stamp<=0) { reason="invalid quote"; return false; }
      double mid=(bid+ask)*0.5;
      if(m_count>0)
        {
         int last=Physical(m_count-1);
         double jump=MathAbs(mid-m_mid[last])/m_pip;
         if(m_max_jump>0 && jump>m_max_jump) { reason="abnormal price jump"; return false; }
        }
      if(m_count==m_capacity) { m_head=(m_head+1)%m_capacity; m_count--; }
      int slot=Physical(m_count); m_mid[slot]=mid; m_time[slot]=stamp; m_count++;
      double spread=(ask-bid)/m_pip;
      out.bid=bid; out.ask=ask; out.spread_pips=spread; out.time=stamp;
      if(max_spread>0 && spread>max_spread) { reason="spread filter"; return true; }
      if(m_count<m_window) { reason="warming tick buffer"; return true; }
      int oldest=Physical(m_count-m_window);
      double momentum=(mid-m_mid[oldest])/m_pip;
      out.momentum_pips=momentum;
      if(m_max_range>0)
        {
         double lo=mid,hi=mid;
         for(int i=m_count-m_window;i<m_count;i++) { double p=m_mid[Physical(i)]; if(p<lo)lo=p; if(p>hi)hi=p; }
         if((hi-lo)/m_pip>m_max_range) { reason="volatility filter"; return true; }
        }
      int active=0;
      for(int i=m_count-1;i>=0;i--)
        {
         int idx=Physical(i);
         if(stamp-m_time[idx]>60) break;
         active++;
        }
      if(active<m_min_ticks_minute) { reason="minimum tick activity"; return true; }
      if(m_latched_direction!=0 && MathAbs(momentum)<m_threshold*0.5) m_latched_direction=0;
      int dir=(momentum>=m_threshold ? 1 : (momentum<=-m_threshold ? -1 : 0));
      if(dir!=0 && dir==m_latched_direction) { reason="signal already consumed"; return true; }
      if(dir!=0) out.direction=dir;
      return true;
     }
  };

#endif
