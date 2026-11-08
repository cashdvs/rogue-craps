#!/usr/bin/env python3
"""Regression for the frozen-stream tool. Synthetic geometry only.

Mirrors the QA counterexamples: a Head triangle that cuts a cube without
its own edges hitting, a point 0.5 µm inside a face, and empty inputs.
"""
from __future__ import annotations

import os
import shutil
import sys
import tempfile
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import frozen_head_manifest as manifest
import measure_frozen_head_rails as m


def main() -> int:
    failed = 0

    def check(cond: bool, msg: str) -> None:
        nonlocal failed
        print(("OK  " if cond else "FAIL ") + msg)
        if not cond:
            failed += 1

    verts = np.array(
        [[-1, -1, -1], [-1, -1, 1], [-1, 1, -1], [-1, 1, 1], [1, -1, -1], [1, -1, 1], [1, 1, -1], [1, 1, 1]],
        dtype=float,
    )
    faces = np.array([[0, 4, 5], [0, 5, 1], [2, 3, 7], [2, 7, 6], [0, 2, 6], [0, 6, 4], [1, 5, 7], [1, 7, 3], [0, 1, 3], [0, 3, 2], [4, 6, 7], [4, 7, 5]])
    solid = m.weld_solid(verts[faces])
    head = np.array([[[-4.0, 0.0, -4.0], [4.0, 0.0, -4.0], [0.0, 0.0, 4.0]]], dtype=float)
    check(m._edges_vs_tris(head, solid["tris"]) == "separate", "Head edges miss the cube")
    check(m._edges_vs_tris(solid["tris"], head) == "transverse", "cube edges cut the Head triangle")
    check(m.transverse_any(head, solid["tris"]) == "transverse", "bidirectional surface crossing is transverse")
    points = np.array([[0.0, 0.0, 0.0], [2.0, 0.0, 0.0], [1.0 - 5e-7, 0.0, 0.0], [1.0 - 2e-6, 0.0, 0.0], [1.0, 0.0, 0.0]])
    kinds = m.points_vs_solid(points, solid)
    print("point kinds", kinds.tolist())
    check(int(kinds[0]) == 1, "cube centre is inside")
    check(int(kinds[1]) == 0, "point outside the cube stays outside")
    check(int(kinds[2]) != 0, "0.5 µm inside the face is not certified outside")
    check(int(kinds[4]) != 1, "the face point itself is not counted as penetration")
    nested = m.weld_solid(np.concatenate([verts[faces], verts[faces] * 0.5]))
    # A clean tilted ray is even (not a union). Axis rays graze shared
    # edges, so the point is indeterminate rather than a certified outside.
    check(int(m.points_vs_solid(np.array([[0.0, 0.0, 0.0]]), nested)[0]) == 2, "nested-shell center is not certified outside or inside")
    meta = {"vertices": 3, "surfaces": [{"mesh": "Smiles_Head", "material": "opaque", "start": 0, "count": 3, "indices": [0, 1, 2]}]}
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "head.bin"
        path.write_bytes(head.astype("<f4").tobytes())
        hit = m.measure_stream(path, meta, [solid], False)
        print("crossing stream", hit)
        check(hit.get("ok") is True and hit.get("bad") == 1, "slicing triangle is one bad frame")
        missing = m.measure_stream(path, meta, [], False)
        print("missing rails", missing)
        check(missing.get("ok") is False, "empty rail list fails closed")
        empty = Path(tmp) / "empty.bin"
        empty.write_bytes(b"")
        blank = m.measure_stream(empty, meta, [solid], False)
        print("empty stream", blank)
        check(blank.get("ok") is False and blank.get("frames") == 0, "empty stream fails closed")
        wrong_frames = m.measure_stream(path, meta, [solid], False, expected_frames=2)
        print("frame mismatch", wrong_frames)
        check(wrong_frames.get("ok") is False and wrong_frames.get("reason") == "frame_count", "expected_frames rejects a short stream")
        empty_idx = {
            "vertices": 3,
            "surfaces": [{"mesh": "Smiles_Head", "material": "opaque", "start": 0, "count": 3, "indices": []}],
        }
        bare = m.measure_stream(path, empty_idx, [solid], False, 1)
        print("empty indices stream", bare)
        check(bare.get("ok") is False, "empty triangle indices are not a clear stream")
        parent = np.eye(4, 3)
        # Identity parent, yaw 0: the full matrix is the seat origin.
        play = manifest.world_matrix(parent, 0.0, np.array([-0.42, -0.35, -0.86]))
        check(np.allclose(play, manifest.expected_actor("production"), atol=1e-8), "production seat is parent times local")
        turned = manifest.world_matrix(manifest.world_matrix(parent, 90.0, np.zeros(3)), 0.0, np.array([-0.42, -0.35, -0.86]))
        check(not np.allclose(turned, play, atol=1e-5), "a rotated parent is a different world transform")
        mc = manifest.world_matrix(parent, 90.0, np.array([-1.32, -0.42, -0.30]))
        check(not np.allclose(mc, manifest.expected_actor("production"), atol=1e-3), "MC yaw 90 is not the production seat")
        check(not np.allclose(mc, manifest.expected_actor("fixture"), atol=1e-3), "MC yaw 90 is not the fixture seat")
        incomplete = Path(tmp) / "diagnostics"
        (incomplete / "native_head").mkdir(parents=True)
        (incomplete / "native_head" / "extra.bin").write_bytes(b"\x00\x00\x00\x00")
        errs = m.validate_bundle(incomplete)
        print("incomplete manifest", errs[:3], "count", len(errs))
        check(len(errs) > 0, "a partial file list is not a complete manifest")
        # Complete file list, correct seats and cadence, empty required triangles.
        bundle = Path(tmp) / "bundle"
        bdiag = bundle / "smiles-v194-fixture" / "diagnostics"
        (bdiag / "native_head").mkdir(parents=True)
        geom_src = Path("/tmp/frozen-evidence/smiles-v194-fixture/diagnostics")
        if geom_src.is_dir():
            shutil.copy(geom_src / "geometry_pc.json", bdiag / "geometry_pc.json")
            shutil.copy(geom_src / "geometry_mobile.json", bdiag / "geometry_mobile.json")
            for asset in m.ASSETS:
                for lod in m.LODS:
                    for seat in m.SEATS:
                        actor = [[1, 0, 0], [0, 1, 0], [0, 0, 1], [-0.42, -0.35 if seat == "production" else -0.47, -0.86]]
                        surfaces = []
                        for i, (mesh, material) in enumerate((("Smiles_Head", "opaque"), ("Smiles_Visor", "opaque"), ("Smiles_Head", "glow"), ("Smiles_Visor", "glow"))):
                            surfaces.append({"mesh": mesh, "material": material, "start": 3 * i, "count": 3, "indices": []})
                        meta_b = {
                            "label": asset, "lod": lod, "seat": seat, "vertices": 12,
                            "actor": actor, "skeleton": [row[:] for row in actor], "surfaces": surfaces,
                            "clips": {clip: {"frames": n, "length": (n - 1) / 60, "times": [i / 60 for i in range(n)]} for clip, n in m.CLIPS.items()},
                        }
                        (bdiag / f"{asset}_{lod}_{seat}.json").write_text(__import__("json").dumps(meta_b))
                        for clip, n in m.CLIPS.items():
                            np.full((n, 12, 3), 10, dtype="<f4").tofile(bdiag / "native_head" / f"{asset}_{lod}_{seat}_{clip}.bin")
            empty_errs = m.validate_bundle(bdiag)
            print("empty-index bundle errors", [e for e in empty_errs if "empty" in e or "layout" in e][:4], "count", len(empty_errs))
            check(any("empty triangles" in e for e in empty_errs), "empty required indices fail the manifest")
            os.environ["EVIDENCE"] = str(bundle)
            os.environ["OUT"] = str(bundle / "out.json")
            rc = m.main()
            report = __import__("json").loads((bundle / "out.json").read_text())
            print("empty-index main", rc, "cells", len(report.get("cells", [])))
            check(rc != 0 and "cells" not in report, "empty required geometry fails the driver before a clear scan")
            poked = bdiag / "baseline_pc_production.json"
            doc = __import__("json").loads(poked.read_text())
            doc["actor"][3][0] = 99
            doc["skeleton"] = [row[:] for row in doc["actor"]]
            doc["clips"]["idle"]["times"] = [0] * 181
            poked.write_text(__import__("json").dumps(doc))
            poked_errs = m.validate_bundle(bdiag)
            print("x99/zero-time errors", [e for e in poked_errs if "transform" in e or "cadence" in e][:4])
            check(any(e.endswith("transform") for e in poked_errs), "actor X=99 fails even when skeleton matches")
            check(any("cadence" in e for e in poked_errs), "all-zero idle times fail the 60 Hz cadence")
    real = Path("/tmp/frozen-evidence/smiles-v194-fixture/diagnostics")
    if real.is_dir():
        live = m.validate_bundle(real)
        print("frozen manifest errors", live[:4], "count", len(live))
        check(live == [], "the extracted frozen bundle matches the expected manifest")
    print(f"{failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
