# Changelog

## cTrader port — 2026-10-28

- Added a C# cBot and chart indicator based on the rolling-tick momentum strategy.
- Added cTrader install, backtest, risk-scope, persistence, and validation notes.

## TradingView companion 2.0 — 2026-10-28

- Paired the Pine indicator and Strategy Tester scripts with the cTrader port's shared default parameters.
- Clarified that Pine uses chart-close samples and bar-based historical testing, while the cTrader cBot uses tick midpoint samples.

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
