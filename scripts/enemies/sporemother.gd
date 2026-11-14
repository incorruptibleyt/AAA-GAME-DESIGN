class_name Sporemother
extends Enemy
## The boss of the Glowcap Grotto (floor 4, then every fifth floor from 10): a towering
## mossy skeleton sorceress under a huge glowing toadstool cap, with mushrooms growing out
## of her back and a staff budding with a pink spore bulb. Where the Colossus fills the floor
## with fire, she seeds it with spores and roots. Every attack has a warning:
## - Spore Pods: she lobs glowing pods; circles show where they land. Each bursts and leaves
##   a spore cloud behind for a few seconds.
## - Root Snare: lines of roots crawl after you from her feet (they turn slowly: step aside,
##   or dash; caught, you are held in place for a moment).
## - Fairy Ring: a ring of little mushrooms springs up around you; everything inside it
##   bursts. Get out before it does.
## - Brood (every other round; more pods in between): Sporelings sprout beside her.
## Below half health she blooms: three rings of spore bursts roll out from her one after
## another, with gaps to slip through (her new move, Spore Bloom), and everything gets
## quicker and bigger.

const DISPLAY_NAME := "The Sporemother"
const PINK := Color(1.0, 0.42, 0.82)
const LIME := Color(0.72, 1.0, 0.3)

var _enraged := false
var _started := false
var _busy := false
var _cap: Node3D
var _bulb: MeshInstance3D
static var _pod_mat: StandardMaterial3D
static var _back_baked: ArrayMesh


## On the free floor (4) she is a little gentler, like the Lich was there: less health and
## fewer pods; deeper Sporemothers (10, 15...) are the full fight.
func _gentle() -> bool:
	return Game.floor_num <= 4


func _setup() -> void:
	is_boss = true
	init_health(560.0 if _gentle() else 640.0)
	drop_chance = 0.0
	move_speed = 1.3
	contact_damage = 16.0
	radius = 1.15
	center_height = 1.8
	knockback_scale = 0.06
	var look := bones(Art.SKELETON_MAGE, 3.9, PINK)
	look.overlay = FungalLook.overlay(0.22)
	look.accent = Color(0.3, 0.16, 0.34)
	look.weapon = "Skeleton_Staff"
	look.attack_anim = "Spellcast_Shoot"
	look.hide = ["Skeleton_Mage_Hat"]
	make_visual(look)
	_dress()


func _dress() -> void:
	var skel := Art._find_skeleton(visual)
	if skel == null:
		return
	if skel.find_bone("head") >= 0:
		var att := BoneAttachment3D.new()
		skel.add_child(att)
		att.bone_name = "head"
		# The great cap, worn on the back of the skull and tipped back, so from the
		# top-down camera the skull, eyes and body still show under it.
		_cap = Node3D.new()
		_cap.position = Vector3(0, 0.6, -0.16)
		_cap.rotation = Vector3(-0.38, 0, -0.08)
		att.add_child(_cap)
		var cap := MeshInstance3D.new()
		cap.mesh = FungalLook.cap_mesh(0.64, 7)
		_cap.add_child(cap)
	if skel.find_bone("chest") >= 0:
		var back := BoneAttachment3D.new()
		skel.add_child(back)
		back.bone_name = "chest"
		var mi := MeshInstance3D.new()
		mi.mesh = _back_mesh()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		back.add_child(mi)
	if skel.find_bone("handslot.r") >= 0:
		var hand := BoneAttachment3D.new()
		skel.add_child(hand)
		hand.bone_name = "handslot.r"
		var glow := U.unlit(Color(PINK.r, PINK.g, PINK.b, 0.9), U.soft_circle(), true).duplicate()
		glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_bulb = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 0.9)
		_bulb.mesh = q
		_bulb.material_override = glow
		_bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hand.add_child(_bulb)
		_bulb.position = Vector3(0, 1.2, 0)


## Mushrooms growing out of her shoulders and back.
static func _back_mesh() -> ArrayMesh:
	if _back_baked:
		return _back_baked
	var parts := []
	var plan := [[0.42, 0.2, 0.6, Vector3(0.3, 0.25, -0.22), 0.6], [0.36, 0.17, 0.75, Vector3(-0.32, 0.22, -0.2), 2.6],
		[0.3, 0.14, 0.4, Vector3(0.05, 0.1, -0.32), 1.6], [0.26, 0.12, 0.9, Vector3(0.42, 0.42, -0.05), 0.1]]
	for m in plan:
		parts.append_array(FungalLook.mushroom_parts(m[0], m[1], m[2], m[3], m[4], 3))
	_back_baked = Props._bake(parts)
	return _back_baked


func display_name() -> String:
	return DISPLAY_NAME


func _think(hero: Hero, delta: float) -> void:
	if not _started:
		_started = true
		Sfx.play("roar")
		Sfx.play("spore", 1.0, 0.7)
		Game.shake(0.5)
		_brain()
	if not _enraged and health < max_health * 0.5:
		_enraged = true
		move_speed *= 1.25
		Sfx.play("spore", 1.0, 0.6)
		phase_two(PINK, "bloom", "Spore Bloom")
		if _bulb:
			_bulb.create_tween().tween_property(_bulb, "scale", Vector3.ONE * 1.7, 0.4)
	if randf() < delta * 3.0:
		Fx.magic(center() + Vector3(randf_range(-0.9, 0.9), randf_range(0.0, 1.6), randf_range(-0.9, 0.9)), PINK if randf() < 0.75 else LIME, 2)
	if _cap:
		_cap.scale = Vector3.ONE * (1.0 + 0.025 * sin(Time.get_ticks_msec() * 0.003))
	if _busy:
		stand(delta)
		return
	# She keeps a middle distance: close enough to reach, far enough to lob.
	var to := hero.global_position - global_position
	to.y = 0.0
	if to.length() > 5.5:
		walk(to, delta)
	elif to.length() < 3.0:
		walk(-to, delta, 0.8)
	else:
		stand(delta)
		face(to, 6.0, delta)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _alive() -> bool:
	return is_instance_valid(self) and not dead and Game.state == Game.State.PLAYING


func _brain() -> void:
	await _wait(1.2)
	var bags := 0
	while _alive():
		await roar_done()
		if not _alive():
			break
		_busy = true
		var moves := ["pods", "roots", "ring", "pods"]
		if bags % 2 == 0:   # every other round of moves
			moves.append("brood")
		if _enraged:
			moves.append("bloom")   # phase 2's own move
		var m := next_move(moves)
		if _bag.is_empty():
			bags += 1
		match m:
			"pods": await _pods()
			"roots": await _roots()
			"ring": await _ring()
			"brood": await _brood()
			"bloom": await _bloom()
		_busy = false
		await _wait(0.9 if _enraged else 1.4)


## Lobs glowing pods high over the room; a circle shows where each will land, at you and
## around you. Each bursts where it lands and leaves a spore cloud for a few seconds.
func _pods(count := 0) -> void:
	var hero := Game.hero
	if hero == null:
		return
	if count == 0:
		count = 3 + (1 if _enraged else 0) + (0 if _gentle() else 1)
	visual.attack(true)
	face(hero.global_position - global_position, 30.0, 0.1)
	Sfx.play("spore", 0.7, 1.2)
	var flight := 1.05 if _enraged else 1.2
	var turn := randf() * TAU
	for i in count:
		var spot := hero.global_position
		if i > 0:
			spot += Vector3.FORWARD.rotated(Vector3.UP, turn + i * TAU / maxf(count - 1, 1)) * randf_range(2.0, 2.8)
		spot.x = clampf(spot.x, -Room.HALF_W + 0.8, Room.HALF_W - 0.8)
		spot.z = clampf(spot.z, -Room.HALF_L + 0.8, Room.HALF_L - 0.8)
		var at := spot
		track(Telegraph.circle(at, 1.25, flight, func(): _pod_lands(at), 0.4 if i > 0 else 0.6))
		_lob(center() + Vector3.UP * 1.2, at, flight)
		await _wait(0.12)
	await _wait(flight)


## A pod flying in an arc from her staff to `to`, over `seconds`.
func _lob(from: Vector3, to: Vector3, seconds: float) -> void:
	if _pod_mat == null:
		_pod_mat = U.mat(Color(1.0, 0.42, 0.82), 0.4, 0.7)
	var parent: Node = Room.current if Room.current else Game.world
	var pod := U.sphere(parent, 0.28, _pod_mat)
	pod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pod.global_position = from
	var fly := func(k: float) -> void:
		if is_instance_valid(pod):
			pod.global_position = from.lerp(to, k) + Vector3.UP * (4.5 * k * (1.0 - k) * 4.0 * 0.5)
			pod.rotation.y = k * 9.0
	var tw := pod.create_tween()
	tw.tween_method(fly, 0.0, 1.0, seconds)
	tw.tween_callback(pod.queue_free)


func _pod_lands(at: Vector3) -> void:
	Sfx.play("spore", 0.75, randf_range(0.85, 1.1))
	Fx.magic(at + Vector3.UP * 0.4, PINK, 18)
	Fx.shockwave(at, PINK, 1.6)
	SporeCloud.spawn(at, 1.1, 2.6 if _gentle() else 3.0, 5.0)
	var hero := Game.hero
	if hero == null or dead:
		return
	var d := hero.global_position - at
	d.y = 0.0
	if d.length() < 1.25 + hero.radius * 0.5:
		Game.hit_source = DISPLAY_NAME
		hero.take_damage(12.0, d, 6.0)


## Lines of roots crawl after the hero from her feet, fanned out so they close in from
## different sides.
func _roots() -> void:
	var hero := Game.hero
	if hero == null:
		return
	if not visual.play_named("Spellcast_Summon"):
		visual.attack(true)
	Sfx.play("roots", 0.9, 0.8)
	Game.shake(0.2)
	Fx.shockwave(global_position, LIME, 2.4)
	await _wait(0.45)
	if not _alive() or Game.hero == null:
		return
	# A fan of crawls, wide enough apart that a step between two of them works; they turn
	# slowly, and on floor 4 they hold for less time.
	var n := 4 if _enraged else 3
	var to := Game.hero.global_position - global_position
	to.y = 0.0
	to = to.normalized()
	for i in n:
		var a := (i - (n - 1) * 0.5) * 0.6
		var d := to.rotated(Vector3.UP, a)
		var r := RootCrawl.spawn(global_position + d * 1.3, global_position + d * 5.0, DISPLAY_NAME, 10.0, 0.7 if _gentle() else 0.9)
		if r:
			r.turn = 0.55
			r.speed = 4.8 if _enraged else 4.4
			r.life = 2.6
	await _wait(1.6)


## A ring of little mushrooms springs up around the hero; then everything inside it bursts.
func _ring() -> void:
	var hero := Game.hero
	if hero == null:
		return
	visual.attack(true)
	Sfx.play("roar", 0.4, 1.3)
	var at := hero.global_position
	at.x = clampf(at.x, -Room.HALF_W + 1.0, Room.HALF_W - 1.0)
	at.z = clampf(at.z, -Room.HALF_L + 1.0, Room.HALF_L - 1.0)
	var r := 2.1 if _gentle() else 2.3
	var wind := 1.6 if _gentle() else 1.45
	if _enraged:
		r += 0.3
		wind -= 0.2
	track(Telegraph.circle(at, r, wind, func(): _ring_bursts(at, r)))
	# The mushrooms themselves, springing up round the edge.
	var parent: Node = Room.current if Room.current else Game.world
	var ring := Node3D.new()
	parent.add_child(ring)
	ring.global_position = Vector3(at.x, 0, at.z)
	var count := 10
	for i in count:
		var a := i / float(count) * TAU
		var m := MeshInstance3D.new()
		m.mesh = FungalLook.cap_mesh(0.28, 3)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = Vector3(cos(a) * r, 0.1, sin(a) * r)
		m.scale = Vector3.ZERO
		ring.add_child(m)
		m.create_tween().tween_property(m, "scale", Vector3.ONE, 0.25).set_delay(i * 0.03).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tw := ring.create_tween()
	tw.tween_interval(wind + 0.35)
	tw.tween_property(ring, "scale", Vector3(1, 0.02, 1), 0.3)
	tw.tween_callback(ring.queue_free)
	await _wait(wind + 0.5)


func _ring_bursts(at: Vector3, r: float) -> void:
	Sfx.play("spore", 1.0, 0.8)
	Sfx.play("boom", 0.5, 1.2)
	Game.shake(0.3)
	Fx.shockwave(at, PINK, r + 0.4)
	for i in 8:
		var a := i / 8.0 * TAU
		Fx.magic(at + Vector3(cos(a), 0.3, sin(a)) * r * 0.6, PINK, 5)
	var hero := Game.hero
	if hero == null or dead:
		return
	var d := hero.global_position - at
	d.y = 0.0
	if d.length() < r + hero.radius * 0.5:
		Game.hit_source = DISPLAY_NAME
		hero.take_damage(16.0, d, 8.0)


## Sporelings sprout from the floor beside her. They shield her, so not too many.
func _brood() -> void:
	if not visual.play_named("Spellcast_Summon"):
		visual.attack(true)
	Sfx.play("roar", 0.6)
	Sfx.play("spore", 0.8, 0.9)
	var n := 2
	var cap := 4 if _enraged else 3   # herself and at most two (three when angry) Sporelings
	for i in n:
		if Game.alive_enemies >= cap:
			break
		var off := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / n + randf_range(-0.4, 0.4)) * 3.0
		var spot := Room.current.resolve_move(global_position + off, Vector3.ZERO, 0.4)
		Fx.shockwave(spot, PINK, 1.4)
		RootCrawl._burst(spot, 1.3)
		Game.spawn_enemy("p", spot)
	await _wait(1.0)


## Phase 2: three rings of spore bursts roll out from her, each a moment after the last.
## Every ring has gaps (turned differently each time) to stand in or slip through. Then a
## volley of pods while you are still finding your feet.
func _bloom() -> void:
	if not visual.play_named("Spellcast_Raise"):
		visual.attack(true)
	Sfx.play("roar", 0.8, 0.8)
	Game.shake(0.35)
	var centre := global_position
	var radii := [2.4, 4.3, 6.2]
	for k in radii.size():
		var rad: float = radii[k]
		var count := maxi(4, int(TAU * rad / 3.3))
		var turn := randf() * TAU
		var wind := 1.0 + 0.45 * k
		for i in count:
			var a := turn + i * TAU / count
			var at := centre + Vector3(cos(a), 0, sin(a)) * rad
			if absf(at.x) > Room.HALF_W - 0.4 or absf(at.z) > Room.HALF_L - 0.4:
				continue
			track(Telegraph.circle(at, 0.95, wind, func(): _bloom_burst(at), 0.6 if i == 0 else 0.0))
	await _wait(1.0 + 0.45 * 2 + 0.3)
	if _alive():
		await _pods(3)


func _bloom_burst(at: Vector3) -> void:
	Sfx.play("spore", 0.55, randf_range(0.9, 1.2))
	Fx.magic(at + Vector3.UP * 0.4, PINK, 10)
	RootCrawl._burst(at, 1.1, 0.4)
	var hero := Game.hero
	if hero == null or dead:
		return
	var d := hero.global_position - at
	d.y = 0.0
	if d.length() < 0.95 + hero.radius * 0.5:
		Game.hit_source = DISPLAY_NAME
		hero.take_damage(14.0, d, 7.0)


func _on_death() -> void:
	Sfx.play("roar", 0.8)
	Sfx.play("spore", 1.0, 0.6)
	Game.hit_stop(0.25)
	Game.shake(0.8)
	if _bulb:
		_bulb.create_tween().tween_property(_bulb, "scale", Vector3.ZERO, 0.6)
	if _cap:
		var tw := _cap.create_tween()
		tw.tween_property(_cap, "scale", Vector3.ONE * 1.25, 0.2).set_ease(Tween.EASE_OUT)
		tw.tween_property(_cap, "scale", Vector3.ZERO, 0.5).set_ease(Tween.EASE_IN)
	Fx.magic(center(), PINK, 60)
	Fx.magic(center(), LIME, 20)
	Fx.shockwave(global_position, PINK, 5.0)
	for i in 4:
		Fx.bones(global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
	super._on_death()
