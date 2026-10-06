extends RefCounted
class_name SealedRoutes
static func materialize(definition:Dictionary,flags:Dictionary) -> Dictionary:
	var room:Dictionary=definition.duplicate(true)
	var solid:Array=[]
	for platform in room.platforms:
		var id:String=platform.get("seal_id","")
		var removal:String=platform.get("remove_flag","")
		if (id.is_empty() or not flags.get(id,false)) and (removal.is_empty() or not flags.get(removal,false)):solid.append(platform)
	room.platforms=solid
	return room
static func crossed_seals(definition:Dictionary,flags:Dictionary,before:Rect2,after:Rect2,breaker:RefCounted) -> Array:
	var result:Array=[]
	for platform in definition.platforms:
		var id:String=platform.get("seal_id","")
		if not id.is_empty() and not flags.get(id,false) and breaker.crossed_seal(before,after,platform.rect):result.append(id)
	return result
