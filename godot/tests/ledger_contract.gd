extends SceneTree
const Core=preload("res://scripts/ledger_core.gd")
var passed:=0
var failed:=0
func check(ok:bool,label:String) -> void:
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;print("FAIL ",label)
func _initialize() -> void:
 var c=Core.new()
 check(c.world.size()==14,"candidate adds one room")
 var original_shortcut:bool=c.flags.get("shortcut",false)
 c.enter_room("rf_ledger",Vector2(218,286));c.interact()
 check(c.flags.get("rf_tilu_met",false) and not c.flags.get("mara_gift",false) and c.max_hp==5,"Tilu has explicit topic dispatch without Mara's reward")
 for d in [false,true]:
  for r in [false,true]:
   var n=Core.new();n.flags.rf_delivery_record=d;n.flags.rf_rootledger_read=r;n.talk_tilu()
   check(n.flags.get("rf_tilu_records_told",false)==(d and r),"first meeting evaluates evidence %s/%s"%[d,r])
   var before_hp:int=n.max_hp;n.talk_tilu();check(n.max_hp==before_hp,"repeat topic grants no combat stat")
 c.enter_room("rf_ledger",Vector2(223,552));c.interact()
 check(c.flags.get("rf_archive_hatch",false) and c.flags.get("shortcut",false)==original_shortcut,"local hatch does not open Gatewater gallery")
 c.enter_room("rf_ledger",Vector2(963,552));c.interact()
 check(c.flags.get("rf_ledger_return",false) and c.room.platforms.size()==8,"return grate opens without deleting ceramic")
 check(not c.flags.get("rf_ledger_seal",false),"lever cannot break the ability seal")
 var n=Core.new();n.restore(c.serialize());check(n.flags.get("rf_archive_hatch",false) and n.flags.get("rf_ledger_return",false),"local route flags survive save restore")
 check(not Core.new().flags.get("rf_archive_hatch",false),"fresh journey stays isolated")
 var safe:=true
 for id in c.world:
  for door in c.world[id].doors:
   var target=Core.new();target.enter_room(door.target,door.spawn);target.enemies.clear()
   for frame in range(70):target.step(1./60,{})
   if target.hp<5 or target.player.dead:safe=false;print("UNSAFE ",id," ",door.id)
 check(safe,"all candidate portal spawns settle without damage in no-enemy harness")
 var arrival=Core.new();arrival.enter_room("archive",Vector2(710,362))
 for frame in range(300):arrival.step(1./60,{})
 check(arrival.hp==5,"sheltered Archive arrival survives five seconds with normal enemies")
 print("LEDGER_CONTRACT ",passed," passed; ",failed," failed");quit(1 if failed else 0)
