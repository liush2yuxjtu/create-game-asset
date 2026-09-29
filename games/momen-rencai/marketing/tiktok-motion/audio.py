# Original synthesized score, 120 BPM, synced to scene cuts. No samples, no third-party audio.
import numpy as np, wave, sys
V2 = 'v2' in sys.argv
SR=44100; DUR=21.5 if 'v2' in sys.argv else 21.0; N=int(SR*DUR); fr=lambda f:int(f/30*SR)
L=np.zeros(N); R=np.zeros(N); rng=np.random.default_rng(7)
def add(sig,at,pan=0.0,g=1.0):
    s=fr(at) if isinstance(at,int) else int(at*SR); e=min(N,s+len(sig)); sig=sig[:e-s]*g
    L[s:e]+=sig*(1-pan)/1; R[s:e]+=sig*(1+pan)/1
t=lambda d:np.arange(int(d*SR))/SR
def kick(): x=t(.45); f=50+120*np.exp(-x*30); return np.sin(2*np.pi*np.cumsum(f)/SR)*np.exp(-x*7)
def snare(): x=t(.25); return (rng.standard_normal(len(x))*.7+np.sin(2*np.pi*190*x)*.5)*np.exp(-x*18)
def hat(): x=t(.06); return rng.standard_normal(len(x))*np.exp(-x*80)*.35
def impact(): x=t(1.6); boom=np.sin(2*np.pi*(38+60*np.exp(-x*6))*x)*np.exp(-x*2.2); n=rng.standard_normal(len(x))*np.exp(-x*9)*.6; return boom+n
def tick(p=1800): x=t(.03); return np.sin(2*np.pi*p*x)*np.exp(-x*150)*.5
def blip(p): x=t(.18); return np.sign(np.sin(2*np.pi*p*x))*np.exp(-x*20)*.18
def riser(d): x=t(d); n=rng.standard_normal(len(x)); env=(x/d)**2; return n*env*.35+np.sin(2*np.pi*(200+1400*(x/d)**2)*x)*env*.2
CUTS=[0,60,120,225,330,450,525,570,645] if V2 else [0,60,120,195,345,480,555,630]
LENS=(225,7) if V2 else (195,10); END=CUTS[-1]; TITLE=CUTS[-2]
# drone: D minor-ish, dark
x=np.arange(N)/SR
drone=(np.sin(2*np.pi*73.4*x)+.5*np.sin(2*np.pi*110*x)+.3*np.sin(2*np.pi*146.8*x*(1+.002*np.sin(x*.7))))*(.5+.5*np.sin(x*1.1))*.12
L+=drone; R+=drone
for b in range(END//15):
    f=b*15
    if f<60:
        if b in (0,): add(kick(),f,g=1.0)
        continue
    if TITLE-3<=f<TITLE: continue
    add(kick(),f,g=.9)
    if f>=120 and b%2==1: add(snare(),f,g=.55)
    add(hat(),f+7,pan=.3);
    if f>=195: add(hat(),f+3,pan=-.3,g=.6); add(hat(),f+11,pan=.3,g=.6)
for c in sorted(set(CUTS[:-1]+[72])): add(impact(),c,g=.9 if c in (0,60,72,TITLE) else .5)
add(impact(),END-6,g=1.0)  # loop slam
for i in range(26): add(tick(1400+i*40),20+i,pan=(-1)**i*.4)  # counter roll
add(tick(900),46); add(tick(900),50)
for k in range(LENS[1]): add(blip(440*(2**((k%5)/12*3))),LENS[0]+k*15,pan=(-1)**k*.5)  # lens hops
add(blip(880),LENS[0]+(LENS[1]-1)*15,g=2)
add(riser(1.0),TITLE-30)  # before title
for i in range(7): add(tick(700+i*120),CUTS[4 if not V2 else 2]+i*2,pan=.5)
mx=np.max(np.abs(np.stack([L,R]))); L/=mx/0.89; R/=mx/0.89
st=np.stack([L,R],1); st=np.tanh(st*1.2)/np.tanh(1.2)
with wave.open('out/score-v2.wav' if V2 else 'out/score.wav','wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((st*32767).astype('<i2').tobytes())
print('ok')
