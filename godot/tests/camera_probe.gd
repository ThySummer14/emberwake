extends SceneTree
const Main=preload("res://scripts/main.gd")
const Core=preload("res://scripts/ledger_core.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=Main.new();root.add_child(game);game.set_process(false);game.journey_active=false;game.core=Core.new();game.core.flags={"double_jump":true,"boss_defeated":true,"orchard_beacon":true,"archive_beacon":true,"gallery_beacon":true}
	game.core.enter_room("observatory",Vector2(854,368));game.consume_events()
	var trace:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/route_input_trace.json"));var worst:=0.;var clipped:=0
	for input in trace.input_frames:
		game.core.step(1./60,input);game.consume_events();game.update_camera(1./60)
		if game.core.room_id=="rf_workshop":
			var feet:float=game.core.player.pos.y+24-game.camera.y;worst=maxf(worst,feet)
			if feet>316.001:clipped+=1
	print("ROOT_CAMERA_PROBE max_feet_y=",worst," offscreen_frames=",clipped)
	game.queue_free();quit(1 if clipped>0 else 0)
