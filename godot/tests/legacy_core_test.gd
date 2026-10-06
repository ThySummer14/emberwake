extends SceneTree
const Core=preload("res://scripts/ledger_core.gd")
var passed:=0
var failed:=0
var report: Array=[]
func check(condition: bool,name: String) -> void:
	if condition: passed+=1;print("PASS ",name)
	else: failed+=1;print("FAIL ",name)
	report.append({"test":name,"passed":condition})
func tick(c: RefCounted,n: int,input: Dictionary={}) -> void:
	for i in range(n):
		c.step(1.0/60.0,input)
		c.events.clear()
func clean(room: String="gate",at: Vector2=Vector2(100,368)) -> RefCounted:
	var c=Core.new()
	c.enter_room(room,at)
	c.enemies.clear()
	c.events.clear()
	return c
func _initialize() -> void:
	var c=clean()
	tick(c,5)
	check(c.player.grounded,"player starts and lands on floor")
	var start: float=c.player.pos.x
	tick(c,45,{"right":true})
	check(c.player.pos.x>start+100 and c.player.pos.x<start+135,"ground acceleration and maximum speed")
	c=clean();tick(c,2)
	c.step(1.0/60.0,{"jump_press":true})
	var high: float=c.player.pos.y
	for i in range(60): c.step(1.0/60.0,{});high=minf(high,c.player.pos.y)
	check(high<290 and high>280,"full jump reaches designed 82-pixel arc")
	check(c.player.grounded,"jump returns to floor")
	c=clean();tick(c,2);c.step(1.0/60.0,{"jump_press":true});tick(c,3);c.step(1.0/60.0,{"jump_release":true})
	high=c.player.pos.y
	for i in range(60):c.step(1.0/60.0,{});high=minf(high,c.player.pos.y)
	check(high>325,"releasing jump produces shorter arc")
	c=clean();tick(c,2);c.hitstop=.05;c.step(1./60,{"jump_press":true});c.step(1./60,{"jump_release":true});high=c.player.pos.y
	for i in range(70):c.step(1./60,{});high=minf(high,c.player.pos.y)
	check(high>325,"short-jump release survives hitstop buffering")
	for freeze in [0.,.05]:
		c=clean("hall",Vector2(400,360));c.player.vel.y=120;c.player.grounded=false;c.hitstop=freeze;c.step(1./60,{"jump_press":true});c.step(1./60,{"jump_release":true});high=c.player.pos.y
		for i in range(90):c.step(1./60,{});high=minf(high,c.player.pos.y)
		check(high>325,"pre-landing short tap remains short, hitstop="+str(freeze))
	c=clean();tick(c,2);c.player.coyote=.08;c.player.grounded=false;c.player.pos.y-=3;c.step(1.0/60.0,{"jump_press":true})
	check(c.player.vel.y<-400,"coyote-time jump accepted")
	c=clean();c.player.pos=Vector2(100,350);c.player.vel.y=120;c.step(1.0/60.0,{"jump_press":true});tick(c,8)
	check(c.player.vel.y<0,"buffered jump fires on landing")
	c=clean();tick(c,2);c.step(1.0/60.0,{"jump_press":true});tick(c,12);var vy:float=c.player.vel.y;c.step(1.0/60.0,{"jump_press":true})
	check(c.player.vel.y>vy,"second jump locked before ability")
	c.flags.double_jump=true;c.step(1.0/60.0,{"jump_press":true})
	check(c.player.air_jump and c.player.vel.y<-370,"double jump unlock changes traversal")
	tick(c,10);vy=c.player.vel.y;c.step(1.0/60.0,{"jump_press":true})
	check(c.player.vel.y>vy,"no unlimited airborne jumps")
	c=clean();tick(c,2);start=c.player.pos.x;c.step(1.0/60.0,{"dash_press":true});tick(c,8)
	check(c.player.pos.x>start+60 and c.player.invuln>0,"dash covers useful distance with invulnerability")
	var cooldown:float=c.player.dash_cd;c.step(1.0/60.0,{"dash_press":true})
	check(c.player.dash_cd<cooldown,"dash cannot ignore cooldown")
	c=clean();c.hp=3;c.charge=66;tick(c,65,{"heal":true})
	check(c.hp==4 and c.charge==33,"held heal restores one heart and spends energy")
	c=clean();c.hp=3;c.charge=0;tick(c,90,{"heal":true})
	check(c.hp==3,"heal requires sufficient charge")
	c=clean();c.player.invuln=0;c.damage_player(1,Vector2(50,350));c.damage_player(1,Vector2(50,350))
	check(c.hp==4 and c.player.vel.x>0,"damage grants protection and directional knockback")
	c=clean();c.player.invuln=0;c.damage_player(1,Vector2.ZERO,false,"wave")
	check(c.player.last_hit=="wave" and c.death_hint().contains("波纹"),"retry hint matches the actual damaging cue")
	c.damage_player(1,Vector2.ZERO,false,"projectile")
	check(c.player.last_hit=="wave","blocked damage cannot overwrite the last useful retry hint")
	c.events.clear();c.respawn()
	check(c.events[-1].get("hint","").contains("波纹"),"retry lesson remains readable after checkpoint return")
	c=clean();c.hp=1;c.player.invuln=0;c.damage_player(1,Vector2.ZERO);tick(c,100)
	check(not c.player.dead and c.hp==5 and c.total_deaths==1,"death reliably restores checkpoint")
	c=clean();tick(c,3);var safe:Vector2=c.player.safe_pos;c.player.pos=Vector2(499,435);c.player.grounded=false;c.step(1.0/60.0,{})
	check(c.hp==4 and c.player.pos.distance_to(safe)<2,"water fall recovers to safe foothold")
	c=clean();c.player.pos=Vector2(410,300);c.player.vel=Vector2(0,220);tick(c,10)
	check(c.player.pos.y<350,"platform collision prevents falling through")
	c=clean();c.projectiles=[{"pos":Vector2(300,380),"vel":Vector2(0,140),"life":2.,"size":5.,"kind":"ember"}];tick(c,10)
	check(c.projectiles.is_empty(),"enemy projectiles stop at solid terrain")
	c=clean("boss",Vector2(100,388));c.echoes=[{"pos":Vector2(500,405),"wait":.58,"total":.58,"dir":-1}];tick(c,25)
	check(c.projectiles.is_empty() and not c.echoes.is_empty(),"phase-two echo provides a visible reaction window")
	tick(c,15)
	check(c.echoes.is_empty() and c.projectiles.size()==1,"telegraphed phase-two echo releases exactly once")
	c=clean();c.player.pos=Vector2(366,368);tick(c,30,{"right":true})
	check(c.player.pos.x<=391.01,"movement body blocks low ceilings before the helmet clips")
	check(Core.PLAYER_COLLISION_SIZE.y>Core.PLAYER_SIZE.y,"movement clearance is separate from forgiving combat hurtbox")
	c=clean();c.enemies=[{"kind":"crab","pos":Vector2(120,350),"size":Vector2(24,18),"hp":5,"max_hp":5,"dead":false,"last_swing":-1,"flash":0.,"vel":Vector2.ZERO}];c.player.pos=Vector2(100,344);c.player.swing_id=1;c.player.attack_dir=0;c.player.face=1;c.player.combo=1
	c.check_player_attack();c.check_player_attack()
	check(c.enemies[0].hp==3,"one attack cannot repeatedly hit same enemy")
	c.player.swing_id=2;c.check_player_attack()
	check(c.enemies[0].hp==1,"later attack can hit same enemy")
	c=clean();c.player.pos=Vector2(100,310);c.player.attack_dir=1;c.player.swing_id=1;c.player.combo=1;c.enemies=[{"kind":"crab","pos":Vector2(100,344),"size":Vector2(24,18),"hp":5,"max_hp":5,"dead":false,"last_swing":-1,"flash":0.,"vel":Vector2.ZERO}];c.check_player_attack()
	check(c.player.vel.y==-335 and c.enemies[0].hp==3,"down strike bounces and damages")
	c=clean("orchard",Vector2(664,202));c.interact()
	check(c.flags.get("double_jump",false),"movement ability is collectible")
	c=clean("roost",Vector2(547,310));c.interact();c.interact()
	check(c.max_hp==6,"health relic cannot be collected twice")
	c=clean("nave",Vector2(561,496));c.flags.gate_memory=true;c.flags.well_memory=true;c.flags.roost_memory=true;c.interact();c.interact()
	check(c.max_hp==6 and c.flags.get("mara_gift",false),"side-story reward only awarded once")
	c=clean("nave",Vector2(561,496));c.flags.gate_memory=true;c.flags.well_memory=true;c.flags.roost_memory=true
	c.room.items=[{"kind":"npc","id":"test_archivist","pos":Vector2(568,520),"label":"Archivist","text":"A separate voice."}];c.interact()
	check(c.max_hp==5 and not c.flags.has("mara_gift") and c.events[-1].text=="A separate voice.","NPC identity cannot inherit another character's story reward")
	check(not c.can_use_door({"gate":"unregistered_ability"}) and c.can_use_door({"gate":""}),"unknown gate IDs fail closed while open doors remain open")
	c=clean("hall",Vector2(804,368));c.interact()
	check(c.room_id=="hall","boss gate holds before three braziers")
	c.flags.orchard_beacon=true;c.flags.archive_beacon=true;c.flags.gallery_beacon=true;c.interact()
	check(c.room_id=="boss","three braziers open boss route")
	c=clean("nave",Vector2(1271,256));c.interact();check(c.room_id=="nave","shortcut cannot open from wrong side")
	c.flags.shortcut=true;c.interact();check(c.room_id=="gallery","unlocked shortcut works both directions")
	c=Core.new();c.enter_room("boss",Vector2(90,388));tick(c,5)
	check(not c.boss_started,"boss waits until arena entry")
	c.player.pos.x=180;tick(c,5)
	check(c.boss_started,"boss starts after player enters")
	c.player.invuln=999;c.enemies[0].hp=24;tick(c,2)
	check(c.enemies[0].phase==2,"boss enters distinct second phase")
	c=Core.new();c.enter_room("boss",Vector2(90,388));c.boss_started=true;c.player.invuln=999
	var boss:Dictionary=c.enemies[0];boss.state="windup";boss.t=.25;boss.hp=24
	c.step(1./60,{})
	check(boss.state=="windup" and boss.phase==1,"phase threshold cannot cancel a visible windup")
	var promised_attack:=false;var phase_arrived:=false
	for n in range(180):
		c.step(1./60,{})
		if boss.state=="attack":promised_attack=true
		if boss.state=="phase":phase_arrived=true;break
	check(promised_attack and phase_arrived,"phase change waits for promised attack and recovery")
	c.player.pos=boss.pos+Vector2(-27,38);c.player.face=1;c.player.attack_dir=0;c.player.swing_id=900;c.player.combo=1
	var shield_hp:int=boss.hp;c.check_player_attack()
	check(boss.hp==shield_hp,"visible transition bell-ring deflects damage")
	c.player.pos=boss.pos+Vector2(18,34);c.player.invuln=0;var protected_hp:int=c.hp;c.step(1./60,{})
	check(c.hp==protected_hp,"protected transition is also a safe contact break")
	c.player.pos=Vector2(90,388);c.player.invuln=999
	for n in range(120):
		c.step(1./60,{})
		if boss.state=="windup":break
	check(boss.phase==2 and boss.state=="windup" and boss.pattern==0,"second phase opens with a telegraphed leap/slam")
	c.kill_enemy(c.enemies[0]);check(c.flags.get("boss_defeated",false) and not c.boss_started,"boss defeat unlocks world and ends fight")
	c.enter_room("boss",Vector2(90,388));check(c.enemies.is_empty(),"defeated boss stays defeated after backtracking")
	c=clean("hall",Vector2(326,368));c.interact();c.flags.double_jump=true;c.sparks=44
	var saved:Dictionary=c.serialize();var restored=Core.new()
	check(restored.restore(saved) and restored.room_id=="hall" and restored.flags.double_jump and restored.sparks==44,"save roundtrip preserves progression and checkpoint")
	check(restored.restore(JSON.parse_string(JSON.stringify(saved))) and restored.sparks==44,"serialized JSON numeric types restore without rejecting real saves")
	check(not restored.restore({"version":42}),"unknown save version rejected safely")
	var malformed_ok:=true
	for bad in [{"version":{}},{"version":1,"checkpoint":"broken"},{"version":1,"checkpoint":{"room":[],"x":1,"y":2}},{"version":1,"checkpoint":{"room":"gate","x":{},"y":2}}]:
		if restored.restore(bad):malformed_ok=false
	for field in ["max_hp","sparks","play_seconds","deaths","assisted"]:
		var bad:Dictionary=saved.duplicate(true);bad[field]={}
		if restored.restore(bad):malformed_ok=false
	check(malformed_ok and restored.sparks==44,"malformed save types reject transactionally without partial state loss")
	check(not restored.restore({"version":1,"checkpoint":{"room":"missing"}}),"unknown checkpoint rejected safely")
	check(not restored.restore({"version":1,"checkpoint":{"room":"gate","x":-99,"y":5}}),"invalid saved position rejected safely")
	check(not restored.restore({"version":1,"checkpoint":{"room":"gate","x":50,"y":50},"flags":"bad"}),"malformed saved flags rejected safely")
	# Topology: every portal resolves and has a structural reverse path; all rooms connected.
	c=Core.new();var valid:=true;var reversed:=true;var queue:Array=["gate"];var seen:Array=[]
	while not queue.is_empty():
		var id:String=queue.pop_front()
		if seen.has(id):continue
		seen.append(id)
		for d in c.world[id].doors:
			if not c.world.has(d.target): valid=false;continue
			queue.append(d.target)
			var reverse:=false
			for back in c.world[d.target].doors:
				if back.target==id:reverse=true
			if not reverse:reversed=false
	check(valid and seen.size()==c.world.size(),"entire implemented world is structurally connected")
	check(reversed,"every transition has a reverse route")
	var f:=FileAccess.open("res://tests/test_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":passed,"failed":failed,"tests":report},"\t"));f.close()
	print("RESULT ",passed," passed; ",failed," failed")
	quit(1 if failed>0 else 0)
