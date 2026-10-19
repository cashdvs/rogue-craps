import io, json, math, os, shutil
import cairosvg, uharfbuzz as hb
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.transformPen import TransformPen
from PIL import Image
from shapes import *
from pathlib import Path
# Paths relative to this script: outputs go to the studio folder above src/.
SRC=str(Path(__file__).resolve().parent); OUT=str(Path(SRC).parent)
S=2.4    # px per anvil unit at 2x layout  (anvil ≈ 500 px wide)
meta={}

def svg_doc(vb, body):
    x,y,w,h=vb
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x} {y} {w} {h}" width="{w}" height="{h}">{body}</svg>'

def render(svg, vb, scale, name, pivots):
    """render svg (viewBox vb in local units) at scale px/unit, trim to alpha, save PNG, return pivots in px"""
    png=cairosvg.svg2png(bytestring=svg.encode(), output_width=int(round(vb[2]*scale)), output_height=int(round(vb[3]*scale)))
    im=Image.open(io.BytesIO(png)).convert("RGBA")
    l,t,r,b=im.getchannel("A").point(lambda a:255 if a>0 else 0).getbbox()
    im=im.crop((l,t,r,b)); im.save(f"{OUT}/{name}.png")
    piv={k:[round((px-vb[0])*scale-l,1), round((py-vb[1])*scale-t,1)] for k,(px,py) in pivots.items()}
    meta[name]={"size":list(im.size),"pivots_px":piv}
    return im

def save_svg(name, svg): open(f"{OUT}/{name}.svg","w").write(svg)

# ---------- anvil (no spark), spark, hammer
pad=10; avb=(-pad,20-pad,214+2*pad,138+2*pad)     # covers x -4..210, y 18..152
anvil_body=f'<path d="{FINAL_ANVIL}" fill="{ORANGE}" stroke="{ORANGE}" stroke-width="{FINAL_ROUND}" stroke-linejoin="round"/>'
a_svg=svg_doc(avb, anvil_body); save_svg("anvil", a_svg)
render(a_svg, avb, S, "anvil", {"base_center":ANVIL_BASE_CENTER,"strike_point":STRIKE_POINT,"spark_home":SPARK_HOME[:2]})
for w in (1024,512):
    render(a_svg, avb, w/avb[2], f"anvil_{w}", {"base_center":ANVIL_BASE_CENTER})

cx,cy,R=SPARK_HOME
svb=(cx-R-2,cy-R-2,2*R+4,2*R+4)
s_svg=svg_doc(svb, f'<path d="{spark_path(cx,cy,R)}" fill="{ORANGE}"/>'); save_svg("spark", s_svg)
render(s_svg, svb, S, "spark", {"center":(cx,cy)})

hvb=(-36,-56,230,96)
h_body=(f'<path d="{HAMMER_HANDLE}" fill="{CREAM}"/><path d="{HAMMER_GRIP_BAND}" fill="{ORANGE}"/>'
        f'<path d="{HAMMER_HEAD}" fill="{CREAM}" stroke="{CREAM}" stroke-width="4" stroke-linejoin="round"/>')
h_svg=svg_doc(hvb, h_body); save_svg("hammer", h_svg)
render(h_svg, hvb, S, "hammer", {"grip":HAMMER_GRIP,"head_face_center":HAMMER_FACE,"head_center":(0,0)})

# spark particle: 64x64 white soft 4-point star
p_svg=('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64"><defs>'
 '<radialGradient id="g"><stop offset="0" stop-color="#fff" stop-opacity="1"/><stop offset="0.35" stop-color="#fff" stop-opacity="0.55"/>'
 '<stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient><filter id="b"><feGaussianBlur stdDeviation="1.4"/></filter></defs>'
 '<circle cx="32" cy="32" r="30" fill="url(#g)" opacity="0.6"/>'
 f'<path d="{spark_path(32,32,28)}" fill="#fff" filter="url(#b)"/></svg>')
open(f"{OUT}/spark_particle.svg","w").write(p_svg)
Image.open(io.BytesIO(cairosvg.svg2png(bytestring=p_svg.encode(),output_width=64,output_height=64))).save(f"{OUT}/spark_particle.png")
meta["spark_particle"]={"size":[64,64],"pivots_px":{"center":[32,32]}}

# ---------- wordmark: Fredoka Bold (wght 700, wdth 100) -> outlines.  "TINY ANVIL" + spaced "GAMES" under it
inst=SRC+"/Fredoka-Bold-instance.ttf"
if not os.path.exists(inst):
    f=TTFont(SRC+"/Fredoka.ttf"); instancer.instantiateVariableFont(f,{"wght":700,"wdth":100},inplace=True); f.save(inst)
font=TTFont(inst); gs=font.getGlyphSet(); upm=font["head"].unitsPerEm; cap=font["OS/2"].sCapHeight
blob=hb.Blob.from_file_path(inst); face=hb.Face(blob); hbf=hb.Font(face); order=font.getGlyphOrder()
def shape_text(text, size=1.0, track=0.0, space_adj=0.0, ox=0.0, oy=0.0):
    buf=hb.Buffer(); buf.add_str(text); buf.guess_segment_properties(); hb.shape(hbf,buf,{"kern":True,"liga":False})
    x=0; out=[]; bmin=[1e9,1e9]; bmax=[-1e9,-1e9]; n=len(buf.glyph_infos)
    for i,(info,pos) in enumerate(zip(buf.glyph_infos,buf.glyph_positions)):
        g=order[info.codepoint]
        pen=SVGPathPen(gs); gs[g].draw(TransformPen(pen,(size,0,0,-size,ox+x+pos.x_offset*size,oy)))
        bp=BoundsPen(gs); gs[g].draw(bp)
        if bp.bounds:
            bb=bp.bounds; gx=ox+x+pos.x_offset*size
            bmin[0]=min(bmin[0],gx+bb[0]*size); bmax[0]=max(bmax[0],gx+bb[2]*size)
            bmin[1]=min(bmin[1],oy-bb[3]*size); bmax[1]=max(bmax[1],oy-bb[1]*size); out.append(pen.getCommands())
        if i<n-1: x+=pos.x_advance*size+track+(space_adj if g=="space" else 0)
    return out,bmin,bmax
MAIN,mmin,mmax=shape_text("TINY ANVIL", track=-0.012*upm, space_adj=-0.03*upm)
def build_games(GAMES_RATIO, track_em, gap_ratio):
  global GAMES,gmin,gmax,bmin,bmax,mc,gc,WM,tb_top,tb_bot,tb_h,tb_mid
  GAMES_TRACK=track_em*upm*GAMES_RATIO; GAMES_GAP=gap_ratio*cap
  _,g0min,g0max=shape_text("GAMES", GAMES_RATIO, GAMES_TRACK)
  gw=g0max[0]-g0min[0]; gx=(mmin[0]+mmax[0])/2-gw/2-g0min[0]
  GAMES,gmin,gmax=shape_text("GAMES", GAMES_RATIO, GAMES_TRACK, ox=gx, oy=GAMES_GAP+cap*GAMES_RATIO)
  bmin=[min(mmin[0],gmin[0]),min(mmin[1],gmin[1])]; bmax=[max(mmax[0],gmax[0]),max(mmax[1],gmax[1])]
  bmin=[min(mmin[0],gmin[0]),min(mmin[1],gmin[1])]; bmax=[max(mmax[0],gmax[0]),max(mmax[1],gmax[1])]
  mc=((mmin[0]+mmax[0])/2,(mmin[1]+mmax[1])/2); gc=((gmin[0]+gmax[0])/2,(gmin[1]+gmax[1])/2)
  WM="".join(f'<path d="{d}"/>' for d in MAIN+GAMES)
  tb_top=mmin[1]; tb_bot=gmax[1]; tb_h=tb_bot-tb_top; tb_mid=(tb_top+tb_bot)/2
GAMES_CAP, GAMES_TRACK_EM, GAMES_GAP = 0.52, 0.36, 0.30   # v1.1 (2026-10-19): GAMES cap 52% of TINY ANVIL cap (was 40% / +0.42 em), spaced caps, gap 0.30 cap
build_games(GAMES_CAP, GAMES_TRACK_EM, GAMES_GAP)
WW=1200.0; ws=WW/(mmax[0]-mmin[0])   # TINY ANVIL line = 1200 px at 2x
def vb_of(lo,hi,p=6): return (lo[0]-p,lo[1]-p,hi[0]-lo[0]+2*p,hi[1]-lo[1]+2*p)
def paths_svg(ps,color,vb): return svg_doc(vb,"".join(f'<path d="{d}" fill="{color}"/>' for d in ps))
mc=((mmin[0]+mmax[0])/2,(mmin[1]+mmax[1])/2); gc=((gmin[0]+gmax[0])/2,(gmin[1]+gmax[1])/2)
for cname,c in (("cream",CREAM),("charcoal",CHAR)):
    vb=vb_of(bmin,bmax); svg=paths_svg(MAIN+GAMES,c,vb); save_svg(f"wordmark_{cname}",svg)
    render(svg,vb,ws,f"wordmark_{cname}",{"main_center":mc,"games_center":gc,"center":((bmin[0]+bmax[0])/2,(bmin[1]+bmax[1])/2),"baseline_left":(mmin[0],0)})
    # optional sub-layers for the delayed GAMES reveal
    vb=vb_of(mmin,mmax); svg=paths_svg(MAIN,c,vb); save_svg(f"wordmark_main_{cname}",svg); render(svg,vb,ws,f"wordmark_main_{cname}",{"center":mc})
    vb=vb_of(gmin,gmax); svg=paths_svg(GAMES,c,vb); save_svg(f"wordmark_games_{cname}",svg); render(svg,vb,ws,f"wordmark_games_{cname}",{"center":gc})
meta["_wordmark_geometry"]={"games_center_offset_from_main_center_px_2x":[round((gc[0]-mc[0])*ws,1),round((gc[1]-mc[1])*ws,1)],
  "games_cap_ratio":GAMES_CAP,"games_track_em":GAMES_TRACK_EM,"games_width_ratio":round((gmax[0]-gmin[0])/(mmax[0]-mmin[0]),3),"main_line_width_px_2x":WW}
WM="".join(f'<path d="{d}"/>' for d in MAIN+GAMES)
tb_top=mmin[1]; tb_bot=gmax[1]; tb_h=tb_bot-tb_top; tb_mid=(tb_top+tb_bot)/2

# ---------- lockups (units: font units; anvil placed via transform)
anvil_w_units=214      # local anvil width incl stroke (-4..210)
def anvil_group(scale, tx, ty, fill=ORANGE, spark=True, small=False):
    p=SMALL_ANVIL if small else FINAL_ANVIL
    g=(f'<g transform="translate({tx},{ty}) scale({scale})"><path d="{p}" fill="{fill}" stroke="{fill}" stroke-width="{FINAL_ROUND}" stroke-linejoin="round"/>')
    if spark: g+=f'<path d="{spark_path(*SPARK_HOME)}" fill="{ORANGE}"/>'
    return g+'</g>'
def lockup(kind, text_color):
    tw=bmax[0]-bmin[0]
    if kind=="horizontal":
        ah=tb_h*1.12; sc=ah/161; gap=cap*0.45; aw=(anvil_w_units)*sc
        ty=tb_mid-ah/2+9*sc
        body=anvil_group(sc, 4*sc, ty) + f'<g transform="translate({aw+gap-bmin[0]},0)" fill="{text_color}">{WM}</g>'
        pad=cap*0.25; vb=(-pad, min(tb_top,tb_mid-ah/2)-pad, aw+gap+tw+2*pad, max(tb_h,ah)+2*pad)
    else:
        aw=tw*0.44; sc=aw/anvil_w_units; ah=161*sc; gap=cap*0.35
        ax=(bmin[0]+bmax[0])/2-aw/2+4*sc; ay=tb_top-gap-152*sc
        body=anvil_group(sc, ax, ay) + f'<g fill="{text_color}">{WM}</g>'
        pad=cap*0.25; top=ay-9*sc; vb=(bmin[0]-pad, top-pad, tw+2*pad, tb_bot-top+2*pad)
    return svg_doc(vb, body), vb
for kind in ("horizontal","stacked"):
    for suffix,col in (("",CREAM),("_on_light",CHAR)):
        svg,vb=lockup(kind,col); nm=f"logo_lockup_{kind}{suffix}"; save_svg(nm,svg)
        render(svg, vb, (1600 if kind=="horizontal" else 1200)/vb[2], nm, {})
# small-use lockups (<= 240 px wide): GAMES at 62% cap, tighter tracking so it survives at ~120 px
build_games(0.62, 0.22, 0.26)
for kind in ("horizontal","stacked"):
    for suffix,col in (("",CREAM),("_on_light",CHAR)):
        svg,vb=lockup(kind,col); nm=f"logo_lockup_{kind}_small{suffix}"; save_svg(nm,svg)
        render(svg, vb, 480/vb[2], nm, {})

# ---------- icon + favicons
def icon_svg(small=False):
    plate=f'<rect x="0" y="0" width="256" height="256" rx="56" fill="{CHAR}"/>'
    sc=(1.0 if small else 0.9); w=anvil_w_units*sc; h=161*sc
    return svg_doc((0,0,256,256), plate+anvil_group(sc, (256-w)/2+4*sc, (256-h)/2+9*sc, small=small))
save_svg("icon", icon_svg()); save_svg("icon_small", icon_svg(True))
for nm,sz,sm in (("icon",1024,False),("favicon_32",32,True),("favicon_16",16,True)):
    Image.open(io.BytesIO(cairosvg.svg2png(bytestring=icon_svg(sm).encode(),output_width=sz,output_height=sz))).save(f"{OUT}/{nm}.png")
    meta[nm]={"size":[sz,sz],"pivots_px":{"center":[sz/2,sz/2]}}
json.dump(meta,open(f"{OUT}/layers.json","w"),indent=1)
print(json.dumps(meta,indent=1))
print("cap",cap,"upm",upm,"ws",ws)
