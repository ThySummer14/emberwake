extends SceneTree
const Core=preload("res://scripts/ledger_core.gd")
const Main=preload("res://scripts/main.gd")
var pass_count:=0
var fail_count:=0
func check(condition:bool,name:String) -> void:
	if condition:pass_count+=1;print("PASS ",name)
	else:fail_count+=1;print("FAIL ",name)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var world=Core.new().world
	var safe_spawns:=true
	for source in world:
		for d in world[source].doors:
			var c=Core.new();c.enter_room(d.target,d.spawn);c.enemies.clear()
			for i in range(180):c.step(1./60,{});c.events.clear();c.particles.clear()
			if c.hp!=5 or not c.player.grounded:
				safe_spawns=false;print("BAD_SPAWN ",d.id," ",c.player.pos," hp=",c.hp)
	check(safe_spawns,"every actual door spawn settles safely without input")
	var c=Core.new();c.flags.shortcut=true;c.enter_room("nave",Vector2(1271,256));c.enemies.clear();c.interact();c.enemies.clear()
	for i in range(180):c.step(1./60,{})
	check(c.room_id=="gallery" and c.hp==5 and c.player.grounded,"unlocked Nave-to-Gallery shortcut is a safe landing")
	c.enter_room("gallery",Vector2(900,396));c.enemies.clear()
	for i in range(180):c.step(1./60,{})
	check(c.hp==4 and not c.player.dead and c.player.grounded,"unexpected unsafe entry recovers once to validated ground")
	var game=Main.new();root.add_child(game);game.set_process(false);game.save_exists=false
	# Reproduce a real native mouse event at logical title coordinates.
	var motion:=InputEventMouseMotion.new();motion.position=Vector2(260,180);motion.global_position=motion.position
	root.push_input(motion)
	root.canvas_transform=Transform2D(0,game.get_global_mouse_position()-Vector2(260,180))
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=Vector2(260,180);event.global_position=event.position
	game._unhandled_input(event)
	check(game.mode=="play" and game.journey_active and not game.confirm_new,"one mouse click starts exactly one menu action")
	game.core.sparks=77;game.core.flags.double_jump=true;game.mode="pause";game.choose_menu(0)
	check(game.core.sparks==77 and game.core.flags.double_jump,"pause resume cannot activate a hidden New Game confirmation")
	game.write_save();game.queue_free()
	game.mode="title";game.save_exists=false;game.selected=0
	var down:=InputEventJoypadButton.new();down.pressed=true;down.button_index=JOY_BUTTON_DPAD_DOWN
	game._unhandled_input(down)
	check(game.selected==1 and game.mode=="title","controller D-pad navigates menu without activating")
	var up:=InputEventJoypadButton.new();up.pressed=true;up.button_index=JOY_BUTTON_DPAD_UP
	game._unhandled_input(up)
	check(game.selected==0 and game.mode=="title","controller up returns selection without confirming")
	check(InputMap.action_has_event("up",up) and not InputMap.action_has_event("interact",up),"controller directional attack and interaction bindings are distinct")
	var fresh=Main.new();root.add_child(fresh);fresh.set_process(false);fresh.save_exists=true;fresh.mode="title";fresh.choose_menu(2)
	check(fresh.mode=="dialog" and not fresh.journey_active,"title-owned help never activates an unstarted journey")
	fresh._notification(Main.NOTIFICATION_WM_CLOSE_REQUEST)
	var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Main.SAVE))
	check(saved.sparks==77 and saved.flags.double_jump,"closing title help preserves existing save")
	print("REGRESSION_RESULT ",pass_count," passed; ",fail_count," failed")
	fresh.queue_free();quit(1 if fail_count else 0)
