extends SceneTree
const Core=preload("res://scripts/ledger_core.gd")
var passed:=0
var failed:=0
func check(ok:bool,label:String) -> void:
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;print("FAIL ",label)
func step(c:RefCounted,n:int,input:Dictionary={}) -> void:
 for i in range(n):c.step(1./60,input);c.events.clear()
func walk(c:RefCounted,x:float) -> bool:
 for i in range(650):
  if absf(c.player.pos.x-x)<4:return true
  c.step(1./60,{"right":c.player.pos.x<x,"left":c.player.pos.x>x});c.events.clear()
 return false
func jump_to(c:RefCounted,x:float,y:float) -> bool:
 step(c,10)
 c.step(1./60,{"jump_press":true,"right":x>c.player.pos.x,"left":x<c.player.pos.x})
 for i in range(90):
  c.step(1./60,{"right":c.player.pos.x<x-3,"left":c.player.pos.x>x+3});c.events.clear()
  if c.player.grounded and absf(c.player.pos.y+24-y)<1 and absf(c.player.pos.x-x)<15:return true
 return false
func _initialize() -> void:
 var c=Core.new();c.flags.rf_breaker=true;c.flags.rf_workshop_seal=true;c.flags.rf_workshop_hoist=true
 c.enter_room("rf_workshop",Vector2(1167,286));step(c,2);walk(c,1213);c.interact();c.events.clear()
 check(c.room_id=="rf_ledger","normal workshop door enters gallery")
 c.enemies.clear();check(walk(c,218),"entry reaches quiet Tilu bench");c.interact();c.events.clear()
 check(c.flags.get("rf_tilu_met",false),"ordinary interaction starts character topic")
 check(walk(c,609),"upper path reaches ceramic")
 c.step(1./60,{"jump_press":true});step(c,8);c.step(1./60,{"down":true,"dash_press":true});step(c,70)
 check(c.flags.get("rf_ledger_seal",false) and c.player.grounded and c.player.pos.y==552,"breaker opens seal and lands on safe service floor")
 check(walk(c,963),"service floor reaches return control");c.interact();c.events.clear()
 check(c.flags.get("rf_ledger_return",false),"return control opens physical grate")
 check(walk(c,1084),"approach is outside first cabinet overhang")
 check(jump_to(c,1146,506),"ordinary single jump reaches first cabinet tread")
 print("FIRST ",c.player.pos)
 check(jump_to(c,1049,436),"ordinary single jump reaches second broad tread")
 print("SECOND ",c.player.pos)
 check(jump_to(c,1110,366),"ordinary single jump reaches third broad tread")
 print("THIRD ",c.player.pos)
 check(jump_to(c,1190,310),"ordinary single jump exits opened return grate")
 print("TOP ",c.player.pos)
 check(c.hp==5 and not c.flags.get("double_jump",false),"whole staircase needs no second jump or damage boost")
 check(walk(c,609),"upper route returns to the broken seal");step(c,60)
 check(c.player.pos.y==552,"permanent broken seal still descends")
 check(walk(c,223),"service route reaches inside Archive latch");c.interact();c.events.clear()
 check(walk(c,71),"latch has a separate readable doorway");c.interact();c.events.clear();step(c,150)
 check(c.room_id=="archive" and c.hp==5,"Archive link settles without immediate enemy damage")
 c.interact();c.events.clear();step(c,3)
 check(c.room_id=="rf_ledger" and c.player.pos.y==552,"opened Archive link is reciprocal")
 print("LEDGER_TRAVERSAL ",passed," passed; ",failed," failed");quit(1 if failed else 0)
