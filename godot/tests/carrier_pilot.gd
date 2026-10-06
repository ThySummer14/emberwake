extends SceneTree
const Core=preload("res://scripts/ledger_core.gd")
var results:Array=[]
func _initialize() -> void:
	for delay in [9,15,21]:
		var c=Core.new();c.enter_room("rf_workshop",Vector2(760,286));c.player.invuln=0;c.flags.double_jump=true
		var e:Dictionary=c.enemies[0];e.cooldown=0.;var observations:Array=[];var frames:=0;var hits:=0;var prior_hp:int=c.hp
		for n in range(2400):
			frames=n+1
			if e.dead or c.player.dead:break
			observations.append({"center":e.pos+e.size/2,"raised":e.state=="windup","stuck":e.state=="recover"})
			var obs:Dictionary=observations[maxi(0,observations.size()-1-delay)]
			var delta:Vector2=obs.center-(c.player.pos+Vector2(7,12));var input:Dictionary={"right":delta.x>46,"left":delta.x< -46}
			if absf(delta.x)<58 and absf(delta.y)<37 and c.player.attack<=0:
				input.attack_press=true;input.right=delta.x>0;input.left=delta.x<0
			if obs.raised and c.player.grounded and absf(delta.x)<110:input.jump_press=true
			if not c.player.grounded and delta.y>17 and absf(delta.x)<25:input.down=true;input.attack_press=c.player.attack<=0
			c.step(1./60,input);c.events.clear();c.particles.clear()
			if c.hp<prior_hp:hits+=prior_hp-c.hp
			prior_hp=c.hp
		var row:Dictionary={"initial_state":"alert after ordinary approach","reaction_ms":delay*1000/60,"victory":e.dead,"death":c.player.dead,"seconds":snappedf(frames/60.,.01),"hits_taken":hits,"scope":"Delayed visible pose/position encoding; no enemy timers, no assist/invulnerability, not human feel"}
		results.append(row);print("CARRIER_POLICY ",row)
	var f:=FileAccess.open("res://tests/carrier_results.json",FileAccess.WRITE);f.store_string(JSON.stringify(results,"\t"));f.close();quit()
