extends SceneTree
const Core=preload("res://scripts/ledger_core.gd")
var passed:=0
var failed:=0
var trace:Array=[]
func check(ok:bool,label:String) -> void:
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;print("FAIL ",label)
func step(c:RefCounted,input:Dictionary={}) -> void:
 trace.append(input.duplicate());c.step(1./60,input);c.events.clear();c.particles.clear()
func tick(c:RefCounted,n:int,input:Dictionary={}) -> void:
 for i in range(n):step(c,input)
func walk(c:RefCounted,x:float) -> bool:
 for i in range(700):
  if absf(c.player.pos.x-x)<4:return true
  step(c,{"right":c.player.pos.x<x,"left":c.player.pos.x>x})
 return false
func jump_to(c:RefCounted,x:float,y:float) -> bool:
 tick(c,10);step(c,{"jump_press":true,"right":x>c.player.pos.x,"left":x<c.player.pos.x})
 for i in range(90):
  step(c,{"right":c.player.pos.x<x-3,"left":c.player.pos.x>x+3})
  if c.player.grounded and absf(c.player.pos.y+24-y)<1 and absf(c.player.pos.x-x)<15:return true
 return false
func fight(c:RefCounted) -> bool:
 var e:Dictionary=c.enemies[0];var observations:Array=[];var attacked:=false;var previous_rest:=false
 for n in range(2400):
  if e.dead:return true
  if c.player.dead:return false
  observations.append({"center":e.pos+e.size*.5,"resting":e.state=="recover","ready":e.state=="patrol"})
  var obs:Dictionary=observations[maxi(0,observations.size()-10)]
  if obs.resting and not previous_rest:attacked=false
  previous_rest=obs.resting
  var delta:Vector2=obs.center-(c.player.pos+Vector2(7,12));var distance:float=absf(delta.x)
  var wanted:float=45. if obs.resting else (64. if obs.ready else 90.)
  var direction:float=signf(delta.x);var move:=0.
  if distance>wanted+4:move=direction
  elif distance<wanted-4:move=-direction
  var input:Dictionary={"right":move>0,"left":move<0}
  if obs.resting and not attacked and distance<57 and absf(delta.y)<30 and c.player.attack<=0:
   input.attack_press=true;input.right=direction>0;input.left=direction<0;attacked=true
  step(c,input)
 return false
func _initialize() -> void:
 var c=Core.new();c.flags={"boss_defeated":true,"double_jump":false,"orchard_beacon":true,"archive_beacon":true,"gallery_beacon":true,"rf_breaker":true,"rf_delivery_record":true,"rf_workshop_seal":true,"rf_workshop_hoist":true}
 c.enter_room("rf_workshop",Vector2(1167,286));tick(c,3)
 check(walk(c,1213),"prior workshop route reaches adjacent gallery doorway");step(c,{"interact_press":true})
 check(c.room_id=="rf_ledger" and c.hp==5,"ordinary door enters ledger safely")
 check(walk(c,218),"quiet gallery entry reaches the working tallykeeper");step(c,{"interact_press":true})
 check(c.flags.get("rf_tilu_delivery_told",false),"workshop record creates a specific first conversation")
 check(walk(c,1170),"intact upper gallery reaches optional encounter without breaker")
 check(fight(c),"delayed visible-pose policy defeats the real optional hammer")
 check(c.hp==5,"cautious encounter needs no damage boost or assist")
 check(walk(c,1383),"the record beyond the encounter is reachable");step(c,{"interact_press":true})
 check(c.flags.get("rf_rootledger_read",false),"retained names are collected by ordinary interaction")
 check(walk(c,218),"backtracking returns to the same character");step(c,{"interact_press":true})
 check(c.flags.get("rf_tilu_records_told",false) and c.max_hp==5,"both records produce a durable character beat without a stat bribe")
 check(walk(c,609),"the ceramic seam remains a deliberate descent")
 step(c,{"jump_press":true});tick(c,8);step(c,{"down":true,"dash_press":true});tick(c,70)
 check(c.flags.get("rf_ledger_seal",false) and c.player.pos.y==552,"normal breaker opens the service path")
 check(walk(c,963),"safe lower floor reaches the physical return control");step(c,{"interact_press":true})
 check(c.flags.get("rf_ledger_return",false),"lower control opens the return grate")
 check(walk(c,1084) and jump_to(c,1146,506) and jump_to(c,1049,436) and jump_to(c,1110,366) and jump_to(c,1190,310),"the full broad-tread return is reachable with ordinary single jumps")
 check(c.hp==5 and not c.flags.double_jump,"return traversal does not depend on damage or double jump")
 check(walk(c,609),"revisited upper route reaches the persistent opening");tick(c,60)
 check(walk(c,223),"service route reaches the inside latch");step(c,{"interact_press":true})
 check(c.flags.get("rf_archive_hatch",false) and not c.flags.get("shortcut",false),"new world link never toggles the old gallery shortcut")
 check(walk(c,71),"inside latch leads to a separate doorway");step(c,{"interact_press":true});tick(c,150)
 check(c.room_id=="archive" and c.hp==5,"actual return to the old Archive has a sheltered landing")
 var saved:Dictionary=JSON.parse_string(JSON.stringify(c.serialize()));var restored=Core.new();check(restored.restore(saved) and restored.flags.get("rf_tilu_records_told",false) and restored.flags.get("rf_archive_hatch",false),"story and opened world topology survive real serialized restoration")
 var file:=FileAccess.open("res://tests/ledger_full_input_trace.json",FileAccess.WRITE);file.store_string(JSON.stringify({"start_room":"rf_workshop","start_pos":[1167,286],"initial_flags":{"boss_defeated":true,"double_jump":false,"orchard_beacon":true,"archive_beacon":true,"gallery_beacon":true,"rf_breaker":true,"rf_delivery_record":true,"rf_workshop_seal":true,"rf_workshop_hoist":true},"input_frames":trace,"expected_room":c.room_id,"expected_hp":c.hp}));file.close()
 print("LEDGER_FULL_TOUR ",passed," passed; ",failed," failed; frames=",trace.size(),"; hp=",c.hp);quit(1 if failed else 0)
