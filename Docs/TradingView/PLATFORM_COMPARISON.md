# Parallel platform behavior

| Behavior | TradingView realtime indicator | TradingView BAR PROXY strategy | cTrader port |
| --- | --- | --- | --- |
| Price/window | Latest chart close per live chart update, N=30 | Confirmed chart closes, N=30 bars | Bid/ask midpoint per tick, N=30 |
| Momentum / rearm | +/-1.5 pips; rearm strictly below half; reverse episodes allowed | Same rule | Same shared default rule, separate C# implementation |
| SL / TP | Indicative 5 / 7.5 pip levels | Simulated fill-relative 5 / 7.5 pips, tick rounded | Broker orders 5 / 7.5 pips |
| Spread | Assumed 1-pip gate | Assumed 1-pip gate, costs configured separately | Actual quote spread gate 1 pip |
| Activity | Min 10 accepted updates in last minute | Omitted; bars cannot represent tick rate | Min 10 ticks/minute |
| Cooldown / cap | 30 seconds / 30 signals per day | 30 seconds / 30 submitted entries per day | 30 seconds / 30 filled entries per day |
| Session | Disabled by default; configurable timezone, defaults UTC | Same | Disabled by default; UTC |
| Range / jump | 8 / 5 pips | 8 / 5 pips per bar window/jump | 8 / 5 pips per tick window/jump |
| Long gap reset | 120 seconds live, configurable | Over 3 chart periods | Jump reset only; explicit stale-window parity needs future C# work |
| Daily equity | No account equity access | 1% strategy-equity lock, previous evaluated close baseline | 1% account-equity lock; first-start/day snapshot; local storage |
| Holding exit | No broker exit | 60 seconds evaluated at bar close | 60 seconds with native timer |
| Sizing | None | 0.10% risk; feed quantities configured by user | 0.10% risk; broker symbol volume limits |
| Restart history | Pine chart buffer restarts; use Alerts Log exports | Recomputed from loaded historical bars | Desktop local storage; cloud persistence limited |
| Validation | Current candidate native/live checks pending | Native compilation and reports pending | C# compilation and broker execution pending |

This release does not claim identical fills, signals or results across platforms. cTrader remains the next validation milestone, including risk persistence, stale-window behavior, broker stop rules and account modes. MT5 work is deferred.
