extends RefCounted
# Root-bound stamping mallet. target is player-center minus enemy-center.
# The caller owns position, vertical velocity, physics, HP, contact and damage.
const WINDUP := 0.78
const ACTIVE := 0.14
const REPRISE := 0.46
const RECOVERY := 0.90
const FACE_WINDOW := 0.20
const REST := 0.55
const PATROL_SPEED := 18.0
const STRIKE_SIZE := Vector2(37, 22) # Damage is the low visible ground impact, not an invisible falling column.
const STRIKE_REACH := 45.0 # Measured from body center to the visible hammer tip.

static func initialize(e: Dictionary) -> void:
	e.state = "patrol"
	e.t = 0.0
	e.cooldown = maxf(0.0, float(e.get("cooldown", REST)))
	e.face = -1 if int(e.get("face", 1)) < 0 else 1
	e.attack_face = e.face
	e.next_hits = 1
	e.cue_hits = 0
	e.strike_index = 0
	e.attack_serial = 0
	e.vel.x = 0.0

static func tick(e: Dictionary, dt: float, target: Vector2) -> void:
	# Hitstop must not turn, consume cooldown, or cross a state boundary.
	if dt <= 0.0:
		return
	if _disabled(e):
		e.vel.x = 0.0
		e.cue_hits = 0
		e.strike_index = 0
		return
	e.cooldown = maxf(0.0, e.cooldown - dt)
	var old_time: float = e.t
	e.t += dt
	match e.state:
		"patrol":
			e.cue_hits = 0
			e.strike_index = 0
			_patrol(e, dt)
			if absf(target.x) <= 70.0 and absf(target.y) <= 46.0 and e.cooldown <= 0.0:
				e.cue_hits = e.next_hits
				e.next_hits = 3 - e.next_hits
				e.strike_index = 1
				_face_target(e, target)
				_enter(e, "windup")
		"windup":
			e.vel.x = 0.0
			if old_time < FACE_WINDOW:
				_face_target(e, target)
			e.face = e.attack_face
			if e.t + 0.000001 >= WINDUP:
				_strike(e)
		"attack":
			e.vel.x = 0.0
			e.face = e.attack_face
			if e.t + 0.000001 >= ACTIVE:
				if e.strike_index < e.cue_hits:
					e.strike_index += 1
					_enter(e, "reprise")
				else:
					_enter(e, "recover")
		"reprise":
			e.vel.x = 0.0
			e.face = e.attack_face
			if e.t + 0.000001 >= REPRISE:
				_strike(e)
		"recover":
			e.vel.x = 0.0
			e.face = e.attack_face
			if e.t + 0.000001 >= RECOVERY:
				_enter(e, "patrol")
				e.cooldown = REST
				e.cue_hits = 0
				e.strike_index = 0

static func strike_rect(e: Dictionary) -> Rect2:
	if _disabled(e) or e.get("state", "patrol") != "attack":
		return Rect2()
	return cue_rect(e)

# Same low, feet-anchored impact footprint for both warning stages and active strikes.
# This helper never implies damage; only strike_rect is a damaging footprint.
static func cue_rect(e: Dictionary) -> Rect2:
	if _disabled(e) or e.get("state", "patrol") not in ["windup", "attack", "reprise"]:
		return Rect2()
	var offset_x: float = e.size.x * 0.5 + (STRIKE_REACH - STRIKE_SIZE.x if e.attack_face > 0 else -STRIKE_REACH)
	return Rect2(e.pos + Vector2(offset_x, e.size.y - STRIKE_SIZE.y), STRIKE_SIZE)

static func cue_progress(e: Dictionary) -> float:
	if _disabled(e):
		return 0.0
	if e.get("state", "patrol") == "windup":
		return clampf(e.t / WINDUP, 0.0, 1.0)
	if e.get("state", "patrol") == "reprise":
		return clampf(e.t / REPRISE, 0.0, 1.0)
	return 0.0

# Explicit caller-owned interruptions cancel the promise and pay full recovery.
# Ordinary flash/knockback does not cancel or reroll an announced sequence.
static func cancel(e: Dictionary) -> void:
	_enter(e, "recover")
	e.cue_hits = 0
	e.strike_index = 0

static func _disabled(e: Dictionary) -> bool:
	return bool(e.get("dead", false)) or int(e.get("hp", 1)) <= 0

static func _face_target(e: Dictionary, target: Vector2) -> void:
	if not is_zero_approx(target.x):
		e.face = 1 if target.x > 0.0 else -1
	e.attack_face = e.face

static func _patrol(e: Dictionary, dt: float) -> void:
	if e.hi - e.lo <= e.size.x:
		e.vel.x = 0.0
		return
	if e.pos.x <= e.lo:
		e.face = 1
	elif e.pos.x + e.size.x >= e.hi:
		e.face = -1
	e.vel.x = move_toward(e.vel.x, e.face * PATROL_SPEED, 100.0 * dt)
	# Limit the next proposed move, rather than teleporting the physics body.
	if e.vel.x > 0.0:
		e.vel.x = minf(e.vel.x, maxf(0.0, e.hi - e.size.x - e.pos.x) / dt)
	elif e.vel.x < 0.0:
		e.vel.x = maxf(e.vel.x, -maxf(0.0, e.pos.x - e.lo) / dt)

static func _enter(e: Dictionary, state: String) -> void:
	e.state = state
	e.t = 0.0
	e.vel.x = 0.0
	# At most one boundary per tick: a stalled frame cannot skip an entire cue.

static func _strike(e: Dictionary) -> void:
	_enter(e, "attack")
	e.attack_serial += 1
