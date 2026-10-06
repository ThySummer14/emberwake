extends Node2D
const CORE=preload("res://scripts/ledger_core.gd")
const AUDIO=preload("res://scripts/audio.gd")
const SAVE="user://emberwake_save.json"
const W=640.0
const H=360.0
var core: RefCounted
var audio: Node
var textures: Dictionary={}
var props: Dictionary={}
var font: Font
var title_font: Font
var camera:=Vector2.ZERO
var tick:=0.0
var accumulator:=0.0
var mode: String="title"
var selected:=0
var dialog: Dictionary={}
var dialog_return: String="play"
var toast: Dictionary={}
var toast_time:=0.0
var room_title:=0.0
var boss_intro:=0.0
var fade:=1.0
var gamepad: int=-1
var menu_axis_held:=false
var pending: Dictionary={}
var save_exists:=false
var journey_active:=false
var save_error: String=""
var reduced_motion:=false
var show_fps:=false
var confirm_new:=false
var screenshot_requested:=false
var colors: Dictionary={"gold":Color("efbd70"),"teal":Color("7ad0c6"),"mist":Color("8ea7b1"),"copper":Color("bd6852")}

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	for key in ["tiles","props","city"]:
		textures[key]=load_pixel_texture("res://assets/"+("props_refined" if key=="props" else key)+".png")
	textures["bellkeeper_keyposes"]=load_pixel_texture("res://assets/bellkeeper_keyposes.png")
	textures["player_keyposes"]=load_pixel_texture("res://assets/player_keyposes.png")
	textures["enemy_keyposes"]=load_pixel_texture("res://assets/enemy_keyposes.png")
	for key in ["rootfoundry_background","rootfoundry_modules","breaker_poses","carrier_poses","tilu_modular","ledger_background","foldhammer_poses"]:
		textures[key]=load_pixel_texture("res://assets/"+key+".png")
	props=JSON.parse_string(FileAccess.get_file_as_string("res://assets/props.json"))
	font=load_game_font("res://assets/ui_font.otf")
	title_font=load_game_font("res://assets/title_font.ttf")
	core=CORE.new()
	audio=AUDIO.new()
	add_child(audio)
	setup_input()
	save_exists=FileAccess.file_exists(SAVE)
	camera=Vector2(0,120)
	DisplayServer.window_set_title("EMBERWAKE · 余烬回潮")
	if "--smoke-test" in OS.get_cmdline_user_args():
		print("EMBERWAKE_NATIVE_BOOT_OK; rooms=",core.world.size()," textures=",textures.size())
		get_tree().quit(0)
	if "--autoplay-test" in OS.get_cmdline_user_args():
		mode="play"
		core.assisted=true

# Runtime loading keeps the tiny native game independent of an editor import cache.
# Godot still owns image decoding, texture creation, fonts, rendering, audio and input.
func load_pixel_texture(path: String) -> ImageTexture:
	var image:=Image.new()
	var err:=image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	if err!=OK:
		push_error("Unable to load game image: "+path)
		image=Image.create(1,1,false,Image.FORMAT_RGBA8)
	var texture:=ImageTexture.create_from_image(image)
	texture.set_meta("source_path",path)
	return texture

func load_game_font(path: String) -> FontFile:
	var result:=FontFile.new()
	result.data=FileAccess.get_file_as_bytes(path)
	result.set_meta("source_path",path)
	return result

func setup_input() -> void:
	var actions: Dictionary={"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"up":[KEY_W,KEY_UP],"down":[KEY_S,KEY_DOWN],"jump":[KEY_SPACE],"attack":[KEY_J,KEY_Z],"dash":[KEY_K,KEY_SHIFT,KEY_X],"interact":[KEY_E,KEY_ENTER],"heal":[KEY_Q,KEY_C],"map":[KEY_M,KEY_TAB],"pause":[KEY_ESCAPE],"mute":[KEY_F8],"fullscreen":[KEY_F11]}
	for name in actions:
		if not InputMap.has_action(name): InputMap.add_action(name)
		for code in actions[name]:
			var ev:=InputEventKey.new()
			ev.physical_keycode=code
			InputMap.action_add_event(name,ev)
	var buttons: Dictionary={"jump":JOY_BUTTON_A,"attack":JOY_BUTTON_X,"dash":JOY_BUTTON_B,"interact":JOY_BUTTON_RIGHT_SHOULDER,"heal":JOY_BUTTON_Y,"map":JOY_BUTTON_BACK,"pause":JOY_BUTTON_START,"up":JOY_BUTTON_DPAD_UP,"down":JOY_BUTTON_DPAD_DOWN,"left":JOY_BUTTON_DPAD_LEFT,"right":JOY_BUTTON_DPAD_RIGHT}
	for name in buttons:
		var ev:=InputEventJoypadButton.new()
		ev.button_index=buttons[name]
		InputMap.action_add_event(name,ev)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and event.axis==JOY_AXIS_LEFT_Y:
		if absf(event.axis_value)<.25:menu_axis_held=false
		elif absf(event.axis_value)>.55 and not menu_axis_held and mode in ["title","pause"]:
			menu_axis_held=true
			selected=posmod(selected+(1 if event.axis_value>0 else -1),menu_options().size())
			return
	if event.is_action_pressed("fullscreen"):
		var full:=DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event.is_action_pressed("mute"): audio.toggle()
	if event is InputEventKey and event.echo: return
	if mode=="play":
		for action in ["jump","attack","dash","interact"]:
			if event.is_action_pressed(action): pending[action+"_press"]=true
		if event.is_action_released("jump"): pending.jump_release=true
		if event.is_action_pressed("map"):
			mode="map"
			pending.clear()
		elif event.is_action_pressed("pause"):
			mode="pause"
			selected=0
			write_save()
	elif mode=="map":
		if event.is_action_pressed("map") or event.is_action_pressed("pause") or event.is_action_pressed("interact"): mode="play"
	elif mode in ["dialog","ending"]:
		if event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("pause"):
			mode=dialog_return
			pending.clear()
	elif mode in ["title","pause"]:
		if event.is_action_pressed("down"): selected=(selected+1)%menu_options().size()
		if event.is_action_pressed("up"): selected=posmod(selected-1,menu_options().size())
		if event.is_action_pressed("jump") or event.is_action_pressed("interact"): choose_menu(selected)
		if event.is_action_pressed("pause") and mode=="pause": mode="play"
	if event is InputEventMouseMotion and mode in ["title","pause"]:
		for i in range(menu_options().size()):
			if menu_rect(i).has_point(event.position): selected=i
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and mode in ["title","pause"]:
		for i in range(menu_options().size()):
			if menu_rect(i).has_point(event.position):
				choose_menu(i)
				return

func menu_options() -> Array:
	if mode=="pause": return ["继续旅途","操作与旅途提示","辅助模式："+("开" if core.assisted else "关"),"减少震动："+("开" if reduced_motion else "关"),"返回标题"]
	if confirm_new: return ["确认重新出发","保留现有旅途"]
	return (["继续旅途"] if save_exists else [])+["点亮第一盏灯","操作与旅途提示","声音："+("开" if audio.enabled else "关")]

func menu_rect(i: int) -> Rect2:
	return Rect2(218,174+i*31,204,27) if mode=="title" else Rect2(204,128+i*32,232,28)

func choose_menu(i: int) -> void:
	if mode!="title":confirm_new=false
	audio.start()
	var option: String=menu_options()[i]
	if confirm_new and mode=="title":
		confirm_new=false
		selected=0
		if i==0: start_game(false)
		return
	if option=="继续旅途":
		if mode=="pause": mode="play"
		else: start_game(true)
	elif option=="点亮第一盏灯":
		if save_exists: confirm_new=true;selected=0
		else: start_game(false)
	elif option=="操作与旅途提示":
		dialog_return=mode
		dialog={"title":"带一盏灯，走自己的路","text":"移动 A/D 或方向键  ·  跳跃 空格  ·  挥刃 J/Z\n冲刺 K/Shift/X  ·  交互 E/Enter  ·  蓄力疗愈 按住 Q/C\n地图 M/Tab  ·  暂停 Esc  ·  全屏 F11  ·  静音 F8\n\n手柄：左摇杆移动，A 跳跃，X 挥刃，B 冲刺，Y 疗愈，RB 交互。\n方向上/下 + 挥刃可改变攻击方向；下劈命中可反弹。\n灯座会恢复心火并记录进度。坠落只损失一格心火。\n三座信号炉位于铜色果园、浸水档案馆和断索回廊。\n落砧环：空中 下 + 冲刺。下 + 挥刃仍是下劈反弹。"}
		mode="dialog"
	elif option.begins_with("声音"): audio.toggle()
	elif option.begins_with("辅助模式"):
		core.assisted=not core.assisted
		write_save()
	elif option.begins_with("减少震动"): reduced_motion=not reduced_motion
	elif option=="返回标题":
		write_save()
		journey_active=false
		confirm_new=false
		mode="title"
		selected=0

func start_game(load_saved: bool) -> void:
	if load_saved:
		var parser:=JSON.new()
		var error:=parser.parse(FileAccess.get_file_as_string(SAVE))
		var data=parser.data if error==OK else null
		if not data is Dictionary or not core.restore(data):
			toast={"title":"记录无法读取","text":"原记录保留。你可以开始一段新旅途。"}
			toast_time=4
			return
		var settings=data.get("settings",{})
		if settings is Dictionary:
			reduced_motion=bool(settings.get("reduced_motion",false))
			if audio.enabled!=bool(settings.get("sound",true)):audio.toggle()
	else:
		core=CORE.new()
		journey_active=true
		write_save()
	journey_active=true
	confirm_new=false
	mode="play"
	camera=core.player.pos-Vector2(230,210)
	camera.x=clampf(camera.x,0,maxf(0,core.room.size.x-W))
	camera.y=clampf(camera.y,0,maxf(0,core.room.size.y-H))
	pending.clear()
	fade=1
	audio.start()

func write_save() -> void:
	if not journey_active:return
	var file:=FileAccess.open(SAVE+".tmp",FileAccess.WRITE)
	if file==null:
		save_error="记录失败：无法写入本机存档目录"
		return
	var data:Dictionary=core.serialize()
	data.settings={"sound":audio.enabled,"reduced_motion":reduced_motion}
	file.store_string(JSON.stringify(data))
	file.close()
	if FileAccess.file_exists(SAVE):
		DirAccess.copy_absolute(SAVE,SAVE+".backup")
	var err:=DirAccess.rename_absolute(SAVE+".tmp",SAVE)
	if err!=OK:
		save_error="记录失败：原存档仍然保留"
	else:
		save_exists=true
		save_error=""

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if core!=null and journey_active: write_save()
		get_tree().quit()
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and mode=="play":
		mode="pause"
		selected=0
		pending.clear()

func _process(delta: float) -> void:
	tick+=delta
	fade=maxf(0,fade-delta*1.8)
	toast_time=maxf(0,toast_time-delta)
	room_title=maxf(0,room_title-delta)
	boss_intro=maxf(0,boss_intro-delta)
	if mode=="play":
		var axis:=0.0
		var axis_y:=0.0
		var devices:=Input.get_connected_joypads()
		if not devices.is_empty():
			axis=Input.get_joy_axis(devices[0],JOY_AXIS_LEFT_X)
			axis_y=Input.get_joy_axis(devices[0],JOY_AXIS_LEFT_Y)
		var input: Dictionary={"left":Input.is_action_pressed("left") or axis<-.22,"right":Input.is_action_pressed("right") or axis>.22,"up":Input.is_action_pressed("up") or axis_y<-.4,"down":Input.is_action_pressed("down") or axis_y>.4,"heal":Input.is_action_pressed("heal")}
		for key in pending: input[key]=pending[key]
		accumulator+=minf(delta,0.08)
		var first:=true
		while accumulator>=1.0/60.0:
			if not first:
				for k in ["jump_press","attack_press","dash_press","interact_press","jump_release"]: input[k]=false
			core.step(1.0/60.0,input)
			accumulator-=1.0/60.0
			first=false
			consume_events()
			if mode!="play": accumulator=0;break
		if not first: pending.clear()
		update_camera(delta)
	queue_redraw()

func update_camera(delta:float) -> void:
	camera=camera.lerp(camera_target(),1-exp(-delta*5))
	if core.room_id in ["rf_workshop","rf_ledger"]:
		# Keep a readable floor margin during the fast boots-first descent.
		camera.y=maxf(camera.y,minf(core.room.size.y-H,core.player.pos.y+24-(H-44)))

func camera_target() -> Vector2:
	var target:Vector2=core.player.pos+Vector2(core.player.face*48-320,-212)
	# Keep the arena floor and ground telegraphs visible throughout a double jump.
	if core.room_id=="boss":target.y=core.room.size.y-H
	target.x=clampf(target.x,0,maxf(0,core.room.size.x-W))
	target.y=clampf(target.y,0,maxf(0,core.room.size.y-H))
	return target

func consume_events() -> void:
	for event in core.events:
		match event.type:
			"sound": audio.play(event.id)
			"room":
				room_title=3.3
				fade=0.65
				camera=core.player.pos-Vector2(320,210)
				camera.x=clampf(camera.x,0,maxf(0,core.room.size.x-W))
				camera.y=clampf(camera.y,0,maxf(0,core.room.size.y-H))
			"dialog","ending":
				dialog=event
				dialog_return="play"
				mode=event.type
			"toast","rest","boss_defeated":
				toast=event
				toast_time=4
				if event.type=="rest": audio.play("heal")
				elif event.type=="boss_defeated": audio.play("beacon")
			"respawn":
				toast={"title":"灯火未熄","text":event.get("hint","")}
				toast_time=4
			"boss_intro": boss_intro=1.8
			"save": write_save()
	core.events.clear()

func text_at(text: String, pos: Vector2, size: int=12, color: Color=Color("d8dfd8"), align: HorizontalAlignment=HORIZONTAL_ALIGNMENT_LEFT, width: float=-1, use_title: bool=false) -> void:
	draw_string(title_font if use_title else font,pos,text,align,width,size,color)

func centered(text: String,y: float,size: int=12,color: Color=Color("d8dfd8"),use_title: bool=false) -> void:
	text_at(text,Vector2(0,y),size,color,HORIZONTAL_ALIGNMENT_CENTER,W,use_title)

func _draw() -> void:
	if textures.is_empty() or core==null: return
	if mode=="title": draw_title();return
	draw_game()
	if mode=="map": draw_map()
	elif mode=="pause": draw_pause()
	elif mode in ["dialog","ending"]: draw_dialog()
	if fade>0: draw_rect(Rect2(0,0,W,H),Color(0.02,0.05,0.08,fade*.8))
	if save_error!="": text_at(save_error,Vector2(14,346),11,Color("e79577"))

func draw_title() -> void:
	draw_texture_rect(textures.city,Rect2(0,0,W,H),false)
	draw_rect(Rect2(0,0,W,H),Color(0.02,0.04,0.07,.38))
	for i in range(45):
		var x:=fmod(i*83.7+tick*2,640)
		var y:=fmod(i*39.7-tick*(8+i%3*3)+500,360)
		draw_rect(Rect2(x,y,1,2),Color(.98,.77,.38,.4+sin(tick+i)*.25))
	centered("EMBERWAKE",112,45,Color("e8d7ae"),true)
	centered("余 烬 回 潮",143,18,Color("b5d1cd"))
	draw_line(Vector2(238,158),Vector2(402,158),Color("6d786f"))
	for i in range(menu_options().size()): draw_menu_option(i,menu_options()[i])
	centered("潮门的回声",324,11,Color("98a9aa"))
	centered("第一章 · 潮门的回声  /  旅途在本机自动记录",343,10,Color("7d959b"))
	if confirm_new: centered("重新出发将替换当前旅途，上一份记录会保留备份。",296,10,Color("efbd70"))
	if toast_time>0: draw_toast()

func draw_menu_option(i: int, label: String) -> void:
	var r:=menu_rect(i)
	if selected==i:
		draw_rect(r,Color(.10,.18,.21,.85))
		draw_line(r.position+Vector2(16,26),r.end-Vector2(16,1),Color("a7865a"))
		draw_colored_polygon(PackedVector2Array([r.position+Vector2(5,13),r.position+Vector2(10,9),r.position+Vector2(10,17)]),Color("efbd70"))
	text_at(label,r.position+Vector2(0,18),13,Color("efdfbc") if selected==i else Color("9eb3b7"),HORIZONTAL_ALIGNMENT_CENTER,r.size.x)

func screen_pos(world_pos: Vector2) -> Vector2:
	return (world_pos-camera).round()

func glow(pos: Vector2,radius: float,color: Color,intensity: float=1) -> void:
	for i in range(7,0,-1):
		var r:=radius*i/7.0
		draw_circle(pos.round(),r,Color(color.r,color.g,color.b,(1-float(i)/8)*.025*intensity))

func draw_prop(name: String, pos: Vector2, scale_factor: float=1.0,tint: Color=Color.WHITE) -> void:
	var data: Array=props[name]
	var size:=Vector2(128,128)*scale_factor
	var dest:=Rect2(pos-Vector2(size.x/2,size.y),size)
	draw_texture_rect_region(textures.props,dest,Rect2(data[0],data[1],data[2],data[3]),tint)

func draw_game() -> void:
	if core.room_id=="rf_workshop":draw_rootfoundry();return
	if core.room_id=="rf_ledger":draw_ledger();return
	var palette: String=core.room.palette
	var tint:=Color("689695") if palette=="garden" else (Color("456775") if palette=="deep" else (Color("b49c76") if palette=="gold" else Color("7293a3")))
	if palette=="dawn": tint=Color("d9c8a0")
	draw_rect(Rect2(0,0,W,H),Color("071320"))
	var far_x: float=-camera.x*.035
	draw_texture_rect(textures.city,Rect2(far_x,-camera.y*.055,690,389),false,tint)
	draw_rect(Rect2(0,0,W,H),Color(.015,.045,.07,.46 if palette!="deep" else .64))
	# Atmospheric columns move slower than traversal geometry.
	for i in range(-1,9):
		var x: float=i*188-camera.x*.43
		if x< -180 or x>800: continue
		draw_prop("arch",Vector2(x,core.room.size.y*.52-camera.y*.4+125),1.9,Color(.25,.47,.53,.26))
	var landmark: String=core.room.landmark
	if landmark in ["gate","nave","bellgate","greatbell"]:
		var pos: Vector2=screen_pos(Vector2(core.room.size.x*.57,core.room.size.y-100))
		draw_prop("bell",pos,2.25 if landmark=="greatbell" else 1.55,Color(.48,.58,.57,.55))
		draw_prop("arch",pos+Vector2(0,48),3.4,Color(.25,.44,.48,.6))
	elif landmark in ["tree","nest"]:
		for i in range(5): draw_prop("tree",screen_pos(Vector2(190+i*246,430)),1.8,Color(.62,.72,.52,.75))
	elif landmark=="archive":
		for i in range(7): draw_prop("bookcase",screen_pos(Vector2(95+i*145,450)),1.85,Color(.45,.67,.66,.66))
	elif landmark in ["sluice","well"]:
		for i in range(4): draw_prop("wheel",screen_pos(Vector2(175+i*307,480)),1.7,Color(.38,.57,.6,.6))
	elif landmark in ["cable","tower"]:
		for i in range(4):
			var start:=screen_pos(Vector2(i*350-100,70))
			var end:=screen_pos(Vector2(i*350+500,160))
			draw_line(start,end,Color("264653"),3)
			for n in range(12):
				var pt: Vector2=start.lerp(end,n/12.0)
				draw_line(pt,pt+Vector2(0,33+n%3*12),Color("365666"))
	elif landmark=="observatory":
		var center:=screen_pos(Vector2(731,240))
		draw_arc(center-Vector2(0,100),105,0,TAU,64,Color("708c8b"),2)
		draw_arc(center-Vector2(0,100),83,0,TAU,64,Color("4e6972"))
		for i in range(12):
			var d:=Vector2.from_angle(i*TAU/12)
			draw_line(center-Vector2(0,100)+d*78,center-Vector2(0,100)+d*105,Color("82938e"))
	# Slanted shafts of sparse waterlight; never cover walkable edges.
	for i in range(3):
		var x: float=170+i*287-camera.x*.12
		draw_colored_polygon(PackedVector2Array([Vector2(x,-20),Vector2(x+23,-20),Vector2(x-110,360),Vector2(x-160,360)]),Color(.4,.75,.78,.024))
	draw_water()
	var draw_camera:=camera
	if not reduced_motion and core.shake>0: camera+=(Vector2(sin(tick*93),cos(tick*79))*core.shake).round()
	for platform in core.room.platforms: draw_platform(platform)
	for d in core.room.doors:
		var pos:=screen_pos(d.pos)
		draw_prop("door",pos,.7,Color(.7,.85,.83,1) if core.can_use_door(d) else Color(.35,.47,.52,1))
		if core.can_use_door(d):
			glow(pos-Vector2(0,35),35,Color("68cec1"),.6)
			draw_line(pos+Vector2(-13,-3),pos+Vector2(13,-3),Color("70b7ac"))
	for obj in core.room.items: draw_item(obj)
	for t in core.trail:
		draw_actor("player_keyposes",screen_pos(t.pos)-Vector2(33,46),Vector2(80,80),1,4,t.face,Color(.5,.95,.86,t.life*2))
	for e in core.enemies:
		if not e.dead: draw_enemy(e)
	for echo in core.echoes:
		var pos:=screen_pos(echo.pos)
		var radius:float=23*(echo.wait/echo.total)+4
		draw_arc(pos+Vector2(0,7),radius,PI,TAU,10,Color("efbe78"),2)
		draw_line(pos+Vector2(0,7),pos+Vector2(echo.dir*52,7),Color(.96,.7,.35,.6),1)
		glow(pos,33,Color("e6ac67"),1.2)
	for q in core.projectiles: draw_projectile(q)
	draw_player()
	for a in core.particles:
		var color: Color=colors.get(a.color,Color.WHITE)
		color.a=minf(1,a.life*3)
		draw_rect(Rect2(screen_pos(a.pos),Vector2(a.size,a.size)),color)
	# Foreground grasses and leaking masonry, anchored to safe edges.
	for platform in core.room.platforms:
		var r: Rect2=platform.rect
		if r.size.x>120:
			draw_prop("roots",screen_pos(r.position+Vector2(30,3)),.53,Color(.28,.43,.44,.84))
	camera=draw_camera
	draw_weather()
	draw_hud()
	if mode=="play":
		var nearest: Dictionary=core.nearest_interaction()
		if not nearest.is_empty():
			var obj: Dictionary=nearest.data
			var label: String="前往 "+core.world[obj.target].name if nearest.category=="door" else obj.label
			var pos:=screen_pos(core.player.pos)+Vector2(7,-21)
			var box:=Rect2(clampf(pos.x-80,8,472),clampf(pos.y-19,59,290),160,25)
			draw_rect(box,Color(.025,.07,.095,.92))
			text_at("E  "+label,box.position+Vector2(0,17),11,Color("eddfb8"),HORIZONTAL_ALIGNMENT_CENTER,160)
	if room_title>0 and mode=="play" and not core.boss_started:
		var alpha: float=minf(1,room_title)*minf(1,(3.3-room_title)*2)
		centered(core.room.name,103,22,Color(.78,.85,.83,alpha))
		centered(core.room.subtitle,121,10,Color(.61,.76,.77,alpha),true)
	if boss_intro>0:
		var alpha: float=minf(1,boss_intro)
		centered("守 钟 人",94,21,Color(.95,.79,.51,alpha))
		centered("THE LAST BELLKEEPER",114,10,Color(.75,.77,.72,alpha),true)
	if toast_time>0: draw_toast()
	if core.player.dead:
		draw_rect(Rect2(0,0,W,H),Color(.01,.03,.055,.48))
		centered("灯火未熄",168,28,Color("ecd6a4"))
		centered("在最后的灯座重新醒来",195,12,Color("9bb7b8"))
		centered(core.death_hint(),218,10,Color("a5b9b8"))

func draw_platform(platform: Dictionary) -> void:
	var r: Rect2=platform.rect
	var screen:=screen_pos(r.position)
	if screen.x>W or screen.x+r.size.x<0 or screen.y>H or screen.y+r.size.y<0: return
	var material: int={"stone":0,"wood":1,"metal":2}.get(platform.material,0)
	for yy in range(0,int(r.size.y),32):
		for xx in range(0,int(r.size.x),32):
			var size:=Vector2(minf(32,r.size.x-xx),minf(32,r.size.y-yy))
			var src:=Rect2(posmod(int(r.position.x/32)+xx/32,4)*32,(material if yy==0 else 3)*32,size.x,size.y)
			var dest:=Rect2(screen+Vector2(xx,yy),size)
			draw_texture_rect_region(textures.tiles,dest,src,Color(1,1,1) if yy==0 else Color(.65,.76,.81))
	# Broken stone undercuts, loose iron ties and salt-drips give each ledge weight.
	if r.size.y<34 and platform.material=="stone":
		for n in range(0,int(r.size.x)-8,17):
			var depth: float=4+posmod(int(r.position.x)+n*7,7)
			var at: Vector2=screen+Vector2(n,r.size.y-1)
			draw_colored_polygon(PackedVector2Array([at,at+Vector2(15,0),at+Vector2(13,depth),at+Vector2(4,depth)]),Color("142d3a"))
			draw_line(at+Vector2(1,0),at+Vector2(4,depth),Color("31505a"))
			if n%3==0:draw_line(at+Vector2(7,depth),at+Vector2(6,depth+8),Color("335a56"))
	if r.size.y>40:
		for i in range(5):
			draw_rect(Rect2(screen+Vector2(0,32+i*13),Vector2(r.size.x,13)),Color(.02,.045,.06,.10+i*.06))
	# Deliberate bright navigation edge and a dark underside.
	draw_line(screen,screen+Vector2(r.size.x,0),Color("729494"))
	if r.size.y<34: draw_line(screen+Vector2(0,r.size.y),screen+r.size,Color("07131c"),3)

func draw_water() -> void:
	var y: float=core.room.size.y-43-camera.y
	if y>360: return
	draw_rect(Rect2(0,y,W,H-y),Color(.04,.18,.23,.7))
	for i in range(54):
		var x: float=fmod(i*103.1-camera.x*.6+sin(tick+i)*3+3000,640)
		var yy: float=y+fmod(i*17.9+sin(tick*.6+i)*3,54)
		draw_line(Vector2(x,yy),Vector2(x+6+i%4*4,yy),Color(.19,.49,.54,.17+float(i%3)*.08))

func draw_weather() -> void:
	var rain: bool=core.room.palette in ["rain","garden"]
	for i in range(68 if rain else 30):
		var x: float=fmod(i*83.7-camera.x*.26+tick*(7 if rain else 2)+5000,640)
		var y: float=fmod(i*47.3+tick*(156+i%4*15 if rain else -8)+camera.y*.3+5000,360)
		if rain: draw_line(Vector2(x,y),Vector2(x-2,y+8),Color(.45,.7,.76,.15))
		else: draw_rect(Rect2(x,y,1,1),Color(.69,.72,.53,.23+sin(tick+i)*.16))
	# A gentle vignette made from broad alpha strips.
	for i in range(8):
		var a:=.017*(8-i)/8
		draw_rect(Rect2(0,0,W,5+i*4),Color(0,.025,.055,a))
		draw_rect(Rect2(0,H-5-i*3,W,5+i*3),Color(0,.018,.035,a))

func draw_item(obj: Dictionary) -> void:
	if obj.id=="rf_tilu":draw_tilu(obj);return
	if obj.kind in ["ability","health","memory","relic"] and core.flags.get(obj.id,false): return
	var pos:=screen_pos(obj.pos)
	match obj.kind:
		"checkpoint":
			draw_prop("lamp",pos,.64)
			glow(pos+Vector2(11,-37),72,Color("ffc677"),1.5)
			for i in range(4): draw_rect(Rect2(pos+Vector2(sin(tick*2+i)*10,-48-fmod(tick*9+i*8,32)),Vector2(1,2)),Color("e4b46e"))
		"beacon":
			draw_prop("beacon",pos,.8)
			if core.flags.get(obj.id,false):
				glow(pos-Vector2(0,47),95,Color("ffc578"),2)
				draw_flame(pos-Vector2(0,42),1.4)
			else:
				draw_circle(pos-Vector2(0,42),3,Color("467d85"))
		"sign": draw_prop("sign",pos,.68)
		"npc": draw_prop("npc",pos,.85);glow(pos-Vector2(-19,11),40,Color("efba67"))
		"shortcut": draw_prop("wheel",pos,.58)
		"ending":
			glow(pos-Vector2(0,40),110,Color("e7d09a"),2)
			draw_line(pos-Vector2(0,12),pos-Vector2(0,65),Color("ddca92"),2)
			draw_arc(pos-Vector2(0,60),13,0,TAU,16,Color("f5e2ad"),2)
		_:
			var yy: float=-21+sin(tick*2.8+obj.pos.x)*3
			glow(pos+Vector2(0,yy),35,Color("92d9c8"),1.4)
			if obj.kind=="memory":
				draw_colored_polygon(PackedVector2Array([pos+Vector2(-6,yy-6),pos+Vector2(4,yy-8),pos+Vector2(6,yy+4),pos+Vector2(-4,yy+6)]),Color("d3b980"))
				for n in range(3): draw_line(pos+Vector2(-3,yy-3+n*2),pos+Vector2(3,yy-4+n*2),Color("7a735b"))
			elif obj.kind=="ability":
				draw_colored_polygon(PackedVector2Array([pos+Vector2(-2,yy+10),pos+Vector2(10,yy-12),pos+Vector2(2,yy-10),pos+Vector2(-7,yy+2)]),Color("b6e4cd"))
				draw_line(pos+Vector2(-4,yy+8),pos+Vector2(8,yy-11),Color("e4e6b6"))
			else:
				draw_colored_polygon(PackedVector2Array([pos+Vector2(0,yy-8),pos+Vector2(6,yy),pos+Vector2(0,yy+7),pos+Vector2(-6,yy)]),Color("e8bd74"))

func draw_flame(pos: Vector2,s: float=1) -> void:
	var wave: float=sin(tick*14)*2
	var pts:=PackedVector2Array([pos+Vector2(-6,0)*s,pos+Vector2(-7,-7)*s,pos+Vector2(-2,-17-wave)*s,pos+Vector2(0,-12)*s,pos+Vector2(4,-22+wave)*s,pos+Vector2(6,-8)*s,pos+Vector2(5,0)*s])
	draw_colored_polygon(pts,Color("ce7542"))
	draw_colored_polygon(PackedVector2Array([pos+Vector2(-3,0)*s,pos+Vector2(-4,-7)*s,pos+Vector2(2,-16)*s,pos+Vector2(4,-4)*s,pos+Vector2(2,1)*s]),Color("f6c573"))
	draw_rect(Rect2(pos+Vector2(-1,-6)*s,Vector2(3,7)*s),Color("fff0b5"))

func actor_rect(pos:Vector2,size:Vector2,face:int) -> Rect2:
	# Godot flips negative texture-rect width in place; do not also offset the origin.
	return Rect2(pos,Vector2(-size.x if face<0 else size.x,size.y))

func draw_actor(texture: String,pos: Vector2,size: Vector2,row: int,frame: int,face: int=1,tint: Color=Color.WHITE) -> void:
	var dest:=actor_rect(pos,size,face)
	draw_texture_rect_region(textures[texture],dest,Rect2(frame*size.x,row*size.y,size.x,size.y),tint)

func draw_player() -> void:
	if core.get("breaker")!=null and core.breaker.state!="idle" and not core.player.dead:
		draw_breaker_player();return
	var p: Dictionary=core.player
	if p.dead: return
	var pose:=4
	if p.hurt>0: pose=13
	elif p.dash>0: pose=12
	elif p.attack>0:
		if p.attack_dir<0: pose=8 if p.attack>.25 else 10
		elif p.attack_dir>0: pose=11 if p.attack>.25 else 6
		else: pose=8 if p.attack>.25 else (9 if p.attack>.12 else 4)
	elif not p.grounded: pose=5 if p.vel.y<0 else 6
	elif p.land>0: pose=7
	elif absf(p.vel.x)>12: pose=int(p.animation*16)%4
	elif p.heal>0: pose=14
	var pos:=screen_pos(p.pos)
	if p.grounded: draw_shadow(pos+Vector2(7,24),12)
	glow(pos+Vector2(8,1),45,Color("f4c170"),1.7)
	var tint:=Color.WHITE
	if p.invuln>0 and int(tick*16)%2==0: tint.a=.47
	draw_actor("player_keyposes",pos-Vector2(33,46),Vector2(80,80),pose/8,pose%8,p.face,tint)
	if p.attack>0.12 and p.attack<.25:
		var center:=pos+Vector2(7,11)
		var rotation: float=0 if p.attack_dir==0 else (-PI/2 if p.attack_dir<0 else PI/2)
		if p.attack_dir==0 and p.face<0: rotation=PI
		var progress: float=(.25-p.attack)/.13
		var start: float=rotation-1.3+progress*1.8
		draw_arc(center,33,start,start+1.15,8,Color("ffe9b5"),3)
		draw_arc(center,28,start-.1,start+1.2,8,Color(.6,.93,.86,.45),2)
		if p.attack_dir==1:
			draw_colored_polygon(PackedVector2Array([center+Vector2(-3,9),center+Vector2(2,34),center+Vector2(6,10),center+Vector2(2,14)]),Color("fff0bf"))
	if p.heal>0:
		draw_arc(pos+Vector2(7,11),22,-PI/2,-PI/2+TAU*p.heal/.85,26,Color("edd69c"),2)

func draw_shadow(center: Vector2, radius: float) -> void:
	var pts:=PackedVector2Array()
	for i in range(12):
		var a: float=i*TAU/12
		pts.append(center+Vector2(cos(a)*radius,sin(a)*3))
	draw_colored_polygon(pts,Color(.005,.015,.022,.52))

func draw_enemy(e: Dictionary) -> void:
	if e.kind=="rf_foldhammer":draw_foldhammer(e);return
	if e.kind=="rf_carrier":draw_carrier(e);return
	var pos:=screen_pos(e.pos)
	var frame:=int(e.t*10)%8 if e.state!="patrol" else int(tick*8)%8
	var tint:=Color(1,1,1)
	if e.flash>0: tint=Color(2,2,2)
	if e.kind=="boss":
		var pose: int=0
		match e.state:
			"patrol": pose=0 if absf(e.vel.x)<10 or int(tick*4)%2==0 else 1
			"windup": pose=2
			"attack": pose=(4 if not e.grounded else 5) if e.pattern==0 else (3 if e.pattern==1 else 7)
			"recover": pose=5 if e.pattern==0 and e.t<.16 else 6
			"phase": pose=7
		draw_shadow(pos+Vector2(24,68),30)
		draw_actor("bellkeeper_keyposes",pos-Vector2(55,76),Vector2(160,160),0,pose,e.face,tint)
		glow(pos+Vector2(24,24),65,Color("efb566"),1)
		if e.state=="phase":
			# An enclosed, cool bell-ring reads as a protected transition and a healing breath.
			draw_arc(pos+Vector2(24,32),48,0,TAU,32,Color("9dd8d0"),2)
			draw_arc(pos+Vector2(24,32),53,0,TAU,32,Color(.6,.88,.83,.3),1)
		elif e.phase==2:
			draw_line(pos+Vector2(18,16),pos+Vector2(26,30),Color("ffe0a1"),2)
			draw_line(pos+Vector2(26,30),pos+Vector2(20,40),Color("ffe0a1"),1)
		if e.state=="windup":
			var icon:=pos+Vector2(24,-19)
			draw_circle(icon,6,Color("eaaa65"))
			text_at("!",icon+Vector2(-2,4),12,Color("201a21"))
			if e.pattern==1:
				draw_line(pos+Vector2(25,70),pos+Vector2(25+e.face*140,70),Color(.98,.65,.35,.6),2)
			elif e.pattern==0:
				draw_arc(pos+Vector2(24,67),48,PI,TAU,18,Color(.99,.72,.4,.5),2)
			else:
				for angle in range(5):
					var a:float=-PI+angle*PI/4
					var rune:Vector2=pos+Vector2(24,24)+Vector2(cos(a),sin(a))*(40+sin(tick*9)*2)
					draw_rect(Rect2(rune-Vector2(2,2),Vector2(4,4)),Color("f0c180"),false)
				draw_arc(pos+Vector2(24,24),40,-PI,0,20,Color(.99,.72,.4,.4),1)
		return
	if e.kind!="moth": draw_shadow(pos+Vector2(e.size.x/2,e.size.y),e.size.x*.5)
	var kind_index: int={"crab":0,"moth":1,"warden":2,"eel":3}[e.kind]
	var pose: int={"patrol":0,"windup":1,"attack":2,"recover":3}.get(e.state,0)
	if e.kind=="moth" and e.state=="patrol": pose=0 if int(tick*7)%2==0 else 3
	var cell: int=kind_index*4+pose
	var offset:=Vector2(48-e.size.x/2,80-e.size.y)
	draw_actor("enemy_keyposes",pos-offset,Vector2(96,96),cell/8,cell%8,e.face,tint)
	if e.state=="windup":
		var icon:=pos+Vector2(e.size.x/2,-10)
		draw_colored_polygon(PackedVector2Array([icon+Vector2(0,-5),icon+Vector2(4,0),icon+Vector2(0,5),icon+Vector2(-4,0)]),Color("efb96c"))
		glow(icon,27,Color("edb15e"),.7)
	if e.hp<e.max_hp and e.flash>0:
		draw_rect(Rect2(pos-Vector2(0,7),Vector2(e.size.x,2)),Color("172f3b"))
		draw_rect(Rect2(pos-Vector2(0,7),Vector2(e.size.x*float(e.hp)/e.max_hp,2)),Color("dfa65d"))

func draw_projectile(q: Dictionary) -> void:
	var pos:=screen_pos(q.pos)
	glow(pos,18,Color("db9c5d"),1)
	if q.kind=="wave":
		draw_arc(pos+Vector2(0,8),13,PI,TAU,7,Color("f2c57a"),3)
		draw_line(pos+Vector2(-10,7),pos+Vector2(10,7),Color("ad724b"),2)
	else:
		draw_colored_polygon(PackedVector2Array([pos+Vector2(0,-5),pos+Vector2(4,1),pos+Vector2(0,5),pos+Vector2(-4,-1)]),Color("e6ba71"))
		draw_rect(Rect2(pos-Vector2(1,2),Vector2(2,4)),Color("fff1ba"))

func draw_hud() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(0,0),Vector2(270,0),Vector2(258,46),Vector2(0,46)]),Color(.02,.055,.08,.78))
	draw_colored_polygon(PackedVector2Array([Vector2(445,0),Vector2(640,0),Vector2(640,46),Vector2(453,46)]),Color(.02,.055,.08,.82))
	draw_line(Vector2(16,44),Vector2(148,44),Color(.38,.52,.49,.25))
	for i in range(core.max_hp):
		var pos:=Vector2(22+i*18,20)
		var c:=Color("f0c17a") if i<core.hp else Color("2b454f")
		draw_colored_polygon(PackedVector2Array([pos+Vector2(-5,3),pos+Vector2(-4,-4),pos+Vector2(0,-9),pos+Vector2(4,-3),pos+Vector2(5,3),pos+Vector2(0,7)]),c)
		if i<core.hp: draw_rect(Rect2(pos-Vector2(1,3),Vector2(2,6)),Color("fff0b9"))
	draw_rect(Rect2(17,35,86,3),Color("1c3945"))
	draw_rect(Rect2(17,35,86*core.charge/99,3),Color("76c4ba"))
	text_at("%d"%core.sparks,Vector2(maxf(122,25+18*core.max_hp),28),12,Color("cbaa70"))
	text_at("根火铸所" if core.room_id.begins_with("rf_") else "信号炉  %d / 3"%core.beacon_count(),Vector2(459,22),11,Color("e8d6b0"))
	text_at("M 地图   Esc 暂停",Vector2(459,38),10,Color("acc0c5"))
	if core.flags.get("double_jump",false): text_at("回声羽",Vector2(178,27),10,Color("96cabe"))
	if core.flags.get("rf_breaker",false):
		draw_rect(Rect2(279,9,50,25),Color(.02,.055,.08,.78));text_at("落砧环",Vector2(286,27),10,Color("d6b780"))
	if core.assisted: text_at("辅助",Vector2(241,27),10,Color("c3bc8d"))
	if core.player.dash_cd>0: draw_rect(Rect2(17,42,35*(1-core.player.dash_cd/.56),1),Color("dbb777"))
	if core.boss_started:
		for e in core.enemies:
			if e.kind=="boss" and not e.dead:
				text_at("守钟人",Vector2(134,321),10,Color("dcc391"))
				draw_rect(Rect2(132,329,376,4),Color("1d3037"))
				draw_rect(Rect2(132,329,376*float(e.hp)/e.max_hp,4),Color("c89460"))
				break
	if show_fps: text_at(str(Engine.get_frames_per_second()),Vector2(602,355),10)

func draw_toast() -> void:
	var y:=286.0 if core!=null and core.boss_started else 302.0
	draw_rect(Rect2(136,y-21,368,48),Color(.025,.07,.09,.94))
	centered(toast.get("title",""),y-3,13,Color("e5c58b"))
	centered(toast.get("text",""),y+16,11,Color("aac0bf"))

func draw_pause() -> void:
	draw_rect(Rect2(0,0,W,H),Color(.015,.04,.065,.88))
	centered("暂 歇",91,26,Color("e6cfa1"))
	for i in range(menu_options().size()): draw_menu_option(i,menu_options()[i])
	centered("离开窗口时会暂停。进度在灯座与重要发现后自动记录。",327,10,Color("829da5"))

func dialog_action_text() -> String:
	return "E / 空格  继续旅途" if mode=="ending" else "E / 空格  收起"

func draw_dialog() -> void:
	draw_rect(Rect2(0,0,W,H),Color(.01,.04,.06,.72))
	var lines: PackedStringArray=dialog.get("text","").split("\n")
	var height:=minf(286,91+lines.size()*20)
	var top: float=(H-height)/2
	draw_rect(Rect2(58,top,524,height),Color("0e232f"))
	draw_rect(Rect2(63,top+5,514,height-10),Color("496068"),false)
	text_at(dialog.get("title",""),Vector2(83,top+34),19,Color("e1c491"))
	var y: float=top+65
	for line in lines:
		text_at(line,Vector2(83,y),12,Color("b9caca"))
		y+=20
	text_at(dialog_action_text(),Vector2(403,top+height-18),10,Color("7799a2"))

func map_layout() -> Dictionary:
	var layout:Dictionary={
		"gate":Rect2(35,205,70,24),"nave":Rect2(126,157,84,81),
		"steps":Rect2(157,78,28,69),"gallery":Rect2(257,73,82,27),
		"orchard":Rect2(241,182,94,48),"roost":Rect2(275,137,34,24),
		"sluice":Rect2(143,280,71,24),"well":Rect2(243,245,33,65),
		"archive":Rect2(306,256,72,46),"hall":Rect2(366,77,46,29),
		"boss":Rect2(437,66,79,43),"observatory":Rect2(541,57,59,49),"rf_workshop":Rect2(524,139,80,48),"rf_ledger":Rect2(416,241,83,58)}
	for id in core.world:
		if not layout.has(id):
			var room:Dictionary=core.world[id];var cell:Vector2=room.get("map",Vector2.ZERO)
			layout[id]=room.get("map_rect",Rect2(Vector2(35,65)+cell*Vector2(85,80),Vector2(clampf(room.size.x/18,36,90),clampf(room.size.y/12,24,65))))
	return layout

func map_room_polygon(rect:Rect2,id:String) -> PackedVector2Array:
	var p:Vector2=rect.position
	var s:Vector2=rect.size
	if id=="nave":
		return PackedVector2Array([p+Vector2(0,s.y),p+Vector2(0,s.y*.45),p+Vector2(s.x*.25,s.y*.45),p+Vector2(s.x*.25,0),p+Vector2(s.x*.83,0),p+Vector2(s.x*.83,s.y*.33),p+Vector2(s.x,s.y*.33),p+s])
	var b:=3.0
	return PackedVector2Array([p+Vector2(b,0),p+Vector2(s.x-b,0),p+Vector2(s.x-b,b),p+Vector2(s.x,b),p+Vector2(s.x,s.y-b),p+Vector2(s.x-b,s.y-b),p+Vector2(s.x-b,s.y),p+Vector2(0,s.y),p+Vector2(0,b),p+Vector2(b,b)])

func draw_map() -> void:
	draw_rect(Rect2(0,0,W,H),Color(.016,.038,.052,.97))
	centered("根 火 铸 所" if core.room_id.begins_with("rf_") else "潮 门 旧 城",47,23,Color("dccaa5"))
	centered("寻着火光，绘出回去的路。",67,11,Color("8eaaac"))
	var layout:Dictionary=map_layout()
	var known:Array=core.visited.duplicate()
	for id in core.visited:
		for d in core.world[id].doors:
			if d.target=="roost" and not core.visited.has("roost"):continue
			if not known.has(d.target):known.append(d.target)
	var bounds:Rect2=layout[core.room_id]
	for id in known:
		if layout.has(id):bounds=bounds.merge(layout[id])
	var zoom:float=minf(1.7,minf(538/maxf(bounds.size.x,1),203/maxf(bounds.size.y,1)))
	var offset:Vector2=Vector2(320,197)-bounds.get_center()*zoom
	var positions:Dictionary={}
	for id in known:
		if layout.has(id):positions[id]=Rect2(layout[id].position*zoom+offset,layout[id].size*zoom)
	# Soft grid marks read as a survey surface, without revealing undiscovered rooms.
	for x in range(24,625,24):
		for y in range(90,302,24):draw_rect(Rect2(x,y,1,1),Color(.23,.37,.39,.14))
	var drawn:Array=[]
	for id in known:
		if not positions.has(id):continue
		for d in core.world[id].doors:
			if not positions.has(d.target):continue
			var key:String=id+d.target if id<d.target else d.target+id
			if drawn.has(key):continue
			drawn.append(key)
			var ar:Rect2=positions[id]
			var br:Rect2=positions[d.target]
			var a:Vector2=ar.get_center()
			var b:Vector2=br.get_center()
			var complete:bool=core.visited.has(id) and core.visited.has(d.target)
			var active:bool=core.can_use_door(d)
			if not complete:
				var from_visited:bool=core.visited.has(id)
				var origin:Vector2=a if from_visited else b
				var destination:Vector2=b if from_visited else a
				var r:Rect2=ar if from_visited else br
				var dir:Vector2=(destination-origin).normalized()
				var reach_to_edge:float=minf(r.size.x*.5/maxf(absf(dir.x),.001),r.size.y*.5/maxf(absf(dir.y),.001))
				var start:Vector2=origin+dir*(reach_to_edge+2)
				var end:Vector2=start+dir*22
				draw_line(start,end,Color("3c5b61"),2)
				text_at("?",end+Vector2(-3,4),10,Color("749297"))
				continue
			var pts:Array=[a]
			if key=="gallerynave":
				var elbow_a:Vector2=Vector2(224,layout.nave.get_center().y)*zoom+offset
				var elbow_b:Vector2=Vector2(224,124)*zoom+offset
				var elbow_c:Vector2=Vector2(layout.gallery.get_center().x,124)*zoom+offset
				pts.append_array([elbow_c,elbow_b,elbow_a] if id=="gallery" else [elbow_a,elbow_b,elbow_c])
			elif key=="gallerysteps":
				var lane:float=85*zoom+offset.y
				pts.append(Vector2(a.x,lane));pts.append(Vector2(b.x,lane))
			elif absf(a.x-b.x)>15 and absf(a.y-b.y)>15:
				pts.append(Vector2(b.x,a.y))
			pts.append(b)
			for n in range(pts.size()-1):
				draw_line(pts[n],pts[n+1],Color("142e37"),5)
				draw_line(pts[n],pts[n+1],Color("6c8f91") if active else Color("755c44"),1)
			if not active:
				var middle:int=pts.size()/2
				var lock:Vector2=pts[middle-1].lerp(pts[middle],.5)
				draw_rect(Rect2(lock-Vector2(3,3),Vector2(6,6)),Color("b68b55"),false)
	for id in core.visited:
		if not positions.has(id):continue
		var r:Rect2=positions[id]
		var current:bool=id==core.room_id
		var poly:PackedVector2Array=map_room_polygon(r,id)
		var fill:=Color("23434d") if current else Color("142f39")
		if core.world[id].palette=="garden":fill=Color("293e37") if not current else Color("3e5140")
		draw_colored_polygon(poly,fill)
		for n in range(poly.size()):draw_line(poly[n],poly[(n+1)%poly.size()],Color("d5b87f") if current else Color("5c7c82"),1)
		# Miniature ledges derive from the real room geometry, rather than generic nodes.
		for platform in core.ROUTES.materialize(core.world[id],core.flags).platforms:
			var source:Rect2=platform.rect
			var local:Vector2=(source.position/core.world[id].size)*r.size
			var length:float=source.size.x/core.world[id].size.x*r.size.x
			if source.position.y/core.world[id].size.y>.1:
				draw_line(r.position+local,r.position+local+Vector2(length,0),Color(.48,.62,.62,.32),1)
		for obj in core.world[id].items:
			var marker:Vector2=r.position+(obj.pos/core.world[id].size)*r.size
			if obj.kind=="checkpoint":
				draw_line(marker-Vector2(0,4),marker+Vector2(0,1),Color("e1bd7d"),1)
				draw_circle(marker-Vector2(0,5),2,Color("ecd19b"))
			elif obj.kind=="npc" and obj.id=="rf_tilu" and core.flags.get("rf_tilu_met",false):
				draw_rect(Rect2(marker-Vector2(2,4),Vector2(5,5)),Color("c6c5a9"))
				draw_rect(Rect2(marker-Vector2(0,3),Vector2(2,2)),Color("548d8d"))
			elif obj.kind=="beacon":
				if core.flags.get(obj.id,false):draw_circle(marker-Vector2(0,3),3,Color("e8b872"))
				else:draw_arc(marker-Vector2(0,3),3,0,TAU,8,Color("997850"),1)
		if r.size.x>45 and id!=core.room_id:
			text_at(core.world[id].name,r.position+Vector2(-15,-6),9,Color("86a3a7"),HORIZONTAL_ALIGNMENT_CENTER,r.size.x+30)
	var here:Rect2=positions[core.room_id]
	var normalized_player:Vector2=(core.player.pos+Vector2(7,24))/core.room.size
	normalized_player=normalized_player.clamp(Vector2(.02,.02),Vector2(.98,.98))
	var player_at:Vector2=here.position+normalized_player*here.size
	glow(player_at,12,Color("f0c67d"),1.5)
	draw_colored_polygon(PackedVector2Array([player_at+Vector2(0,-5),player_at+Vector2(4,0),player_at+Vector2(0,4),player_at+Vector2(-4,0)]),Color("ffe4a4"))
	centered(core.room.name,324,14,Color("e0c592"))
	centered("灯座  ·  信号炉  ·  金色菱形是你的位置       M / Tab 收起",344,10,Color("8da6ab"))

func root_module(name:String,dest:Rect2,tint:Color=Color.WHITE) -> void:
	var regions:Dictionary={"workshop":Rect2(98,8,638,341),"bridge":Rect2(780,202,697,146),"pier":Rect2(290,373,259,314),"hoist":Rect2(935,363,432,349),"pressure":Rect2(122,699,601,300),"seal":Rect2(769,889,706,107)}
	draw_texture_rect_region(textures.rootfoundry_modules,dest,regions[name],tint)

func sheet_pose_rect(box:Rect2,anchor:Vector2,scale_factor:float,at:Vector2,face:int) -> Rect2:
	var origin:=at+Vector2((box.position.x-anchor.x)*scale_factor,(box.position.y-anchor.y)*scale_factor)
	if face<0:origin.x=at.x-(box.end.x-anchor.x)*scale_factor
	return Rect2(origin,Vector2(box.size.x*scale_factor*(-1 if face<0 else 1),box.size.y*scale_factor))

func sheet_pose(key:String,box:Rect2,anchor:Vector2,s:float,at:Vector2,face:int,tint:Color=Color.WHITE) -> void:
	draw_texture_rect_region(textures[key],sheet_pose_rect(box,anchor,s,at,face),box,tint)

func draw_breaker_player() -> void:
	var p:Dictionary=core.player;var pose:=0
	if core.breaker.state=="fall":pose=1
	elif core.breaker.state=="recovery":pose=2 if core.breaker.time_left>.09 else 3
	var boxes:Array=[Rect2(68,140,440,420),Rect2(630,32,326,590),Rect2(1134,241,470,431),Rect2(1647,290,490,382)]
	var anchors:Array=[Vector2(323,548),Vector2(804,610),Vector2(1320,660),Vector2(1920,660)]
	var at:=screen_pos(p.pos+Vector2(7,24))
	if p.grounded:draw_shadow(at,14)
	glow(at-Vector2(0,27),44,Color("e5b06b"),1.1)
	# The copper suit shares the regular player's cooler ambient material response.
	# This is lighting modulation only: source pixels, scale and foot anchors stay intact.
	var tint:=Color(.82,.88,.90)
	if p.invuln>0 and int(tick*16)%2==0:tint.a=.47
	sheet_pose("breaker_poses",boxes[pose],anchors[pose],.105,at,p.face,tint)
	if core.breaker.state=="fall":
		draw_line(at-Vector2(9,41),at-Vector2(9,16),Color(.6,.78,.71,.45),1)
		draw_line(at+Vector2(10,-46),at+Vector2(10,-22),Color(.6,.78,.71,.45),1)

func draw_carrier(e:Dictionary) -> void:
	var pose:=0
	if e.flash>0:pose=7
	elif e.state=="patrol":pose=1+int(tick*8)%2 if absf(e.vel.x)>8 else 0
	elif e.state=="windup":pose=3 if e.t<.30 else 4
	elif e.state=="attack":pose=5
	elif e.state=="recover":pose=6
	var boxes:Array=[Rect2(28,210,414,199),Rect2(454,202,432,206),Rect2(896,207,431,204),Rect2(1340,68,396,342),Rect2(40,472,357,363),Rect2(411,658,497,182),Rect2(912,634,438,202),Rect2(1347,608,398,226)]
	var anchors:Array=[Vector2(160,400),Vector2(605,400),Vector2(1045,400),Vector2(1500,400),Vector2(272,824),Vector2(618,824),Vector2(1044,824),Vector2(1477,824)]
	var at:=screen_pos(e.pos+Vector2(15,24))
	draw_shadow(at,20)
	sheet_pose("carrier_poses",boxes[pose],anchors[pose],.15,at,e.face,Color(1.35,1.25,1.08) if e.flash>0 else Color.WHITE)
	if e.state=="windup":
		var cue:=at-Vector2(0,38)
		draw_colored_polygon(PackedVector2Array([cue-Vector2(0,5),cue+Vector2(4,0),cue+Vector2(0,5),cue-Vector2(4,0)]),Color("ecc58c"))
		draw_line(at+Vector2(e.face*9,-1),at+Vector2(e.face*45,-1),Color(.93,.7,.4,.7),1)

func draw_root_platform(platform:Dictionary) -> void:
	var r:Rect2=platform.rect;var at:=screen_pos(r.position)
	if at.x>W or at.x+r.size.x<0 or at.y>H or at.y+r.size.y+60<0:return
	if platform.get("material","")=="ceramic":
		root_module("seal",Rect2(at-Vector2(0,2),Vector2(r.size.x,26)))
		draw_line(at+Vector2(4,1),at+Vector2(r.size.x-4,1),Color("dfd7b0"),1)
	elif r.size.y<=30:
		var sections:int=ceili(r.size.x/280.)
		var width:float=r.size.x/sections
		for i in range(sections):root_module("bridge",Rect2(at+Vector2(i*width,-1),Vector2(width,58)),Color(.82,.88,.85))
		draw_line(at,at+Vector2(r.size.x,0),Color("b99e76"),1)
	else:
		draw_platform(platform)
		for x in range(0,int(r.size.x),96):
			draw_rect(Rect2(at+Vector2(x,1),Vector2(2,7)),Color("ba8860"))

func draw_pressure_register(cell:RefCounted) -> void:
	var lane:Rect2=cell.lane;var origin:=screen_pos(Vector2(lane.position.x-184,lane.end.y-90))
	root_module("pressure",Rect2(origin,Vector2(180,90)),Color(.78,.84,.77))
	var shutters:int=cell.warning_shutters()
	for n in range(3):
		var w:=origin+Vector2(64+n*24,67)
		draw_rect(Rect2(w-Vector2(8,7),Vector2(16,14)),Color("152933"))
		var lit:bool=(cell.state()=="warning" and n<shutters) or cell.active()
		for bar in range(3):draw_rect(Rect2(w+Vector2(-5,-4+bar*4),Vector2(10,2)),Color("ffd893") if lit else Color("365255"))
	var screen:=Rect2(screen_pos(lane.position),lane.size)
	if cell.state()=="warning":
		draw_rect(screen,Color(.92,.6,.3,.055))
		for x in range(0,int(lane.size.x),12):draw_line(screen.position+Vector2(x,lane.size.y-3),screen.position+Vector2(x+5,lane.size.y-7),Color("ddb073"),1)
	elif cell.active():
		# Clustered steam moves out from the nozzle; the floor brackets retain the exact lane.
		for layer in range(2):
			for i in range(12):
				var x:float=fmod(i*13+tick*92+layer*7,lane.size.x)
				var radius:float=5+x/lane.size.x*7
				var y:float=14+layer*17+sin(tick*8+i)*4
				var shape:Array=[Vector2(-1,-.4),Vector2(-.6,-.4),Vector2(-.6,-.85),Vector2(.25,-.85),Vector2(.25,-.6),Vector2(.85,-.6),Vector2(.85,.5),Vector2(.45,.5),Vector2(.45,.85),Vector2(-.5,.85),Vector2(-.5,.55),Vector2(-1,.55)]
				var points:=PackedVector2Array()
				for unit in shape:
					var point:Vector2=Vector2(x,y)+unit*radius
					point.x=clampf(point.x,0,lane.size.x);point.y=clampf(point.y,1,lane.size.y-2);points.append((screen.position+point).round())
				draw_colored_polygon(points,Color(.77,.83,.72,.16 if layer==0 else .23))
				if i%3==0:draw_line(screen.position+Vector2(x,y-radius*.4),screen.position+Vector2(minf(x+6,lane.size.x),y-radius*.4),Color(.93,.92,.73,.44),1)
		draw_line(screen.position+Vector2(0,lane.size.y-2),screen.end-Vector2(0,2),Color("d4bc87"),2)

func draw_rootfoundry() -> void:
	var unshaken:=camera
	if not reduced_motion and core.shake>0:camera+=(Vector2(sin(tick*93),cos(tick*79))*core.shake).round()
	draw_rect(Rect2(0,0,W,H),Color("08121b"))
	draw_texture_rect(textures.rootfoundry_background,Rect2(-camera.x*.045,-camera.y*.075,700,395),false,Color(.68,.72,.70))
	draw_rect(Rect2(0,0,W,H),Color(.02,.05,.075,.48))
	# Physical bridge architecture is separate from the parallax painting.
	for x in [30,1040]:
		root_module("pier",Rect2(screen_pos(Vector2(x,340)),Vector2(150,260)),Color(.30,.42,.45,.80))
	root_module("workshop",Rect2(screen_pos(Vector2(28,187)),Vector2(230,123)))
	glow(screen_pos(Vector2(145,278)),68,Color("e9ad62"),1.2)
	for platform in core.room.platforms:draw_root_platform(platform)
	if core.flags.get("rf_workshop_seal",false):
		for x in [640,731]:draw_rect(Rect2(screen_pos(Vector2(x,310)),Vector2(5,5)),Color("b5b4a0"))
	# Two visible cage gates and a continuous guide cable describe one in-room lift.
	var cable_top:=screen_pos(Vector2(271,244));var cable_bottom:=screen_pos(Vector2(271,594))
	draw_line(cable_top,cable_bottom,Color("4b4b3e"),2)
	for d in core.room.doors:
		var at:=screen_pos(d.pos)
		if d.id.begins_with("rf_hoist"):
			root_module("hoist",Rect2(at-Vector2(43,72),Vector2(89,72)),Color.WHITE if core.can_use_door(d) else Color(.5,.61,.65))
		else:draw_prop("door",at,.7)
	for obj in core.room.items:
		if obj.id=="rf_breaker":
			if not core.flags.get(obj.id,false):
				var at:=screen_pos(obj.pos)+Vector2(0,-23+sin(tick*3)*2)
				glow(at,35,Color("c9c294"));draw_arc(at,8,.4,TAU-.4,12,Color("d6a66d"),3);draw_rect(Rect2(at+Vector2(-3,5),Vector2(6,5)),Color("746852"))
		elif obj.id=="rf_workshop_hoist":
			draw_prop("wheel",screen_pos(obj.pos),.45,Color(.9,.75,.55));glow(screen_pos(obj.pos)-Vector2(0,20),22,Color("dda465"),.7)
		elif obj.kind=="checkpoint":
			draw_item(obj)
		elif obj.kind in ["memory","sign"]:draw_item(obj)
	for cell in core.pressure_cells:draw_pressure_register(cell)
	finish_foundry_draw(unshaken)

func finish_foundry_draw(unshaken:Vector2) -> void:
	for e in core.enemies:
		if not e.dead:draw_enemy(e)
	for t in core.trail:draw_actor("player_keyposes",screen_pos(t.pos)-Vector2(33,46),Vector2(80,80),1,4,t.face,Color(.7,.84,.71,t.life*2))
	draw_player()
	for a in core.particles:
		var col:Color=colors.get(a.color,Color.WHITE);col.a=minf(1,a.life*3);draw_rect(Rect2(screen_pos(a.pos),Vector2(a.size,a.size)),col)
	for i in range(24):
		var at:=Vector2(fmod(i*71.3+tick*3-camera.x*.1+2000,640),fmod(i*39.7-tick*9+2000,360))
		draw_rect(Rect2(at,Vector2(1,1)),Color(.8,.59,.34,.22))
	camera=unshaken
	draw_hud()
	if mode=="play":
		var nearest:Dictionary=core.nearest_interaction()
		if not nearest.is_empty():
			var obj:Dictionary=nearest.data
			var label:String=obj.get("label","") if nearest.category=="item" else obj.get("label","前往 "+core.world[obj.target].name)
			var at:=screen_pos(core.player.pos)+Vector2(7,-21);var box:=Rect2(clampf(at.x-88,8,456),clampf(at.y-19,59,290),176,25)
			draw_rect(box,Color(.025,.06,.07,.93));text_at("E  "+label,box.position+Vector2(0,17),11,Color("eddfb8"),HORIZONTAL_ALIGNMENT_CENTER,176)
	if room_title>0 and core.room_time<3.4:
		centered(core.room.name,96,22,Color("d7c59f"));centered(core.room.subtitle,116,10,Color("94aba6"),true)
	if toast_time>0:draw_toast()
	if core.player.dead:
		draw_rect(Rect2(0,0,W,H),Color(.01,.03,.05,.6));centered("灯火未熄",170,28,Color("ecd6a4"));centered(core.death_hint(),204,10,Color("aabdb5"))


func draw_tilu(obj:Dictionary) -> void:
	var poses:Array=[0,1,0,2,3,4,3,4,6,7]
	var pose:int=poses[int(tick*1.8)%poses.size()]
	if mode=="dialog" and dialog.get("title","")=="记薪人 · 缇芦":pose=5 if core.flags.get("rf_tilu_records_told",false) else 1
	var boxes:Array=[Rect2(157,32,234,306),Rect2(656,39,227,299),Rect2(1168,42,246,296),Rect2(138,375,259,301),Rect2(652,375,252,302),Rect2(1145,372,325,304),Rect2(152,691,203,307),Rect2(664,690,196,308)]
	var anchors:Array=[Vector2(263,331),Vector2(761,331),Vector2(1265,331),Vector2(243,669),Vector2(756,670),Vector2(1261,669),Vector2(258,991),Vector2(774,991)]
	var at:=screen_pos(obj.pos)
	draw_shadow(at+Vector2(9,0),26)
	# Workstation is its own fixed prop; gesture frames cannot drag the desk around.
	sheet_pose("tilu_modular",Rect2(1112,742,299,247),Vector2(1262,982),.14,at+Vector2(17,0),1,Color(.76,.85,.88))
	glow(at-Vector2(0,24),43,Color("cfbb8a"),.8)
	sheet_pose("tilu_modular",boxes[pose],anchors[pose],.125,at,1,Color(.80,.88,.91))
	if core.flags.get("rf_tilu_records_told",false):
		for n in range(2):
			draw_rect(Rect2(at+Vector2(34+n*4,-14-n*2),Vector2(8,11)),Color("a17350"))
			draw_line(at+Vector2(36+n*4,-11-n*2),at+Vector2(40+n*4,-11-n*2),Color("d2b98a"))

func draw_ledger() -> void:
	var unshaken:=camera
	if not reduced_motion and core.shake>0:camera+=(Vector2(sin(tick*93),cos(tick*79))*core.shake).round()
	draw_rect(Rect2(0,0,W,H),Color("07141e"))
	draw_texture_rect(textures.ledger_background,Rect2(-camera.x*.048,-camera.y*.072,700,395),false,Color(.61,.72,.75))
	draw_rect(Rect2(0,0,W,H),Color(.015,.035,.052,.32))
	# Recessed guide tracks tie the projecting rack treads to the cooling wall.
	for x in [948,1060,1126,1240]:
		var top:=screen_pos(Vector2(x,322));var bottom:=screen_pos(Vector2(x,574))
		draw_line(top,bottom,Color("112630"),7);draw_line(top+Vector2(2,0),bottom+Vector2(2,0),Color("27424b"),1)
		for y in range(336,573,42):draw_rect(Rect2(screen_pos(Vector2(x-3,y)),Vector2(7,4)),Color("344b50"))
	for platform in core.room.platforms:
		var r:Rect2=platform.rect;var at:=screen_pos(r.position)
		if platform.material=="cabinet":
			# Broad, open-sided cooling-rack treads: exact bright collision edge,
			# restrained shallow underside, no spike-shaped nonhazard support.
			draw_texture_rect_region(textures.rootfoundry_modules,Rect2(at,Vector2(r.size.x,12)),Rect2(788,204,684,42),Color(.68,.81,.82))
			draw_line(at,at+Vector2(r.size.x,0),Color("a7bfc0"),2)
			for x in range(8,int(r.size.x)-3,24):
				draw_rect(Rect2(at+Vector2(x,4),Vector2(4,3)),Color("806e50"))
				draw_line(at+Vector2(x,12),at+Vector2(x,25),Color(.23,.34,.36,.45),1)
		elif platform.material=="grate":
			draw_texture_rect_region(textures.rootfoundry_modules,Rect2(at,r.size),Rect2(788,204,684,42),Color(.63,.80,.81))
			for x in range(7,int(r.size.x)-4,12):
				draw_rect(Rect2(at+Vector2(x,4),Vector2(5,9)),Color("10242f"))
				draw_line(at+Vector2(x+5,4),at+Vector2(x+5,12),Color("547071"),1)
			draw_line(at,at+Vector2(r.size.x,0),Color("9eaea5"),2)
		else:draw_root_platform(platform)
	if core.flags.get("rf_ledger_seal",false):
		for x in [576,668]:draw_rect(Rect2(screen_pos(Vector2(x,310)),Vector2(4,4)),Color("b2bfae"))
	if core.flags.get("rf_ledger_return",false):
		var at:=screen_pos(Vector2(1150,310))
		draw_line(at,at+Vector2(0,-37),Color("768987"),3)
		for y in range(-35,0,9):draw_line(at+Vector2(-5,y),at+Vector2(4,y),Color("5a7576"),1)
	for d in core.room.doors:
		var at:=screen_pos(d.pos)
		draw_prop("door",at,.7,Color(.62,.79,.82) if core.can_use_door(d) else Color(.30,.42,.46))
		if d.id=="ledger_archive":
			draw_line(at+Vector2(-11,-24),at+Vector2(11,-24),Color("ac8963") if not core.can_use_door(d) else Color("284a50"),3)
	for obj in core.room.items:
		if obj.id in ["rf_archive_hatch","rf_ledger_return"]:
			var at:=screen_pos(obj.pos);draw_prop("wheel",at,.48,Color("86a8a1") if core.flags.get(obj.id,false) else Color("d2b17b"))
			glow(at-Vector2(0,20),25,Color("c8bf95"),.6)
		else:draw_item(obj)
	finish_foundry_draw(unshaken)


func draw_foldhammer(e:Dictionary) -> void:
	var pose:int=int(tick*5)%2 if e.state=="patrol" and absf(e.vel.x)>2 else 0
	match e.state:
		"windup":pose=2 if e.cue_hits==1 else 3
		"attack":pose=4
		"reprise":pose=5
		"recover":pose=6
	if e.flash>0 and e.state in ["patrol","recover"]:pose=7
	var boxes:Array=[Rect2(33,126,344,319),Rect2(491,170,377,275),Rect2(935,8,350,437),Rect2(1392,102,290,343),Rect2(31,575,442,278),Rect2(483,578,427,262),Rect2(918,582,410,260),Rect2(1339,518,397,324)]
	var anchors:Array=[Vector2(228,438),Vector2(694,438),Vector2(1084,438),Vector2(1544,438),Vector2(185,835),Vector2(630,833),Vector2(1084,835),Vector2(1577,835)]
	var at:=screen_pos(e.pos+Vector2(15,38));draw_shadow(at,22)
	sheet_pose("foldhammer_poses",boxes[pose],anchors[pose],.165,at,e.face,Color(1.22,1.15,1.02) if e.flash>0 else Color(.83,.89,.87))
	if e.state in ["windup","reprise"]:
		var area:Rect2=core.FOLDHAMMER.cue_rect(e);var warning:=screen_pos(Vector2(area.position.x,area.end.y-1))
		draw_line(warning,warning+Vector2(area.size.x,0),Color("c69967"),2)
		var remaining:int=e.cue_hits-e.strike_index+1
		for n in range(remaining):
			var icon:=at+Vector2((n-(remaining-1)*.5)*8,-79)
			draw_colored_polygon(PackedVector2Array([icon-Vector2(0,4),icon+Vector2(3,0),icon+Vector2(0,4),icon-Vector2(3,0)]),Color("f0c78c"))
	elif e.state=="attack":
		var area:Rect2=core.FOLDHAMMER.strike_rect(e)
		# A low, pixel-edged impact flare occupies the declared ground-stamp height.
		# There is no damaging invisible column above the grounded mallet pose.
		var crest:=PackedVector2Array()
		for unit in [Vector2(0,1),Vector2(.12,.60),Vector2(.04,.29),Vector2(.28,.41),Vector2(.35,0),Vector2(.52,.32),Vector2(.74,.18),Vector2(.84,.55),Vector2(1,1)]:crest.append((screen_pos(area.position)+unit*area.size).round())
		draw_colored_polygon(crest,Color(.81,.68,.43,.23))
		draw_line(screen_pos(Vector2(area.position.x,area.end.y)),screen_pos(area.end),Color("e8d9b3"),2)
