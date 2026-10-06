extends SceneTree
const Core=preload("res://scripts/ledger_core.gd")
var c:RefCounted
var reach:Dictionary
var frames:=0
var checkpoints:Array=[]
var failed:=false
var assertions:=0
var combat_active:=false
var event_log:Array=[]
var saves:Array=[]
var damage_events:Array=[]
func step(input:Dictionary={}) -> void:
	var before_hp:int=c.hp
	c.step(1.0/60,input);frames+=1
	if c.hp<before_hp:damage_events.append({"frame":frames,"room":c.room_id,"reason":c.player.get("last_hit",""),"x":c.player.pos.x,"hp":c.hp})
	if not combat_active and c.room_id!="boss":c.enemies.clear()
	event_log.append_array(c.events.duplicate(true));c.events.clear();c.particles.clear();c.trail.clear()
func platform_at() -> int:
	for i in range(c.room.platforms.size()):
		var r:Rect2=c.room.platforms[i].rect
		if absf(c.player.pos.y+24-r.position.y)<1 and c.player.pos.x+14>r.position.x and c.player.pos.x<r.end.x:return i
	return -1
func floor_for(pos:Vector2) -> int:
	var best:=-1;var distance:=99999.0
	for i in range(c.room.platforms.size()):
		var r:Rect2=c.room.platforms[i].rect
		var d:float=absf(pos.y-r.position.y)+maxf(0,absf(pos.x-r.get_center().x)-r.size.x/2)*3
		if d<distance:distance=d;best=i
	return best
func walk_to(x:float) -> bool:
	for i in range(480):
		var dx:float=x-c.player.pos.x
		if absf(dx)<4 and absf(c.player.vel.x)<10:return true
		step({"right":dx>3,"left":dx< -3})
	return false
func jump_edge(edge:Dictionary) -> bool:
	if not walk_to(edge.start_x):return false
	for i in range(10):step()
	for frame in range(maxi(150,int(edge.frames)+45)):
		var dx:float=edge.target_x-c.player.pos.x
		step({"right":dx>3,"left":dx< -3,"jump_press":(frame==0 and edge.get("jump",true)) or (edge.double_at>0 and frame==edge.double_at),"dash_press":edge.dash_at>0 and frame==edge.dash_at})
		if frame>4 and c.player.grounded and platform_at()==int(edge.to):return true
	return false
func path_to(target:int) -> Array:
	var source:=platform_at()
	if source==target:return []
	var edges:Array=reach.rooms[c.room_id].edges
	if not c.flags.get("double_jump",false) and reach.pre_ability_rooms.has(c.room_id):edges=reach.pre_ability_rooms[c.room_id]
	var queue:Array=[source];var previous:Dictionary={source:{}}
	while not queue.is_empty():
		var id:int=queue.pop_front()
		for edge in edges:
			if edge.from!=id:continue
			if not c.flags.get("double_jump",false) and edge.double_at>0:continue
			if previous.has(int(edge.to)):continue
			previous[int(edge.to)]=edge;queue.append(int(edge.to))
	if not previous.has(target):return [{"error":"no path"}]
	var result:Array=[];var node:=target
	while node!=source:
		var edge:Dictionary=previous[node];result.push_front(edge);node=int(edge.from)
	return result
func go_to(id:String) -> bool:
	var target:Dictionary={}
	for obj in c.room.items+c.room.doors:
		if obj.id==id:target=obj;break
	if target.is_empty():return false
	for i in range(150):
		if c.player.grounded:break
		step()
	var desired:=floor_for(target.pos)
	var attempts:=0
	while platform_at()!=desired and attempts<12:
		attempts+=1
		var route:=path_to(desired)
		if route.is_empty() or route[0].has("error"):
			print("ROUTE_FAILED ",c.room_id," target=",id," no path at ",platform_at());return false
		var edge:Dictionary=route[0]
		if not jump_edge(edge) and platform_at()<0:
			print("ROUTE_FAILED ",c.room_id," target=",id," edge=",edge," pos=",c.player.pos);return false
	if platform_at()!=desired:return false
	if not walk_to(target.pos.x-7):return false
	step({"interact_press":true})
	checkpoints.append({"target":id,"room":c.room_id,"hp":c.hp,"frame":frames,"double_jump":c.flags.get("double_jump",false),"beacons":c.beacon_count()})
	print("REACHED ",checkpoints.back())
	return true
func observe(c:RefCounted,e:Dictionary) -> Dictionary:
	var cue:="idle"
	if e.state=="windup":cue=["slam_marker","charge_marker","ring_glow"][int(e.pattern)]
	elif e.state=="recover":cue="bent_recovery"
	elif e.state=="phase":cue="opening_bell"
	elif e.state=="attack":cue=["airborne_bell","extended_charge","ring_release"][int(e.pattern)]
	var echo_positions:Array=[]
	for echo in c.echoes:echo_positions.append(echo.pos)
	return {"center":e.pos+e.size/2,"cue":cue,"phase_two":e.phase==2,"grounded":e.grounded,"echo_markers":echo_positions}
func fight_boss() -> Dictionary:
	var profile:="cautious";var reaction_frames:=15;var seed_number:=32;var attempt:=0;var learned:Dictionary={}
	var e:Dictionary=c.enemies[0];var history:Array=[];var cue_age:=0.0;var previous_cue:="";var phase_two_seen:=false
	var rng:=RandomNumberGenerator.new();rng.seed=seed_number
	var boss_frames:=0;var taken:=0;var prev_hp:int=c.hp;var phase_transitions:=0
	var echo_age:=0.0
	var phase_durations:Dictionary={"1":0.,"2":0.};var patterns:Dictionary={"1":[],"2":[]}
	var previous_boss_state:="";var damage_log:Array=[];var echo_count:=0;var peak_echoes:=0
	var input_trace:Array=[]
	var exposed:Dictionary=learned.duplicate()
	var knows_spacing:bool=profile!="learning" or learned.get("spacing",false)
	var knows_charge:bool=profile not in ["unfamiliar","learning"] or learned.get("charge",false)
	var knows_slam:bool=profile not in ["unfamiliar","learning"] or learned.get("slam",false)
	var knows_echo:bool=profile not in ["unfamiliar","learning"] or learned.get("echo",false)
	var input:Dictionary={};var current_reaction:=reaction_frames;var next_decision:=0
	for frame in range(10800):
		boss_frames=frame+1
		if e.dead or c.player.dead:break
		phase_durations[str(e.phase)]+=1./60
		if e.state=="attack" and previous_boss_state!="attack":patterns[str(e.phase)].append(int(e.pattern))
		previous_boss_state=e.state
		if c.echoes.size()>peak_echoes:echo_count+=c.echoes.size()-peak_echoes
		peak_echoes=c.echoes.size()
		history.append(observe(c,e))
		var obs:Dictionary=history[maxi(0,history.size()-1-current_reaction)]
		if obs.cue=="extended_charge":exposed.charge=true
		if obs.cue=="airborne_bell":exposed.slam=true
		if not obs.echo_markers.is_empty():exposed.echo=true
		if obs.cue!=previous_cue:cue_age=0;previous_cue=obs.cue
		else:cue_age+=1.0/60
		if obs.echo_markers.is_empty():echo_age=0.0
		else:echo_age+=1./60
		if obs.phase_two and not phase_two_seen:phase_transitions+=1;phase_two_seen=true
		if frame>=next_decision:
			next_decision=frame+rng.randi_range(2,5)
			current_reaction=clampi(reaction_frames+rng.randi_range(-3,3),3,36)
			var dx:float=obs.center.x-(c.player.pos.x+7)
			var dy:float=obs.center.y-(c.player.pos.y+12)
			var standoff:float=57 if profile=="cautious" else (48 if profile=="aggressive" or (profile=="learning" and knows_spacing) else 30)
			input={"right":dx>standoff+4 or (dx<0 and absf(dx)<standoff-7),"left":dx< -standoff-4 or (dx>0 and absf(dx)<standoff-7)}
			var willing:bool=(profile!="cautious" and not (profile=="learning" and knows_spacing)) or obs.cue in ["bent_recovery","idle","ring_glow"]
			if profile=="learning" and obs.cue=="opening_bell":willing=false
			if willing and absf(dx)<62 and absf(dy)<43 and c.player.attack<=0:
				input.right=dx>0;input.left=dx<0;input.attack_press=true
			if not knows_charge:
				if obs.cue=="extended_charge" and c.player.grounded:input.jump_press=true
			elif obs.cue=="charge_marker" and cue_age>(.23 if obs.phase_two else .40) and c.player.grounded:
				input.jump_press=true
			if knows_charge and obs.cue=="extended_charge" and not c.player.grounded and c.player.vel.y>0 and not c.player.air_jump:input.jump_press=true
			if knows_slam and obs.cue=="airborne_bell" and absf(dx)<125:
				input.right=dx<0;input.left=dx>0;input.dash_press=c.player.dash_cd<=0
			if knows_slam and obs.cue=="bent_recovery" and cue_age<.13 and c.player.grounded:
				input.jump_press=true
			if not c.player.grounded and dy>16 and absf(dx)<25:
				input.down=true;input.attack_press=c.player.attack<=0
			if knows_echo and not obs.echo_markers.is_empty() and echo_age>.12 and c.player.grounded:
				input.jump_press=true
			if (profile=="cautious" or (profile=="learning" and knows_spacing)) and obs.echo_markers.is_empty() and c.hp<4 and c.charge>=33 and c.player.grounded and (obs.cue=="bent_recovery" or c.player.heal>0):
				input={"heal":true}
		if profile=="aggressive" and reaction_frames==9:input_trace.append(input.duplicate())
		step(input)
		for k in ["attack_press","jump_press","dash_press"]:input[k]=false
		if c.hp<prev_hp:
			taken+=prev_hp-c.hp
			exposed.spacing=true
			damage_log.append({"seconds":snappedf(frame/60.,.01),"observed_cue":obs.cue,"boss_phase":e.phase,"player_x":snappedf(c.player.pos.x,.1),"boss_x":snappedf(e.pos.x,.1)})
		prev_hp=c.hp;c.events.clear();c.particles.clear();c.trail.clear()
	var row:Dictionary={"profile":profile,"attempt":attempt,"learned_before":learned.duplicate(),"learned_after":exposed,"reaction_ms":reaction_frames*1000/60,"timing_jitter_frames":3,"seed":seed_number,"victory":e.dead,"death":c.player.dead,"enemy_hp_remaining":e.hp,"damage_taken":taken,"seconds":snappedf(boss_frames/60.,.01),"phase_two_reached":phase_two_seen,"phase_seconds":phase_durations,"patterns_launched":patterns,"echo_markers_seen":echo_count,"damage_log":damage_log}
	return row

func check(ok:bool,label:String) -> bool:
	assertions+=1
	if not ok:failed=true
	print("PASS " if ok else "FAIL ",label)
	return ok
func verify_save(label:String) -> void:
	var data:Dictionary=JSON.parse_string(JSON.stringify(c.serialize()));var restored=Core.new()
	var okay:bool=restored.restore(data)
	for k in c.flags:okay=okay and restored.flags.get(k,false)==c.flags[k]
	for n in range(90):restored.step(1./60,{});restored.events.clear();restored.particles.clear()
	okay=okay and restored.hp==restored.max_hp and not restored.player.dead and restored.player.grounded
	saves.append({"label":label,"checkpoint":c.checkpoint.room,"flags":c.flags.duplicate(),"passed":okay})
	check(okay,"save/load durable state and safe checkpoint: "+label)
func replay_file(path:String) -> void:
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	for input in data.input_frames:step(input)
func cross_workshop_opening() -> bool:
	if not walk_to(610):return false
	for n in range(95):
		var dx:float=765-c.player.pos.x
		step({"right":dx>3,"left":dx< -3,"jump_press":n==0,"dash_press":n==14})
		if n>12 and c.player.grounded and c.player.pos.x>744 and c.player.pos.y<310:return true
	return false
func carrier_approach() -> bool:
	var e:Dictionary=c.enemies[0];var observations:Array=[]
	for n in range(1800):
		if e.dead:return true
		if c.player.dead:return false
		observations.append({"center":e.pos+e.size/2,"raised":e.state=="windup"})
		var obs:Dictionary=observations[maxi(0,observations.size()-10)]
		var delta:Vector2=obs.center-(c.player.pos+Vector2(7,12));var input:Dictionary={"right":delta.x>46,"left":delta.x< -46}
		if absf(delta.x)<58 and absf(delta.y)<37 and c.player.attack<=0:
			input.attack_press=true;input.right=delta.x>0;input.left=delta.x<0
		if obs.raised and c.player.grounded and absf(delta.x)<110:input.jump_press=true
		if not c.player.grounded and delta.y>17 and absf(delta.x)<25:input.down=true;input.attack_press=c.player.attack<=0
		step(input)
	return false
func _initialize() -> void:
	c=Core.new();c.enemies.clear();reach=JSON.parse_string(FileAccess.get_file_as_string("res://tests/reachability_results.json"))
	var targets:Array=["gate_lamp","first_steps","gate_nave","nave_lamp","mara","map_sign","nave_orchard","double_jump","orchard_beacon","orchard_archive","archive_beacon","archive_well","well_lamp","well_sluice","sluice_nave","nave_steps","steps_gallery","gallery_beacon","gallery_shortcut","gallery_hall","hall_lamp","hall_boss"]
	for target in targets:
		if not check(go_to(target),"new-game ordinary navigation reaches "+target):break
		if target.ends_with("lamp") or target in ["double_jump","gallery_shortcut"]:verify_save(target)
	if not failed:
		combat_active=true
		var boss:Dictionary=fight_boss();check(boss.victory and not boss.death,"real Bellkeeper encounter from genuine approach: "+str(boss))
	if not failed:
		check(go_to("boss_observatory") and go_to("first_dawn"),"victory reaches chapter conclusion with no flag injection")
		var text:=""
		for event in event_log:
			if event.type=="ending":text=event.text
		print("OBSERVATORY_HANDOFF_TEXT ",text)
		check(c.flags.get("chapter_one",false),"chapter completion is durable")
		check(go_to("observatory_lamp"),"chapter platform descends to the existing safe checkpoint");verify_save("chapter completion")
		check(walk_to(854),"normal walking reaches the workshop continuation entrance")
		replay_file("res://tests/full_route_input_trace.json")
		check(c.room_id=="observatory" and c.hp==5 and c.flags.get("rf_workshop_hoist",false),"complete workshop acquisition/pressure/return loop follows the chapter in one journey")
		verify_save("workshop return")
		step({"interact_press":true});check(c.room_id=="rf_workshop","same physical Observatory door starts the onward visit")
		check(cross_workshop_opening(),"onward revisit jumps the persistently opened ceramic gap")
		check(carrier_approach(),"onward revisit handles the respawned carrier with delayed cues")
		check(walk_to(1167),"onward walk reaches the existing Ledger approach")
		replay_file("res://tests/ledger_full_input_trace.json")
		check(c.room_id=="archive" and c.hp>0 and c.total_deaths==0,"combined journey completes the real Ledger tour and returns to Archive alive without reset")
		check(c.flags.get("shortcut",false) and c.flags.get("rf_archive_hatch",false) and c.flags.get("rf_tilu_records_told",false),"new route/story preserves the earlier Gatewater shortcut")
		verify_save("Archive return")
	var first_steps_seen:=false;var mara_seen:=false;var map_seen:=false
	for event in event_log:
		if event.type=="dialog":
			first_steps_seen=first_steps_seen or event.title=="褪色的路牌"
			mara_seen=mara_seen or event.title=="织灯人 · 玛拉"
			map_seen=map_seen or event.title=="浸水的城区图"
	check(first_steps_seen and mara_seen and map_seen,"new-game route can encounter movement, objective and map guidance before regional expansion")
	var output:Dictionary={"passed":not failed,"assertions":assertions,"frames":frames,"hp":c.hp,"room":c.room_id,"checkpoints":saves,"damage_events":damage_events,"scope":"Deterministic combined route from new game; Gatewater ordinary enemies removed for navigation isolation; Bellkeeper and all workshop/Ledger encounters active with delayed cues. No human playtest."}
	var file:=FileAccess.open("res://tests/combined_loop_result.json",FileAccess.WRITE);file.store_string(JSON.stringify(output,"\t"));file.close()
	print("COMBINED_LOOP_RESULT ",not failed," assertions=",assertions," frames=",frames," room=",c.room_id," hp=",c.hp)
	quit(1 if failed else 0)
