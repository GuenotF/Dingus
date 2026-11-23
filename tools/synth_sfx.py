import numpy as np, wave, sys
SR=44100
rng=np.random.default_rng(7)
def t(d): return np.arange(int(SR*d))/SR
def noise(d): return rng.standard_normal(int(SR*d))
def band(x,lo,hi):
    X=np.fft.rfft(x); f=np.fft.rfftfreq(len(x),1/SR)
    m=np.ones_like(f)
    if lo: m*=1/(1+(lo/np.maximum(f,1))**4)
    if hi: m*=1/(1+(f/hi)**4)
    return np.fft.irfft(X*m,len(x))
def env(n,a=0.002,d=0.1,curve=3.0):
    x=np.arange(n)/SR; e=np.exp(-x/d*curve/3.0)
    e*=np.minimum(1,x/a) if a>0 else 1
    return e
def add(out,x,at):
    i=int(at*SR); n=min(len(x),len(out)-i)
    if n>0: out[i:i+n]+=x[:n]
def thump(freq,d,drop=0.5):
    tt=t(d); f=freq*(1-drop*tt/d)
    return np.sin(2*np.pi*np.cumsum(f)/SR)*env(len(tt),0.001,d/3)
def crack(freq,d,amp=1.0):
    n=noise(d); n=band(n,freq*0.6,freq*1.8)
    return n/np.max(np.abs(n))*env(len(n),0.0005,d/4)*amp
def finish(x,peak=0.85):
    x=x/np.max(np.abs(x))*peak
    fade=int(0.005*SR); x[-fade:]*=np.linspace(1,0,fade)
    return x
def save(name,x):
    w=wave.open(f"{sys.argv[1]}/{name}.wav","wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((np.clip(x,-1,1)*32767).astype("<i2").tobytes()); w.close()

# --- pierre ---
for v in (1,2):
    base=[90,75][v-1]
    o=np.zeros(int(SR*0.4))
    add(o,thump(base*1.6,0.28)*1.0,0)
    add(o,band(noise(0.18),200,2500)*env(int(SR*0.18),0.0005,0.05)*0.9,0)
    add(o,crack(3200+300*v,0.04,0.35),0.0)
    save(f"hit_pierre_{v}",finish(o))
for v in (1,2):
    o=np.zeros(int(SR*1.4))
    add(o,thump(55+10*v,0.7,0.6)*1.2,0)
    rumble=band(noise(1.3),40,700)*env(int(SR*1.3),0.01,0.6)
    add(o,rumble*1.4,0)
    for k in range(7):
        at=rng.uniform(0.03,0.55); f=rng.uniform(900,3500)
        add(o,crack(f,rng.uniform(0.03,0.07),rng.uniform(0.25,0.6)),at)
    dust=band(noise(1.2),2500,9000)*env(int(SR*1.2),0.05,0.35)
    add(o,dust*0.18,0.1)
    save(f"destroy_pierre_{v}",finish(o))
# --- bois ---
for v in (1,2):
    f0=[420,520][v-1]
    o=np.zeros(int(SR*0.3))
    add(o,crack(f0,0.12,1.0),0)
    add(o,thump(160+20*v,0.2,0.4)*0.8,0)
    add(o,crack(f0*2.2,0.03,0.4),0.0)
    save(f"hit_bois_{v}",finish(o))
for v in (1,2):
    o=np.zeros(int(SR*1.1))
    add(o,thump(110,0.4,0.5)*0.9,0)
    for k in range(10):
        at=rng.uniform(0.0,0.5)+0.01*k; f=rng.uniform(350,1800)
        add(o,crack(f,rng.uniform(0.04,0.14),rng.uniform(0.35,0.9)),at)
    for k in range(5):
        at=rng.uniform(0.35,0.9)
        add(o,crack(rng.uniform(500,900),0.05,0.4),at); add(o,thump(rng.uniform(90,140),0.12)*0.4,at)
    add(o,band(noise(0.9),800,6000)*env(int(SR*0.9),0.02,0.25)*0.12,0.05)
    save(f"destroy_bois_{v}",finish(o))
# --- paille ---
for v in (1,2):
    o=np.zeros(int(SR*0.3))
    r=band(noise(0.25),1200,7000)*env(int(SR*0.25),0.01,0.09)
    r*=0.6+0.4*np.sin(2*np.pi*(18+4*v)*t(0.25))**2
    add(o,r,0); add(o,thump(110,0.1,0.3)*0.3,0)
    save(f"hit_paille_{v}",finish(o,0.6))
for v in (1,2):
    o=np.zeros(int(SR*0.8))
    r=band(noise(0.75),900,8000)*env(int(SR*0.75),0.02,0.28)
    r*=0.55+0.45*np.sin(2*np.pi*(14+3*v)*t(0.75)+v)**2
    add(o,r,0); add(o,thump(90,0.2,0.4)*0.4,0.0)
    for k in range(6): add(o,crack(rng.uniform(1500,4000),0.02,0.15),rng.uniform(0.02,0.4))
    save(f"destroy_paille_{v}",finish(o,0.6))
