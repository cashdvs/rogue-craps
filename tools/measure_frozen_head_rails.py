#!/usr/bin/env python3
"""Finite-solid Head/Visor check on the frozen native streams.

Reads the extracted QA bundle (EVIDENCE, default /tmp/frozen-evidence).
Only Smiles_Head and Smiles_Visor vertices are tested. Glow materials on
those meshes are counted apart from the opaque shell. Body and Chip slots
in the same binaries stay normalized-CPU and are not measured.

Ray parity and both edge directions live in frozen_head_classifier. The
fixture manifest lives in frozen_head_manifest. Kind 2 stays fail-closed:
it may be a 1 µm face hit or a distant barycentric edge graze. A distant
graze is not a penetration and is not a 1 µm proximity claim. Zero bad
frames means this sample detected nothing, not a solid-clearance certificate.

60 Hz samples with endpoints. Not swept motion, not blends, not the yaw-90
MC seat. Open-head reverse containment is not certified.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import numpy as np

from frozen_head_classifier import _edges_vs_tris, points_vs_solid, transverse_any, weld_solid
from frozen_head_manifest import ASSETS, CLIPS, LODS, SEATS, load_expected, validate_bundle

__all__ = [
    "ASSETS",
    "CLIPS",
    "LODS",
    "SEATS",
    "_edges_vs_tris",
    "load_expected",
    "main",
    "measure_stream",
    "points_vs_solid",
    "transverse_any",
    "validate_bundle",
    "weld_solid",
]


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
    for surface in meta["surfaces"]:
        mesh = surface["mesh"]
        if mesh not in ("Smiles_Head", "Smiles_Visor"):
            continue
        is_glow = "glow" in surface["material"]
        if is_glow != glow:
            continue
        idx = np.asarray(surface["indices"], dtype=np.int64) + int(surface["start"])
        out.append((int(surface["start"]), int(surface["count"]), idx))
    return out


def _fail(reason: str, frames: int = 0) -> dict:
    return {"ok": False, "reason": reason, "frames": frames, "bad": 0, "indeterminate_frames": 0}


def measure_stream(bin_path: Path, meta: dict, rails: list[dict], glow: bool, expected_frames: int | None = None) -> dict:
    """One native stream against closed rails. Empty required triangles fail closed."""
    if not rails or any(not solid.get("ok") for solid in rails):
        return _fail("no_rails")
    ranges = opaque_ranges(meta, glow)
    if not ranges:
        return _fail("no_part")
    for start, count, idx in ranges:
        local = idx - start
        if local.size == 0 or local.size % 3 != 0:
            return _fail("empty_geometry")
        if int(local.min()) < 0 or int(local.max()) >= count:
            return _fail("index_out_of_range")
    arr = np.fromfile(bin_path, dtype="<f4")
    nvert = int(meta["vertices"])
    if nvert <= 0 or arr.size == 0 or arr.size % (nvert * 3) != 0:
        return _fail("empty_stream")
    nframes = arr.size // (nvert * 3)
    if nframes == 0 or (expected_frames is not None and nframes != expected_frames):
        return _fail("frame_count", nframes)
    pos = arr.reshape(nframes, nvert, 3).astype(np.float64)
    if not np.isfinite(pos).all():
        return _fail("nonfinite_positions", nframes)
    index_sets = [idx for _, _, idx in ranges]
    bad = inside_frames = cross_frames = indet = 0
    witnesses = []
    pts_i = np.unique(np.concatenate(index_sets))
    if pts_i.size == 0:
        return _fail("empty_geometry", nframes)
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


def _binding(diag: Path) -> dict:
    manifest = load_expected()
    files = manifest["files"]
    return {
        "source_commit": os.environ.get("SOURCE_COMMIT", ""),
        "expected_manifest": "tools/frozen_head_expected.json",
        "input_sha256": {name: spec["sha256"] for name, spec in files.items()},
        "evidence": str(diag),
    }


def main() -> int:
    root = Path(os.environ.get("EVIDENCE", "/tmp/frozen-evidence"))
    diag = root / "smiles-v194-fixture" / "diagnostics"
    out_path = Path(os.environ.get("OUT", "/opt/cursor/artifacts/frozen_head_rail_measure.json"))
    pc = load_rails(diag / "geometry_pc.json", ("greybox/RailFar", "greybox/RailNear", "greybox/RailLeft", "greybox/RailRight", "hearth/Visual/Rails/rails"))
    mobile = load_rails(diag / "geometry_mobile.json", ("greybox/RailFar", "greybox/RailNear", "greybox/RailLeft", "greybox/RailRight", "hearth/Visual/Rails/rails_mobile"))
    by_name = {solid["path"]: solid for solid in pc + mobile}
    report = {
        "binding": _binding(diag),
        "rails": {key: {"ok": value["ok"], "reason": value["reason"], "triangles": int(len(value["tris"])) if value["ok"] else 0} for key, value in by_name.items()},
    }
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
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if errors:
        print("MANIFEST FAILED", errors[:12], flush=True)
        out_path.write_text(json.dumps(report, indent=2))
        return 2
    if controls["jaw_inside"] != 1 or controls["outside_footprint"] != 0 or controls["above_real_surface"] != 0:
        print("POINT CONTROLS FAILED; not scanning streams", flush=True)
        out_path.write_text(json.dumps(report, indent=2))
        return 2
    cells = []
    bins = sorted((diag / "native_head").glob("*.bin"))
    for stream in bins:
        parts = stream.stem.split("_")
        if parts[0] == "baseline":
            label, lod, seat = "baseline", parts[1], parts[2]
            clip = "_".join(parts[3:])
        else:
            label, lod, seat = parts[0], parts[1], parts[2]
            clip = "_".join(parts[3:])
        meta = json.loads((diag / f"{label}_{lod}_{seat}.json").read_text())
        expected_frames = int(meta["clips"][clip]["frames"])
        solids_pc = [by_name[name] for name in ("greybox/RailFar", "greybox/RailNear", "greybox/RailLeft", "greybox/RailRight")]
        hearth_name = "hearth/Visual/Rails/rails" if lod == "pc" else "hearth/Visual/Rails/rails_mobile"
        for board, solids in (("greybox", solids_pc), ("hearth", [by_name[hearth_name]])):
            opaque = measure_stream(stream, meta, solids, False, expected_frames)
            glow_r = measure_stream(stream, meta, solids, True, expected_frames)
            cells.append({
                "asset": label,
                "lod": lod,
                "seat": seat,
                "board": board,
                "clip": clip,
                "opaque": opaque,
                "glow_native_separate": glow_r,
            })
            print(
                f"{label} {lod} {seat} {board} {clip} opaque_bad={opaque.get('bad')} indet={opaque.get('indeterminate_frames')} glow_bad={glow_r.get('bad')}",
                flush=True,
            )
    report["cells"] = cells
    report["distinctions"] = {
        "native": "Smiles_Head and Smiles_Visor positions only",
        "body_chip": "present in the binaries as normalized CPU; not measured",
        "reverse_containment": "unverified",
        "mc_yaw90": "these seats are far-dealer yaw 0, not the MC seat",
        "classifier": "closed-rail ray parity and bidirectional transverse edges; not min/max vertical",
        "surface_crossing": "both edge directions; not reverse solid containment",
        "indeterminate_cause": "Kind 2 is unresolved. It includes a distant barycentric edge graze (BARY=1e-5) as well as a face hit within 1 µm. A distant graze is not a 1 µm proximity claim and is not a penetration.",
        "zero_bad_means": "no detection in this sample, not a solid-clearance certificate",
        "continuous": False,
    }
    out_path.write_text(json.dumps(report))
    failed = [cell for cell in cells if not cell["opaque"].get("ok") or not cell["glow_native_separate"].get("ok")]
    print("WROTE", out_path, "cells", len(cells), "failed_cells", len(failed), flush=True)
    if len(cells) != 168 or failed:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
