"""Sync shared helpers into self-contained Pine scripts; --check never writes."""
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BEGIN = "// BEGIN SHARED MOMENTUM CORE"
END = "// END SHARED MOMENTUM CORE"
TARGETS = [ROOT / "TradingView" / name for name in (
    "EURUSD_Momentum_Scalper_Indicator.pine",
    "EURUSD_Momentum_Scalper_Backtest.pine",
    "Tests/Momentum_Scalper_SelfTest.pine",
)]

def sync(check=False):
    core = (ROOT / "TradingView/Shared/MomentumCore.pineinc").read_text().rstrip()
    stale = []
    for path in TARGETS:
        source = path.read_text()
        before, rest = source.split(BEGIN, 1)
        _, after = rest.split(END, 1)
        result = before + BEGIN + "\n" + core + "\n" + END + after
        if source != result:
            stale.append(str(path.relative_to(ROOT)))
            if not check:
                path.write_text(result)
    return stale

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    stale = sync(args.check)
    if args.check and stale:
        parser.exit(1, "Unsynced Pine helpers: " + ", ".join(stale) + "\n")
    print("Pine helper sync checked" if args.check else "Pine helpers synced")
