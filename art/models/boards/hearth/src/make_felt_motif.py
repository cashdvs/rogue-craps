"""Hearth felt overlay: a faint ember motif in each felt corner, nothing else (no rules text).

Writes art/models/boards/hearth/textures/felt_ember_corners.png (1024 x 512 RGBA, the felt bed's
0-1 UV, 2.04 x 1.04 m). RGB = Ember #E8622A everywhere, alpha = the ink; hearth_felt.tres draws it
with toon_noir's overlay (overlay_tint.a sets the strength). Each corner: a three-tongue flame crown
(hooked tips, odd count, tallest in the centre: fire_style.md) pointing into the felt along the
diagonal, two diamond sparks, and a thin quarter-arc rule. Kept within ~0.2 m of the corner so dice
never sit on a busy pattern. Run: python3 art/models/boards/hearth/src/make_felt_motif.py
"""
import math
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "textures", "felt_ember_corners.png"))
W, H = 1024, 512
SS = 4                      # supersampling
PX_PER_M = W / 2.04         # 502 px per metre (same in V: 512 / 1.04 = 492)
EMBER = (232, 98, 42)


def tongue(cx, cy, h, w, lean, hook):
    """Teardrop tongue: fat round base, sharp tip that leans and hooks. Polygon in pixels, tip up (-y)."""
    n = 24
    left, right = [], []
    for k in range(n + 1):
        t = k / n
        hw = w * min(1.0, 2.6 * math.sqrt(t + 1e-4)) * (1 - t) ** 1.25
        xc = lean * h * t * t + hook * h * 0.16 * t ** 5
        y = cy + w * 0.35 - t * (h + w * 0.35)
        left.append((cx + xc - hw, y))
        right.append((cx + xc + hw, y))
    return left + right[::-1]


def rot(pts, cx, cy, ang):
    c, s = math.cos(ang), math.sin(ang)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for (x, y) in pts]


def diamond(cx, cy, r):
    return [(cx, cy - r), (cx + r * 0.55, cy), (cx, cy + r), (cx - r * 0.55, cy)]


def corner(draw, ox, oy, sx, sy):
    """Motif for the corner at pixel (ox, oy); sx, sy = +-1 point into the felt."""
    m = PX_PER_M * SS
    base = (ox + sx * 0.12 * m, oy + sy * 0.12 * m)
    # pointing into the felt along the diagonal: rotate "up" (-y) onto (sx, sy)
    ang = math.atan2(sy, sx) + math.pi / 2
    for (dx, h, w, lean, hook, a) in ((-0.03, 0.075, 0.015, -0.12, -1.0, 0.0), (0.0, 0.11, 0.019, 0.06, 1.0, 0.0),
                                      (0.03, 0.08, 0.015, 0.14, 1.0, 0.0)):
        px = base[0] + dx * m
        poly = tongue(px, base[1], h * m, w * m, lean, hook)
        poly = rot(poly, base[0], base[1], ang)
        draw.polygon(poly, fill=255)
        # inner cut-out band so the motif reads drawn (outline + fill), like the flame cards
        inner = tongue(px, base[1] - 0.004 * m, h * m * 0.55, w * m * 0.45, lean, hook)
        draw.polygon(rot(inner, base[0], base[1], ang), fill=110)
    for (d, r) in ((0.33, 0.013), (0.385, 0.009)):
        c = (ox + sx * d * m * 0.72, oy + sy * d * m * 0.72)
        draw.polygon(diamond(c[0], c[1], r * m), fill=255)
    # quarter-arc rule around the corner
    R = 0.3 * m
    box = [ox - R, oy - R, ox + R, oy + R]
    a0 = {(1, 1): 0, (-1, 1): 90, (-1, -1): 180, (1, -1): 270}[(sx, sy)]
    draw.arc(box, a0 + 6, a0 + 84, fill=200, width=int(0.006 * m))


def main():
    a = Image.new("L", (W * SS, H * SS), 0)
    d = ImageDraw.Draw(a)
    for (ox, oy, sx, sy) in ((0, 0, 1, 1), (W * SS, 0, -1, 1), (0, H * SS, 1, -1), (W * SS, H * SS, -1, -1)):
        corner(d, ox, oy, sx, sy)
    a = a.resize((W, H), Image.LANCZOS)
    img = Image.new("RGBA", (W, H), EMBER + (0,))
    img.putalpha(a)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print("wrote", OUT)


main()
