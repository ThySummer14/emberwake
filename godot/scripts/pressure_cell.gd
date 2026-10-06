extends RefCounted
class_name PressureCell
# A local, explicitly signaled cycle. Route state belongs to persistent flags;
# this transient hazard always restarts safely on entry.
const DURATIONS:=[1.10,.90,.65,1.35]
const STATES:=["fill","warning","discharge","rest"]
var lane:Rect2
var phase:=0
var elapsed:=0.0
var enabled:=true
var cycles:=0
func _init(area:Rect2=Rect2(360,354,100,38)) -> void:lane=area
func reset_safe() -> void:
	phase=0;elapsed=0.;cycles=0
func state() -> String:return STATES[phase] if enabled else "vented"
func warning_shutters() -> int:
	if phase!=1 or not enabled:return 0
	return clampi(1+int(elapsed/(DURATIONS[1]/3.)),1,3)
func active() -> bool:return enabled and phase==2
func step(dt:float,paused:bool=false) -> void:
	if paused or not enabled:return
	elapsed+=maxf(dt,0.)
	while elapsed+0.000001>=DURATIONS[phase]:
		elapsed=maxf(0.,elapsed-DURATIONS[phase]);phase=(phase+1)%4
		if phase==0:cycles+=1
func hurts(body:Rect2) -> bool:return active() and lane.intersects(body)
