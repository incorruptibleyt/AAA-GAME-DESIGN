class_name Hero
extends Actor
## The player's hero. Drag your thumb to move; stand still and the hero automatically
## fires at the nearest skeleton.

# Starting numbers. Blessings (upgrades.gd) change these during a run.
var move_speed := 5.2
var damage := 12.0
var shots_per_second := 1.8
var bolt_speed := 17.0
var front_bolts := 1
var diagonal_bolts := 0
var rear_bolts := 0
var pierce := 0
var crit_chance := 0.05
var burn_dps := 0.0
var heal_on_kill := 0.0
## From Bone Harvest: only heals while the Bone Chain is x2 or higher.
var harvest_heal := 0.0
## Set by the chosen hero (heroes.gd).
var hero_id := "rogue"
var bolt_size := 0.22
var bolt_color := Color(0.55, 0.85, 1.0)
var bolt_push := 4.0
var splash := 0.0
var armor := 0.0
var _dash_ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
## From the Armory: survive one killing blow per run.
var second_wind := false
## Blessings that aren't plain numbers.
var frost := false
var frost_time := 1.5
## Blessings taken this run, by id, for the ones that change rules rather than numbers.
var perks := {}
var _volleys := 0
## The special move fills from kills (elites and perfect dodges count more).
var special_charge := 0.0
var _spin_left := 0.0
var _spin_tick := 0.0
var magnet := 1.0
var coin_bonus := 0.0
## Bone Ward: hits blocked per room, and how many are left in this room.
var ward_max := 0
var ward := 0
var _ward_bubble: MeshInstance3D

## Dash: flick your thumb (or press Space) to zip a short way, untouchable while dashing.
const DASH_SPEED := 21.0
const DASH_TIME := 0.17
const DASH_COOLDOWN := 1.1
var _dash_left := 0.0
var _dash_cooldown := 0.0
var _last_dash_ms := -100000
var _aura: MeshInstance3D
var _dash_dir := Vector3.ZERO
var _trail_t := 0.0
var _ring_was_ready := true

var _shot_timer := 0.4
var _invulnerable := 0.0
var _moving := false


static func spawn(parent: Node, pos: Vector3, id := "rogue") -> Hero:
	var def := Heroes.get_hero(id)
	var h := Hero.new()
	h.name = "Hero"
	h.team = Team.HERO
	h.radius = 0.45
	h.center_height = 1.0
	h.hero_id = def.id
	h.init_health(def.health)
	h.move_speed = def.move_speed
	h.damage = def.damage
	h.shots_per_second = def.rate
	h.bolt_speed = def.bolt_speed
	h.bolt_size = def.bolt_size
	h.bolt_color = def.bolt_color
	h.bolt_push = def.get("push", 4.0)
	h.pierce = def.get("pierce", 0)
	h.armor = def.get("armor", 0.0)
	h.splash = def.get("splash", 0.0)
	h.heal_on_kill = def.get("heal_on_kill", 0.0)
	parent.add_child(h)
	h.global_position = pos
	var look := {"key": def.key, "height": 2.1, "body": def.body, "accent": Color(0.85, 0.75, 0.5), "eyes": Color(0.6, 0.9, 1.0),
		"hide": def.hide, "attack_anim": def.attack_anim}
	for extra in ["hood", "helmet", "hat", "horns"]:
		if def.has(extra):
			look[extra] = def[extra]
	h.make_visual(look)
	h._build_dash_ring()
	# Curse mastery rewards (curses.gd): a red lantern, a grave aura, golden bolts.
	var mastery := Curses.mastery(Game._load_save(), def.id)
	if mastery >= 10:
		h.bolt_color = Color(1.0, 0.8, 0.3)
	if mastery >= 6:
		h._build_aura()
	# A soft light that travels with the hero so they never get lost in the dark.
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.45, 0.42) if mastery >= 2 else Color(0.75, 0.85, 1.0)
	lantern.light_energy = 0.9
	lantern.omni_range = 8.0
	lantern.position = Vector3(0, 3.6, 0.6)   # high and slightly behind, so the hood isn't blown out
	h.add_child(lantern)
	return h


func place_at(pos: Vector3) -> void:
	global_position = pos
	rotation = Vector3.ZERO
	knockback = Vector3.ZERO
	_shot_timer = 0.4


func can_be_hit() -> bool:
	return not dead and _invulnerable <= 0.0 and _dash_left <= 0.0 and Game.state == Game.State.PLAYING


func heal(amount: float) -> void:
	var before := health
	super.heal(amount)
	Game.report_event("healed", health - before)


func is_dashing() -> bool:
	return _dash_left > 0.0


## For the Grave Pact curse: a dash in the last 1.5 seconds.
func dashed_recently() -> bool:
	return Time.get_ticks_msec() - _last_dash_ms < 1500


func dash_ready() -> bool:
	return _dash_cooldown <= 0.0


## Start a dash along `dir` (on the floor). Does nothing while it's recharging.
func dash(dir: Vector3) -> void:
	dir.y = 0.0
	if dead or not dash_ready() or dir.length_squared() < 0.01 or Game.state != Game.State.PLAYING:
		return
	_dash_dir = dir.normalized()
	_dash_left = DASH_TIME
	_last_dash_ms = Time.get_ticks_msec()
	_dash_cooldown = DASH_COOLDOWN
	_trail_t = 0.0
	knockback = Vector3.ZERO
	rotation.y = atan2(-_dash_dir.x, -_dash_dir.z)
	Sfx.play("dash", 0.7)
	Game.report_event("dash")
	Fx.dust(global_position, 10)
	_perfect_done = false
	_check_perfect(PERFECT_WINDOW)


## Grave Dash: dashing through a red shot just before it lands is a perfect dodge.
## Time slows, nearby shots shatter, and the hero answers with a ring of bolts.
const PERFECT_WINDOW := 0.22
var _perfect_done := false


func _check_perfect(window: float) -> void:
	if _perfect_done:
		return
	for p in Projectile.danger:
		if is_instance_valid(p) and not p.is_queued_for_deletion() and p.time_to_hit(global_position, radius + 0.15) <= window:
			_perfect_dodge()
			return


func _perfect_dodge() -> void:
	_perfect_done = true
	_dash_cooldown = 0.0
	add_charge(0.25)
	for p in Projectile.danger.duplicate():
		if is_instance_valid(p) and p.global_position.distance_to(global_position) < 3.0:
			p.shatter()
	Game.perfect_dodge(center())
	var col := bolt_color.lerp(Color.WHITE, 0.4)
	for i in 8:
		var d := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0 + rotation.y)
		var p := Projectile.fire(Team.HERO, global_position + Vector3.UP * 1.1 + d * 0.5, d, damage * 1.5 * Game.chain_damage(), bolt_speed, col, bolt_size)
		p.pierce = pierce + 1
		p.push = bolt_push


func special_ready() -> bool:
	return special_charge >= 1.0


func add_charge(amount: float) -> void:
	if Game.curses.has("quick"):
		amount *= 2.0   # Daily Crypt rule: Quick Hands
	var was := special_ready()
	special_charge = minf(1.0, special_charge + amount)
	if special_ready() and not was:
		Sfx.play("upgrade", 0.5)


## Each hero has one big move, used from the button on the right.
func use_special() -> void:
	if dead or not special_ready() or Game.state != Game.State.PLAYING or not Game.special_unlocked():
		return
	special_charge = 0.0
	Game.report_event("special")
	if Game.curses.has("blood"):
		# Blood Price: the special costs a quarter of max health, but never kills.
		health = maxf(1.0, health - max_health * 0.25)
		Game.hud.flash(Color(0.9, 0.1, 0.1), 0.3)
	Game.hud.tip("", 0.0)
	Game.hud.callout(Heroes.get_hero(hero_id).special.to_upper() + "!", bolt_color.lerp(Color.WHITE, 0.3))
	Game.shake(0.25)
	match hero_id:
		"knight": _shield_slam()
		"barbarian":
			_spin_left = 2.5
			Sfx.play("dash", 0.9)
		"mage": _meteors()
		_: _shadow_volley()


func _special_hit(a: Actor, amount: float, from: Vector3, push: float) -> void:
	var d := a.global_position - from
	d.y = 0.0
	a.take_damage(amount * Game.chain, d, push)   # specials get the full chain


func _shadow_volley() -> void:
	for wave in 3:
		get_tree().create_timer(0.22 * wave, false).timeout.connect(func():
			if dead:
				return
			Sfx.play("shoot", 0.9)
			for i in 12:
				var d := Vector3.FORWARD.rotated(Vector3.UP, TAU * (i + wave * 0.33) / 12.0)
				var p := Projectile.fire(Team.HERO, global_position + Vector3.UP * 1.1 + d * 0.5, d, damage * 1.4 * Game.chain, bolt_speed, bolt_color.lerp(Color(0.6, 0.3, 1.0), 0.4), bolt_size)
				p.pierce = pierce + 1
				p.push = bolt_push)


func _shield_slam() -> void:
	visual.attack()
	Game.finisher(global_position, 0.35, 0.3, Color(1, 0.95, 0.7))
	Fx.shockwave(global_position, Color(1, 0.9, 0.6), 5.0)
	Fx.dust(global_position, 30)
	_invulnerable = maxf(_invulnerable, 1.2)
	for a: Actor in Actor.all.duplicate():
		if a.team != Team.UNDEAD or not a.can_be_hit():
			continue
		if a.global_position.distance_to(global_position) < 5.0 + a.radius:
			_special_hit(a, damage * 3.0, global_position, 14.0)
			if not a.dead and a is Enemy:
				(a as Enemy).chill(2.5)


func _meteors() -> void:
	var targets := Actor.all.filter(func(a: Actor): return a.team == Team.UNDEAD and a.can_be_hit())
	targets.sort_custom(func(a: Actor, b: Actor): return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))
	targets = targets.slice(0, 5)
	if targets.is_empty():
		targets = [self]   # nothing around: one meteor lands in front so the move isn't wasted
	for i in targets.size():
		var spot: Vector3 = targets[i].global_position if targets[i] != self else global_position - basis.z * 3.0
		spot.y = 0.0
		get_tree().create_timer(0.15 * i, false).timeout.connect(func(): _meteor(spot))


func _meteor(spot: Vector3) -> void:
	if Room.current == null:
		return
	var mark := U.floor_quad(Room.current, Vector2(4.4, 4.4), U.unlit(Color(1, 0.75, 0.3, 0.5), U.soft_circle()).duplicate(), spot + Vector3.UP * 0.05)
	var rock := Node3D.new()
	Room.current.add_child(rock)
	rock.global_position = spot + Vector3.UP * 9.0
	U.sphere(rock, 0.45, U.unlit(Color(1, 0.55, 0.2)))
	U.sphere(rock, 0.3, U.unlit(Color(1, 0.95, 0.7)))
	var tw := rock.create_tween()
	tw.tween_property(rock, "global_position", spot + Vector3.UP * 0.3, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		rock.queue_free()
		mark.queue_free()
		Fx.shockwave(spot, Color(1, 0.55, 0.2), 2.4)
		Fx.magic(spot + Vector3.UP * 0.5, Color(1, 0.6, 0.2), 20)
		Sfx.play("boom", 0.7)
		Game.shake(0.2)
		for a: Actor in Actor.all.duplicate():
			if a.team == Team.UNDEAD and a.can_be_hit() and a.global_position.distance_to(spot) < 2.2 + a.radius:
				_special_hit(a, damage * 3.0, spot, 8.0)
				if not a.dead:
					Burning.apply(a, maxf(burn_dps, 8.0), 3.0))


func _whirlwind(delta: float) -> void:
	_spin_left -= delta
	visual.rotation.y += delta * 22.0
	_spin_tick -= delta
	if _spin_tick <= 0.0:
		_spin_tick = 0.16
		Fx.trail(center(), Color(1, 0.7, 0.4))
		for a: Actor in Actor.all.duplicate():
			if a.team == Team.UNDEAD and a.can_be_hit() and a.global_position.distance_to(global_position) < 2.8 + a.radius:
				_special_hit(a, damage * 0.8, global_position, 5.0)
				heal(1.0)
	if _spin_left <= 0.0:
		visual.rotation.y = 0.0


func on_kill() -> void:
	var amount := heal_on_kill
	if Game.chain >= 2.0:
		amount += harvest_heal
	if amount > 0.0:
		heal(amount)


func _process(delta: float) -> void:
	if dead:
		return
	_update_ward_bubble()
	_update_dash_ring()
	_dash_cooldown -= delta
	if _dash_left > 0.0:
		_dash_left -= delta
		move_by(_dash_dir * DASH_SPEED * delta, delta)
		visual.set_moving(true)
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = 0.025
			Fx.trail(center(), Color(0.45, 0.8, 1.0))
		_shot_timer = maxf(_shot_timer, 0.1)
		_check_perfect(0.0)
		return
	if _invulnerable > 0.0:
		_invulnerable -= delta
		visual.set_visible_blink(_invulnerable <= 0.0 or fmod(_invulnerable, 0.12) > 0.05)

	var playing := Game.state == Game.State.PLAYING
	if _spin_left > 0.0 and playing:
		_whirlwind(delta)
		_shot_timer = maxf(_shot_timer, 0.1)
	var stick := Vector2.ZERO
	if playing:
		stick = Game.hud.joystick + Game.keyboard_move()
		stick = stick.limit_length(1.0)
	var move := Vector3(stick.x, 0, stick.y)
	_moving = move.length_squared() > 0.02
	visual.set_moving(_moving)

	if _moving:
		move_by(move * move_speed * (1.3 if _spin_left > 0.0 else 1.0) * delta, delta)
		face(move, 18.0, delta)
		_shot_timer = maxf(_shot_timer, 0.12)   # firing resumes shortly after you stop
	else:
		move_by(Vector3.ZERO, delta)
		if playing:
			_auto_attack(delta)

	if playing and Room.current and Room.current.is_at_exit(global_position):
		Game.enter_next_room()


func _auto_attack(delta: float) -> void:
	_shot_timer -= delta
	var target := _pick_target()
	if target == null:
		return
	var to := target.global_position - global_position
	face(to, 30.0, delta)
	if _shot_timer > 0.0:
		return
	_shot_timer = 1.0 / shots_per_second
	_shoot(to.normalized())


## The nearest skeleton the hero can actually hit; if every one is behind cover, just the nearest.
func _pick_target() -> Actor:
	var best: Actor = null
	var best_sq := INF
	for a: Actor in Actor.all:
		if a.team != Team.UNDEAD or not a.can_be_hit():
			continue
		var sq := (a.global_position - global_position).length_squared()
		if Room.current and not Room.current.clear_shot(global_position, a.global_position):
			sq += 10000.0
		if sq < best_sq:
			best_sq = sq
			best = a
	return best


func _shoot(fwd: Vector3) -> void:
	visual.attack()
	Sfx.play("shoot", 0.5)
	var right := fwd.cross(Vector3.UP).normalized()
	var origin := global_position + Vector3.UP * 1.1 + fwd * 0.6
	var col := Color(1.0, 0.55, 0.2) if burn_dps > 0.0 else bolt_color
	for i in front_bolts:
		var offset := (i - (front_bolts - 1) * 0.5) * 0.35
		_fire(origin + right * offset, fwd, col)
	for i in diagonal_bolts:
		var angle := deg_to_rad(30.0 + i * 15.0)
		_fire(origin, fwd.rotated(Vector3.UP, angle), col)
		_fire(origin, fwd.rotated(Vector3.UP, -angle), col)
	for i in rear_bolts:
		_fire(global_position + Vector3.UP * 1.1 - fwd * 0.6, -fwd, col)
	# Bone Storm: every third volley also throws a ring of piercing bone shards.
	_volleys += 1
	if perks.has("bonestorm") and _volleys % 3 == 0:
		for i in 10:
			var d := fwd.rotated(Vector3.UP, TAU * (i + 0.5) / 10.0)
			var p := Projectile.fire(Team.HERO, origin - fwd * 0.6 + d * 0.5, d, damage * 0.7 * Game.chain_damage(), bolt_speed * 0.85, Color(0.95, 0.92, 0.8), bolt_size * 0.9)
			p.pierce = 2
			p.push = bolt_push * 0.5


func _fire(origin: Vector3, d: Vector3, col: Color) -> void:
	var p := Projectile.fire(Team.HERO, origin, d, damage * Game.chain_damage(), bolt_speed, col, bolt_size)
	p.pierce = pierce
	p.push = bolt_push
	p.splash = splash
	p.crit_chance = crit_chance
	p.burn_dps = burn_dps
	p.frost = frost


func take_damage(amount: float, direction: Vector3, push: float, crit := false) -> void:
	if not can_be_hit():
		return
	if ward > 0:
		ward -= 1
		Game.report_event("ward")
		_invulnerable = 0.7
		Fx.magic(center(), Color(0.8, 0.9, 1.0), 24)
		Sfx.play("upgrade", 0.6)
		Game.shake(0.2)
		return
	if second_wind and amount * Game.damage_scale() * (1.0 - armor) >= health:
		second_wind = false
		Game.report_event("second_wind")
		health = max_health * 0.5
		_invulnerable = 2.0
		Fx.magic(center(), Color(1, 0.9, 0.5), 50)
		Sfx.play("victory", 0.6)
		Game.shake(0.4)
		Game.hud.banner("Second Wind!", Color(1, 0.9, 0.5))
		return
	var before := health
	super.take_damage(amount * Game.damage_scale() * (1.0 - armor), direction, push, crit)
	Game.report_damage(before - health)
	if dead:
		return
	Sfx.play("hurt")
	Input.vibrate_handheld(45)
	Game.shake(0.35)
	Game.hit_stop(0.06)
	_invulnerable = 0.7


## Grave Aura (a Curse mastery reward): a slow red glow on the floor under the hero.
func _build_aura() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 1.1
	disc.bottom_radius = 1.1
	disc.height = 0.02
	disc.radial_segments = 32
	var m := MeshInstance3D.new()
	m.mesh = disc
	var mat := U.unlit(Color(0.9, 0.12, 0.15, 0.22))
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(0, 0.03, 0)
	add_child(m)
	_aura = m


## A ring at the hero's feet: bright when the dash is ready, faint while it recharges.
func _build_dash_ring() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.72
	torus.rings = 32
	torus.ring_segments = 4
	_dash_ring = MeshInstance3D.new()
	_dash_ring.mesh = torus
	_ring_mat = U.unlit(Color(0.5, 0.85, 1.0, 0.55))
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_dash_ring.material_override = _ring_mat
	_dash_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dash_ring.position = Vector3(0, 0.05, 0)
	_dash_ring.scale = Vector3(1, 0.15, 1)
	add_child(_dash_ring)


func _update_dash_ring() -> void:
	if _aura:
		var s := 1.0 + sin(Time.get_ticks_msec() * 0.002) * 0.08
		_aura.scale = Vector3(s, 1, s)
	if _dash_ring == null:
		return
	var ready := dash_ready()
	var a := 0.12 + 0.12 * (1.0 - clampf(_dash_cooldown / DASH_COOLDOWN, 0.0, 1.0))
	if ready:
		a = 0.45 + sin(Time.get_ticks_msec() * 0.006) * 0.1
	_ring_mat.albedo_color.a = a
	var was_ready := _ring_was_ready
	_ring_was_ready = ready
	if ready and not was_ready:
		Fx.magic(global_position + Vector3.UP * 0.2, Color(0.5, 0.85, 1.0), 10)


## Refills Bone Ward at the start of each room.
func new_room() -> void:
	ward = ward_max


## A faint bubble around the hero while Bone Ward is up.
func _update_ward_bubble() -> void:
	if ward <= 0 or dead:
		if _ward_bubble:
			_ward_bubble.visible = false
		return
	if _ward_bubble == null:
		var mat := U.unlit(Color(0.7, 0.85, 1.0, 0.18))
		_ward_bubble = U.sphere(self, 0.95, mat, Vector3(0, 1.0, 0))
		_ward_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ward_bubble.visible = true
	var s := 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.04
	_ward_bubble.scale = Vector3(s, s, s)


func _on_death() -> void:
	visual.set_visible_blink(true)
	visual.die()
	Sfx.play("hurt")
	Game.shake(0.6)
	Game.on_hero_died()
