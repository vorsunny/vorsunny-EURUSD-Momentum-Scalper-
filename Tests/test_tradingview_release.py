"""Tooling tests with synthetic logs; these do NOT execute Pine or validate trading."""
import copy
import csv
from datetime import datetime, timezone
import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from Tools.build_tradingview import sync, TARGETS, BEGIN, END
from Tools.check_alert_log import check_log
from Tools.package_tradingview import package, stable_ready, REQUIRED_GATES

STAMP = 1767225600000

def event(stamp=STAMP, sequence=1, direction='BUY'):
    fields = {'id': f'CAPITALCOM:EURUSD:{STAMP}:{stamp}:{sequence}',
              'feed': 'CAPITALCOM:EURUSD', 'mode': 'Realtime updates',
              'time_ms': str(stamp), 'time': datetime.fromtimestamp(stamp / 1000, timezone.utc).strftime('%Y-%m-%d %H:%M:%S'),
              'tz': 'Etc/UTC', 'direction': direction, 'momentum_pips': '1.5',
              'sample_count': '30', 'price': '1.10015', 'stop': '1.09965',
              'target': '1.10090', 'assumed_spread_pips': '1.0'}
    if direction == 'SELL':
        fields.update(momentum_pips='-1.5', stop='1.10065', target='1.09940')
    return fields

def text(fields):
    return 'MS3|' + '|'.join(f'{key}={value}' for key, value in fields.items())

class AlertLogTests(unittest.TestCase):
    def check(self, fields, **kwargs):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'synthetic.csv'
            with path.open('w', newline='') as stream:
                writer = csv.writer(stream)
                writer.writerow(['Message'])
                writer.writerows([[text(item)] for item in fields])
            return check_log(path, **kwargs)

    def test_valid_reversal_and_daily_rollover(self):
        events = [event(), event(STAMP + 30000, 2, 'SELL'), event(STAMP + 86400000, 3)]
        report = self.check(events, daily_cap=2)
        self.assertEqual(report['errors'], [])
        self.assertEqual(report['events'], 3)
        self.assertEqual(len(report['active_dates']), 2)

    def test_duplicate_event(self):
        self.assertIn('duplicate', str(self.check([event(), event()])['errors']))

    def test_cooldown_boundary(self):
        self.assertEqual(self.check([event(), event(STAMP + 30000, 2)])['errors'], [])
        self.assertIn('cooldown', str(self.check([event(), event(STAMP + 29999, 2)])['errors']))

    def test_post_cap_event_rejected(self):
        self.assertIn('cap exceeded', str(self.check([event(), event(STAMP + 30000, 2)], daily_cap=1)['errors']))

    def test_missing_event_detected(self):
        self.assertIn('counter gap', str(self.check([event(), event(STAMP + 30000, 3)])['errors']))

    def test_invalid_level_and_direction(self):
        fields = event(); fields['stop'] = '1.2'
        self.assertIn('direction disagrees', str(self.check([fields])['errors']))

    def test_nonfinite_and_malformed_message(self):
        fields = event(); fields['price'] = 'nan'
        self.assertIn('non-finite', str(self.check([fields])['errors']))
        fields = event(); fields.pop('id')
        self.assertIn('missing', str(self.check([fields])['errors']))

    def test_id_and_timestamp_consistency(self):
        fields = event(); fields['time_ms'] = str(STAMP + 30000)
        self.assertIn('ID does not match', str(self.check([fields])['errors']))
        fields = event(); fields['time'] = '2026-01-01 01:00:00'
        self.assertIn('timezone disagree', str(self.check([fields])['errors']))

    def test_export_column_and_empty_file_are_explicit_failures(self):
        self.assertIn('No valid', str(self.check([])['errors']))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'wrong.csv'
            path.write_text('Other\nvalue\n')
            self.assertIn('Missing CSV column', str(check_log(path)['errors']))

class ReleaseTests(unittest.TestCase):
    def test_scripts_share_exact_core(self):
        self.assertEqual(sync(check=True), [])
        cores = [path.read_text().split(BEGIN)[1].split(END)[0] for path in TARGETS]
        self.assertTrue(all(core == cores[0] for core in cores))

    def test_dashboard_is_computed_after_signal_counters(self):
        source = TARGETS[0].read_text()
        # Source-order check only; native same-update helper behavior has its own Pine test.
        self.assertGreater(source.index('int cooldownRemaining ='), source.index('signalsToday += 1'))
        self.assertGreater(source.index('bool dailyLimitPassed ='), source.index('signalsToday += 1'))

    def test_pending_evidence_cannot_be_stable(self):
        results = json.loads((ROOT / 'Docs/TradingView/validation_results.json').read_text())
        self.assertFalse(stable_ready(results))
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, 'Stable release blocked'):
                package(Path(directory), stable=True)

    def test_stable_gate_requires_sessions_signals_and_zero_mismatches(self):
        gates = {name: {'status': 'passed', 'evidence': ['example-evidence']} for name in REQUIRED_GATES}
        results = {'gates': gates}
        self.assertFalse(stable_ready(results))
        gates['live_alert_reconciliation'].update(active_sessions=3, signal_events=10, unexplained_mismatches=0)
        self.assertTrue(stable_ready(results))
        bad = copy.deepcopy(results)
        bad['gates']['live_alert_reconciliation']['unexplained_mismatches'] = 1
        self.assertFalse(stable_ready(bad))

    def test_bundle_is_reproducible(self):
        with tempfile.TemporaryDirectory() as directory:
            first = package(Path(directory) / 'one').read_bytes()
            second = package(Path(directory) / 'two').read_bytes()
            self.assertEqual(first, second)

    def test_bundle_contains_sources_and_pending_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = package(Path(directory))
            with zipfile.ZipFile(archive) as bundle:
                manifest = json.loads(bundle.read('manifest.json'))
                self.assertIn('pending', manifest['status'])
                for path, digest in manifest['sha256'].items():
                    import hashlib
                    self.assertEqual(hashlib.sha256(bundle.read(path)).hexdigest(), digest)
