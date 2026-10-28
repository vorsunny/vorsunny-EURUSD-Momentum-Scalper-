"""Check an exported TradingView Message column. Does not validate the live feed."""
import argparse
import csv
from datetime import datetime, timezone
import json
import math
from pathlib import Path
from zoneinfo import ZoneInfo

FIELDS = {'id', 'feed', 'mode', 'time_ms', 'time', 'tz', 'direction',
          'momentum_pips', 'sample_count', 'price', 'stop', 'target', 'assumed_spread_pips'}

def check_log(path, message_column='Message', cooldown=30, daily_cap=30):
    errors, events, ids, previous, daily = [], [], set(), {}, {}
    ignored = 0
    with Path(path).open(newline='', encoding='utf-8-sig') as stream:
        reader = csv.DictReader(stream)
        if message_column not in (reader.fieldnames or []):
            return {'events': 0, 'errors': [f'Missing CSV column: {message_column}'], 'ignored': 0}
        for line, row in enumerate(reader, start=2):
            message = row.get(message_column) or ''
            if not message.startswith('MS3|'):
                ignored += 1
                continue
            try:
                pieces = message.split('|')[1:]
                fields = dict(piece.split('=', 1) for piece in pieces)
                if len(fields) != len(pieces) or not FIELDS.issubset(fields):
                    raise ValueError('missing or repeated fields')
                feed, run, stamp_id, counter = fields['id'].rsplit(':', 3)
                stamp, sequence = int(fields['time_ms']), int(counter)
                if feed != fields['feed'] or int(stamp_id) != stamp or sequence < 1 or int(run) < 0:
                    raise ValueError('signal ID does not match event')
                if fields['id'] in ids:
                    raise ValueError('duplicate signal ID')
                if fields['direction'] not in ('BUY', 'SELL') or fields['mode'] not in ('Realtime updates', 'Bar-close proxy'):
                    raise ValueError('invalid direction or sampling mode')
                numeric = {key: float(fields[key]) for key in ('price', 'stop', 'target', 'momentum_pips', 'assumed_spread_pips')}
                if not all(math.isfinite(value) for value in numeric.values()):
                    raise ValueError('non-finite numeric value')
                price, stop, target = (numeric[key] for key in ('price', 'stop', 'target'))
                if min(price, stop, target) <= 0 or numeric['assumed_spread_pips'] < 0 or int(fields['sample_count']) < 2:
                    raise ValueError('invalid sample count, spread or level')
                if fields['direction'] == 'BUY':
                    consistent = stop < price < target and numeric['momentum_pips'] > 0
                else:
                    consistent = target < price < stop and numeric['momentum_pips'] < 0
                if not consistent:
                    raise ValueError('direction disagrees with momentum or levels')
                local = datetime.fromtimestamp(stamp / 1000, timezone.utc).astimezone(ZoneInfo(fields['tz']))
                if local.strftime('%Y-%m-%d %H:%M:%S') != fields['time']:
                    raise ValueError('timestamp/timezone disagree')
                group = (feed, run)
                if group in previous:
                    old_stamp, old_sequence = previous[group]
                    if stamp < old_stamp or sequence <= old_sequence:
                        raise ValueError('out-of-order event or counter')
                    if sequence != old_sequence + 1:
                        raise ValueError('counter gap: missing signal event')
                    if stamp - old_stamp < cooldown * 1000:
                        raise ValueError('cooldown violation')
                day_key = (*group, local.date().isoformat())
                if daily.get(day_key, 0) >= daily_cap:
                    raise ValueError('daily signal cap exceeded')
                ids.add(fields['id'])
                previous[group] = stamp, sequence
                daily[day_key] = daily.get(day_key, 0) + 1
                events.append(fields)
            except (ValueError, KeyError, OverflowError) as exc:
                errors.append(f'CSV row {line}: {exc}')
    if not events:
        errors.append('No valid MS3 signal events found')
    return {'events': len(events), 'errors': errors, 'ignored': ignored,
            'active_dates': sorted({key[2] for key in daily}),
            'script_runs': len(previous), 'cooldown_seconds_checked': cooldown,
            'daily_cap_checked_per_run': daily_cap,
            'native_validation': 'NOT established by this log check'}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('csv', type=Path)
    parser.add_argument('--message-column', default='Message')
    parser.add_argument('--cooldown', type=int, default=30)
    parser.add_argument('--daily-cap', type=int, default=30)
    args = parser.parse_args()
    if args.cooldown < 0 or args.daily_cap < 1:
        parser.error('cooldown must be nonnegative; daily cap must be positive')
    report = check_log(args.csv, args.message_column, args.cooldown, args.daily_cap)
    print(json.dumps(report, indent=2))
    raise SystemExit(bool(report['errors']))
