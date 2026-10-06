from PIL import Image,ImageDraw
from pathlib import Path
R=Path(__file__).resolve().parents[1]
im=Image.open(R/'art/bellkeeper_generated_keyposes.png').convert('RGBA')
# Exact inspected pose cells, with a stable torso/ground anchor. No pose-dependent resizing.
poses=[((18,60,356,457),(176,443)),((363,61,716,458),(554,443)),((720,45,1024,457),(876,443)),((1034,128,1586,458),(1249,443)),((9,464,348,900),(191,875)),((355,601,773,950),(509,934)),((774,619,1085,950),(921,934)),((1093,520,1580,956),(1333,936))]
a=Image.new('RGBA',(160*8,160))
for i,(box,anchor) in enumerate(poses):
 crop=im.crop(box);s=.225;crop=crop.resize((round(crop.width*s),round(crop.height*s)),Image.Resampling.LANCZOS)
 # Palette reduction creates intentional clustered native pixels at the actual game resolution.
 alpha=crop.getchannel('A');rgb=crop.convert('RGB').quantize(colors=68,dither=Image.Dither.NONE).convert('RGB');crop=rgb.convert('RGBA');crop.putalpha(alpha.point(lambda v:255 if v>130 else 0))
 x=round(80+(box[0]-anchor[0])*s);y=round(144+(box[1]-anchor[1])*s)
 a.alpha_composite(crop,(i*160+x,y))
a.save(R/'godot/assets/bellkeeper_keyposes.png')
review=Image.new('RGB',(1280,320),'#0b202d');review.paste(a.resize((1280,160)),(0,0),a)
font=None;d=ImageDraw.Draw(review)
for i,s in enumerate(['IDLE','WALK','ANTICIPATION','CHARGE','LEAP','IMPACT','RECOVER','RING']):d.text((i*160+45,170),s,fill='#dfc58f')
review.resize((1280,320),Image.Resampling.NEAREST).save(R/'art/bellkeeper_keypose_review.png')
