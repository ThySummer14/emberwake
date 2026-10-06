extends SceneTree
const Main=preload("res://scripts/main.gd")
var passed:=0
var failed:=0
func check(ok:bool,label:String) -> void:
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;print("FAIL ",label)
func key(code:Key) -> InputEventKey:
 var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true;return event
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var game=Main.new();root.add_child(game);game.set_process(false);game.start_game(false)
 check(game.core.room_id=="gate" and not game.core.flags.get("chapter_one",false),"new journey still starts at first lamp with no chapter flags")
 game.core.flags.boss_defeated=true;game.core.flags.orchard_beacon=true;game.core.flags.archive_beacon=true;game.core.flags.gallery_beacon=true
 game.core.enter_room("observatory",Vector2(221,368));game.core.interact();game.consume_events()
 check(game.core.checkpoint.room=="observatory","existing Observatory lamp remains the chapter retry/save anchor")
 var before_hp:int=game.core.hp;var before_sparks:int=game.core.sparks
 game.core.enter_room("observatory",Vector2(742,221));game.core.events.clear();game.core.interact();game.consume_events()
 check(game.mode=="ending" and game.dialog_return=="play","actual first-dawn interaction opens chapter ending and returns to play")
 check(game.dialog.text.contains("观测所右侧下层的铜门，通向根火工坊"),"chapter ending names the real nearby continuation")
 check(not game.dialog.text.contains("仍等待下一次出发"),"chapter ending no longer mislabels the playable workshop as future content")
 check(game.dialog.text.contains("第一章") and game.dialog.text.contains("/ 完"),"first chapter still has its intended conclusion")
 check(game.dialog_action_text()=="E / 空格  继续旅途","ending footer explicitly offers continuation")
 var body_fits:=true
 for line in game.dialog.text.split("\n"):body_fits=body_fits and game.font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x<474
 check(body_fits and game.dialog.text.split("\n").size()<=8,"actual font metrics keep continuation text within the existing panel")
 check(game.font.get_string_size(game.dialog_action_text(),HORIZONTAL_ALIGNMENT_LEFT,-1,10).x<170,"continuation footer fits without changing layout")
 var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Main.SAVE))
 check(saved.flags.get("chapter_one",false) and saved.checkpoint.room=="observatory","ending autosave records completion without moving the checkpoint")
 game._unhandled_input(key(KEY_ENTER))
 check(game.mode=="play" and game.pending.is_empty(),"ordinary confirmation resumes gameplay without buffered actions")
 check(game.core.hp==before_hp and game.core.sparks==before_sparks,"chapter acknowledgment does not alter health or currency")
 game.core.enter_room("observatory",Vector2(854,368));game.core.interact();game.consume_events()
 check(game.core.room_id=="rf_workshop","the named copper door actually leads to the workshop")
 game.write_save();game.mode="title";game.journey_active=false;game.start_game(true)
 check(game.mode=="play" and game.core.room_id=="observatory" and game.core.flags.get("chapter_one",false),"Continue returns to the saved lamp with chapter completion intact")
 game.core.enter_room("observatory",Vector2(742,221));game.core.interact();game.consume_events();game._unhandled_input(key(KEY_SPACE))
 check(game.mode=="play" and game.core.hp==before_hp and game.core.sparks==before_sparks,"repeat conclusion after reload remains harmless and dismissible")
 game.mode="dialog";check(game.dialog_action_text()=="E / 空格  收起","ordinary story dialogues retain their existing close label")
 game.mode="pause";game.choose_menu(4)
 var bytes_before:=FileAccess.get_file_as_bytes(Main.SAVE)
 game.choose_menu(2);game._unhandled_input(key(KEY_ESCAPE))
 check(game.mode=="title" and FileAccess.get_file_as_bytes(Main.SAVE)==bytes_before,"title-owned help remains independent of the completed journey")
 print("HANDOFF_UI_RESULT ",passed," passed; ",failed," failed")
 game.audio.music.stop()
 for voice in game.audio.voices:voice.stop()
 game.queue_free()
 await process_frame
 await process_frame
 quit(1 if failed else 0)
