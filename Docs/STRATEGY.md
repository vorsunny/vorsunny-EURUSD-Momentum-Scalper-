# Strategy specification

## Signal

On each valid EURUSD quote, the EA computes the mid-price `(bid + ask) / 2` and stores it in a fixed 512-slot circular array. Once at least N samples exist, momentum in pips is:

`(current_mid - oldest_mid_of_latest_N_samples) / pip_size`

A positive value at or above the configured threshold creates a buy signal; a negative value at or below the negative threshold creates a sell signal. Five- and three-digit FX quotes use 10 points per pip; four- and two-digit quotes use one point per pip. The default is 30 ticks and 1.5 pips.

The signal latch suppresses repeated signals in the same momentum episode when a signal is emitted, even if a later risk or broker check rejects it. It clears when absolute momentum falls below half the entry threshold. A valid tick excluded by a spread, quote, session, or jump filter does not trigger an order.

## Filters

- Maximum spread: default 1 pip; zero disables the spread ceiling.
- Minimum activity: default 10 accepted ticks in the last 60 seconds.
- Short-term range: reject when the latest N mid-price range exceeds 8 pips; zero disables it.
- Single-tick jump: reject the quote when its mid-price differs from the preceding accepted quote by more than 5 pips; zero disables it.
- Stale/future quote: default maximum age 3 seconds, with a 2-second future-time tolerance.
- Session: disabled by default. When enabled, start/end use broker server time; an overnight range is supported. Equal start/end means all day.
- Trading permissions and symbol mode: checked immediately before submission.

There are no indicator dependencies. A fixed buffer and bounded scans keep per-tick work small; event processing and broker response latency still prevent deterministic microsecond execution.

## Defaults

30-tick window, 1.5-pip threshold, 5-pip stop, 7.5-pip target, 60-second maximum hold, 1-pip spread ceiling, 30-second entry cooldown, 0.10% risk, 1% daily loss cap, one EA position, and 30 entries per broker day. These are starting parameters for testing, not optimized or validated settings.
