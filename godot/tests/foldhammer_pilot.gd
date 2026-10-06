extends SceneTree
const Core=preload("res://scripts/ledger_core.gd")
func trial(delay:int,policy:String) -> Dictionary:
 var c=Core.new();c.enter_room("rf_ledger",Vector2(1170,286));c.player.invuln=0.;c.player.grounded=true;c.flags.rf_breaker=true
 var e:Dictionary=c.enemies[0];var seen:Array=[];var attacked_recover:=false;var old_rest:=false;var patterns:Dictionary={};var attacks:=0
 for n in range(3600):
  if e.dead:return {"delay_ms":delay*1000/60,"policy":policy,"win":true,"seconds":n/60.,"hp":c.hp,"promises_seen":patterns.keys(),"attack_inputs":attacks}
  if c.player.dead:break
  # This projection contains only positions and silhouettes/cue marks actually drawn.
  var raised:bool=e.state in ["windup","reprise"]
  seen.append({"center":e.pos+e.size*.5,"raised":raised,"resting":e.state=="recover","ready":e.state=="patrol","marks":e.cue_hits if e.state=="windup" else 0})
  var observation:Dictionary=seen[maxi(0,seen.size()-1-delay)]
  if observation.marks>0:patterns[observation.marks]=true
  var resting:bool=observation.resting
  if resting and not old_rest:attacked_recover=false
  old_rest=resting
  var offset:Vector2=observation.center-(c.player.pos+Vector2(7,12));var distance:float=absf(offset.x)
  var wanted:=43. if policy=="aggressive" else (45. if resting else (64. if observation.ready else 90.))
  var dir:float=signf(offset.x);var move:=0.
  if distance>wanted+4:move=dir
  elif distance<wanted-4:move=-dir
  var input:Dictionary={"right":move>0,"left":move<0}
  var may_strike:bool=policy=="aggressive" or (resting and not attacked_recover)
  if may_strike and distance<57 and absf(offset.y)<30 and c.player.attack<=0:
   input.attack_press=true;input.right=dir>0;input.left=dir<0;attacked_recover=true;attacks+=1
  c.step(1./60,input);c.events.clear();c.particles.clear()
 return {"delay_ms":delay*1000/60,"policy":policy,"win":false,"seconds":60.,"hp":c.hp,"promises_seen":patterns.keys(),"attack_inputs":attacks}
func _initialize() -> void:
 var rows:Array=[];var failed:=0
 for policy in ["aggressive","cautious"]:
  for delay in [9,15,21]:
   var r:Dictionary=trial(delay,policy);rows.append(r);print("FOLD_POLICY ",JSON.stringify(r))
   if not r.win:failed+=1
 var f:=FileAccess.open("res://tests/foldhammer_policy_results.json",FileAccess.WRITE);f.store_string(JSON.stringify({"scope":"Delayed rendered-cue design probes; not human enjoyment or native graphics","trials":rows},"\t"));f.close();quit(1 if failed else 0)
