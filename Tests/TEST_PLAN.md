# Validation checklist

## Automated checks included

- `python3 Tests/static_checks.py` checks expected artifacts, default safety inputs, key risk/execution API calls, placeholder markers, and balanced braces. This is a repository sanity check, not an MQL compiler.
- Compile `Tests/UnitTests.mq5` as an MT5 Script and run it in a demo terminal. It checks pip conversion at 2/3/4/5 digit precision, volume step rounding and minimum-volume rejection, rolling-window momentum, signal latching, and direction change.

## Required MetaEditor/Strategy Tester checks

| Area | Procedure | Expected result |
| --- | --- | --- |
| Compilation | Compile EA and unit script on target terminal build | No errors; investigate every warning |
| Invalid quotes | Feed/no quote or test with invalid symbol data | No entry; diagnostic rejection |
| Stale quotes | Disconnect feed or use stale-tick fixture | Entry gate rejects stale quote; timer still manages an existing position when prices return |
| Spread | Set max spread below observed spread | No entry while above limit |
| Tick activity | Set high minimum tick rate in quiet period | No entry until rate qualifies |
| Volatility/jump | Simulate/locate high-range period and abnormal tick | Signal rejected by the relevant filter |
| Session | Enable a narrow server-time session and test inside/outside/overnight | Only configured broker-time interval allows entry |
| Volume sizing | Test risk that maps below min lot, on a step boundary, and above max | Reject below min; round down; cap at max; calculated risk never exceeds budget |
| Daily limits | Create realized loss and open floating loss in Tester | Both contribute; new entry locks at threshold |
| Daily reset | Test across broker midnight and restart EA | Day state resets once; same-day lock/baseline survive restart |
| Deposits/withdrawals | Add balance operations in a controlled account history | Cash deal is excluded from trading P&L sum; next-day baseline uses current equity |
| Cooldown/duplicate | Sustained threshold momentum; close/restart inside cooldown | No duplicate while position/order pending or cooldown active |
| Position cap | Attempt multiple entry signals | No more than configured cap; default is one |
| Restart recovery | Restart with a same-day lock/cooldown and inspect Global Variables/history | Lock and cooldown state restored; history recomputes daily entries/P&L |
| Broker rejection | Use invalid stop distance or unsupported conditions | Reject before submission or log server retcode; no stop removal workaround |
| Partial fills | Use broker/tester conditions that produce partial execution | Log partial result and transaction; do not issue duplicate entry |
| Requote/price change | Use execution-delay/slippage test if available | Bounded retries only for recoverable retcodes |
| Margin | Reduce free margin in demo/tester | OrderCalcMargin/OrderCheck prevents entry |
| Netting | Existing unrelated position on EURUSD | New entry rejected; unrelated position untouched |
| Hedging | Existing other-magic position and then EA position | EA only tracks/closes its own symbol+magic position |
| Timer exits | Open EA position and suppress ticks or test time passage | Time exit/optional daily-loss close runs from timer when tradeable quotes return |
| Filling policies | Test broker symbols with IOC/FOK/RETURN support | Chosen policy accepted or explicit server rejection is logged |
| Demo gate | Try non-demo login with default input | Initialization fails before any order request |

Some scenarios require a scripted fixture, a broker demo, or tester support for injected responses. Do not mark them passed merely from source inspection.

## Results for this workspace

- Python static checks: run and report in the task summary.
- MQL unit script: authored but not run; no MetaEditor/MT5 was available.
- Native compilation, Strategy Tester, broker rejection, partial fills, and hedging/netting execution: unverified.


## TradingView strategy proxy status

- Pine v6 indicator and strategy sources pass static repository checks for expected declarations, chart alerts/strategy order calls, absence of strategy orders in the indicator, and balanced braces.
- The TradingView Pine Editor and Strategy Tester were not available in this environment. Neither Pine script has been compiled or run there; no performance metrics are reported.
- In TradingView, run the strategy on EURUSD 1-minute bars for Jan–Jun 2026, freeze parameters, then run Jul–Sep 2026 out-of-sample. Confirm symbol point value and quantity units, and set actual commission/slippage in Strategy Properties before interpreting results.
