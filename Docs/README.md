# EURUSD Momentum Scalper 1.0

A native MQL5, tick-driven demo EA for MetaTrader 5. The implementation separates signal generation, risk checks, execution, position management, and logging. It uses no DLLs, web APIs, external services, martingale, grid, or averaging-down logic.

This is a strategy implementation, not evidence of profitability. It is intended for controlled demo validation. Do not use its defaults as a claim that this strategy has positive expectancy.

## Project layout

- `Experts/EURUSD_Momentum_Scalper.mq5` — EA inputs and event flow.
- `Include/MomentumScalper/` — signal, risk, execution, position and logging modules.
- `Config/EURUSD_Default.set` — baseline input values.
- `Tests/UnitTests.mq5` — MT5 script for deterministic helper and signal checks.
- `Tests/static_checks.py` — repository checks that can run outside MT5.
- `Tests/TEST_PLAN.md` — broker/terminal test matrix.
- `Docs/STRATEGY.md`, `Docs/RISK.md`, `Docs/BACKTEST.md` — methodology and limitations.
- `cTrader/` and `Docs/CTRADER.md` — C# cBot/indicator port and cTrader install/backtest guide.

## Install and compile

1. In MT5, use **File → Open Data Folder**.
2. Copy `Experts/EURUSD_Momentum_Scalper.mq5` into `MQL5/Experts/`.
3. Copy the contents of `Include/MomentumScalper/` into `MQL5/Include/MomentumScalper/`.
4. Open the EA in MetaEditor and compile with the installed terminal's current compiler.
5. Optionally place `Config/EURUSD_Default.set` in `MQL5/Profiles/Tester/` or load it from the EA Inputs dialog.
6. Attach to EURUSD or a broker symbol beginning with `EURUSD`. Keep **Allow algorithmic trading** on, and start on a demo account. Demo-only protection is on by default.

The `.set` file is a baseline, not a broker-specific profile. Default maximum simultaneous positions is one; a configured cap up to ten is supported only where hedging behavior is safe, and raises aggregate risk. Confirm symbol digits, pip size, stop/freeze levels, volume steps, commission, and filling policy before any run.

## Run a strategy test

Open **View → Strategy Tester**, select the EA and the exact broker EURUSD symbol, and use **Every tick based on real ticks**. Set an initial balance of EUR 10,000 and EUR account currency when supported. Follow the windows and scenarios in `BACKTEST.md`. The EA's tester CSV is stored in the tester's file area and includes `TESTER` in its name/rows; terminal logs use `TERMINAL`.

## Diagnostic logs

`InpLoggingLevel` supports 0 (decisions/errors), 1 (operational), and 2 (filter diagnostics). CSV logging is on by default. CSVs are created under the terminal/tester Files directory and include time, environment, event, and details. A file-open failure does not stop trading; use the Experts and Journal tabs as a fallback.

## Status

Static checks and reference math checks are provided in the repository. This build environment had no MetaEditor or MT5 terminal, so native compilation, Strategy Tester runs, live broker execution, partial-fill behavior, and account-mode tests remain unverified. See `Tests/TEST_PLAN.md` before relying on the EA.
