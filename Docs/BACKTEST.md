# Backtest procedure

## Baseline run

1. Compile with the target MetaEditor build and keep the compiler log.
2. In Strategy Tester select this EA and the broker's EURUSD symbol (including any suffix).
3. Set model to **Every tick based on real ticks**.
4. Set initial deposit to EUR 10,000 and account currency EUR when available.
5. Run in-sample from 2026-01-01 through 2026-06-30.
6. Run out-of-sample from 2026-07-01 through 2026-09-30 with parameters frozen before the run.
7. Save tester report, journal, EA CSV, symbol specification, and tester build number for each run.

The requested calendar periods may not yet exist in a broker's real-tick archive. If data is unavailable, record the actual data coverage and do not substitute an overlapping sample while labeling it as the requested period.

## Report these metrics

Net profit after commission, swap, and modeled spread; profit factor; expectancy per trade; maximum equity drawdown in money and percent; win rate; average win and loss; trade frequency; average holding time; maximum consecutive losses; and exposure/trade count. Reconcile these with the tester's deal list. Do not infer profitability from gross profit or a single sample.

## Sensitivity runs

Keep the same frozen strategy and data while changing one execution assumption at a time: spread (baseline and wider levels), commission (broker schedule and stress level), and slippage/deviation (zero/low and stressed values where tester supports them). Also run an execution-delay sensitivity where supported. Record tester settings and avoid comparing runs with different data windows.

## Avoiding leakage

Use Jan–Jun only for development. Freeze parameters before July–September out-of-sample. Do not choose a parameter set based on out-of-sample results and then report that same window as an unbiased validation. Keep all attempted parameter variants and report the selection process. Do not optimize tick window, thresholds, stop, target, sessions, or filters on the OOS period.

## Limitations

Real-tick tests are still simulations. Historical liquidity, queue position, partial fills, latency, rejected requests, variable spreads, commissions, swaps, and demo/live execution can differ. `OrderCalcProfit`, margin, and symbol rules use tester/broker specifications. Strategy Tester cannot establish production execution quality or future returns. No results are included here because no MT5 Strategy Tester was available in the build environment.


## TradingView strategy proxy

Use `TradingView/EURUSD_Momentum_Scalper_Backtest.pine` on the EURUSD 1-minute chart in TradingView Strategy Tester. This script samples one close per bar, so a 30-sample window means 30 bars. It is not equivalent to the MT5 real-tick test or the indicator's realtime tick mode. Set tester commission and slippage in Strategy Properties; the script's defaults are zero. The assumed-spread input gates candidate signals only and is not a simulated fill spread. The script has a 1.0% strategy-equity daily loss limit by default: it blocks new entries for the rest of the selected timezone date and closes an open strategy position when enabled. This does not include account activity outside this strategy. Repeat at wider cost assumptions and compare the report. Time and daily-loss exits are evaluated on bar closes and execute at the next available tick, which can exceed their thresholds.

No TradingView Strategy Tester session was available from this environment. The Pine strategy is prepared for a chart-side run, but it has not been compiled or tested there and no results are reported.
