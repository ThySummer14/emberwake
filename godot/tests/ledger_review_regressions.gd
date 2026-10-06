extends SceneTree
const Core=preload("res://scripts/ledger_core.gd")
var passed:=0
var failed:=0
func check(ok:bool,label:String) -> void:
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;print("FAIL ",label)
func strike_at(face:int,relative_y:float) -> RefCounted:
 var c=Core.new();c.enter_room("rf_ledger",Vector2(1180,286));var e:Dictionary=c.enemies[0]
 e.state="attack";e.t=0.;e.attack_face=face;e.face=face;e.vel=Vector2.ZERO
 var feet:float=e.pos.y+38
 c.player.pos=Vector2(e.pos.x+15+face*35-7,feet+relative_y);c.player.invuln=0.;c.player.vel=Vector2.ZERO;c.player.grounded=false
 c.step(1./60,{})
 return c
func talk(c:RefCounted) -> String:
 c.events.clear();c.talk_tilu()
 for event in c.events:
  if event.type=="dialog":return event.text
 return ""
func _initialize() -> void:
 for face in [-1,1]:
  var above=strike_at(face,-76.)
  check(above.hp==5,"exact floating-hit repro now clears entire impact, facing %d"%face)
  var lip=strike_at(face,-47.)
  check(lip.hp==5,"feet just above visible low impact remain unharmed, facing %d"%face)
  var inside=strike_at(face,-43.)
  check(inside.hp==4,"actual low impact still damages feet inside it, facing %d"%face)
  var ground=strike_at(face,-24.)
  check(ground.hp==4,"grounded mallet contact still damages, facing %d"%face)
  var box:Rect2=above.FOLDHAMMER.strike_rect(above.enemies[0])
  check(box.size==Vector2(37,22) and box.end.y==310,"impact height remains aligned with floor, facing %d"%face)
 var c=Core.new();c.flags.rf_delivery_record=true;c.flags.rf_rootledger_read=true;talk(c)
 var closed:String=talk(c);check(closed.contains("等那扇旧栓打开") and not closed.contains("旧栓通了"),"closed-hatch repeat correctly waits")
 c.flags.rf_archive_hatch=true
 var opened:String=talk(c);check(not opened.contains("等那扇旧栓打开") and opened.contains("可以送回档案馆") and opened.contains("旧栓通了"),"opened-hatch repeat cannot contradict its acknowledgment")
 var restored=Core.new();restored.restore(JSON.parse_string(JSON.stringify(c.serialize())))
 check(not talk(restored).contains("等那扇旧栓打开"),"opened-hatch dialogue remains coherent after reload")
 print("LEDGER_REVIEW_REGRESSIONS ",passed," passed; ",failed," failed");quit(1 if failed else 0)
