"""Builds assets/world.json from a Natural Earth admin-0 countries GeoJSON.

Usage: python3 tool/build_map.py ne_50m_admin_0_countries.geojson 0.04 assets/world.json
Coordinates are stored as integers (degrees * 100), outer rings only.
Natural Earth data is public domain.
"""
import json, sys
src, tol, out = sys.argv[1], float(sys.argv[2]), sys.argv[3]

def rdp(pts, eps):
    if len(pts) < 3: return pts
    keep = [False]*len(pts); keep[0]=keep[-1]=True
    stack=[(0,len(pts)-1)]
    while stack:
        a,b=stack.pop(); ax,ay=pts[a]; bx,by=pts[b]
        dx,dy=bx-ax,by-ay; L=(dx*dx+dy*dy) or 1e-12
        best,bi=-1,-1
        for i in range(a+1,b):
            px,py=pts[i]
            t=((px-ax)*dx+(py-ay)*dy)/L; t=max(0,min(1,t))
            qx,qy=ax+t*dx,ay+t*dy; d=(px-qx)**2+(py-qy)**2
            if d>best: best,bi=d,i
        if bi>=0 and best>eps*eps:
            keep[bi]=True; stack+=[(a,bi),(bi,b)]
    return [p for p,k in zip(pts,keep) if k]

d=json.load(open(src)); countries=[]; npts=0
for f in d['features']:
    p=f['properties']
    iso=p.get('ISO_A2_EH') or p.get('ISO_A2')
    if not iso or iso=='-99': iso=''
    g=f['geometry']; polys=g['coordinates'] if g['type']=='MultiPolygon' else [g['coordinates']]
    rings=[]
    for poly in polys:
        ring=rdp(poly[0], tol)  # outer ring only
        if len(ring)<4 or max(y for _,y in ring) < -60: continue
        flat=[]
        for x,y in ring: flat+= [round(x*100), round(y*100)]
        rings.append(flat); npts+=len(ring)
    if rings: countries.append({'i':iso,'n':p.get('NAME_TR') or p.get('NAME',''),'r':rings})
json.dump({'c':countries},open(out,'w'),separators=(',',':'))
import os; print(len(countries),'countries',npts,'points',os.path.getsize(out),'bytes')
