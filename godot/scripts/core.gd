extends RefCounted
class_name EmberCore

const WORLD = preload("res://scripts/world.gd")
const PLAYER_SIZE = Vector2(14,24)
const PLAYER_COLLISION_SIZE = Vector2(14,38)
const PLAYER_COLLISION_OFFSET = Vector2(0,-14)
const SPEED = 172.0
const GRAVITY = 1100.0
const JUMP = -432.0
const SAVE_VERSION = 1
var world: Dictionary = WORLD.rooms()
var room_id: String = "gate"
var room: Dictionary
var player: Dictionary
var enemies: Array = []
var projectiles: Array = []
var echoes: Array = []
var particles: Array = []
var events: Array = []
var flags: Dictionary = {}
var visited: Array = []
var checkpoint: Dictionary = {"room":"gate","pos":Vector2(153,368)}
var max_hp: int = 5
var hp: int = 5
var charge: float = 60.0
var sparks: int = 0
var timer: float = 0.0
var hitstop: float = 0.0
var shake: float = 0.0
var death_time: float = 0.0
var total_deaths: int = 0
var play_seconds: float = 0.0
var room_time: float = 0.0
var trail: Array = []
var victory: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var attack_serial: int = 0
var boss_started: bool = false
var assisted: bool = false

func _init() -> void:
	rng.seed = 9022026
	make_player(Vector2(110,368))
	enter_room("gate",Vector2(110,368))

func make_player(at: Vector2) -> void:
	player = {"pos":at,"vel":Vector2.ZERO,"face":1,"grounded":false,"coyote":0.0,"jump_buffer":0.0,"jump_cut_pending":false,"attack_buffer":0.0,"air_jump":false,"air_dash":false,"dash":0.0,"dash_cd":0.0,"dash_buffer":0.0,"attack":0.0,"attack_dir":0,"combo":0,"combo_timer":0.0,"invuln":0.0,"hurt":0.0,"heal":0.0,"land":0.0,"animation":0.0,"safe_pos":at,"safe_room":room_id,"swing_id":0,"last_hit":"contact","dead":false}

func enter_room(id: String, at: Vector2) -> void:
	if not world.has(id): return
	room_id = id
	room = world[id]
	room_time = 0
	boss_started = false
	player.pos = at
	player.vel = Vector2.ZERO
	player.safe_pos = safe_landing_for(at)
	player.safe_room = id
	player.grounded = false
	player.dash = 0.0
	player.attack = 0.0
	player.invuln = 0.75
	projectiles.clear()
	echoes.clear()
	particles.clear()
	trail.clear()
	enemies.clear()
	if not visited.has(id): visited.append(id)
	for i in range(room.enemies.size()):
		var spec: Dictionary = room.enemies[i]
		if spec.kind == "boss" and flags.get("boss_defeated",false): continue
		var size := Vector2(24,18)
		var health := 3
		if spec.kind == "warden":
			size = Vector2(22,34)
			health = 6
		elif spec.kind == "moth":
			size = Vector2(22,20)
			health = 3
		elif spec.kind == "eel":
			size = Vector2(27,19)
			health = 4
		elif spec.kind == "boss":
			size = Vector2(49,68)
			health = 54
		enemies.append({"kind":spec.kind,"pos":spec.pos-Vector2(size.x/2,size.y),"home":spec.pos-Vector2(size.x/2,size.y),"vel":Vector2.ZERO,"size":size,"hp":health,"max_hp":health,"lo":spec.lo,"hi":spec.hi,"face":-1,"state":"patrol","t":0.0,"cooldown":float(i)*0.47+0.8,"flash":0.0,"last_swing":-1,"grounded":false,"dead":false,"pattern":0,"phase":1,"contact_cd":0.0,"id":room_id+str(i)})
	events.append({"type":"room","title":room.name,"subtitle":room.subtitle})

func safe_landing_for(at: Vector2) -> Vector2:
	var best:=at
	var cost:=INF
	for platform in room.platforms:
		var r:Rect2=platform.rect
		if r.size.x<PLAYER_SIZE.x+4:continue
		var candidate:=Vector2(clampf(at.x,r.position.x+2,r.end.x-PLAYER_SIZE.x-2),r.position.y-PLAYER_SIZE.y)
		var occupied:=false
		for other in room.platforms:
			if Rect2(candidate+PLAYER_COLLISION_OFFSET+Vector2(.1,.1),PLAYER_COLLISION_SIZE-Vector2(.2,.2)).intersects(other.rect):occupied=true
		for hazard in room.hazards:
			if Rect2(candidate,PLAYER_SIZE).intersects(hazard):occupied=true
		if occupied:continue
		var score:float=absf(candidate.x-at.x)+absf(candidate.y-at.y)*.45
		if score<cost:cost=score;best=candidate
	return best

func body(pos: Vector2, size: Vector2) -> Rect2:
	return Rect2(pos,size)

func move_body(pos: Vector2, vel: Vector2, size: Vector2, dt: float) -> Dictionary:
	var new_pos := pos
	var velocity := vel
	var grounded := false
	var wall := false
	new_pos.x += velocity.x*dt
	for platform in room.platforms:
		var r: Rect2 = platform.rect
		if Rect2(new_pos,size).intersects(r):
			if velocity.x > 0: new_pos.x = r.position.x-size.x
			elif velocity.x < 0: new_pos.x = r.end.x
			velocity.x = 0
			wall = true
	new_pos.x = clampf(new_pos.x,0,room.size.x-size.x)
	new_pos.y += velocity.y*dt
	for platform in room.platforms:
		var r: Rect2 = platform.rect
		if Rect2(new_pos,size).intersects(r):
			if velocity.y >= 0 and pos.y+size.y <= r.position.y+4:
				new_pos.y = r.position.y-size.y
				velocity.y = 0
				grounded = true
			elif velocity.y < 0 and pos.y >= r.end.y-4:
				new_pos.y = r.end.y
				velocity.y = 0
	return {"pos":new_pos,"vel":velocity,"grounded":grounded,"wall":wall}

func update_particles(dt: float) -> void:
	for i in range(particles.size()-1,-1,-1):
		var a: Dictionary = particles[i]
		a.life -= dt
		a.pos += a.vel*dt
		a.vel.y += a.get("gravity",90.0)*dt
		if a.life <= 0: particles.remove_at(i)
	for i in range(trail.size()-1,-1,-1):
		trail[i].life -= dt
		if trail[i].life <= 0: trail.remove_at(i)

func burst(at: Vector2, count: int, color: String, force: float = 100.0) -> void:
	for i in range(count):
		var a := rng.randf()*TAU
		var speed := rng.randf_range(force*0.2,force)
		particles.append({"pos":at,"vel":Vector2(cos(a),sin(a))*speed,"life":rng.randf_range(0.22,0.65),"max":0.65,"color":color,"size":rng.randi_range(1,3)})

func step(dt: float, input: Dictionary) -> void:
	timer += dt
	shake = maxf(0,shake-dt*22)
	update_particles(dt)
	if hitstop > 0:
		if input.get("attack_press",false): player.attack_buffer=0.16
		if input.get("jump_press",false):
			player.jump_buffer=0.13
			player.jump_cut_pending=false
		if input.get("jump_release",false):player.jump_cut_pending=true
		if input.get("dash_press",false): player.dash_buffer=0.12
		hitstop -= dt
		return
	play_seconds += dt
	room_time += dt
	if player.dead:
		death_time -= dt
		if death_time <= 0: respawn()
		return
	var p: Dictionary = player
	p.animation += dt
	for k in ["coyote","jump_buffer","attack_buffer","dash_cd","invuln","hurt","combo_timer","land","dash_buffer"]:
		p[k] = maxf(0,p[k]-dt)
	if p.combo_timer <= 0: p.combo = 0
	if input.get("jump_press",false):
		p.jump_buffer = 0.13
		p.jump_cut_pending=false
	if input.get("jump_release",false):p.jump_cut_pending=true
	if input.get("attack_press",false): p.attack_buffer = 0.16
	if input.get("dash_press",false): p.dash_buffer = 0.12
	var axis: float = float(input.get("right",false))-float(input.get("left",false))
	if axis != 0 and p.hurt <= 0 and p.dash <= 0 and p.attack<=0.12: p.face = int(axis)
	if p.grounded:
		p.coyote = 0.1
		p.air_jump = false
		p.air_dash = false
		if p.hurt <= 0:
			p.safe_pos = p.pos
			p.safe_room = room_id
	if p.jump_buffer > 0 and p.hurt <= 0 and p.dash <= 0:
		if p.coyote > 0:
			p.vel.y = JUMP
			p.grounded = false
			p.coyote = 0
			p.jump_buffer = 0
			burst(p.pos+Vector2(7,24),8,"mist",55)
			events.append({"type":"sound","id":"jump"})
		elif flags.get("double_jump",false) and not p.air_jump:
			p.vel.y = JUMP*0.92
			p.air_jump = true
			p.jump_buffer = 0
			burst(p.pos+Vector2(7,24),15,"teal",90)
			events.append({"type":"sound","id":"double_jump"})
	if p.jump_cut_pending and p.vel.y < -140:
		p.vel.y *= 0.48
		p.jump_cut_pending=false
	elif p.jump_buffer<=0:p.jump_cut_pending=false
	if p.dash_buffer > 0 and p.dash_cd <= 0 and p.hurt <= 0 and (p.grounded or not p.air_dash):
		if axis!=0:p.face=int(axis)
		p.dash = 0.16
		p.dash_buffer = 0
		p.dash_cd = 0.56
		p.air_dash = true
		p.attack = 0
		p.invuln = maxf(p.invuln,0.18)
		p.vel = Vector2(p.face*440,0)
		burst(p.pos+Vector2(7,15),9,"gold",80)
		events.append({"type":"sound","id":"dash"})
	if p.attack_buffer > 0 and p.attack <= 0 and p.dash <= 0 and p.hurt <= 0:
		p.attack = 0.31 if p.combo < 2 else 0.38
		p.attack_buffer = 0
		p.combo = (int(p.combo)+1)%3
		p.combo_timer = 0.65
		p.attack_dir = -1 if input.get("up",false) else (1 if input.get("down",false) and not p.grounded else 0)
		attack_serial += 1
		p.swing_id = attack_serial
		events.append({"type":"sound","id":"swing"})
	if p.attack > 0:
		p.attack -= dt
		if p.attack < 0.25 and p.attack > 0.12:
			check_player_attack()
	if p.dash > 0:
		p.dash -= dt
		p.vel.y = 0
		p.vel.x = p.face*440
		if int(timer*60)%2==0: trail.append({"pos":p.pos,"face":p.face,"life":0.19})
	else:
		if p.hurt <= 0:
			var target_speed := axis*SPEED
			if input.get("heal",false) and p.grounded and hp<max_hp and charge>=33: target_speed=0
			if p.attack > 0 and p.grounded: target_speed *= 0.64
			p.vel.x = move_toward(p.vel.x,target_speed,(1500 if p.grounded else 820)*dt)
		else: p.vel.x = move_toward(p.vel.x,0,280*dt)
		p.vel.y = minf(p.vel.y+GRAVITY*dt,640)
	var was_grounded: bool = p.grounded
	var moved := move_body(p.pos+PLAYER_COLLISION_OFFSET,p.vel,PLAYER_COLLISION_SIZE,dt)
	p.pos = moved.pos-PLAYER_COLLISION_OFFSET
	p.vel = moved.vel
	p.grounded = moved.grounded
	if p.grounded and not was_grounded:
		p.land=0.13
		burst(p.pos+Vector2(7,24),6,"mist",55)
		events.append({"type":"sound","id":"land"})
	if p.pos.y > room.size.y+30: fall_recover()
	else:
		for hazard in room.hazards:
			if Rect2(p.pos+Vector2(2,3),PLAYER_SIZE-Vector2(4,4)).intersects(hazard):
				fall_recover()
				break
	if player.dead: return
	if input.get("heal",false) and p.grounded and p.dash <= 0 and p.attack <= 0 and p.hurt <= 0 and hp<max_hp and charge>=33:
		p.heal += dt
		p.vel.x = 0
		if p.heal >= 0.85:
			p.heal = 0
			hp = mini(max_hp,hp+1)
			charge -= 33
			burst(p.pos+Vector2(7,10),22,"gold",70)
			events.append({"type":"sound","id":"heal"})
	else: p.heal = 0
	if input.get("interact_press",false): interact()
	update_enemies(dt)
	update_echoes(dt)
	update_projectiles(dt)
	if assisted: charge = minf(99,charge+dt*2)

func attack_rect() -> Rect2:
	var pos: Vector2 = player.pos
	if player.attack_dir == -1: return Rect2(pos+Vector2(-8,-30),Vector2(30,36))
	if player.attack_dir == 1: return Rect2(pos+Vector2(-8,18),Vector2(30,36))
	return Rect2(pos+Vector2(10 if player.face>0 else -36,-7),Vector2(40,36))

func check_player_attack() -> void:
	var hit := attack_rect()
	for e in enemies:
		if e.dead or e.last_swing == player.swing_id: continue
		if hit.intersects(enemy_hurtbox(e)):
			e.last_swing = player.swing_id
			if e.kind=="boss" and e.state=="phase":
				burst(e.pos+e.size/2,7,"mist",55)
				events.append({"type":"sound","id":"bell"})
				continue
			var damage: int = 3 if player.combo==0 else 2
			e.hp -= damage
			e.flash = 0.12
			e.vel.x += player.face*(30 if e.kind=="boss" else 95)
			charge = minf(99,charge+8)
			hitstop = 0.052 if e.kind=="boss" else 0.045
			shake = 2.5
			burst(e.pos+e.size/2,16,"gold",145)
			events.append({"type":"sound","id":"hit"})
			if player.attack_dir==1:
				player.vel.y = -335
				player.air_dash = false
				player.air_jump = false
			elif not player.grounded:
				player.vel.x -= player.face*35
			if e.hp<=0: kill_enemy(e)

func kill_enemy(e: Dictionary) -> void:
	e.dead = true
	burst(e.pos+e.size/2,28,"teal",135)
	sparks += 3 if e.kind != "boss" else 50
	events.append({"type":"sound","id":"enemy_die"})
	if e.kind=="boss":
		flags.boss_defeated = true
		boss_started = false
		projectiles.clear()
		echoes.clear()
		shake = 9
		hitstop = 0.18
		charge = 99
		hp = max_hp
		events.append({"type":"boss_defeated","title":"钟声归于人间","text":"守钟人放下了最后一枚钥匙。东侧的门缓缓打开。"})
		events.append({"type":"save"})

func update_enemies(dt: float) -> void:
	for e in enemies:
		if e.dead: continue
		e.t += dt
		e.cooldown -= dt
		e.flash = maxf(0,e.flash-dt)
		e.contact_cd = maxf(0,e.contact_cd-dt)
		var delta_to_player: Vector2 = player.pos+PLAYER_SIZE/2-(e.pos+e.size/2)
		var distance: float = delta_to_player.length()
		if e.kind=="boss":
			update_boss(e,dt,delta_to_player)
		elif e.kind=="moth":
			update_moth(e,dt,delta_to_player)
		else:
			if e.state=="patrol":
				if e.pos.x<e.lo: e.face = 1
				if e.pos.x+e.size.x>e.hi: e.face = -1
				e.vel.x = move_toward(e.vel.x,e.face*(27 if e.kind=="crab" else 34),dt*120)
				if distance<190 and absf(delta_to_player.y)<55 and e.cooldown<=0:
					e.state="windup"
					e.t=0
					e.face=1 if delta_to_player.x>0 else -1
			elif e.state=="windup":
				e.vel.x=move_toward(e.vel.x,0,dt*700)
				var windup: float = 0.62 if e.kind=="warden" else 0.55
				if e.t>=windup:
					e.state="attack"
					e.t=0
					e.vel.x=e.face*(225 if e.kind=="warden" else 150)
					if e.kind=="eel": e.vel.y=-275
					events.append({"type":"sound","id":"enemy_attack"})
			elif e.state=="attack":
				if e.kind=="warden" and e.t<0.25:
					var spear := Rect2(e.pos+Vector2(14 if e.face>0 else -34,5),Vector2(42,18))
					if spear.intersects(Rect2(player.pos,PLAYER_SIZE)): damage_player(1,e.pos+e.size/2,false,"spear")
				if e.t>0.30:
					e.state="recover"
					e.t=0
			elif e.state=="recover":
				e.vel.x=move_toward(e.vel.x,0,dt*700)
				if e.t>0.55:
					e.state="patrol"
					e.cooldown=0.7
			e.vel.y=minf(e.vel.y+GRAVITY*dt,600)
			var result := move_body(e.pos,e.vel,e.size,dt)
			e.pos=result.pos
			e.vel=result.vel
			e.grounded=result.grounded
			if result.wall and e.state=="patrol": e.face *= -1
			# Ground enemies turn before a platform edge instead of walking blindly into water.
			if e.grounded and e.state=="patrol":
				var ahead: Vector2 = e.pos+Vector2(e.size.x+5 if e.face>0 else -5,e.size.y+4)
				var has_floor := false
				for platform in room.platforms:
					if platform.rect.has_point(ahead): has_floor=true
				if not has_floor: e.face *= -1
		if e.pos.y>room.size.y+60:
			e.pos=e.home
			e.vel=Vector2.ZERO
		if not e.dead and not (e.kind=="boss" and e.state=="phase") and enemy_hurtbox(e).grow(-2).intersects(Rect2(player.pos+Vector2(2,3),PLAYER_SIZE-Vector2(4,4))):
			damage_player(1,e.pos+e.size/2,false,"boss_contact" if e.kind=="boss" else "contact")

func enemy_hurtbox(e: Dictionary) -> Rect2:
	if e.kind=="boss":
		if e.state in ["windup","recover"]: return Rect2(e.pos+Vector2(0,22),Vector2(49,46))
		if e.state=="attack" and e.get("pattern",0)==1: return Rect2(e.pos+Vector2(0,15),Vector2(49,53))
	return Rect2(e.pos,e.size)

func update_moth(e: Dictionary, dt: float, target: Vector2) -> void:
	e.face=1 if target.x>0 else -1
	e.pos.y=e.home.y+sin(timer*2.2+e.home.x)*18
	if e.state=="windup":
		if e.t>0.55:
			var direction: Vector2 = (player.pos+Vector2(7,9)-(e.pos+e.size/2)).normalized()
			projectiles.append({"pos":e.pos+e.size/2,"vel":direction*114,"life":4.0,"size":5.0,"kind":"ember"})
			e.state="patrol"
			e.cooldown=2.3
			e.t=0
	else:
		e.pos.x=e.home.x+sin(timer*0.55+e.home.y)*36
		if target.length()<310 and e.cooldown<=0:
			e.state="windup"
			e.t=0

func update_boss(e: Dictionary, dt: float, target: Vector2) -> void:
	if not boss_started:
		if player.pos.x>150:
			boss_started=true
			e.cooldown=1.2
			events.append({"type":"boss_intro","title":"守钟人","subtitle":"THE LAST BELLKEEPER"})
		return
	var phase: int = 2 if e.hp <= e.max_hp*0.48 else 1
	# Finish the promised attack and recovery before the phase changes.
	if phase>e.phase and e.state=="patrol":
		e.phase=phase
		e.state="phase"
		e.pattern=2 # The new phase opens with a leap/slam, not another interrupted charge.
		projectiles.clear()
		echoes.clear()
		e.t=0
		e.vel=Vector2.ZERO
		shake=5
		burst(e.pos+e.size/2,40,"gold",190)
		events.append({"type":"toast","title":"钟声开始断裂。","text":"他不再等待回应。"})
	if e.state=="phase":
		if e.t>1.2:
			e.state="patrol"
			e.cooldown=0.2
	elif e.state=="patrol":
		e.face=1 if target.x>0 else -1
		e.vel.x=move_toward(e.vel.x,e.face*34,dt*140)
		if e.cooldown<=0:
			e.pattern=(int(e.pattern)+1)%3
			e.state="windup"
			e.t=0
			e.vel.x=0
			events.append({"type":"sound","id":"boss_windup"})
	elif e.state=="windup":
		e.vel.x=0
		var windup: float = 0.85 if e.phase==1 else 0.64
		if e.t>windup:
			e.state="attack"
			e.t=0
			if e.pattern==0:
				e.vel.y=-410
				e.vel.x=clampf(target.x*1.3,-210,210)
			elif e.pattern==1:
				e.vel.x=e.face*(305 if e.phase==1 else 370)
			else:
				for i in range(7 if e.phase==2 else 5):
					var a := -PI+float(i)*PI/(6 if e.phase==2 else 4)
					projectiles.append({"pos":e.pos+Vector2(24,24),"vel":Vector2(cos(a),sin(a))*135,"life":4.0,"size":5.0,"kind":"shard"})
				events.append({"type":"sound","id":"bell"})
	elif e.state=="attack":
		if e.pattern==0:
			if e.t>0.25 and e.grounded:
				shake=7
				for dir in [-1,1]: projectiles.append({"pos":e.pos+Vector2(25,61),"vel":Vector2(dir*175,0),"life":2.4,"size":10.0,"kind":"wave"})
				burst(e.pos+Vector2(24,68),35,"gold",170)
				e.state="recover"
				e.t=0
				events.append({"type":"sound","id":"slam"})
		elif e.pattern==1:
			var strike:=Rect2(e.pos+Vector2(34 if e.face>0 else -49,25),Vector2(64,22))
			if strike.intersects(Rect2(player.pos,PLAYER_SIZE)): damage_player(1,e.pos+Vector2(24,35),false,"boss_charge")
			if e.t>0.55 or e.pos.x<110 or e.pos.x>970:
				if e.phase==2:
					echoes.append({"pos":e.pos+Vector2(24,61),"wait":.58,"total":.58,"dir":-e.face})
					events.append({"type":"sound","id":"boss_windup"})
				e.state="recover"
				e.t=0
		elif e.t>0.40:
			e.state="recover"
			e.t=0
	elif e.state=="recover":
		e.vel.x=move_toward(e.vel.x,0,dt*800)
		if e.t>(0.95 if e.phase==1 else 0.68):
			e.state="patrol"
			e.cooldown=0.35
	e.vel.y=minf(e.vel.y+GRAVITY*dt,650)
	var result := move_body(e.pos,e.vel,e.size,dt)
	e.pos=result.pos
	e.vel=result.vel
	e.grounded=result.grounded
	e.pos.x=clampf(e.pos.x,88,988)

func update_echoes(dt: float) -> void:
	for i in range(echoes.size()-1,-1,-1):
		var echo:Dictionary=echoes[i]
		echo.wait-=dt
		if echo.wait<=0:
			projectiles.append({"pos":echo.pos,"vel":Vector2(echo.dir*160,0),"life":2.6,"size":9.,"kind":"wave"})
			burst(echo.pos,12,"gold",75)
			events.append({"type":"sound","id":"bell"})
			echoes.remove_at(i)

func update_projectiles(dt: float) -> void:
	for i in range(projectiles.size()-1,-1,-1):
		var q: Dictionary = projectiles[i]
		q.pos += q.vel*dt
		q.life -= dt
		if q.kind=="shard": q.vel.y += 110*dt
		var radius: float = q.size
		var rect := Rect2(q.pos-Vector2(radius,radius),Vector2(radius*2,radius*2))
		if rect.intersects(Rect2(player.pos+Vector2(2,3),PLAYER_SIZE-Vector2(4,4))):
			damage_player(1,q.pos,false,"wave" if q.kind=="wave" else "projectile")
			q.life=0
		if player.attack>0.12 and player.attack<0.25 and attack_rect().intersects(rect) and q.kind!="wave":
			q.life=0
			burst(q.pos,8,"gold",70)
			charge=minf(99,charge+3)
		if q.kind!="wave":
			for platform in room.platforms:
				if rect.intersects(platform.rect):
					q.life=0
					burst(q.pos,4,"mist",30)
					break
		if q.life<=0 or q.pos.y>room.size.y+40: projectiles.remove_at(i)

func damage_player(amount: int, from: Vector2, force: bool = false, reason: String = "contact") -> void:
	if player.dead or (player.invuln>0 and not force): return
	if assisted and not force and rng.randf()<0.35: return
	hp-=amount
	player.last_hit=reason
	player.invuln=1.15
	player.hurt=0.24
	player.dash=0
	player.attack=0
	player.heal=0
	player.vel=Vector2(180 if player.pos.x>from.x else -180,-180)
	shake=5
	hitstop=0.06
	burst(player.pos+Vector2(7,12),18,"copper",130)
	events.append({"type":"sound","id":"hurt"})
	if hp<=0:
		player.dead=true
		death_time=1.35
		total_deaths+=1
		burst(player.pos+Vector2(7,10),38,"gold",155)
		events.append({"type":"death"})

func death_hint() -> String:
	match player.get("last_hit","contact"):
		"boss_charge":return "金色横线预示冲撞。看清起手，再跳过他。"
		"wave":return "波纹贴地而行。跃过回声，别急着落地。"
		"projectile":return "迎着碎光挥刃，可以打散飞来的碎片。"
		"boss_contact":return "靠近刀尖的距离就够了。等他收势，再还击。"
		"fall":return "先找明亮的落脚边缘。灯座会记住你的归路。"
	return "观察起手，留出退路。命中积蓄的灯芯可以疗愈。"

func fall_recover() -> void:
	damage_player(1,player.pos+Vector2(0,10),true,"fall")
	if not player.dead:
		player.pos=player.safe_pos
		player.vel=Vector2.ZERO
		player.invuln=1.2
		player.dash=0
		player.air_dash=false
		player.air_jump=false

func respawn() -> void:
	var retry_hint:=death_hint()
	hp=max_hp
	charge=maxf(charge,33)
	make_player(checkpoint.pos)
	enter_room(checkpoint.room,checkpoint.pos)
	events.append({"type":"respawn","hint":retry_hint})

func beacon_count() -> int:
	var count:=0
	for k in ["orchard_beacon","archive_beacon","gallery_beacon"]:
		if flags.get(k,false): count+=1
	return count

func can_use_door(d: Dictionary) -> bool:
	match d.get("gate",""):
		"": return true
		"double_jump": return flags.get("double_jump",false)
		"shortcut": return flags.get("shortcut",false)
		"beacons": return beacon_count()>=3
		"boss_defeated": return flags.get("boss_defeated",false)
		"boss_exit": return not boss_started or flags.get("boss_defeated",false)
	return false # Unknown ability/gate IDs must never silently open a route.

func nearest_interaction() -> Dictionary:
	var center: Vector2 = player.pos+Vector2(7,24)
	var best: Dictionary = {}
	var distance:=54.0
	for obj in room.items:
		if obj.kind in ["ability","health","memory","relic"] and flags.get(obj.id,false): continue
		var delta: float = center.distance_to(obj.pos-Vector2(0,10))
		if delta<distance:
			distance=delta
			best={"category":"item","data":obj}
	for d in room.doors:
		var delta: float = center.distance_to(d.pos-Vector2(0,14))
		if delta<distance:
			distance=delta
			best={"category":"door","data":d}
	return best

func interact() -> void:
	var nearest:=nearest_interaction()
	if nearest.is_empty(): return
	var o: Dictionary = nearest.data
	if nearest.category=="door":
		if can_use_door(o):
			enter_room(o.target,o.spawn)
			if o.id=="gallery_nave": flags.shortcut=true
			events.append({"type":"save"})
		else:
			var message := "这条路还没有被点亮。"
			if o.gate=="beacons": message="三座信号炉已点亮 %d / 3。"%beacon_count()
			elif o.gate=="shortcut": message="升降机停在上层。试着从另一侧唤醒它。"
			elif o.gate=="double_jump": message="还需要一种能在空中再次跃起的力量。"
			elif o.gate=="boss_exit": message="钟门已落下。守钟人正在等待你的回应。"
			events.append({"type":"toast","title":"道路未通","text":message})
		return
	match o.kind:
		"checkpoint":
			checkpoint={"room":room_id,"pos":o.pos-Vector2(7,24)}
			hp=max_hp
			charge=99
			burst(o.pos-Vector2(0,20),28,"gold",95)
			events.append({"type":"rest","title":o.label,"text":"心火已恢复 · 旅途已记录"})
			events.append({"type":"save"})
		"beacon":
			if not flags.get(o.id,false):
				flags[o.id]=true
				burst(o.pos-Vector2(0,36),42,"gold",145)
				shake=3
				events.append({"type":"toast","title":o.label+" 已点亮","text":"归航信号 %d / 3"%beacon_count()})
				events.append({"type":"sound","id":"beacon"})
				events.append({"type":"save"})
			else: events.append({"type":"toast","title":o.label,"text":"火光仍在回应。"})
		"ability","health","memory":
			flags[o.id]=true
			if o.kind=="health":
				max_hp+=1
				hp=max_hp
			burst(o.pos-Vector2(0,12),26,"teal",110)
			events.append({"type":"dialog","title":o.label,"text":o.text})
			events.append({"type":"sound","id":"relic"})
			events.append({"type":"save"})
		"relic":
			flags[o.id]=true
			sparks+=10
			charge=minf(99,charge+25)
			burst(o.pos-Vector2(0,15),20,"gold",100)
			events.append({"type":"toast","title":"铜羽碎片","text":"余烬 +10 · 灯芯能量恢复"})
			events.append({"type":"sound","id":"relic"})
			events.append({"type":"save"})
		"shortcut":
			flags.shortcut=true
			events.append({"type":"dialog","title":o.label,"text":o.text})
			events.append({"type":"save"})
		"ending":
			victory=true
			flags.chapter_one=true
			events.append({"type":"ending","title":o.label,"text":o.text})
			events.append({"type":"save"})
		"npc":
			if o.id!="mara":
				events.append({"type":"dialog","title":o.label,"text":o.text})
				return
			var memories:=0
			for key in ["gate_memory","well_memory","roost_memory"]:
				if flags.get(key,false): memories+=1
			var text: String = o.text
			if memories>=3:
				text="我记得这些笔迹。园丁、守闸人，还有那个总来借灯的孩子。\n谢谢你把他们的名字带回来。\n这枚灯芯，原本是为最后一次告别留下的。现在，用它迎接明天吧。"
				if not flags.get("mara_gift",false):
					flags.mara_gift=true
					max_hp+=1
					hp=max_hp
					text+="\n\n心火上限增加。"
				events.append({"type":"save"})
			elif flags.get("boss_defeated",false): text="我听见了。那不再是守钟人的钟声。\n是我们自己的。"
			events.append({"type":"dialog","title":o.label,"text":text})
		_:
			events.append({"type":"dialog","title":o.label,"text":o.text})

func serialize() -> Dictionary:
	return {"version":SAVE_VERSION,"flags":flags.duplicate(true),"visited":visited.duplicate(),"checkpoint":{"room":checkpoint.room,"x":checkpoint.pos.x,"y":checkpoint.pos.y},"max_hp":max_hp,"sparks":sparks,"play_seconds":play_seconds,"deaths":total_deaths,"assisted":assisted}

func restore(data: Dictionary) -> bool:
	if typeof(data.get("version",0)) not in [TYPE_INT,TYPE_FLOAT] or float(data.get("version",0))!=SAVE_VERSION:return false
	if not data.get("checkpoint",{}) is Dictionary:return false
	var cp: Dictionary = data.get("checkpoint",{})
	if not cp.get("room","") is String:return false
	for axis in ["x","y"]:
		if typeof(cp.get(axis,0)) not in [TYPE_INT,TYPE_FLOAT]:return false
	if not world.has(cp.get("room","")): return false
	var x: float = float(cp.get("x",0))
	var y: float = float(cp.get("y",0))
	if not is_finite(x) or not is_finite(y): return false
	if not data.get("flags",{}) is Dictionary or not data.get("visited",[]) is Array: return false
	if x<0 or x>world[cp.room].size.x-PLAYER_SIZE.x or y<0 or y>world[cp.room].size.y: return false
	for key in data.get("flags",{}):
		if (not key is String and not key is StringName) or not data.flags[key] is bool: return false
	for field in ["max_hp","sparks","play_seconds","deaths"]:
		if data.has(field) and (typeof(data[field]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data[field]))):return false
	if data.has("assisted") and not data.assisted is bool:return false
	flags=data.get("flags",{}).duplicate(true)
	visited=[]
	for id in data.get("visited",[]):
		if id is String and world.has(id) and not visited.has(id): visited.append(id)
	max_hp=clampi(int(data.get("max_hp",5)),5,7)
	hp=max_hp
	sparks=maxi(0,int(data.get("sparks",0)))
	play_seconds=maxf(0,float(data.get("play_seconds",0)))
	total_deaths=maxi(0,int(data.get("deaths",0)))
	assisted=bool(data.get("assisted",false))
	checkpoint={"room":cp.room,"pos":Vector2(x,y)}
	charge=99
	make_player(checkpoint.pos)
	enter_room(checkpoint.room,checkpoint.pos)
	return true
