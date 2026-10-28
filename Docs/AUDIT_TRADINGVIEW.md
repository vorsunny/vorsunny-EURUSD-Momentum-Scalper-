# TradingView code audit — version 2.2

Scope: the Pine indicator and Strategy Tester proxy. This is a correctness and usability review; it does not establish profitability or validate cTrader/MT5 execution.

## Findings fixed

| Finding | Previous behavior | Correction |
| --- | --- | --- |
| EURUSD CFD pip conversion | A non-FX feed with a 0.000001 tick could infer a 0.00001 pip, producing a 10x momentum error. | EURUSD uses a 0.0001 pip regardless of FX/CFD classification, provided currency metadata identifies EUR/USD. Override remains available. |
| Stale rolling samples | Prices before a long quote/session gap could be compared with new quotes. | Reset live samples after the configured gap and proxy samples after three chart periods. Rewarm the window while preserving daily limits/cooldown. |
| Daily baseline | The strategy used the first new-day bar's ending equity as its baseline, excluding that bar's loss. | Use previous evaluated close equity (initial capital on the first loaded bar). |
| Indicator chart restrictions | Synthetic prices could generate indicator alerts even though the strategy blocked them. | Both scripts require standard charts. |
| Rejected-sample diagnostics | The proxy could display momentum against a close it had not accepted into its window. | Calculate momentum only on accepted samples. |
| Stop rounding | Floating-point division followed by floor could shorten an intended stop by one tick. | Round to nearest tick and size against that exact distance. |
| Alert attribution | Messages could say EURUSD even when the symbol restriction was disabled; mode/time were absent. | Include actual feed identifier, sampling mode and formatted timestamp. |
| Dashboard limits | Ready could appear while a cooldown or daily signal limit blocked new alerts. | Display these blocking reasons. |

## Validation performed

- Eight existing repository static checks passed after the source changes; whitespace/error checks passed.
- Manually reviewed circular indexing: a window of N samples compares the newest sample to sample N-1 intervals earlier; wraparound uses fixed capacity 512 and no per-update array resizing.
- Reviewed the gap-reset trace: a gap exceeding the limit clears count/index/latch; its incoming valid price becomes sample one, and no momentum is calculated before N new samples.
- Reviewed daily equity trace: previous close 10,000 and first new-day close 9,850 gives -1.5%, so a 1% breaker locks. Recovery later that day does not unlock it.
- Reviewed stop sizing: both risk per quantity unit and bracket orders use the same rounded tick count; quantity is rounded down and rejected below minimum.

Static checks are repository sanity checks, not a Pine compiler or a simulation. No native Pine compilation or Strategy Tester performance run occurred in this environment.

## Remaining platform/model limitations

- Exact live update history is unavailable after Pine restarts. The alert log is the record of server alert events; chart markers cannot be reconstructed from missing ticks. Alerts must be created by the user and recreated after script/input changes.
- Pine samples chart close on live updates, which is not guaranteed to be every broker tick or the bid/ask midpoint. Historical proxy samples are chart bar closes; the activity filter is omitted there.
- Assumed spread only gates signals. Commission/slippage defaults are zero and must be configured in Strategy Properties; no realistic net-profit claim can be made with those defaults.
- Daily equity is strategy-specific and checked at bar close. Day-boundary gaps and bars spanning midnight cannot be valued at exact midnight; the change from the previous close belongs to the newly evaluated date. Risk stops/time exits can overshoot.
- Simulated sizing depends on feed quantity units, point value and account-currency conversion. It does not include commission in the nominal stop-risk budget. Gaps, costs and slippage can exceed that budget.
- A threshold episode is consumed even when cooldown, position limits or a daily limit blocks entry; a new episode requires momentum to rearm or reverse. This is deliberate duplicate prevention.

## Required chart-side checks

Build both scripts in Pine Editor. On EURUSD standard candles, verify live warmup, gap reset, BUY/SELL pulses and alert timestamps. In the proxy, check session/day boundaries, first-bar losses and lock retention, minimum quantity rejection, and actual bracket levels against fill prices. Repeat with realistic costs before interpreting Strategy Tester results.
