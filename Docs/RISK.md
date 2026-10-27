# Risk controls and accounting

## Per-entry risk

Volume is based on current equity and configured risk percentage. `OrderCalcProfit` estimates one-lot loss from entry to the configured stop using broker symbol/account-currency conversion; the maximum volume supported by the risk budget is divided by that loss, then rounded down to the broker volume step. If the result is below minimum volume, the trade is rejected. The EA never raises volume to satisfy minimum lot size. It uses broker volume minimum, maximum, and step values.

Before sending, it checks free margin with `OrderCalcMargin` and `OrderCheck`. It rejects a configured stop or target that is closer than the greater of the broker stop and freeze levels (plus one point). It does not widen the stop to satisfy a broker. Commission, slippage, gaps, conversion changes, and execution price differences can make realized risk exceed the estimate.

## Daily circuit breaker

Daily risk is **account-wide**: realized P&L from all account buy/sell deals for the current broker-server day (profit, swap, commission and deal fees), plus recognized separate commission, charge, and interest deal types, plus the current floating profit and swap of all open account positions. The daily money threshold is the persisted account equity observed at the broker-day start multiplied by the configured percentage. Deposits and withdrawals are excluded from the trade-P&L sum, so they do not directly masquerade as trading profit/loss or change the day's threshold. The equity baseline is reset at the next broker-server midnight. A restart on the same broker day restores the baseline and lock state from terminal Global Variables, keyed by account login, magic, and symbol. History is re-read to reconstruct realized daily P&L and trade count.

The account-wide P&L includes other EAs and manual trading by design. The trade-count limit applies only to this EA's symbol and magic. Floating P&L on positions opened before midnight is counted in full while the position remains open; this is conservative and can attribute pre-day unrealized movement to the new day. Set the daily loss percentage to zero only to disable the circuit breaker. A loss lock persists until the next broker-day boundary. With `InpClosePositionsOnDailyLoss=true`, this EA attempts to close only positions with its symbol and magic. It never closes manual or unrelated EA positions.

Terminal Global Variables persist across EA restarts and are flushed when risk/cooldown state changes, but can be deleted by the user or terminal cleanup. Initialization rejects incomplete same-day risk state. A cooldown timestamp is persisted before an order request; a rejected order can therefore leave a conservative cooldown in place. If state is missing on the same broker day, the EA starts a fresh baseline; inspect account history and logs before resuming after manual deletion. Time source and day boundary are broker server time, not local workstation time.

## Position isolation and account modes

Maximum simultaneous positions defaults to one and can be configured up to ten. On hedging accounts, position scanning and closing require matching symbol and magic. Increasing the cap can multiply aggregate stop risk by the number of open positions; per-trade risk is not reduced to compensate. On netting accounts, any pre-existing position on the symbol blocks a new entry, because a market deal would merge with or reduce that exposure, so this configuration remains effectively one position. The EA closes only a position whose current symbol and magic match; verify broker/account behavior before demo use.

Every entry request includes stop-loss and take-profit. Maximum holding time is enforced by a one-second timer as well as incoming ticks. Break-even and trailing stop options are disabled by default. Emergency close is configurable through the daily-loss close option.

## Important residual risks

Stops can slip or gap; spread/commission may exceed modeled limits; a terminal/VPS disconnect can prevent timer exits; broker rejection can prevent opening or closing; a forced market close can realize a worse result than the configured stop. The demo-only check blocks non-demo accounts by default, but terminal/broker classification and tester behavior must be confirmed in MetaEditor/MT5 before deployment. Keep it demo-only until validation is complete.
