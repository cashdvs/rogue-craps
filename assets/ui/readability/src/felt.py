import json
from common import *
S = 2048/2.04           # px per metre
TW, TH = 2048, round(1.04*S)  # 2048 x 1044
COMBOS = [  # name, tier (0 bone,1 ember,2 hellfire,3 black-gold), mock value for review only
 ('Pair',0,'Lv1 10x2'),('Run of 3',0,'Lv1 20x2'),('Two Pair',1,'Lv2 30x3'),('Trips',1,'Lv3 60x5'),
 ('Run of 4',1,'Lv1 40x3'),('Full House',2,'Lv1 50x4'),('Run of 5',2,'Lv2 85x6'),('Quads',2,'Lv1 80x5'),
 ('Five of a Kind',3,'Lv1 120x8')]
TIERC = [BONE, EM, HF, PIT]
NAMEC = mix(BRASS, BONE, 0.35)   # gold-leaf print ink
def px(x): return (x+1.02)*S
def pz(z): return (z+0.52)*S
def diamond(cx,cy,w,h,fill,stroke,sw):
    return f'<path d="M{cx:.1f} {cy-h/2:.1f} L{cx+w/2:.1f} {cy:.1f} L{cx:.1f} {cy+h/2:.1f} L{cx-w/2:.1f} {cy:.1f} Z" fill="{fill}" stroke="{stroke}" stroke-width="{sw:.1f}" stroke-linejoin="round"/>'
def pipfill(t): return TIERC[t]
def pips_col(cx, ztop, zbot, t, k):   # stacked diamonds, count=tier+1
    n=t+1; h=0.020*S; w=0.020*S; gap=0.006*S; tot=n*h+(n-1)*gap
    cy0=(pz(ztop)+pz(zbot))/2-tot/2+h/2; out=''
    for i in range(n):
        st = BRASS if t==3 else PIT
        out+=diamond(cx, cy0+i*(h+gap), w, h, pipfill(t), st, 0.004*S)
    return out
# ---------- LANDSCAPE / PC decal: thin band along the near rail ----------
LK = 1.40; LCAP = 0.046          # glyphs stretched x1.4 along Z so they read upright through the camera's foreshortening
LEM = LCAP/LK/CAP_B              # em measured along X (m)
BAND = (0.372, 0.507); NAME_BASE=0.428; SLOT=(0.436,0.503); SLOT_BASE=0.4925
def landscape(dynamic=False):
    body=''; items=[]; slots=[]
    x0,x1=-0.985,0.985; gap=0.011; pipw=0.030; slotmin=0.166
    widths=[pipw+max(tw(n,LEM),slotmin) for n,_,_ in COMBOS]
    extra=((x1-x0)-sum(widths)-gap*(len(widths)-1))/len(widths)
    assert extra>=0, extra
    # band rules (gold leaf)
    for z in (BAND[0]-0.004, BAND[1]+0.004):
        body+=f'<line x1="{px(x0):.1f}" y1="{pz(z):.1f}" x2="{px(x1):.1f}" y2="{pz(z):.1f}" stroke="{BRASS}" stroke-width="{0.004*S:.1f}" stroke-linecap="round"/>'
    for xe,sgn in ((x0,1),(x1,-1)):   # end flourishes: brass teardrops
        cx=px(xe-sgn*0.012); cy=pz(sum(BAND)/2)
        body+=diamond(cx,cy,0.016*S,0.05*S,BRASS,PIT,0.003*S)
    x=x0
    for (name,t,mock),w in zip(COMBOS,widths):
        w+=extra
        if x>x0+0.01: body+=f'<line x1="{px(x-gap/2):.1f}" y1="{pz(BAND[0]+0.01):.1f}" x2="{px(x-gap/2):.1f}" y2="{pz(BAND[1]-0.01):.1f}" stroke="{BRASS}" stroke-width="{0.0025*S:.1f}" stroke-dasharray="{0.006*S:.0f} {0.006*S:.0f}" opacity="0.7"/>'
        body+=pips_col(px(x+0.013), BAND[0]+0.008, BAND[1]-0.008, t, LK)
        tx=x+pipw
        body+=f'<g transform="translate({px(tx):.1f},{pz(NAME_BASE):.1f}) scale(1,{LK})">'+text(0,0,name,LEM*S,NAMEC,extra=f'stroke="{PIT}" stroke-width="{0.0018*S:.1f}" paint-order="stroke"')+'</g>'
        items.append(dict(kind='name',text=name,x0=tx,x1=tx+tw(name,LEM),z_base=NAME_BASE,z_top=NAME_BASE-LCAP))
        sx0,sx1=tx-0.004, x+w
        body+=f'<rect x="{px(sx0):.1f}" y="{pz(SLOT[0]):.1f}" width="{(sx1-sx0)*S:.1f}" height="{(SLOT[1]-SLOT[0])*S:.1f}" rx="{0.008*S:.1f}" fill="{PIT}" fill-opacity="0.28" stroke="{BRASS}" stroke-width="{0.0025*S:.1f}" stroke-dasharray="{0.008*S:.0f} {0.005*S:.0f}" opacity="0.85"/>'
        cxm=(sx0+sx1)/2
        slots.append(dict(combo=name,tier=t,center_x=round(cxm,4),center_z=round((SLOT[0]+SLOT[1])/2,4),baseline_z=SLOT_BASE,
                          box_x=[round(sx0,4),round(sx1,4)],box_z=list(SLOT),max_text_width_m=round(sx1-sx0-0.008,4)))
        if dynamic:
            s=mock; sc=min(1.0,(sx1-sx0-0.008)/tw(s,LEM))
            body+=f'<g transform="translate({px(cxm):.1f},{pz(SLOT_BASE):.1f}) scale({sc:.3f},{LK})">'+text(0,0,s,LEM*S,BONE,anchor='middle',extra=f'stroke="{PIT}" stroke-width="{0.002*S:.1f}" paint-order="stroke"')+'</g>'
            items.append(dict(kind='slot',text=s,x0=cxm-0.05,x1=cxm+0.05,z_base=SLOT_BASE,z_top=SLOT_BASE-LCAP))
        x+=w+gap
    return svgdoc(TW,TH,body), items, slots
# ---------- PORTRAIT decal: block at the screen-bottom end of the felt (world -X), text upright for portrait ----------
PK=1.10; PCAP=0.034; PEM=PCAP/PK/CAP_B
XTOP=-0.722; PITCH=0.0545
def portrait(dynamic=False):
    # author in local coords: lx along +Z, ly along -X (screen down in portrait); then rotate into texture space
    L=lambda m: m*S
    body=''; items=[]; slots=[]
    cols=[(-0.50,-0.012),(0.012,0.50)]
    body+=f'<line x1="{L(0.02)}" y1="{L(-0.006)}" x2="{L(1.02)}" y2="{L(-0.006)}" stroke="{BRASS}" stroke-width="{0.004*S:.1f}" stroke-linecap="round"/>'
    body+=f'<line x1="{L(0.52)}" y1="{L(0.006)}" x2="{L(0.52)}" y2="{L(0.272)}" stroke="{BRASS}" stroke-width="{0.0025*S:.1f}" stroke-dasharray="{0.006*S:.0f} {0.006*S:.0f}" opacity="0.7"/>'
    for i,(name,t,mock) in enumerate(COMBOS):
        c=i//5; r=i%5; z0,z1=cols[c]; ly_top=0.006+r*PITCH; ly_base=ly_top+PCAP
        lx0=z0+0.52
        # pips: 2x2 grid of small diamonds, count = tier+1
        for j in range(t+1):
            cx=L(lx0+0.008+(j%2)*0.013); cy=L(ly_top+0.008+(j//2)*0.017)
            body+=diamond(cx,cy,0.012*S,0.015*S,TIERC[t],BRASS if t==3 else PIT,0.0025*S)
        nx=lx0+0.034
        body+=f'<g transform="translate({L(nx):.1f},{L(ly_base):.1f}) scale(1,{PK})">'+text(0,0,name,PEM*S,NAMEC,extra=f'stroke="{PIT}" stroke-width="{0.0016*S:.1f}" paint-order="stroke"')+'</g>'
        X_base=XTOP-ly_base; X_top=XTOP-ly_top
        items.append(dict(kind='name',text=name,z0=nx-0.52,z1=nx-0.52+tw(name,PEM),x_base=X_base,x_top=X_top))
        sw=0.165; sx1=z1+0.52; sx0=sx1-sw
        body+=f'<rect x="{L(sx0):.1f}" y="{L(ly_top-0.006):.1f}" width="{L(sw):.1f}" height="{L(PCAP+0.012):.1f}" rx="{0.007*S:.1f}" fill="{PIT}" fill-opacity="0.28" stroke="{BRASS}" stroke-width="{0.0022*S:.1f}" stroke-dasharray="{0.007*S:.0f} {0.005*S:.0f}" opacity="0.85"/>'
        cz=(sx0+sx1)/2-0.52
        slots.append(dict(combo=name,tier=t,center_z=round(cz,4),center_x=round(XTOP-(ly_top+PCAP/2),4),baseline_x=round(X_base,4),
                          box_z=[round(sx0-0.52,4),round(sx1-0.52,4)],box_x=[round(XTOP-(ly_top+PCAP+0.006),4),round(XTOP-(ly_top-0.006),4)],max_text_width_m=round(sw-0.008,4)))
        if dynamic:
            sc=min(1.0,(sw-0.008)/tw(mock,PEM))
            body+=f'<g transform="translate({L(cz+0.52):.1f},{L(ly_base):.1f}) scale({sc:.3f},{PK})">'+text(0,0,mock,PEM*S,BONE,anchor='middle',extra=f'stroke="{PIT}" stroke-width="{0.0018*S:.1f}" paint-order="stroke"')+'</g>'
            items.append(dict(kind='slot',text=mock,z0=cz-0.05,z1=cz+0.05,x_base=X_base,x_top=X_top))
    g=f'<g transform="matrix(0,1,-1,0,{(XTOP+1.02)*S:.2f},0)">{body}</g>'
    return svgdoc(TW,TH,g), items, slots
def build():
    import os
    d=OUT+'/felt'; os.makedirs(d,exist_ok=True)
    meta={}
    for nm,fn in (('landscape',landscape),('portrait',portrait)):
        svg,items,slots=fn(False); save_svg(f'{d}/felt_combo_decal_{nm}.svg',svg)
        im=wear(render(svg),0.30,seed=11 if nm=='landscape' else 12); im.save(f'{d}/felt_combo_decal_{nm}.png')
        svgd,itemsd,_=fn(True)
        meta[nm]=dict(items=itemsd,slots=slots)
    json.dump(meta,open(f'{d}/felt_slots.json','w'),indent=1)
    return meta
if __name__=='__main__':
    m=build(); print(json.dumps(m['landscape']['slots'][:2],indent=0)); print(m['portrait']['slots'][8])
