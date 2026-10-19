"""Procedural "hand-drawn" flame flipbook for the toon fire (art/concept/fire/fire_style.md).

Writes (art/models/boards/hearth/textures/ (copied from the paused toon fire WIP, art/toon-fire-vfx fd42d78, so the board does not depend on the dice fire)):
  flame_tongue_4x4.png         2048 px, 4x4 frames of 512 px (PC)
  flame_tongue_4x4_mobile.png  1024 px, 4x4 frames of 256 px (mobile)
  smoke_curl.png               256 px, one outlined charcoal curl (tier 4 cap, bust wisp)

Each frame is ONE flame tongue: a teardrop that is fat at the base, with a sharp hooked tip that
leans and flicks sideways, plus an occasional side lick. The 16 frames are one 1.33 s loop at
12 fps (on twos). Channels are signed distance fields (0.5 = the edge, +inside, spread SDF_SPREAD
px at 512), so the shader cuts hard, resolution-independent band edges and a constant ~2 px outline:
  R = outer silhouette (Hellfire band + the oxblood outline outside it)
  G = mid shape (Ember)
  B = core shape (Butter, the only band that blooms)
Run: python3 art/models/boards/hearth/src/make_flame_atlas.py   (numpy + Pillow; deterministic)
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "textures"))
F = 512            # frame size (PC)
GRID = 4
SDF_SPREAD = 48.0  # px at 512 per frame


def _seg_dist(px, py, poly):
    """Unsigned distance from every pixel to the closed polygon's edges (numpy)."""
    d = np.full(px.shape, 1e9, dtype=np.float32)
    n = len(poly)
    for i in range(n):
        ax, ay = poly[i]
        bx, by = poly[(i + 1) % n]
        dx, dy = bx - ax, by - ay
        l2 = dx * dx + dy * dy
        if l2 < 1e-9:
            continue
        t = np.clip(((px - ax) * dx + (py - ay) * dy) / l2, 0.0, 1.0)
        qx = ax + t * dx - px
        qy = ay + t * dy - py
        d = np.minimum(d, qx * qx + qy * qy)
    return np.sqrt(d)


def _sdf(polys, size):
    """SDF of the union of polygons (inner edges between overlapping polygons are dropped)."""
    mask_img = Image.new("L", (size, size), 0)
    dr = ImageDraw.Draw(mask_img)
    for p in polys:
        dr.polygon([tuple(v) for v in p], fill=255)
    mask = np.asarray(mask_img) > 127
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32) + 0.5
    d = np.full((size, size), 1e9, dtype=np.float32)
    for k, p in enumerate(polys):
        # Keep only the edge segments that are on the union's outline.
        others = [q for j, q in enumerate(polys) if j != k]
        keep = []
        for i in range(len(p)):
            a, b = p[i], p[(i + 1) % len(p)]
            mx, my = (a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5
            inside = False
            for q in others:
                if _point_in(mx, my, q):
                    inside = True
                    break
            keep.append(not inside)
        # Distance to kept segments only.
        segs = [(p[i], p[(i + 1) % len(p)]) for i in range(len(p)) if keep[i]]
        for (a, b) in segs:
            dx, dy = b[0] - a[0], b[1] - a[1]
            l2 = dx * dx + dy * dy
            if l2 < 1e-9:
                continue
            t = np.clip(((xs - a[0]) * dx + (ys - a[1]) * dy) / l2, 0.0, 1.0)
            qx = a[0] + t * dx - xs
            qy = a[1] + t * dy - ys
            d = np.minimum(d, qx * qx + qy * qy)
    d = np.sqrt(d)
    return np.where(mask, d, -d)


def _point_in(x, y, poly):
    c = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi:
            c = not c
        j = i
    return c


def tongue(cx, base, H, R, lean, hook, wave, phase, wob, n=64):
    """Polygon of one tongue in image coords (y down). base = bottom y, H = height, R = base radius."""
    tb = 0.24
    spine = []
    for i in range(n + 1):
        t = i / n
        y = base - t * H
        x = cx + lean * H * t ** 1.5 + wave * H * 0.05 * math.sin(math.pi * 1.6 * t + phase) * t
        if t > 0.6:  # the hook: the tip curls hard to one side and tips over a little
            h = (t - 0.6) / 0.4
            x += hook * H * h ** 2.2
            y += hook * H * 0.35 * h ** 3.0
        spine.append((x, y))
    left, right = [], []
    for i, (x, y) in enumerate(spine):
        t = i / n
        if t < tb:
            w = R * math.sqrt(max(0.0, 1.0 - ((tb - t) / tb) ** 2))
        else:
            w = R * (1.0 - (t - tb) / (1.0 - tb)) ** 1.3
        x0, y0 = spine[max(i - 1, 0)]
        x1, y1 = spine[min(i + 1, n)]
        tx, ty = x1 - x0, y1 - y0
        ln = math.hypot(tx, ty) or 1.0
        nx, ny = -ty / ln, tx / ln
        wl = w * (1.0 + wob * math.sin(t * 9.0 + phase))
        wr = w * (1.0 + wob * math.sin(t * 7.0 - phase * 1.3 + 1.0))
        left.append((x + nx * wl, y + ny * wl))
        right.append((x - nx * wr, y - ny * wr))
    return left + right[::-1]


def side_lick(cx, base, H, R, side, s, phase):
    """A small licking tongue off one flank (s = 0..1 size)."""
    s = 0.6 + 0.4 * s
    sx = cx + side * R * 0.5
    return tongue(sx, base - H * 0.08, H * 0.5 * s, R * 0.5 * s, side * 0.34, side * 0.2, 0.5, phase, 0.05, n=32)


def frame_polys(i, size):
    k = size / 512.0
    p = 2.0 * math.pi * i / 16.0
    cx = size * 0.44
    base = size - 58 * k
    H = size * 0.8 * (0.92 + 0.07 * math.sin(2 * p + 0.7))
    R = size * 0.175 * (1.0 + 0.05 * math.sin(2 * p + 2.0))
    lean = 0.09 * math.sin(p)
    hook = 0.17 + 0.07 * math.sin(p + 1.3)
    wave = math.sin(2 * p)
    lick = max(0.0, math.sin(p * 2 + 0.4))
    side = -1 if (i // 4) % 2 == 0 else 1
    outer = [tongue(cx, base, H, R, lean, hook, wave, p, 0.07)]
    mid = [tongue(cx + R * 0.02, base - H * 0.05, H * 0.84, R * 0.72, lean * 1.1, hook * 1.05, wave, p + 0.6, 0.09)]
    core = [tongue(cx + R * 0.04, base - H * 0.07, H * 0.58, R * 0.48, lean * 0.7 - 0.03, hook * 0.9, wave * 0.8, p + 1.1, 0.06, n=40)]
    if lick > 0.4:
        outer.append(side_lick(cx, base, H, R, side, lick, p))
        mid.append(side_lick(cx, base - H * 0.03, H * 0.8, R * 0.62, side, lick * 0.8, p))
    return outer, mid, core


def enc(sdf, spread):
    return np.clip(0.5 + sdf / (2.0 * spread), 0.0, 1.0)


def make_atlas(size_frame):
    k = size_frame / 512.0
    atlas = np.zeros((size_frame * GRID, size_frame * GRID, 4), dtype=np.uint8)
    for i in range(16):
        outer, mid, core = frame_polys(i, size_frame)
        r = enc(_sdf(outer, size_frame), SDF_SPREAD * k)
        g = enc(_sdf(mid, size_frame), SDF_SPREAD * k)
        b = enc(_sdf(core, size_frame), SDF_SPREAD * k)
        fx, fy = i % GRID, i // GRID
        tile = np.stack([r, g, b, np.ones_like(r)], axis=-1)
        atlas[fy * size_frame:(fy + 1) * size_frame, fx * size_frame:(fx + 1) * size_frame] = (tile * 255 + 0.5).astype(np.uint8)
    return Image.fromarray(atlas, "RGBA")


def smoke_curl(size=256):
    """One curl: a short rising tail that rolls into a spiral (stroke SDF)."""
    pts = []
    cx, cy = size * 0.55, size * 0.36
    for i in range(90):
        th = i / 89.0 * 1.6 * math.pi
        r = size * 0.2 * (1.0 - th / (2.2 * math.pi))
        a = -math.pi * 0.5 - th  # starts below the centre, winds up and over (clockwise on screen)
        pts.append((cx + r * math.cos(a), cy - r * math.sin(a)))
    sx, sy = pts[0]
    tail = [(sx - size * 0.07 * math.sin(t * math.pi), sy + t * size * 0.36) for t in np.linspace(1, 0, 20, endpoint=False)]
    line = tail + pts
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32) + 0.5
    d = np.full((size, size), 1e9, dtype=np.float32)
    thick = np.zeros((size, size), dtype=np.float32)
    nseg = len(line) - 1
    for i in range(nseg):
        a, b = line[i], line[i + 1]
        dx, dy = b[0] - a[0], b[1] - a[1]
        l2 = dx * dx + dy * dy + 1e-9
        t = np.clip(((xs - a[0]) * dx + (ys - a[1]) * dy) / l2, 0.0, 1.0)
        qx = a[0] + t * dx - xs
        qy = a[1] + t * dy - ys
        dd = np.sqrt(qx * qx + qy * qy)
        u = (i + t) / nseg
        w = size * (0.075 * (1.0 - u) + 0.03 * u + 0.02 * np.sin(u * math.pi))
        better = (dd - w) < d
        d = np.where(better, dd - w, d)
    spread = SDF_SPREAD * size / 512.0
    r = enc(-d, spread)
    g = enc(-(d + size * 0.03), spread)  # inner highlight band
    img = np.stack([r, g, np.zeros_like(r), np.ones_like(r)], axis=-1)
    return Image.fromarray((img * 255 + 0.5).astype(np.uint8), "RGBA")


def main():
    os.makedirs(OUT, exist_ok=True)
    pc = make_atlas(512)
    pc.save(os.path.join(OUT, "flame_tongue_4x4.png"), optimize=True)
    make_atlas(256).save(os.path.join(OUT, "flame_tongue_4x4_mobile.png"), optimize=True)
    smoke_curl().save(os.path.join(OUT, "smoke_curl.png"), optimize=True)
    print("atlas written to", OUT)


if __name__ == "__main__":
    main()
