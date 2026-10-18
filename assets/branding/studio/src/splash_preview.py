"""Renders splash frames straight from ../splash_timings.json + the real PNG layers (for previews / QA)."""
import json, math, random, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path
D=str(Path(__file__).resolve().parent.parent)+"/"  # the studio folder above src/
J=json.load(open(D+"splash_timings.json"))
def ease(trans, e, x):
    def ein(x):
        return {"LINEAR":x,"QUAD":x*x,"CUBIC":x**3,"SINE":1-math.cos(x*math.pi/2),
                "EXPO":0 if x==0 else 2**(10*x-10),"BACK":2.70158*x**3-1.70158*x*x}[trans]
    if trans=="LINEAR": return x
    if e=="IN": return ein(x)
    if e=="OUT": return 1-ein(1-x)
    return ein(2*x)/2 if x<0.5 else 1-ein(2-2*x)/2
def state(layer, t):
    st=json.loads(json.dumps(layer["rest"])); st.setdefault("scale",[1,1]); st.setdefault("rotation",0); st.setdefault("modulate_a",1); st["modulate_rgb"]=1.0
    tr=sorted(layer["tracks"], key=lambda k:k.get("at",k.get("start",0)))
    for k in tr:
        p=k["prop"]
        if "set" in k:
            if t>=k["at"]: v=k["set"]
            else: continue
        else:
            if t<k["start"]: continue
            x=min(1,(t-k["start"])/k["dur"]); f=ease(k["trans"],k["ease"],x); a,b=k["from"],k["to"]
            v=[a[i]+(b[i]-a[i])*f for i in range(2)] if isinstance(a,list) else a+(b-a)*f
        if p=="position:x": st["position"][0]=v
        elif p=="position:y": st["position"][1]=v
        else: st[p]=v
    return st
def draw_sprite(canvas, tex, pivot, st, reveal=None):
    im=Image.open(D+tex).convert("RGBA")
    if reveal is not None and reveal<1:
        w=im.width; edge=0.06*w; xr=reveal*(w+edge)
        m=Image.new("L",im.size,0); px=m.load()
        col=[max(0,min(255,int(255*(xr-x)/edge))) for x in range(w)]
        for x in range(w):
            for y in range(im.height): px[x,y]=col[x]
        a=im.getchannel("A"); im.putalpha(Image.composite(a,Image.new("L",im.size,0),m))
    if st["modulate_rgb"]!=1.0:
        r,g,b,a=im.split(); k=st["modulate_rgb"]; r,g,b=[c.point(lambda v:min(255,int(v*k))) for c in (r,g,b)]; im=Image.merge("RGBA",(r,g,b,a))
    if st["modulate_a"]<1:
        im.putalpha(im.getchannel("A").point(lambda v:int(v*max(0,st["modulate_a"]))))
    sx,sy=[0.5*s for s in st["scale"]]
    if sx<=1e-4 or sy<=1e-4: return
    th=math.radians(st["rotation"]); c,s=math.cos(th),math.sin(th); px,py=st["position"]
    # canvas -> local: l = pivot + S^-1 R^-1 (p - pos)
    a=c/sx; b=s/sx; d=-s/sy; e=c/sy
    coef=(a,b,pivot[0]-a*px-b*py, d,e,pivot[1]-d*px-e*py)
    layer=im.transform(canvas.size, Image.AFFINE, coef, resample=Image.BICUBIC)
    canvas.alpha_composite(layer)
def particles(canvas,t,b):
    t0=t-b["emit_at"]
    if t0<0: return
    part=Image.open(D+b["texture"]).convert("RGBA"); rnd=random.Random(7)
    ramp=b["color_ramp"]
    def col(u):
        for i in range(len(ramp)-1):
            if ramp[i][0]<=u<=ramp[i+1][0]:
                f=(u-ramp[i][0])/(ramp[i+1][0]-ramp[i][0]); c0=ramp[i][1]; c1=ramp[i+1][1]
                h=lambda c,k:int(c[1+2*k:3+2*k],16)
                return tuple(int(h(c0,k)+(h(c1,k)-h(c0,k))*f) for k in range(3))+(ramp[i][2]+(ramp[i+1][2]-ramp[i][2])*f,)
        return (255,255,255,0)
    for i in range(b["amount"]):
        life=b["lifetime"]*(1-b["randomness"]*rnd.random())
        ang=math.radians(-90+rnd.uniform(-b["spread_deg"],b["spread_deg"])); v=rnd.uniform(*b["initial_velocity"]); damp=rnd.uniform(*b["damping"])
        scl=rnd.uniform(*b["scale"])
        if t0>life: continue
        u=t0/life; vx,vy=v*math.cos(ang),v*math.sin(ang); x,y=b["position"]; dt=1/240
        for _ in range(int(t0/dt)):
            sp=math.hypot(vx,vy); 
            if sp>0: k=max(0,sp-damp*dt)/sp; vx*=k; vy*=k
            vy+=b["gravity"][1]*dt; x+=vx*dt; y+=vy*dt
        r,g,bb,al=col(u); sz=max(2,int(64*scl*(1-u)))
        p=part.resize((sz,sz)); tint=Image.new("RGBA",p.size,(r,g,bb,255)); tint.putalpha(p.getchannel("A").point(lambda q:int(q*al)))
        canvas.alpha_composite(tint,(int(x-sz/2),int(y-sz/2)))
def frame(t):
    cv=Image.new("RGBA",(1920,1080),J["background"]["color"])
    L=J["layers"]
    draw_sprite(cv,L["anvil"]["texture"],L["anvil"]["pivot_px"],state(L["anvil"],t))
    w=L["wordmark"]
    for k in ("main","games"):
        st=state(w[k],t); rv=st.get("reveal",None)
        draw_sprite(cv,w[k]["texture"],w[k]["pivot_px"],st,reveal=rv)
    draw_sprite(cv,L["hammer"]["texture"],L["hammer"]["pivot_px"],state(L["hammer"],t))
    particles(cv,t,L["sparks"]["burst"])
    draw_sprite(cv,L["sparks"]["hero"]["texture"],L["sparks"]["hero"]["pivot_px"],state(L["sparks"]["hero"],t))
    return cv
if __name__=="__main__":
    for t in map(float,sys.argv[1:]): frame(t).convert("RGB").save(f"/tmp/splash_{t:.2f}.png")
