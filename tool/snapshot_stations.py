#!/usr/bin/env python3
"""Writes assets/stations.json: the most popular Radio Browser stations, bundled
into the app as an offline catalog for when the radio directory is down.

If the directory can't be reached, an existing file (e.g. restored from the CI
cache) is kept; without one an empty list is written so the build still works.
Radio Browser data is free to use (https://www.radio-browser.info).
"""
import json
import os
import random
import sys
import time
import urllib.request

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'stations.json')
LIMIT = 8000
KEYS = ['stationuuid', 'name', 'url_resolved', 'favicon', 'country', 'countrycode',
        'tags', 'codec', 'bitrate', 'language', 'geo_lat', 'geo_long']
SERVERS = ['https://de1.api.radio-browser.info', 'https://de2.api.radio-browser.info']
random.shuffle(SERVERS)
SERVERS.append('https://all.api.radio-browser.info')


def fetch():
    query = f'/json/stations/search?hidebroken=true&order=clickcount&reverse=true&limit={LIMIT}'
    for server in SERVERS:
        try:
            req = urllib.request.Request(server + query, headers={'User-Agent': 'WorldRadioAlarm/1.0 (build)'})
            with urllib.request.urlopen(req, timeout=90) as res:
                data = json.load(res)
            if isinstance(data, list) and data:
                return data
        except Exception as e:  # noqa: BLE001 - any failure means "try the next mirror"
            print(f'{server}: {e}', file=sys.stderr)
    return None


data = fetch()
if data is None:
    if os.path.exists(OUT) and os.path.getsize(OUT) > 2:
        print('radio directory unreachable; keeping the existing snapshot')
    else:
        print('radio directory unreachable and no snapshot; writing an empty catalog')
        with open(OUT, 'w') as f:
            f.write('[]')
    sys.exit(0)

slim = []
for s in data:
    item = {k: s.get(k) for k in KEYS if s.get(k) not in (None, '', 0)}
    if item.get('url_resolved') and item.get('name'):
        slim.append(item)
with open(OUT, 'w') as f:
    json.dump(slim, f, ensure_ascii=False, separators=(',', ':'))
# When this snapshot was taken (read by tool/catalog_needs_refresh.py).
with open(os.path.join(os.path.dirname(OUT), 'stations.stamp'), 'w') as f:
    f.write(str(int(time.time())))
print(f'wrote {len(slim)} stations, {os.path.getsize(OUT)} bytes')
