extends SceneTree
const Core=preload("res://scripts/ledger_core.gd")
var passed:=0
var failed:=0
func check(ok:bool,label:String) -> void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;print("FAIL ",label)
func _initialize() -> void:
	var c=Core.new();c.flags.rf_breaker=true;c.enter_room("gate",Vector2(900,300));c.player.invuln=0
	var e:Dictionary=c.enemies[0]
	c.step(1./60,{"down":true,"dash_press":true})
	for n in range(25):c.step(1./60,{});c.events.clear();c.particles.clear()
	check(e.dead and c.hp==5,"breaker also strikes a backtracked Gatewater enemy before contact hurts")
	c=Core.new();c.flags.rf_breaker=true;c.enter_room("nave",Vector2(100,100));c.enemies=c.enemies.filter(func(a):return a.kind=="warden");e=c.enemies[0]
	c.player.pos=e.pos+Vector2(4,-64);c.player.invuln=0;c.player.grounded=false
	c.step(1./60,{"down":true,"dash_press":true})
	for n in range(20):c.step(1./60,{});c.events.clear();c.particles.clear()
	check(e.hp==3 and c.hp==5,"armored enemy takes one committed breaker strike with local contact grace")
	var remaining:int=e.hp;c.breaker_strike(Rect2(e.pos-Vector2(0,36),Vector2(14,38)),Rect2(e.pos-Vector2(0,34),Vector2(14,38)))
	check(e.hp==remaining,"one breaker activation cannot repeatedly damage the same enemy")
	c.player.invuln=0;c.damage_player(1,e.pos+e.size*.5,false,"projectile")
	check(c.hp==4,"local contact grace does not block projectiles")
	c.player.invuln=0;c.damage_player(1,e.pos+e.size*.5,false,"spear")
	check(c.hp==3,"local contact grace does not block a telegraphed spear attack")
	c=Core.new();c.flags.rf_breaker=true;c.enter_room("hall",Vector2(400,300));c.player.grounded=false;c.hitstop=.05
	c.step(1./60,{"down":true,"dash_press":true})
	for n in range(12):c.step(1./60,{})
	check(c.breaker.active_id==1 and c.player.dash==0 and c.player.dash_buffer==0,"legal hitstop intent becomes a breaker, never a horizontal dash")
	c.player.dash_cd=.3
	check(not c.breaker.request({"down":true,"dash_press":true},c.player,true,0),"breaker respects the shared dash cooldown")
	c=Core.new();c.flags.rf_breaker=true;c.enter_room("rf_workshop",Vector2(876,265));c.player.invuln=0;c.enemies[0].state="recover";c.enemies[0].t=0.
	c.step(1./60,{"attack_press":true})
	for n in range(10):
		if c.hitstop>0:break
		c.step(1./60,{})
	check(c.hitstop>0 and c.player.attack>.12,"regression reproduces a genuine airborne sword-hit freeze")
	c.step(1./60,{"down":true,"dash_press":true});var horizontal:=false;var unexpected_protection:=false
	for n in range(30):
		c.step(1./60,{})
		if c.player.dash>0:horizontal=true
		if c.player.invuln>0:unexpected_protection=true
	check(c.breaker.active_id==0 and c.player.grounded and not horizontal and not unexpected_protection,"low sword-hit intent cancels on landing without horizontal dash or protection")
	c=Core.new();c.flags.rf_breaker=true;c.enter_room("rf_workshop",Vector2(876,265));c.player.invuln=0;c.player.vel.y=-180;c.enemies[0].state="recover";c.enemies[0].t=0.
	c.step(1./60,{"attack_press":true})
	for n in range(10):
		if c.hitstop>0:break
		c.step(1./60,{})
	check(c.hitstop>0,"rising airborne attack also reproduces genuine sword-hit freeze")
	c.step(1./60,{"down":true,"dash_press":true});horizontal=false;unexpected_protection=false
	for n in range(30):
		c.step(1./60,{})
		if c.player.dash>0:horizontal=true
		if c.player.invuln>0:unexpected_protection=true
	check(c.breaker.active_id==1 and not horizontal and not unexpected_protection,"still-airborne sword-hit intent reaches recovery and starts the intended breaker")
	c=Core.new();c.flags.rf_breaker=true;c.enter_room("hall",Vector2(400,300));c.player.invuln=0;c.player.hurt=.25;c.hitstop=.05
	c.step(1./60,{"down":true,"dash_press":true})
	for n in range(30):c.step(1./60,{})
	check(c.breaker.active_id==0 and c.player.dash==0 and not c.player.air_dash and c.breaker_buffer==0,"hurt input is consumed with no delayed action or air-dash expenditure")
	c=Core.new();c.flags.rf_breaker=true;c.enter_room("hall",Vector2(400,300));c.player.attack=.31;c.hitstop=.05;c.player.invuln=0
	c.step(1./60,{"down":true,"dash_press":true})
	for n in range(30):c.step(1./60,{})
	check(c.breaker.active_id==0 and c.breaker_buffer==0 and c.player.dash==0,"intent expires rather than canceling a long locked attack")
	c=Core.new();c.flags.rf_breaker=true;c.enter_room("hall",Vector2(400,367));c.player.vel.y=120;c.player.attack=.2;c.hitstop=.05;c.player.invuln=0
	c.step(1./60,{"down":true,"dash_press":true})
	for n in range(20):c.step(1./60,{})
	check(c.breaker.active_id==0 and c.breaker_buffer==0 and c.player.dash==0,"landing cancels an unconsumed airborne breaker intent")
	c=Core.new();c.flags.rf_breaker=true;c.enter_room("hall",Vector2(400,300));c.hitstop=.05;c.step(1./60,{"down":true,"dash_press":true});c.enter_room("gate",Vector2(100,368))
	check(c.breaker_buffer==0,"room change clears pending breaker intent")
	print("BREAKER_COMBAT_RESULT ",passed," passed; ",failed," failed");quit(1 if failed else 0)
