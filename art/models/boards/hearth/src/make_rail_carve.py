"""Hearth rail carving (detail pass, Art Director Oct 19): one tile of carved relief for the rail leather.

Writes art/models/boards/hearth/textures/rail_carve.png (256 x 512 RGBA, LINEAR data, not colour):
RGB = tangent-space normal (OpenGL / Godot convention), A = cavity (1 = deepest groove), sampled by
shaders/hearth_toon_detail.gdshader on the Board A rail mesh (no new geometry, no new silhouettes).

Rail UVs (Board A rails.glb / rails_mobile.glb): U runs round the perimeter, 2 U per metre (13.451 total),
V runs round the tube cross-section, 0 = 1 = the tube top, V up = toward the felt (0.125 = the ember seam
on the inner lip), V down = the outer shoulder. The tile spans 13.451 / 22 = 0.6114 U (0.306 m), so 22
tiles close seamlessly round the table, and the whole V range (0.565 m of tube).

Pattern, per tile (v2, AD Oct 19: "put the carving where the camera looks"): hooked flame-tongue
scrollwork along the TOP face (a running stem just outboard of the crest, alternating hooked tongues, odd
groups, tallest in the middle: fire_style.md) whose down-tongues run between the brass studs; one grinning
imp face (~3.2 cm) on the FRONT (outer) face below the stud row, upright as seen from outside the table,
flanked by two small curls; two incised border grooves (felt side of the crest, outer equator). Deeper
relief than v1, and B = a brass edge mask (a thin rim inside every raised form) that the shader turns into a
brass highlight. The shader fades the carving out on the far rail (Smiles' side; carve_skip_u).
RGBA = R,G tangent normal (Godot rebuilds Z), B brass edge mask, A cavity.
Run: python3 art/models/boards/hearth/src/make_rail_carve.py
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "textures", "rail_carve.png"))
W, H = 256, 512
SS = 4
TILE_U = 13.451 / 22.0          # UV period along the rail
TILE_M = TILE_U * 0.5           # 0.3057 m
CIRC = 2 * math.pi * 0.09       # 0.5655 m of tube = V 0..1
RELIEF = 0.0024                 # carving depth (m) for the normals (v2: deeper)
# band edges (metres of arc from the tube top; + = toward the felt / inner lip, - = outer shoulder)
SEAM_LO = 0.125 * CIRC - 0.012 * CIRC   # the ember seam starts at w 0.064
GROOVE_IN = 0.032               # felt side of the crest (the ember seam starts at w 0.064)
GROOVE_OUT = -0.132             # just above the outer equator (w -0.141)
FACE_W = -0.097                 # imp face centre (front face, below the stud row at w -0.053)
FACE_K = 1.35                   # imp face scale vs v1
STEM_W = -0.012                 # scroll stem line (top face, just outboard of the crest)
TONGUE_K = 0.78                 # tongue height scale (the down-tongues end between the studs)


def px(u_m, w_m):
    """metres (along the rail from the tile start, arc from the tube top) -> supersampled canvas px.
    The canvas is 3 tiles wide (wrap) and runs w from -CIRC/2 (row 0) to +CIRC/2."""
    x = (u_m + TILE_M) / (3 * TILE_M) * (3 * W * SS)
    y = (w_m + CIRC / 2) / CIRC * (H * SS)
    return (x, y)


def tongue(cu, cw, h, wd, lean, hook, up):
    """Hooked flame tongue in (u, w) metres; up = +1 grows toward +w, -1 toward -w."""
    n = 18
    left, right = [], []
    for k in range(n + 1):
        t = k / n
        hw = wd * min(1.0, 2.6 * math.sqrt(t + 1e-4)) * (1 - t) ** 1.25
        xc = lean * h * t * t + hook * h * 0.2 * t ** 4
        w = cw + up * t * h
        left.append(px(cu + xc - hw, w))
        right.append(px(cu + xc + hw, w))
    return left + right[::-1]


def draw_tile(d, du):
    """Everything for one tile, offset by du metres (drawn at -1, 0, +1 tiles for the wrap)."""
    L = TILE_M
    # border grooves (drawn as depressions later: separate canvas)
    # scroll stem: a gentle running wave
    pts = []
    for k in range(65):
        u = -0.02 + (L + 0.04) * k / 64
        pts.append(px(u + du, STEM_W + 0.006 * math.sin(2 * math.pi * u / (L / 2))))
    d["stem"].line(pts, fill=255, width=int(0.0042 * 837 * SS))
    # tongues: 2 groups of 3 per tile (odd, tallest in the middle), alternating up / down, hooked
    for g in range(2):
        cu = L * (0.25 + 0.5 * g) + du
        up = 1 if g == 0 else -1
        base = STEM_W + 0.006 * math.sin(2 * math.pi * (cu - du) / (L / 2))
        for (dx, h, wd, lean, hook) in ((-0.026, 0.034, 0.0085, -0.3, -1.0), (0.0, 0.05, 0.011, 0.08, 1.0), (0.026, 0.036, 0.0085, 0.32, 1.0)):
            h *= TONGUE_K
            d["tongue"].polygon(tongue(cu + dx, base, h, wd, lean, hook, up), fill=255)
            d["inner"].polygon(tongue(cu + dx, base + up * 0.004, h * 0.55, wd * 0.42, lean, hook, up), fill=255)
        # a small hooked curl (the scroll) between groups
        cc = cu + L * 0.25
        r = 0.0095
        box = [px(cc - r, base - r * 1.05), px(cc + r, base + r * 1.05)]
        d["curl"].arc([box[0][0], box[0][1], box[1][0], box[1][1]], 30 if up > 0 else 210, 300 if up > 0 else 120, fill=255,
                      width=int(0.0036 * 837 * SS))
    # the imp face at the tile centre, on the front face, upright toward +w (the tube top, seen from outside)
    fu = L * 0.5 + du
    fw = FACE_W
    k = FACE_K
    sg = -1.0   # v1 drew it upright toward -w; flip

    def P(u, dw):
        return px(fu + u * k, fw + sg * dw * k)

    rx, ry = 0.0118 * k, 0.011 * k
    d["face"].ellipse([*px(fu - rx, fw - ry), *px(fu + rx, fw + ry)], fill=255)
    for sx in (-1, 1):   # horns: hooked, pointing up and out
        horn = tongue(fu + sx * 0.0085 * k, fw + sg * 0.004 * k, 0.0105 * k, 0.0034 * k, 0.55 * sx, sx * 1.0, -sg)
        d["face"].polygon(horn, fill=255)
    for sx in (-1, 1):   # eyes: slanted slits
        cx, cy = sx * 0.0042, -0.0022
        poly = [P(cx - 0.0028 * sx, cy + 0.0006), P(cx + 0.0028 * sx, cy - 0.0013), P(cx + 0.0005 * sx, cy + 0.0012)]
        d["cut"].polygon(poly, fill=255)
    grin = []
    for j in range(13):
        a_ = math.pi * j / 12
        grin.append(P(-0.0068 * math.cos(a_), 0.0028 + 0.0036 * math.sin(a_)))
    for j in range(12, -1, -1):
        a_ = math.pi * j / 12
        grin.append(P(-0.0055 * math.cos(a_), 0.0028 + 0.0012 * math.sin(a_)))
    d["cut"].polygon(grin, fill=255)
    for sx in (-1, 0, 1):   # teeth: little raised wedges left in the grin
        cx = sx * 0.0026
        d["teeth"].polygon([P(cx - 0.0008, 0.0033), P(cx + 0.0008, 0.0033), P(cx, 0.0052)], fill=255)
    # two small curls flanking the face on the front face
    for sx in (-1, 1):
        cc = fu + sx * 0.075
        r = 0.009
        box = [px(cc - r, fw - r), px(cc + r, fw + r)]
        d["curl"].arc([box[0][0], box[0][1], box[1][0], box[1][1]], 200 if sx < 0 else 340, 120 if sx < 0 else 260, fill=255,
                      width=int(0.0036 * 837 * SS))


def main():
    cw, ch = 3 * W * SS, H * SS
    layers = {k: Image.new("L", (cw, ch), 0) for k in ("stem", "tongue", "inner", "curl", "face", "cut", "teeth", "groove")}
    d = {k: ImageDraw.Draw(v) for k, v in layers.items()}
    for du in (-TILE_M, 0.0, TILE_M):
        draw_tile(d, du)
    for wv in (GROOVE_IN, GROOVE_OUT):
        y = px(0, wv)[1]
        d["groove"].line([(0, y), (cw, y)], fill=255, width=int(0.0016 * 905 * SS))

    def arr(k, blur):
        im = layers[k].crop((W * SS, 0, 2 * W * SS, ch)).resize((W, H), Image.LANCZOS)
        if blur:
            im = im.filter(ImageFilter.GaussianBlur(blur))
        return np.asarray(im, dtype=np.float32) / 255.0

    stem, tng, inner, curl = arr("stem", 0.6), arr("tongue", 0.6), arr("inner", 0.5), arr("curl", 0.5)
    face, cut, teeth, groove = arr("face", 0.9), arr("cut", 0.4), arr("teeth", 0.3), arr("groove", 0.5)
    # height: raised scroll and face; tongue centres cut back in (reads drawn: outline + fill), grooves cut
    h = np.maximum.reduce([stem * 0.75, tng * (1.0 - 0.45 * inner), curl * 0.7, face * 1.0])
    h = h * (1.0 - 0.85 * cut) + teeth * cut * 0.8
    h = h - groove * 0.9
    # face dome: a soft bulge on top of the face disc
    dome = np.asarray(layers["face"].crop((W * SS, 0, 2 * W * SS, ch)).resize((W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(5)), dtype=np.float32) / 255.0
    h = h + 0.35 * dome * (1.0 - cut)
    # roll rows so row 0 = V 0 (the tube top) instead of w = -CIRC/2
    h = np.roll(h, -H // 2, axis=0)
    groove_r = np.roll(groove, -H // 2, axis=0)
    cut_r = np.roll(cut, -H // 2, axis=0)
    # normals from the height field (periodic in both axes)
    du_m = TILE_M / W
    dv_m = CIRC / H
    z = h * RELIEF
    dzdu = (np.roll(z, -1, axis=1) - np.roll(z, 1, axis=1)) / (2 * du_m)
    dzdv = (np.roll(z, -1, axis=0) - np.roll(z, 1, axis=0)) / (2 * dv_m)
    # tangent space: +X = +U, +Y = -V (image rows grow with V, OpenGL normal maps have green = up = -row)
    n = np.dstack([-dzdu, dzdv, np.ones_like(z)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    # cavity: where the surface sits below its neighbourhood (and the cut-in grooves / eyes / grin)
    blur = np.asarray(Image.fromarray(np.clip(h * 255, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3)), dtype=np.float32) / 255.0
    cav = np.clip((blur - h) * 2.2, 0, 1)
    cav = np.maximum(cav, np.maximum(groove_r * 0.85, cut_r * 0.8 * (np.roll(face, -H // 2, axis=0) > 0.3)))
    # brass edge mask: a thin (~2 px) rim just inside every raised form (the edges that catch the lamp)
    raised = Image.fromarray(((h > 0.42) * 255).astype(np.uint8))
    inner_r = raised.filter(ImageFilter.MinFilter(5))
    edge = (np.asarray(raised, dtype=np.float32) - np.asarray(inner_r, dtype=np.float32)) / 255.0
    edge = np.asarray(Image.fromarray((edge * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.5)), dtype=np.float32) / 255.0
    rgba = np.dstack([(n[..., 0] + 1) * 0.5, (n[..., 1] + 1) * 0.5, edge, cav]) * 255.0
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray(np.clip(rgba + 0.5, 0, 255).astype(np.uint8), "RGBA").save(OUT)
    # preview (not shipped): height + cavity
    print("wrote", OUT, "relief %.1f mm, tile %.4f U" % (RELIEF * 1000, TILE_U))


main()
