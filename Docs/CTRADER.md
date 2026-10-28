# cTrader port

The cTrader implementation is a native C# cBot plus a chart indicator:

- `cTrader/cBots/EURUSD_Momentum_Scalper_cBot.cs` samples live bid/ask midpoint updates, sizes orders from equity risk, and manages entries/exits. Use this cBot for cTrader backtests and demo runs.
- `cTrader/Indicators/EURUSD_Momentum_Scalper_Indicator.cs` shows realtime signals and indicative stop/target levels. It does not place trades.

## Import and compile

1. Open cTrader Desktop and go to **Algo**.
2. Create a new cBot named `EURUSDMomentumScalper`, replace the starter code with the entire cBot `.cs` file, then build it.
3. Create a new indicator named `EURUSDMomentumScalperIndicator`, replace its starter code with the entire indicator `.cs` file, then build it.
4. Attach the indicator to the broker's EURUSD chart. Its circular buffer starts empty and warms from live ticks.
5. For the cBot, start with a demo account and `Demo account only = true`. Review the parameters, broker symbol volume units, and label before starting it.

cTrader uses `Symbol.PipSize` and broker symbol volume limits. The cBot sizes with cTrader's proportional equity risk helper rounded down, rejects a size below broker minimum, checks estimated margin, and uses a market range order with bounded entry slippage. cTrader documents its proportional risk estimate as approximate because market movement can exceed the stop distance. A stop can also slip in a gap.

## Backtest

1. Open the cBot in cTrader Algo and choose **Backtesting**.
2. Select the broker's EURUSD symbol, a period long enough to include the chosen test dates, and tick data where the broker provides it. cBot `OnTick` runs for each replayed tick.
3. Start with the default settings: 30 samples, 1.5-pip threshold, 5-pip stop, 7.5-pip target, 0.10% equity risk, 1.0-pip spread ceiling, 60-second maximum holding, and 1.0% daily equity loss.
4. Set realistic commission and spread assumptions using cTrader/broker backtest settings. The in-code spread filter checks the replayed spread; it does not add commission.
5. Record net profit, profit factor, expectancy, equity drawdown, win rate, average win/loss, trades per day, hold time, consecutive losses, and the selected data/cost settings. Preserve a later untouched period for out-of-sample evaluation.

The cBot uses UTC session and daily boundaries. The daily loss baseline is account equity at the first cBot start or first tick of each UTC day, whichever initializes the state. It includes open and closed account P&L, including other positions; deposits and withdrawals during the day can distort the percentage. The baseline, entry count and lockout are saved in cTrader instance local storage and flushed after updates. cTrader Cloud local storage is not persistent between runs according to cTrader documentation, so a Cloud restart can reset this state; use Desktop for restart-persistent daily risk unless this has been validated for the chosen deployment. Run only one cBot instance for this strategy on the account: the daily entry counter is instance scoped, so multiple instances would each have their own trade cap and baseline.

The cBot blocks entry if another labeled/manual position exists on the same symbol to reduce interference with netting-style exposure. It manages only positions with its exact label and chart symbol. Do not reuse the label across separate cBot instances. The indicator displays signals on the chart and writes signal details to the cTrader log; it does not place orders or send push alerts. A market-range order bounds entry price movement; the broker can still reject it. The cBot does not run an automatic retry loop.

## Validation status and limitations

The source uses documented cTrader Algo API members for tick callbacks, market-range orders, risk-based volume sizing, estimated margin and local storage. This workspace has no .NET SDK or cTrader compiler, so the C# has not been compiled or run here. A cTrader desktop build and broker demo/backtest are required before relying on it. No profitability result is claimed.

This port is based on the TradingView momentum rule, but the cTrader bot samples true bid/ask midpoints on ticks. The TradingView Strategy Tester remains a bar-close approximation, so results across platforms will differ. Historical tick coverage, spread, commission, slippage, account type, broker stop rules, and cTrader version can affect behavior.

API references: [market-range orders](https://help.ctrader.com/ctrader-algo/references/General/Robot/ExecuteMarketRangeOrder/), [proportional risk volume](https://help.ctrader.com/ctrader-algo/references/MarketData/Symbols/Symbol/VolumeForProportionalRisk/), [estimated margin](https://help.ctrader.com/ctrader-algo/references/MarketData/Symbols/Symbol/GetEstimatedMargin/), and [local storage](https://help.ctrader.com/ctrader-algo/guides/local-storage/).
