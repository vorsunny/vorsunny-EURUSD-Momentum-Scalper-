# TradingView validation and acceptance

Current status is machine-readable in `validation_results.json`. Repository tests, native helper tests, Strategy Tester behavior and live alert validation are separate categories. The current candidate has no native compiler, Tester report or live-session evidence collected by this workspace.

## Repository checks

Run with Python 3.11+ from the repo root:

```sh
python3 Tools/build_tradingview.py --check
python3 Tests/static_checks.py
python3 -m unittest discover -s Tests -p 'test_*.py' -v
python3 Tools/package_tradingview.py
```

Shared Pine helpers are maintained in `TradingView/Shared/MomentumCore.pineinc`. Run `python3 Tools/build_tradingview.py` after changing them. Each shipped script remains standalone: no TradingView library publishing or external service is required. CI checks that all copies match. Python tests check packaging, release gating and synthetic exported-log cases; they do not execute Pine.

## Native checklist

For each row record exact source SHA, test settings, date, result and evidence paths. Anything not run stays pending.

| Check | Procedure / expected behavior |
| --- | --- |
| Build | Compile indicator, strategy and self-test in Pine Editor. Resolve errors and review warnings. Keep compiler evidence. |
| Actual shared helper tests | Add the standalone native self-test. Assertions cover EURUSD/JPY pip conversion, session boundaries, circular wraparound, warmup, jump recovery, gap reset, rate expiry, clock reversal, threshold episodes, rearming, reversal, cooldown boundaries, sizing and daily locks. A green table means helper assertions passed only. |
| Warmup and reset | On live mode observe 0/N through N/N; no signal before N accepted updates. After a gap over 120 seconds rewarm. Jump resets discard the jumping sample. Daily counters and cooldown do not reset with the window. |
| Signal behavior | Sustained same-direction momentum produces no repeated episode. Below half threshold rearms; exact half does not. A reverse threshold can produce a new episode. Filter-blocked samples do not produce alerts. Episodes blocked by execution gates are consumed. |
| Same-update dashboard | On a signal the cooldown immediately displays its full configured seconds. A signal that hits the daily cap immediately displays the cap reason. With cooldown=0 the counter still updates immediately. |
| Native strategy controls | In small-risk cases reject quantity below minimum; round down to step/cap. Check stop risk and active levels against entry fills. Exercise daily first-bar loss, recovery while locked, next-day reset and time exits. Use controlled settings/data; preserve evidence for cases not observed. |
| Session/day/timezone | Test daytime, overnight, equal bounds and exclusive end. Compare mode-specific timestamp to the selected timezone. Check bars spanning midnight and weekend gaps; previous-close equity change is allocated to the new evaluated date. |
| Date filter and exits | Confirm inclusive start/exclusive end for submissions, pre-window warmup, invalid date rejection and close request at/after end. Check exits still operate while entry session/spread filters block. Actual fills may extend beyond the window. |
| Chart restrictions | Heikin Ashi/Renko/tick charts block entries/signals; standard time-based candles work. |
| Live logs versus chart | Across at least three active market sessions and ten signal events, record each feed/direction/time/price pair. Chart and server runtimes have separate IDs and warmup; explain mismatches rather than pretending IDs must be equal. Verify default cooldown and daily cap. |
| Reload and closed browser | Create a server alert, reload chart (chart rewarms), close browser, observe independently recorded server events, reopen and export log. Check alert remains active and has not expired or hit platform throttling. |
| Cost reproducibility | Complete the settings worksheet with measured/broker-sourced cost assumptions. Zero-default-cost results cannot count as performance evidence. |

## Log checking

Export TradingView's Alerts Log as CSV. Keep the original private (it can contain account-specific alert names), then run:

```sh
python3 Tools/check_alert_log.py /path/to/export.csv --cooldown 30 --daily-cap 30
```

The default message column is `Message`; use `--message-column` if the export names it differently. Use the cooldown and cap of that saved alert. The checker validates MS3 field types, IDs, direction/levels, time/timezone, repeated IDs, missing/out-of-order event counters, cooldown and daily caps within each runtime. Unrelated messages are counted and ignored. A filtered export with omitted MS3 events can report counter gaps; inspect the complete export. Separate runtime IDs must not be combined as one sequence. Matching format and counts do not prove chart reconciliation, native compilation, all market ticks being received, or three full active sessions. Those require separate evidence.

## Release gate

All six gates in the validation JSON require a passed status and evidence before stable signoff. The live gate also requires at least three active sessions, ten events and no unexplained mismatches. `python3 Tools/package_tradingview.py --check-stable` fails while any gate is pending. GitHub CI applies that guard to stable TradingView tags.

The current published artifact must be a **prerelease**, visibly marked native-validation-pending. After evidence is collected, update the results, review source changes against that evidence, choose a stable version, and rerun checks before stable publication. No profitability signoff follows from software acceptance alone.
