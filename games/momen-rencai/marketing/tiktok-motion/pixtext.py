import json
from PIL import Image, ImageDraw, ImageFont
F="/usr/share/fonts/opentype/noto/NotoSansCJK-Black.ttc"
out={}
for key,text,size in [("title","魔门人材",28),("small","第38次轮回",14)]:
    f=ImageFont.truetype(F,size,index=2)
    w=int(size*len(text)*1.1)+4;h=size+8
    im=Image.new("L",(w,h),0);d=ImageDraw.Draw(im);d.text((2,0),text,font=f,fill=255)
    bb=im.getbbox();im=im.crop(bb)
    rows=["".join("1" if im.getpixel((x,y))>110 else "0" for x in range(im.width)) for y in range(im.height)]
    out[key]=rows
    print(key,im.size); print("\n".join(r.replace("0"," ").replace("1","#") for r in rows))
json.dump(out,open("src/pixtext.json","w"))
