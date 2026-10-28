# TradingView companion version 2.2

The two Pine scripts are the TradingView companion to the cTrader cBot. The chart indicator runs on live chart updates and shows BUY/SELL markers, alert conditions, and indicative stop and target levels. The indicator also sends a detailed `alert()` message for each signal, including direction, momentum, signal price, stop, target, and assumed spread. The separate strategy runs in Strategy Tester. Both use the same default threshold, stop, target, cooldown, daily trade cap, spread assumption, volatility ceiling, jump ceiling, UTC session inputs and EURUSD restriction as the cTrader version where those controls can be represented.

The scripts cannot produce identical results to cTrader. The indicator samples the chart's latest close on live updates; the cTrader bot samples bid/ask midpoint ticks. The Strategy Tester script samples one close per historical bar, not ticks. Pine therefore cannot reproduce cTrader's tick activity filter, real spread stream, timer exit, account-wide equity circuit breaker or exact order execution. Use the same shared parameter values for a useful strategy comparison, then treat TradingView's report as a bar-based screening result.

FX pip sizing uses the quote-currency convention (0.0001 for EURUSD and 0.01 for JPY quote pairs), independent of fractional quote precision. Use the pip override for unusual symbols or nonstandard conventions.

## Install

1. Open the EURUSD chart in TradingView.
2. Open Pine Editor, select all existing text (Cmd+A on Mac or Ctrl+A on Windows), and replace it with the entire `.pine` file. Do not append it to the starter script: Pine permits only one `indicator()` or `strategy()` declaration. Save and choose **Add to chart**.
3. Use **Realtime updates** to accumulate live chart updates in a fixed 512-slot circular buffer. The buffer warms up from the time the indicator is added; TradingView does not provide historical tick-by-tick replay to Pine.
4. Choose **Bar-close proxy** to evaluate one chart close per confirmed bar across history. In that mode, the window is N bars, not N ticks, so signals will differ from the cTrader bot and depend on chart timeframe. The tick-rate filter is skipped in this proxy mode because bar samples cannot represent tick activity.
5. Confirm pip size for the feed. Auto pip sizing supports standard fractional/non-fractional FX quote precision; use the pip size override for nonstandard increments.
6. Create TradingView alerts from **EURUSD Momentum BUY** and **EURUSD Momentum SELL**. For realtime updates choose **Once Per Bar** to receive intrabar alerts; a bar-close-only alert can miss a signal that occurred earlier in the bar. Chart markers stay visible for the rest of that bar, while the alert condition is true only on the update that generated the signal. TradingView's alert frequency can limit multiple signals within one bar.

## Limits compared with the cTrader bot

Pine indicators can display signals and raise alerts but cannot submit or manage broker orders. The script uses chart `close` as its sampled price, not a broker bid/ask midpoint. Pine does not provide a consistent historical bid/ask spread series here, so spread filtering uses the user-entered assumed spread. It cannot enforce equity-based position sizing, free-margin checks, account-wide daily loss limits, stop placement, broker filling policies, partial-fill handling, or timed exits. Stop and target lines are visual references only.

TradingView only executes the script when chart updates arrive, so it cannot detect a stale feed while no updates are occurring. Sessions and the daily signal counter use the selected IANA timezone, not necessarily broker server time. Realtime update behavior depends on the data feed, chart type, and TradingView plan. This indicator is for signal visualization and controlled alert testing; it does not prove profitability or reproduce cTrader cBot backtests.

The live tick buffer is held in Pine's runtime memory; chart reloads restart that buffer, and Pine cannot reconstruct exact prior tick signals as chart labels. For a persistent event record, create a TradingView alert using **Any alert() function call**. Its detailed events remain in the TradingView Alerts Log while the alert is active. The alert runs independently of the open chart, but the on-chart markers appear only while the chart script is running. If you instead choose an **alertcondition** for BUY or SELL, do not also choose **Any alert() function call** for the same indicator, or each signal may notify twice. Recreate alerts after changing the script or its inputs so the alert uses the updated version.


## Strategy Tester backtest

`TradingView/EURUSD_Momentum_Scalper_Backtest.pine` is the Strategy Tester version. Add it to a EURUSD chart and use a 1-minute timeframe for the reference run. The rolling window is 30 bars, not 30 ticks. Use the Strategy Tester date controls for Jan–Jun 2026 development and Jul–Sep 2026 out-of-sample, and freeze inputs before the out-of-sample run.

The strategy starts with EUR 10,000 and calculates quantity from 0.10% equity risk, the tick-rounded stop distance, and the chart's point value/account-currency conversion. It rounds quantity down to the configured feed-unit step and rejects sizes below the configured minimum. Verify the feed's quantity units and point value first. The 1.0% daily loss limit compares strategy equity, including its open position P&L, with equity at the previous evaluated bar close when the selected timezone date changes; it blocks entries for the remainder of that day and closes an open strategy position by default. This includes losses on the first evaluated bar of the new day. With gaps or bars spanning midnight, the entire change since the previous evaluated close is attributed to the new day; exact midnight equity is unavailable. This is strategy-level simulated equity, not the cTrader bot's account-wide circuit breaker. Deposits, withdrawals, and external positions are not modeled. Set broker commission and slippage in **Strategy Properties**; their defaults in the script are zero. The assumed-spread input only gates signals and does not alter simulated fills. Repeat runs with wider assumed spread, commission, and slippage.

Protective orders use distances in ticks relative to the actual simulated entry fill. The plotted levels are calculated from the simulated position's average entry price while it is open. Stop and target distances are rounded to the nearest tick, with a minimum of one tick. Sizing uses that rounded stop distance. Gaps and slippage at the stop can still cause losses beyond the estimated risk. The 60-second time exit and daily-loss close are evaluated only at bar close and fill on the next available tick, so a 1-minute chart can exceed those thresholds. Strategy Tester intrabar OHLC assumptions, available Bar Magnifier data, spread, and feed contract specifications affect results. The strategy blocks entries on nonstandard charts such as Heikin Ashi; use standard candles. It does not simulate partial fills, broker rejections, account-wide risk, or timer-driven exit precision. Its daily-loss calculation can differ from cTrader when trades span UTC boundaries or the account has external cash flows/positions.

For comparing the indicator with the proxy, choose Bar-close proxy in the indicator and match the timeframe and common inputs. Both use the bar close time for session and day boundaries. Their markers need not match: the indicator counts signals, whereas the strategy also applies position, sizing and daily equity controls.

When a sample exceeds the configured jump threshold, both scripts discard it and clear their sample buffer. They resume after building a new window from subsequent samples. Signal markers on the strategy indicate submitted entry orders; inspect Strategy Tester for fills.

No TradingView chart/Strategy Tester connection was available in this workspace, so neither Pine script was compiled in TradingView and no strategy report or performance result is claimed. Use the procedure in `Docs/BACKTEST.md` and save the Tester report and cost settings for each run.

## Version 2.2 audit changes

EURUSD pip sizing now uses 0.0001 even when the feed identifies it as a CFD. Other non-FX instruments default to one minimum price tick unless overridden. Both scripts require standard charts and valid timestamps.

The realtime indicator resets its sample window after a configurable gap (120 seconds by default). Proxy samples in both scripts reset after a gap exceeding three chart periods. The next accepted sample seeds a fresh window; cooldown and daily counters are preserved. This prevents stale prices from before an interruption/session gap contributing to a new momentum signal.

Detailed alerts include the actual feed identifier, sampling mode and signal timestamp in the selected timezone. Dashboard status reports cooldown and daily signal limits. The strategy calculates momentum only when it actually accepts a sample. See `Docs/AUDIT_TRADINGVIEW.md` for findings and validation limits.
