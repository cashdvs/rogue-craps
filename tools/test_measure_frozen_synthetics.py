#!/usr/bin/env python3
"""Regression for the frozen-stream tool. Synthetic geometry only.

Mirrors the QA counterexamples: a Head triangle that cuts a cube without
its own edges hitting, a point 0.5 µm inside a face, and empty inputs.
"""
from __future__ import annotations

import sys
import tempfile
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
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
        incomplete = Path(tmp) / "diagnostics"
        (incomplete / "native_head").mkdir(parents=True)
        (incomplete / "native_head" / "extra.bin").write_bytes(b"\x00\x00\x00\x00")
        errs = m.validate_bundle(incomplete)
        print("incomplete manifest", errs[:3], "count", len(errs))
        check(len(errs) > 0, "a partial file list is not a complete manifest")
    real = Path("/tmp/frozen-evidence/smiles-v194-fixture/diagnostics")
    if real.is_dir():
        live = m.validate_bundle(real)
        print("frozen manifest errors", live[:4], "count", len(live))
        check(live == [], "the extracted frozen bundle matches the expected manifest")
    print(f"{failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
