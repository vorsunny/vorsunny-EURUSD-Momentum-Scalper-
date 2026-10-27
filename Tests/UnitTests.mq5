#property strict
#property script_show_inputs
#include <MomentumScalper/Types.mqh>
#include <MomentumScalper/SignalEngine.mqh>

int g_failures=0;
void Check(const bool condition,const string name)
  {
   if(condition) Print("PASS: ",name);
   else { Print("FAIL: ",name); g_failures++; }
  }

void OnStart()
  {
   Check(MathAbs(MSPipFromPoint(5,0.00001)-0.0001)<1e-12,"five-digit pip conversion");
   Check(MathAbs(MSPipFromPoint(3,0.001)-0.01)<1e-12,"three-digit pip conversion");
   Check(MathAbs(MSPipFromPoint(4,0.0001)-0.0001)<1e-12,"four-digit pip conversion");
   Check(MSFloorVolume(0.019,0.01,0.01,100.0)==0.01,"volume rounds down to step");
   Check(MSFloorVolume(0.009,0.01,0.01,100.0)==0.0,"minimum lot is not forced above risk budget");
   Check(MSFloorVolume(7.0,0.01,0.01,2.0)==2.0,"volume respects broker maximum");
   Check(MSFloorVolume(0.03,0.01,0.01,0.025)==0.02,"maximum volume remains aligned to broker step");
   double risk=0;
   Check(MSVolumeForRiskBudget(20.0,1000.0,0.01,0.01,100.0,risk)==0.02 && MathAbs(risk-20.0)<0.01,"risk budget sizing uses loss per lot and volume step");
   Check(MSVolumeForRiskBudget(5.0,1000.0,0.01,0.01,100.0,risk)==0.0,"risk sizing rejects budget below minimum volume");
   Check(MSDailyLossBreached(-100.0,100.0),"daily loss boundary triggers at limit");
   Check(!MSDailyLossBreached(-99.99,100.0),"daily loss stays unlocked below limit");
   Check(MSCooldownElapsed(100,130,30) && !MSCooldownElapsed(100,129,30),"cooldown boundary math");
   Check(MSPositionLimitReached(1,1) && !MSPositionLimitReached(0,1),"position limit math");
   Check(MSBrokerDayId(StringToTime("2026.10.27 23:59:59"))==20261027,"broker day identifier");

   MSSignalEngine engine; MSSignal out; string why;
   Check(engine.Init(3,1.0,0.0001,0.0,0.0,0),"signal engine initializes");
   engine.AddTick(1.10000,1.10002,100,0,out,why);
   engine.AddTick(1.10005,1.10007,101,0,out,why);
   engine.AddTick(1.10020,1.10022,102,0,out,why);
   Check(out.direction==1 && MathAbs(out.momentum_pips-2.0)<0.02,"window momentum uses oldest of latest N ticks");
   engine.Consume(1);
   engine.AddTick(1.10020,1.10022,103,0,out,why);
   Check(out.direction==0 && why=="signal already consumed","signal latch suppresses repeated same episode");
   engine.AddTick(1.10000,1.10002,104,0,out,why);
   engine.AddTick(1.09980,1.09982,105,0,out,why);
   Check(out.direction==-1,"rolling buffer can produce opposite direction after turnover");
   Print("Unit test failures: ",g_failures);
  }
