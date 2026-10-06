extends SceneTree
const Core=preload("res://scripts/ledger_core.gd")
const Main=preload("res://scripts/main.gd")
var passed:=0
var failed:=0
func check(ok:bool,label:String) -> void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;print("FAIL ",label)
func tick(c:RefCounted,n:int,input:Dictionary={}) -> void:
	for i in range(n):c.step(1./60,input);c.events.clear();c.particles.clear()
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var c=Core.new();c.enter_room("rf_workshop",Vector2(800,286));tick(c,80)
	var e:Dictionary=c.enemies[0]
	e.state="windup";e.t=.25;e.face=-1;e.vel=Vector2.ZERO;c.player.pos=Vector2(e.pos.x+80,286);c.player.invuln=1
	tick(c,15);check(e.state=="windup" and e.face==-1,"carrier locks facing before the remaining warning")
	tick(c,10);check(e.state=="attack","carrier commits only after the complete windup")
	tick(c,13);check(e.state=="recover","low sweep has a bounded active duration")
	var before:int=c.hp;c.player.pos=e.pos+Vector2(-25,-10);c.player.invuln=0;tick(c,15)
	check(c.hp==before,"extended scoop is harmless during recovery outside the body")
	for face in [-1,1]:
		c=Core.new();c.enter_room("rf_workshop",Vector2(800,286));e=c.enemies[0];e.state="attack";e.t=0.;e.face=face;e.vel=Vector2.ZERO;c.player.invuln=0
		c.player.pos=e.pos+Vector2(39 if face>0 else -22,0);tick(c,1);check(c.hp==4,"active low sweep connects in facing direction "+str(face))
		c.player.invuln=0;c.player.pos=e.pos+Vector2(-23 if face>0 else 40,0);before=c.hp;tick(c,1);check(c.hp==before,"sweep has no hidden opposite-side hit "+str(face))
	for delay in [9,15,21]:
		c=Core.new();c.enter_room("rf_workshop",Vector2(606,576));c.enemies.clear();var observations:Array=[];var saw_steam:=false;var committed:=false
		for n in range(600):
			var cell=c.pressure_cells[0];observations.append(2 if cell.active() else (1 if cell.warning_shutters()>0 else 0))
			var cue:int=observations[maxi(0,observations.size()-1-delay)]
			if cue==2:saw_steam=true
			if saw_steam and cue==0:committed=true
			c.step(1./60,{"left":committed});c.events.clear();c.particles.clear()
			if c.player.pos.x<440:break
		check(c.player.pos.x<440 and c.hp==5,"visible steam/clear cue crossing survives "+str(delay*1000/60)+"ms reaction delay")
	c=Core.new();c.flags.rf_breaker=true;c.flags.rf_workshop_seal=true;c.flags.rf_workshop_hoist=true;c.enter_room("rf_workshop",Vector2(606,576));c.checkpoint={"room":"rf_workshop","pos":Vector2(103,286)}
	c.pressure_cells[0].phase=2;c.pressure_cells[0].elapsed=.3;c.hp=1;c.player.invuln=0;c.damage_player(1,Vector2.ZERO,true,"pressure");tick(c,90)
	check(not c.player.dead and c.hp==5 and c.player.pos.y<310,"pressure death returns to the clear upper checkpoint")
	check(c.pressure_cells[0].state()=="fill" and c.pressure_cells[0].elapsed<.3,"checkpoint retry restarts a complete safe pressure cycle")
	check(c.room.platforms.size()==3 and c.flags.rf_breaker,"retry retains destroyed seal and acquired ability")
	var game=Main.new();root.add_child(game);game.set_process(false)
	var box:=Rect2(630,32,326,590);var anchor:=Vector2(804,610);var at:=Vector2(300,200);var s:=.105
	for face in [-1,1]:
		var rect:Rect2=game.sheet_pose_rect(box,anchor,s,at,face)
		var anchor_offset:Vector2=Vector2((anchor.x-box.position.x if face>0 else box.end.x-anchor.x)*s,(anchor.y-box.position.y)*s)
		check((rect.position+anchor_offset).distance_to(at)<.001,"cropped pose preserves its physical anchor facing "+str(face))
	game.queue_free()
	print("ROOT_FAIRNESS_RESULT ",passed," passed; ",failed," failed");quit(1 if failed else 0)
