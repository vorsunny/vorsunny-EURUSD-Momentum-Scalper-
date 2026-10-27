# TradingView indicator

`TradingView/EURUSD_Momentum_Scalper_Indicator.pine` is a Pine Script v6 chart indicator that mirrors the EA's rolling-sample momentum signal and principal market filters. It draws BUY/SELL markers, offers alert conditions, and plots indicative stop and target levels from the latest signal.

## Install

1. Open the EURUSD chart in TradingView.
2. Open Pine Editor, paste the `.pine` file, and choose **Add to chart**.
3. Use **Realtime updates** to accumulate live chart updates in a fixed 512-slot circular buffer. The buffer warms up from the time the indicator is added; TradingView does not provide historical tick-by-tick replay to Pine.
4. Choose **Bar-close proxy** to evaluate one chart close per confirmed bar across history. In that mode, the window is N bars, not N ticks, so signals will differ from the EA and depend on chart timeframe. The tick-rate filter is skipped in this proxy mode because bar samples cannot represent tick activity.
5. Confirm pip size for the feed. Auto pip sizing supports standard fractional/non-fractional FX quote precision; use the pip size override for nonstandard increments.
6. Create TradingView alerts from **EURUSD Momentum BUY** and **EURUSD Momentum SELL**. Choose the alert frequency appropriate to whether you want intrabar or bar-close notifications.

## Limits compared with the MT5 EA

Pine indicators can display signals and raise alerts but cannot submit or manage broker orders. The script uses chart `close` as its sampled price, not a broker bid/ask midpoint. Pine does not provide a consistent historical bid/ask spread series here, so spread filtering uses the user-entered assumed spread. It cannot enforce equity-based position sizing, free-margin checks, account-wide daily loss limits, stop placement, broker filling policies, partial-fill handling, or timed exits. Stop and target lines are visual references only.

TradingView only executes the script when chart updates arrive, so it cannot detect a stale feed while no updates are occurring. Sessions and the daily signal counter use the selected IANA timezone, not necessarily broker server time. Realtime update behavior depends on the data feed, chart type, and TradingView plan. This indicator is for signal visualization and controlled alert testing; it does not prove profitability or reproduce EA backtests.


## Strategy Tester backtest

`TradingView/EURUSD_Momentum_Scalper_Backtest.pine` is a separate `strategy()` version intended for the Strategy Tester. Add it to a EURUSD chart and use a 1-minute timeframe for the reference run. The rolling window is 30 bars in this version; it is a bar-close approximation, not 30 ticks. Use the Strategy Tester date controls for the project's Jan–Jun 2026 development window and Jul–Sep 2026 out-of-sample window. Freeze inputs before the out-of-sample run.

The strategy starts with EUR 10,000 and calculates quantity from 0.10% equity risk, stop distance, and the chart's point value/account-currency conversion. Verify the feed's quantity units and point value first. Set broker commission and slippage in **Strategy Properties**; their defaults in the script are zero. The assumed-spread input only gates signals and does not alter simulated fills. Repeat runs with wider assumed spread, commission, and slippage.

Protective stop/target orders are anchored to the signal bar close and can fill at the next bar open; a gap changes realized risk. The 60-second time exit is evaluated only at bar close and fills on the next available tick, so a 1-minute chart can exceed that holding time. Strategy Tester intrabar OHLC assumptions, available Bar Magnifier data, spread, and feed contract specifications affect results. The backtest script does not simulate partial fills, broker rejections, the EA's daily equity circuit breaker, or its timer-driven exit precision.

No TradingView chart/Strategy Tester connection was available in this workspace, so neither Pine script was compiled in TradingView and no strategy report or performance result is claimed. Use the procedure in `Docs/BACKTEST.md` and save the Tester report and cost settings for each run.
