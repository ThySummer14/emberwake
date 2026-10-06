extends SceneTree
const Core=preload("res://scripts/ledger_core.gd")
var passed:=0
var failed:=0
func check(ok:bool,label:String) -> void:
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;print("FAIL ",label)
func tick(c:RefCounted,n:int,input:Dictionary={}) -> void:
 for i in range(n):c.step(1./60,input);c.events.clear()
func _initialize() -> void:
 for action in ["down_sword","ordinary_dash","unowned_down_dash"]:
  var c=Core.new();c.enter_room("rf_ledger",Vector2(609,286));c.enemies.clear();tick(c,3)
  c.step(1./60,{"jump_press":true});tick(c,8)
  var input:Dictionary={"down":action!="ordinary_dash","attack_press":action=="down_sword","dash_press":action!="down_sword"};c.step(1./60,input);tick(c,100)
  check(not c.flags.get("rf_ledger_seal",false) and c.player.pos.y<=286,"only owned breaker opens ceramic, not "+action)
 var no_ability=Core.new();no_ability.enter_room("rf_ledger",Vector2(70,286));no_ability.enemies.clear();tick(no_ability,550,{"right":true})
 check(no_ability.room_id=="rf_ledger" and no_ability.player.pos.y==286,"unopened top route has no accidental lower-level fall")
 var sealed=Core.new();sealed.enter_room("archive",Vector2(710,362));sealed.interact()
 check(sealed.room_id=="archive" and not sealed.flags.get("rf_archive_hatch",false),"earlier Archive visit cannot unlatch from outside")
 for phase in ["rf_ledger_seal","rf_ledger_return","rf_archive_hatch"]:
  var c=Core.new();c.flags.rf_breaker=true;c.flags[phase]=true;c.enter_room("rf_ledger",Vector2(71,552));var data:Dictionary=JSON.parse_string(JSON.stringify(c.serialize()));var restore=Core.new()
  check(restore.restore(data) and restore.flags.get(phase,false),"durable route survives isolated save stage "+phase)
  c.damage_player(99,Vector2.ZERO,true,"pressure");tick(c,150)
  check(c.flags.get(phase,false) and c.flags.rf_breaker and c.hp==5,"death cannot reclose route stage "+phase)
 var both=Core.new();both.flags.rf_delivery_record=true;both.flags.rf_rootledger_read=true;both.flags.rf_archive_hatch=true;both.enter_room("rf_ledger",Vector2(218,286));both.interact()
 var dialog:String=""
 for event in both.events:
  if event.type=="dialog":dialog=event.text
 check(both.flags.get("rf_tilu_records_told",false) and dialog.contains("名字可以先回家"),"first meeting with both records and open hatch chooses strongest topic immediately")
 var prior:Dictionary=both.flags.duplicate(true);var hp:int=both.max_hp;both.events.clear();both.interact()
 check(both.flags==prior and both.max_hp==hp and not both.flags.get("mara_gift",false),"repeated reconciliation neither consumes evidence nor grants duplicate rewards")
 print("LEDGER_GATES ",passed," passed; ",failed," failed");quit(1 if failed else 0)
