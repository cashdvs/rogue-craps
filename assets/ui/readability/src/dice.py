import os, colorsys
from common import *
D=os.path.join(OUT,'dice_states'); os.makedirs(D,exist_ok=True)
def rgb(c): return np.array(hx(c),float)/255
def tohex(v): v=np.clip(v,0,1); return '#%02X%02X%02X'%tuple(int(round(x*255)) for x in v)
# shader-equivalent colour maths (sRGB approximations of the Godot params in README)
COLD_MUL=np.array([0.80,0.78,0.76]); COLD_DESAT=0.75; COLD_PIP_TOWARD_BODY=0.55
WARM=np.array([1.0,0.96,0.90])
def cold(c):
    v=rgb(c); l=v@[0.299,0.587,0.114]; g=l*WARM; return tohex((v*(1-COLD_DESAT)+g*COLD_DESAT)*COLD_MUL)
DICE={'bone':dict(body=BONE,pip=PIT),'charcoal':dict(body='#2E2A28',pip=BONE)}
def die_svg(kind,state,s):
    d=DICE[kind]; body=d['body']; pip=d['pip']; k=s/48
    if state=='cold':
        body=cold(body); pip=tohex(rgb(cold(pip))*(1-COLD_PIP_TOWARD_BODY)+rgb(body)*COLD_PIP_TOWARD_BODY)
    if state=='lit': body=tohex(np.minimum(1,rgb(body)*np.array([1.04,1.0,0.94])+np.array([0.04,0.02,0])))
    sw=2.4*k; m=4*k; w=s-2*m; r=9*k
    b=''
    if state=='lit': b+=f'<rect x="{m-1.2*k}" y="{m-1.2*k}" width="{w+2.4*k}" height="{w+2.4*k}" rx="{r+1.2*k}" fill="none" stroke="{EM}" stroke-width="{3.2*k}"/>'
    b+=f'<rect x="{m}" y="{m}" width="{w}" height="{w}" rx="{r}" fill="{body}" stroke="{PIT}" stroke-width="{sw}"/>'
    shade = mix(body,PIT,0.25) if state!='lit' else mix(body,EM,0.45)
    b+=f'<path d="M{m+r*0.6} {m+w-2.6*k} L{m+w-r*0.6} {m+w-2.6*k} Q{m+w-2.6*k} {m+w-2.6*k} {m+w-2.6*k} {m+w-r*0.6} L{m+w-2.6*k} {m+r*0.6}" fill="none" stroke="{shade}" stroke-width="{2.6*k}" stroke-linecap="round"/>'
    if state=='base': b+=f'<path d="M{m+3*k} {m+w*0.55} L{m+3*k} {m+r*0.7} Q{m+3*k} {m+3*k} {m+r*0.7} {m+3*k} L{m+w*0.55} {m+3*k}" fill="none" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="{1.6*k}" stroke-linecap="round"/>'
    for (i,j) in [(-1,-1),(1,-1),(0,0),(-1,1),(1,1)]:   # showing a 5
        cx,cy=s/2+i*11*k,s/2+j*11*k
        if state=='lit':
            b+=f'<circle cx="{cx}" cy="{cy}" r="{4.6*k}" fill="{EM}" stroke="{PIT}" stroke-width="{0.9*k}"/><circle cx="{cx}" cy="{cy}" r="{2.5*k}" fill="{EC}"/>'
        else: b+=f'<circle cx="{cx}" cy="{cy}" r="{4.2*k}" fill="{pip}"/>'
    return svgdoc(s,s,b)
def die_img(kind,state,s):
    pad=int(s*0.25); im=render(die_svg(kind,state,s)); out=Image.new('RGBA',(s+2*pad,s+2*pad))
    if state=='lit':   # rim bloom (ember mid, below glow threshold) + pip core bloom (ember core)
        halo=render(svgdoc(s,s,f'<rect x="{s*0.06}" y="{s*0.06}" width="{s*0.88}" height="{s*0.88}" rx="{s*0.2}" fill="none" stroke="{EM}" stroke-width="{s*0.08}"/>'))
        hb=Image.new('RGBA',out.size); hb.alpha_composite(halo,(pad,pad)); hb=hb.filter(ImageFilter.GaussianBlur(s*0.07))
        out.alpha_composite(hb); out.alpha_composite(hb)
    out.alpha_composite(im,(pad,pad))
    if state=='lit':
        core=Image.new('RGBA',out.size); k=s/48
        cs=render(svgdoc(s,s,''.join(f'<circle cx="{s/2+i*11*k}" cy="{s/2+j*11*k}" r="{3.2*k}" fill="{EC}"/>' for i,j in [(-1,-1),(1,-1),(0,0),(-1,1),(1,1)])))
        core.alpha_composite(cs,(pad,pad)); core=core.filter(ImageFilter.GaussianBlur(s*0.035))
        a=np.asarray(out).astype(float); c=np.asarray(core).astype(float); al=c[...,3:4]/255*0.9
        a[...,:3]=np.clip(a[...,:3]+c[...,:3]*al,0,255); a[...,3]=np.maximum(a[...,3],c[...,3]*0.9); out=Image.fromarray(a.astype('uint8'))
    return out
if __name__=='__main__':
    for kind in DICE:
        for st in ('base','lit','cold'):
            save_svg(f'{D}/die_{kind}_{st}.svg',die_svg(kind,st,192))
            die_img(kind,st,192).save(f'{D}/die_{kind}_{st}_x4.png'); die_img(kind,st,48).save(f'{D}/die_{kind}_{st}_48.png')
    # comparison board
    W,H=1500,1080; bg=Image.new('RGBA',(W,H),hx(FELT)+(255,))
    lab=''
    cols=['base','lit','cold']
    for r,kind in enumerate(DICE):
        for c,st in enumerate(cols):
            bg.alpha_composite(die_img(kind,st,48),(60+c*90,120+r*110))
            bg.alpha_composite(die_img(kind,st,192),(380+c*360,40+r*300))
            lab+=text(380+c*360+144,40+r*300+292,f'{kind} / {st}',26,BONE,anchor='middle')
        lab+=text(30,120+r*110+44,kind,18,BONE,extra='transform="rotate(-90 30 %d)"'%(120+r*110+44))
    for c,st in enumerate(cols): lab+=text(84+c*90,100,st,18,BONE,anchor='middle')
    lab+=text(40,40,'48 px (actual)',22,BRASS)+text(40,690,'Greyscale check (value read, no hue):',26,BRASS)
    bg.alpha_composite(render(svgdoc(W,H,lab)))
    g=bg.crop((40,90,1500,640)).convert('L').convert('RGBA').resize((730,275),Image.LANCZOS)
    bg.alpha_composite(g,(40,720))
    bg.convert('RGB').save(f'{D}/dice_states_compare.png')
    # swatches + luminance
    sw=[('lit pip core (emission)',EC),('lit pip ring / rim (emission)',EM),('bone base',BONE),('bone lit',None),('bone cold',cold(BONE)),('charcoal base','#2E2A28'),('charcoal cold',cold('#2E2A28')),('bone-die cold pip',None)]
    import json
    bl=tohex(np.minimum(1,rgb(BONE)*np.array([1.04,1.0,0.94])+np.array([0.04,0.02,0])))
    cp=tohex(rgb(cold(PIT))*(1-COLD_PIP_TOWARD_BODY)+rgb(cold(BONE))*COLD_PIP_TOWARD_BODY)
    sw[3]=('bone lit',bl); sw[7]=('bone-die cold pip',cp)
    body=''; rows=[]
    for i,(n,c) in enumerate(sw):
        L_=float(rgb(c)@[0.2126,0.7152,0.0722])
        body+=f'<rect x="20" y="{20+i*70}" width="120" height="56" rx="8" fill="{c}" stroke="{PIT}" stroke-width="4"/>'+text(160,58+i*70,f'{n}  {c}  rel.lum≈{L_:.2f}',28,BONE)
        rows.append(dict(name=n,hex=c,rel_lum_srgb_approx=round(L_,3)))
    s=svgdoc(800,600,body,bg=OX); save_svg(f'{D}/dice_states_swatches.svg',s); render(s).save(f'{D}/dice_states_swatches.png')
    json.dump(rows,open(f'{D}/swatches.json','w'),indent=1); print(rows)
