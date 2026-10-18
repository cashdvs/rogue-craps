# Hand-written SVG geometry for the Tiny Anvil logo. Units: anvil-local, base line y=150.
ORANGE="#F26A1B"; CHAR="#1E1B1A"; CREAM="#F4EDE4"

def spark_path(cx,cy,R,pinch=0.0):
    # concave four-point star; control points at center give the sparkle "pinch"
    k=pinch
    return (f"M{cx},{cy-R} Q{cx+k},{cy-k} {cx+R},{cy} Q{cx+k},{cy+k} {cx},{cy+R} "
            f"Q{cx-k},{cy+k} {cx-R},{cy} Q{cx-k},{cy-k} {cx},{cy-R} Z")

VARIANTS={
# A: stubby chunky, exaggerated horn, hardy-hole notch, waist pinch, heel step, flared feet
"A_stubby": dict(path=(
 "M58,34 L170,34 L170,46 L186,46 L186,34 L214,34 L214,56 L204,56 L204,70 "
 "Q178,72 170,96 L170,112 Q192,116 218,124 L218,150 L62,150 L62,124 Q88,116 108,112 L108,96 "
 "Q100,72 70,70 Q30,66 8,44 Q34,40 58,34 Z"), round=10, spark=(26,14,15)),
# B: horn hero, long upturned horn, small body
"B_hornhero": dict(path=(
 "M76,40 L176,40 L176,50 L190,50 L190,40 L212,40 L212,72 Q186,74 178,98 L178,114 "
 "Q198,118 216,126 L216,150 L84,150 L84,126 Q102,118 122,114 L122,98 Q114,76 84,74 "
 "Q40,72 4,22 Q40,40 76,40 Z"), round=8, spark=(14,6,14)),
# C: blocky geometric, straight cuts only
"C_blocky": dict(path=(
 "M60,36 L172,36 L172,50 L188,50 L188,36 L214,36 L214,58 L202,58 L202,72 L176,72 L164,104 "
 "L164,116 L212,124 L212,150 L68,150 L68,124 L116,116 L116,104 L104,72 L70,72 L14,50 Z"), round=0, spark=(30,18,15)),
# D: bubble-soft, very round, short horn
"D_bubble": dict(path=(
 "M66,36 L172,36 L172,48 L186,48 L186,36 L210,36 L210,70 Q180,72 172,98 L172,114 "
 "Q196,118 212,128 L212,150 L68,150 L68,128 Q84,118 108,114 L108,98 Q100,72 72,70 "
 "Q40,68 24,52 Q36,38 66,36 Z"), round=22, spark=(30,16,15)),
}

def anvil_svg(v, fill=ORANGE, spark_fill=ORANGE, bg=None, with_spark=True, pad=14):
    d=VARIANTS[v]; r=d["round"]
    s=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{-pad} {-pad} {230+2*pad} {160+2*pad}">']
    if bg: s.append(f'<rect x="{-pad}" y="{-pad}" width="{230+2*pad}" height="{160+2*pad}" fill="{bg}"/>')
    stroke=f' stroke="{fill}" stroke-width="{r}" stroke-linejoin="round"' if r else ""
    s.append(f'<path d="{d["path"]}" fill="{fill}"{stroke}/>')
    if with_spark:
        cx,cy,R=d["spark"]; s.append(f'<path d="{spark_path(cx,cy,R)}" fill="{spark_fill}"/>')
    s.append('</svg>'); return "".join(s)

# ---- FINAL (refined A): stubbier body, thicker horn, hardy-hole notch, heel step, waist pinch, flared feet
FINAL_ANVIL=("M60,30 L158,30 L158,42 L174,42 L174,30 L200,30 L200,54 L190,54 L190,68 "
 "Q166,70 160,92 L160,108 Q182,112 204,120 L204,146 L64,146 L64,120 Q86,112 106,108 L106,92 "
 "Q100,70 66,68 Q30,66 8,46 Q30,32 60,30 Z")
FINAL_ROUND=12                      # stroke-linejoin round, same color: friendly corners
# small-size variant (<= 32 px): no notch, slightly fatter horn tip
SMALL_ANVIL=("M60,30 L200,30 L200,54 L190,54 L190,68 Q166,70 160,92 L160,108 Q182,112 204,120 "
 "L204,146 L64,146 L64,120 Q86,112 106,108 L106,92 Q100,70 66,68 Q30,68 6,46 Q30,30 60,30 Z")
SPARK_HOME=(26,8,17)                # cx, cy, R in anvil-local units (off the horn tip)
STRIKE_POINT=(140,24)               # top of the face (stroke edge) where the hammer lands
ANVIL_BASE_CENTER=(134,152)         # bottom of the feet incl. the stroke
# hammer, local units; neutral pose = handle horizontal, head on the LEFT, striking face DOWN
HAMMER_HEAD="M-22,-40 Q-22,-48 -14,-48 L14,-48 Q22,-48 22,-40 L22,20 L28,32 L-28,32 L-22,20 Z"   # head centered on handle axis, face flares at the bottom
HAMMER_HANDLE="M14,-7 L176,-7 Q186,-7 186,0 Q186,7 176,7 L14,7 Z"
HAMMER_GRIP_BAND="M150,-9 L176,-9 Q188,-9 188,0 Q188,9 176,9 L150,9 Z"
HAMMER_GRIP=(172,0)                 # pivot (the hand)
HAMMER_FACE=(0,32)                  # center of the striking face (bottom of head)
