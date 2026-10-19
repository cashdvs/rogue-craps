"""Batch-2 special dice (plus the batch-1 contrast-pass accents: Hellfire spikes, Gilded beads): writes the toon materials (materials/<slot>.tres) and maps each .glb's material slots
onto them in its .glb.import (run `godot --headless --import` once first so the .import files exist).
    python3 art/models/dice/src/write_batch2.py [--imports]
Body slots get the shared ink hull (die_ink_outline.tres) as next_pass, like batch 1, and so do the fin-read accents
(AD, Oct 19: spikes, beads, fins, seals + stamps, collars), so they keep an ink line of their own at 48 px."""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
TOON = "res://shaders/3d/toon_noir.gdshader"
INK = "res://art/models/dice/materials/die_ink_outline.tres"
# thinner ink hull for the fin-read accents: the body's 4.2 mm hull would swallow a 1 cm fin at 48 px
INK_ACCENT = "res://art/models/dice/materials/die_ink_accent.tres"
INK_ACCENT_W = 0.0022


def col(h, a=1.0):
    h = h.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return "Color(%.6f, %.6f, %.6f, %g)" % (r, g, b, a)


BONE_SPEC = {"spec_size": 0.975, "spec_color": "#FFF6E0", "spec_strength": 0.35}
PIP_DARK = {"albedo": "#0E1414", "shadow_color": "#000000", "roughness": 0.8, "ambient_energy": 0.1, "light_gain": 0.4}
PIP_BONE = {"albedo": "#E8DCC0", "shadow_color": "#7A6A52", "mid_tint": 0.8, "wrap": 0.4, "roughness": 0.6}

def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _srgb(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


LAMP = "#FFB070"  # Lamp3D spot colour (scripts/table3d/lamp_3d.gd)
LAMP_K = 8.3  # measured: lit-face linear gain per unit light_gain under the lamp at rest height


def lamp_comp(target, s=0.7, v=1.3):
    """The AD swatch is how the die should READ under the warm lamp. The #FFB070 spot multiplies blue by ~0.16
    and green by ~0.43 (linear), which drags every cool/purple swatch to the same beige. Pre-divide the albedo by
    lamp^s (s = how much of the lamp's tint to cancel) and pick light_gain so the lit face lands at v x the
    swatch's luminance. Returns {"albedo", "light_gain"} to merge into the material params."""
    lamp = [_lin(int(LAMP[i:i + 2], 16) / 255) for i in (1, 3, 5)]
    t = [_lin(int(target[i:i + 2], 16) / 255) for i in (1, 3, 5)]
    a = [t[i] / lamp[i] ** s for i in range(3)]
    m = max(a)
    if m > 1.0:
        a = [x / m for x in a]
    lum = lambda c: 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    gain = v * lum(t) / (LAMP_K * lum([a[i] * lamp[i] for i in range(3)]))
    return {"albedo": "#%02X%02X%02X" % tuple(round(_srgb(x) * 255) for x in a), "light_gain": round(gain, 3)}


# slot -> (params, inked). Palette: art/concept/special_dice/batch2_palette.md (AD, Oct 18): spread hue AND value
# under the warm lamp; never Soul cyan, Danger #FF2E3E, the Satanic violet glow or felt green on a body.
# Fin-read contrast pass (AD, Oct 19): the decoration that defines the silhouette is bone or bright brass at FULL value
# against its body (lamp-tuned like the stamps so it lands near the swatch instead of clipping), and inked.
BONE_FULL = {**PIP_BONE, **lamp_comp("#E8DCC0", s=0.3, v=1.5), "roughness": 0.5, **BONE_SPEC}
BRASS_FULL = {"shadow_color": "#4A3410", "mid_tint": 0.82, "wrap": 0.45, "roughness": 0.25, **lamp_comp("#E2C06A", s=0.3, v=1.8),
              "spec_size": 0.9, "spec_color": "#FFF0C8", "spec_strength": 0.8}
# Dark iron (fin read v2, AD Oct 19): reads ~22% value under the lamp (lit-face sRGB max ~0.22 after lamp_comp);
# used where the body is mid / light and the accent must sit DARK against it (Last Breath collars, Wanderer fins).
IRON_DARK = {"albedo": "#34302E", "shadow_color": "#0E1414", "mid_tint": 0.7, "roughness": 0.4, **lamp_comp("#34302E", s=0.8, v=1.0),
             "spec_size": 0.9, "spec_color": "#C8C0B8", "spec_strength": 0.6, "rim_color": "#8A847E", "rim_strength": 0.3, "rim_power": 3.0}
CREAM = {"albedo": "#F2E6C8", "shadow_color": "#7E7058", "mid_tint": 0.8, "wrap": 0.4, "roughness": 0.6}
MATS = {
    # Twin Flame: bone half / charcoal half (max value split), thin ember line at the waist, pips flip per half
    "twin_flame_body": ({"albedo": "#EDE3CF", "shadow_color": "#7E6A50", "mid_tint": 0.78, "wrap": 0.35, "roughness": 0.55, **BONE_SPEC}, True),
    "twin_flame_pip": (PIP_DARK, False),
    "twin_flame_half": ({"albedo": "#2A2426", "shadow_color": "#0E0C0D", "mid_tint": 0.72, "wrap": 0.3, "roughness": 0.6, **lamp_comp("#2A2426", s=0.9, v=1.0),
                         "spec_size": 0.985, "spec_color": "#C8B8B0", "spec_strength": 0.2}, False),
    "twin_flame_pip_light": ({"albedo": "#EDE3CF", "shadow_color": "#7E6A50", "mid_tint": 0.8, "wrap": 0.4, "roughness": 0.6}, False),
    "twin_flame_cleft": ({"albedo": "#0E1414", "shadow_color": "#000000", "roughness": 0.85, "light_gain": 0.5}, False),
    "twin_flame_line": ({"albedo": "#E8622A", "shadow_color": "#7A2A10", "mid_tint": 0.85, "wrap": 0.5, "roughness": 0.5,
                         "light_gain": 0.3}, False),  # low gain: lit, it stays ember instead of clipping to peach
    # Wanderer: desaturated steel blue (not cyan), brass fins, cream pips
    "wanderer_body": ({"albedo": "#5C7894", "shadow_color": "#1C2632", "mid_tint": 0.74, "wrap": 0.3, "roughness": 0.6, **lamp_comp("#5C7894"),
                       "spec_size": 0.985, "spec_color": "#D8E0E8", "spec_strength": 0.25}, True),
    "wanderer_pip": (CREAM, False),
    # fin read v2 (AD, Oct 19): value flipped, dark iron corner blades on the mid steel-blue body, small bright brass
    # tips that glint (no ink on the 4.6 mm tip: a 2.2 mm hull would eat it)
    "wanderer_fin": (IRON_DARK, "accent"),
    "wanderer_fin_tip": (BRASS_FULL, False),  # bright brass at full value (was #B08D3C at 0.8 gain: it sank into the lamp-lit body)
    # Bellows: warm tan leather, dark brown pleats, oxblood pips
    "bellows_body": ({"albedo": "#B88A5A", "shadow_color": "#46291A", "mid_tint": 0.72, "wrap": 0.3, "roughness": 0.75, **lamp_comp("#B88A5A"),
                      "spec_size": 0.975, "spec_color": "#E8C8A0", "spec_strength": 0.2}, True),
    "bellows_pip": ({"albedo": "#3B0D14", "shadow_color": "#14040A", "roughness": 0.8, "ambient_energy": 0.1, "light_gain": 0.5}, False),
    "bellows_pleat": ({"albedo": "#3A2418", "shadow_color": "#140A06", "mid_tint": 0.7, "roughness": 0.85}, False),
    # Blood Pact: deep crimson (well below Danger), black wax seals with a gold stamp, bone pips
    "blood_pact_body": ({"albedo": "#7E1626", "shadow_color": "#26060C", "mid_tint": 0.72, "wrap": 0.3, "roughness": 0.3, **lamp_comp("#7E1626", v=1.2),
                         "spec_size": 0.975, "spec_color": "#FFD6D0", "spec_strength": 0.6, "rim_color": "#C83848", "rim_strength": 0.2, "rim_power": 3.0}, True),
    "blood_pact_pip": (PIP_BONE, False),
    "blood_pact_seal": ({"albedo": "#141012", "shadow_color": "#060405", "mid_tint": 0.7, "roughness": 0.2,
                         "spec_size": 0.9, "spec_color": "#D8C8C0", "spec_strength": 0.7}, "accent"),  # black wax ring, inked
    # bone stamps (AD, Oct 18: bone, not gold, so nothing on the corners reads as the Devilish brass cue); the
    # same bone as the pips, lamp-tuned so the raised boss reads bone rather than clipping to the lamp's orange-white
    # Fin read (AD, Oct 19): the boss is widened to most of the seal, so each seal reads as a full-value bone disc
    "blood_pact_stamp": (BONE_FULL, "accent"),
    # Coven: matte dusty plum, NO glow / emission, bone pips (wax-pale coves keep the scooped edges reading)
    "coven_body": ({"albedo": "#6E4A6E", "shadow_color": "#241626", "mid_tint": 0.74, "wrap": 0.3, "roughness": 0.95, **lamp_comp("#6E4A6E", v=1.2)}, True),
    "coven_pip": (PIP_BONE, False),
    "coven_cove": ({"albedo": "#D9CBA8", "shadow_color": "#6E6048", "mid_tint": 0.8, "wrap": 0.4, "roughness": 0.9}, False),
    # Last Breath: pale cool ash stone, dark iron collars on both ends, charcoal pips
    "last_breath_body": ({"albedo": "#9AA0A6", "shadow_color": "#363A40", "mid_tint": 0.75, "wrap": 0.35, "roughness": 0.9, **lamp_comp("#9AA0A6", s=0.8)}, True),
    "last_breath_pip": ({"albedo": "#2A2426", "shadow_color": "#0A0809", "roughness": 0.8, "ambient_energy": 0.1, "light_gain": 0.45}, False),
    # Fin read v2 (AD, Oct 19): back to dark iron (~22% value as lit), now with its own accent ink hull
    "last_breath_collar": (IRON_DARK, "accent"),
    # batch-1 fin-read accents: Hellfire's corner spikes in bone (not brass: no Devilish corner-cap cue), Gilded's
    # studs polished bright brass on the tarnished body
    "hellfire_spike": (BONE_FULL, "accent"),
    "gilded_bead": (BRASS_FULL, "accent"),
}
DICE = {
    "twin_flame_d6": ["twin_flame_body", "twin_flame_pip", "twin_flame_half", "twin_flame_pip_light", "twin_flame_cleft", "twin_flame_line"],
    "wanderer_d6": ["wanderer_body", "wanderer_pip", "wanderer_fin", "wanderer_fin_tip"],
    "bellows_d6": ["bellows_body", "bellows_pip", "bellows_pleat"],
    "blood_pact_d6": ["blood_pact_body", "blood_pact_pip", "blood_pact_seal", "blood_pact_stamp"],
    "coven_d6": ["coven_body", "coven_pip", "coven_cove"],
    "last_breath_d6": ["last_breath_body", "last_breath_pip", "last_breath_collar"],
    "hellfire_d6": ["hellfire_body", "hellfire_pip", "hellfire_seam", "hellfire_spike"],
    "gilded_d6": ["gilded_body", "gilded_pip", "gilded_panel", "gilded_bead"],
}


def write_tres(name, params, inked):
    lines = ['[gd_resource type="ShaderMaterial" load_steps=%d format=3]' % (3 if inked else 2), "",
             '[ext_resource type="Shader" path="%s" id="1"]' % TOON]
    if inked:
        lines.append('[ext_resource type="Material" path="%s" id="2"]' % (INK_ACCENT if inked == "accent" else INK))
    lines += ["", "[resource]", "render_priority = 0"]
    if inked:
        lines.append('next_pass = ExtResource("2")')
    lines.append('shader = ExtResource("1")')
    for k, v in params.items():
        lines.append("shader_parameter/%s = %s" % (k, col(v) if isinstance(v, str) else repr(float(v))))
    with open(os.path.join(ROOT, "materials", name + ".tres"), "w") as f:
        f.write("\n".join(lines) + "\n")


def write_import(die, slots):
    path = os.path.join(ROOT, die + ".glb.import")
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


def write_accent_ink():
    with open(os.path.join(ROOT, "materials", "die_ink_accent.tres"), "w") as f:
        f.write('[gd_resource type="ShaderMaterial" load_steps=2 format=3]\n\n[ext_resource type="Shader" path="res://shaders/3d/outline.gdshader" id="1"]\n\n'
                '[resource]\nrender_priority = 0\nshader = ExtResource("1")\nshader_parameter/color = Color(0.054902, 0.0784314, 0.0784314, 1)\n'
                'shader_parameter/width = %g\nshader_parameter/mode = 1\n' % INK_ACCENT_W)


if __name__ == "__main__":
    write_accent_ink()
    for n, (p, ink) in MATS.items():
        write_tres(n, p, ink)
    print("wrote %d materials" % len(MATS))
    if "--imports" in sys.argv:
        for d, slots in DICE.items():
            write_import(d, slots)
            print("mapped", d)
