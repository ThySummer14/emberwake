extends RefCounted
const W=preload("res://scripts/world.gd")
static func rooms() -> Dictionary:
 var seal:Dictionary=W.p(576,310,96,24,"ceramic");seal.seal_id="rf_ledger_seal"
 var grate:Dictionary=W.p(1050,310,100,16,"grate");grate.remove_flag="rf_ledger_return"
 var back:Dictionary=W.door("ledger_workshop",42,310,"rf_workshop",Vector2(1167,286));back.label="返回根火工坊"
 var archive:Dictionary=W.door("ledger_archive",78,576,"archive",Vector2(710,362),"rf_archive_hatch");archive.label="前往浸水档案馆"
 return {"rf_ledger":{"name":"冷名廊","subtitle":"THE COOLED LEDGER","size":Vector2(1440,680),"palette":"ledger","map":Vector2(5,2),
 "platforms":[W.p(0,310,576,24,"metal"),seal,W.p(672,310,378,24,"metal"),grate,W.p(1150,310,290,24,"metal"),W.p(0,576,1440,104),W.p(1110,506,170,12,"cabinet"),W.p(920,436,160,12,"cabinet"),W.p(1090,366,170,12,"cabinet")],"hazards":[],
 "doors":[back,archive],
 "items":[W.item("npc","rf_tilu",225,310,"记薪人 · 缇芦",""),W.item("sign","rf_ledger_seal_note",470,310,"留下的缺口","这些炉砖也刻着相对的凿印。\n下方的旧栓通向档案馆，另一端仍能回到工坊。"),W.item("shortcut","rf_archive_hatch",230,576,"档案馆内栓",""),W.item("shortcut","rf_ledger_return",970,576,"冷柜回程栓",""),W.item("memory","rf_rootledger_read",1390,310,"年轮里的姓名","铜牌已经取走，名字却压进了年轮。\n有一行被反复描深：先照亮回去的路。"),W.item("sign","rf_ledger_racks",865,310,"双胆冷名柜","外胆走水，内胆留名。\n冷却后的隔板，正好能落一双靴子。")],
 "enemies":[W.enemy("rf_foldhammer",1270,310,1250,1380)],"landmark":"ledger"}}
