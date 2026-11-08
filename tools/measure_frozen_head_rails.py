#!/usr/bin/env python3
"""Finite-solid Head/Visor check on the frozen native streams.

Reads the extracted QA bundle (EVIDENCE, default /tmp/frozen-evidence).
Only Smiles_Head and Smiles_Visor vertices are tested. Glow materials on
those meshes are counted apart from the opaque shell. Body and Chip slots
in the same binaries stay normalized-CPU and are not measured.

This is ray-parity through the closed rail plus transverse edge hits.
It does not use a min/max vertical span at the same XZ. Reverse containment
is not claimed: the head is not treated as a closed solid.

60 Hz samples with endpoints. Not swept motion, not blends, not the yaw-90
MC seat.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import numpy as np

EDGE = 1e-6
MARGIN = 1e-6
BARY = 1e-5
WELD = 1e-8
DIRS = (
    np.array([0.0, 1.0, 0.0]),
    np.array([1.0, 0.0, 0.0]),
    np.array([0.0, 0.0, 1.0]),
    np.array([0.31, 0.83, 0.46]),
)


def weld_solid(tris: np.ndarray) -> dict:
    """tris (T,3,3). Closed manifold or a fail-closed reason."""
    if tris.size == 0:
        return {"ok": False, "reason": "no_triangles"}
    if not np.isfinite(tris).all():
        return {"ok": False, "reason": "nonfinite"}
    flat = tris.reshape(-1, 3)
    keys = np.round(flat / WELD).astype(np.int64)
    # unique vertices
    _, inv = np.unique(keys, axis=0, return_inverse=True)
    faces = inv.reshape(-1, 3)
    faces = faces[(faces[:, 0] != faces[:, 1]) & (faces[:, 1] != faces[:, 2]) & (faces[:, 2] != faces[:, 0])]
    if len(faces) == 0:
        return {"ok": False, "reason": "no_triangles"}
    e01 = np.sort(faces[:, 0:2], axis=1)
    e12 = np.sort(faces[:, 1:3], axis=1)
    e20 = np.sort(faces[:, [2, 0]], axis=1)
    edges = np.vstack([e01, e12, e20])
    uniq, counts = np.unique(edges, axis=0, return_counts=True)
    if not np.all(counts == 2):
        return {"ok": False, "reason": "open_or_nonmanifold", "bad_edges": int(np.sum(counts != 2))}
    verts = np.zeros((inv.max() + 1, 3), dtype=np.float64)
    # first occurrence position
    order = np.argsort(inv, kind="stable")
    first = np.unique(inv, return_index=True)[1]
    verts[inv[first]] = flat[first]
    out = verts[faces]
    return {
        "ok": True,
        "reason": "closed",
        "tris": out,
        "min": out.reshape(-1, 3).min(axis=0),
        "max": out.reshape(-1, 3).max(axis=0),
    }


def _ray_kind(orig: np.ndarray, direction: np.ndarray, tris: np.ndarray) -> np.ndarray:
    """Per point: 0 outside-clean, 1 inside-clean, 2 indeterminate. orig (N,3), tris (T,3,3)."""
    n = len(orig)
    if n == 0:
        return np.zeros(0, dtype=np.int8)
    v0, v1, v2 = tris[:, 0], tris[:, 1], tris[:, 2]
    e1 = v1 - v0
    e2 = v2 - v0
    pvec = np.cross(direction, e2)
    det = np.einsum("ij,ij->i", e1, pvec)
    safe = np.abs(det) > 1e-12
    inv_det = np.zeros_like(det)
    inv_det[safe] = 1.0 / det[safe]
    # chunk points to bound memory
    kind = np.zeros(n, dtype=np.int8)
    step = 128
    for s in range(0, n, step):
        o = orig[s : s + step]
        tvec = o[:, None, :] - v0[None, :, :]
        u = np.einsum("ntj,tj->nt", tvec, pvec) * inv_det
        qvec = np.cross(tvec, e1)
        v = np.einsum("ntj,j->nt", qvec, direction) * inv_det
        t = np.einsum("ntj,tj->nt", qvec, e2) * inv_det
        w = 1.0 - u - v
        miss = (~safe)[None, :] | (u < -1e-8) | (u > 1.0 + 1e-8) | (v < -1e-8) | (u + v > 1.0 + 1e-8) | (t <= MARGIN)
        graze = (~miss) & ((u < BARY) | (v < BARY) | (w < BARY))
        hit = (~miss) & (~graze)
        grazed = graze.any(axis=1)
        count = hit.sum(axis=1)
        block = np.where(grazed, 2, np.where(count % 2 == 1, 1, 0)).astype(np.int8)
        kind[s : s + len(o)] = block
    return kind


def points_vs_solid(pts: np.ndarray, solid: dict) -> np.ndarray:
    """0 outside, 1 inside, 2 indeterminate."""
    n = len(pts)
    out = np.zeros(n, dtype=np.int8)
    if n == 0:
        return out
    if not solid["ok"]:
        return np.full(n, 2, dtype=np.int8)
    mn, mx = solid["min"], solid["max"]
    inside_box = np.all((pts >= mn - MARGIN) & (pts <= mx + MARGIN), axis=1)
    out[~inside_box] = 0
    idx = np.nonzero(inside_box)[0]
    if len(idx) == 0:
        return out
    votes_in = np.zeros(len(idx), dtype=bool)
    votes_out = np.zeros(len(idx), dtype=bool)
    for d in DIRS:
        direction = d / np.linalg.norm(d)
        kind = _ray_kind(pts[idx], direction, solid["tris"])
        votes_in |= kind == 1
        votes_out |= kind == 0
    disagree = votes_in & votes_out
    decided_in = votes_in & ~votes_out
    decided_out = votes_out & ~votes_in
    out[idx[decided_in]] = 1
    out[idx[decided_out]] = 0
    out[idx[disagree | ~(votes_in | votes_out)]] = 2
    return out


def transverse_any(head_tris: np.ndarray, rail: np.ndarray) -> str:
    """'transverse', 'separate', or 'graze'. head_tris (H,3,3) already near the rail."""
    if len(head_tris) == 0:
        return "separate"
    # three edges
    edges = np.stack(
        [
            np.stack([head_tris[:, 0], head_tris[:, 1]], axis=1),
            np.stack([head_tris[:, 1], head_tris[:, 2]], axis=1),
            np.stack([head_tris[:, 2], head_tris[:, 0]], axis=1),
        ],
        axis=1,
    ).reshape(-1, 2, 3)
    v0, v1, v2 = rail[:, 0], rail[:, 1], rail[:, 2]
    n = np.cross(v1 - v0, v2 - v0)
    grazed = False
    step = 64
    for s in range(0, len(edges), step):
        p0 = edges[s : s + step, 0]
        p1 = edges[s : s + step, 1]
        direction = p1 - p0
        # (E,T)
        e = len(p0)
        tvec = p0[:, None, :] - v0[None, :, :]
        denom = np.einsum("ij,ej->ei", n, direction)
        safe = np.abs(denom) > 1e-12
        inv = np.zeros_like(denom)
        inv[safe] = 1.0 / denom[safe]
        t = np.einsum("ij,eij->ei", n, tvec) * inv  # n · (v0 - p0) / denom wait sign
        # n·(a-p0)/denom = -n·(p0-a)/denom. Use t = n·(v0-p0) / n·dir ? 
        # standard t = dot(n, v0-p0) / dot(n, dir) = -dot(n, p0-v0)/dot(n,dir)
        t = np.einsum("ij,eij->ei", n, (v0[None, :, :] - p0[:, None, :])) * inv
        hitp = p0[:, None, :] + direction[:, None, :] * t[:, :, None]
        # barycentric
        # area vector n
        area2 = np.einsum("ij,ij->i", n, n)
        def bary(p):
            # p (E,T,3)
            u = np.einsum("eti,ti->et", np.cross(v1[None, :, :] - p, v2[None, :, :] - p), n) / area2
            v = np.einsum("eti,ti->et", np.cross(v2[None, :, :] - p, v0[None, :, :] - p), n) / area2
            w = 1.0 - u - v
            return u, v, w
        u, v, w = bary(hitp)
        miss = (~safe) | (t <= 0.0) | (t >= 1.0) | (u < -1e-8) | (v < -1e-8) | (w < -1e-8)
        # endpoint exclusion in metres
        near0 = np.linalg.norm(hitp - p0[:, None, :], axis=2) < EDGE
        near1 = np.linalg.norm(hitp - p1[:, None, :], axis=2) < EDGE
        graze = (~miss) & (near0 | near1 | (u < BARY) | (v < BARY) | (w < BARY))
        good = (~miss) & (~graze)
        if good.any():
            return "transverse"
        if graze.any():
            grazed = True
    return "graze" if grazed else "separate"


def load_rails(geom_path: Path, names: tuple[str, ...]) -> list[dict]:
    raw = json.loads(geom_path.read_text())
    solids = []
    for item in raw:
        if item["path"] not in names:
            continue
        idx = np.asarray(item["indices"], dtype=np.int64)
        verts = np.asarray(item["vertices"], dtype=np.float64)
        tris = verts[idx].reshape(-1, 3, 3)
        solid = weld_solid(tris)
        solid["path"] = item["path"]
        solids.append(solid)
    return solids


def opaque_ranges(meta: dict, glow: bool) -> list[tuple[int, int, np.ndarray]]:
    out = []
    for s in meta["surfaces"]:
        mesh = s["mesh"]
        if mesh not in ("Smiles_Head", "Smiles_Visor"):
            continue
        is_glow = "glow" in s["material"]
        if is_glow != glow:
            continue
        idx = np.asarray(s["indices"], dtype=np.int64) + int(s["start"])
        out.append((int(s["start"]), int(s["count"]), idx))
    return out


def measure_stream(bin_path: Path, meta: dict, rails: list[dict], glow: bool) -> dict:
    ranges = opaque_ranges(meta, glow)
    if not ranges:
        return {"ok": False, "reason": "no_part"}
    arr = np.fromfile(bin_path, dtype="<f4")
    frames = int(meta["clips"][bin_path.stem.split("_")[-1]]["frames"]) if False else None
    # shape from file size and vertex count
    nvert = int(meta["vertices"])
    if arr.size % (nvert * 3) != 0:
        return {"ok": False, "reason": "bad_stride"}
    nframes = arr.size // (nvert * 3)
    pos = arr.reshape(nframes, nvert, 3).astype(np.float64)
    if not np.isfinite(pos).all():
        return {"ok": False, "reason": "nonfinite_positions"}
    index_sets = [idx for _, _, idx in ranges]
    # local index bound
    for s in meta["surfaces"]:
        if s["mesh"] not in ("Smiles_Head", "Smiles_Visor"):
            continue
        if ("glow" in s["material"]) != glow:
            continue
        if len(s["indices"]) and max(s["indices"]) >= s["count"]:
            return {"ok": False, "reason": "index_not_local"}
    bad = inside_frames = cross_frames = indet = 0
    witnesses = []
    pts_i = np.unique(np.concatenate(index_sets))
    for fi in range(nframes):
        frame = pos[fi]
        saw_hit = ""
        saw_indet = False
        pts = frame[pts_i]
        for solid in rails:
            if not solid["ok"]:
                saw_indet = True
                continue
            klass = points_vs_solid(pts, solid)
            if (klass == 1).any():
                saw_hit = "hit_inside"
                break
            if (klass == 2).any():
                saw_indet = True
            mn, mx = solid["min"] - 0.02, solid["max"] + 0.02
            tri_list = []
            for idx in index_sets:
                tri = frame[idx].reshape(-1, 3, 3)
                tmn = tri.min(axis=1)
                tmx = tri.max(axis=1)
                near = np.all(tmx >= mn, axis=1) & np.all(tmn <= mx, axis=1)
                if near.any():
                    tri_list.append(tri[near])
            if not tri_list:
                continue
            rel = transverse_any(np.concatenate(tri_list, axis=0), solid["tris"])
            if rel == "transverse":
                saw_hit = "hit_crossing"
                break
            if rel == "graze":
                saw_indet = True
        if saw_hit == "hit_inside":
            inside_frames += 1
            bad += 1
        elif saw_hit == "hit_crossing":
            cross_frames += 1
            bad += 1
        elif saw_indet:
            indet += 1
            bad += 1
        else:
            continue
        if len(witnesses) < 3:
            witnesses.append(fi)
    return {
        "ok": True,
        "frames": nframes,
        "bad": bad,
        "inside_frames": inside_frames,
        "crossing_only_frames": cross_frames,
        "indeterminate_frames": indet,
        "witness_frames": witnesses,
    }


def main() -> int:
    root = Path(os.environ.get("EVIDENCE", "/tmp/frozen-evidence"))
    diag = root / "smiles-v194-fixture" / "diagnostics"
    out_path = Path(os.environ.get("OUT", "/opt/cursor/artifacts/frozen_head_rail_measure.json"))
    pc = load_rails(diag / "geometry_pc.json", ("greybox/RailFar", "greybox/RailNear", "greybox/RailLeft", "greybox/RailRight", "hearth/Visual/Rails/rails"))
    mobile = load_rails(diag / "geometry_mobile.json", ("greybox/RailFar", "greybox/RailNear", "greybox/RailLeft", "greybox/RailRight", "hearth/Visual/Rails/rails_mobile"))
    by_name = {s["path"]: s for s in pc + mobile}
    report = {"rails": {k: {"ok": v["ok"], "reason": v["reason"], "triangles": int(len(v["tris"])) if v["ok"] else 0} for k, v in by_name.items()}}
    # point controls on hearth PC, before the long scan
    hearth = by_name["hearth/Visual/Rails/rails"]
    controls = {
        "jaw_inside": points_vs_solid(np.array([[-0.419990689, 0.021211118, -0.610123754]]), hearth)[0].item(),
        "outside_footprint": points_vs_solid(np.array([[-0.420674, 0.018086, -0.802405]]), hearth)[0].item(),
        "above_real_surface": points_vs_solid(np.array([[-0.42, 0.108872, -0.592908]]), hearth)[0].item(),
    }
    report["point_controls_0out_1in_2indet"] = controls
    print("rails", report["rails"], "controls", controls, flush=True)
    if controls["jaw_inside"] != 1 or controls["outside_footprint"] != 0 or controls["above_real_surface"] != 0:
        print("POINT CONTROLS FAILED; not scanning streams", flush=True)
        out_path.write_text(json.dumps(report, indent=2))
        return 2
    cells = []
    bins = sorted((diag / "native_head").glob("*.bin"))
    for b in bins:
        # name: {label}_{lod}_{seat}_{clip}.bin  label may be baseline/v188/v194
        stem = b.stem
        meta_name = "_".join(stem.split("_")[:3]) + ".json" if stem.startswith("baseline") or stem.startswith("v188") or stem.startswith("v194") else ""
        # baseline_pc_production_idle -> baseline_pc_production.json
        parts = stem.split("_")
        # baseline_pc_production_mc_cheer or v194_pc_fixture_idle
        if parts[0] == "baseline":
            label, lod, seat = "baseline", parts[1], parts[2]
            clip = "_".join(parts[3:])
        else:
            label, lod, seat = parts[0], parts[1], parts[2]
            clip = "_".join(parts[3:])
        meta = json.loads((diag / f"{label}_{lod}_{seat}.json").read_text())
        board_set = []
        solids_pc = [by_name[n] for n in ("greybox/RailFar", "greybox/RailNear", "greybox/RailLeft", "greybox/RailRight")]
        solids_h = [by_name["hearth/Visual/Rails/rails" if lod == "pc" else "hearth/Visual/Rails/rails_mobile"]]
        for board, solids in (("greybox", solids_pc), ("hearth", solids_h)):
            opaque = measure_stream(b, meta, solids, glow=False)
            glow_r = measure_stream(b, meta, solids, glow=True)
            row = {
                "asset": label,
                "lod": lod,
                "seat": seat,
                "board": board,
                "clip": clip,
                "opaque": opaque,
                "glow_native_separate": glow_r,
            }
            cells.append(row)
            print(f"{label} {lod} {seat} {board} {clip} opaque_bad={opaque.get('bad')} indet={opaque.get('indeterminate_frames')} glow_bad={glow_r.get('bad')}", flush=True)
    report["cells"] = cells
    report["distinctions"] = {
        "native": "Smiles_Head and Smiles_Visor positions only",
        "body_chip": "present in the binaries as normalized CPU; not measured",
        "reverse_containment": "unverified",
        "mc_yaw90": "these seats are far-dealer yaw 0, not the MC seat",
        "classifier": "closed-rail ray parity and transverse edges; not min/max vertical",
        "continuous": False,
    }
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(report))
    print("WROTE", out_path, "cells", len(cells), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
