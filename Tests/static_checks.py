"""Repository-level checks; these do not replace MetaEditor compilation or MT5 execution."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ProjectChecks(unittest.TestCase):
    def test_required_artifacts_exist(self):
        expected = [
            "Experts/EURUSD_Momentum_Scalper.mq5",
            "Include/MomentumScalper/Types.mqh",
            "Include/MomentumScalper/SignalEngine.mqh",
            "Include/MomentumScalper/RiskManager.mqh",
            "Include/MomentumScalper/ExecutionEngine.mqh",
            "Include/MomentumScalper/PositionManager.mqh",
            "Include/MomentumScalper/Logger.mqh",
            "Config/EURUSD_Default.set",
            "Docs/README.md", "Docs/STRATEGY.md", "Docs/RISK.md",
            "Docs/BACKTEST.md", "Docs/TRADINGVIEW.md", "TradingView/EURUSD_Momentum_Scalper_Indicator.pine",
            "TradingView/EURUSD_Momentum_Scalper_Backtest.pine",
            "Tests/TEST_PLAN.md", "Tests/UnitTests.mq5",
        ]
        for item in expected:
            with self.subTest(item=item):
                self.assertTrue((ROOT / item).is_file())

    def test_no_placeholder_markers(self):
        paths = list((ROOT / "Experts").glob("*.mq5")) + list((ROOT / "Include").rglob("*.mqh")) + list((ROOT / "TradingView").glob("*.pine"))
        for path in paths:
            source = path.read_text()
            self.assertNotRegex(source, r"(?i)TODO|FIXME|not implemented|placeholder")

    def test_safe_defaults_are_present(self):
        ea = (ROOT / "Experts/EURUSD_Momentum_Scalper.mq5").read_text()
        self.assertIn("InpDemoAccountOnly=true", ea)
        self.assertIn("InpRiskPercent=0.10", ea)
        self.assertIn("InpMaximumDailyLossPercent=1.0", ea)
        self.assertIn("InpMaximumSimultaneousPositions=1", ea)
        self.assertIn("InpClosePositionsOnDailyLoss=true", ea)

    def test_key_controls_are_present(self):
        risk = (ROOT / "Include/MomentumScalper/RiskManager.mqh").read_text()
        execution = (ROOT / "Include/MomentumScalper/ExecutionEngine.mqh").read_text()
        self.assertIn("OrderCalcProfit", risk)
        self.assertIn("MSVolumeForRiskBudget", risk)
        self.assertIn("GlobalVariableSet", risk)
        self.assertIn("MSDailyLossBreached", risk)
        self.assertIn("OrderCheck", execution)
        self.assertIn("TRADE_RETCODE_DONE_PARTIAL", execution)
        self.assertIn("TRADE_TRANSACTION_DEAL_ADD", execution)
        self.assertIn("SYMBOL_TRADE_FREEZE_LEVEL", execution)

    def test_tradingview_indicator_is_not_a_strategy(self):
        pine = (ROOT / "TradingView/EURUSD_Momentum_Scalper_Indicator.pine").read_text()
        self.assertTrue(pine.startswith("//@version=6"))
        self.assertIn("indicator(", pine)
        self.assertIn("alertcondition(buyPulse", pine)
        self.assertIn("alertcondition(sellPulse", pine)
        self.assertIn("varip array<float>", pine)
        self.assertNotIn("strategy(", pine)
        self.assertNotRegex(pine, r"strategy\.(entry|exit|order)\(")
        strategy = (ROOT / "TradingView/EURUSD_Momentum_Scalper_Backtest.pine").read_text()
        self.assertTrue(strategy.startswith("//@version=6"))
        self.assertIn("strategy(", strategy)
        self.assertIn("initial_capital=10000", strategy)
        self.assertIn("strategy.exit", strategy)
        self.assertIn("strategy.close_all", strategy)

    def test_braces_balance(self):
        paths = list((ROOT / "Experts").glob("*.mq5")) + list((ROOT / "Include").rglob("*.mqh")) + list((ROOT / "Tests").glob("*.mq5")) + list((ROOT / "TradingView").glob("*.pine"))
        for path in paths:
            source = path.read_text()
            source = re.sub(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"', "", source, flags=re.S)
            self.assertEqual(source.count("{"), source.count("}"), str(path))

if __name__ == "__main__":
    unittest.main(verbosity=2)
