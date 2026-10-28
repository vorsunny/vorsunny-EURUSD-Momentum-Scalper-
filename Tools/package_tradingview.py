"""Create the versioned candidate bundle. Stable packaging requires native evidence."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = '3.0.0-rc.1'
VALIDATION = ROOT / 'Docs/TradingView/validation_results.json'

REQUIRED_GATES = ('pine_compilation', 'native_helper_tests', 'live_alert_reconciliation',
                  'reload_and_closed_browser', 'strategy_controls', 'reproducible_cost_settings')

def stable_ready(results):
    gates = results.get('gates', {})
    live = gates.get('live_alert_reconciliation', {})
    return (live.get('active_sessions', 0) >= 3 and live.get('signal_events', 0) >= 10
            and live.get('unexplained_mismatches') == 0 and all(gates.get(key, {}).get('status') == 'passed'
               and gates[key].get('evidence') for key in REQUIRED_GATES))

def package(output, stable=False):
    results = json.loads(VALIDATION.read_text())
    if stable and not stable_ready(results):
        raise ValueError('Stable release blocked: native/live acceptance evidence is pending')
    if stable and '-' in VERSION:
        raise ValueError('Stable release blocked: promote the prerelease version first')
    paths = [ROOT / item for item in (
        'TradingView/EURUSD_Momentum_Scalper_Indicator.pine',
        'TradingView/EURUSD_Momentum_Scalper_Backtest.pine',
        'TradingView/Tests/Momentum_Scalper_SelfTest.pine',
        'Docs/TradingView/QUICK_START.md', 'Docs/TradingView/SETTINGS_WORKSHEET.md',
        'Docs/TradingView/VALIDATION.md', 'Docs/TradingView/validation_results.json',
        'Docs/TradingView/PLATFORM_COMPARISON.md', 'Docs/TradingView/RELEASE_NOTES.md',
        'Docs/TRADINGVIEW.md', 'Tools/check_alert_log.py')]
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f'tradingview-momentum-scalper-{VERSION}.zip'
    checksums = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as bundle:
        def member(name, content):
            info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            bundle.writestr(info, content)
        for path in paths:
            member(str(path.relative_to(ROOT)), path.read_bytes())
        member('manifest.json', json.dumps({'version': VERSION,
            'status': 'stable' if stable else 'prerelease-native-validation-pending',
            'sha256': checksums}, indent=2) + '\n')
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix('.sha256').write_text(f'{digest}  {archive.name}\n')
    return archive

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'dist')
    parser.add_argument('--stable', action='store_true')
    parser.add_argument('--check-stable', action='store_true')
    args = parser.parse_args()
    if args.check_stable:
        if '-' in VERSION or not stable_ready(json.loads(VALIDATION.read_text())):
            parser.exit(1, 'Stable release blocked: native/live evidence is pending\n')
    else:
        try:
            print(package(args.output, args.stable))
        except ValueError as exc:
            parser.exit(1, f'{exc}\n')
