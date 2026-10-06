from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import math, random, json, numpy as np, wave, subprocess
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'godot/assets'; OUT.mkdir(exist_ok=True)
P={'ink':'#070e18','edge':'#132a36','dark':'#1d3b49','mid':'#2e5c68','light':'#588691','pale':'#b6d1cf','cream':'#f2e4b8','gold':'#efbb67','sun':'#ffe5a0','copper':'#a86745','rust':'#693d36','red':'#ba624d','teal':'#71c8be'}
# Draw game-native, frame-specific raster sprites from a stable pixel skeleton.
def poly(d,pts,c): d.polygon([(int(x),int(y)) for x,y in pts],fill=P.get(c,c))
def rect(d,b,c): d.rectangle(tuple(map(int,b)),fill=P.get(c,c))
def line(d,p,c,w=1): d.line([(int(x),int(y)) for x,y in p],fill=P.get(c,c),width=w)
def ellipse(d,b,c): d.ellipse(tuple(map(int,b)),fill=P.get(c,c))

def player_frame(state,f):
 im=Image.new('RGBA',(64,64)); d=ImageDraw.Draw(im); bob=1 if state=='run' and f%3==1 else 0
 cx=32; by=54+bob; tx=0; ty=0
 if state=='idle': ty=round(math.sin(f*math.pi/4))
 if state=='run': tx=round(math.sin(f*math.pi/4)*2)+1;ty=[0,-2,-3,-1,0,-2,-3,-1][f]
 if state=='fall': tx=-1;ty=2
 if state=='land': tx=2;ty=5-int(f/2)
 if state.startswith('attack'): tx=[-3,-4,2,5,3,1,0,0][f];ty=[1,2,-1,1,2,1,0,0][f]
 if state=='dash': tx=5; ty=6
 if state=='hurt': tx=-3; ty=0
 if state=='rest': by=56; ty=5
 if state=='jump': tx=2;ty=-4
 if state=='dead':
  ellipse(d,(18,45,48,55),'dark'); poly(d,[(20,46),(22,36),(36,35),(43,42),(40,53)],'copper');rect(d,(25,40,38,44),'ink');line(d,[(25,40),(38,40)],'gold'); return im
 phase=f/8*math.tau; leg=round(math.sin(phase)*5) if state=='run' else 0
 if state=='jump':leg=7;by=48
 if state=='fall':leg=-5;by=53
 if state.startswith('attack'):leg=[-2,-4,2,6,5,2,0,0][f]
 if state=='land':leg=5
 # Back scarf ribbon, with individually animated folds.
 poly(d,[(29+tx,32+ty),(20+tx,33+ty),(13-int(math.sin(f)*4),30+ty- (8 if state=='fall' else 0)),(5 if state=='run' else 8,31+ty- (10 if state=='fall' else 0)),(18,38+ty),(30+tx,35+ty)],'rust')
 line(d,[(12,33+ty),(21,35+ty),(30,33+ty)],'red',2)
 # Behind leg, boot, light edge
 poly(d,[(27,41+ty),(30,43+ty),(27-leg,by-2),(24-leg,by-2),(25,47+ty)],'edge')
 rect(d,(23-leg,by-3,29-leg,by),'copper');rect(d,(23-leg,by,30-leg,by+1),'ink')
 # Coat spreads during movement.
 poly(d,[(25+tx,31+ty),(37+tx,31+ty),(39+tx,42+ty),(34,47+ty),(22-leg*.6,45+ty),(19+tx,42+ty)],'ink')
 poly(d,[(26+tx,32+ty),(36+tx,32+ty),(36+tx,41+ty),(32,44+ty),(25,42+ty)],'dark')
 poly(d,[(27+tx,33+ty),(30+tx,34+ty),(29,42+ty),(25,41+ty)],'mid')
 line(d,[(34+tx,33+ty),(37+tx,41+ty),(33,44+ty)],'light')
 # Foreground articulated leg.
 poly(d,[(32,43+ty),(36,42+ty),(35+leg,by-3),(31+leg,by-2)],'dark')
 rect(d,(31+leg,by-3,38+leg,by),'copper');line(d,[(32+leg,by-3),(36+leg,by-3)],'gold')
 rect(d,(31+leg,by,39+leg,by+1),'ink')
 # Copper lantern helmet, not a horned/masked silhouette.
 hx=31+tx;hy=23+ty
 poly(d,[(hx-8,hy-6),(hx-5,hy-10),(hx+6,hy-10),(hx+10,hy-6),(hx+10,hy+5),(hx+6,hy+9),(hx-6,hy+8),(hx-9,hy+4)],'ink')
 poly(d,[(hx-7,hy-5),(hx-4,hy-8),(hx+5,hy-8),(hx+8,hy-5),(hx+8,hy+4),(hx+5,hy+7),(hx-5,hy+6),(hx-7,hy+3)],'copper')
 poly(d,[(hx-6,hy-5),(hx-3,hy-7),(hx+5,hy-7),(hx+7,hy-4),(hx-1,hy-3),(hx-5,hy+3)],'gold')
 rect(d,(hx-4,hy-3,hx+8,hy+2),'ink');rect(d,(hx-2,hy-2,hx+7,hy+1),'dark');rect(d,(hx+2,hy-2,hx+6,hy),'sun')
 rect(d,(hx+5,hy-1,hx+7,hy+1),'cream');rect(d,(hx-4,hy+4,hx+5,hy+5),'rust')
 rect(d,(hx-3,hy-11,hx+3,hy-9),'rust');rect(d,(hx-1,hy-12,hx+1,hy-10),'copper')
 for xx in [hx-6,hx+7]: rect(d,(xx,hy+3,xx,hy+4),'cream')
 # Scarf front and small lantern satchel.
 poly(d,[(24+tx,31+ty),(36+tx,31+ty),(36+tx,34+ty),(28+tx,36+ty),(23+tx,33+ty)],'red')
 line(d,[(26+tx,32+ty),(35+tx,32+ty)],'gold')
 rect(d,(23+tx,38+ty,26+tx,43+ty),'rust');rect(d,(24+tx,39+ty,25+tx,41+ty),'gold')
 # Helmet seam, salt deposits, vents and engraved custodian number.
 line(d,[(hx-5,hy-6),(hx+5,hy-6)],'#ffda8b')
 line(d,[(hx+7,hy+2),(hx+5,hy+5)],'#754338')
 for xx in [hx-3,hx,hx+3]:rect(d,(xx,hy+4,xx,hy+5),'#41353a')
 rect(d,(hx-6,hy-2,hx-5,hy),'#66958d');rect(d,(hx-6,hy+2,hx-5,hy+3),'#3d6c6b')
 line(d,[(28+tx,36+ty),(28,41+ty)],'#47747b');rect(d,(31+tx,38+ty,33+tx,39+ty),'#987153')
 # Frame-specific arm and blade silhouette. Blade stays at rest outside attacks.
 if state.startswith('attack'):
  angles=([-20,-45,-70,-100,-115,-130] if state=='attack_up' else ([0,30,65,90,110,130] if state=='attack_down' else [-125,-95,-30,18,40,56]))
  angle=math.radians(angles[min(f,5)]);arm=(39+tx,34+ty);hand=(arm[0]+int(math.cos(angle)*7),arm[1]+int(math.sin(angle)*7))
  line(d,[(35+tx,35+ty),hand],'ink',5);line(d,[(36+tx,34+ty),hand],'copper',3)
  tip=(hand[0]+math.cos(angle)*23,hand[1]+math.sin(angle)*23);normal=(-math.sin(angle)*3,math.cos(angle)*3)
  poly(d,[(hand[0]+normal[0],hand[1]+normal[1]),(tip[0]+normal[0]*.3,tip[1]+normal[1]*.3),(tip[0]+math.cos(angle)*4,tip[1]+math.sin(angle)*4),(hand[0]-normal[0],hand[1]-normal[1])],'pale')
  line(d,[hand,tip],'cream',1)
  line(d,[(hand[0]-normal[0]*1.5,hand[1]-normal[1]*1.5),(hand[0]+normal[0]*1.5,hand[1]+normal[1]*1.5)],'gold',2)
 elif state=='dash':
  line(d,[(39,39),(49,37)],'copper',4);line(d,[(47,37),(61,32)],'pale',2)
 else:
  arm_swing=round(math.sin(phase)*3) if state=='run' else (-4 if state=='jump' else (2 if state=='fall' else 0))
  line(d,[(37+tx,35+ty),(40+tx+arm_swing,41+ty)],'ink',5);line(d,[(37+tx,35+ty),(40+tx+arm_swing,40+ty)],'copper',3)
  line(d,[(40+tx,39+ty),(47+tx,53)],'ink',4);line(d,[(41+tx,40+ty),(48+tx,51)],'pale',2);rect(d,(38+tx,39+ty,43+tx,40+ty),'gold')
 return im
states=['idle','run','jump','fall','dash','attack','hurt','rest','dead','land','attack_up','attack_down']
atlas=Image.new('RGBA',(64*8,64*len(states)))
for row,state in enumerate(states):
 for f in range(8): atlas.alpha_composite(player_frame(state,f),(f*64,row*64))
atlas.save(OUT/'player.png')

# Readable families: low bell-crab, hovering wickmoth, long-limbed municipal warden and reed-eel.
def enemy_frame(kind,state,f):
 im=Image.new('RGBA',(64,64));d=ImageDraw.Draw(im); cx=32;by=55; bob=round(math.sin(f*math.pi/4))
 flash=state=='windup'; hi='sun' if flash else 'teal'
 if kind=='crab':
  for s in [-1,1]:
   for n in range(3):
    x=cx+s*(8+n*2);y=46+n*2
    line(d,[(x,y),(x+s*(5+n),y+2),(x+s*(8+n),54+(f+n)%2)],'ink',3)
    line(d,[(x,y),(x+s*(5+n),y+2),(x+s*(8+n),53+(f+n)%2)],'copper')
  poly(d,[(18,47),(21,37+bob),(27,33+bob),(36,33+bob),(43,40+bob),(46,49),(40,53),(23,53)],'ink')
  poly(d,[(21,46),(24,38+bob),(29,36+bob),(35,36+bob),(40,41+bob),(43,49),(25,50)],'copper')
  poly(d,[(24,39+bob),(30,35+bob),(34,36+bob),(31,46),(24,46)],'gold')
  rect(d,(20,46,44,49),'rust');line(d,[(21,46),(43,46)],'gold');ellipse(d,(29,30+bob,34,35+bob),'rust')
  rect(d,(35,42+bob,40,44+bob),hi);rect(d,(38,43+bob,42,43+bob),'cream')
  line(d,[(23,50),(20,53)],'light');line(d,[(40,50),(44,53)],'light')
 elif kind=='moth':
  flap=round(math.sin(f*math.pi/4)*12)
  for s in [-1,1]:
   poly(d,[(32,39),(32+s*7,30),(32+s*24,22+flap),(32+s*19,42),(32+s*10,46)],'ink')
   poly(d,[(32+s*3,36),(32+s*9,31),(32+s*21,26+flap),(32+s*15,40),(32+s*7,42)],'mid')
   line(d,[(32+s*4,37),(32+s*18,28+flap)],'light')
   line(d,[(32+s*7,38),(32+s*14,37)],'teal')
  ellipse(d,(27,31,36,46),'ink');rect(d,(29,33,34,44),'copper');rect(d,(30,35,34,39),hi)
  line(d,[(30,32),(25,26),(23,27)],'gold');line(d,[(34,32),(39,27),(41,28)],'gold')
  poly(d,[(30,44),(33,52),(35,44)],'rust')
 elif kind=='warden':
  leg=round(math.sin(f*math.pi/4)*4) if state=='patrol' else 0
  line(d,[(26,41),(24-leg,52)],'ink',6);line(d,[(35,41),(37+leg,52)],'ink',6)
  line(d,[(26,42),(24-leg,51)],'mid',3);line(d,[(35,42),(37+leg,51)],'light',3)
  rect(d,(21-leg,52,27-leg,55),'copper');rect(d,(34+leg,52,41+leg,55),'copper')
  poly(d,[(20,26),(39,25),(42,43),(31,48),(20,43),(17,35)],'ink')
  poly(d,[(23,28),(36,27),(38,42),(31,45),(24,40)],'dark');line(d,[(24,28),(25,40),(31,45)],'light')
  line(d,[(33,28),(34,40)],'mid');rect(d,(24,39,38,41),'copper')
  poly(d,[(23,16),(26,11),(34,10),(39,15),(37,29),(31,31),(22,27)],'ink')
  poly(d,[(25,16),(28,13),(34,13),(36,17),(35,25),(30,28),(25,25)],'mid')
  rect(d,(26,18,38,21),'ink');rect(d,(30,19,38,20),hi);poly(d,[(26,10),(29,4),(32,3),(33,13)],'copper')
  line(d,[(24,15),(27,14),(27,25)],'light');poly(d,[(20,27),(26,27),(23,37),(18,35)],'copper')
  hand=(42,36) if state!='attack' else (43,31)
  line(d,[(36,30),hand],'dark',5);line(d,[hand,(59,29 if state=='attack' else 13)],'copper',2)
  poly(d,[(57,28 if state=='attack' else 16),(63,26 if state=='attack' else 6),(60,34 if state=='attack' else 16)],'pale')
 else:
  poly(d,[(11,53),(18,43),(27,42),(29,35),(38,34),(45,38),(48,47),(43,53)],'ink')
  poly(d,[(15,50),(23,46),(30,46),(33,37),(39,37),(44,41),(44,48),(38,51)],'mid')
  line(d,[(18,48),(27,47),(34,39),(41,39)],'teal',2);rect(d,(37,41,43,43),hi)
  for i in range(5): line(d,[(19+i*5,47-i%2*4),(17+i*5,41-i%2*5)],'copper',2)
  poly(d,[(35,49),(39,49),(37,54)],'cream')
 return im
kinds=['crab','moth','warden','eel']; enemy_states=['patrol','windup','attack','recover']
atlas=Image.new('RGBA',(512,64*len(kinds)*4))
for k,kind in enumerate(kinds):
 for s,state in enumerate(enemy_states):
  for f in range(8): atlas.alpha_composite(enemy_frame(kind,state,f),(f*64,(k*4+s)*64))
atlas.save(OUT/'enemies.png')

# Boss: a heavy, asymmetrical bell on a chain-backed skeleton, with a striking empty center.
def boss_frame(state,f):
 im=Image.new('RGBA',(128,128));d=ImageDraw.Draw(im);cx=64;by=112;lift=-7 if state=='windup' else 0
 sway=round(math.sin(f*math.pi/4)*4)
 if state=='windup':lift=-8-int(f/2)
 elif state=='attack':lift=[-6,-3,4,8,5,3,2,0][f]
 elif state=='recover':lift=[7,6,5,4,2,1,0,0][f]
 # chain cape
 for n in range(6):
  x=46+n*5
  line(d,[(x,38),(x-10+int(math.sin(f+n)*3),80),(x-18,107)],'ink',4)
  for y in range(42,102,8): ellipse(d,(x-10*(y-38)/70-2,y,x-10*(y-38)/70+1,y+4),'copper')
 # spindly articulated legs
 for s in [-1,1]:
  knee=(cx+s*(23 if state in ['windup','recover'] else 17)+sway,94+sway*s+(4 if state=='recover' else 0));foot=(cx+s*27+(5 if state=='attack' and s==1 else 0),by)
  line(d,[(cx+s*13,75),knee,foot],'ink',10);line(d,[(cx+s*13,76),knee,foot],'dark',6)
  ellipse(d,(knee[0]-4,knee[1]-3,knee[0]+4,knee[1]+3),'copper');line(d,[knee,foot],'light',2)
  poly(d,[(foot[0]-8,by-4),(foot[0]+5,by-4),(foot[0]+9,by),(foot[0]-9,by+2)],'ink');line(d,[(foot[0]-7,by-3),(foot[0]+5,by-3)],'gold',2)
 # great hollow bell torso
 poly(d,[(cx-17,30+lift),(cx-20,42+lift),(cx-23,66+lift),(cx-31,75+lift),(cx-28,83+lift),(cx+30,83+lift),(cx+33,75+lift),(cx+24,64+lift),(cx+21,42+lift),(cx+15,30+lift)],'ink')
 poly(d,[(cx-15,33+lift),(cx-18,46+lift),(cx-20,66+lift),(cx-27,76+lift),(cx+29,76+lift),(cx+21,64+lift),(cx+18,43+lift),(cx+13,33+lift)],'rust')
 poly(d,[(cx-14,33+lift),(cx-17,49+lift),(cx-16,67+lift),(cx-22,74+lift),(cx-7,72+lift),(cx-5,35+lift)],'copper')
 line(d,[(cx-11,35+lift),(cx-13,54+lift),(cx-10,65+lift)],'gold',2)
 line(d,[(cx+12,35+lift),(cx+16,50+lift),(cx+16,63+lift),(cx+24,73+lift)],'mid',3)
 ellipse(d,(cx-10,44+lift,cx+12,70+lift),'ink');ellipse(d,(cx-6,48+lift,cx+7,67+lift),'edge')
 line(d,[(cx+2,45+lift),(cx+2,60+lift)],'copper',2);ellipse(d,(cx-2,59+lift,cx+5,64+lift),'sun' if state=='windup' else 'gold')
 rect(d,(cx-28,76+lift,cx+29,79+lift),'copper');line(d,[(cx-24,77+lift),(cx+23,77+lift)],'gold',2)
 # Hammered copper reflects a narrow key light; engraved bands and patina follow the bell.
 rng=random.Random(703)
 for n in range(100):
  x=rng.randrange(cx-17,cx+20);y=rng.randrange(36,73)+lift
  if abs(x-cx)<10 and 43+lift<y<70+lift:continue
  c=rng.choice(['#c49259','#8d694f','#355a58','#4c746a','#1d393e'])
  rect(d,(x,y,x+rng.randrange(1,3),y),c)
 for yy in [38,69,73]:d.arc((cx-20,yy-4+lift,cx+22,yy+4+lift),0,180,fill='#c1945b',width=1)
 for xx in range(cx-22,cx+27,7):rect(d,(xx,77+lift,xx+1,78+lift),'#f0c57e')
 d.arc((cx-11,43+lift,cx+13,71+lift),90,270,fill='#d0a96c',width=2)
 d.arc((cx-8,46+lift,cx+10,68+lift),-90,90,fill='#366665',width=1)
 # crowned hanging head
 rect(d,(cx-5,24+lift,cx+5,32+lift),'copper');ellipse(d,(cx-7,14+lift,cx+7,27+lift),'ink');ellipse(d,(cx-4,17+lift,cx+5,25+lift),'copper')
 rect(d,(cx-4,20+lift,cx+7,22+lift),'sun' if state=='windup' else 'teal');line(d,[(cx-3,14+lift),(cx-3,8+lift),(cx+3,8+lift),(cx+3,14+lift)],'gold',2)
 # arms and ceremonial counterweight hammer
 arm=(87-int(f/2),28-int(f/2)) if state=='windup' else ((109,91) if state=='attack' else ((93,78) if state=='recover' else (100,62+sway)))
 line(d,[(cx+21,43+lift),(cx+30,54+lift),arm],'ink',9);line(d,[(cx+21,43+lift),(cx+30,54+lift),arm],'copper',4)
 line(d,[(arm[0],arm[1]-20),(arm[0]-8,arm[1]+32)],'ink',5);line(d,[(arm[0],arm[1]-20),(arm[0]-8,arm[1]+32)],'gold',2)
 ax=arm[0];ay=arm[1]-23
 poly(d,[(ax-10,ay-8),(ax+10,ay-8),(ax+15,ay),(ax+10,ay+9),(ax-10,ay+9),(ax-14,ay)],'ink')
 poly(d,[(ax-8,ay-5),(ax+8,ay-5),(ax+11,ay),(ax+8,ay+6),(ax-8,ay+6)],'copper');rect(d,(ax-4,ay-4,ax+4,ay+5),'gold');line(d,[(ax-10,ay+1),(ax+11,ay+1)],'rust')
 return im
boss_states=['patrol','windup','attack','recover','phase']
a=Image.new('RGBA',(1024,len(boss_states)*128))
for s,st in enumerate(boss_states):
 for f in range(8): a.alpha_composite(boss_frame(st,f),(f*128,s*128))
a.save(OUT/'bellkeeper.png')
# Tiles: 4 variants per material, upper lip, fractured internal brick lines and lichen.
a=Image.new('RGBA',(128,128));d=ImageDraw.Draw(a);rng=random.Random(844)
for row,material in enumerate(['stone','wood','metal','deep']):
 for col in range(4):
  x,y=col*32,row*32
  base=['#142e3b','#3e332e','#263b45','#102732'][row];rect(d,(x,y,x+31,y+31),base)
  if row in [0,3]:
   for yy in [8,21]:
    line(d,[(x,y+yy),(x+31,y+yy)],'#0b1c27');line(d,[(x,y+yy+1),(x+31,y+yy+1)],'#1b3a48')
   for xx,yy in [(8,1),(22,9),(5,22)]:line(d,[(x+xx,y+yy),(x+xx,y+yy+9)],'#0b1c27')
   for i in range(18):
    xx=rng.randrange(32);yy=rng.randrange(4,32);rect(d,(x+xx,y+yy,x+xx+rng.randrange(1,4),y+yy),rng.choice(['#224350','#234754','#152d3c']))
  elif row==1:
   for yy in [8,17,27]:line(d,[(x,y+yy),(x+31,y+yy)],'#231e21');line(d,[(x+2,y+yy+2),(x+27,y+yy+2)],'#594736')
   for xx in [3,27]:rect(d,(x+xx,y+4,x+xx+1,y+5),'gold')
  else:
   line(d,[(x,y+27),(x+31,y+27)],'#0c202d');line(d,[(x+4,y+6),(x+27,y+6)],'#355362');line(d,[(x+5,y+5),(x+25,y+25)],'#182e3c',2)
   for xx in [3,27]:rect(d,(x+xx,y+9,x+xx+1,y+10),'copper')
  
  if row<3:line(d,[(x,y),(x+31,y)],'#80a6a6' if row!=1 else '#ae9061');line(d,[(x,y+1),(x+31,y+1)],'#355d67' if row!=1 else '#65573d')
  if col%2==0 and row<3:
   for i in range(6):xx=rng.randrange(32);line(d,[(x+xx,y+2),(x+xx-2,y+5)],'#53756c')
a.save(OUT/'tiles.png')
# Props atlas: fixed 128px cells; origin in manifest always bottom center.
props={};a=Image.new('RGBA',(1024,512))
def prop(name,fn):
 idx=len(props);im=Image.new('RGBA',(128,128));d=ImageDraw.Draw(im);fn(d);a.alpha_composite(im,((idx%8)*128,(idx//8)*128));props[name]=[idx%8*128,idx//8*128,128,128]
def lamp(d):
 line(d,[(64,122),(64,53)],'ink',7);line(d,[(64,118),(64,53)],'copper',3)
 poly(d,[(54,48),(57,34),(70,34),(75,48)],'ink');line(d,[(54,48),(74,48)],'gold',2)
 rect(d,(56,48,72,69),'ink');rect(d,(59,50,69,64),'gold');rect(d,(62,51,66,62),'sun')
 for x in [57,64,71]:line(d,[(x,48),(x,67)],'copper',2)
 line(d,[(56,68),(72,68)],'gold',2);ellipse(d,(56,119,72,126),'rust');line(d,[(54,126),(75,126)],'light',2)
 line(d,[(64,34),(64,27)],'copper',2);ellipse(d,(61,28,66,33),'gold')
def beacon(d):
 poly(d,[(50,122),(56,78),(72,78),(79,122)],'ink');poly(d,[(55,120),(60,80),(68,80),(74,120)],'dark')
 line(d,[(58,116),(62,84)],'light',2);rect(d,(43,117,84,125),'dark');line(d,[(45,118),(82,118)],'copper',2)
 poly(d,[(43,69),(48,82),(79,82),(85,69)],'ink');poly(d,[(46,70),(51,78),(76,78),(82,70)],'copper');line(d,[(45,69),(83,69)],'gold',2)
 for x in [49,64,78]: line(d,[(x,69),(x,60)],'copper',2)
def door(d):
 poly(d,[(31,126),(31,52),(37,34),(50,24),(64,19),(79,25),(92,38),(97,56),(97,126)],'ink')
 line(d,[(33,126),(33,52),(40,36),(53,27),(64,23),(77,29),(89,40),(94,56),(94,126)],'mid',5)
 line(d,[(39,125),(39,54),(44,42),(53,34),(64,29),(76,35),(86,47),(89,57),(89,125)],'copper',2)
 rect(d,(42,61,86,125),'ink')
 for x in [49,63,78]:line(d,[(x,54),(x,124)],'dark',2)
 ellipse(d,(58,37,69,48),'rust');ellipse(d,(61,40,66,45),'gold');line(d,[(28,125),(99,125)],'light',2)
def sign(d):
 rect(d,(61,94,65,125),'rust');poly(d,[(43,79),(83,78),(88,85),(81,98),(43,97)],'ink');rect(d,(46,81,82,94),'dark');line(d,[(47,81),(81,81)],'copper')
 for y in [85,89]:line(d,[(51,y),(75,y)],'light');rect(d,(49,93,56,93),'gold')
def bookcase(d):
 rect(d,(22,8,103,127),'ink');rect(d,(25,10,99,124),'rust')
 for row in range(5):
  yy=16+row*21;rect(d,(29,yy,96,yy+16),'edge')
  for i in range(9):
   xx=30+i*7;hh=random.Random(i+row*20).randrange(10,17);c=['#415853','#6b5b49','#394951','#756346'][ (i+row)%4];rect(d,(xx,yy+16-hh,xx+4,yy+16),c);rect(d,(xx+1,yy+17-hh,xx+2,yy+18-hh),'gold')
  line(d,[(26,yy+18),(99,yy+18)],'copper',2)
 line(d,[(23,8),(102,8)],'light',2)
def tree(d):
 poly(d,[(49,127),(61,94),(58,63),(47,42),(51,35),(64,57),(69,34),(74,26),(74,60),(90,45),(93,49),(78,72),(75,108),(85,127)],'ink')
 line(d,[(63,124),(68,86),(64,57),(53,39)],'rust',4);line(d,[(69,86),(73,48),(84,36)],'copper',2)
 r=random.Random(35)
 for i in range(70):
  x=r.randrange(18,111);y=r.randrange(12,72)
  if ((x-66)/48)**2+((y-37)/31)**2<1:
   col=r.choice(['#263f3a','#34564d','#51684e','#837348','#a78b4e']);rect(d,(x,y,x+r.randrange(2,8),y+r.randrange(1,4)),col)
 for x,y in [(38,53),(94,55),(74,65),(51,74)]:line(d,[(x,y-10),(x,y)],'copper');poly(d,[(x-2,y),(x+2,y),(x+4,y+6),(x-4,y+6)],'gold')
def npc(d):
 poly(d,[(50,126),(56,95),(51,83),(61,75),(70,79),(74,93),(80,124)],'ink');poly(d,[(54,123),(61,93),(71,92),(75,123)],'rust')
 poly(d,[(51,85),(53,75),(63,69),(73,75),(77,86),(67,93),(55,90)],'dark');line(d,[(54,79),(64,73),(73,79)],'light',2)
 rect(d,(58,81,71,86),'ink');rect(d,(64,83,70,84),'gold');line(d,[(72,103),(90,98)],'copper',3)
 line(d,[(89,95),(89,121)],'gold');rect(d,(85,108,93,118),'copper');rect(d,(87,110,91,115),'sun');line(d,[(59,104),(57,119)],'copper')
 line(d,[(59,96),(63,116),(70,122)],'#a1795c');line(d,[(67,95),(69,110),(74,121)],'#4e3836')
 for y in [99,105,111]:line(d,[(57,y),(71,y+2)],'#84624c')
 line(d,[(54,79),(57,75),(64,71)],'#8aa9a5');rect(d,(68,74,70,76),'gold')
 line(d,[(55,90),(48,103),(52,111)],'copper',2);ellipse(d,(43,109,57,123),'rust');line(d,[(43,112),(56,113)],'gold');line(d,[(46,109),(46,105),(54,105),(55,110)],'mid')
def roots(d):
 for i in range(6):
  x=12+i*19;line(d,[(x,127),(x+5,100-i%3*15),(x-2,89-i%3*16)],'ink',4);line(d,[(x,124),(x+4,103-i%3*15)],'mid')
  line(d,[(x+4,107),(x+12,101)],'copper');line(d,[(x+3,106),(x-6,99)],'dark',2)
def arch(d):
 for x in [6,103]:rect(d,(x,37,x+17,127),'edge');line(d,[(x,40),(x,125)],'mid',2);rect(d,(x-3,121,x+20,127),'dark')
 d.arc((6,0,120,105),180,360,fill=P['edge'],width=18);d.arc((7,1,119,104),180,360,fill=P['mid'],width=2)
 for a0 in range(195,350,20):
  a1=math.radians(a0);line(d,[(63+44*math.cos(a1),52+44*math.sin(a1)),(63+55*math.cos(a1),52+55*math.sin(a1))],'ink',2)
def bell(d):
 line(d,[(64,0),(64,20)],'copper',3);ellipse(d,(54,14,75,33),'rust')
 poly(d,[(45,28),(39,38),(37,68),(27,80),(26,88),(103,88),(102,80),(91,68),(87,38),(80,29)],'ink')
 poly(d,[(47,31),(43,40),(41,69),(31,81),(99,81),(88,67),(83,38),(77,32)],'rust');poly(d,[(47,33),(44,60),(46,71),(57,72),(61,32)],'copper')
 line(d,[(48,36),(46,56)],'gold',2);line(d,[(79,36),(83,60),(87,73)],'mid',3);line(d,[(31,83),(99,83)],'gold',2)
 # Curved bronze gradients, corrosion clusters, relief lines and rivets.
 for xx in range(42,88):
  if xx<58: c=['#794d35','#8b5b3e','#9d6a48','#ba8051'][min(3,(xx-42)//4)]
  elif xx<72:c=['#855b43','#714b3d','#593e37'][(xx-58)//5]
  else:c=['#365455','#2f494c','#253d44'][(xx-72)//6]
  yy=39+abs(xx-64)//4
  line(d,[(xx,yy),(xx,67)],c)
 rng=random.Random(141)
 for i in range(95):
  x=rng.randrange(43,88);y=rng.randrange(40,70)
  if ((x-75)/17)**2+((y-57)/24)**2<1:rect(d,(x,y,x+rng.randrange(1,3),y+rng.randrange(1,3)),rng.choice(['#426b68','#325957','#557a6d','#29484a']))
 for yy in [39,68,72]:
  d.arc((35,yy-5,95,yy+6),0,180,fill='#b88a58',width=1)
 for x in range(37,96,9):rect(d,(x,78,x+1,79),'#dfb36b')
 line(d,[(69,34),(64,45),(70,55),(65,63),(67,70)],'ink',2)
 line(d,[(64,83),(64,99)],'copper',3);ellipse(d,(58,96,71,107),'gold');line(d,[(70,35),(64,47),(70,56),(64,65)],'ink',2)
def wheel(d):
 ellipse(d,(22,37,104,119),'ink');ellipse(d,(26,41,100,115),'copper');ellipse(d,(32,47,94,109),'ink')
 for n in range(8):
  a0=n*math.pi/4;line(d,[(63,78),(63+35*math.cos(a0),78+35*math.sin(a0))],'rust',5);line(d,[(63,78),(63+34*math.cos(a0),78+34*math.sin(a0))],'copper',2)
 ellipse(d,(55,70,71,86),'gold');ellipse(d,(59,74,67,82),'rust')
for name,fn in [('lamp',lamp),('beacon',beacon),('door',door),('sign',sign),('bookcase',bookcase),('tree',tree),('npc',npc),('roots',roots),('arch',arch),('bell',bell),('wheel',wheel)]:prop(name,fn)
a.save(OUT/'props.png');(OUT/'props.json').write_text(json.dumps(props))
# Normalize the generated city for the game's native 640x360 presentation.
city=Image.open(ROOT/'art/emberwake_city_original.png').convert('RGB');city=city.resize((640,360),Image.Resampling.LANCZOS);city.save(OUT/'city.png',optimize=True)
# Original ambient score: a 40-second A-Dorian bell/cello-like drone loop, no sampled music.
if not (OUT/'gatewater.ogg').exists():
 sr=22050;duration=40;N=sr*duration;t=np.arange(N)/sr;left=np.zeros(N);right=np.zeros(N)
 def voice(start,dur,freq,amp,pan=.0,bell=False):
  n=int(dur*sr);tt=np.arange(n)/sr
  if bell: env=np.exp(-tt*1.8)*np.minimum(tt/.009,1);tone=np.sin(2*np.pi*freq*tt)+.30*np.sin(2*np.pi*freq*2.76*tt)*np.exp(-tt*2)+.14*np.sin(2*np.pi*freq*5.4*tt)*np.exp(-tt*3)
  else: env=np.minimum(tt/2.2,1)*np.minimum((dur-tt)/3,1);tone=.6*np.sin(2*np.pi*freq*tt)+.2*np.sin(2*np.pi*(freq*1.003)*tt)+.08*np.sin(2*np.pi*freq*2*tt)
  sig=tone*env*amp;i=int(start*sr)
  for off,gain in [(0,1),(int(.31*sr),.17),(int(.67*sr),.09)]:
   for dest,pg in [(left,1-pan*.6),(right,1+pan*.6)]:
    idx=(np.arange(n)+i+off)%N;np.add.at(dest,idx,sig*gain*pg)
 chords=[(110,164.81,246.94),(98,146.83,220),(130.81,196,293.66),(110,164.81,246.94)]
 for k,c in enumerate(chords):
  for j,freq in enumerate(c):voice(k*10,13,freq,.07 if j==0 else .042,(-.4+j*.4))
 notes=[(0,440),(3,659.25),(6.5,587.33),(10.5,493.88),(15,440),(19,329.63),(22.5,392),(25.5,587.33),(29,659.25),(33,493.88),(36.5,440)]
 for i,(start,freq) in enumerate(notes):voice(start,3.5,freq,.10,(-.55 if i%2 else .55),True)
 # Sparse original raindrop texture; low-level, never masking telegraphs.
 rng=np.random.default_rng(26);noise=rng.normal(0,1,N);noise=np.convolve(noise,np.ones(12)/12,mode='same')*.006
 left+=noise;right+=np.roll(noise,173)
 audio=np.stack([left,right],axis=-1);audio=np.tanh(audio*1.2)*.74
 with wave.open(str(OUT/'gatewater.wav'),'w') as w:w.setnchannels(2);w.setsampwidth(2);w.setframerate(sr);w.writeframes((audio*32767).astype('<i2').tobytes())
 subprocess.run(['ffmpeg','-y','-loglevel','error','-i',str(OUT/'gatewater.wav'),'-c:a','libvorbis','-q:a','3',str(OUT/'gatewater.ogg')],check=True);(OUT/'gatewater.wav').unlink()
# Sprite contact sheet for pixel-level visual review.
sheet=Image.new('RGB',(1024,780),'#091622');sheet.paste(atlas.resize((1024,1152),Image.Resampling.NEAREST).crop((0,0,1024,600)),(0,0),atlas.resize((1024,1152),Image.Resampling.NEAREST).crop((0,0,1024,600)))
player=Image.open(OUT/'player.png');sheet.paste(player.resize((1024,1152),Image.Resampling.NEAREST).crop((0,0,1024,128)),(0,640),player.resize((1024,1152),Image.Resampling.NEAREST).crop((0,0,1024,128)))
sheet.save(ROOT/'art/sprite_review.png')
print('ASSETS',[(p.name,p.stat().st_size) for p in OUT.iterdir()])
