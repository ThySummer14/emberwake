extends SceneTree
const Core=preload("res://scripts/ledger_core.gd")
var passed:=0
var failed:=0
func check(ok:bool,label:String) -> void:
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;print("FAIL ",label)
func fixture(face:int=1) -> RefCounted:
 var c=Core.new();c.enter_room("rf_ledger",Vector2(1180,286));c.player.invuln=0.;c.player.grounded=true
 var e:Dictionary=c.enemies[0];e.face=face;e.attack_face=face;e.cooldown=0.;return c
func tick(c:RefCounted,n:int,input:Dictionary={}) -> void:
 for i in range(n):c.step(1./60,input);c.events.clear()
func _initialize() -> void:
 for face in [-1,1]:
  var c=fixture(face);var e:Dictionary=c.enemies[0]
  check(e.kind=="rf_foldhammer" and e.hp==5 and e.size==Vector2(30,38),"integrated hammer body and HP facing %d"%face)
  c.player.pos=e.pos+Vector2(15+face*35-7,14);c.player.safe_pos=c.player.pos
  tick(c,1);check(e.state=="windup","visible proximity begins promised strike")
  tick(c,40);check(c.hp==5 and e.state=="windup","forty windup frames do no weapon damage")
  tick(c,9);check(c.hp==4,"active hammer removes exactly one heart")
  var serial:int=e.attack_serial;tick(c,15)
  check(c.hp==4 and e.attack_serial==serial,"normal damage protection prevents multi-tick strike damage")
  var z=fixture(face);var ze:Dictionary=z.enemies[0];ze.state="recover";ze.t=0.;z.player.pos=ze.pos+Vector2(15+face*35-7,14);tick(z,25)
  check(z.hp==5,"resting visible mallet is harmless")
  var b=fixture(face);b.flags.rf_breaker=true;var be:Dictionary=b.enemies[0];be.state="recover";be.t=0.;be.face=face;be.attack_face=face
  b.player.pos=be.pos+Vector2(8,-78);b.player.grounded=false;b.player.vel=Vector2(0,100);b.step(1./60,{"down":true,"dash_press":true});tick(b,30)
  check(be.hp==2 and b.hp==5,"breaker hits hammer once and grants only struck-body grace")
  var g=fixture(face);var ge:Dictionary=g.enemies[0];ge.state="attack";ge.t=0.;ge.breaker_protect=.4;ge.attack_face=face
  g.player.pos=ge.pos+Vector2(15+face*35-7,14);tick(g,1)
  check(g.hp==4,"mallet strike still hurts during body-contact grace")
  var freeze=fixture(face);var fe:Dictionary=freeze.enemies[0];fe.state="windup";fe.t=.5;freeze.hitstop=.05;var old:float=fe.t;tick(freeze,2)
  check(fe.t==old,"real core hitstop freezes hammer promise clock")
 var distant=fixture();tick(distant,300)
 check(distant.enemies[0].pos.x>=1250 and distant.enemies[0].pos.x+30<=1380,"real physics preserves optional encounter patrol bounds")
 var safe=fixture();safe.player.pos=Vector2(218,286);tick(safe,600)
 check(safe.hp==5,"Tilu refuge stays safe through ten seconds of ordinary enemy activity")
 print("LEDGER_COMBAT ",passed," passed; ",failed," failed");quit(1 if failed else 0)
