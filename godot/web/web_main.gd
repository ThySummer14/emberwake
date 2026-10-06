extends "res://scripts/main.gd"

# The Web edition adapts browser input and lifecycle; the 0.8.1 simulation stays unchanged.
const WEB_ACTIONS=["left","right","up","down","jump","attack","dash","interact","heal","map","pause","mute"]
var web_window
var web_callback
var web_held: Dictionary={}
var web_last_status: String=""
var web_save_count:=0

func _ready() -> void:
	super._ready()
	if OS.has_feature("web"):
		web_window=JavaScriptBridge.get_interface("window")
		web_callback=JavaScriptBridge.create_callback(_web_input)
		web_window.emberwakeInput=web_callback
		_publish_status()

func _web_input(args: Array) -> void:
	if args.is_empty() or not args[0] is String:return
	var action: String=args[0]
	if action=="blur":
		_release_web_inputs(true)
		if mode=="play":
			mode="pause"
			selected=0
		if journey_active:write_save()
		_publish_status()
		return
	if action.begins_with("menu:"):
		if mode not in ["title","pause"]:return
		var suffix:=action.trim_prefix("menu:")
		if not suffix.is_valid_int():return
		var index:=suffix.to_int()
		if index<0 or index>=menu_options().size():return
		_release_web_inputs()
		choose_menu(index)
		_publish_status()
		return
	if action not in WEB_ACTIONS or args.size()!=2 or not args[1] is bool:return
	var pressed:bool=args[1]
	if pressed==bool(web_held.get(action,false)):return
	web_held[action]=pressed
	var event:=InputEventAction.new()
	event.action=action
	event.pressed=pressed
	event.strength=1.0 if pressed else 0.0
	Input.parse_input_event(event)

func _release_web_inputs(all_actions:bool=false) -> void:
	for action in WEB_ACTIONS:
		if all_actions or bool(web_held.get(action,false)):
			Input.action_release(action)
	web_held.clear()
	pending.clear()

func write_save() -> void:
	super.write_save()
	if journey_active and save_error.is_empty():web_save_count+=1
	_publish_status()

func _process(delta:float) -> void:
	var prior_mode:=mode
	super._process(delta)
	if prior_mode!=mode:_release_web_inputs()
	_publish_status()

func _notification(what:int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_web_inputs(true)
		if core!=null and journey_active:write_save()
	super._notification(what)

func _publish_status() -> void:
	if web_window==null or core==null:return
	var state:Dictionary={"mode":mode,"options":menu_options() if mode in ["title","pause"] else [],"selected":selected,"dialog":dialog if mode in ["dialog","ending"] else {},"save_error":save_error,"save_count":web_save_count,"save_exists":save_exists,"persistent":OS.is_userfs_persistent(),"sound":audio.enabled}
	var encoded:=JSON.stringify(state)
	if encoded==web_last_status:return
	web_last_status=encoded
	web_window.emberwakeState(encoded)
