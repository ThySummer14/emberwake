extends "res://scripts/core.gd"
const BREAKER=preload("res://scripts/breaker_motion.gd")
const PRESSURE=preload("res://scripts/pressure_cell.gd")
const ROUTES=preload("res://scripts/sealed_routes.gd")
const ROOT_ROOMS=preload("res://scripts/root_room.gd")
var breaker:RefCounted=BREAKER.new()
var pressure_cells:Array=[]
var probe_axis:=0.
var internal_lift_transfer:=false
var breaker_buffer:=0.0
func _init() -> void:
	super._init()
	world.merge(ROOT_ROOMS.rooms(),false)
	world.observatory.doors.append(WORLD.door("observatory_workshop",861,392,"rf_workshop",Vector2(70,286)))
func enter_room(id:String,at:Vector2) -> void:
	breaker_buffer=0.
	if breaker!=null:breaker.cancel()
	if internal_lift_transfer and id=="rf_workshop" and room_id==id and room!=null:
		player.pos=at;player.vel=Vector2.ZERO;player.grounded=false;player.dash=0.;player.attack=0.;player.safe_pos=safe_landing_for(at);player.invuln=.5
		trail.clear();particles.clear();events.append({"type":"room","title":room.name,"subtitle":room.subtitle});return
	super.enter_room(id,at)
	room=ROUTES.materialize(world[room_id],flags)
	player.safe_pos=safe_landing_for(at)
	pressure_cells.clear()
	for e in enemies:
		e.breaker_protect=0.;e.last_breaker=-1
		if e.kind=="rf_carrier":
			var feet:Vector2=e.pos+Vector2(e.size.x/2,e.size.y);e.size=Vector2(30,24);e.pos=feet-Vector2(15,24);e.home=e.pos;e.hp=4;e.max_hp=4;e.state="patrol";e.breaker_protect=0.;e.last_breaker=-1
	for spec in room.get("pressure_cells",[]):
		var cell=PRESSURE.new(spec.lane);cell.enabled=not flags.get(spec.id+"_vented",false);pressure_cells.append(cell)
func step(dt:float,input:Dictionary) -> void:
	var effective:Dictionary=input.duplicate()
	var frozen:bool=hitstop>0
	var downward_request:bool=flags.get("rf_breaker",false) and input.get("down",false) and input.get("dash_press",false) and not player.grounded
	if downward_request:
		effective.dash_press=false;player.dash_buffer=0.
		if not player.dead and player.hurt<=0 and not player.air_dash and player.dash<=0 and breaker.state=="idle":breaker_buffer=.14
	if player.dead or player.hurt>0 or player.grounded:breaker_buffer=0.
	if not frozen:
		probe_axis=float(input.get("right",false))-float(input.get("left",false))
		if breaker_buffer>0:
			if breaker.request({"down":true,"dash_press":true},player,flags.get("rf_breaker",false),0):
				breaker_buffer=0.;events.append({"type":"sound","id":"breaker_tuck"})
			else:breaker_buffer=maxf(0.,breaker_buffer-dt)
		breaker.step(dt,player)
		if breaker.state!="idle":
			for key in ["dash_press","jump_press","attack_press","heal"]:effective[key]=false
	super.step(dt,effective)
	if frozen or player.dead:return
	for cell in pressure_cells:
		var old_phase:String=cell.state();var old_shutters:int=cell.warning_shutters()
		cell.step(dt)
		if cell.state()=="warning" and cell.warning_shutters()!=old_shutters:events.append({"type":"sound","id":"pressure_click"})
		if cell.state()=="discharge" and old_phase!="discharge":events.append({"type":"sound","id":"pressure_vent"})
		if cell.hurts(Rect2(player.pos,PLAYER_SIZE)):
			damage_player(1,cell.lane.get_center(),false,"pressure")
func move_body(pos:Vector2,velocity:Vector2,size:Vector2,dt:float) -> Dictionary:
	if breaker==null or size!=PLAYER_COLLISION_SIZE or breaker.state=="idle":return super.move_body(pos,velocity,size,dt)
	var imposed:Vector2=breaker.velocity(probe_axis)
	if breaker.state=="recovery":imposed=Vector2(0,GRAVITY*dt)
	var before:=Rect2(pos,size)
	var after:=Rect2(pos+imposed*dt,size)
	var broken:Array=ROUTES.crossed_seals(world[room_id],flags,before,after,breaker)
	if not broken.is_empty():
		for id in broken:flags[id]=true;breaker.broken_this_activation.append(id)
		room=ROUTES.materialize(world[room_id],flags)
		burst(after.get_center(),22,"gold",100);shake=4;events.append({"type":"sound","id":"breaker_impact"});events.append({"type":"save"})
	var moved:Dictionary=super.move_body(pos,imposed,size,dt)
	if breaker.state=="fall":breaker_strike(before,Rect2(moved.pos,size))
	if moved.grounded and breaker.state=="fall":
		breaker.land();events.append({"type":"sound","id":"breaker_impact"});shake=3
	return moved
func can_use_door(d:Dictionary) -> bool:
	if d.get("gate","")=="rf_workshop_hoist":return flags.get("rf_workshop_hoist",false)
	return super.can_use_door(d)
func interact() -> void:
	var nearest:Dictionary=nearest_interaction()
	if not nearest.is_empty() and nearest.category=="door" and nearest.data.target==room_id and can_use_door(nearest.data):
		internal_lift_transfer=true;super.interact();internal_lift_transfer=false;return
	if not nearest.is_empty() and nearest.category=="item" and nearest.data.id=="rf_workshop_hoist":
		flags.rf_workshop_hoist=true;events.append({"type":"toast","title":"回程绞盘","text":"旧索重新绷紧。升降门可以往返了。"});events.append({"type":"save"});return
	super.interact()

func update_enemies(dt:float) -> void:
	var all_enemies:Array=enemies
	var regular:Array=[];var carriers:Array=[]
	for e in all_enemies:
		e.breaker_protect=maxf(0,e.get("breaker_protect",0.)-dt)
		if e.kind=="rf_carrier":carriers.append(e)
		else:regular.append(e)
	enemies=regular;super.update_enemies(dt);enemies=all_enemies
	for e in carriers:
		if e.dead:continue
		e.t+=dt;e.cooldown=maxf(0,e.cooldown-dt);e.flash=maxf(0,e.flash-dt)
		var target:Vector2=player.pos+Vector2(7,12)-(e.pos+Vector2(15,12))
		match e.state:
			"patrol":
				if e.pos.x<e.lo:e.face=1
				if e.pos.x+e.size.x>e.hi:e.face=-1
				e.vel.x=move_toward(e.vel.x,e.face*24,120*dt)
				if absf(target.x)<190 and absf(target.y)<45 and e.cooldown<=0:
					e.state="windup";e.t=0.;e.face=1 if target.x>0 else -1
			"windup":
				e.vel.x=move_toward(e.vel.x,0,600*dt)
				if e.t<.20:e.face=1 if target.x>0 else -1
				if e.t>=.65:e.state="attack";e.t=0.;events.append({"type":"sound","id":"carrier_sweep"})
			"attack":
				var hit:=Rect2(e.pos+Vector2(23 if e.face>0 else -30,10),Vector2(37,14))
				if hit.intersects(Rect2(player.pos,PLAYER_SIZE)):damage_player(1,e.pos,false,"carrier_sweep")
				if e.t>=.20:e.state="recover";e.t=0.
			"recover":
				e.vel.x=move_toward(e.vel.x,0,500*dt)
				if e.t>=.75:e.state="patrol";e.cooldown=.55;e.t=0.
		e.vel.y=minf(e.vel.y+GRAVITY*dt,640)
		var moved:Dictionary=super.move_body(e.pos,e.vel,e.size,dt);e.pos=moved.pos;e.vel=moved.vel;e.grounded=moved.grounded
		if e.grounded and e.state=="patrol":
			var probe:Vector2=e.pos+Vector2(e.size.x+5 if e.face>0 else -5,e.size.y+3);var floor_exists:=false
			for platform in room.platforms:
				if platform.rect.has_point(probe):floor_exists=true
			if not floor_exists:e.face*=-1

		if not e.dead and e.breaker_protect<=0 and Rect2(e.pos+Vector2(3,2),e.size-Vector2(6,3)).intersects(Rect2(player.pos+Vector2(2,3),PLAYER_SIZE-Vector2(4,4))):damage_player(1,e.pos,false,"contact")
func death_hint() -> String:
	match player.get("last_hit",""):
		"pressure":return "三扇铜窗依次张开。喷气停下后，再穿过白雾。"
		"carrier_sweep":return "煤铲会贴着地面扫过。跃过它，等它卡住再还击。"
	return super.death_hint()

func breaker_strike(before:Rect2,after:Rect2) -> void:
	var left:float=minf(before.position.x,after.position.x)-4
	var right:float=maxf(before.end.x,after.end.x)+4
	var top:float=minf(before.end.y,after.end.y)-4
	var bottom:float=maxf(before.end.y,after.end.y)+4
	var strike:=Rect2(Vector2(left,top),Vector2(right-left,bottom-top))
	for e in enemies:
		if e.dead or e.get("last_breaker",-1)==breaker.active_id:continue
		if e.kind=="boss" and e.state=="phase":continue
		if not strike.intersects(enemy_hurtbox(e)):continue
		e.last_breaker=breaker.active_id;e.breaker_protect=.4;e.hp-=3;e.flash=.15
		e.vel.x+=(30 if e.kind=="boss" else 180)*(1 if e.pos.x+e.size.x*.5>=player.pos.x+7 else -1)
		charge=minf(99,charge+8);burst(e.pos+e.size*.5,15,"gold",80);events.append({"type":"sound","id":"breaker_impact"})
		if e.hp<=0:kill_enemy(e)

func damage_player(amount:int,from:Vector2,force:bool=false,reason:String="contact") -> void:
	# A struck body's brief contact grace is local, not immunity to a spear, projectile or vent.
	if not force and reason in ["contact","boss_contact"]:
		for e in enemies:
			if e.get("breaker_protect",0.)>0 and from.distance_to(e.pos+e.size*.5)<.5:return
	super.damage_player(amount,from,force,reason)
