import io, math, random
import numpy as np
import cairosvg
from PIL import Image, ImageFont, ImageFilter, ImageChops
OUT = '/workspace/dice/art/ui/readability'
FB = '/usr/share/fonts/truetype/sand-box/google/Barlow Condensed/BarlowCondensed-Bold.ttf'
FA = '/usr/share/fonts/truetype/sand-box/google/Alfa Slab One/AlfaSlabOne-Regular.ttf'
CAP_B, CAP_A = 0.700, 0.778   # cap height / em, measured from the TTFs
BONE='#E8DCC0'; BRASS='#B08D3C'; BURG='#6E1A24'; OX='#3B0D14'; EC='#FFE6A8'; EM='#E8622A'
HF='#C8281E'; LEATHER='#5A1620'; PIT='#0E1414'; FELT='#123A36'
def hx(c): c=c.lstrip('#'); return tuple(int(c[i:i+2],16) for i in (0,2,4))
def mix(a,b,t):
    a,b=hx(a),hx(b); return '#%02X%02X%02X'%tuple(round(a[i]+(b[i]-a[i])*t) for i in range(3))
BRASS_HI = mix(BRASS, BONE, 0.45); BRASS_LO = mix(BRASS, OX, 0.45)
_fc={}
def font(path, size):
    k=(path,size)
    if k not in _fc: _fc[k]=ImageFont.truetype(path,size)
    return _fc[k]
def tw(text, em, path=FB):  # advance width in same units as em
    return font(path,1000).getlength(text)*em/1000.0
def esc(s): return s.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;')
FAM={FB:"font-family=\"Barlow Condensed\" font-weight=\"bold\"", FA:"font-family=\"Alfa Slab One\""}
def text(x,y,s,em,fill,path=FB,anchor='start',extra=''):
    return f'<text x="{x:.2f}" y="{y:.2f}" {FAM[path]} font-size="{em:.2f}" fill="{fill}" text-anchor="{anchor}" {extra}>{esc(s)}</text>'
def svgdoc(w,h,body,bg=None):
    b = f'<rect width="{w}" height="{h}" fill="{bg}"/>' if bg else ''
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{b}{body}</svg>'
def render(svg, w=None, h=None):
    png = cairosvg.svg2png(bytestring=svg.encode(), output_width=w, output_height=h)
    return Image.open(io.BytesIO(png)).convert('RGBA')
def save_svg(path, svg):
    open(path,'w').write(svg)
def noise(w,h,seed=1,octaves=((8,0.5),(32,0.3),(128,0.2))):
    rng=np.random.default_rng(seed); acc=np.zeros((h,w))
    for cells,amp in octaves:
        a=rng.random((max(2,int(h*cells/w)+2),cells+2))
        im=Image.fromarray((a*255).astype('uint8')).resize((w,h),Image.BICUBIC)
        acc+=np.asarray(im)/255.0*amp
    return acc/sum(a for _,a in octaves)
def wear(img, strength=0.35, seed=3, speck=0.04):
    """grimy worn print: modulate alpha with noise + knock out specks; never below 1-strength"""
    a=np.asarray(img).astype(float); h,w=a.shape[:2]
    n=noise(w,h,seed); m=1-strength*np.clip((n-0.35)*2.2,0,1)
    rng=np.random.default_rng(seed+7); sp=rng.random((h,w))<speck
    sp=np.asarray(Image.fromarray((sp*255).astype('uint8')).filter(ImageFilter.MaxFilter(3)))>0
    m=np.where(sp, m*0.55, m)
    a[...,3]*=m; return Image.fromarray(a.clip(0,255).astype('uint8'))
def homography(src, dst):
    A=[];B=[]
    for (x,y),(u,v) in zip(src,dst):
        A+= [[x,y,1,0,0,0,-u*x,-u*y],[0,0,0,x,y,1,-v*x,-v*y]]; B+=[u,v]
    h=np.linalg.solve(np.array(A,float),np.array(B,float)); return np.append(h,1).reshape(3,3)
def apply_h(H,x,y):
    p=H@np.array([x,y,1.0]); return p[0]/p[2], p[1]/p[2]
def warp(img, H, size):
    Hi=np.linalg.inv(H); Hi/=Hi[2,2]
    return img.transform(size, Image.PERSPECTIVE, tuple(Hi.flatten()[:8]), Image.BICUBIC)
