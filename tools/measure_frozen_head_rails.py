#!/usr/bin/env python3
"""Finite-solid Head/Visor check on the frozen native streams.

Reads the extracted QA bundle (EVIDENCE, default /tmp/frozen-evidence).
Only Smiles_Head and Smiles_Visor vertices are tested. Glow materials on
those meshes are counted apart from the opaque shell. Body and Chip slots
in the same binaries stay normalized-CPU and are not measured.

This is ray-parity through the closed rail plus transverse edge hits in
both directions (each mesh's edges against the other's triangles). A Head
triangle can cut a rail even when every Head edge misses it. That surface
test is not reverse containment: the open head is still not a closed solid.

A hit closer than 1 µm is unresolved, not outside. Zero bad frames means
this sample detected nothing, not a solid-clearance certificate.

It does not use a min/max vertical span at the same XZ.

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
        on = safe[None, :] & (u >= -1e-8) & (v >= -1e-8) & (w >= -1e-8)
        # Within 1 µm of a face the parity is not reliable. That is not
        # "outside", and it is not a penetration tolerance.
        near = on & (np.abs(t) <= MARGIN)
        miss = ~on | ((t <= 0.0) & ~near)
        graze = near | ((~miss) & ((u < BARY) | (v < BARY) | (w < BARY)))
        hit = (~miss) & (~graze) & (t > MARGIN)
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
    saw_in = np.zeros(len(idx), dtype=bool)
    saw_out = np.zeros(len(idx), dtype=bool)
    saw_ind = np.zeros(len(idx), dtype=bool)
    for d in DIRS:
        direction = d / np.linalg.norm(d)
        kind = _ray_kind(pts[idx], direction, solid["tris"])
        saw_in |= kind == 1
        saw_out |= kind == 0
        saw_ind |= kind == 2
    # An unresolved ray must not be outvoted into a clearance.
    inside = saw_in & ~saw_out
    outside = saw_out & ~saw_in & ~saw_ind
    out[idx[inside]] = 1
    out[idx[outside]] = 0
    out[idx[~(inside | outside)]] = 2
    return out


def _edges_vs_tris(src: np.ndarray, dst: np.ndarray) -> str:
    """Edges of src against triangles of dst. 'transverse', 'graze', or 'separate'."""
    edges = np.stack(
        [
            np.stack([src[:, 0], src[:, 1]], axis=1),
            np.stack([src[:, 1], src[:, 2]], axis=1),
            np.stack([src[:, 2], src[:, 0]], axis=1),
        ],
        axis=1,
    ).reshape(-1, 2, 3)
    dmin = dst.min(axis=(0, 1)) - EDGE
    dmax = dst.max(axis=(0, 1)) + EDGE
    emin = edges.min(axis=1)
    emax = edges.max(axis=1)
    edges = edges[np.all(emax >= dmin, axis=1) & np.all(emin <= dmax, axis=1)]
    if len(edges) == 0:
        return "separate"
    v0, v1, v2 = dst[:, 0], dst[:, 1], dst[:, 2]
    n = np.cross(v1 - v0, v2 - v0)
    grazed = False
    step = 64
    for s in range(0, len(edges), step):
        p0 = edges[s : s + step, 0]
        p1 = edges[s : s + step, 1]
        direction = p1 - p0
        denom = np.einsum("ij,ej->ei", n, direction)
        safe = np.abs(denom) > 1e-12
        inv = np.zeros_like(denom)
        inv[safe] = 1.0 / denom[safe]
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


def transverse_any(a_tris: np.ndarray, b_tris: np.ndarray) -> str:
    """Surface crossing either way. Not reverse solid containment.

    Head edges can miss a rail while a rail edge still cuts the Head
    triangle. Both directions are required. Coplanar contact is not a hit.
    """
    if len(a_tris) == 0 or len(b_tris) == 0:
        return "separate"
    ab = _edges_vs_tris(a_tris, b_tris)
    if ab == "transverse":
        return "transverse"
    ba = _edges_vs_tris(b_tris, a_tris)
    if ba == "transverse":
        return "transverse"
    if ab == "graze" or ba == "graze":
        return "graze"
    return "separate"


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


def measure_stream(bin_path: Path, meta: dict, rails: list[dict], glow: bool, expected_frames: int | None = None) -> dict:
    if not rails or any(not s.get("ok") for s in rails):
        return {"ok": False, "reason": "no_rails", "frames": 0, "bad": 0, "indeterminate_frames": 0}
    ranges = opaque_ranges(meta, glow)
    if not ranges:
        return {"ok": False, "reason": "no_part", "frames": 0, "bad": 0, "indeterminate_frames": 0}
    for start, count, idx in ranges:
        local = idx - start
        if local.size and (int(local.min()) < 0 or int(local.max()) >= count):
            return {"ok": False, "reason": "index_out_of_range", "frames": 0, "bad": 0, "indeterminate_frames": 0}
    arr = np.fromfile(bin_path, dtype="<f4")
    nvert = int(meta["vertices"])
    if nvert <= 0 or arr.size == 0 or arr.size % (nvert * 3) != 0:
        return {"ok": False, "reason": "empty_stream", "frames": 0, "bad": 0, "indeterminate_frames": 0}
    nframes = arr.size // (nvert * 3)
    if nframes == 0 or (expected_frames is not None and nframes != expected_frames):
        return {"ok": False, "reason": "frame_count", "frames": nframes, "bad": 0, "indeterminate_frames": 0}
    pos = arr.reshape(nframes, nvert, 3).astype(np.float64)
    if not np.isfinite(pos).all():
        return {"ok": False, "reason": "nonfinite_positions", "frames": nframes, "bad": 0, "indeterminate_frames": 0}
    index_sets = [idx for _, _, idx in ranges]
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
        if len(witnesses) < 40:
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


CLIPS = {"idle": 181, "deal": 61, "taunt": 85, "grudging": 97, "cheat": 73, "mc_idle": 145, "mc_cheer": 73}
ASSETS = ("baseline", "v188", "v194")
LODS = ("pc", "mobile")
SEATS = ("production", "fixture")


def _identity_basis(rows: list) -> bool:
    m = np.asarray(rows[:3], dtype=np.float64)
    return m.shape == (3, 3) and np.allclose(m, np.eye(3), atol=1e-5)


def validate_bundle(diag: Path) -> list[str]:
    """Fail closed unless the frozen manifest is complete. Do not count files that merely exist."""
    errors: list[str] = []
    if sum(CLIPS.values()) != 715:
        errors.append("clip frame table is not 715")
    expected = []
    for asset in ASSETS:
        for lod in LODS:
            for seat in SEATS:
                meta_path = diag / f"{asset}_{lod}_{seat}.json"
                if not meta_path.is_file():
                    errors.append(f"missing metadata {meta_path.name}")
                    continue
                meta = json.loads(meta_path.read_text())
                if not _identity_basis(meta["actor"]) or not _identity_basis(meta["skeleton"]):
                    errors.append(f"{meta_path.name} basis")
                if meta["skeleton"] != meta["actor"]:
                    errors.append(f"{meta_path.name} skeleton != actor")
                origin_y = float(meta["actor"][3][1])
                want_y = -0.35 if seat == "production" else -0.47
                if abs(origin_y - want_y) > 1e-5:
                    errors.append(f"{meta_path.name} origin y {origin_y}")
                if set(meta["clips"]) != set(CLIPS):
                    errors.append(f"{meta_path.name} clips")
                for clip, n in CLIPS.items():
                    info = meta["clips"][clip]
                    if int(info["frames"]) != n or len(info["times"]) != n:
                        errors.append(f"{meta_path.name} {clip} frames/times")
                    expected.append(f"{asset}_{lod}_{seat}_{clip}.bin")
                opaque = [s for s in meta["surfaces"] if s["mesh"] in ("Smiles_Head", "Smiles_Visor") and "glow" not in s["material"]]
                if not any(s["mesh"] == "Smiles_Head" for s in opaque) or not any(s["mesh"] == "Smiles_Visor" for s in opaque):
                    errors.append(f"{meta_path.name} missing Head or Visor")
                for s in meta["surfaces"]:
                    idx = s["indices"]
                    if any(i < 0 or i >= s["count"] for i in idx):
                        errors.append(f"{meta_path.name} bad index {s['mesh']}")
                        break
    found = sorted(p.name for p in (diag / "native_head").glob("*.bin"))
    if found != sorted(expected):
        errors.append(f"stream manifest {len(found)} files, expected {len(expected)}")
    return errors


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
    errors = validate_bundle(diag)
    report["manifest_errors"] = errors
    print("rails", report["rails"], "controls", controls, "manifest_errors", len(errors), flush=True)
    if errors:
        print("MANIFEST FAILED", errors[:8], flush=True)
        out_path.write_text(json.dumps(report, indent=2))
        return 2
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
        expected_frames = int(meta["clips"][clip]["frames"])
        board_set = []
        solids_pc = [by_name[n] for n in ("greybox/RailFar", "greybox/RailNear", "greybox/RailLeft", "greybox/RailRight")]
        solids_h = [by_name["hearth/Visual/Rails/rails" if lod == "pc" else "hearth/Visual/Rails/rails_mobile"]]
        for board, solids in (("greybox", solids_pc), ("hearth", solids_h)):
            opaque = measure_stream(b, meta, solids, False, expected_frames)
            glow_r = measure_stream(b, meta, solids, True, expected_frames)
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
        "classifier": "closed-rail ray parity and bidirectional transverse edges; not min/max vertical",
        "surface_crossing": "both edge directions; not reverse solid containment",
        "zero_bad_means": "no detection in this sample, not a solid-clearance certificate",
        "continuous": False,
    }
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(report))
    failed = [c for c in cells if not c["opaque"].get("ok") or not c["glow_native_separate"].get("ok")]
    print("WROTE", out_path, "cells", len(cells), "failed_cells", len(failed), flush=True)
    if len(cells) != 168 or failed:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
