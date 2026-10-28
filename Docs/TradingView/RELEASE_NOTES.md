# TradingView v3.0.0-rc.1 — native validation pending

A release candidate for controlled TradingView validation. It has not met stable acceptance, has not been compiled by this workspace in Pine Editor, and includes no performance results.

- Expanded live dashboard: warmup, momentum, blocking reason, immediate cooldown/cap state, latest signal time/price/reference levels and ID.
- Detailed MS3 alerts with feed/mode/timezone and per-runtime IDs; green/red live-session markers and labeled indicative SL/TP.
- Shared source helpers embedded in both standalone scripts and a native Pine self-test. Floating subtraction noise at exact pip boundaries is rounded to nine pip decimal places.
- BAR PROXY dashboard shows cost and holding-resolution limits, rounded stop risk and optional explicit UTC entry-date filtering.
- Added settings/exposure worksheet, validation checklist/results, platform comparison, log checker, packaging checks and GitHub CI.

## Upgrade

Replace the complete script in Pine Editor; do not append it to an existing declaration. Recheck all inputs. Recreate alerts with **Any alert() function call** after changes. MS3 is a new message format; older free-text exports are ignored by the new log checker. Historical proxy and realtime events remain different sample models. Signal IDs identify one runtime and may differ between server alert and chart copies.

## Known limits

Realtime tick history and chart markers cannot be restored after a Pine restart. TradingView retains alert logs according to its platform/plan limits; export for durable records. Assumed spread does not model fills; configure actual commission/slippage. Native and live gates are pending in the included validation JSON, so this artifact must remain a prerelease. No forecast of profitability is made.

## Download

The candidate bundle and SHA256 are versioned in the repository because this publishing environment cannot authenticate to GitHub release-attachment uploads. The release source archive also contains the standalone sources and guides.

- [Download candidate bundle](https://github.com/vorsunny/vorsunny-EURUSD-Momentum-Scalper-/raw/refs/tags/tradingview-v3.0.0-rc.1/Releases/TradingView/3.0.0-rc.1/tradingview-momentum-scalper-3.0.0-rc.1.zip)
- [Bundle SHA256](https://github.com/vorsunny/vorsunny-EURUSD-Momentum-Scalper-/raw/refs/tags/tradingview-v3.0.0-rc.1/Releases/TradingView/3.0.0-rc.1/tradingview-momentum-scalper-3.0.0-rc.1.sha256)
