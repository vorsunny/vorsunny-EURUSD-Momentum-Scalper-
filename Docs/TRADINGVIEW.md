# TradingView release candidate 3.0.0-rc.1

Start with the [quick-start guide](TradingView/QUICK_START.md). The two scripts are standalone Pine v6 sources: a realtime chart indicator and a separate Strategy Tester **BAR PROXY**. The release is native-validation-pending, not production-validated and not evidence of profitability.

- [Settings and exposure worksheet](TradingView/SETTINGS_WORKSHEET.md)
- [Native/live validation checklist](TradingView/VALIDATION.md)
- [Validation results](TradingView/validation_results.json)
- [Parallel platform comparison](TradingView/PLATFORM_COMPARISON.md)
- [Release notes and known limitations](TradingView/RELEASE_NOTES.md)

## Indicator behavior

Realtime updates is the default: the newest chart close is sampled on each live chart execution. The circular buffer contains up to 512 accepted updates; momentum compares newest against oldest of the configured N samples (N-1 intervals). Standard time-based candles and valid prices/timestamps are required. EURUSD uses a 0.0001 pip, including CFD feeds with EUR/USD metadata; other FX quote conventions and an override are supported.

Signals require +/-1.5 pip momentum by default, at least 10 accepted updates in the last minute, a window range no greater than 8 pips, a single-update jump no greater than 5 pips, and the configured session/spread gates. Spread is an assumption, not a measured bid/ask stream. A jumping sample is discarded; the next sample starts rewarming. Live gaps over 120 seconds reset/reseed the window; proxy gaps over three chart periods do the same. Cooldown and daily counts survive these resets while the script remains running.

The threshold episode latch prevents repeated events during one sustained move. Momentum strictly below half the threshold rearms it, or an opposite threshold can create a reversal episode. A blocked episode is consumed even if cooldown/daily limits or strategy execution gates reject it. Cooldown defaults to 30 seconds and the indicator cap to 30 signals per selected-timezone day. The dashboard computes their state after the latest event, displays warmup and latest signal/ID, and updates only when chart executions occur.

BUY/SELL markers persist during the live chart session, with indicative reference levels from the latest signal. Multiple events may share one bar's markers; the alert stream is the event record. Pine cannot restore exact intrabar signals after a restart because the historic update sequence is not available in this script.

## Alerts

Create one indicator alert using **Any alert() function call** for detailed MS3 messages, then enable the desired notifications and check expiration. Alert calls do not create the user alert automatically. Separate BUY/SELL conditions remain alternatives. Avoid duplicate alerts. TradingView may throttle excessive rates; keep default cooldown for initial validation and check status.

MS3 messages include feed, mode, timestamp, timezone, direction, momentum, sample count, signal price, reference stop/target, spread assumption and a per-runtime ID. The ID combines feed, runtime start, signal timestamp and session event counter. Server alerts run a saved independent script/settings snapshot; their warmup/IDs can differ from chart copies. Reconcile event observations by feed/direction/time/price as well as run-specific IDs. Changing code/inputs requires recreating alerts. Logs have platform/plan retention limits: export them for durable research records.

References: [TradingView alert snapshots](https://www.tradingview.com/pine-script-docs/faq/alerts/), [alert frequency behavior](https://www.tradingview.com/pine-script-docs/concepts/alerts/).

## Strategy Tester proxy

The strategy samples one confirmed bar close per sample; 30 samples on the reference 1-minute chart mean 30 bars. Activity cannot be reconstructed from those bars and is omitted. Both scripts embed the same mathematical helpers; this does not make a bar proxy tick-equivalent. Use Bar-close proxy in the indicator for comparisons of common rules, allowing for the strategy's extra position/risk gates and different signal-versus-entry counts.

Sizing is 0.10% strategy-equity risk by default. Stops/targets are rounded to nearest tick (minimum one tick), sizing uses the rounded stop and feed point-value/account conversion, and quantity is rounded down to the configured step/cap. Sizes below minimum or with unavailable conversions are rejected. Feed units must be verified. Commission is not part of nominal stop-risk sizing; gaps/costs can exceed the estimated budget.

The 1% daily loss lock compares strategy equity with the previous evaluated close at the selected-timezone date change. It includes realized/unrealized strategy P&L and locks for the rest of that date, optionally closing the position. Midnight-spanning bars/gaps cannot be valued exactly at midnight; the whole change belongs to the new evaluated date. The 60-second holding limit is checked at bar close. Exit requests are independent of entry readiness/session/spread, and fills occur on subsequent available ticks; all thresholds can overshoot.

The optional UTC entry-date filter supports reproducible periods while warming the window from pre-period data. Configure Jan–Jun 2026 development, freeze settings, then Jul–Sep evaluation only if previous exposure is recorded. No period is claimed untouched by default.

The dashboard always reminds you to configure commission and slippage/spread costs in Strategy Properties. The assumed spread input is ONLY an entry gate and never deducts fill costs. Initial Properties defaults are zero; no net-performance conclusion is valid from those settings alone. The strategy does not simulate partial fills, broker rejections, account-wide risk, real quote spread or cTrader's native timer.

## Development and validation

`Tools/build_tradingview.py` synchronizes shared helpers into each standalone file and the native Pine self-test. CI checks sync, repository contracts and Python tooling. It does not compile or execute Pine. Native editor builds, strategy-control checks, real cost settings and at least three active live sessions/ten events with no unexplained mismatch are required before a stable release. Current evidence is tracked in the validation JSON. The earlier v2.2 audit remains an archived historical review.
