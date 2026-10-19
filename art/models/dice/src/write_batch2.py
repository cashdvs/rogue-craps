"""Batch-2 special dice: writes the toon materials (materials/<slot>.tres) and maps each .glb's material slots
onto them in its .glb.import (run `godot --headless --import` once first so the .import files exist).
    python3 art/models/dice/src/write_batch2.py [--imports]
Body slots get the shared ink hull (die_ink_outline.tres) as next_pass, like batch 1."""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
TOON = "res://shaders/3d/toon_noir.gdshader"
INK = "res://art/models/dice/materials/die_ink_outline.tres"


def col(h, a=1.0):
    h = h.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return "Color(%.6f, %.6f, %.6f, %g)" % (r, g, b, a)


BONE_SPEC = {"spec_size": 0.975, "spec_color": "#FFF6E0", "spec_strength": 0.35}
PIP_DARK = {"albedo": "#0E1414", "shadow_color": "#000000", "roughness": 0.8, "ambient_energy": 0.1, "light_gain": 0.4}
PIP_BONE = {"albedo": "#E8DCC0", "shadow_color": "#7A6A52", "mid_tint": 0.8, "wrap": 0.4, "roughness": 0.6}

# slot -> (params, inked)
MATS = {
    # Twin Flame: bone half / burgundy half, pips flip colour with the half
    "twin_flame_body": ({"albedo": "#E8DCC0", "shadow_color": "#7A6046", "mid_tint": 0.78, "wrap": 0.35, "roughness": 0.55, **BONE_SPEC}, True),
    "twin_flame_pip": (PIP_DARK, False),
    "twin_flame_half": ({"albedo": "#3B0D14", "shadow_color": "#14040A", "mid_tint": 0.7, "wrap": 0.3, "roughness": 0.45,
                         "spec_size": 0.95, "spec_color": "#E8B0A0", "spec_strength": 0.35}, False),
    "twin_flame_pip_light": (PIP_BONE, False),
    "twin_flame_cleft": ({"albedo": "#0E1414", "shadow_color": "#000000", "roughness": 0.85, "light_gain": 0.5}, False),
    # Wanderer: road clay, bone compass fins
    "wanderer_body": ({"albedo": "#7E3E28", "shadow_color": "#2E120A", "mid_tint": 0.72, "wrap": 0.3, "roughness": 0.8}, True),
    "wanderer_pip": (PIP_DARK, False),
    "wanderer_fin": ({"albedo": "#E8DCC0", "shadow_color": "#7A6046", "mid_tint": 0.8, "wrap": 0.35, "roughness": 0.5, **BONE_SPEC}, False),
    # Bellows: tan leather, dark leather pleat risers
    "bellows_body": ({"albedo": "#A8784A", "shadow_color": "#3E2414", "mid_tint": 0.72, "wrap": 0.3, "roughness": 0.75,
                      "spec_size": 0.93, "spec_color": "#E8C8A0", "spec_strength": 0.2}, True),
    "bellows_pip": (PIP_DARK, False),
    "bellows_pleat": ({"albedo": "#3A2418", "shadow_color": "#140A06", "mid_tint": 0.7, "roughness": 0.85}, False),
    # Blood Pact: glossy crimson, blood-black seals, bone pips
    "blood_pact_body": ({"albedo": "#8E1822", "shadow_color": "#2A060C", "mid_tint": 0.72, "wrap": 0.3, "roughness": 0.3,
                         "spec_size": 0.92, "spec_color": "#FFD6D0", "spec_strength": 0.7, "rim_color": "#E8505A", "rim_strength": 0.25, "rim_power": 3.0}, True),
    "blood_pact_pip": (PIP_BONE, False),
    "blood_pact_seal": ({"albedo": "#2A0A10", "shadow_color": "#0E0406", "mid_tint": 0.7, "roughness": 0.2,
                         "spec_size": 0.9, "spec_color": "#FFB0B0", "spec_strength": 0.8}, False),
    # Coven: soot-plum, wax-pale coves, bone pips
    "coven_body": ({"albedo": "#3E2A48", "shadow_color": "#140C18", "mid_tint": 0.72, "wrap": 0.3, "roughness": 0.7}, True),
    "coven_pip": (PIP_BONE, False),
    "coven_cove": ({"albedo": "#D9CBA8", "shadow_color": "#6E6048", "mid_tint": 0.8, "wrap": 0.4, "roughness": 0.6}, False),
    # Last Breath: ash-grey stone, iron collar
    "last_breath_body": ({"albedo": "#565C62", "shadow_color": "#1A1C20", "mid_tint": 0.75, "wrap": 0.35, "roughness": 0.9}, True),
    "last_breath_pip": (PIP_DARK, False),
    "last_breath_collar": ({"albedo": "#34302E", "shadow_color": "#0E1414", "mid_tint": 0.7, "roughness": 0.4,
                            "spec_size": 0.9, "spec_color": "#C8C0B8", "spec_strength": 0.6, "rim_color": "#8A847E", "rim_strength": 0.3, "rim_power": 3.0}, False),
}
DICE = {
    "twin_flame_d6": ["twin_flame_body", "twin_flame_pip", "twin_flame_half", "twin_flame_pip_light", "twin_flame_cleft"],
    "wanderer_d6": ["wanderer_body", "wanderer_pip", "wanderer_fin"],
    "bellows_d6": ["bellows_body", "bellows_pip", "bellows_pleat"],
    "blood_pact_d6": ["blood_pact_body", "blood_pact_pip", "blood_pact_seal"],
    "coven_d6": ["coven_body", "coven_pip", "coven_cove"],
    "last_breath_d6": ["last_breath_body", "last_breath_pip", "last_breath_collar"],
}


def write_tres(name, params, inked):
    lines = ['[gd_resource type="ShaderMaterial" load_steps=%d format=3]' % (3 if inked else 2), "",
             '[ext_resource type="Shader" path="%s" id="1"]' % TOON]
    if inked:
        lines.append('[ext_resource type="Material" path="%s" id="2"]' % INK)
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


if __name__ == "__main__":
    for n, (p, ink) in MATS.items():
        write_tres(n, p, ink)
    print("wrote %d materials" % len(MATS))
    if "--imports" in sys.argv:
        for d, slots in DICE.items():
            write_import(d, slots)
            print("mapped", d)
