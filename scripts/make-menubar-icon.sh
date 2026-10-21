#!/bin/sh
# Regenerates Resources/MenuBarIcon.pdf: a slimmer, single-colour version of the app icon's S for the status bar.
# Needs python3 and rsvg-convert (brew install librsvg). Black = opaque; the status bar uses only the alpha of a template image.
set -e
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"
python3 - "$TMP/s.svg" <<'PY'
import math, sys
r, w, E = 132, 80, -48            # centre-line radius, stroke width, end angle of the top bowl (same shape as the app icon)
hw = w / 2
def pt(cy, R, deg):
    a = math.radians(deg); return (512 + R * math.cos(a), cy + R * math.sin(a))
def f(p): return f"{p[0]:.1f} {p[1]:.1f}"
top, bot = 512 - r, 512 + r
def ring(cy, a0, a1, sweep):
    Ro, Ri = r + hw, r - hw
    return (f"M {f(pt(cy, Ro, a0))} A {Ro} {Ro} 0 1 {sweep} {f(pt(cy, Ro, a1))} "
            f"L {f(pt(cy, Ri, a1))} A {Ri} {Ri} 0 1 {1 - sweep} {f(pt(cy, Ri, a0))} Z")
def arrow(B, d, half=112, length=150, back=12):
    n = (-d[1], d[0]); base = (B[0] - back * d[0], B[1] - back * d[1]); tip = (B[0] + length * d[0], B[1] + length * d[1])
    return f"M {f((base[0] + half * n[0], base[1] + half * n[1]))} L {f(tip)} L {f((base[0] - half * n[0], base[1] - half * n[1]))} Z"
d = (math.cos(math.radians(E + 90)), math.sin(math.radians(E + 90)))
B1 = pt(top, r, E); B2 = pt(bot, r, E + 180)
# The two bowls overlap by 4 degrees at the join so no hairline seam shows between them when drawn small.
paths = [ring(top, E, -274, 0), ring(bot, -94, E + 180, 1), arrow(B1, d), arrow(B2, (-d[0], -d[1]))]
body = "".join(f'<path d="{p}" fill="#000000"/>' for p in paths)

# Tight viewBox from the geometry itself, so the glyph fills the page height.
pts = []
for cy, a0, a1 in ((top, E, -274), (bot, -94, E + 180)):
    lo, hi = min(a0, a1), max(a0, a1)
    for k in range(0, 361):
        a = lo + (hi - lo) * k / 360
        for R in (r + hw, r - hw): pts.append(pt(cy, R, a))
for B, dd in ((B1, d), (B2, (-d[0], -d[1]))):
    nn = (-dd[1], dd[0])
    pts += [(B[0] + 112 * nn[0], B[1] + 112 * nn[1]), (B[0] - 112 * nn[0], B[1] - 112 * nn[1]), (B[0] + 150 * dd[0], B[1] + 150 * dd[1])]
x0, x1 = min(p[0] for p in pts), max(p[0] for p in pts)
y0, y1 = min(p[1] for p in pts), max(p[1] for p in pts)
open(sys.argv[1], "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{x1 - x0:.0f}" height="{y1 - y0:.0f}" viewBox="{x0:.1f} {y0:.1f} {x1 - x0:.1f} {y1 - y0:.1f}">{body}</svg>')
PY
rsvg-convert -f pdf -o Resources/MenuBarIcon.pdf "$TMP/s.svg"
rm -rf "$TMP"
echo "Wrote Resources/MenuBarIcon.pdf"
