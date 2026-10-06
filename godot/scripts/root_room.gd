extends RefCounted
const W=preload("res://scripts/world.gd")
static func rooms() -> Dictionary:
	var seal:Dictionary=W.p(640,310,96,24,"ceramic");seal.seal_id="rf_workshop_seal"
	var upper:Dictionary=W.door("rf_hoist_down",230,310,"rf_workshop",Vector2(223,576),"rf_workshop_hoist");upper.label="乘索下行"
	var lower:Dictionary=W.door("rf_hoist_up",230,600,"rf_workshop",Vector2(223,286),"rf_workshop_hoist");lower.label="乘索返回工坊"
	return {"rf_workshop":{"name":"根火工坊","subtitle":"THE ROOTFOUNDRY WORKSHOP","size":Vector2(1280,680),"palette":"foundry","map":Vector2(6,1),
	"platforms":[W.p(0,310,640,24,"metal"),seal,W.p(736,310,544,24,"metal"),W.p(0,600,1280,80)],"hazards":[],
	"doors":[W.door("rf_observatory",42,310,"observatory",Vector2(854,368)),upper,lower],
	"items":[W.item("checkpoint","rf_workshop_lamp",110,310,"留手灯座"),W.item("ability","rf_breaker",390,310,"落砧环","把重量交给铜环，别把刀刃当成锤子。\n\n空中按住下方向，再按冲刺：落砧。\n象牙色炉砖的中缝会为你打开。\n空中下方向 + 挥刃，仍然是下劈反弹。"),W.item("sign","rf_seal_note",582,310,"见证炉砖","两枚凿印朝向中缝。\n只有落砧能释放下方的压力。\n破开后，旧索可以带你回来。"),W.item("shortcut","rf_workshop_hoist",145,600,"回程绞盘","旧索重新绷紧。升降门可以往返了。"),W.item("memory","rf_delivery_record",1090,310,"无重的交货单","最后一车没有木头，只有铜牌。\n记薪人把重量一栏留了空白，\n又在空白处抄了一遍所有人的名字。"),W.item("sign","rf_boundary",1212,310,"铸所深处","这段后续区域尚未开放。\n当前可沿原路，或从下方旧索返回观测所。")],
	"enemies":[W.enemy("rf_carrier",920,310,820,1110)],"pressure_cells":[{"id":"rf_workshop_pressure","lane":Rect2(470,552,110,48)}],"landmark":"rootfoundry"}}
