"""Shared die surface masks (original, procedural; no external sources).

bevel_map  die_surface_mask.png 512x512 RGBA, tiling, NON-colour:
  R = edge micro-wear chips (sparse dark-ish specks, used only near bevels)
  G = wood grain bands (along U)       B = fine speckle (bone pores / brass grain)
  A = frost noise (milky glass)
pip_map    die_pip_profile.png 512x16 RGBA, NON-colour, x = depth below the
  face plane (0 = lip, 1 = floor at pip_depth):
  R = shade (1 lip .. ~0.22 floor)   G = lip highlight ring near x~0.06
Run: python3 art/materials/dice/src/make_die_masks.py
"""
import numpy as np
from PIL import Image
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "textures"
N = 512
rng = np.random.default_rng(1666)


def tile_noise(cells, octaves=4, seed=0):
    r = np.random.default_rng(seed)
    acc = np.zeros((N, N))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        c = cells * 2 ** o
        g = r.random((c, c))
        g = np.pad(g, ((0, 1), (0, 1)), mode="wrap")  # tileable
        x = np.linspace(0, c, N, endpoint=False)
        i = x.astype(int); f = x - i; f = f * f * (3 - 2 * f)
        a = g[i][:, i] * (1 - f)[None, :] + g[i][:, i + 1] * f[None, :]
        b = g[i + 1][:, i] * (1 - f)[None, :] + g[i + 1][:, i + 1] * f[None, :]
        acc += amp * (a * (1 - f)[:, None] + b * f[:, None])
        tot += amp; amp *= 0.5
    return acc / tot


wear = tile_noise(16, 4, 1)
wear = np.clip((wear - 0.58) / 0.12, 0, 1)                    # sparse chips
grain = tile_noise(4, 3, 2)
u = np.linspace(0, 1, N, endpoint=False)[None, :]
bands = 0.5 + 0.5 * np.sin((u * 18 + grain * 3.0) * 2 * np.pi)  # tiles: 18 whole cycles
grain_m = np.clip(bands ** 3 * 0.8 + tile_noise(32, 2, 3) * 0.2, 0, 1)
speck = np.clip((tile_noise(64, 2, 4) - 0.45) * 2.5, 0, 1)
frost = tile_noise(24, 4, 5)
rgba = np.stack([wear, grain_m, speck, frost], -1)
Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(OUT / "die_surface_mask.png", optimize=True)

x = np.linspace(0, 1, N)
shade = 1 - 0.78 * np.clip((x - 0.08) / 0.5, 0, 1) ** 0.7
lip = np.exp(-((x - 0.05) / 0.035) ** 2)
prof = np.stack([shade, lip, np.zeros(N), np.ones(N)], -1)
prof = np.repeat(prof[None], 16, 0)
Image.fromarray((prof * 255).astype(np.uint8), "RGBA").save(OUT / "die_pip_profile.png", optimize=True)
print("wrote", OUT)
