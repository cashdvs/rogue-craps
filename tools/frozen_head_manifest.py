"""Expected fixture manifest for the frozen Head/Visor bundle.

The supported seats are the production play seat and the Hearth capture
fixture, each under an identity parent and yaw 0. The MC seat (yaw 90) is
named and is not a measured stream. Actor and skeleton are checked against
that full parent-relative matrix. Agreement between the two blocks is not
enough: a shared bogus origin still fails.

Clip times must be the 60 Hz cadence. Head and Visor triangles must be
nonempty and must match the recorded start/count/index layout. File bytes
must match the transferred SHA256 inventory.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np

CLIPS = {"idle": 181, "deal": 61, "taunt": 85, "grudging": 97, "cheat": 73, "mc_idle": 145, "mc_cheer": 73}
ASSETS = ("baseline", "v188", "v194")
LODS = ("pc", "mobile")
SEATS = ("production", "fixture")
_EXPECTED_PATH = Path(__file__).with_name("frozen_head_expected.json")
_PARENT = np.array([[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0], [0.0, 0.0, 0.0]], dtype=np.float64)


def load_expected() -> dict:
    """The committed fixture manifest. Not a count of whatever files exist."""
    return json.loads(_EXPECTED_PATH.read_text())


def world_matrix(parent: np.ndarray, yaw_deg: float, local: np.ndarray) -> np.ndarray:
    """Full 4x3 world rows: parent * yaw-about-Y * local origin.

    Identity parent and yaw 0 leave `local` as the world origin. A rotated
    parent changes the basis as well as the origin. Callers compare both
    actor and skeleton to this matrix.
    """
    rad = float(np.deg2rad(yaw_deg))
    c, s = float(np.cos(rad)), float(np.sin(rad))
    yaw = np.array([[c, 0.0, s], [0.0, 1.0, 0.0], [-s, 0.0, c]], dtype=np.float64)
    basis = parent[:3] @ yaw
    origin = parent[:3] @ np.asarray(local, dtype=np.float64) + parent[3]
    return np.vstack([basis, origin])


def expected_actor(seat: str, manifest: dict | None = None) -> np.ndarray:
    """World matrix of one supported seat. MC is not supported."""
    doc = manifest if manifest is not None else load_expected()
    if seat not in doc["seats"]:
        raise KeyError(seat)
    local = np.asarray(doc["seats"][seat]["local"], dtype=np.float64)
    return world_matrix(_PARENT, float(doc["yaw_deg"]), local)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _matrix_ok(rows: list, want: np.ndarray) -> bool:
    got = np.asarray(rows, dtype=np.float64)
    return got.shape == want.shape and np.allclose(got, want, rtol=0.0, atol=1e-5)


def _cadence_ok(info: dict, frames: int) -> bool:
    times = np.asarray(info.get("times", []), dtype=np.float64)
    if times.shape != (frames,):
        return False
    step = np.arange(frames, dtype=np.float64) / 60.0
    if not np.allclose(times, step, rtol=0.0, atol=1e-6):
        return False
    length = float(info.get("length", -1.0))
    return abs(length - (frames - 1) / 60.0) <= 1e-4


def _surface_errors(meta: dict, expected_surfaces: list) -> list[str]:
    errors: list[str] = []
    surfaces = meta.get("surfaces", [])
    got = [
        (s.get("mesh"), s.get("material"), int(s.get("start", -1)), int(s.get("count", -1)), len(s.get("indices", [])))
        for s in surfaces
    ]
    want = [(s["mesh"], s["material"], int(s["start"]), int(s["count"]), int(s["index_count"])) for s in expected_surfaces]
    if got != want:
        errors.append("surface layout")
    vertices = int(meta.get("vertices", -1))
    spans = sorted((int(s.get("start", -1)), int(s.get("start", -1)) + int(s.get("count", -1))) for s in surfaces)
    covered = bool(spans) and spans[0][0] == 0 and spans[-1][1] == vertices
    if covered:
        for left, right in zip(spans, spans[1:]):
            if left[1] != right[0]:
                covered = False
                break
    if not covered:
        errors.append("surface coverage")
    opaque = {"Smiles_Head": False, "Smiles_Visor": False}
    for s in surfaces:
        idx = s.get("indices", [])
        mesh = str(s.get("mesh"))
        count = int(s.get("count", 0))
        start = int(s.get("start", -1))
        material = str(s.get("material", ""))
        if len(idx) == 0 or len(idx) % 3 != 0:
            errors.append(f"empty triangles {mesh}")
        elif any(i < 0 or i >= count for i in idx):
            errors.append(f"index out of range {mesh}")
        if start < 0 or count <= 0 or start + count > vertices:
            errors.append(f"start/count {mesh}")
        if mesh in opaque and "glow" not in material and len(idx) >= 3 and len(idx) % 3 == 0:
            opaque[mesh] = True
    if not opaque["Smiles_Head"] or not opaque["Smiles_Visor"]:
        errors.append("missing nonempty Head or Visor")
    return errors


def validate_bundle(diag: Path) -> list[str]:
    """Fail closed unless this directory is the expected fixture bundle.

    Structural checks run even when a hash already fails, so an empty index
    list or a wrong origin is visible. A hash match is the inventory binding.
    """
    errors: list[str] = []
    if sum(CLIPS.values()) != 715:
        errors.append("clip frame table is not 715")
    manifest = load_expected()
    files: dict = manifest["files"]
    expected_names: list[str] = []
    for asset in ASSETS:
        for lod in LODS:
            for seat in SEATS:
                name = f"{asset}_{lod}_{seat}.json"
                expected_names.append(name)
                spec = files.get(name)
                path = diag / name
                if spec is None or not path.is_file():
                    errors.append(f"missing metadata {name}")
                    continue
                if path.stat().st_size != int(spec["bytes"]) or _sha256(path) != spec["sha256"]:
                    errors.append(f"{name} sha256")
                meta = json.loads(path.read_text())
                if meta.get("label") != asset or meta.get("lod") != lod or meta.get("seat") != seat:
                    errors.append(f"{name} label")
                want = expected_actor(seat, manifest)
                if not _matrix_ok(meta.get("actor", []), want) or not _matrix_ok(meta.get("skeleton", []), want):
                    errors.append(f"{name} transform")
                if int(meta.get("vertices", -1)) != int(spec["vertices"]):
                    errors.append(f"{name} vertices")
                if set(meta.get("clips", {})) != set(CLIPS):
                    errors.append(f"{name} clips")
                else:
                    for clip, frames in CLIPS.items():
                        if int(meta["clips"][clip].get("frames", -1)) != frames or not _cadence_ok(meta["clips"][clip], frames):
                            errors.append(f"{name} {clip} cadence")
                        expected_names.append(f"native_head/{asset}_{lod}_{seat}_{clip}.bin")
                for item in _surface_errors(meta, spec["surfaces"]):
                    errors.append(f"{name} {item}")
    for name, spec in files.items():
        if not name.endswith(".bin") and not name.startswith("geometry_"):
            continue
        path = diag / name
        if not path.is_file():
            errors.append(f"missing {name}")
            continue
        if path.stat().st_size != int(spec["bytes"]) or _sha256(path) != spec["sha256"]:
            errors.append(f"{name} sha256")
    found = sorted(p.name for p in (diag / "native_head").glob("*.bin")) if (diag / "native_head").is_dir() else []
    wanted = sorted(Path(n).name for n in expected_names if n.startswith("native_head/"))
    if found != wanted:
        errors.append(f"stream manifest {len(found)} files, expected {len(wanted)}")
    return errors
