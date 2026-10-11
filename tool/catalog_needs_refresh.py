#!/usr/bin/env python3
"""Decides whether a scheduled CI run should rebuild the app to refresh the
offline station catalog: yes when Radio Browser is reachable and the bundled
snapshot (restored from the CI cache) is empty or older than 7 days.

Prints `needed=true|false` and appends it to $GITHUB_OUTPUT when set.
"""
import json
import os
import time
import urllib.request

ROOT = os.path.join(os.path.dirname(__file__), '..')
SNAPSHOT = os.path.join(ROOT, 'assets', 'stations.json')
STAMP = os.path.join(ROOT, 'assets', 'stations.stamp')
MAX_AGE = 7 * 24 * 3600


def snapshot_ok():
    try:
        with open(SNAPSHOT) as f:
            if not json.load(f):
                return False
        with open(STAMP) as f:
            return time.time() - float(f.read().strip()) < MAX_AGE
    except Exception:  # noqa: BLE001 - missing/invalid files mean "refresh"
        return False


def directory_up():
    for server in ['https://de1.api.radio-browser.info', 'https://de2.api.radio-browser.info',
                   'https://all.api.radio-browser.info']:
        try:
            req = urllib.request.Request(server + '/json/stats', headers={'User-Agent': 'WorldRadioAlarm/1.0 (ci)'})
            with urllib.request.urlopen(req, timeout=20) as res:
                if res.status == 200 and json.load(res).get('stations', 0) > 0:
                    return True
        except Exception:  # noqa: BLE001
            pass
    return False


fresh = snapshot_ok()
up = directory_up()
needed = up and not fresh
print(f'snapshot fresh={fresh} directory up={up} -> needed={needed}')
out = os.environ.get('GITHUB_OUTPUT')
if out:
    with open(out, 'a') as f:
        f.write(f'needed={"true" if needed else "false"}\n')
