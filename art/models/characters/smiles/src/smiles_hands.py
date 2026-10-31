"""Shared relaxed hand builder (Smiles + every boss). Split out of build_smiles.py (file-size limit);
behaviour unchanged. Bosses call it as bs.build_hand(...)."""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

# ---------------------------------------------------------------- shared relaxed hand (Smiles + every boss)
# Cash playtest (Oct 30): "the hands still look unnatural and weird". The old hands were a flat paddle with four
# dead-straight tubes as long as the palm and a half (rakes / garden forks at the table), and the thumb ran parallel
# to them. A relaxed human hand has fingers about as long as the palm, a cascade of curl (index least, pinky most)
# and a thumb that sits forward of the palm, opposed. The rig has one bone per finger group (index, fingers, thumb),
# so the relaxed curl is SCULPTED into the bind pose (bent at the knuckle, middle and end joints) and the bones only
# add to it. Bone names, heads and count are unchanged.
#   hand frame at rest: hangs down -Z from hand_s (x = sx*0.2, z = -0.085), palm faces the body (-sx X), thumb -Y.
FINGERS = (  # (name, bone, thumb-side offset at the knuckle, length, (knuckle, middle, end joint) curl in degrees, fan deg)
    ("index", "index", 0.024, 0.068, (8, 26, 16), 4),
    ("middle", "fingers", 0.008, 0.074, (12, 32, 20), 0),
    ("ring", "fingers", -0.008, 0.069, (16, 38, 24), -4),
    ("pinky", "fingers", -0.023, 0.055, (22, 44, 28), -9),
)
PHALANX = (0.46, 0.31, 0.23)  # proximal / middle / distal share of the finger length


def hand_point(sx, u, v, w):
    """u = down the hand from the wrist pivot, v = toward the palm side, w = toward the thumb side."""
    return (sx * 0.2 - sx * v, -w, -0.085 - u)


def build_hand(part, s, mat, S, k=1.0, wrist_r=0.021, palm_r=0.037, fr=0.0098, tip=0.0, finger_mat=None,
               palm_flat=0.52, seg_lo=4):
    """Relaxed hand on hand_s / thumb_s / index_s / fingers_s. k scales the whole hand; fr = finger root radius;
    tip = fingertip radius (0 = pointed claw); finger_mat = a different material for the fingers (Collector)."""
    sx = 1 if s == "L" else -1
    H = "hand_" + s
    fm = finger_mat or mat
    pt = lambda u, v, w: hand_point(sx, u * k, v * k, w * k)
    # wrist + palm: palm ~6.6 cm long (wrist crease -> knuckles), ~1.75x the wrist width, a little thicker at the heel
    part.tube([(pt(-0.012, 0, 0), wrist_r * k), (pt(0.018, 0.001, 0), wrist_r * 1.08 * k)], mat, H, seg=S(8, seg_lo))
    part.tube([(pt(0.008, 0.002, 0.0), palm_r * 0.8 * k), (pt(0.042, 0.003, 0.0), palm_r * k), (pt(0.08, -0.002, 0.0), palm_r * 0.86 * k)],
              mat, H, seg=S(10, seg_lo), flat=palm_flat, flat_axis=(1, 0, 0))
    for _n, bone, w0, ln, curl, fan in FINGERS:
        u, v, w = 0.077, 0.004, w0
        a = 0.0
        pts = [(pt(u, v, w), fr * k)]
        rads = (0.95, 0.85, 0.72)
        fw = math.sin(math.radians(fan))
        for j, (share, c) in enumerate(zip(PHALANX, curl)):
            a += math.radians(c)
            seglen = ln * share
            u += math.cos(a) * seglen
            v += math.sin(a) * seglen
            w += fw * seglen * 0.6
            pts.append((pt(u, v, w), fr * rads[j] * k))
        if tip <= 0.0:  # short claw past the fingertip
            a += math.radians(10)
            pts.append((pt(u + math.cos(a) * 0.012, v + math.sin(a) * 0.012, w), 0.0))
        else:
            pts[-1] = (pts[-1][0], max(tip, fr * 0.6) * k)
        part.tube(pts, fm, bone + "_" + s, seg=S(5, seg_lo))
    # thumb: a fat root on the heel of the palm (the thenar pad), angled forward of the palm, bent toward the index
    tp = [(0.024, 0.008, 0.022), (0.05, 0.026, 0.042), (0.074, 0.036, 0.049), (0.088, 0.041, 0.046)]
    pts = [(pt(*tp[0]), fr * 1.7 * k), (pt(*tp[1]), fr * 1.15 * k), (pt(*tp[2]), fr * 0.95 * k), (pt(*tp[3]), fr * (0.72 if tip else 0.6) * k)]
    if tip <= 0.0:
        pts.append((pt(0.097, 0.044, 0.042), 0.0))
    part.tube(pts, mat, "thumb_" + s, seg=S(5, seg_lo))
