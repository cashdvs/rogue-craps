import os, math, json
from common import *
def P(*a): return os.path.join(OUT,*a)
for d in ('bounty','banner','dice_states','value_tags'): os.makedirs(P(d),exist_ok=True)
ink=lambda w: f'stroke="{PIT}" stroke-width="{w}" stroke-linejoin="round"'
# ---------------- mini dice icons (20 pt display, authored at 80 px = @4x) ----------------
PIPS={1:[(0,0)],2:[(-1,-1),(1,1)],3:[(-1,-1),(0,0),(1,1)],4:[(-1,-1),(1,-1),(-1,1),(1,1)],5:[(-1,-1),(1,-1),(0,0),(-1,1),(1,1)],6:[(-1,-1),(1,-1),(-1,0),(1,0),(-1,1),(1,1)]}
def mini_die(v, s=80):
    b=f'<rect x="5" y="5" width="70" height="70" rx="16" fill="{BONE}" {ink(7)}/>'
    b+=f'<path d="M14 68 L66 68 Q70 68 70 62 L70 20" fill="none" stroke="{mix(BONE,BRASS,0.55)}" stroke-width="5" stroke-linecap="round" opacity="0.8"/>'
    if v=='any':
        b+=f'<rect x="17" y="17" width="46" height="46" rx="8" fill="none" stroke="{PIT}" stroke-width="4" stroke-dasharray="8 6"/>'
        b+=text(40,53,'?',38,PIT,anchor='middle')
    else:
        for (i,j) in PIPS[v]: b+=f'<circle cx="{40+i*19}" cy="{40+j*19}" r="7.5" fill="{PIT}"/>'
    return svgdoc(s,s,b)
def run_arrow():
    b=f'<path d="M6 28 L30 28 L30 16 L54 40 L30 64 L30 52 L6 52 Z" fill="{BRASS}" {ink(6)}/>'
    b+=f'<path d="M12 34 L34 34" stroke="{BRASS_HI}" stroke-width="4" stroke-linecap="round"/>'
    return svgdoc(60,80,b)
icons={}
for v in [1,2,3,4,5,6,'any']:
    svg=mini_die(v); save_svg(P('bounty',f'icon_die_{v}.svg'),svg); render(svg).save(P('bounty',f'icon_die_{v}.png')); icons[v]=svg
svg=run_arrow(); save_svg(P('bounty','icon_run_arrow.svg'),svg); render(svg).save(P('bounty','icon_run_arrow.png'))
# ---------------- bounty card frame (136 x 72 pt, @4x = 544 x 288) ----------------
CW,CH=544,288
def card_frame():
    b=f'<rect x="6" y="6" width="{CW-12}" height="{CH-12}" rx="26" fill="{BRASS}" {ink(9)}/>'
    b+=f'<rect x="16" y="16" width="{CW-32}" height="{CH-32}" rx="18" fill="none" stroke="{BRASS_HI}" stroke-width="4" opacity="0.7"/>'
    b+=f'<rect x="24" y="24" width="{CW-48}" height="{CH-48}" rx="14" fill="{BONE}" stroke="{BRASS_LO}" stroke-width="5"/>'
    b+=f'<line x1="44" y1="92" x2="{CW-44}" y2="92" stroke="{BRASS_LO}" stroke-width="4" stroke-dasharray="14 8"/>'   # title rule
    for (x,y) in ((18,18),(CW-18,18),(18,CH-18),(CW-18,CH-18)):
        b+=f'<circle cx="{x}" cy="{y}" r="9" fill="{BRASS_HI}" {ink(4)}/>'
    return svgdoc(CW,CH,b)
def grime_card(im):
    a=np.asarray(im).astype(float); h,w=a.shape[:2]; n=noise(w,h,5)
    yy,xx=np.mgrid[0:h,0:w]; edge=np.minimum(np.minimum(xx,w-xx),np.minimum(yy,h-yy))/40.0
    dark=1-0.18*np.clip((n-0.4)*2,0,1)-0.12*np.clip(1-edge,0,1)
    a[...,:3]*=dark[...,None]; return Image.fromarray(a.clip(0,255).astype('uint8'))
fsvg=card_frame(); save_svg(P('bounty','card_frame.svg'),fsvg); frame=grime_card(render(fsvg)); frame.save(P('bounty','card_frame.png'))
TITLE_CAP=10.0  # pt
def card_composite(title, pattern, scale=4):
    """pattern: list of die values / 'arrow'. Returns RGBA at scale (4 => 544x288)."""
    im=frame.copy() if scale==4 else frame.resize((136*scale,72*scale),Image.LANCZOS)
    em=TITLE_CAP/CAP_B*scale
    t=render(svgdoc(136*scale,72*scale,text(68*scale,(8+TITLE_CAP+4)*scale,title,em,PIT,anchor='middle')))
    im.alpha_composite(t)
    sizes=[(12 if p=='arrow' else 20) for p in pattern]; gap=3; tot=sum(sizes)+gap*(len(sizes)-1)
    x=68-tot/2; y=34
    for p,sz in zip(pattern,sizes):
        ic = render(run_arrow(), 12*scale, 20*scale) if p=='arrow' else render(icons[p],20*scale,20*scale)
        im.alpha_composite(ic,(round(x*scale),round(y*scale))); x+=sz+gap
    return im
# ---------------- PENDING ghost stamp ----------------
def pending(col):
    w,h=480,200; em=12/CAP_B*4
    b=f'<g transform="rotate(-6 {w/2} {h/2})"><rect x="40" y="44" width="400" height="112" rx="22" fill="none" stroke="{col}" stroke-width="10" stroke-dasharray="26 16"/>'
    b+=text(w/2,h/2+12*4/2,'PENDING',em,col,anchor='middle',extra='letter-spacing="8"')+'</g>'
    return svgdoc(w,h,f'<g opacity="0.25">{b}</g>'), svgdoc(w,h,b)
for nm,col in (('oxblood',OX),('bone',BONE)):
    s25,s100=pending(col)
    save_svg(P('bounty',f'stamp_pending_{nm}.svg'),s25); render(s25).save(P('bounty',f'stamp_pending_{nm}_25pct.png'))
    render(s100).save(P('bounty',f'stamp_pending_{nm}_opaque.png'))
# ---------------- CLAIMED wax seal ----------------
def blob_path(cx,cy,rx,ry,seed=4,wob=0.07,n=72):
    rng=np.random.default_rng(seed); ph=rng.random(4)*6.28; pts=[]
    for i in range(n):
        a=2*math.pi*i/n; r=1+wob*(0.6*math.sin(3*a+ph[0])+0.4*math.sin(7*a+ph[1])+0.25*math.sin(13*a+ph[2]))
        pts.append((cx+rx*r*math.cos(a), cy+ry*r*math.sin(a)))
    return 'M'+' L'.join(f'{x:.1f} {y:.1f}' for x,y in pts)+' Z'
def seal_body(w,h):
    cx,cy=w/2,h/2; rx,ry=200,124  # @4x => 100 x 62 pt
    b=f'<path d="{blob_path(cx,cy,rx+18,ry+16,seed=9,wob=0.10)}" fill="{mix(BURG,OX,0.35)}" {ink(8)}/>'  # spread wax
    for (dx,dy,r) in ((-150,110,22),(120,118,16),(178,40,14)):   # drips
        b+=f'<circle cx="{cx+dx}" cy="{cy+dy}" r="{r}" fill="{mix(BURG,OX,0.35)}" {ink(6)}/>'
    b+=f'<path d="{blob_path(cx,cy,rx,ry,seed=4,wob=0.04)}" fill="{BURG}" stroke="{OX}" stroke-width="7"/>'
    b+=f'<ellipse cx="{cx}" cy="{cy}" rx="{rx-26}" ry="{ry-24}" fill="none" stroke="{OX}" stroke-width="6" opacity="0.8"/>'
    b+=f'<ellipse cx="{cx}" cy="{cy}" rx="{rx-32}" ry="{ry-30}" fill="none" stroke="{mix(BURG,HF,0.5)}" stroke-width="3" opacity="0.7"/>'
    b+=f'<path d="M{cx-rx+40} {cy-50} Q{cx-60} {cy-ry+14} {cx+40} {cy-ry+22}" fill="none" stroke="{mix(BURG,BONE,0.35)}" stroke-width="9" stroke-linecap="round" opacity="0.55"/>'
    em=11.5/CAP_B*4; base=cy+11.5*4/2
    b+=text(cx+3,base+4,'CLAIMED',em,OX,anchor='middle')               # emboss shadow
    b+=text(cx-1.5,base-2,'CLAIMED',em,mix(BONE,'#FFFFFF',0.3),anchor='middle',extra='opacity="0.6"')
    b+=text(cx,base,'CLAIMED',em,BONE,anchor='middle')
    return b
W2,H2=512,384
seal_rot=svgdoc(W2,H2,f'<g transform="rotate(-10 {W2/2} {H2/2})">{seal_body(W2,H2)}</g>')
save_svg(P('bounty','stamp_claimed.svg'),seal_rot); seal_img=render(seal_rot); seal_img.save(P('bounty','stamp_claimed.png'))
dec=svgdoc(512,512,seal_body(512,512)); save_svg(P('bounty','stamp_claimed_decal3d.svg'),dec); render(dec).save(P('bounty','stamp_claimed_decal3d_512.png'))
# stamp-in sheet: 6 frames x 512x384
FRAMES=[(1.60,1.00,1.00,0.00,-16),(1.25,1.00,1.00,0.85,-12),(1.00,1.14,0.82,1.0,-10),(1.00,0.95,1.06,1.0,-10),(1.00,1.02,0.98,1.0,-10),(1.00,1.00,1.00,1.0,-10)]
sheet=Image.new('RGBA',(W2*6,H2))
for i,(s,sx,sy,al,rot) in enumerate(FRAMES):
    g=f'<g opacity="{al}" transform="translate({W2/2} {H2/2}) rotate({rot}) scale({s*sx*0.62} {s*sy*0.62}) translate({-W2/2} {-H2/2})">{seal_body(W2,H2)}</g>'
    sheet.alpha_composite(render(svgdoc(W2,H2,g)),(i*W2,0))
sheet.save(P('bounty','stamp_claimed_stampin_sheet_6x1.png'))
json.dump([dict(frame=i,t=round(i*0.045,3),scale=f[0],scale_x=f[1],scale_y=f[2],alpha=f[3],rot_deg=f[4]) for i,f in enumerate(FRAMES)],open(P('bounty','stamp_claimed_stampin_keys.json'),'w'),indent=1)
# composites
c1=card_composite('RUN OF 3',['any','arrow','any','arrow','any']); c1.save(P('bounty','card_run3_clean.png'))
p=Image.open(P('bounty','stamp_pending_oxblood_25pct.png')).resize((400,167),Image.LANCZOS)
c1p=c1.copy(); c1p.alpha_composite(p,(72,110)); c1p.save(P('bounty','card_run3_pending.png'))
c2=card_composite('PAIR OF 6s',[6,6]); c2.save(P('bounty','card_pair6_clean.png'))
sl=seal_img.resize((408,306),Image.LANCZOS); c2c=Image.new('RGBA',(CW,CH+48)); c2c.alpha_composite(c2); c2c.alpha_composite(sl,(150,22))  # seal 0.8x => CLAIMED cap 9.2 pt; canvas 544x336; c2c.save(P('bounty','card_pair6_claimed.png'))
# ---------------- TABLE CLEARED banner (358 x 112 pt, @3x = 1074 x 336) ----------------
BS=3; BW,BH=358*BS,112*BS
def L(v): return v*BS
tail_c=mix(BURG,OX,0.4)
tails=f'<path d="M{L(4)} {L(46)} L{L(74)} {L(46)} L{L(74)} {L(98)} L{L(4)} {L(98)} L{L(22)} {L(72)} Z" fill="{tail_c}" {ink(L(1.8))}/>'
tails+=f'<path d="M{L(354)} {L(46)} L{L(284)} {L(46)} L{L(284)} {L(98)} L{L(354)} {L(98)} L{L(336)} {L(72)} Z" fill="{tail_c}" {ink(L(1.8))}/>'
tails+=f'<path d="M{L(58)} {L(88)} L{L(74)} {L(98)} L{L(74)} {L(86)} Z M{L(300)} {L(88)} L{L(284)} {L(98)} L{L(284)} {L(86)} Z" fill="{OX}"/>'
ribbon=f'<path d="M{L(40)} {L(30)} Q{L(179)} {L(18)} {L(318)} {L(30)} L{L(318)} {L(90)} Q{L(179)} {L(78)} {L(40)} {L(90)} Z" fill="{BURG}" {ink(L(2))}/>'
ribbon+=f'<path d="M{L(48)} {L(38)} Q{L(179)} {L(27)} {L(310)} {L(38)}" fill="none" stroke="{mix(BURG,BONE,0.25)}" stroke-width="{L(1.5)}" opacity="0.6"/>'
frame_b=f'<path d="M{L(50)} {L(34)} Q{L(179)} {L(23)} {L(308)} {L(34)} L{L(308)} {L(86)} Q{L(179)} {L(75)} {L(50)} {L(86)} Z" fill="none" stroke="{PIT}" stroke-width="{L(6)}"/>'
frame_b+=f'<path d="M{L(50)} {L(34)} Q{L(179)} {L(23)} {L(308)} {L(34)} L{L(308)} {L(86)} Q{L(179)} {L(75)} {L(50)} {L(86)} Z" fill="none" stroke="{BRASS}" stroke-width="{L(3.6)}"/>'
frame_b+=f'<path d="M{L(53)} {L(37)} Q{L(179)} {L(26.5)} {L(305)} {L(37)}" fill="none" stroke="{BRASS_HI}" stroke-width="{L(1.2)}"/>'
for (x,y) in ((50,34),(308,34),(50,86),(308,86)):
    frame_b+=f'<circle cx="{L(x)}" cy="{L(y)}" r="{L(4.2)}" fill="{BRASS_HI}" {ink(L(1.4))}/>'
TXT='TABLE CLEARED'; tem=min(232/tw(TXT,1,FA),40); tcap=tem*CAP_A; tbase=60+tcap/2-1
textl=text(L(179),L(tbase),TXT,L(tem),BONE,path=FA,anchor='middle',extra=f'stroke="{PIT}" stroke-width="{L(2.6)}" paint-order="stroke"')
def sparkle(x,y,r,c):
    return f'<path d="M{x} {y-r} Q{x+r*0.18} {y-r*0.18} {x+r} {y} Q{x+r*0.18} {y+r*0.18} {x} {y+r} Q{x-r*0.18} {y+r*0.18} {x-r} {y} Q{x-r*0.18} {y-r*0.18} {x} {y-r} Z" fill="{c}"/>'
sp=''.join(sparkle(L(x),L(y),L(r),c) for x,y,r,c in ((62,22,6,EC),(296,24,5,EC),(84,98,4,EM),(272,96,5,EC),(170,14,4,EM),(330,64,4,EM),(28,62,4,EC)))
layers={'01_tails':tails,'02_ribbon':ribbon,'03_brass_frame':frame_b,'05_text':textl,'06_sparkles':sp}
imgs={}
for k,v in layers.items():
    s=svgdoc(BW,BH,v); save_svg(P('banner',f'table_cleared_{k}.svg'),s); imgs[k]=render(s); imgs[k].save(P('banner',f'table_cleared_{k}.png'))
# ember glow (additive layer): blurred ember text
gl=render(svgdoc(BW,BH,text(L(179),L(tbase),TXT,L(tem),EM,path=FA,anchor='middle',extra=f'stroke="{EM}" stroke-width="{L(5)}"')))
gl=gl.filter(ImageFilter.GaussianBlur(L(5))); ga=np.asarray(gl).astype(float); ga[...,3]=np.clip(ga[...,3]*1.6,0,255)
gl=Image.fromarray(ga.astype('uint8')); gl.save(P('banner','table_cleared_04_ember_glow_ADD.png')); imgs['04']=gl
comp=Image.new('RGBA',(BW,BH))
for k in ('01_tails','02_ribbon','03_brass_frame'): comp.alpha_composite(imgs[k])
# approximate additive for the flat composite
c=np.asarray(comp).astype(float); g=np.asarray(gl).astype(float); a=g[...,3:4]/255*0.8
c[...,:3]=np.clip(c[...,:3]+g[...,:3]*a,0,255); c[...,3]=np.maximum(c[...,3],g[...,3]*0.8)
comp=Image.fromarray(c.astype('uint8')); comp.alpha_composite(imgs['05_text']); comp.alpha_composite(imgs['06_sparkles'])
comp.save(P('banner','table_cleared_composite_3x.png'))
save_svg(P('banner','table_cleared_full.svg'),svgdoc(BW,BH,tails+ribbon+frame_b+textl+sp))
json.dump(dict(text_em_pt=round(tem,2),text_cap_pt=round(tcap,2)),open(P('banner','_metrics.json'),'w'))
print('banner cap pt',tcap)
# ---------------- value tags (26 pt tall, authored @4x = 104 px) ----------------
TS=4; TH_=26
def pill(wpt, inner=''):
    w=wpt*TS; h=TH_*TS; r=h/2-6
    b=f'<rect x="6" y="6" width="{w-12}" height="{h-12}" rx="{r}" fill="{LEATHER}" stroke="{OX}" stroke-width="10"/>'
    b+=f'<rect x="12" y="12" width="{w-24}" height="{h-24}" rx="{r-6}" fill="none" stroke="{BRASS}" stroke-width="7"/>'
    b+=f'<path d="M{r+4} 22 L{w-r-4} 22" stroke="{mix(LEATHER,BONE,0.25)}" stroke-width="4" stroke-linecap="round" opacity="0.7"/>'
    return svgdoc(w,h,b+inner)
NCAP=13.0; NEM=NCAP/CAP_B
def num(x,s,anchor='middle',col=BONE): return text(x*TS,(TH_/2+NCAP/2)*TS,s,NEM*TS,col,anchor=anchor)
def star4(cx,cy,r,fill):
    return f'<path d="M{cx} {cy-r} L{cx+r*0.28} {cy-r*0.28} L{cx+r} {cy} L{cx+r*0.28} {cy+r*0.28} L{cx} {cy+r} L{cx-r*0.28} {cy+r*0.28} L{cx-r} {cy} L{cx-r*0.28} {cy-r*0.28} Z" fill="{fill}" stroke="{PIT}" stroke-width="5" stroke-linejoin="round"/>'
def arrow(x0,x1,y):
    return f'<path d="M{x0} {y} L{x1-14} {y}" stroke="{BRASS_HI}" stroke-width="7" stroke-linecap="round"/><path d="M{x1-22} {y-12} L{x1} {y} L{x1-22} {y+12} Z" fill="{BRASS_HI}"/>'
tags={}
base=pill(40); save_svg(P('value_tags','tag_9slice_base.svg'),base); render(base).save(P('value_tags','tag_9slice_base.png'))  # 160x104
def mk(name,wpt,inner):
    s=pill(wpt,inner); save_svg(P('value_tags',f'{name}.svg'),s); im=render(s); im.save(P('value_tags',f'{name}.png')); tags[name]=im
for n in ['1','2','3','4','5','6','7','8','9','10','11','12','20']:
    wpt=max(30, tw(n,NEM)+18); mk(f'tag_num_{n}',math.ceil(wpt),num(math.ceil(wpt)/2,n))
mk('tag_wild',30,star4(15*TS,13*TS,10*TS,BONE))
kw=math.ceil(20+tw('9',NEM)+14)
mk('tag_kicker_9',kw,f'<circle cx="{13*TS}" cy="{13*TS}" r="{8.5*TS}" fill="{BRASS}" stroke="{PIT}" stroke-width="5"/>'+text(13*TS,(13+4.5)*TS,'K',9/CAP_B*TS,PIT,anchor='middle')+num(23+tw('9',NEM)/2,'9'))
a_w=tw('IX',NEM); b_w=tw('3',NEM); cw=math.ceil(9+a_w+4+14+4+b_w+9)
mk('tag_countsas_IX_3',cw,num(9,'IX','start',mix(BONE,BRASS,0.35))+arrow((9+a_w+4)*TS,(9+a_w+4+14)*TS,13*TS)+num(9+a_w+22,'3','start'))
ptr=svgdoc(40,24,f'<path d="M4 2 L36 2 L20 22 Z" fill="{BRASS}" stroke="{OX}" stroke-width="4" stroke-linejoin="round"/>'); save_svg(P('value_tags','tag_pointer.svg'),ptr); render(ptr).save(P('value_tags','tag_pointer.png'))
gl=svgdoc(80,80,star4(40,40,36,BONE)); save_svg(P('value_tags','glyph_wild_star.svg'),gl); render(gl).save(P('value_tags','glyph_wild_star.png'))
json.dump({k:list(v.size) for k,v in tags.items()},open(P('value_tags','_sizes_4x.json'),'w'),indent=0)
print('ok')
