extends RefCounted
class_name BreakerMotion
# Outputs committed motion; owns no save file and grants no generic invulnerability.
const WINDUP:=.12
const RECOVERY:=.18
const FALL_SPEED:=640.
const AIR_STEER:=50.
var state:="idle"
var time_left:=0.
var active_id:=0
var broken_this_activation:Array=[]
func can_begin(p:Dictionary,owned:bool,hitstop:float) -> bool:
	return owned and state=="idle" and not p.grounded and p.hurt<=0 and p.dash<=0 and p.dash_cd<=0 and p.attack<=.12 and p.heal<=0 and not p.air_dash and not p.dead and hitstop<=0
func request(input:Dictionary,p:Dictionary,owned:bool,hitstop:float) -> bool:
	if not input.get("down",false) or not input.get("dash_press",false):return false
	if not can_begin(p,owned,hitstop):return false
	state="windup";time_left=WINDUP;active_id+=1;broken_this_activation.clear();p.air_dash=true;p.dash_cd=.56;p.attack=0.
	return true
func cancel() -> void:state="idle";time_left=0.;broken_this_activation.clear()
func step(dt:float,p:Dictionary) -> void:
	if p.dead or p.hurt>0:cancel();return
	if state in ["windup","recovery"]:
		time_left=maxf(0.,time_left-dt)
		if time_left<=0:state="fall" if state=="windup" else "idle"
func velocity(axis:float) -> Vector2:
	return Vector2(clampf(axis,-1,1)*AIR_STEER,0 if state!="fall" else FALL_SPEED)
func land() -> void:
	if state in ["windup","fall"]:state="recovery";time_left=RECOVERY
func crossed_seal(before:Rect2,after:Rect2,plate:Rect2) -> bool:
	if state!="fall":return false
	var horizontal:bool=after.position.x<plate.end.x and after.end.x>plate.position.x
	return horizontal and before.end.y<=plate.position.y+.001 and after.end.y>=plate.position.y
