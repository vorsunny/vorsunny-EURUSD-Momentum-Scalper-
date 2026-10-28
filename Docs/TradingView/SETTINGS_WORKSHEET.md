# TradingView run settings worksheet

Copy this worksheet for **every** run. Fields marked unknown block performance interpretation; do not fill them with invented broker terms.

## Identity and reproducibility

| Field | Recorded value |
| --- | --- |
| Run ID / operator / date | Unrecorded |
| Script version, Git commit, downloaded file SHA256 | Unrecorded |
| Indicator mode or BAR PROXY | Unrecorded |
| Broker and exact TradingView feed ID | Unrecorded; previous screenshots used Capital.com EURUSD, not verified for this run |
| Standard chart / timeframe / available data coverage | Unrecorded; reference: 1-minute standard candles |
| Account currency / initial balance | Reference: EUR / 10,000 |
| Chart minimum tick / pip size / point value | Unknown; verify feed specification |
| Quantity units / step / minimum / maximum | Unknown; defaults 1,000 step/min, 1,000,000 max are assumptions |
| Session timezone / start / end / enabled | Reference: Etc/UTC / 00:00 / 23:59 / disabled |
| All strategy inputs / Properties screenshot / Bar Magnifier state | Unrecorded |
| Inputs freeze date and SHA of saved settings record | Unrecorded |

## Period and exposure ledger

| Run purpose | Entry window in UTC | Freeze and prior exposure |
| --- | --- | --- |
| Development baseline | 2026-01-01 inclusive to 2026-07-01 exclusive | Record every prior run, inspection, optimization or manual chart review; currently unknown |
| Held-out evaluation | 2026-07-01 inclusive to 2026-10-01 exclusive | Use only after freeze; prior exposure currently unknown, so NOT established as untouched |

Record actual data coverage. If settings or selection decisions were influenced by July–September, label it a retrospective evaluation and choose a later genuinely untouched period for a new prospective test. No performance runs have been completed by this workspace.

## Costs (required)

| Field | Baseline | Stress A | Stress B |
| --- | --- | --- | --- |
| Commission type, value, currency, broker source/date | Unknown | Baseline x1.5 | Baseline x2 |
| Full roundtrip spread estimate (pips), source/date | Unknown | Baseline x1.5 | Baseline x2 |
| Additional adverse execution slippage per leg (pips) | Unknown | Baseline x1.5 | Baseline x2 |
| Strategy Properties slippage in ticks | Unrecorded | Unrecorded | Unrecorded |
| Modeled execution delay / unsupported | Unrecorded | Unrecorded | Unrecorded |

For a fixed spread approximation on a time-based chart, allocate half the full spread to each leg and combine it with adverse slippage; convert price distance to whole ticks using `ceil((spreadPips / 2 + extraSlippagePips) * pipSize / minimumTick)`. Record this approximation and avoid double counting spread already embedded in another cost setting. Pine applies slippage according to broker-emulator order rules (not identically to every order type), so this is not an exact bid/ask model. Commission type and units must match the selected feed. Keep input spread gates identical when measuring the cost sensitivity alone.

## Outputs and evidence

Record net profit after modeled costs, profit factor, expectancy per trade, maximum equity drawdown, win rate, average win/loss, trade frequency, average hold, consecutive losses and trade count. Include full Tester exports/screenshots, actual settings, log exports, missing-data notes and limitations. If zero trades occur, record that outcome rather than retuning on the held-out period.

Live event reconciliation record: alert name/settings, chart runtime and alert runtime start times, active-session dates, signal counts, feed/direction/time/price pairs, mismatches and explanations. Native validation needs at least three active sessions, ten signal events and zero unexplained mismatches.
