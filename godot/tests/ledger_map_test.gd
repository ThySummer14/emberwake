extends SceneTree
const Main=preload("res://tests/main_capture.gd")
const Core=preload("res://scripts/ledger_core.gd")
var passed:=0
var failed:=0
func check(ok:bool,label:String) -> void:
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;print("FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var game=Main.new();root.add_child(game);game.set_process(false);game.core=Core.new();game.core.enter_room("rf_ledger",Vector2(225,286));game.core.visited=["gate","nave","orchard","archive","boss","observatory","rf_workshop","rf_ledger"];game.core.flags.rf_tilu_met=true;game.mode="map";game.camera=Vector2(0,90);game.room_title=0;game.fade=0
 var layout:Dictionary=game.map_layout();var complete:=true
 for id in game.core.world:
  if not layout.has(id):complete=false
 check(complete,"every implemented room has a safe map layout")
 game.recorded.clear();game._draw()
 var names:Array=[]
 for command in game.recorded:
  if command.op=="text":names.append(command.text)
 check(names.has("冷名廊") and not names.has("无声的巢"),"new current room labels correctly without exposing hidden roost")
 game.core.world.future_fixture=game.core.world.rf_ledger.duplicate(true);game.core.world.future_fixture.map=Vector2(8,4)
 check(game.map_layout().has("future_fixture"),"authored future room data cannot crash a missing map dictionary entry")
 game.core.world.erase("future_fixture")
 game.core.flags.rf_ledger_seal=true;game.core.flags.rf_ledger_return=true;game.core.flags.rf_archive_hatch=true
 game.recorded.clear();game._draw()
 var f:=FileAccess.open("res://tests/render_ledger_map.json",FileAccess.WRITE);f.store_string(JSON.stringify(game.recorded));f.close()
 check(game.core.ROUTES.materialize(game.core.world.rf_ledger,game.core.flags).platforms.size()==7,"map geometry reflects removed ceramic and opened return grate")
 game.queue_free();print("LEDGER_MAP ",passed," passed; ",failed," failed");quit(1 if failed else 0)
