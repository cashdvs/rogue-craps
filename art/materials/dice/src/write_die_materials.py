"""Writes the five die material families (body + pip) and the locked batch-3
demo material as .tres, all on art/materials/dice/toon_die.gdshader.
Run: python3 art/materials/dice/src/write_die_materials.py"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SH = "res://art/materials/dice/toon_die.gdshader"
INK = "res://art/models/dice/materials/die_ink_outline.tres"
BEVEL = "res://art/materials/dice/textures/die_surface_mask.png"
PIP = "res://art/materials/dice/textures/die_pip_profile.png"


def c(r, g, b):
    return f"Color({r}, {g}, {b}, 1)"


def hexc(h):
    h = h.lstrip("#")
    return c(*[round(int(h[i:i + 2], 16) / 255, 4) for i in (0, 2, 4)])


BASE = {"glow_energy": 0.0, "glow_color": hexc("E8622A")}
FAM = {
    # Lamp-comped: the key lamp is warm (#FFB070-ish), so cool/neutral
    # albedos are nudged a touch cooler to land neutral under it.
    "bone": dict(albedo_tint=hexc("D2C4A4"), shadow_color=hexc("8E7A5C"), wrap=0.2, mid_tint=0.74,
                 spec_size=0.97, spec_color=hexc("FFF6E0"), spec_strength=0.6, roughness=0.45,
                 speck=0.08, wear=0.20, edge_line_color=hexc("FFFAF0"), edge_line=0.8),
    "brass": dict(albedo_tint=hexc("BE9648"), shadow_color=hexc("4A3414"), wrap=0.15, die_half=0.0384, mid_tint=0.74,
                  spec_size=0.9, spec_color=hexc("FFE9B0"), spec_strength=0.85, rim_color=hexc("E2C06A"),
                  rim_strength=0.3, rim_power=3.0, roughness=0.3, speck=0.12, wear=0.16,
                  edge_line_color=hexc("FFF3CC"), edge_line=0.9),
    "glass": dict(albedo_tint=hexc("CFCDC6"), shadow_color=hexc("6E6A64"), wrap=0.25, mid_tint=0.74,
                  spec_size=0.985, spec_color=hexc("FFFFFF"), spec_strength=0.7, roughness=0.2,
                  glass_mode=True, glass_inner=hexc("A6A29A"), glass_fresnel=hexc("FFFCF4"),
                  glass_fresnel_power=2.2, frost=0.10, glass_core=hexc("FFA458"), glass_core_k=0.75, glass_cold_tint=hexc("C4D0DC"), glass_cold_k=0.9, cold_albedo_mul=(0.72, 0.74, 0.78), speck=0.0, wear=0.10,
                  edge_line_color=hexc("FFFFFF"), edge_line=0.9, glow_color=hexc("F07A3A")),
    "wood": dict(albedo_tint=hexc("BA8650"), shadow_color=hexc("5A3420"), wrap=0.15, mid_tint=0.76,
                 spec_size=0.985, spec_color=hexc("FFE6C8"), spec_strength=0.25, roughness=0.7,
                 grain=0.38, grain_color=hexc("7A4A28"), speck=0.04, wear=0.22,
                 edge_line_color=hexc("FFE8C8"), edge_line=0.8),
    "obsidian": dict(albedo_tint=hexc("3A3E44"), shadow_color=hexc("101214"), wrap=0.3, mid_tint=0.78,
                     spec_size=0.95, spec_color=hexc("F2EDE6"), spec_strength=0.75, roughness=0.15,
                     speck=0.05, wear=0.12, edge_line_color=hexc("CFC6BA"), edge_line=0.95, cold_albedo_mul=(0.62, 0.62, 0.64),
                     glow_color=hexc("F07A3A")),
}
PIPS = {  # pip surface: lip = body colour, floor dark (obsidian: inverse bone pips)
    "bone": dict(albedo_tint=hexc("D2C4A4"), pip_floor_color=hexc("141818"), shadow_color=hexc("8E7A5C")),
    "brass": dict(albedo_tint=hexc("BE9648"), pip_floor_color=hexc("1A1208"), shadow_color=hexc("4A3414")),
    "glass": dict(albedo_tint=hexc("CFCDC6"), pip_floor_color=hexc("2A2826"), shadow_color=hexc("6E6A64")),
    "wood": dict(albedo_tint=hexc("BA8650"), pip_floor_color=hexc("1E120A"), shadow_color=hexc("5A3420")),
    "obsidian": dict(albedo_tint=hexc("EEE4CC"), pip_floor_color=hexc("A89C84"), shadow_color=hexc("6E6450"),
                     pip_lip=0.15, pip_dark_at=0.6),
}
LOCKED = {  # batch 3 keeps its locked colours; surface treatment only
    "lantern_d8": dict(albedo_tint=c(0.478431, 0.356863, 0.145098), light_gain=0.35,
                       shadow_color=c(0.164706, 0.070588, 0.023529), mid_tint=0.75, wrap=0.35,
                       roughness=0.15, spec_size=0.99, spec_color=c(1.0, 0.909804, 0.752941),
                       spec_strength=1.0, rim_color=c(0.878431, 0.627451, 0.313725), rim_strength=1.4,
                       rim_power=1.4, ink_shadow=0.6, use_overlay=True, overlay="res://art/models/dice/textures/lantern_d8_faces.png",
                       edge_lo=0.9, edge_hi=0.95, wear=0.0, speck=0.05),
}


def fmt(v):
    if isinstance(v, tuple):
        return "Vector3(%s, %s, %s)" % v
    if isinstance(v, bool):
        return "true" if v else "false"
    return str(v)


def write(path, params, ink=True, pip=False):
    params = {**BASE, **params}
    ext = [f'[ext_resource type="Shader" path="{SH}" id="1"]',
           f'[ext_resource type="Texture2D" path="{BEVEL}" id="2"]',
           f'[ext_resource type="Texture2D" path="{PIP}" id="3"]']
    n = 4
    body = ["[resource]", "render_priority = 0"]
    if ink:
        ext.append(f'[ext_resource type="Material" path="{INK}" id="4"]'); n = 5
        body.append('next_pass = ExtResource("4")')
    body += ['shader = ExtResource("1")', 'shader_parameter/bevel_map = ExtResource("2")',
             'shader_parameter/pip_map = ExtResource("3")']
    if pip:
        body.append("shader_parameter/pip_mode = true")
    ov = params.pop("overlay", None)
    if ov:
        ext.append(f'[ext_resource type="Texture2D" path="{ov}" id="5"]'); n += 1
        body.append('shader_parameter/overlay_tex = ExtResource("5")')
    for k, v in params.items():
        body.append(f"shader_parameter/{k} = {fmt(v)}")
    txt = f'[gd_resource type="ShaderMaterial" load_steps={n} format=3]\n\n' + "\n".join(ext) + "\n\n" + "\n".join(body) + "\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(txt)


for f, p in FAM.items():
    write(ROOT / f"{f}.tres", p)
    pp = {k: v for k, v in p.items() if k not in ("edge_line", "speck", "wear", "grain", "glass_mode")}
    pp.update(PIPS[f])
    write(ROOT / f"{f}_pip.tres", pp, ink=False, pip=True)
for d, p in LOCKED.items():
    write(ROOT / "locked" / f"{d}.tres", p)
print("ok")
