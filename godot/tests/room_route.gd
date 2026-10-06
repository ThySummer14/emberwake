extends SceneTree
const Core=preload("res://scripts/ledger_core.gd")
var passed:=0
var failed:=0
var trace:Array=[]
func check(ok:bool,label:String) -> void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;print("FAIL ",label)
func step(c:RefCounted,input:Dictionary={}) -> void:
	trace.append(input.duplicate());c.step(1./60,input);c.events.clear();c.particles.clear()
func tick(c:RefCounted,n:int,input:Dictionary={}) -> void:
	for i in range(n):step(c,input)
func walk(c:RefCounted,x:float,limit:int=600,watch_pressure:bool=false) -> bool:
	for i in range(limit):
		if absf(c.player.pos.x-x)<4:return true
		var input:Dictionary={"right":c.player.pos.x<x,"left":c.player.pos.x>x}
		if watch_pressure and c.room_id=="rf_workshop" and c.player.pos.y>500 and c.player.pos.x<630 and c.player.pos.x>=590:
			var cell=c.pressure_cells[0]
			if cell.state()!="rest" or cell.elapsed>.25:input={}
		step(c,input)
	return false
func _initialize() -> void:
	var c=Core.new();c.flags.double_jump=true;c.flags.boss_defeated=true;c.flags.orchard_beacon=true;c.flags.archive_beacon=true;c.flags.gallery_beacon=true
	c.enter_room("observatory",Vector2(854,368));tick(c,3);step(c,{"interact_press":true})
	check(c.room_id=="rf_workshop","real Observatory door enters the new connected room")
	tick(c,3);check(c.hp==5 and c.player.grounded,"new room entry settles on clear upper bridge")
	check(walk(c,103),"entry reaches the workshop lamp");step(c,{"interact_press":true})
	check(c.checkpoint.room=="rf_workshop","new lamp stores a valid local retry position")
	check(walk(c,383),"normal movement reaches the collar");step(c,{"interact_press":true})
	check(c.flags.get("rf_breaker",false),"collar acquisition is persistent")
	check(walk(c,677),"ordinary bridge traversal reaches the ceramic seam")
	step(c,{"jump_press":true});tick(c,8);step(c,{"down":true,"dash_press":true});tick(c,85)
	check(c.flags.get("rf_workshop_seal",false) and c.player.grounded and c.player.pos.y>550,"normal jump/down-dash breaks the seal and lands below")
	check(c.hp==5,"breaker's landing zone is outside the pressure lane")
	var same_enemy:Dictionary=c.enemies[0];same_enemy.hp=2
	check(walk(c,138,720,true),"visible pressure rest permits a complete safe return crossing")
	check(c.hp==5,"cue-based crossing needs neither damage boost nor assist")
	step(c,{"interact_press":true});check(c.flags.get("rf_workshop_hoist",false),"reachable lower control unlocks the paired lift gates")
	check(walk(c,223),"return control leads to the visible lift gate");step(c,{"interact_press":true});tick(c,3)
	check(c.room_id=="rf_workshop" and c.player.pos.y<310 and c.player.grounded,"lift returns to the upper bridge in the same room")
	check(c.enemies[0]==same_enemy and c.enemies[0].hp==2,"in-room lift does not respawn or heal the enemy")
	check(walk(c,35),"upper return reaches the Observatory link");step(c,{"interact_press":true})
	check(c.room_id=="observatory" and c.hp==5,"complete ability/descent/pressure/lift loop returns to existing world")
	var saved:Dictionary=JSON.parse_string(JSON.stringify(c.serialize()));var restored=Core.new()
	check(restored.restore(saved) and restored.flags.get("rf_workshop_seal",false) and restored.flags.get("rf_workshop_hoist",false) and restored.flags.get("rf_breaker",false),"reload keeps ability, destroyed ceramic and return route")
	var tf:=FileAccess.open("res://tests/route_input_trace.json",FileAccess.WRITE);tf.store_string(JSON.stringify({"start_room":"observatory","start_x":854,"start_y":368,"input_frames":trace,"expected_room":c.room_id,"expected_hp":c.hp}));tf.close()
	var f:=FileAccess.open("res://tests/route_result.json",FileAccess.WRITE);f.store_string(JSON.stringify({"passed":passed,"failed":failed,"frames":trace.size(),"hp":c.hp,"scope":"Ordinary-input deterministic route, pressure rest observation; no graphical playtest"},"\t"));f.close()
	print("ROOT_ROOM_ROUTE ",passed," passed; ",failed," failed; frames=",trace.size());quit(1 if failed else 0)
