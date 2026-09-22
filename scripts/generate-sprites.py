"""Deterministic auxiliary ink-burst atlas for engine porting, not a rendered 3D flipbook."""
import math,struct,zlib,json,pathlib
size=128; cols=4; frames=16; W=H=size*cols
raw=bytearray()
for y in range(H):
 raw.append(0)
 for x in range(W):
  frame=(y//size)*cols+x//size;t=frame/(frames-1);px=((x%size)+.5)/size*2-1;py=((y%size)+.5)/size*2-1
  r=math.hypot(px,py);a=math.atan2(py,px);radius=.12+.72*t
  noise=.5+.24*math.sin(a*13+r*27)+.15*math.sin(a*29-r*41)
  ring=math.exp(-((r-radius)/(.07+.09*t))**2)
  fade=math.sin(math.pi*t)**.7
  alpha=max(0,min(1,ring*fade*(.35+.65*noise)))
  raw.extend((123,203,176,round(alpha*255)))
def chunk(k,v):return struct.pack('>I',len(v))+k+v+struct.pack('>I',zlib.crc32(k+v)&0xffffffff)
p=pathlib.Path('public/assets/qinglan/v2')
p.joinpath('ink-burst-atlas.png').write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',W,H,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b''))
p.joinpath('sprite-manifest.json').write_text(json.dumps({'image':'ink-burst-atlas.png','purpose':'Auxiliary 2D impact texture; not a bake of the 3D effect','width':W,'height':H,'alpha':'straight','color_space':'sRGB','order':'row-major top-left','fps':20,'loop':False,'frames':[{'index':i,'x':i%cols*size,'y':i//cols*size,'w':size,'h':size,'pivot':[.5,.5]} for i in range(frames)]},ensure_ascii=False,indent=2)+'\n')
