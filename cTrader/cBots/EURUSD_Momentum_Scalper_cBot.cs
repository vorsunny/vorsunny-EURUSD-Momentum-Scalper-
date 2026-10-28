using System;
using System.Collections.Generic;
using System.Globalization;
using cAlgo.API;

namespace cAlgo.Robots
{
    [Robot(TimeZone = TimeZones.UTC, AccessRights = AccessRights.None)]
    public class EURUSDMomentumScalper : Robot
    {
        private const int Capacity = 512;
        private readonly double[] _prices = new double[Capacity];
        private readonly DateTime[] _times = new DateTime[Capacity];
        private readonly Dictionary<long, DateTime> _lastCloseAttempt = new Dictionary<long, DateTime>();
        private int _next, _count, _latchedDirection;
        private int _tradesToday;
        private DateTime _activeDay, _lastEntry = DateTime.MinValue;
        private double _dayStartEquity;
        private bool _dailyLocked, _executionPending;

        [Parameter("Bot label", DefaultValue = "EURUSD Momentum Scalper", Group = "General")]
        public string BotLabel { get; set; }
        [Parameter("Demo account only", DefaultValue = true, Group = "Safety")]
        public bool DemoOnly { get; set; }
        [Parameter("Require EURUSD", DefaultValue = true, Group = "Safety")]
        public bool RequireEurUsd { get; set; }
        [Parameter("Tick window", DefaultValue = 30, MinValue = 2, MaxValue = 512, Group = "Signal")]
        public int TickWindow { get; set; }
        [Parameter("Momentum threshold (pips)", DefaultValue = 1.5, MinValue = 0.1, Group = "Signal")]
        public double MomentumThreshold { get; set; }
        [Parameter("Stop loss (pips)", DefaultValue = 5, MinValue = 0.1, Group = "Risk")]
        public double StopLossPips { get; set; }
        [Parameter("Take profit (pips)", DefaultValue = 7.5, MinValue = 0.1, Group = "Risk")]
        public double TakeProfitPips { get; set; }
        [Parameter("Risk per trade (%)", DefaultValue = 0.10, MinValue = 0.01, MaxValue = 10, Group = "Risk")]
        public double RiskPercent { get; set; }
        [Parameter("Maximum daily equity loss (%)", DefaultValue = 1, MinValue = 0, MaxValue = 50, Group = "Risk")]
        public double MaxDailyLossPercent { get; set; }
        [Parameter("Close positions at daily loss", DefaultValue = true, Group = "Risk")]
        public bool CloseAtDailyLoss { get; set; }
        [Parameter("Maximum spread (pips)", DefaultValue = 1, MinValue = 0, Group = "Filters")]
        public double MaxSpreadPips { get; set; }
        [Parameter("Minimum ticks per minute", DefaultValue = 10, MinValue = 0, MaxValue = 512, Group = "Filters")]
        public int MinimumTicksPerMinute { get; set; }
        [Parameter("Maximum window range (pips, 0 off)", DefaultValue = 8, MinValue = 0, Group = "Filters")]
        public double MaxWindowRangePips { get; set; }
        [Parameter("Maximum single tick jump (pips, 0 off)", DefaultValue = 5, MinValue = 0, Group = "Filters")]
        public double MaxJumpPips { get; set; }
        [Parameter("Enable UTC session", DefaultValue = false, Group = "Session")]
        public bool UseSession { get; set; }
        [Parameter("Session start hour UTC", DefaultValue = 0, MinValue = 0, MaxValue = 23, Group = "Session")]
        public int SessionStartHour { get; set; }
        [Parameter("Session start minute UTC", DefaultValue = 0, MinValue = 0, MaxValue = 59, Group = "Session")]
        public int SessionStartMinute { get; set; }
        [Parameter("Session end hour UTC", DefaultValue = 23, MinValue = 0, MaxValue = 23, Group = "Session")]
        public int SessionEndHour { get; set; }
        [Parameter("Session end minute UTC", DefaultValue = 59, MinValue = 0, MaxValue = 59, Group = "Session")]
        public int SessionEndMinute { get; set; }
        [Parameter("Cooldown seconds", DefaultValue = 30, MinValue = 0, Group = "Limits")]
        public int CooldownSeconds { get; set; }
        [Parameter("Maximum entries per UTC day", DefaultValue = 30, MinValue = 1, Group = "Limits")]
        public int MaxTradesPerDay { get; set; }
        [Parameter("Maximum holding seconds", DefaultValue = 60, MinValue = 1, Group = "Limits")]
        public int MaxHoldingSeconds { get; set; }
        [Parameter("Maximum volume units (0 = broker max)", DefaultValue = 0, MinValue = 0, Group = "Risk")]
        public double MaxVolumeUnits { get; set; }
        [Parameter("Maximum entry slippage (pips)", DefaultValue = 0.5, MinValue = 0.1, Group = "Execution")]
        public double MaxSlippagePips { get; set; }

        protected override void OnStart()
        {
            if (string.IsNullOrWhiteSpace(BotLabel))
            {
                Print("INIT_REJECT: bot label is empty.");
                Stop();
                return;
            }
            if (DemoOnly && Account.IsLive)
            {
                Print("INIT_REJECT: demo-only protection is enabled; this is a live account.");
                Stop();
                return;
            }
            if (RequireEurUsd && !IsEurUsdSymbol(SymbolName))
            {
                Print("INIT_REJECT: attach this cBot to an EURUSD symbol. Current: {0}", SymbolName);
                Stop();
                return;
            }

            RestoreRiskState();
            Positions.Closed += OnPositionClosed;
            Timer.Start(TimeSpan.FromSeconds(1));
            Print("START symbol={0} pip={1} tick={2} account={3} demoOnly={4}", SymbolName, Symbol.PipSize, Symbol.TickSize, Account.Number, DemoOnly);
        }

        protected override void OnTick()
        {
            ManageSafetyAndExits();
            if (_executionPending || _dailyLocked || !Symbol.IsTradingEnabled)
                return;

            var bid = Symbol.Bid;
            var ask = Symbol.Ask;
            if (!IsValidQuote(bid, ask))
                return;
            var now = Server.TimeInUtc;
            UpdateDay(now);
            if (_dailyLocked || !SessionAllowed(now) || (ask - bid) / Symbol.PipSize > MaxSpreadPips)
                return;

            var mid = (bid + ask) * 0.5;
            var previous = _count == 0 ? double.NaN : _prices[(_next - 1 + Capacity) % Capacity];
            if (_count > 0 && MaxJumpPips > 0 && Math.Abs(mid - previous) / Symbol.PipSize > MaxJumpPips)
            {
                _next = _count = _latchedDirection = 0;
                Print("FILTER price jump; rolling window reset. jumpPips={0:F2}", Math.Abs(mid - previous) / Symbol.PipSize);
                return;
            }

            _prices[_next] = mid;
            _times[_next] = now;
            _next = (_next + 1) % Capacity;
            _count = Math.Min(_count + 1, Capacity);
            if (_count < TickWindow)
                return;

            var oldest = (_next - TickWindow + Capacity) % Capacity;
            var momentum = (mid - _prices[oldest]) / Symbol.PipSize;
            var low = mid;
            var high = mid;
            for (var i = 0; i < TickWindow; i++)
            {
                var p = _prices[(_next - 1 - i + Capacity) % Capacity];
                low = Math.Min(low, p);
                high = Math.Max(high, p);
            }
            var range = (high - low) / Symbol.PipSize;
            var active = 0;
            for (var i = 0; i < _count; i++)
            {
                var stamp = _times[(_next - 1 - i + Capacity) % Capacity];
                if ((now - stamp).TotalSeconds > 60)
                    break;
                active++;
            }
            if ((MaxWindowRangePips > 0 && range > MaxWindowRangePips) || active < MinimumTicksPerMinute)
                return;

            if (Math.Abs(momentum) < MomentumThreshold * 0.5)
                _latchedDirection = 0;
            var direction = momentum >= MomentumThreshold ? 1 : momentum <= -MomentumThreshold ? -1 : 0;
            if (direction == 0 || direction == _latchedDirection)
                return;

            _latchedDirection = direction;
            Print("SIGNAL time={0:O} direction={1} momentumPips={2:F3} bid={3} ask={4} spreadPips={5:F2} rangePips={6:F2}", now, direction > 0 ? "BUY" : "SELL", momentum, bid, ask, (ask - bid) / Symbol.PipSize, range);
            TryEnter(direction, now);
        }

        protected override void OnTimer() => ManageSafetyAndExits();

        protected override void OnStop()
        {
            Positions.Closed -= OnPositionClosed;
            Timer.Stop();
            SaveRiskState();
        }

        private void TryEnter(int direction, DateTime now)
        {
            if (now - _lastEntry < TimeSpan.FromSeconds(CooldownSeconds))
            {
                Print("REJECT cooldown");
                return;
            }
            if (_tradesToday >= MaxTradesPerDay)
            {
                Print("REJECT daily trade limit");
                return;
            }
            if (FindBotPositions().Length > 0)
            {
                Print("REJECT bot position already open");
                return;
            }
            // On netting accounts an order can alter an existing symbol position. Block when any
            // position exists on this symbol unless it is clearly this bot's managed position.
            foreach (var position in Positions)
                if (position.SymbolName == SymbolName && position.Label != BotLabel)
                {
                    Print("REJECT another position exists on symbol; preserving unrelated exposure");
                    return;
                }

            var tradeType = direction > 0 ? TradeType.Buy : TradeType.Sell;
            var riskVolume = Symbol.VolumeForProportionalRisk(ProportionalAmountType.Equity, RiskPercent, StopLossPips, RoundingMode.Down);
            if (!IsFinitePositive(riskVolume) || riskVolume < Symbol.VolumeInUnitsMin)
            {
                Print("REJECT minimum volume exceeds risk budget; calculatedUnits={0} brokerMin={1}", riskVolume, Symbol.VolumeInUnitsMin);
                return;
            }
            var cap = MaxVolumeUnits > 0 ? Math.Min(MaxVolumeUnits, Symbol.VolumeInUnitsMax) : Symbol.VolumeInUnitsMax;
            var volume = Symbol.NormalizeVolumeInUnits(Math.Min(riskVolume, cap), RoundingMode.Down);
            if (volume < Symbol.VolumeInUnitsMin || volume > Symbol.VolumeInUnitsMax)
            {
                Print("REJECT volume invalid after rounding; units={0}", volume);
                return;
            }
            var margin = Symbol.GetEstimatedMargin(tradeType, volume);
            if (!IsFinitePositive(margin) || margin > Account.FreeMargin)
            {
                Print("REJECT insufficient margin; required={0} free={1}", margin, Account.FreeMargin);
                return;
            }

            _executionPending = true;
            var reference = direction > 0 ? Symbol.Ask : Symbol.Bid;
            var result = ExecuteMarketRangeOrder(tradeType, SymbolName, volume, MaxSlippagePips, reference, BotLabel,
                StopLossPips, TakeProfitPips, "rolling momentum scalper");
            _executionPending = false;
            if (!result.IsSuccessful || result.Position == null)
            {
                Print("ORDER_REJECTED direction={0} units={1} error={2}", tradeType, volume, result.Error);
                return;
            }

            _lastEntry = now;
            _tradesToday++;
            SaveRiskState();
            var fill = result.Position.EntryPrice;
            var slipPips = Math.Abs(fill - reference) / Symbol.PipSize;
            Print("FILL id={0} direction={1} units={2} entry={3} slPips={4} tpPips={5} estimatedRisk={6} slippagePips={7:F2}",
                result.Position.Id, tradeType, volume, fill, StopLossPips, TakeProfitPips,
                Account.Equity * RiskPercent / 100.0, slipPips);
        }

        private void ManageSafetyAndExits()
        {
            var now = Server.TimeInUtc;
            UpdateDay(now);
            if (MaxDailyLossPercent > 0 && _dayStartEquity > 0)
            {
                var loss = (_dayStartEquity - Account.Equity) / _dayStartEquity * 100.0;
                if (loss >= MaxDailyLossPercent && !_dailyLocked)
                {
                    _dailyLocked = true;
                    SaveRiskState();
                    Print("RISK_LOCK daily equity loss={0:F3}% limit={1:F3}% dayStart={2} equity={3}", loss, MaxDailyLossPercent, _dayStartEquity, Account.Equity);
                }
            }
            foreach (var position in FindBotPositions())
            {
                var shouldClose = (_dailyLocked && CloseAtDailyLoss) || (now - position.EntryTime).TotalSeconds >= MaxHoldingSeconds;
                if (shouldClose && (!_lastCloseAttempt.TryGetValue(position.Id, out var previousAttempt) || (now - previousAttempt).TotalSeconds >= 5))
                {
                    _lastCloseAttempt[position.Id] = now;
                    var result = ClosePosition(position);
                    if (!result.IsSuccessful)
                        Print("CLOSE_REJECTED id={0} error={1}", position.Id, result.Error);
                }
            }
        }

        private void OnPositionClosed(PositionClosedEventArgs args)
        {
            var p = args.Position;
            if (p.Label != BotLabel || p.SymbolName != SymbolName)
                return;
            Print("CLOSED id={0} reason={1} durationSeconds={2:F1} realizedNet={3}", p.Id, args.Reason, (Server.TimeInUtc - p.EntryTime).TotalSeconds, p.NetProfit);
        }

        private Position[] FindBotPositions() => Positions.FindAll(BotLabel, SymbolName);

        private void UpdateDay(DateTime now)
        {
            var day = now.Date;
            if (day == _activeDay)
                return;
            _activeDay = day;
            _dayStartEquity = Account.Equity;
            _tradesToday = 0;
            _dailyLocked = false;
            SaveRiskState();
            Print("RISK_DAY_RESET utcDate={0:yyyy-MM-dd} startEquity={1}", day, _dayStartEquity);
        }

        private bool SessionAllowed(DateTime utc)
        {
            if (!UseSession)
                return true;
            var now = utc.Hour * 60 + utc.Minute;
            var start = SessionStartHour * 60 + SessionStartMinute;
            var end = SessionEndHour * 60 + SessionEndMinute;
            if (start == end)
                return true;
            return start < end ? now >= start && now < end : now >= start || now < end;
        }

        private void RestoreRiskState()
        {
            var raw = LocalStorage.GetString("Momentum risk state", LocalStorageScope.Instance);
            var parts = raw.Split('|');
            if (parts.Length == 5 && DateTime.TryParseExact(parts[0], "yyyyMMdd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var day)
                && double.TryParse(parts[1], NumberStyles.Float, CultureInfo.InvariantCulture, out var equity)
                && int.TryParse(parts[2], out var trades) && bool.TryParse(parts[3], out var locked)
                && long.TryParse(parts[4], out var lastTicks) && day.Date == Server.TimeInUtc.Date)
            {
                _activeDay = day.Date;
                _dayStartEquity = equity;
                _tradesToday = trades;
                _dailyLocked = locked;
                _lastEntry = lastTicks == 0 ? DateTime.MinValue : new DateTime(lastTicks, DateTimeKind.Utc);
                Print("RISK_STATE_RESTORED day={0:yyyy-MM-dd} trades={1} locked={2}", _activeDay, _tradesToday, _dailyLocked);
                return;
            }
            _activeDay = Server.TimeInUtc.Date;
            _dayStartEquity = Account.Equity;
            _tradesToday = 0;
            _lastEntry = DateTime.MinValue;
            _dailyLocked = false;
            SaveRiskState();
        }

        private void SaveRiskState()
        {
            var payload = string.Join("|", _activeDay.ToString("yyyyMMdd", CultureInfo.InvariantCulture),
                _dayStartEquity.ToString("R", CultureInfo.InvariantCulture), _tradesToday.ToString(CultureInfo.InvariantCulture),
                _dailyLocked.ToString(), _lastEntry == DateTime.MinValue ? "0" : _lastEntry.Ticks.ToString(CultureInfo.InvariantCulture));
            LocalStorage.SetString("Momentum risk state", payload, LocalStorageScope.Instance);
            LocalStorage.Flush(LocalStorageScope.Instance);
        }

        private static bool IsValidQuote(double bid, double ask) => IsFinitePositive(bid) && IsFinitePositive(ask) && ask >= bid;
        private static bool IsFinitePositive(double value) => !double.IsNaN(value) && !double.IsInfinity(value) && value > 0;
        private static bool IsEurUsdSymbol(string name)
        {
            var compact = name.Replace(".", string.Empty).Replace("_", string.Empty).Replace("-", string.Empty);
            return compact.StartsWith("EURUSD", StringComparison.OrdinalIgnoreCase);
        }
    }
}
