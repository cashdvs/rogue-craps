"""Smiles poses and clips: arm IK authoring helpers, the base stance, every clip (CLIPS) and the action
baker make_actions(). Split out of build_smiles.py (file-size limit); behaviour unchanged. Bosses read and
patch bs.CLIPS (the same dict object) and call bs.make_actions."""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

from smiles_rig import BONES, FPS, GLOW_BONES


# ---------------------------------------------------------------- poses / clips
def mirror(p):
    """Pose dict with L/R swapped (yaw / roll flip)."""
    out = {}
    for k, v in p.items():
        k2 = k.replace("_L", "_#").replace("_R", "_L").replace("_#", "_R")
        out[k2] = (v[0], -v[1], -v[2]) + tuple(v[3:])
    return out


# ---- 2-bone arm IK (authoring only: solved to plain FK rotations, nothing exported but the keys)
def _local_euler(r_arm):
    """Armature-space rotation -> euler degrees in the (shared) bone-local frame."""
    m = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0))).transposed()  # columns = bone X, Y(up), Z(-fwd) in armature space
    e = (m.inverted() @ r_arm @ m).to_euler("XYZ")
    return tuple(round(math.degrees(a), 2) for a in e)


def _arm_mat(e):
    """Bone-local euler degrees -> armature-space rotation (inverse of _local_euler)."""
    m = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0))).transposed()
    return m @ Euler([math.radians(a) for a in e], "XYZ").to_matrix() @ m.inverted()


def arm(s, wrist, pole, twist=0.0, hand=(0, 0, 0), fingers=None, roll=0.0, palm=None, sh=None):
    """Pose upper_arm_s / forearm_s so the wrist lands on `wrist` (armature rest coords, i.e. relative to the
    unposed chest; the chest / spine lean carries it). pole = a point the elbow bends toward.
    palm (with fingers): armature-space direction the palm should face. Without it the palm roll is whatever
    the forearm twist leaves (it depends on the elbow pole), so two hands with mirrored wrists / fingers can
    still end up rolled 180 deg apart (both thumbs to the same side). Give mirrored palms for mirrored hands.
    sh: shoulder_s euler (bone-local degrees: X = round forward / back, Z = shrug up when sx * Z < 0 ... see SHRUG).
    The IK is solved from the moved shoulder, so the wrist still lands on `wrist` and the shoulders can move
    with the gesture (before, the shoulders never moved in any clip: the stiff "coat hanger" read)."""
    Rsh = _arm_mat(sh) if sh else Matrix.Identity(3)
    SH = Vector(BONES["shoulder_" + s][1])
    S = SH + Rsh @ (Vector(BONES["upper_arm_" + s][1]) - SH)
    S_rest = Vector(BONES["upper_arm_" + s][1])
    E0 = Vector(BONES["forearm_" + s][1])
    W0 = Vector(BONES["hand_" + s][1])
    a, b = (E0 - S_rest).length, (W0 - E0).length
    W = Vector(wrist)
    d = min((W - S).length, a + b - 1e-4)
    n = (W - S).normalized()
    x = (a * a - b * b + d * d) / (2 * d)
    h = math.sqrt(max(a * a - x * x, 0.0))
    pv = Vector(pole) - S
    pv = (pv - n * pv.dot(n)).normalized()
    E = S + n * x + pv * h
    Wr = S + n * d
    ru = (E0 - S_rest).rotation_difference(E - S).to_matrix()  # world (armature) rotation of the upper arm
    fw = ru.inverted() @ (Wr - E)  # wrist direction in the upper arm's posed frame
    rf = (W0 - E0).rotation_difference(fw).to_matrix()
    if twist:
        rf = Matrix.Rotation(math.radians(twist), 3, (W0 - E0).normalized()) @ rf
    out = {"upper_arm_" + s: _local_euler(Rsh.inverted() @ ru), "forearm_" + s: _local_euler(rf), "hand_" + s: hand}
    out["shoulder_" + s] = tuple(sh) if sh else (0, 0, 0)  # always keyed: an arm solved from the rest shoulder must not inherit a moved one
    if fingers is not None:  # aim the hand (wrist -> knuckles) along an armature-space direction
        rest = Vector((0, -0.004, -0.085))
        want = (ru @ rf).inverted() @ Vector(fingers).normalized()
        rh = rest.rotation_difference(want).to_matrix()
        if palm is not None:  # roll about the wrist -> knuckles axis until the palm faces `palm`
            fw_w = Vector(fingers).normalized()
            cur = (ru @ rf @ rh) @ Vector((-1 if s == "L" else 1, 0, 0))  # palm faces the body at rest: -sx X
            cur = (cur - fw_w * cur.dot(fw_w)).normalized()
            tgt = Vector(palm) - fw_w * Vector(palm).dot(fw_w)
            if tgt.length > 1e-4:
                tgt.normalize()
                ang = math.atan2(fw_w.dot(cur.cross(tgt)), cur.dot(tgt))
                rh = Matrix.Rotation(ang, 3, want) @ rh
        if roll:  # spin the hand about its own wrist -> knuckles axis (palm direction)
            rh = Matrix.Rotation(math.radians(roll), 3, want) @ rh
        out["hand_" + s] = _local_euler(rh)
    return out


def shd(s, fwd=0.0, up=0.0):
    """shoulder_s euler: fwd rounds the shoulder forward (toward the table), up shrugs it."""
    sx = 1 if s == "L" else -1
    return (0.0, -sx * fwd, sx * up)


# Base standing pose: leaning in over the rail, face up toward the game camera, hands steepled.
STAND = {
    "spine": (3, 0, 0), "chest": (4, 0, 0), "neck": (-16, 0, 0), "head": (-26, 0, 0),
    **arm("L", (0.065, -0.04, 0.36), (0.35, 0.25, 0.0), fingers=(-0.35, 0.02, 1), sh=shd("L", 4, -1)), **arm("R", (-0.065, -0.04, 0.36), (-0.35, 0.25, 0.0), fingers=(0.35, 0.02, 1), sh=shd("R", 4, -1)),
    "index_L": (0, 0, -6), "fingers_L": (0, 0, -10), "thumb_L": (0, 0, -8),
    "index_R": (0, 0, 6), "fingers_R": (0, 0, 10), "thumb_R": (0, 0, 8),
}


def P(base, *more, **kw):
    d = dict(base)
    for m in more:
        d.update(m)
    for k, v in kw.items():
        d[k] = v
    return d


def curl(s, a):
    """Fist / curl toward the palm (palm faces the body)."""
    sg = -1 if s == "L" else 1
    return {"index_" + s: (0, 0, sg * a), "fingers_" + s: (0, 0, sg * a * 1.1), "thumb_" + s: (0, 0, sg * a * 0.6)}


CLIPS = {}


# Visor rim read (AD final): on these clips his head sits further back than in idle / cheat, so the brim's top and
# its pale-green rim turn away from the lamp and go dark. Tip the visor toward the camera on every key that does not
# key the visor itself (the cheat tell keeps its own, larger tip).
VISOR_TIP = {"taunt": 15, "grudging": 15, "deal": 15}


def clip(name, length_s, keys, loop=False):
    tip = VISOR_TIP.get(name, 0)
    if tip:
        keys = [(t, p if "visor" in p else {**p, "visor": (tip, 0, 0)}) for t, p in keys]
    CLIPS[name] = (length_s, keys, loop)


# idle (3.0 s loop): leans low on the far rail, both forearms on it; the right hand rolls a chip over its
# knuckles just above the rail top (inside the phone band, clear of the brazier and plaque), grin twitch, head sway.
# Both forearms rest on the rail palms DOWN (knuckles up; the chip rolls over the back of the right hand).
# palm= pins each hand's roll so the two hands mirror (before: left palm down, right palm up = two "right hands").
IDLE_PALM = (0, -0.2, -1)
# Natural-hands pass (Cash, Oct 30): the wrists were cocked UP (fingers 15 deg above the forearm line) with the
# shoulders square; now the wrists sit near neutral (a few degrees of droop over the rail), the sculpted finger curl
# hangs off the rail edge, and both shoulders round forward onto the forearms and rise / settle with the breath.
_lean = arm("L", (0.1, -0.05, 0.677), (0.17, 0.35, 0.05), fingers=(-0.35, -1, 0.42), palm=IDLE_PALM, sh=shd("L", 7, 2))
_lean2 = arm("L", (0.1, -0.052, 0.68), (0.17, 0.35, 0.05), fingers=(-0.33, -1, 0.42), palm=IDLE_PALM, sh=shd("L", 8, 4))
# fingers draped on the rail: the sculpted curl is eased open a little so the tips rest on the rail, not in it
_rail_fingers = {"index_L": (0, 0, 18), "fingers_L": (0, 0, 22), "thumb_L": (0, 0, 14), "index_R": (0, 0, -18), "fingers_R": (0, 0, -22), "thumb_R": (0, 0, -14)}
_chip_hand = P(STAND, _lean, _rail_fingers, arm("R", (-0.17, -0.05, 0.679), (-0.45, 0.3, 0.1), fingers=(0.3, -1, 0.4), palm=IDLE_PALM, sh=shd("R", 6, 2)), spine=(6, 0, 0), chest=(10, 0, 0))
_chip_hand2 = P(STAND, _lean2, _rail_fingers, arm("R", (-0.17, -0.055, 0.687), (-0.45, 0.3, 0.1), fingers=(0.35, -1, 0.42), palm=IDLE_PALM, sh=shd("R", 7, 4)), spine=(6, 0, 0), chest=(10, 0, 0))
clip("idle", 3.0, [
    (0.0, P(_chip_hand, chip=(0, 0, 0, -0.025, 0, 0))),
    (0.5, P(_chip_hand2, chest=(10, 0, 0), chip=(90, 0, 0, -0.025, -0.012, 0))),
    (1.0, P(_chip_hand2, chest=(10, 0, 0), head=(-24, 0, 4), chip=(180, 0, 0, -0.025, -0.024, 0), index_R=(0, 0, 2))),
    (1.4, P(_chip_hand2, chest=(10, 0, 0), head=(-26, 0, 5), jaw=(6, 0, 0), grin_L=(0, 0, 8), grin_R=(0, 0, -8), chip=(260, 0, 0, -0.025, -0.03, 0), index_R=(0, 0, 2))),
    (1.7, P(_chip_hand2, chest=(10, 0, 0), head=(-25, 0, 3), jaw=(0, 0, 0), chip=(300, 0, 0, -0.025, -0.02, 0))),
    (2.2, P(_chip_hand, chest=(10, 0, 0), head=(-23, 0, 0), chip=(340, 0, 0, -0.025, -0.008, 0))),
    (3.0, P(_chip_hand, chip=(360, 0, 0, -0.025, 0, 0))),
], loop=True)

# Camera v2 (Godot Dev a153087): the band above the far rail at Smiles' spot is ~0.22 m on phone landscape and
# ~0.44 m on PC. Everything is authored for the phone band: grin, visor and the key gestures read inside it, and
# nothing goes above his head; on PC he just shows more chest and waistcoat.

# taunt (1.4 s, bust): lean in, cackle (jaw chatter, head tipped back a little), jab a finger at the player at
# eye height (the hand stays at or below his head)
_point = P(STAND, arm("R", (-0.17, -0.06, 0.63), (-0.4, 0.3, 0.2), fingers=(0.15, -1, 0.38), sh=shd("R", 9, 3)), arm("L", (0.1, -0.08, 0.12), (0.5, 0.1, 0.2), hand=(0, 0, 0), sh=shd("L", 0, -3)),
           curl("L", 50), spine=(4, 0, 0), chest=(5, 0, 0), neck=(-18, 0, 0), head=(-28, 0, 0),
           index_R=(0, 0, 0), fingers_R=(0, 0, 70), thumb_R=(0, 0, 30))
_wind = arm("R", (-0.21, 0.03, 0.54), (-0.45, 0.3, 0.2), fingers=(0.1, -0.3, 1), sh=shd("R", -4, 4))
_wind_back = arm("R", (-0.22, 0.03, 0.47), (-0.45, 0.3, 0.2), fingers=(0.1, -0.25, 1))
clip("taunt", 1.4, [
    (0.0, STAND),
    (0.12, P(STAND, _wind, spine=(5, 0, 0), chest=(6, 0, 0), head=(-28, 0, 0), jaw=(10, 0, 0))),
    (0.19, P(STAND, arm("R", (-0.19, -0.05, 0.63), (-0.4, 0.3, 0.2), fingers=(0.12, -0.7, 0.6)), spine=(5, 0, 0), chest=(6, 0, 0), head=(-28, 0, 0), jaw=(16, 0, 0))),
    (0.25, P(_point, jaw=(24, 0, 0), grin_L=(0, 0, 10), grin_R=(0, 0, -10))),
    (0.38, P(_point, jaw=(8, 0, 0), head=(-30, 0, 3), chest=(3, 0, 0))),
    (0.5, P(_point, jaw=(28, 0, 0), head=(-29, 0, -2), grin_L=(0, 0, 12), grin_R=(0, 0, -12))),
    (0.63, P(_point, jaw=(6, 0, 0), head=(-30, 0, 3), chest=(3, 0, 0))),
    (0.76, P(_point, jaw=(26, 0, 0), head=(-29, 0, 0), grin_L=(0, 0, 10), grin_R=(0, 0, -10))),
    (1.0, P(_point, jaw=(10, 0, 0))),
    (1.2, P(STAND, _wind_back, head=(-27, 0, 0))),
    (1.4, STAND),
])

# grudging (1.6 s, big score tier 3+): two slow sarcastic claps at the centre of his body, hands at chin height
# just in front of the face, so on screen the cracking grin sits right above the clapping hands.
_crack = {"jaw": (4, 0, 0), "grin_L": (0, 0, -16), "grin_R": (0, 0, 16)}
_up = {"head": (-25, 0, 0)}
# Clap (AD final): held keys keep the hands a palm-width apart, palms facing, fingers up and slightly splayed,
# wrists never crossing; the palms meet for only 2-3 frames per clap. Elbows tucked down/back (clear of the brazier).
_splay = {'index_L': (-6, 0, 0), 'fingers_L': (5, 0, 0), 'thumb_L': (-14, 0, 0), 'index_R': (-6, 0, 0), 'fingers_R': (5, 0, 0), 'thumb_R': (-14, 0, 0)}
CW = (-0.25, 0.66)  # held clap wrist (y, z)
FY = -0.5  # fingers up, tipped a little toward the camera
PALM_ROLL = 145.0  # spins the hands so the palms face each other (fingers stay up)
def _clap(hx, wy=None, wz=None, fs=0.12, roll=None):
    wy = CW[0] if wy is None else wy
    wz = CW[1] if wz is None else wz
    roll = PALM_ROLL if roll is None else roll
    return {**arm("L", (hx, wy, wz), (0.17, 0.35, 0.35), fingers=(fs, FY, 1), roll=roll, sh=shd("L", 3, 4)),
            **arm("R", (-hx, wy, wz), (-0.17, 0.35, 0.35), fingers=(-fs, FY, 1), roll=-roll, sh=shd("R", 3, 4)), **_splay}
_clap_open = P(STAND, _crack, _up, _clap(0.083))
_clap_shut = P(_clap_open, _clap(0.017, fs=0.0))
# The way up / down: dense keys along a wrist path (straight up behind the rail, then forward over it) with the palm
# roll ramped, so the FK in-betweens never swing the wrists across each other or out toward the brazier.
_CLAP_PATH = [(0.08, -0.04, 0.47, 30.0), (0.08, -0.03, 0.58, 70.0), (0.078, -0.07, 0.66, 100.0),
              (0.077, -0.13, 0.67, 125.0), (0.075, -0.2, 0.665, 140.0)]
_clap_way = [P(STAND, _up if k >= 3 else {}, _clap(hx, wy=wy, wz=wz, roll=r), head=(-14 - 3 * k, 0, 0)) for k, (hx, wy, wz, r) in enumerate(_CLAP_PATH)]
_hide = {"chip": (0, 0, 0, 0, 0, 0, 0.0)}
clip("grudging", 1.6, [
    (0.0, STAND),
    *[(0.05 * (k + 1), P(w, _hide)) for k, w in enumerate(_clap_way)],
    (0.3, P(_clap_open, _hide)),
    (0.44, P(_clap_open, _hide, grin_L=(0, 0, -18), grin_R=(0, 0, 18))),
    (0.5, P(_clap_shut, _hide, head=(-25, 0, 3), grin_L=(0, 0, -20), grin_R=(0, 0, 20))),
    (0.534, P(_clap_shut, _hide, head=(-25, 0, 3), grin_L=(0, 0, -20), grin_R=(0, 0, 20))),
    (0.6, P(_clap_open, _hide, grin_L=(0, 0, -18), grin_R=(0, 0, 18))),
    (0.94, P(_clap_open, _hide, grin_L=(0, 0, -20), grin_R=(0, 0, 20))),
    (1.0, P(_clap_shut, _hide, head=(-25, 0, 3), jaw=(2, 0, 0), grin_L=(0, 0, -24), grin_R=(0, 0, 24))),
    (1.034, P(_clap_shut, _hide, head=(-25, 0, 3), jaw=(2, 0, 0), grin_L=(0, 0, -24), grin_R=(0, 0, 24))),
    (1.1, P(_clap_open, _hide, grin_L=(0, 0, -16), grin_R=(0, 0, 16))),
    (1.25, P(_clap_open, _hide, grin_L=(0, 0, -14), grin_R=(0, 0, 14))),
    *[(1.35 + 0.05 * k, P(w, _hide)) for k, w in enumerate(reversed(_clap_way))],
    (1.6, P(STAND, chip=(0, 0, 0, 0, 0, 0, 1.0))),
])
# cheat (1.2 s, boss tell; AD final): swung to screen-left, his own side, away from the brazier. Shifty glance
# that way, visor tipped down, and the right hand palms the chip low by his right shoulder and flicks it up the
# cuff (hand at or below head height; left hand stays down behind the rail), then a smug grin.
_glance = P(STAND, head=(-14, -16, 8), neck=(-12, -7, 0), visor=(12, 0, 0))
_cuff = lambda wx, wy, wz, f: arm("R", (wx, wy, wz), (-0.3, 0.35, -0.1), fingers=f, sh=shd("R", 3, 6))
clip("cheat", 1.2, [
    (0.0, STAND),
    (0.1, P(STAND, _cuff(-0.14, 0.0, 0.53, (0.2, -0.45, 0.85)), head=(-12, -10, 4), neck=(-8, -4, 0), visor=(6, 0, 0))),
    (0.2, P(_glance, _cuff(-0.2, -0.03, 0.545, (0.25, -0.3, 1)))),
    (0.45, P(_glance, _cuff(-0.22, -0.01, 0.565, (-0.25, -0.2, 1)), chip=(40, 0, 0, 0, 0.0, 0, 0.6))),
    (0.6, P(_glance, _cuff(-0.215, -0.01, 0.545, (-0.15, -0.3, 1)), head=(-18, 10, 0), chip=(80, 0, 0, 0, 0.0, 0, 0.0))),
    (0.72, P(STAND, _cuff(-0.15, 0.03, 0.5, (0.15, -0.15, 1)), head=(-20, -4, 4), visor=(7, 0, 0), grin_L=(0, 0, 10), grin_R=(0, 0, -10),
             chip=(0, 0, 0, 0, 0, 0, 0.0))),
    (0.79, P(STAND, _cuff(-0.12, 0.03, 0.42, (0.25, 0.08, 1)), head=(-21, -2, 5), visor=(5, 0, 0), grin_L=(0, 0, 12), grin_R=(0, 0, -12),
             chip=(0, 0, 0, 0, 0, 0, 0.0))),
    (0.85, P(STAND, head=(-22, 0, 6), visor=(4, 0, 0), grin_L=(0, 0, 14), grin_R=(0, 0, -14), chip=(0, 0, 0, 0, 0, 0, 0.0))),
    (1.1, P(STAND, chip=(0, 0, 0, 0, 0, 0, 0.0))),
    (1.2, P(STAND, chip=(0, 0, 0, 0, 0, 0, 1.0))),
])

# deal (1.0 s): right hand flicks a chip out across the felt, low over the rail (inside the phone band)
clip("deal", 1.0, [
    (0.0, STAND),
    (0.25, P(STAND, arm("R", (-0.17, 0.01, 0.56), (-0.5, 0.35, 0.0), fingers=(0.1, -0.4, 0.9), sh=shd("R", -3, 3)), chest=(2, -3, 0), index_R=(0, 0, 14), fingers_R=(0, 0, 18))),
    (0.42, P(STAND, arm("R", (-0.15, -0.2, 0.688), (-0.45, 0.4, 0.4), fingers=(0.1, -1, 0.04), sh=shd("R", 10, 2)), arm("L", (0.075, -0.045, 0.37), (0.35, 0.25, 0.0), fingers=(-0.35, 0.0, 1), sh=shd("L", 2, -2)),
             chest=(4, 6, 0), index_R=(0, 0, -8), fingers_R=(0, 0, -4), thumb_R=(0, 0, -14), chip=(0, 0, 0, 0, 0, 0.0, 1.0))),
    (0.5, P(STAND, arm("R", (-0.15, -0.2, 0.692), (-0.45, 0.4, 0.4), fingers=(0.1, -1, 0.06), sh=shd("R", 10, 2)), arm("L", (0.075, -0.045, 0.37), (0.35, 0.25, 0.0), fingers=(-0.35, 0.0, 1), sh=shd("L", 2, -2)),
            chest=(4, 6, 0), index_R=(0, 0, -6), fingers_R=(0, 0, 0), thumb_R=(0, 0, -12), chip=(0, 0, 0, 0, 0, 0.03, 0.0))),
    (0.7, P(STAND, arm("R", (-0.19, -0.04, 0.58), (-0.45, 0.4, 0.3), fingers=(0.1, -0.2, 1), sh=shd("R", 4, 2)), chest=(3, 2, 0), chip=(0, 0, 0, 0, 0, 0, 0.0))),
    (0.9, P(STAND, chip=(0, 0, 0, 0, 0, 0, 0.0))),
    (1.0, P(STAND, chip=(0, 0, 0, 0, 0, 0, 1.0))),
])

# MC variant (boss in the dealer spot, Smiles on the left rail): upright, fist on hip, chip held up
_mc = P({"spine": (0, 0, 0), "chest": (2, 0, 0), "neck": (-6, 0, 0), "head": (-14, 0, -4)},
        arm("L", (0.2, 0.0, 0.02), (0.6, 0.3, 0.2), hand=(0, 0, -10), sh=shd("L", -3, 2)), curl("L", 60),
        arm("R", (-0.3, 0.0, 0.62), (-0.5, 0.1, 0.3), hand=(0, -30, 0), sh=shd("R", 2, 5)), index_R=(0, 0, 6))
clip("mc_idle", 2.4, [
    (0.0, _mc),
    (0.6, P(_mc, chest=(4, 0, 2), head=(-16, 0, 2), jaw=(4, 0, 0))),
    (1.2, P(_mc, chest=(2, 0, 0), head=(-14, 0, -6))),
    (1.8, P(_mc, chest=(4, 0, -2), head=(-16, 0, 4), grin_L=(0, 0, 6), grin_R=(0, 0, -6))),
    (2.4, _mc),
], loop=True)
_cheer = P(_mc, arm("L", (0.3, -0.05, 0.82), (0.6, 0.2, 0.4), sh=shd("L", 0, 9)), arm("R", (-0.3, -0.05, 0.82), (-0.6, 0.2, 0.4), sh=shd("R", 0, 9)), curl("L", 80), curl("R", 80),
           spine=(-4, 0, 0), chest=(-6, 0, 0), head=(-26, 0, 0), jaw=(26, 0, 0), grin_L=(0, 0, 12), grin_R=(0, 0, -12))
_cheer2 = P(_cheer, arm("L", (0.26, -0.05, 0.74), (0.6, 0.2, 0.4), sh=shd("L", 0, 5)), arm("R", (-0.26, -0.05, 0.74), (-0.6, 0.2, 0.4), sh=shd("R", 0, 5)), jaw=(10, 0, 0))
clip("mc_cheer", 1.2, [
    (0.0, _mc),
    (0.2, _cheer),
    (0.4, _cheer2),
    (0.6, _cheer),
    (0.8, _cheer2),
    (1.2, _mc),
])


def make_actions(arm):
    arm.animation_data_create()
    for name, (length_s, keys, loop) in CLIPS.items():
        keys = sorted(keys, key=lambda k: k[0])  # quaternion sign continuity runs in time order
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        arm.animation_data.action = act
        prev = {}
        for t, pose in keys:
            f = 1 + round(t * FPS)
            for pb in arm.pose.bones:
                v = pose.get(pb.name, (0, 0, 0))
                # quaternion keys: in-betweens take the short way (euler in-betweens swing limbs through the rail)
                q = Euler([math.radians(a) for a in v[:3]], "XYZ").to_quaternion()
                if pb.name in prev and prev[pb.name].dot(q) < 0:
                    q.negate()
                prev[pb.name] = q
                pb.rotation_quaternion = q
                loc = v[3:6] if len(v) >= 6 else (0, 0, 0)
                pb.location = loc
                sc = v[6] if len(v) >= 7 else 1.0
                if pb.name in GLOW_BONES:
                    sc = 1.0 if name.startswith("mc_") else 0.0  # grin + visor-rim glow: MC only
                pb.scale = (max(sc, 0.001),) * 3
                pb.keyframe_insert("rotation_quaternion", frame=f)
                pb.keyframe_insert("location", frame=f)
                pb.keyframe_insert("scale", frame=f)
        act.frame_range = (1, 1 + round(length_s * FPS))
        act.use_frame_range = True
        # stepped scale (prop pops) and a gentle ease on everything else
        for fc in act.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "CONSTANT" if fc.data_path.endswith("scale") else "BEZIER"
                kp.easing = "AUTO"
        if loop:
            for fc in act.fcurves:
                fc.modifiers.new("CYCLES")
        arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)
