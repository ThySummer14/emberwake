from pathlib import Path
import re
p=Path(__file__).resolve().parents[1];s=(p/'scripts/main.gd').read_text()
for name in ['rect','texture_rect_region','texture_rect','line','arc','circle','colored_polygon','string']:
 s=re.sub(r'\bdraw_'+name+r'\(', 'capture_'+name+'(',s)
s+='''
var recorded: Array=[]
func vec(v: Vector2) -> Array: return [v.x,v.y]
func box(r: Rect2) -> Array: return [r.position.x,r.position.y,r.size.x,r.size.y]
func col(c: Color) -> Array: return [c.r,c.g,c.b,c.a]
func capture_rect(r: Rect2,c: Color,filled: bool=true,width: float=-1,_aa: bool=false) -> void:
 recorded.append({"op":"rect","rect":box(r),"color":col(c),"fill":filled,"width":width})
func capture_texture_rect(t: Texture2D,r: Rect2,_tile: bool=false,c: Color=Color.WHITE,_transpose: bool=false) -> void:
 recorded.append({"op":"texture","rect":box(r),"color":col(c),"texture":t.get_meta("source_path",t.resource_path)})
func capture_texture_rect_region(t: Texture2D,r: Rect2,src: Rect2,c: Color=Color.WHITE,_transpose: bool=false,_clip: bool=true) -> void:
 recorded.append({"op":"texture","rect":box(r),"source":box(src),"color":col(c),"texture":t.get_meta("source_path",t.resource_path)})
func capture_line(a: Vector2,b: Vector2,c: Color,width: float=-1,_aa: bool=false) -> void:
 recorded.append({"op":"line","a":vec(a),"b":vec(b),"color":col(c),"width":width})
func capture_arc(center: Vector2,radius: float,start: float,end: float,count: int,c: Color,width: float=-1,_aa: bool=false) -> void:
 recorded.append({"op":"arc","center":vec(center),"radius":radius,"start":start,"end":end,"count":count,"color":col(c),"width":width})
func capture_circle(center: Vector2,radius: float,c: Color,_filled: bool=true,_width: float=-1,_aa: bool=false) -> void:
 recorded.append({"op":"circle","center":vec(center),"radius":radius,"color":col(c)})
func capture_colored_polygon(points: PackedVector2Array,c: Color,_uvs: PackedVector2Array=PackedVector2Array(),_texture: Texture2D=null) -> void:
 var pts:Array=[]
 for point in points: pts.append(vec(point))
 recorded.append({"op":"polygon","points":pts,"color":col(c)})
func capture_string(f: Font,pos: Vector2,text: String,align: HorizontalAlignment=HORIZONTAL_ALIGNMENT_LEFT,width: float=-1,size: int=16,c: Color=Color.WHITE,_flags: int=3,_direction: TextServer.Direction=0,_orientation: TextServer.Orientation=0) -> void:
 recorded.append({"op":"text","pos":vec(pos),"text":text,"align":align,"width":width,"size":size,"color":col(c),"font":f.get_meta("source_path",f.resource_path)})
'''
s=re.sub(r'^ ', '\t', s, flags=re.M)
(p/'tests/main_capture.gd').write_text(s)
