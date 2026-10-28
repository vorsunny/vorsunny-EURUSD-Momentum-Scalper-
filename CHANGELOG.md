# Changelog

## cTrader port — 2026-10-28

- Added a C# cBot and chart indicator based on the rolling-tick momentum strategy.
- Added cTrader install, backtest, risk-scope, persistence, and validation notes.

## TradingView companion 2.0 — 2026-10-28

- Paired the Pine indicator and Strategy Tester scripts with the cTrader port's shared default parameters.
- Clarified that Pine uses chart-close samples and bar-based historical testing, while the cTrader cBot uses tick midpoint samples.

## TradingView companion 2.1

- Added detailed realtime alert messages so signal events can be reviewed in TradingView's Alerts Log after the chart is closed or reloaded.

## TradingView improvements

- Recover from large price jumps by clearing and rebuilding the sample window.
- Anchor simulated brackets to entry fills, size against the tick-rounded stop, and show markers only for submitted entries.
- Clarify the daily equity baseline and execution assumptions.

## TradingView 1.1 — 2026-10-27

- Corrected auto pip sizing for FX feeds with fractional quote precision.
- Added configurable strategy-level daily equity-loss lockout and status panel to the Strategy Tester proxy.
- Expanded TradingView documentation to clarify daily equity scope and bar-close execution limits.

## 1.0.0 — 2026-10-27

- Initial modular EURUSD tick-momentum EA.
- Added fixed circular signal buffer, configurable market filters, independent position sizing, account-wide daily loss circuit breaker, bounded native execution flow, timed exits, CSV diagnostics, and demo-only gate.
- Added installation, risk, strategy, backtest, and validation documentation.

## TradingView companion 2.2 — 2026-10-28

- Audited the Pine scripts and fixed EURUSD CFD pip sizing, stale sample windows, synthetic-chart parity and first-bar daily equity accounting.
- Rounded stop distances consistently with risk sizing, gated momentum on accepted samples, and improved alert identity/time and dashboard diagnostics.
- Recorded findings and native-validation limits in `Docs/AUDIT_TRADINGVIEW.md`.
