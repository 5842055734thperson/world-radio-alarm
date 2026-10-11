"""Builds assets/world.json from Natural Earth 1:50m GeoJSON (public domain).

Usage:
  python3 tool/build_map.py <dir with ne_50m_land, ne_50m_admin_0_boundary_lines_land,
                             ne_50m_admin_0_countries .geojson> assets/world.json

Output (coordinates are integers: degrees * 100, flattened lon,lat pairs):
  land     coastline polylines (open; pole/antimeridian edges removed), drawn at every zoom level
  borders  country border lines, faded in when zooming
  c        country outlines (ISO code, English name) used only to find the tapped country
"""
import json, os, sys

src, out = sys.argv[1], sys.argv[2]


def rdp(pts, eps):
    if len(pts) < 3 or eps <= 0:
        return pts
    keep = [False] * len(pts)
    keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        a, b = stack.pop()
        ax, ay = pts[a]; bx, by = pts[b]
        dx, dy = bx - ax, by - ay
        L = (dx * dx + dy * dy) or 1e-12
        best, bi = -1, -1
        for i in range(a + 1, b):
            px, py = pts[i]
            t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / L))
            d = (px - ax - t * dx) ** 2 + (py - ay - t * dy) ** 2
            if d > best:
                best, bi = d, i
        if bi >= 0 and best > eps * eps:
            keep[bi] = True
            stack += [(a, bi), (bi, b)]
    return [p for p, k in zip(pts, keep) if k]


def flat(pts):
    out = []
    for x, y in pts:
        out += [round(x * 100), round(y * 100)]
    return out


def load(name):
    return json.load(open(os.path.join(src, name + '.geojson')))['features']


def polys(geom):
    return geom['coordinates'] if geom['type'] == 'MultiPolygon' else [geom['coordinates']]


def lines(geom):
    return geom['coordinates'] if geom['type'] == 'MultiLineString' else [geom['coordinates']]


def artificial(a, b):
    """Polygon edges along the poles or the antimeridian are not coastline."""
    return (abs(a[1]) > 89.9 and abs(b[1]) > 89.9) or (abs(a[0]) > 179.9 and abs(b[0]) > 179.9)


def coast_lines(ring):
    """Splits a closed ring into open polylines, dropping artificial edges."""
    pts = ring if ring[0] == ring[-1] else ring + [ring[0]]
    lines, cur = [], [pts[0]]
    for a, b in zip(pts, pts[1:]):
        if artificial(a, b):
            if len(cur) >= 2:
                lines.append(cur)
            cur = [b]
        else:
            cur.append(b)
    if len(cur) >= 2:
        lines.append(cur)
    # Re-join the wrap-around piece with the first one when the ring was cut.
    if len(lines) > 1 and lines[-1][-1] == lines[0][0]:
        lines[0] = lines.pop()[:-1] + lines[0]
    return lines


land = []
for f in load('ne_50m_land'):
    for poly in polys(f['geometry']):
        ring = rdp(poly[0], 0.04)
        xs = [x for x, _ in ring]; ys = [y for _, y in ring]
        # skip specks smaller than ~20 km: they only add noise to a line map
        if len(ring) >= 4 and max(max(xs) - min(xs), max(ys) - min(ys)) >= 0.2:
            land.extend(flat(l) for l in coast_lines(ring))

borders = []
for f in load('ne_50m_admin_0_boundary_lines_land'):
    for line in lines(f['geometry']):
        l = rdp(line, 0.03)
        if len(l) >= 2:
            borders.append(flat(l))

countries = []
for f in load('ne_50m_admin_0_countries'):
    p = f['properties']
    iso = p.get('ISO_A2_EH') or p.get('ISO_A2') or ''
    if iso == '-99':
        iso = ''
    rings = [flat(r) for r in (rdp(poly[0], 0.08) for poly in polys(f['geometry'])) if len(r) >= 4]
    if rings:
        countries.append({'i': iso, 'n': p.get('NAME_EN') or p.get('NAME', ''), 'r': rings})

json.dump({'land': land, 'borders': borders, 'c': countries}, open(out, 'w'), separators=(',', ':'))
print(len(land), 'coast lines,', len(borders), 'border lines,', len(countries), 'countries,',
      os.path.getsize(out), 'bytes')
