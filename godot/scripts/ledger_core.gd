extends "res://scripts/root_core.gd"
const FOLDHAMMER=preload("res://scripts/foldhammer_ai.gd")
const LEDGER=preload("res://scripts/ledger_room.gd")
func _init() -> void:
	super._init()
	world.merge(LEDGER.rooms(),false)
	var workshop_door:Dictionary=WORLD.door("workshop_ledger",1220,310,"rf_ledger",Vector2(70,286));workshop_door.label="前往冷名廊"
	world.rf_workshop.doors.append(workshop_door)
	world.rf_workshop.items=world.rf_workshop.items.filter(func(item):return item.id!="rf_boundary")
	world.archive.platforms.append(WORLD.p(648,386,136,14,"metal"))
	world.archive.platforms.append(WORLD.p(632,318,160,12,"metal"))
	var hatch:Dictionary=WORLD.door("archive_ledger",717,386,"rf_ledger",Vector2(71,552),"rf_archive_hatch");hatch.label="冷名廊检修口"
	world.archive.doors.append(hatch)
func can_use_door(d:Dictionary) -> bool:
	if d.get("gate","")=="rf_archive_hatch":return flags.get("rf_archive_hatch",false)
	return super.can_use_door(d)
func interact() -> void:
	var nearest:Dictionary=nearest_interaction()
	if nearest.is_empty():return
	var object:Dictionary=nearest.data
	if nearest.category=="door" and object.get("gate","")=="rf_archive_hatch" and not can_use_door(object):
		events.append({"type":"toast","title":"栓在另一侧","text":"冷铜管通向根火铸所。检修口得从里面打开。"});return
	if nearest.category=="item":
		if object.id=="rf_tilu":talk_tilu();return
		if object.id in ["rf_archive_hatch","rf_ledger_return"]:
			var fresh:bool=not flags.get(object.id,false);flags[object.id]=true
			room=ROUTES.materialize(world[room_id],flags)
			var text:String="内栓落下。名字终于有一条回到档案馆的路。" if object.id=="rf_archive_hatch" else "上方格栅打开。沿冷柜的隔板，可以回到缇芦身边。"
			events.append({"type":"toast","title":object.label,"text":text if fresh else "回程仍然畅通。"});events.append({"type":"save"});return
	super.interact()
func talk_tilu() -> void:
	var first:bool=not flags.get("rf_tilu_met",false)
	flags.rf_tilu_met=true
	var delivery:bool=flags.get("rf_delivery_record",false);var roots:bool=flags.get("rf_rootledger_read",false)
	var text:String="我先抄还能辨认的字。没有名字的那一行，先空着。"
	if delivery and roots:
		if not flags.get("rf_tilu_records_told",false):
			text="两处记的是同一批名字。我抄两份。\n你带回去的那条路，也该留一份。"
			flags.rf_tilu_delivery_told=true;flags.rf_tilu_roots_told=true;flags.rf_tilu_records_told=true
		else:text="这一份留在冷柜里。另一份，可以送回档案馆了。" if flags.get("rf_archive_hatch",false) else "这一份留在冷柜里。另一份，等那扇旧栓打开。"
	elif delivery:
		text="这张交货单先压在这里。\n右边冷柜里的字，还要逐个核对。" if flags.get("rf_tilu_delivery_told",false) else "交货单也把重量留空了……\n那一车，确实不能只记成薪料。\n右边冷柜里，还有没被铜牌带走的字。"
		flags.rf_tilu_delivery_told=true
	elif roots:
		text="年轮里的这一行，已经抄好了。\n还差工坊交货单的那一栏。" if flags.get("rf_tilu_roots_told",false) else "名字还留在年轮里。至少这一笔，没被烧掉。\n工坊的交货单上，会不会也留着它们？"
		flags.rf_tilu_roots_told=true
	if flags.get("rf_archive_hatch",false) and flags.get("rf_tilu_records_told",false):text+="\n旧栓通了。这次，名字可以先回家。"
	if first:text="我是缇芦。以前记重量，现在得先记人。\n\n"+text
	events.append({"type":"dialog","title":"记薪人 · 缇芦","text":text});events.append({"type":"save"})


func enter_room(id:String,at:Vector2) -> void:
	super.enter_room(id,at)
	for e in enemies:
		if e.kind=="rf_foldhammer":
			var feet:Vector2=e.pos+e.size*.5+Vector2(0,e.size.y*.5)
			e.size=Vector2(30,38);e.pos=feet-Vector2(15,38);e.home=e.pos;e.hp=5;e.max_hp=5
			e.breaker_protect=0.;e.last_breaker=-1;e.cooldown=.05;FOLDHAMMER.initialize(e)

func update_enemies(dt:float) -> void:
	var all_enemies:Array=enemies;var other:Array=[];var hammers:Array=[]
	for e in all_enemies:
		if e.kind=="rf_foldhammer":hammers.append(e)
		else:other.append(e)
	enemies=other;super.update_enemies(dt);enemies=all_enemies
	for e in hammers:
		if e.dead:continue
		e.flash=maxf(0,e.flash-dt);e.breaker_protect=maxf(0,e.breaker_protect-dt)
		var previous_state:String=e.state;var serial:int=e.attack_serial
		FOLDHAMMER.tick(e,dt,player.pos+PLAYER_SIZE*.5-(e.pos+e.size*.5))
		if e.state in ["windup","reprise"] and e.state!=previous_state:events.append({"type":"sound","id":"stamp_windup"})
		if e.attack_serial!=serial:
			events.append({"type":"sound","id":"stamp_hit"});burst(e.pos+Vector2(15+e.attack_face*30,38),9,"gold",65)
		e.vel.y=minf(e.vel.y+GRAVITY*dt,640)
		var moved:Dictionary=super.move_body(e.pos,e.vel,e.size,dt);e.pos=moved.pos;e.vel=moved.vel;e.grounded=moved.grounded
		if e.grounded and e.state=="patrol":
			var probe:Vector2=e.pos+Vector2(e.size.x+5 if e.face>0 else -5,e.size.y+3);var floor_exists:=false
			for platform in room.platforms:
				if platform.rect.has_point(probe):floor_exists=true
			if not floor_exists:e.face*=-1
		var strike:Rect2=FOLDHAMMER.strike_rect(e)
		if strike.has_area() and strike.intersects(Rect2(player.pos+Vector2(2,3),PLAYER_SIZE-Vector2(4,4))):damage_player(1,strike.get_center(),false,"foldhammer_stamp")
		if e.breaker_protect<=0 and Rect2(e.pos+Vector2(3,2),e.size-Vector2(6,3)).intersects(Rect2(player.pos+Vector2(2,3),PLAYER_SIZE-Vector2(4,4))):damage_player(1,e.pos+e.size*.5,false,"contact")

func death_hint() -> String:
	if player.get("last_hit","")=="foldhammer_stamp":return "双凿印意味着还会再落一次。等重锤停下，再靠近它。"
	return super.death_hint()
