from PIL import Image,ImageDraw
from pathlib import Path
R=Path(__file__).resolve().parents[1];im=Image.open(R/'art/player_generated_keyposes.png').convert('RGBA')
poses=[((31,26,347,286),(218,280)),((406,24,710,286),(558,280)),((720,12,1055,287),(907,280)),((1081,25,1398,288),(1284,280)),((38,320,305,580),(184,575)),((385,300,682,580),(553,575)),((753,306,1021,580),(910,575)),((1086,399,1380,582),(1266,575)),((17,632,307,879),(213,870)),((363,644,758,880),(549,870)),((784,575,1020,880),(919,870)),((1134,581,1388,889),(1272,875)),((5,911,391,1113),(239,1101)),((396,886,675,1114),(550,1101)),((778,904,994,1111),(896,1101)),((1077,965,1402,1114),(1250,1101))]
colors=['07121b','0b1c28','102c38','173d48','214d59','306575','467e86','669b99','90b4aa','3b2829','56332d','743e30','914934','a95438','bd6340','d47b4b','e99457','f4b26c','ffd395','ffe9ba','f8f4d4','212532','34373a','55504a','6d6254','8a7960','b49b71','d0b382','405451','35423d','273531','232c35']
pa=Image.new('P',(1,1));rgb=[tuple(bytes.fromhex(c))for c in colors];pa.putpalette(sum([list(c)for c in rgb],[])+[0]*(768-len(rgb)*3))
a=Image.new('RGBA',(80*8,80*2))
for i,(box,anchor) in enumerate(poses):
 crop=im.crop(box);s=.17;crop=crop.resize((round(crop.width*s),round(crop.height*s)),Image.Resampling.LANCZOS)
 alpha=crop.getchannel('A').point(lambda v:255 if v>128 else 0)
 crop=crop.convert('RGB').quantize(palette=pa,dither=Image.Dither.NONE).convert('RGBA');crop.putalpha(alpha)
 x=round(40+(box[0]-anchor[0])*s);y=round(70+(box[1]-anchor[1])*s)
 a.alpha_composite(crop,((i%8)*80+x,(i//8)*80+y))
a.save(R/'godot/assets/player_keyposes.png')
review=Image.new('RGBA',(1280,320),'#0b202d');review.alpha_composite(a.resize((1280,320),Image.Resampling.NEAREST));review.convert('RGB').save(R/'art/player_keypose_review.png')
