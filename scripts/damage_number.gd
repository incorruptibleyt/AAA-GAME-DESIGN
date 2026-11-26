class_name DamageNumber
extends Label3D
## Numbers that pop out of whatever got hit and float away. Quick hits on the same target
## add up into one number, which sits up and to the side so it never hides the skeleton,
## and slides down below the top bar so it never covers the health, room or chain.

const LIFE := 0.75
## A hit this soon after the last one joins its number instead of making a new one.
const MERGE := 0.4
## Hits on skeletons join a number for longer, while it's still clearly on screen: a
## special's rings of bolts hit the same skeleton every half second or so, and each ring
## used to stack a new number on top of the last ("13" over "13").
const FOE_MERGE := 0.6
## Where numbers sit, from the middle of whatever was hit: above it and to the right.
const OFFSET := Vector3(0.75, 0.8, 0)
## In a big fight only this many numbers stay up; older ones start fading early (A-7).
const MAX_LIVE := 10
## Hits on skeletons this close (metres) to a number still adding up join it: a special
## move hitting a crowd shows one growing total instead of a pile of 5 or more numbers.
const CLUSTER := 1.6
## ...for this long after it first showed, so a long brawl still shows fresh numbers.
const CLUSTER_TIME := 0.8
## Version 278: a number adds up for at most this long, then lets go and fades while the
## next hit starts a fresh one. A boss under steady fire (the Rogue's knives and bolts)
## kept one number growing to 1,700 and more over its head for the whole fight.
const MERGE_SPAN := 1.2

var _age := 0.0
var _shown := 0.0   # seconds since it first showed (never reset by a merge)
var _size := 1.0
var _total := 0.0
var _prefix := ""
var _rise := 0.0
var _lift := 0.0
var _follow: Actor
## A number for damage done to skeletons (crowded ones can share it; the hero's never do).
var _foe := false
var _base := Vector3.ZERO
## The number still adding up for each target ("<id>hit" / "<id>heal").
static var _live := {}
## Version 126 (audit #12): finished numbers wait here (hidden) to show the next hit.
static var _spare: Array = []
const SPARE_CAP := 16
var _key := ""
## Version 213: where the number sits from its target (the hero's sit higher, off to the side).
var _off := OFFSET
const HERO_OFFSET := Vector3(1.15, 2.2, 0)   # v220: above the shoulder, off the body


## Damage taken by `who`. Hits on the hero are red; crits turn the number gold and bigger.
static func hit(who: Actor, amount: float, crit: bool) -> void:
	# Version 213 (hardest review fix #10/#17): the hero's own hits are white on a dark red
	# edge (red on the red and orange floors could not be read), on the hero's far side.
	# Version 386 (visual review of v383, fix 5): one style for every hit. White with the ink
	# edge, gold and bigger for a critical hit; the hero's own hits are the same white with a
	# minus in front (a red edge and numbers growing to nearly twice the size before read as
	# three different styles).
	_add(who, "hit", amount, Color.WHITE, "-" if who.team == Actor.Team.HERO else "", crit)


static func healed(who: Actor, amount: float) -> void:
	_add(who, "heal", amount, Color(0.45, 0.95, 1.0), "+", false)   # cyan (was green: red/green pair)


static func _add(who: Actor, kind: String, amount: float, col: Color, prefix: String, crit: bool) -> void:
	if Game.world == null:
		return
	var key := "%d%s" % [who.get_instance_id(), kind]
	var got: Variant = _live.get(key)
	var n: DamageNumber = got if is_instance_valid(got) else null
	var foe := kind == "hit" and who.team != Actor.Team.HERO
	var merge := FOE_MERGE if foe else MERGE
	if is_instance_valid(n) and n._shown >= MERGE_SPAN:
		n._age = maxf(n._age, LIFE * 0.6)   # it fades out now, under the fresh one
		n = null
	if foe and not (is_instance_valid(n) and n._age < merge):
		n = _nearby(who.center())
	if is_instance_valid(n) and n._age < merge:
		n._total += amount
		n._age = 0.0
		n._size = minf(n._size + 0.03, maxf(n._size, 1.2))   # v386: a growing total only grows a little (1.8 before)
	else:
		_trim()
		n = null
		while n == null and not _spare.is_empty():
			var o: Variant = _spare.pop_back()
			if is_instance_valid(o):
				n = o
		if n == null:
			n = DamageNumber.new()
			# The cartoon font with a thick ink edge, like the rest of the game's big text.
			n.font = Hud.UI_FONT
			n.outline_size = 20
			n.font_size = 66
			n.pixel_size = 0.009
			n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			n.no_depth_test = true
			n.fixed_size = false
			Game.world.add_child(n)
			n.tree_exiting.connect(n._gone)
		n.modulate = col
		n.outline_modulate = Hud.INK
		n._age = 0.0
		n._shown = 0.0
		n._size = 1.0
		n._rise = 0.0
		n.scale = Vector3.ONE
		n.visible = true
		n.set_process(true)
		n._follow = who
		n._foe = foe
		n._prefix = prefix
		n._total = amount
		n._base = who.center()
		n._off = HERO_OFFSET if who.team == Actor.Team.HERO else OFFSET
		n._lift = _free_lift(n._base + n._off)
		n.position = n._base + n._off + Vector3(0, n._lift, 0)
		n._key = key
		_live[key] = n
	if crit:
		n.modulate = Color(1, 0.8, 0.12)
		n._size = maxf(n._size, 1.4)
	n.text = n._prefix + str(maxi(1, roundi(n._total)))


## A skeleton-damage number still adding up near `at` (the closest), or null.
static func _nearby(at: Vector3) -> DamageNumber:
	var best: DamageNumber = null
	var best_d := CLUSTER
	for o in _live.values():
		if is_instance_valid(o) and o._foe and o._age < FOE_MERGE and o._shown < CLUSTER_TIME:
			var d: float = o._base.distance_to(at)
			if d < best_d:
				best_d = d
				best = o
	return best


## Takes every number off the screen at once (the blessing cards and doors cover the room,
## and a number frozen under them showed through).
static func clear_all() -> void:
	for o in _live.values():
		if is_instance_valid(o):
			(o as DamageNumber)._done()
	_live.clear()


## Makes room for one more number: when MAX_LIVE are still bright, the oldest fade out now.
static func _trim() -> void:
	var bright: Array = []
	for o in _live.values():
		if is_instance_valid(o) and o._age < LIFE * 0.6:
			bright.append(o)
	if bright.size() < MAX_LIVE:
		return
	bright.sort_custom(func(a, b): return a._age > b._age)
	for i in bright.size() - MAX_LIVE + 1:
		bright[i]._age = LIFE * 0.6


## How far to raise a new number so it doesn't sit on top of one already showing
## (skeletons crowded together).
static func _free_lift(at: Vector3) -> float:
	var lift := 0.0
	for i in 4:
		var clear := true
		for o in _live.values():
			if is_instance_valid(o) and o.position.distance_to(at + Vector3(0, lift, 0)) < 0.55:
				clear = false
				break
		if clear:
			break
		lift += 0.55
	return lift


func _process(delta: float) -> void:
	_age += delta
	_shown += delta
	var k := _age / LIFE
	if k >= 1.0:
		_done()
		return
	if is_instance_valid(_follow):
		_base = _follow.center()
	_rise = minf(_rise + delta * 1.4, 0.9)
	position = _base + _off + Vector3(0, _rise + _lift, 0)
	_keep_below_hud()
	# Pops in big, dips a little under its size and settles: a punchy bounce.
	var pop := 1.0
	if k < 0.1:
		pop = lerpf(1.7, 0.9, k / 0.1)
	elif k < 0.2:
		pop = lerpf(0.9, 1.0, (k - 0.1) / 0.1)
	scale = Vector3.ONE * _size * pop
	modulate.a = 1.0 - clampf((k - 0.6) / 0.4, 0.0, 1.0)
	# Version 386: a skeleton's number right by the hero is see-through, so a crowd's numbers
	# don't bury the hero (the hero's own numbers stay as they are).
	if is_instance_valid(_follow) and _follow != Game.hero:
		modulate.a *= 1.0 - 0.6 * HealthBar.near_hero(_follow.global_position)
	outline_modulate.a = modulate.a


func _keep_below_hud() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or Game.hud == null or not Game.hud.visible:
		return
	var band := Game.hud.top_band() + 24.0 * scale.y
	var y := cam.unproject_position(global_position).y
	if y >= band:
		return
	# How many pixels down the screen one step towards the camera's bottom edge moves it.
	var per := cam.unproject_position(global_position + Vector3(0, 0, 1)).y - y
	if per > 1.0:
		global_position.z += (band - y) / per


## Freed with the world (or anything else): forget it.
func _gone() -> void:
	if _key != "" and _live.get(_key) == self:
		_live.erase(_key)
	_spare.erase(self)


## Off the screen: waits hidden for the next hit (or is freed when enough are waiting).
func _done() -> void:
	if _live.get(_key) == self:
		_live.erase(_key)
	_key = ""
	_follow = null
	if not visible:
		return
	visible = false
	set_process(false)
	if _spare.size() < SPARE_CAP:
		_spare.append(self)
	else:
		queue_free()
