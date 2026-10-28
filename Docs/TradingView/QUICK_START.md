# TradingView v3.0.0-rc.1 quick start

**Release candidate: native compilation and live validation are pending.** Use for controlled validation and manual signal review. These scripts do not connect to a broker or place real orders.

## Chart signals

1. Open your broker/feed's EURUSD chart, select **1 minute** and standard candles. Keep its exact feed identifier for your worksheet. Tick, Renko and Heikin Ashi charts are unsupported.
2. In Pine Editor, select all existing text and replace it with the entire `EURUSD_Momentum_Scalper_Indicator.pine` file. Save, build and add it to the chart. Report any compiler warnings/errors in the validation checklist.
3. Keep **Realtime updates** selected. Warmup means 30 accepted live updates, not 30 minutes. The dashboard shows progress, momentum, cooldown and daily count. Ready means filters allow signals, not that a trade has been recommended.
4. A green BUY or red SELL label identifies a signal episode. Indicative SL/TP levels refer to the latest signal; they are not broker orders. Multiple events in the same bar can share chart markers, so use the signal ID and Alerts Log for event-level records.

## Realtime alerts and retained history

1. After configuring inputs, click **Create Alert**. Select this indicator and **Any alert() function call**. This is the recommended single alert for both directions, with full signal details.
2. Enable the desired app notification/popup/sound/email and check the expiration permitted by your TradingView plan. Confirm the alert is active in the Alerts Manager.
3. Keep cooldown at its default 30 seconds for initial validation. Very high alert rates can cause TradingView to stop alerts; monitor their status.
4. Signals use the `MS3` message format and include a per-runtime signal ID. The server alert runs its own copy of the script; its warmup and IDs can differ from the chart copy. Reconcile by feed, sampling mode, direction, time and price, using IDs within each runtime.
5. The chart buffer starts over on reload. Exact prior live markers cannot be reconstructed. The server alert runs independently of the browser and its events can be reviewed/exported from **Alerts Log** within TradingView's retention limits. Export records for long-term retention; no unlimited retention is promised.
6. Recreate the alert after changing script code, feed, timeframe or inputs. Existing alerts retain their creation-time script/settings. Avoid creating duplicate alerts for the same purpose.

Separate BUY/SELL conditions remain available. Choose **Once Per Bar** for an intrabar condition alert, understanding that this can suppress a second event in the same bar. A bar-close-only condition can miss an earlier intrabar pulse. Do not simultaneously enable those conditions and the recommended all-event alert unless duplicate notifications are intentional.

## Strategy Tester

Use the separate `EURUSD_Momentum_Scalper_Backtest.pine` script. Its visible **BAR PROXY** designation is deliberate: 30 samples mean 30 completed chart bars. It does not replay the indicator's live update stream or apply its tick-activity filter.

In Strategy Properties configure EUR 10,000 initial capital, the feed's quantity units, actual commissions and modeled slippage/spread costs. The assumed-spread input only gates entries; it never deducts spread costs from fills. See the settings worksheet before interpreting net profit. The optional UTC entry-date filter is inclusive at start/exclusive at end and warms samples from earlier available chart data. Orders fill on subsequent available ticks, so gaps/forced closing fills can extend outside the selected window.

## Next validation step

Run `Momentum_Scalper_SelfTest.pine` as a separate indicator in Pine Editor, then follow `VALIDATION.md`. A green helper-test result checks the same mathematical helpers embedded in the scripts; it does not replace checking native strategy orders and live server alerts.
