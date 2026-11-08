"""Closed-rail classifier used by the frozen Head/Visor measurement.

Kind 0 is a clean outside vote, kind 1 a clean inside vote, kind 2 unresolved.
Kind 2 is fail-closed. Two different events produce it:

- a face hit with |t| <= 1 µm, so the sample sits on the surface within the
  near-origin band;
- a forward ray whose barycentric coordinate is within BARY (1e-5, dimensionless)
  of a triangle edge. That graze can be a metre away. It is not evidence the
  vertex is within 1 µm of the rail, and it is not a penetration.

An unresolved ray is not outvoted into a clearance. Thresholds stay as they are.
Open-shell reverse containment is not this test. Nested even-odd shells are not
a union.
"""
from __future__ import annotations

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
        # |t| <= 1 µm is a near-origin face hit. A barycentric edge graze
        # (BARY, dimensionless) can be far from the point. Either one is
        # unresolved. Neither one is a penetration allowance.
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
