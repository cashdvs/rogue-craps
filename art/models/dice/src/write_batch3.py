"""Batch-3 special dice: paints the face textures (textures/<die>_faces.png: numerals, pips, veins, engraving; alpha =
ink over the body colour), writes the toon materials (materials/<slot>.tres, `use_overlay` on the textured slots) and,
with --imports, maps each .glb's slots onto them in its .glb.import and sets the texture imports (mipmaps on,
lossless). Needs the layout from build_batch3.py (src/batch3_layout.json) and Pillow.
    python3 art/models/dice/src/write_batch3.py [--imports]
Numerals use Alfa Slab One (fonts/, SIL OFL 1.1), rasterised into the textures (artwork, not a shipped font)."""
import json
import math
import os
import random
import re
import sys

from PIL import Image, ImageDraw, ImageFont

SRC = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(SRC, ".."))
REPO = os.path.abspath(os.path.join(ROOT, "..", "..", ".."))
sys.path.insert(0, SRC)
from write_batch2 import col, lamp_comp  # noqa: E402

FONT = os.path.join(REPO, "fonts", "AlfaSlabOne-Regular.ttf")
SS = 2  # supersample
ATLAS = 1024
CELL = ATLAS / 5
TOON = "res://shaders/3d/toon_noir.gdshader"
INK = "res://art/models/dice/materials/die_ink_outline.tres"
INK_THIN = "res://art/models/dice/materials/batch3_ink_thin.tres"


def rgba(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def P(p):
    return (p[0] * SS, p[1] * SS)


def cell_box(cell):
    x, y = (cell % 5) * CELL, (cell // 5) * CELL
    return [x * SS, y * SS, (x + CELL) * SS, (y + CELL) * SS]


def inradius(poly, c):
    best = 1e9
    for a, b in zip(poly, poly[1:] + poly[:1]):
        ax, ay, bx, by = a[0] - c[0], a[1] - c[1], b[0] - c[0], b[1] - c[1]
        ex, ey = bx - ax, by - ay
        t = max(0.0, min(1.0, -(ax * ex + ay * ey) / (ex * ex + ey * ey)))
        best = min(best, math.hypot(ax + ex * t, ay + ey * t))
    return best


def label(d, c, text, h, fill, stroke=None, sw=0, max_w=None):
    bar = text.endswith(".")
    text = text.rstrip(".")
    size = int(h * SS * 1.35)
    f = ImageFont.truetype(FONT, size)
    w = d.textlength(text, font=f)
    if max_w and w > max_w * SS:
        size = int(size * max_w * SS / w)
        f = ImageFont.truetype(FONT, size)
    d.text(P(c), text, font=f, fill=fill, anchor="mm", stroke_width=sw * SS, stroke_fill=stroke)
    if bar:  # 6. / 9.: an underline so they can't flip
        bb = d.textbbox(P(c), text, font=f, anchor="mm")
        y = bb[3] + 3 * SS
        d.rectangle([bb[0] + 2 * SS, y, bb[2] - 2 * SS, y + max(3, size // 12)], fill=fill, outline=stroke, width=SS if stroke else 0)


def pip(d, c, r, fill, ring=None, ring_w=0.25):
    if ring:
        rr = r * (1 + ring_w)
        d.ellipse([(c[0] - rr) * SS, (c[1] - rr) * SS, (c[0] + rr) * SS, (c[1] + rr) * SS], fill=ring)
    d.ellipse([(c[0] - r) * SS, (c[1] - r) * SS, (c[0] + r) * SS, (c[1] + r) * SS], fill=fill)


def new():
    img = Image.new("RGBA", (ATLAS * SS, ATLAS * SS), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def fill_cell(d, cell, colr):
    d.rectangle(cell_box(cell), fill=colr)


def finish(img, name):
    out = img.resize((ATLAS, ATLAS), Image.LANCZOS)
    out.save(os.path.join(ROOT, "textures", name + "_faces.png"))


# ---------------------------------------------------------------- per die
def caltrop(L):
    img, d = new()
    for e in L["cells"]:
        cx = sum(p[0] for p in e["poly"]) / 3
        cy = sum(p[1] for p in e["poly"]) / 3
        # rust creeping in from the edges
        d.line([P(p) for p in e["poly"] + e["poly"][:1]], fill=rgba("3A2014", 150), width=8 * SS)
        edge = math.dist(e["poly"][0], e["poly"][1])
        r = edge * 0.052 * 1.5  # AD: tip pips 1.5x, each with a bone rim
        for k, pos in e["corners"]:
            ux, uy = pos[0] - cx, pos[1] - cy
            ln = math.hypot(ux, uy)
            ux, uy = ux / ln, uy / ln
            rx, ry = -uy, ux
            cc = (pos[0] - ux * ln * 0.36, pos[1] - uy * ln * 0.36)
            s = r * 2.5
            offs = {1: [(0, 0)], 2: [(-0.55, 0), (0.55, 0)], 3: [(0, 0.6), (-0.6, -0.42), (0.6, -0.42)],
                    4: [(0, 0.75), (-0.75, 0), (0.75, 0), (0, -0.75)]}[k]
            for a, b in offs:
                pc_ = (cc[0] + (rx * a + ux * b) * s, cc[1] + (ry * a + uy * b) * s)
                pip(d, pc_, r * 1.08, rgba("0E1414"), rgba("E8DCC0"), 0.16)  # bone rim, ink ring
                pip(d, pc_, r * 0.8, rgba("E8DCC0"))
    fill_cell(d, 24, rgba("2E2420"))  # dark rust on the bevels (kept well off Ember / Danger)
    finish(img, "caltrop_d4")


def numerals(L, name, fill, stroke, sw, hfrac, extra=None, trim=None):
    img, d = new()
    for e in L["cells"]:
        c = e["centre"]
        ir = inradius(e["poly"], c)
        if extra:
            extra(d, e, c, ir)
        if e.get("seal"):
            continue
        cc = (c[0], c[1] - e.get("label_shift", 0.0) * CELL * 0.94 * -1)
        if name != "midnight_d12" or e["value"] != 12:
            label(d, cc, e["label"], ir * hfrac, fill, stroke, sw, max_w=ir * 1.55)
    if trim:
        fill_cell(d, 24, trim)
    return img, d


def lantern(L):
    def glass(d, e, c, ir):
        # a pale streak across each pane: reads as glass under the lamp
        # AD: a crisp, bold diagonal highlight (a band + a thin one) on two faces of each view (1/8 and 4/5, so one
        # of them is always on top or in front), so the panes read as glass, not wood
        if e["value"] not in (1, 4, 5, 8):
            return
        poly = e["poly"]
        A = min(poly, key=lambda q: q[0] + q[1] * 0.3)  # the lower-left corner
        B, C = [q for q in poly if q is not A]

        def at(q, t):
            return (A[0] + (q[0] - A[0]) * t, A[1] + (q[1] - A[1]) * t)
        for t1, t2, al in ((0.20, 0.33, 225), (0.39, 0.43, 200)):  # a crisp band + a thin one across the corner
            d.polygon([P(at(B, t1)), P(at(C, t1)), P(at(C, t2)), P(at(B, t2))], fill=rgba("FFF0C8", al))

    img, d = numerals(L, "lantern_d8", rgba("F2E6C8"), rgba("2A1808"), 3, 1.0, glass)
    finish(img, "lantern_d8")


def tithe(L):
    def slot(d, e, c, ir):
        if "slot" in e:
            (sx, sy), ln, wd = e["slot"]
            d.rounded_rectangle([(sx - ln / 2 - 4) * SS, (sy - wd / 2 - 4) * SS, (sx + ln / 2 + 4) * SS, (sy + wd / 2 + 4) * SS],
                                radius=4 * SS, fill=rgba("B08D3C", 230))
    img, d = numerals(L, "tithe_d10", rgba("E8DCC0"), rgba("0E1414"), 3, 1.3, slot)
    finish(img, "tithe_d10")


def midnight(L):
    def dial(d, e, c, ir):
        if e["value"] == 12:
            d.polygon([P(p) for p in e["poly"]], fill=rgba("2C060C"))
        d.line([P(p) for p in e["poly"] + e["poly"][:1]], fill=rgba("1E1A1A"), width=14 * SS, joint="curve")  # AD: charcoal edge outline
        rr = ir * 0.86
        ring = rgba("B08D3C", 220) if e["value"] == 12 else rgba("2A2426", 150)
        d.ellipse([(c[0] - rr) * SS, (c[1] - rr) * SS, (c[0] + rr) * SS, (c[1] + rr) * SS], outline=ring, width=3 * SS)
        for k in range(12):  # minute ticks
            a = math.tau * k / 12
            d.line([P((c[0] + math.cos(a) * rr * 0.9, c[1] + math.sin(a) * rr * 0.9)), P((c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr))], fill=ring, width=2 * SS)
        if e["value"] == 12:
            label(d, (c[0], c[1] - ir * 0.42), "XII", ir * 0.42, rgba("E8DCC0"), rgba("2A0A10"), 2, max_w=ir * 1.0)
            brass = rgba("C9A23A")
            d.line([P(c), P((c[0], c[1] - ir * 0.20))], fill=brass, width=7 * SS)  # hour hand
            d.line([P(c), P((c[0] + 1, c[1] - ir * 0.62))], fill=brass, width=3 * SS)  # minute hand, both at midnight
            d.polygon([P((c[0] - 6, c[1] - ir * 0.15)), P((c[0] + 6, c[1] - ir * 0.15)), P((c[0], c[1] - ir * 0.28))], fill=brass)
            pip(d, c, ir * 0.09, brass)
            label(d, (c[0], c[1] + ir * 0.45), "", 1, brass)
    img, d = numerals(L, "midnight_d12", rgba("2A2426"), None, 0, 0.62, dial, trim=rgba("1E1A1A"))
    finish(img, "midnight_d12")


def verdict(L):
    rng = random.Random(2020)

    def marble(d, e, c, ir):
        if e.get("seal"):
            rr = ir * 0.8
            d.ellipse([(c[0] - rr) * SS, (c[1] - rr) * SS, (c[0] + rr) * SS, (c[1] + rr) * SS], outline=rgba("7A5A18", 220), width=5 * SS)
            label(d, c, "20", ir * 0.75, rgba("4A1018"), None, 0)
            return
        box = cell_box(e["cell"])
        for k in range(4):
            x, y = rng.uniform(box[0], box[2]) / SS, rng.uniform(box[1], box[3]) / SS
            a = rng.uniform(0, math.tau)
            pts = [(x, y)]
            for _ in range(10):
                a += rng.uniform(-0.6, 0.6)
                x += math.cos(a) * 14
                y += math.sin(a) * 14
                pts.append((x, y))
            w = rng.choice([2, 3, 5])
            d.line([P(p) for p in pts], fill=rgba("8A1E2C", 210) if k < 3 else rgba("9A7A7A", 70), width=w * SS, joint="curve")
    img, d = numerals(L, "verdict_d20", rgba("E8DCC0"), rgba("0E1414"), 3, 0.95, marble)
    finish(img, "verdict_d20")


def ferryman(L):
    img, d = new()
    eng = rgba("2A2622", 225)
    hi = rgba("D8D2C4", 90)
    rng = random.Random(9)
    for e in L["cells"]:
        cx, cy = e["centre"]
        fr = e["field_r"]
        R = fr / 0.76
        d.ellipse([(cx - fr) * SS, (cy - fr) * SS, (cx + fr) * SS, (cy + fr) * SS], outline=eng, width=3 * SS)
        for k in range(28):  # beaded rim
            a = math.tau * k / 28
            pip(d, (cx + math.cos(a) * (fr + R) * 0.5, cy + math.sin(a) * (fr + R) * 0.5), 2.6, rgba("4A463E", 200))
        s = fr
        if e["label"] == "heads":  # a grinning skull
            d.ellipse([(cx - s * 0.55) * SS, (cy - s * 0.70) * SS, (cx + s * 0.55) * SS, (cy + s * 0.30) * SS], outline=eng, width=5 * SS)
            d.rounded_rectangle([(cx - s * 0.36) * SS, (cy + s * 0.12) * SS, (cx + s * 0.36) * SS, (cy + s * 0.55) * SS], radius=8 * SS, outline=eng, width=5 * SS)
            for sx in (-1, 1):
                d.ellipse([(cx + sx * s * 0.24 - s * 0.16) * SS, (cy - s * 0.30) * SS, (cx + sx * s * 0.24 + s * 0.16) * SS, (cy + s * 0.0) * SS], fill=eng)
            d.polygon([P((cx, cy + s * 0.04)), P((cx - s * 0.07, cy + s * 0.17)), P((cx + s * 0.07, cy + s * 0.17))], fill=eng)
            d.line([P((cx - s * 0.36, cy + s * 0.36)), P((cx + s * 0.36, cy + s * 0.36))], fill=eng, width=4 * SS)
            for k in range(-3, 4):
                d.line([P((cx + k * s * 0.1, cy + s * 0.22)), P((cx + k * s * 0.1, cy + s * 0.52))], fill=eng, width=3 * SS)
        else:  # a moth
            for sx in (-1, 1):
                d.ellipse([(cx + sx * s * 0.42 - s * 0.36) * SS, (cy - s * 0.55) * SS, (cx + sx * s * 0.42 + s * 0.36) * SS, (cy + s * 0.05) * SS], outline=eng, width=5 * SS)
                d.ellipse([(cx + sx * s * 0.30 - s * 0.24) * SS, (cy + s * 0.0) * SS, (cx + sx * s * 0.30 + s * 0.24) * SS, (cy + s * 0.48) * SS], outline=eng, width=5 * SS)
                pip(d, (cx + sx * s * 0.45, cy - s * 0.25), s * 0.09, eng)
                d.line([P((cx + sx * s * 0.05, cy - s * 0.42)), P((cx + sx * s * 0.25, cy - s * 0.75))], fill=eng, width=3 * SS)
            d.ellipse([(cx - s * 0.09) * SS, (cy - s * 0.45) * SS, (cx + s * 0.09) * SS, (cy + s * 0.45) * SS], fill=eng)
        for _ in range(12):  # wear
            x, y = cx + rng.uniform(-fr, fr), cy + rng.uniform(-fr, fr)
            a = rng.uniform(0, math.pi)
            d.line([P((x, y)), P((x + math.cos(a) * 20, y + math.sin(a) * 20))], fill=hi, width=SS)
    fill_cell(d, 24, rgba("5E5A52"))
    finish(img, "ferryman_d2")


def powder_keg(L):
    img, d = new()
    s = L["px_per_m"]
    for e in L["cells"]:
        if e["value"] in [x["value"] for x in L["cells"] if x is not e and x["cell"] == e["cell"] and L["cells"].index(x) < L["cells"].index(e)]:
            continue
        cx, cy = e["centre"]
        xs = [p[0] for p in e["poly"]]
        hw = (max(xs) - min(xs)) / 2
        for f in (-0.34, 0.34):
            d.line([P((cx + f * hw, cy - 100)), P((cx + f * hw, cy + 100))], fill=rgba("2E1A08", 235), width=4 * SS)  # AD: bolder stave lines
        for f in (-1.0, 1.0):
            d.line([P((cx + f * hw, cy - 100)), P((cx + f * hw, cy + 100))], fill=rgba("2E1A08", 235), width=5 * SS)
        r = 0.0052 * s
        dd = 0.0145 * s
        offs = {1: [0], 2: [-0.5, 0.5], 3: [-1, 0, 1]}[e["value"]]
        for o in offs:
            c = (cx, cy + o * dd)
            pip(d, c, r, rgba("141010"))
            d.rectangle([(c[0] - r - 1) * SS, (c[1] - 1.2) * SS, (c[0] + r + 1) * SS, (c[1] + 1.2) * SS], fill=(0, 0, 0, 0))  # stencil bridge
    fill_cell(d, 23, rgba("3A2418"))
    finish(img, "powder_keg_d3")


def knucklebone(L):
    img, d = new()
    s = L["px_per_m"]
    rng = random.Random(4)
    for e in L["cells"]:
        cx, cy = e["centre"]
        for _ in range(6):  # age streaks along the bone
            x = cx + rng.uniform(-60, 60)
            d.line([P((x, cy - 90)), P((x + rng.uniform(-15, 15), cy + 90))], fill=rgba("9A7A40", 45), width=3 * SS)
        r = 0.0056 * s
        a, b = 0.016 * s, 0.0135 * s  # along the length, across
        lay = {1: [(0, 0)], 3: [(0, -1), (0, 0), (0, 1)], 4: [(-0.5, -0.5), (0.5, -0.5), (-0.5, 0.5), (0.5, 0.5)],
               6: [(-0.5, -1), (-0.5, 0), (-0.5, 1), (0.5, -1), (0.5, 0), (0.5, 1)]}[e["value"]]
        rr = r * (1.35 if e["value"] == 1 else 1.0)
        for u, v in lay:
            pip(d, (cx + u * b, cy + v * a), rr, rgba("2A1A12"), rgba("8A6A3A", 200), 0.3)
    finish(img, "knucklebone_talus")


# ---------------------------------------------------------------- materials
def lit(target, lo=0.35, hi=0.6, s=0.7):
    """lamp_comp() albedo (cancel part of the #FFB070 lamp tint) with the gain clamped: these bodies carry the
    numerals / pips in their overlay, so the gain can't drop as low as batch 2's plain dark bodies."""
    c = lamp_comp(target, s=s)
    return {"albedo": c["albedo"], "light_gain": round(min(hi, max(lo, c["light_gain"])), 3)}


TEX = "res://art/models/dice/textures/%s_faces.png"
MATS = {
    # slot: (params, ink, texture-die)
    "caltrop_body": ({**lit("#2E2B2A"), "shadow_color": "#0E0C0C", "mid_tint": 0.72, "wrap": 0.3, "roughness": 0.5,
                      "spec_size": 0.95, "spec_color": "#C8C0B8", "spec_strength": 0.45}, INK, "caltrop_d4"),
    "lantern_body": ({**lit("#7A4410", hi=0.5), "shadow_color": "#2A1206", "mid_tint": 0.75, "wrap": 0.35, "roughness": 0.15,
                      "spec_size": 0.99, "spec_color": "#FFE8C0", "spec_strength": 0.2, "rim_color": "#E0A050", "rim_strength": 0.35, "rim_power": 2.5}, INK, "lantern_d8"),
    "lantern_frame": ({"shadow_color": "#2A2826", "mid_tint": 0.72, "wrap": 0.25, "roughness": 0.35, **lit("#6E6A64", lo=0.15, hi=0.22, s=0.6),
                       "spec_size": 0.975, "spec_color": "#E8E4DC", "spec_strength": 0.2}, INK_THIN, None),
    "tithe_body": ({"albedo": "#1C2846", "shadow_color": "#060A14", "mid_tint": 0.74, "wrap": 0.3, "roughness": 0.35, **lamp_comp("#1C2846", s=0.75, v=1.6),
                    "spec_size": 0.99, "spec_color": "#D0D8F0", "spec_strength": 0.12}, INK, "tithe_d10"),
    "tithe_slot": ({"albedo": "#0E1414", "shadow_color": "#000000", "roughness": 0.9, "light_gain": 0.4}, None, None),
    "midnight_body": ({"albedo": "#C8B48A", "shadow_color": "#5A4C36", "mid_tint": 0.8, "wrap": 0.35, "roughness": 0.5, "light_gain": 0.6,
                       "spec_size": 0.99, "spec_color": "#FFF6E0", "spec_strength": 0.2}, INK, "midnight_d12"),
    "verdict_body": ({**lit("#2A1E22"), "shadow_color": "#0E080A", "mid_tint": 0.72, "wrap": 0.3, "roughness": 0.25,
                      "spec_size": 0.99, "spec_color": "#FFE0D8", "spec_strength": 0.14}, INK, "verdict_d20"),
    "verdict_seal": ({"albedo": "#C9A23A", "shadow_color": "#4A3410", "mid_tint": 0.75, "wrap": 0.3, "roughness": 0.35, "light_gain": 0.5,
                      "spec_size": 0.985, "spec_color": "#FFE8A0", "spec_strength": 0.25}, None, "verdict_d20"),  # no hull: a push-from-centre hull floats over a flat disc
    "ferryman_body": ({"albedo": "#8A8478", "shadow_color": "#2E2A26", "mid_tint": 0.74, "wrap": 0.3, "roughness": 0.45, **lamp_comp("#8A8478", s=0.6),
                       "spec_size": 0.99, "spec_color": "#F0ECE4", "spec_strength": 0.1}, INK, "ferryman_d2"),
    "powder_keg_body": ({**lit("#C9A030", s=0.5), "shadow_color": "#4A3410", "mid_tint": 0.75, "wrap": 0.3, "roughness": 0.8}, INK, "powder_keg_d3"),
    "powder_keg_hoop": ({"albedo": "#0E0C0C", "shadow_color": "#000000", "mid_tint": 0.6, "roughness": 0.5, "light_gain": 0.5,
                         "spec_size": 0.97, "spec_color": "#8A8480", "spec_strength": 0.3}, None, None),  # no hull: thin bands (see verdict_seal)
    "knucklebone_body": ({"albedo": "#D9C48A", "shadow_color": "#6E5A34", "mid_tint": 0.8, "wrap": 0.35, "roughness": 0.6, "light_gain": 0.42,
                          "spec_size": 0.99, "spec_color": "#FFF0D0", "spec_strength": 0.15}, INK, "knucklebone_talus"),
}
DICE = {
    "caltrop_d4": ["caltrop_body"], "lantern_d8": ["lantern_body", "lantern_frame"], "tithe_d10": ["tithe_body", "tithe_slot"],
    "midnight_d12": ["midnight_body"], "verdict_d20": ["verdict_body", "verdict_seal"], "ferryman_d2": ["ferryman_body"],
    "powder_keg_d3": ["powder_keg_body", "powder_keg_hoop"], "knucklebone_talus": ["knucklebone_body"],
}


def write_tres(name, params, ink, tex):
    ext = ['[ext_resource type="Shader" path="%s" id="1"]' % TOON]
    if ink:
        ext.append('[ext_resource type="Material" path="%s" id="2"]' % ink)
    if tex:
        ext.append('[ext_resource type="Texture2D" path="%s" id="3"]' % (TEX % tex))
    lines = ['[gd_resource type="ShaderMaterial" load_steps=%d format=3]' % (len(ext) + 1), ""] + ext + ["", "[resource]", "render_priority = 0"]
    if ink:
        lines.append('next_pass = ExtResource("2")')
    lines.append('shader = ExtResource("1")')
    for k, v in params.items():
        lines.append("shader_parameter/%s = %s" % (k, col(v) if isinstance(v, str) else repr(float(v))))
    if tex:
        lines += ["shader_parameter/use_overlay = true", 'shader_parameter/overlay_tex = ExtResource("3")',
                  "shader_parameter/overlay_tint = Color(1, 1, 1, 1)"]
    with open(os.path.join(ROOT, "materials", name + ".tres"), "w") as f:
        f.write("\n".join(lines) + "\n")


def write_ink_thin():
    with open(os.path.join(ROOT, "materials", "batch3_ink_thin.tres"), "w") as f:
        f.write('[gd_resource type="ShaderMaterial" load_steps=2 format=3]\n\n[ext_resource type="Shader" path="res://shaders/3d/outline.gdshader" id="1"]\n\n'
                '[resource]\nrender_priority = 0\nshader = ExtResource("1")\nshader_parameter/color = Color(0.054902, 0.0784314, 0.0784314, 1)\n'
                'shader_parameter/width = 0.0022\nshader_parameter/mode = 1\n')


def write_import(glb, slots):
    path = os.path.join(ROOT, glb + ".glb.import")
    text = open(path).read()
    for k, v in (("animation/import", "false"), ("meshes/generate_lods", "false")):
        text = re.sub(r"^%s=.*$" % re.escape(k), "%s=%s" % (k, v), text, flags=re.M)
    sub = ['"materials": {']
    for i, s in enumerate(slots):
        p = "res://art/models/dice/materials/%s.tres" % s
        sub.append('"%s": {\n"use_external/enabled": true,\n"use_external/fallback_path": "%s",\n"use_external/path": "%s"\n}%s' % (s, p, p, "," if i < len(slots) - 1 else ""))
    sub.append("}")
    start = text.index("_subresources={")
    end = text.find("\n", start) if text[start:].startswith("_subresources={}") else text.index("\n}\n", start) + 2
    text = text[:start] + "_subresources={\n" + "\n".join(sub) + "\n}" + text[end:]
    with open(path, "w") as f:
        f.write(text)


def write_tex_import(die):
    path = os.path.join(ROOT, "textures", die + "_faces.png.import")
    text = open(path).read()
    for k, v in {"compress/mode": "0", "mipmaps/generate": "true", "detect_3d/compress_to": "0"}.items():
        text = re.sub(r"^%s=.*$" % re.escape(k), "%s=%s" % (k, v), text, flags=re.M)
    with open(path, "w") as f:
        f.write(text)


PRINT_GRID = 8


def face_print(img, cell):
    """8 x 8 grid over the middle 80% of an atlas cell: mean ink coverage (alpha) and mean ink brightness
    (alpha * luminance), 0..1. The test recomputes it from the imported texture to check each face's mark."""
    w = CELL
    x0, y0 = (cell % 5) * w + w * 0.1, (cell // 5) * w + w * 0.1
    step = w * 0.8 / PRINT_GRID
    px = img.load()
    alpha, bright = [], []
    for gy in range(PRINT_GRID):
        for gx in range(PRINT_GRID):
            sa = sl = 0.0
            n = 0
            for y in range(int(y0 + gy * step), int(y0 + (gy + 1) * step), 2):
                for x in range(int(x0 + gx * step), int(x0 + (gx + 1) * step), 2):
                    r, g, b_, a_ = px[x, y]
                    l = (0.2126 * r + 0.7152 * g + 0.0722 * b_) / 255.0
                    sa += a_ / 255.0
                    sl += l * a_ / 255.0
                    n += 1
            alpha.append(round(sa / n, 3))
            bright.append(round(sl / n, 3))
    return alpha + bright


def write_face_prints(layout):
    """art/models/dice/batch3_face_prints.json: per die, per value, the label painted on that face and its atlas
    fingerprint (tests/test_batch3_dice.gd checks each face shows its own mark, e.g. a Lantern 1/2 swap fails)."""
    out = {}
    for die, L in layout.items():
        img = Image.open(os.path.join(ROOT, "textures", die + "_faces.png")).convert("RGBA")
        faces = {}
        for e in L["cells"]:
            if e.get("seal") or str(e["value"]) in faces:
                continue
            faces[str(e["value"])] = {"cell": e["cell"], "label": e["label"], "print": face_print(img, e["cell"])}
        out[die] = {"grid": PRINT_GRID, "faces": faces}
    with open(os.path.join(ROOT, "batch3_face_prints.json"), "w") as f:
        json.dump(out, f, indent=0, sort_keys=True)
    print("wrote batch3_face_prints.json")


if __name__ == "__main__":
    layout = json.load(open(os.path.join(SRC, "batch3_layout.json")))
    os.makedirs(os.path.join(ROOT, "textures"), exist_ok=True)
    for die, fn in (("caltrop_d4", caltrop), ("lantern_d8", lantern), ("tithe_d10", tithe), ("midnight_d12", midnight),
                    ("verdict_d20", verdict), ("ferryman_d2", ferryman), ("powder_keg_d3", powder_keg), ("knucklebone_talus", knucklebone)):
        fn(layout[die])
        print("painted", die)
    write_face_prints(layout)
    write_ink_thin()
    for n, (p, ink, tex) in MATS.items():
        write_tres(n, p, ink, tex)
    print("wrote %d materials" % len(MATS))
    if "--imports" in sys.argv:
        for die, slots in DICE.items():
            for g in (die, die + "_mobile"):
                write_import(g, slots)
            write_tex_import(die)
            print("mapped", die)
