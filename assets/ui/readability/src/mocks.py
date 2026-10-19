import os, json
from common import *
import felt, dice
M=os.path.join(OUT,'mocks'); os.makedirs(M,exist_ok=True)
R='/workspace/dice/art/renders'
def P(*a): return os.path.join(OUT,*a)
def decal_img(kind):
    svg,items,_=(felt.landscape if kind=='landscape' else felt.portrait)(True)
    return wear(render(svg),0.30,seed=11), items
def lit_mod(dec_warped, base, emission=0.35):
    """printed ink is lit by the lamp: scale by local felt brightness, plus the recommended unshaded emission floor"""
    b=np.asarray(base.convert('L').filter(ImageFilter.GaussianBlur(25))).astype(float)/255
    ref=np.percentile(b[b>0.05],95) if (b>0.05).any() else 1
    m=np.clip(emission+(1-emission)*np.clip(b/ref*1.15,0,1),0,1)
    a=np.asarray(dec_warped).astype(float); a[...,:3]*=m[...,None]; return Image.fromarray(a.clip(0,255).astype('uint8'))
def measure(H, items, kind):
    out=[]
    for it in items:
        if kind=='landscape':
            xm=(it['x0']+it['x1'])/2; p1=(felt.px(xm),felt.pz(it['z_base'])); p2=(felt.px(xm),felt.pz(it['z_top']))
        else:
            zm=(it['z0']+it['z1'])/2; p1=(felt.px(it['x_base']),felt.pz(zm)); p2=(felt.px(it['x_top']),felt.pz(zm))
        a=apply_h(H,*p1); b=apply_h(H,*p2); out.append((round(float(np.hypot(a[0]-b[0],a[1]-b[1])),2),it['kind'],it['text']))
    return sorted(out)
def d12_svg(s):
    k=s/48; import math
    pts=' '.join(f'{s/2+20*k*math.cos(math.radians(-90+72*i)):.1f},{s/2+2*k+20*k*math.sin(math.radians(-90+72*i)):.1f}' for i in range(5))
    b=f'<polygon points="{pts}" fill="{BONE}" stroke="{EM}" stroke-width="{5*k}" stroke-linejoin="round"/><polygon points="{pts}" fill="none" stroke="{PIT}" stroke-width="{2.4*k}" stroke-linejoin="round"/>'
    b+=text(s/2,s/2+8*k,'IX',16*k,mix(EM,PIT,0.3),anchor='middle')
    return svgdoc(s,s,b)
def paste_c(base,im,cx,cy): base.alpha_composite(im,(int(round(cx-im.width/2)),int(round(cy-im.height/2))))
def tag(name, h_px):
    im=Image.open(P('value_tags',f'{name}.png')); w=round(im.width*h_px/im.height); return im.resize((w,h_px),Image.LANCZOS)
def banner(w_px):
    im=Image.open(P('banner','table_cleared_composite_3x.png')); return im.resize((w_px,round(im.height*w_px/im.width)),Image.LANCZOS)
def card(name,w_px):
    im=Image.open(P('bounty',name)); return im.resize((w_px,round(im.height*w_px/im.width)),Image.LANCZOS)
def die(kind,state,px):
    im=dice.die_img(kind,state,px*3); return im.resize((im.width//3,im.height//3),Image.LANCZOS)
report={}
def mock(name, base_path, kind, corners, ui, out_size=None, place=None, fit_width=None, ss=1):
    base=Image.open(base_path).convert('RGBA')
    off=(0,0)
    if fit_width:
        W,Hh=fit_width; sc=W*ss/base.width; nb=base.resize((W*ss,round(base.height*sc)),Image.LANCZOS)
        canvas=Image.new('RGBA',(W*ss,Hh*ss),(8,6,6,255)); off=(0,(Hh*ss-nb.height)//2); canvas.alpha_composite(nb,off)
        corners=[(x*sc+off[0],y*sc+off[1]) for x,y in corners]; base=canvas
    dec,items=decal_img(kind)
    src=[(0,0),(dec.width,0),(dec.width,dec.height),(0,dec.height)]
    H=homography(src,corners); wd=warp(dec,H,base.size)
    wd=lit_mod(wd,base); base.alpha_composite(wd)
    meas=measure(H,items,kind)
    place(base,ss)
    if ss>1:
        base.convert('RGB').save(f'{M}/{name}_3x.png'); base=base.resize((base.width//ss,base.height//ss),Image.LANCZOS); meas=[(round(m/ss,2),k,t) for m,k,t in meas]
    base.convert('RGB').save(f'{M}/{name}.png')
    report[name]=dict(size=list(base.size),felt_text_min_cap_px=meas[0],felt_text_max_cap_px=meas[-1],felt_text_all=meas)
# ---------- PC 1920x1080 (UI scale 2.0 pt->px) ----------
def place_pc(b,ss):
    u=2.0
    b.alpha_composite(card('card_run3_pending.png',int(136*u)),(1330,24)); b.alpha_composite(card('card_pair6_claimed.png',int(136*u)),(1620,24))
    for (cx,cy),st in (((990,544),'lit'),((788,624),'cold'),((1180,696),'lit')):
        paste_c(b,die('bone',st,80),cx,cy)
    paste_c(b,die('charcoal','cold',70),640,560)
    d12=render(d12_svg(84)); paste_c(b,d12,1480,560)
    t=tag('tag_countsas_IX_3',int(26*u)); paste_c(b,t,1480,560-42-34)
    t=tag('tag_num_5',int(26*u)); paste_c(b,t,1180,696-40-34)
    bn=banner(int(358*u)); paste_c(b,bn,960,470)
mock('mock_pc_1920x1080',f'{R}/smiles/camera_v3/smiles_idle_pc.png','landscape',[(360,398),(1560,398),(1752,902),(168,902)],2.0,place=place_pc)
# ---------- phone landscape 844x390 (1 pt = 1 px) ----------
def place_ls(b,ss):
    b.alpha_composite(card('card_run3_pending.png',136),(704,2)); b.alpha_composite(card('card_pair6_claimed.png',136),(4,2))
    for (cx,cy),st in (((435,168),'lit'),((352,201),'cold'),((513,229),'lit')):
        paste_c(b,die('bone',st,32),cx,cy)
    paste_c(b,render(d12_svg(34)),600,170); paste_c(b,tag('tag_countsas_IX_3',26),600,170-17-14)
    paste_c(b,tag('tag_num_5',26),513,229-15-14)
    paste_c(b,banner(358),422,178)
mock('mock_phone_landscape_844x390',f'{R}/smiles/camera_v3/smiles_idle_phone.png','landscape',[(180,112),(668,112),(752,311),(88,311)],1.0,place=place_ls)
# ---------- phone portrait 390x844, rendered at 3x then downsampled (1 pt = 1 px) ----------
def place_pt(b,ss):
    u=ss
    b.alpha_composite(card('card_run3_pending.png',136*u),(52*u,8*u)); b.alpha_composite(card('card_pair6_claimed.png',136*u),(200*u,8*u))
    for (cx,cy),st in (((195,353),'lit'),((246,428),'cold'),((153,503),'lit')):
        paste_c(b,die('bone',st,32*u),cx*u,cy*u)
    paste_c(b,die('charcoal','cold',30*u),110*u,(440+75)*u)
    paste_c(b,render(d12_svg(34*u)),300*u,560*u); paste_c(b,tag('tag_countsas_IX_3',26*u),300*u,(560-17-14)*u)
    paste_c(b,tag('tag_num_5',26*u),153*u,(503-16-14)*u)
    paste_c(b,banner(358*u),195*u,262*u)
pc=[(85,1800),(197,335),(930,335),(1025,1800)]
mock('mock_phone_portrait_390x844',f'{R}/hearth/hearth_phone_portrait.png','portrait',pc,1.0,place=place_pt,fit_width=(390,844),ss=3)
# also: what the LANDSCAPE decal would look like in portrait (to show why the swap is needed)
def nothing(b,ss): pass
pcL=[(197,335),(930,335),(1025,1800),(85,1800)]  # wrong: maps texture onto rotated felt only for illustration
json.dump(report,open(f'{M}/measurements.json','w'),indent=1)
for k,v in report.items(): print(k,v['size'],'min',v['felt_text_min_cap_px'],'max',v['felt_text_max_cap_px'])
