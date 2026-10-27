# EURUSD Momentum Scalper

Native MQL5 tick-momentum Expert Advisor for controlled MetaTrader 5 demo validation. Version 1.0.

The EA uses a fixed rolling tick window, configurable market filters, independent risk sizing, a daily loss circuit breaker, bounded trade submission, and timer-driven position exits. Demo-account-only protection is enabled by default. No profitability claim is made; compile, test, and validate against your broker before any use.

## Project files

- [Installation and usage](Docs/README.md)
- [Strategy specification](Docs/STRATEGY.md)
- [Risk controls and accounting](Docs/RISK.md)
- [Strategy Tester procedure](Docs/BACKTEST.md)
- [Test plan and validation status](Tests/TEST_PLAN.md)
- [EA source](Experts/EURUSD_Momentum_Scalper.mq5)
- [Default settings](Config/EURUSD_Default.set)

The source was not compiled or backtested in the original build environment because MetaEditor and MT5 were unavailable. See the test plan for verified checks and remaining terminal-dependent validation.
