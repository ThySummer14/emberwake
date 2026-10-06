extends RefCounted
class_name EmberWorld

static func p(x: float, y: float, w: float, h: float = 24, material: String = "stone") -> Dictionary:
	return {"rect": Rect2(x,y,w,h), "material": material}
static func door(id: String, x: float, y: float, target: String, spawn: Vector2, gate: String = "") -> Dictionary:
	return {"id":id,"pos":Vector2(x,y),"target":target,"spawn":spawn,"gate":gate}
static func item(kind: String, id: String, x: float, y: float, label: String = "", text: String = "") -> Dictionary:
	return {"kind":kind,"id":id,"pos":Vector2(x,y),"label":label,"text":text}
static func enemy(kind: String, x: float, y: float, lo: float, hi: float) -> Dictionary:
	return {"kind":kind,"pos":Vector2(x,y),"lo":lo,"hi":hi}

static func rooms() -> Dictionary:
	return {
	"gate": {
		"name":"潮门旧城", "subtitle":"GATEWATER", "size":Vector2(1120,480),"palette":"rain","map":Vector2(0,1),
		"platforms":[p(0,392,470,88),p(540,392,580,88),p(405,348,94,18),p(545,322,100,18),p(744,330,120,18)],
		"hazards":[Rect2(470,416,70,64)],
		"doors":[door("gate_nave",1064,392,"nave",Vector2(70,368))],
		"items":[item("checkpoint","gate_lamp",156,392,"潮门灯座"),item("sign","first_steps",255,392,"褪色的路牌","A / D 或方向键移动。空格跳跃，松开可跳得更低。\nJ 挥刃，K 或 Shift 冲刺。E 与灯座、路牌和门交互。"),item("memory","gate_memory",780,330,"被淹没的名字","第十七夜。水已经漫过钟楼的门槛。\n如果还有人回来，请替我们点亮归航的灯。")],
		"enemies":[enemy("crab",910,392,860,1010)], "landmark":"gate"},
	"nave": {
		"name":"雨中长廊", "subtitle":"THE RAIN NAVE", "size":Vector2(1344,600),"palette":"rain","map":Vector2(1,1),
		"platforms":[p(0,520,1344,80),p(145,444,170),p(328,374,130),p(485,304,154),p(895,432,150),p(1070,355,135),p(1180,280,164)],
		"hazards":[],
		"doors":[door("nave_gate",42,520,"gate",Vector2(1020,368)),door("nave_orchard",1286,520,"orchard",Vector2(74,388)),door("nave_steps",555,304,"steps",Vector2(70,472)),door("nave_sluice",826,520,"sluice",Vector2(65,386)),door("nave_gallery",1278,280,"gallery",Vector2(1190,396),"shortcut")],
		"items":[item("checkpoint","nave_lamp",450,520,"归航灯座"),item("npc","mara",568,520,"织灯人 · 玛拉","你手里的灯，还记得火的样子。\n东边的铜果园、下方的档案馆、上方的索道，各有一座信号炉。\n让三点火光相遇，守钟人才会为你开门。"),item("sign","map_sign",690,520,"浸水的城区图","Tab 或 M 打开地图。灰色轮廓是尚未抵达的相邻空间。\n每一条路都能回头；新的力量会让旧路变得不同。"),item("relic","nave_relic",1090,355,"铜羽碎片")],
		"enemies":[enemy("crab",180,520,100,310),enemy("warden",1080,520,1000,1220)],"landmark":"nave"},
	"orchard": {
		"name":"铜色果园", "subtitle":"THE COPPER ORCHARD", "size":Vector2(1200,520),"palette":"garden","map":Vector2(2,1),
		"platforms":[p(0,412,270,108),p(342,412,294,108),p(720,412,480,108),p(240,350,130,22,"wood"),p(435,292,150,22,"wood"),p(620,226,110,22,"wood"),p(770,312,150,24),p(946,250,148),p(720,102,150)],
		"hazards":[Rect2(270,458,72,62),Rect2(636,455,84,65)],
		"doors":[door("orchard_nave",40,412,"nave",Vector2(1240,496)),door("orchard_archive",1137,412,"archive",Vector2(70,426)),door("orchard_roost",787,102,"roost",Vector2(70,310),"double_jump")],
		"items":[item("ability","double_jump",671,226,"回声羽","获得「回声羽」。在空中再次按跳跃，可踏响一次残留的回声。\n铜果园上方的旧巢，终于不再遥不可及。"),item("beacon","orchard_beacon",1017,250,"铜果信号炉"),item("sign","orchard_sign",160,412,"园丁的笔记","树不再结果之后，我们把铜铃挂在枝头。\n有风经过，就假装明年仍会丰收。")],
		"enemies":[enemy("crab",460,412,385,600),enemy("moth",820,200,735,1070),enemy("warden",999,412,935,1110)],"landmark":"tree"},
	"roost": {
		"name":"无声的巢", "subtitle":"THE SILENT ROOST", "size":Vector2(720,420),"palette":"garden","map":Vector2(2,0),
		"platforms":[p(0,334,720,86),p(235,260,126),p(407,189,172)],"hazards":[],
		"doors":[door("roost_orchard",40,334,"orchard",Vector2(785,78))],
		"items":[item("memory","roost_memory",478,189,"给未归者的信","父亲，你教我把名字刻进铜片。\n我把所有人的名字都刻完了，却忘了自己的声音。"),item("health","roost_heart",554,334,"心火容器","心火上限增加。愿这盏灯容得下更多明天。")],
		"enemies":[enemy("moth",360,165,230,570)],"landmark":"nest"},
	"sluice": {
		"name":"旧日水闸", "subtitle":"THE OLD SLUICE", "size":Vector2(1320,530),"palette":"deep","map":Vector2(1,2),
		"platforms":[p(0,410,250,120),p(1030,410,290,120),p(235,357,122,22,"metal"),p(420,302,125,22,"metal"),p(610,365,110,22,"metal"),p(803,303,130,22,"metal"),p(980,357,95,22,"metal")],
		"hazards":[Rect2(250,450,780,80)],
		"doors":[door("sluice_nave",42,410,"nave",Vector2(780,496)),door("sluice_well",1252,410,"well",Vector2(70,422))],
		"items":[item("sign","sluice_sign",158,410,"维修铭牌","冲刺可越过水面。每次落地会恢复一次空中冲刺。\n闸门的转动声里，夹着某种活物的呼吸。"),item("relic","sluice_relic",677,365,"铜羽碎片")],
		"enemies":[enemy("moth",486,224,354,650),enemy("moth",883,212,741,1010),enemy("eel",1120,410,1060,1240)],"landmark":"sluice"},
	"well": {
		"name":"沉声井", "subtitle":"THE SUNKEN WELL", "size":Vector2(840,660),"palette":"deep","map":Vector2(2,2),
		"platforms":[p(0,446,232,32),p(0,612,840,48),p(296,535,120),p(450,460,120),p(600,385,160),p(432,310,120),p(263,235,128),p(430,160,160),p(620,95,220)],
		"hazards":[],
		"doors":[door("well_sluice",40,446,"sluice",Vector2(1208,386)),door("well_archive",774,95,"archive",Vector2(795,426))],
		"items":[item("checkpoint","well_lamp",147,612,"井底灯座"),item("memory","well_memory",72,612,"守闸人的遗言","我不是没有开闸。\n我只是听见水里有人叫我的名字。")],
		"enemies":[enemy("eel",546,612,445,715),enemy("moth",650,272,550,740)],"landmark":"well"},
	"archive": {
		"name":"浸水档案馆", "subtitle":"THE DROWNED ARCHIVE", "size":Vector2(1040,560),"palette":"deep","map":Vector2(3,2),
		"platforms":[p(0,450,1040,110),p(185,377,146),p(400,306,126),p(565,237,136),p(747,174,185),p(800,375,136)],
		"hazards":[],
		"doors":[door("archive_orchard",40,450,"orchard",Vector2(1090,388)),door("archive_well",811,450,"well",Vector2(735,71))],
		"items":[item("beacon","archive_beacon",835,174,"铭名信号炉"),item("sign","archive_sign",134,450,"市民登记册","姓名：不详。职业：灯火保管员。\n余下心愿：让回家的人看见路。"),item("relic","archive_relic",620,237,"铜羽碎片")],
		"enemies":[enemy("warden",437,450,310,620),enemy("moth",610,140,525,880),enemy("crab",957,450,890,1010)],"landmark":"archive"},
	"steps": {
		"name":"点灯者阶梯", "subtitle":"LAMPLIGHTER STEPS", "size":Vector2(880,700),"palette":"rain","map":Vector2(1,0),
		"platforms":[p(0,496,230,36),p(0,660,880,40),p(235,584,120),p(255,510,105),p(375,483,112),p(530,407,140),p(362,330,140),p(194,257,130),p(353,184,143),p(558,116,322)],
		"hazards":[],
		"doors":[door("steps_nave",42,496,"nave",Vector2(515,280)),door("steps_gallery",812,116,"gallery",Vector2(62,396))],
		"items":[item("sign","steps_sign",120,496,"阶梯上的划痕","每天七百二十四阶。每天一百九十盏灯。\n没有人问过，她为何仍愿意爬上去。"),item("relic","steps_relic",420,184,"铜羽碎片")],
		"enemies":[enemy("moth",460,252,350,650),enemy("crab",679,116,595,780)],"landmark":"tower"},
	"gallery": {
		"name":"断索回廊", "subtitle":"THE CABLE GALLERY", "size":Vector2(1320,540),"palette":"rain","map":Vector2(3,0),
		"platforms":[p(0,420,280,120),p(1120,420,200,120),p(264,360,125,20,"wood"),p(449,303,125,20,"wood"),p(638,350,130,20,"wood"),p(835,281,150,24),p(996,356,138,24)],
		"hazards":[Rect2(280,460,840,80)],
		"doors":[door("gallery_steps",40,420,"steps",Vector2(766,92)),door("gallery_hall",1253,420,"hall",Vector2(70,368)),door("gallery_nave",1190,420,"nave",Vector2(1230,256))],
		"items":[item("beacon","gallery_beacon",908,281,"高空信号炉"),item("shortcut","gallery_shortcut",1150,420,"回廊升降机","旧索重新绷紧。雨中长廊的捷径已经打开。")],
		"enemies":[enemy("moth",497,202,320,620),enemy("moth",950,196,785,1100)],"landmark":"cable"},
	"hall": {
		"name":"守钟人前厅", "subtitle":"THE BELL ANTECHAMBER", "size":Vector2(880,480),"palette":"gold","map":Vector2(4,0),
		"platforms":[p(0,392,880,88)],"hazards":[],
		"doors":[door("hall_gallery",42,392,"gallery",Vector2(1210,396)),door("hall_boss",811,392,"boss",Vector2(90,388),"beacons")],
		"items":[item("checkpoint","hall_lamp",333,392,"守钟灯座"),item("sign","hall_warning",570,392,"钟门铭文","三座信号炉，需要三次回应。\n刀刃无法切断记忆。可有些记忆，必须学会放手。")],
		"enemies":[],"landmark":"bellgate"},
	"boss": {
		"name":"失声钟庭", "subtitle":"COURT OF THE VOICELESS", "size":Vector2(1120,520),"palette":"gold","map":Vector2(5,0),
		"platforms":[p(0,412,1120,108),p(189,338,125),p(810,338,125)],"hazards":[],
		"doors":[door("boss_hall",40,412,"hall",Vector2(765,368),"boss_exit"),door("boss_observatory",1056,412,"observatory",Vector2(70,368),"boss_defeated")],
		"items":[],"enemies":[enemy("boss",782,412,170,950)],"landmark":"greatbell"},
	"observatory": {
		"name":"明日观测所", "subtitle":"THE MORROW OBSERVATORY", "size":Vector2(960,480),"palette":"dawn","map":Vector2(6,0),
		"platforms":[p(0,392,960,88),p(410,315,182),p(639,245,224)],"hazards":[],
		"doors":[door("observatory_boss",42,392,"boss",Vector2(1010,388))],
		"items":[item("checkpoint","observatory_lamp",228,392,"曙光灯座"),item("ending","first_dawn",749,245,"第一束曙光","钟声没有带回死去的人。\n它只是让仍然活着的人，终于知道彼此还在。\n\n第一章 · 潮门的回声 / 完\n\n观测所右侧下层的铜门，通向根火工坊。\n收起这段回声，就可以继续旅途。")],
		"enemies":[],"landmark":"observatory"}
	}
