extends SceneTree
const Hammer = preload("res://scripts/foldhammer_ai.gd")
var passed := 0
var failed := 0

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		print("FAIL ", label)

func enemy(face: int = 1) -> Dictionary:
	var e: Dictionary = {"kind":"rf_foldhammer", "pos":Vector2(100, 200),
		"home":Vector2(100, 200), "vel":Vector2(12, 17), "size":Vector2(30, 38),
		"hp":5, "max_hp":5, "lo":80.0, "hi":180.0, "face":face,
		"cooldown":0.0, "dead":false, "grounded":true, "flash":0.0}
	Hammer.initialize(e)
	return e

func start(e: Dictionary, face: int = 1) -> void:
	Hammer.tick(e, 0.01, Vector2(50 * face, 0))

func no_hit(e: Dictionary, label: String) -> void:
	check(not Hammer.strike_rect(e).has_area(), label)

func frozen(e: Dictionary, label: String) -> void:
	var before: Dictionary = e.duplicate(true)
	Hammer.tick(e, 0.0, Vector2(-200, 30))
	check(e == before, label)

func _initialize() -> void:
	var e: Dictionary = enemy()
	check(e.state == "patrol" and e.next_hits == 1 and e.cue_hits == 0, "initial patrol promises no hit")
	check(e.hp == 5 and e.max_hp == 5 and e.pos == Vector2(100, 200) and e.vel.y == 17, "initialization preserves caller-owned body and health")
	no_hit(e, "patrol has no damaging footprint")
	frozen(e, "dt zero cannot start a nearby attack")
	e.cooldown = 0.4
	frozen(e, "dt zero leaves cooldown unchanged")
	Hammer.tick(e, -1.0, Vector2(50, 0))
	check(e.cooldown == 0.4, "negative dt also leaves cooldown unchanged")
	Hammer.tick(e, 0.2, Vector2(50, 0))
	check(e.state == "patrol" and is_equal_approx(e.cooldown, 0.2), "live cooldown delays engagement")
	e.cooldown = 0.0
	start(e)
	check(e.state == "windup" and e.cue_hits == 1 and e.strike_index == 1 and e.next_hits == 2, "first windup promises exactly one hit")
	check(e.vel.x == 0 and e.vel.y == 17, "windup roots horizontal motion only")
	no_hit(e, "first windup is harmless")
	frozen(e, "dt zero freezes windup and facing")
	Hammer.tick(e, 0.10, Vector2(-50, 0))
	check(e.face == -1, "early windup follows a crossing target")
	Hammer.tick(e, 0.10, Vector2(50, 0))
	check(e.face == 1 and is_equal_approx(e.t, 0.20), "facing can change throughout first 0.20 seconds")
	var warning: Rect2 = Hammer.cue_rect(e)
	Hammer.tick(e, 0.57, Vector2(-500, -200))
	check(e.state == "windup" and e.face == 1 and e.cue_hits == 1, "late target retreat cannot turn or reroll the promise")
	check(Hammer.cue_rect(e) == warning and Hammer.cue_progress(e) > 0.98, "late warning footprint stays at the locked feet and facing")
	no_hit(e, "0.77 seconds is still harmless")
	Hammer.tick(e, 0.01, Vector2(-500, 0))
	check(e.state == "attack" and e.attack_serial == 1 and Hammer.strike_rect(e) == warning, "first hit activates only after full 0.78 second cue")
	frozen(e, "dt zero freezes an active strike")
	Hammer.tick(e, 0.13, Vector2(-500, 0))
	check(e.state == "attack" and e.face == 1 and Hammer.strike_rect(e).has_area(), "active strike lasts 0.14 seconds and stays committed")
	Hammer.tick(e, 0.01, Vector2(-500, 0))
	check(e.state == "recover" and e.cue_hits == 1, "single strike enters recovery with original promise retained")
	no_hit(e, "single recovery is harmless")
	frozen(e, "dt zero freezes recovery")
	Hammer.tick(e, 0.89, Vector2(-10, 0))
	check(e.state == "recover" and e.vel.x == 0 and e.face == 1, "recovery cannot chase or restart early")
	Hammer.tick(e, 0.01, Vector2(-10, 0))
	check(e.state == "patrol" and e.cue_hits == 0 and is_equal_approx(e.cooldown, Hammer.REST), "full 0.90 second recovery returns to a safe cooldown")
	Hammer.tick(e, Hammer.REST - 0.01, Vector2(-50, 0))
	check(e.state == "patrol", "post-recovery cooldown prevents an immediate repeat")
	Hammer.tick(e, 0.02, Vector2(-50, 0))
	check(e.state == "windup" and e.cue_hits == 2 and e.next_hits == 1 and e.face == -1, "second sequence announces two hits before the first strike")
	Hammer.tick(e, Hammer.WINDUP, Vector2(-50, 0))
	check(e.state == "attack" and e.strike_index == 1 and e.attack_serial == 2, "double sequence begins its first announced strike")
	Hammer.tick(e, Hammer.ACTIVE, Vector2(500, 0))
	check(e.state == "reprise" and e.strike_index == 2 and e.cue_hits == 2 and e.face == -1, "double strike lifts again without retargeting")
	no_hit(e, "reprise is a separate harmless raised-hammer warning")
	check(Hammer.cue_rect(e).has_area() and Hammer.cue_progress(e) == 0, "second raised-hammer cue begins visibly from zero")
	frozen(e, "dt zero freezes reprise")
	Hammer.tick(e, 0.45, Vector2(500, 100))
	check(e.state == "reprise" and e.cue_hits == 2 and e.face == -1, "second promise survives a fleeing or airborne target")
	no_hit(e, "0.45 second reprise remains harmless")
	Hammer.tick(e, 0.01, Vector2(500, 100))
	check(e.state == "attack" and e.strike_index == 2 and e.attack_serial == 3, "second hit follows the entire 0.46 second reprise")
	Hammer.tick(e, Hammer.ACTIVE, Vector2(500, 0))
	check(e.state == "recover" and e.cue_hits == 2, "double sequence also pays full recovery")
	no_hit(e, "double recovery is harmless")
	Hammer.tick(e, 0.89, Vector2(50, 0))
	check(e.state == "recover", "double recovery does not end before 0.90 seconds")
	Hammer.tick(e, 0.01, Vector2(50, 0))
	Hammer.tick(e, Hammer.REST, Vector2(50, 0))
	check(e.state == "windup" and e.cue_hits == 1, "third promise alternates back to one hit")
	check(e.pos == Vector2(100, 200) and e.vel.y == 17 and e.hp == 5, "entire cycle leaves physics integration and HP to caller")
	_test_footprints()
	_test_patrol()
	_test_interruptions()
	_test_stalled_frames()
	print("FOLDHAMMER_COMPONENT_RESULT ", passed, " passed; ", failed, " failed")
	quit(1 if failed else 0)

func _test_footprints() -> void:
	var rectangles: Array[Rect2] = []
	for face in [-1, 1]:
		var e: Dictionary = enemy(face)
		start(e, face)
		var warning: Rect2 = Hammer.cue_rect(e)
		check(warning.size == Vector2(37, 22) and warning.end.y == e.pos.y + e.size.y, "ground-impact footprint stays low and ends at feet, facing %d" % face)
		var tip: float = warning.end.x if face > 0 else warning.position.x
		check(is_equal_approx((tip - (e.pos.x + e.size.x * 0.5)) * face, 45.0), "damage stops at visible tip 45 pixels from center, facing %d" % face)
		check(warning.position.y >= e.pos.y, "ground impact does not invent a damaging overhead column, facing %d" % face)
		Hammer.tick(e, Hammer.WINDUP, Vector2(50 * face, 0))
		check(Hammer.strike_rect(e) == warning, "active matches announced footprint, facing %d" % face)
		var before: Dictionary = e.duplicate(true)
		Hammer.strike_rect(e)
		Hammer.cue_rect(e)
		Hammer.cue_progress(e)
		check(e == before, "all cue and damage helpers are pure, facing %d" % face)
		Hammer.tick(e, 0.02, Vector2(-900 * face, -600))
		check(Hammer.strike_rect(e) == warning, "active footprint never remotely tracks target, facing %d" % face)
		e.pos += Vector2(3, 5)
		check(Hammer.strike_rect(e).position == warning.position + Vector2(3, 5), "footprint remains attached to moving feet, facing %d" % face)
		rectangles.append(warning)
	check(is_equal_approx(rectangles[0].get_center().x + rectangles[1].get_center().x, 230.0), "left and right footprints mirror across body center")

func _test_patrol() -> void:
	var e: Dictionary = enemy()
	var bounded := true
	var slow := true
	var saw_left := false
	var saw_right := false
	for frame in range(500):
		Hammer.tick(e, 0.02, Vector2(500, 0))
		# Substitute only the caller's horizontal integration, no scene required.
		e.pos.x += e.vel.x * 0.02
		bounded = bounded and e.pos.x >= e.lo - 0.0001 and e.pos.x + e.size.x <= e.hi + 0.0001
		slow = slow and absf(e.vel.x) <= Hammer.PATROL_SPEED
		saw_left = saw_left or e.vel.x < 0
		saw_right = saw_right or e.vel.x > 0
	check(bounded and slow and saw_left and saw_right, "patrol is slow, bounded and reverses at both authored edges")
	e = enemy()
	e.lo = 100.0
	e.hi = 120.0
	Hammer.tick(e, 0.1, Vector2(500, 0))
	check(e.vel.x == 0, "too-narrow patrol lane stays still")
	e = enemy()
	Hammer.tick(e, 0.1, Vector2(10, 100))
	check(e.state == "patrol", "target on a separate vertical tier does not trigger attack")

func _test_interruptions() -> void:
	for state in ["windup", "attack", "reprise", "recover"]:
		var e: Dictionary = enemy()
		start(e)
		e.state = state
		e.cue_hits = 2
		e.t = 0.1
		e.dead = true
		no_hit(e, "death suppresses damage immediately during " + state)
		check(not Hammer.cue_rect(e).has_area(), "death suppresses warning during " + state)
		frozen(e, "dt zero does not mutate a dead " + state)
		Hammer.tick(e, 0.2, Vector2(50, 0))
		check(e.dead and e.hp == 5 and e.t == 0.1 and e.cue_hits == 0, "dead component stops without advancing timers or owning HP during " + state)
	var e: Dictionary = enemy()
	start(e)
	Hammer.tick(e, Hammer.WINDUP, Vector2(50, 0))
	e.hp = 0
	no_hit(e, "zero HP suppresses damage even before caller marks dead")
	e = enemy()
	start(e)
	Hammer.tick(e, Hammer.WINDUP, Vector2(50, 0))
	Hammer.cancel(e)
	check(e.state == "recover" and e.cue_hits == 0 and e.strike_index == 0 and e.hp == 5, "explicit cancellation clears promise without damaging the body")
	no_hit(e, "cancelled active strike is immediately harmless")
	Hammer.tick(e, 0.89, Vector2(50, 0))
	check(e.state == "recover", "cancellation cannot evade committed recovery")

func _test_stalled_frames() -> void:
	var e: Dictionary = enemy()
	e.next_hits = 2
	Hammer.tick(e, 99.0, Vector2(50, 0))
	check(e.state == "windup" and e.t == 0 and e.cue_hits == 2, "long frame cannot skip a newly announced first cue")
	Hammer.tick(e, 99.0, Vector2(50, 0))
	check(e.state == "attack" and e.attack_serial == 1, "long frame crosses at most one boundary")
	Hammer.tick(e, 99.0, Vector2(-500, 0))
	check(e.state == "reprise" and e.t == 0 and e.cue_hits == 2, "long frame cannot skip the separate second cue")
	no_hit(e, "stalled-frame reprise is still harmless")
