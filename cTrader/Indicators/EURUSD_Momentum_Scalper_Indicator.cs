using System;
using cAlgo.API;

namespace cAlgo
{
    [Indicator(IsOverlay = true, TimeZone = TimeZones.UTC, AccessRights = AccessRights.None)]
    public class EURUSDMomentumScalperIndicator : Indicator
    {
        private const int Capacity = 512;
        private readonly double[] _prices = new double[Capacity];
        private readonly DateTime[] _times = new DateTime[Capacity];
        private int _next, _count, _latchedDirection;
        private int _activeDay = -1, _signalsToday;
        private DateTime _lastSignal = DateTime.MinValue;
        private double _lastMomentum = double.NaN, _lastStop = double.NaN, _lastTarget = double.NaN;
        private string _status = "Waiting for live updates";

        [Parameter("Tick window", DefaultValue = 30, MinValue = 2, MaxValue = 512)]
        public int TickWindow { get; set; }
        [Parameter("Momentum threshold (pips)", DefaultValue = 1.5, MinValue = 0.1)]
        public double MomentumThreshold { get; set; }
        [Parameter("Stop reference (pips)", DefaultValue = 5, MinValue = 0.1)]
        public double StopLossPips { get; set; }
        [Parameter("Target reference (pips)", DefaultValue = 7.5, MinValue = 0.1)]
        public double TakeProfitPips { get; set; }
        [Parameter("Maximum assumed spread (pips, 0 off)", DefaultValue = 1, MinValue = 0)]
        public double MaxSpreadPips { get; set; }
        [Parameter("Assumed spread (pips)", DefaultValue = 1, MinValue = 0)]
        public double AssumedSpreadPips { get; set; }
        [Parameter("Minimum ticks per minute", DefaultValue = 10, MinValue = 0, MaxValue = 512)]
        public int MinimumTicksPerMinute { get; set; }
        [Parameter("Maximum window range (pips, 0 off)", DefaultValue = 8, MinValue = 0)]
        public double MaxWindowRangePips { get; set; }
        [Parameter("Maximum single tick jump (pips, 0 off)", DefaultValue = 5, MinValue = 0)]
        public double MaxJumpPips { get; set; }
        [Parameter("Enable UTC session", DefaultValue = false)]
        public bool UseSession { get; set; }
        [Parameter("Session start hour UTC", DefaultValue = 0, MinValue = 0, MaxValue = 23)]
        public int SessionStartHour { get; set; }
        [Parameter("Session start minute UTC", DefaultValue = 0, MinValue = 0, MaxValue = 59)]
        public int SessionStartMinute { get; set; }
        [Parameter("Session end hour UTC", DefaultValue = 23, MinValue = 0, MaxValue = 23)]
        public int SessionEndHour { get; set; }
        [Parameter("Session end minute UTC", DefaultValue = 59, MinValue = 0, MaxValue = 59)]
        public int SessionEndMinute { get; set; }
        [Parameter("Maximum signals per UTC day", DefaultValue = 30, MinValue = 1)]
        public int MaxSignalsPerDay { get; set; }
        [Parameter("Cooldown seconds", DefaultValue = 30, MinValue = 0)]
        public int CooldownSeconds { get; set; }
        [Parameter("Require EURUSD", DefaultValue = true)]
        public bool RequireEurUsd { get; set; }

        protected override void Initialize()
        {
            if (RequireEurUsd && !IsEurUsdSymbol(SymbolName))
                _status = "EURUSD chart required";
        }

        public override void Calculate(int index)
        {
            if (!IsLastBar)
                return;

            var now = Server.TimeInUtc;
            if (RequireEurUsd && !IsEurUsdSymbol(SymbolName))
            {
                _status = "EURUSD chart required";
                DrawStatus();
                return;
            }
            var day = now.Year * 10000 + now.Month * 100 + now.Day;
            if (day != _activeDay)
            {
                _activeDay = day;
                _signalsToday = 0;
            }
            if (!IsValidQuote(Symbol.Bid, Symbol.Ask) || Symbol.PipSize <= 0)
            {
                _status = "Invalid quote";
                DrawStatus();
                return;
            }
            if (MaxSpreadPips > 0 && Symbol.Spread / Symbol.PipSize > MaxSpreadPips)
            {
                _status = "Spread blocked";
                DrawStatus();
                return;
            }
            if (!SessionAllowed(now))
            {
                _status = "Outside session";
                DrawStatus();
                return;
            }

            var mid = (Symbol.Bid + Symbol.Ask) * 0.5;
            var previous = _count == 0 ? double.NaN : _prices[(_next - 1 + Capacity) % Capacity];
            if (_count > 0 && MaxJumpPips > 0 && Math.Abs(mid - previous) / Symbol.PipSize > MaxJumpPips)
            {
                _next = _count = _latchedDirection = 0;
                _status = "Price jump: rebuilding window";
                DrawStatus();
                return;
            }

            _prices[_next] = mid;
            _times[_next] = now;
            _next = (_next + 1) % Capacity;
            _count = Math.Min(_count + 1, Capacity);
            if (_count < TickWindow)
            {
                _status = string.Format("Warming buffer {0}/{1}", _count, TickWindow);
                DrawStatus();
                return;
            }

            var oldest = (_next - TickWindow + Capacity) % Capacity;
            _lastMomentum = (mid - _prices[oldest]) / Symbol.PipSize;
            var low = mid;
            var high = mid;
            for (var i = 0; i < TickWindow; i++)
            {
                var price = _prices[(_next - 1 - i + Capacity) % Capacity];
                low = Math.Min(low, price);
                high = Math.Max(high, price);
            }
            var active = 0;
            for (var i = 0; i < _count; i++)
            {
                var stamp = _times[(_next - 1 - i + Capacity) % Capacity];
                if ((now - stamp).TotalSeconds > 60)
                    break;
                active++;
            }
            if (active < MinimumTicksPerMinute)
                _status = "Activity below minimum";
            else if (MaxWindowRangePips > 0 && (high - low) / Symbol.PipSize > MaxWindowRangePips)
                _status = "Volatility blocked";
            else
                EvaluateSignal(mid, now);

            DrawStatus();
        }

        private void EvaluateSignal(double mid, DateTime now)
        {
            if (Math.Abs(_lastMomentum) < MomentumThreshold * 0.5)
                _latchedDirection = 0;
            var direction = _lastMomentum >= MomentumThreshold ? 1 : _lastMomentum <= -MomentumThreshold ? -1 : 0;
            if (direction == 0 || direction == _latchedDirection)
            {
                _status = "Ready";
                return;
            }
            _latchedDirection = direction;
            if (_signalsToday >= MaxSignalsPerDay)
            {
                _status = "Daily signal limit";
                return;
            }
            if (_lastSignal != DateTime.MinValue && (now - _lastSignal).TotalSeconds < CooldownSeconds)
            {
                _status = "Cooldown";
                return;
            }

            _lastSignal = now;
            _signalsToday++;
            _lastStop = mid - direction * StopLossPips * Symbol.PipSize;
            _lastTarget = mid + direction * TakeProfitPips * Symbol.PipSize;
            var name = "MomentumSignal" + now.Ticks.ToString();
            Chart.DrawText(name, direction > 0 ? "BUY" : "SELL", Bars.Count - 1,
                direction > 0 ? Bars.LowPrices.LastValue : Bars.HighPrices.LastValue,
                direction > 0 ? Color.Lime : Color.Red);
            Chart.DrawHorizontalLine("MomentumStop", _lastStop, Color.Red);
            Chart.DrawHorizontalLine("MomentumTarget", _lastTarget, Color.Lime);
            Print("SIGNAL time={0:O} direction={1} momentumPips={2:F3} mid={3} assumedSpread={4:F2}",
                now, direction > 0 ? "BUY" : "SELL", _lastMomentum, mid, AssumedSpreadPips);
            _status = "Signal " + (direction > 0 ? "BUY" : "SELL");
        }

        private void DrawStatus()
        {
            var momentum = double.IsNaN(_lastMomentum) ? "warming" : _lastMomentum.ToString("F2") + " pips";
            Chart.DrawStaticText("MomentumStatus",
                "EURUSD Momentum Scalper | " + _status + " | Momentum " + momentum + " | Signals " + _signalsToday + "/" + MaxSignalsPerDay +
                " | Assumed spread " + AssumedSpreadPips.ToString("F1") + " pips",
                VerticalAlignment.Top, HorizontalAlignment.Left, Color.White);
        }

        private bool SessionAllowed(DateTime utc)
        {
            if (!UseSession)
                return true;
            var current = utc.Hour * 60 + utc.Minute;
            var start = SessionStartHour * 60 + SessionStartMinute;
            var end = SessionEndHour * 60 + SessionEndMinute;
            return start == end || (start < end ? current >= start && current < end : current >= start || current < end);
        }

        private static bool IsValidQuote(double bid, double ask) => bid > 0 && ask >= bid && !double.IsNaN(bid) && !double.IsNaN(ask);
        private static bool IsEurUsdSymbol(string name)
        {
            var compact = name.Replace(".", string.Empty).Replace("_", string.Empty).Replace("-", string.Empty);
            return compact.StartsWith("EURUSD", StringComparison.OrdinalIgnoreCase);
        }
    }
}
