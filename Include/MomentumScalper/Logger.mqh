#ifndef MOMENTUM_SCALPER_LOGGER_MQH
#define MOMENTUM_SCALPER_LOGGER_MQH

class MSLogger
  {
private:
   int m_level;
   bool m_csv;
   int m_file;
   string m_prefix;
   bool m_tester;

public:
   MSLogger(void) { m_level=1; m_csv=false; m_file=INVALID_HANDLE; m_tester=false; }
   void Init(const int level,const bool csv,const ulong magic,const string symbol)
     {
      m_level=level; m_csv=csv; m_tester=(bool)MQLInfoInteger(MQL_TESTER);
      m_prefix=(m_tester ? "tester" : "terminal")+"_momentum_"+IntegerToString((long)magic)+"_"+StringSubstr(symbol,0,16);
      StringReplace(m_prefix,".","_");
      if(m_csv)
        {
         string name=m_prefix+".csv";
         m_file=FileOpen(name,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
         if(m_file!=INVALID_HANDLE)
           {
            if(FileSize(m_file)==0) FileWrite(m_file,"server_time","environment","event","details");
            FileSeek(m_file,0,SEEK_END);
           }
        }
     }
   void Write(const int level,const string event,const string details)
     {
      if(level>m_level) return;
      string env=(m_tester ? "TESTER" : "TERMINAL");
      Print("[MomentumScalper][",env,"][",event,"] ",details);
      if(m_file!=INVALID_HANDLE)
        {
         FileWrite(m_file,TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),env,event,details);
         FileFlush(m_file);
        }
     }
   void Close(void) { if(m_file!=INVALID_HANDLE) { FileClose(m_file); m_file=INVALID_HANDLE; } }
  };

#endif
