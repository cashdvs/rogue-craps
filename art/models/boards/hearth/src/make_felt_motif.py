"""Hearth felt overlay: a faint ember motif in each felt corner, nothing else (no rules text).

Writes art/models/boards/hearth/textures/felt_ember_corners.png (1024 x 512 RGBA, the felt bed's
0-1 UV, 2.04 x 1.04 m). Straight-alpha RGBA, drawn by toon_noir's overlay
(hearth_felt.tres, overlay_tint.a = 1): an edge lift (lighter teal, ramping up toward the edges and
corners) under the Ember motifs. Each corner: a three-tongue flame crown
(hooked tips, odd count, tallest in the centre: fire_style.md) pointing into the felt along the
diagonal, two diamond sparks, and a thin quarter-arc rule. Kept within ~0.2 m of the corner so dice
never sit on a busy pattern. Run: python3 art/models/boards/hearth/src/make_felt_motif.py

Detail pass (Art Director, Oct 19): also writes textures/felt_ember_corners_worn.png = the same overlay
with low-contrast wear under the motif (hearth_felt_worn.tres, the dressing-on felt): a faint scuffed
arc round the far side of the landing area (the centre stays clean), 2 broad broken scorch rings in front of the
backboard under the brazier, two cigarette-burn pocks on the right half and one old wax drip stain by
the right rail, all clear of the combo-table strips and the landing centre. Felt-toned only (darker / lighter teal and burnt brown, never bone), no round pip-sized
dots, every mark within a 15 % value shift of the felt under it (printed and checked by the test).
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "textures", "felt_ember_corners.png"))
OUT_WORN = os.path.normpath(os.path.join(HERE, "..", "textures", "felt_ember_corners_worn.png"))
FELT = (18, 58, 54)        # Underfelt #123A36 (Board A felt albedo)
SCUFF = (40, 86, 80)       # rubbed nap: a touch lighter, greyer
BURN = (20, 22, 18)        # scorched felt: near-black brown-green
WAX = (34, 74, 68)         # old wax: dulls and lifts the nap a little (not bone)
MAX_SHIFT = 0.15
W, H = 1024, 512
SS = 4                      # supersampling
PX_PER_M = W / 2.04         # 502 px per metre (same in V: 512 / 1.04 = 492)
EMBER = (232, 98, 42)
LIFT = (38, 104, 94)       # lighter Underfelt, the edge lift colour
EDGE_A = 0.75             # edge lift strength at the felt edge
MOTIF_A = 0.5             # ember motif strength (the material draws the texture at full strength)


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
    # Edge lift (Art Director, Oct 18): a lighter felt teal toward the edges and corners, so a die
    # in the lamp's vignette never sits on near-black. Straight alpha ramps 0 -> EDGE_A from an
    # inner rounded rectangle out to the felt edge (strongest in the corners).
    import numpy as np
    u = (np.arange(W) + 0.5) / W * 2.0 - 1.0
    v = (np.arange(H) + 0.5) / H * 2.0 - 1.0
    U, V = np.meshgrid(u, v)
    dx = np.clip((np.abs(U) - 0.55) / 0.45, 0, 1)
    dy = np.clip((np.abs(V) - 0.35) / 0.65, 0, 1)
    ramp = np.clip(np.sqrt(dx * dx + dy * dy), 0, 1) ** 1.3
    edge = Image.new("RGBA", (W, H), LIFT + (0,))
    edge.putalpha(Image.fromarray((ramp * EDGE_A * 255).astype("uint8"), "L"))
    motif = Image.new("RGBA", (W, H), EMBER + (0,))
    motif.putalpha(a.point(lambda x: int(x * MOTIF_A)))
    img = Image.alpha_composite(edge, motif)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print("wrote", OUT)
    worn = Image.alpha_composite(Image.alpha_composite(edge, wear_layer(np)), motif)
    worn.save(OUT_WORN)
    print("wrote", OUT_WORN)
    print("WEAR max value shift %.3f (limit %.2f)" % (value_shift(np, edge, worn), MAX_SHIFT))


def felt_px(x, z):
    """board metres -> overlay pixel (u = (x + 1.02) / 2.04, v = (0.52 - z) / 1.04: row 0 = the near edge)."""
    return ((x + 1.02) / 2.04 * W, (0.52 - z) / 1.04 * H)


def wear_layer(np):
    """Straight-alpha RGBA wear marks (composited between the edge lift and the motif)."""
    import random
    rng = random.Random(19)
    S = SS
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    def stamp(color, mask, alpha):
        m = mask.resize((W, H), Image.LANCZOS).point(lambda v: int(v * alpha))
        c = Image.new("RGBA", (W, H), color + (0,))
        c.putalpha(m)
        return Image.alpha_composite(layer, c)

    # 1. scuffed arc: streaky rubbed nap along an arc round the far side of the landing area (radius
    #    0.42 m round (0, -0.05)), fading at both ends; the centre of the arc (the landing spot) is clean.
    m = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(m)
    for k in range(70):
        a0 = math.radians(rng.uniform(198, 330))
        span = math.radians(rng.uniform(6, 22))
        r = rng.uniform(0.38, 0.47)
        pts = []
        for j in range(12):
            a = a0 + span * j / 11
            x, y = felt_px(math.cos(a) * r * 1.35, -0.05 + math.sin(a) * r)
            pts.append((x * S, y * S))
        fade = math.sin(math.pi * (math.degrees(a0) - 198) / 132) ** 0.7
        d.line(pts, fill=int(255 * fade * rng.uniform(0.4, 1.0)), width=int(rng.uniform(0.003, 0.009) * PX_PER_M * S))
    m = m.filter(ImageFilter.GaussianBlur(2 * S))
    layer = stamp(SCUFF, m, 0.17)
    # 2. scorch rings: two broad, broken heat rings (11 cm across, open arcs, soft wide stroke) where the
    #    brazier pot has stood, in front of the backboard behind the burn line: larger than a die face and
    #    never closed, so nothing on the felt reads as a pip (Oct 19 render check: small rings read as dots).
    m = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(m)
    for (x, z, r, arcs) in ((-0.04, -0.462, 0.054, ((200, 330), (20, 115))), (0.035, -0.47, 0.048, ((280, 410), (95, 165)))):
        cx, cy = felt_px(x, z)
        R = r * PX_PER_M * S
        for (a0, a1) in arcs:
            d.arc([cx * S - R, cy * S - R * 0.9, cx * S + R, cy * S + R * 0.9], a0, a1, fill=255, width=int(0.009 * PX_PER_M * S))
    m = m.filter(ImageFilter.GaussianBlur(3.0 * S))
    layer = stamp(BURN, m, 0.15)
    # 3. cigarette-burn pocks: elongated, ragged (never round dots), near-right and far-right, clear of the
    #    combo-table strips (landscape: the near edge; portrait: the left edge; art/ui/readability/felt)
    m = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(m)
    for (x, z, ang, ln) in ((0.62, 0.27, 0.5, 0.022), (0.78, -0.3, -0.4, 0.019)):
        cx, cy = felt_px(x, z)
        pts = []
        for j in range(14):
            t = 2 * math.pi * j / 14
            rr = (ln if abs(math.cos(t)) > 0.5 else ln * 0.32) * rng.uniform(0.75, 1.05) * PX_PER_M * S * 0.5
            u, v = math.cos(t) * rr * (1.0 if math.cos(t) > 0 else 0.55), math.sin(t) * rr * 0.55
            pts.append((cx * S + u * math.cos(ang) - v * math.sin(ang), cy * S + u * math.sin(ang) + v * math.cos(ang)))
        d.polygon(pts, fill=255)
    m = m.filter(ImageFilter.GaussianBlur(0.9 * S))
    layer = stamp(BURN, m, 0.18)
    # 4. one old wax drip stain by the right rail under the far-right near candle (z -0.24): a splash with a
    #    run, no satellite dots (v2: moved off the left edge, where the portrait combo strip sits)
    m = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(m)
    cx, cy = felt_px(0.93, -0.2)
    pts = []
    for j in range(18):
        t = 2 * math.pi * j / 18
        rr = 0.018 * (1.0 + 0.35 * math.sin(3 * t + 0.4) + 0.2 * math.sin(5 * t)) * PX_PER_M * S
        pts.append((cx * S + math.cos(t) * rr * 1.25, cy * S + math.sin(t) * rr))
    d.polygon(pts, fill=255)
    tx, ty = felt_px(0.86, -0.17)
    d.line([(cx * S, cy * S), (tx * S, ty * S)], fill=255, width=int(0.008 * PX_PER_M * S))
    m = m.filter(ImageFilter.GaussianBlur(1.4 * S))
    layer = stamp(WAX, m, 0.28)
    return layer


def value_shift(np, base, worn):
    """Largest relative HSV-value change of the felt albedo (#123A36 under each overlay) caused by the wear."""
    def albedo(img):
        a = np.asarray(img, dtype=np.float32) / 255.0
        felt = np.array(FELT, dtype=np.float32) / 255.0
        return felt * (1 - a[..., 3:4]) + a[..., :3] * a[..., 3:4]
    b = albedo(base).max(axis=2)
    w = albedo(Image.alpha_composite(base, wear_layer(np))).max(axis=2)
    return float(np.max(np.abs(w - b) / np.maximum(b, 1e-3)))


main()
