# EURUSD Momentum Scalper

Native MQL5 tick-momentum Expert Advisor for controlled MetaTrader 5 demo validation. Version 1.0.

The MT5 EA and cTrader port use a fixed rolling tick window, configurable market filters, risk-based volume sizing, a daily loss circuit breaker, and timed exits. Demo-account-only protection is enabled by default in the automated bots. No profitability claim is made; compile, test, and validate against your broker before any use.

## Project files

- [Installation and usage](Docs/README.md)
- [Strategy specification](Docs/STRATEGY.md)
- [Risk controls and accounting](Docs/RISK.md)
- [Strategy Tester procedure](Docs/BACKTEST.md)
- [Test plan and validation status](Tests/TEST_PLAN.md)
- [TradingView indicator](TradingView/EURUSD_Momentum_Scalper_Indicator.pine)
- [TradingView backtest strategy](TradingView/EURUSD_Momentum_Scalper_Backtest.pine)
- [TradingView setup and limitations](Docs/TRADINGVIEW.md)
- [cTrader C# cBot and indicator](Docs/CTRADER.md)
- [EA source](Experts/EURUSD_Momentum_Scalper.mq5)
- [Default settings](Config/EURUSD_Default.set)

The source was not compiled or backtested in the original build environment because MetaEditor and MT5 were unavailable. See the test plan for verified checks and remaining terminal-dependent validation.
