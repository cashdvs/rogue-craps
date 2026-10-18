import io, cairosvg, sys
from PIL import Image, ImageDraw, ImageFont
from shapes import *
D="/workspace/dice/art/branding/studio/"; P="/workspace/dice/art/concept/studio_logo_final/"
F="/workspace/dice/game/fonts/BarlowCondensed-Bold.ttf"
fT=ImageFont.truetype(F,34); fS=ImageFont.truetype(F,22)
def svgpng(svg=None,url=None,w=None,h=None):
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode() if svg else None,url=url,output_width=w,output_height=h))).convert("RGBA")
# 1) silhouette comparison incl. final
V=dict(VARIANTS); 
def final_svg(fill=ORANGE,bg=None,small=False,pad=14):
    s=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{-pad} {-pad} {230+2*pad} {160+2*pad}">'
    if bg: s+=f'<rect x="{-pad}" y="{-pad}" width="{230+2*pad}" height="{160+2*pad}" fill="{bg}"/>'
    s+=f'<path d="{SMALL_ANVIL if small else FINAL_ANVIL}" fill="{fill}" stroke="{fill}" stroke-width="{FINAL_ROUND}" stroke-linejoin="round"/><path d="{spark_path(*SPARK_HOME)}" fill="{ORANGE}"/></svg>'
    return s
cols=[(k,lambda fill=ORANGE,bg=None,k=k: anvil_svg(k,fill=fill,bg=bg)) for k in V]+[("FINAL (refined A)",lambda fill=ORANGE,bg=None: final_svg(fill,bg)),("FINAL small-size cut",lambda fill=ORANGE,bg=None: final_svg(fill,bg,True))]
W=300; sheet=Image.new("RGB",(W*len(cols)+20,640),CHAR); d=ImageDraw.Draw(sheet)
for i,(name,fn) in enumerate(cols):
    x0=20+i*W; d.text((x0,14),name,fill=ORANGE if "FINAL" in name else CREAM,font=fT)
    y=64
    im=svgpng(fn(),w=256); sheet.paste(im,(x0,y),im); d.text((x0,y+im.height),"256 px",fill="#9a948c",font=fS); y+=im.height+34
    im=svgpng(fn(),w=64); sheet.paste(im,(x0,y),im); im2=svgpng(fn(fill=CHAR,bg=CREAM),w=64); sheet.paste(im2,(x0+80,y),im2)
    d.text((x0,y+im2.height+2),"64 px (dark / light)",fill="#9a948c",font=fS); y+=im2.height+34
    for sz in (32,16):
        im=svgpng(fn(),w=sz); sheet.paste(im,(x0,y),im); im2=svgpng(fn(fill=CHAR,bg=CREAM),w=sz); sheet.paste(im2,(x0+sz+8,y),im2)
        z=im.resize((sz*4,im.height*4),Image.NEAREST); sheet.paste(z,(x0+2*sz+24,y),z)
        d.text((x0,y+z.height+2),f"{sz} px (actual, light, 4x zoom)",fill="#9a948c",font=fS); y+=z.height+34
sheet.save(P+"silhouette_comparison.png")
# 2) lockups on charcoal / cream
for bgname,bg,suf in (("charcoal",CHAR,""),("cream",CREAM,"_on_light")):
    c=Image.new("RGB",(1800,1500),bg)
    a=Image.open(D+f"logo_lockup_stacked{suf}.png"); c.paste(a,((1800-a.width)//2,60),a)
    b=Image.open(D+f"logo_lockup_horizontal{suf}.png"); c.paste(b,((1800-b.width)//2,60+a.height+120),b)
    y=60+a.height+120+b.height+90; x=150
    for nm,w in ((f"logo_lockup_stacked_small{suf}.svg",240),(f"logo_lockup_stacked_small{suf}.svg",120),(f"logo_lockup_horizontal_small{suf}.svg",240)):
        im=svgpng(url=D+nm,w=w); c.paste(im,(x,y),im); ImageDraw.Draw(c).text((x,y+im.height+8),f"{nm.replace('.svg','')} @ {w}px",fill=ORANGE,font=fS); x+=w+180
    c.save(P+f"lockups_on_{bgname}.png")
# 3) icon at sizes
c=Image.new("RGB",(1200,420),"#3a3532"); d=ImageDraw.Draw(c); x=30
for sz,src in ((256,"icon.svg"),(128,"icon.svg"),(64,"icon.svg"),(32,"favicon_32.png"),(16,"favicon_16.png")):
    im=svgpng(url=D+src,w=sz) if src.endswith(".svg") else Image.open(D+src).convert("RGBA")
    c.paste(im,(x,40),im); d.text((x,40+sz+10),f"{sz}px",fill=CREAM,font=fS); x+=sz+40
for sz,src in ((32,"favicon_32.png"),(16,"favicon_16.png")):
    z=Image.open(D+src).convert("RGBA").resize((sz*8,sz*8) if sz==16 else (sz*4,sz*4),Image.NEAREST); c.paste(z,(x,40),z); d.text((x,40+z.height+10),f"{sz}px zoomed",fill=CREAM,font=fS); x+=z.width+40
c.save(P+"icon_sizes.png")
