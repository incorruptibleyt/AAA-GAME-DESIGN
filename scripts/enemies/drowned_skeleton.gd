class_name DrownedSkeleton
extends Enemy
## Drowned Vault floors only (Crypt Pass). A bare skeleton grown over with weed. It sinks
## into the water and swims at you as a ripple you can't hit, stops, and a circle marks
## where it will burst up. Then it stays up for a few seconds to fight. Step out of the
## circle, then hit it while it is up.

enum Mode { UP, SINKING, UNDER, RISING }

const WATER := Color(0.5, 1.0, 0.92)
## Seconds to sink, longest swim, and the warning before it bursts up.
const SINK := 0.45
const SWIM := 2.4
const RISE := 0.8
## How far below the floor the body goes, in metres.
const DEPTH := 2.0

var _mode := Mode.UP
## Seconds left in the current mode (the first sink comes soon after it climbs out).
var _timer := 1.4
var _ripple := 0.0
var _touch_damage := 10.0


func _setup() -> void:
	init_health(34.0)
	move_speed = 2.2
	contact_damage = _touch_damage
	radius = 0.45
	center_height = 0.9
	var look := bones(Art.SKELETON_ROGUE, 1.85, Color(0.45, 1.0, 0.9))
	look.overlay = WetLook.overlay(0.12)
	look.accent = Color(0.12, 0.25, 0.2)
	look.weapon = "Skeleton_Blade"
	# Bare bones, no hood or cape: pale enough to see on the dark water (and unlike the
	# hooded archers).
	look.hide = ["Skeleton_Rogue_Hood", "Skeleton_Rogue_Cape"]
	make_visual(look)


## Only while it is up (or just going under) can it be hit or aimed at.
func can_be_hit() -> bool:
	return super.can_be_hit() and (_mode == Mode.UP or _mode == Mode.SINKING)


func _think(hero: Hero, delta: float) -> void:
	_timer -= delta
	var to := hero.global_position - global_position
	to.y = 0.0
	match _mode:
		Mode.UP:
			if to.length() > 1.0:
				walk(to, delta)
			else:
				stand(delta)
			if _timer <= 0.0:
				_sink()
		Mode.SINKING:
			stand(delta)
			visual.position.y = -DEPTH * (1.0 - clampf(_timer / SINK, 0.0, 1.0))
			if _timer <= 0.0:
				_mode = Mode.UNDER
				_timer = SWIM
				visual.visible = false
		Mode.UNDER:
			visual.position.y = -DEPTH
			# A wake of ripples and bubbles crossing the floor towards the hero.
			if to.length() > 0.5:
				move_by(to.normalized() * 4.0 * delta, delta)
			_ripple -= delta
			if _ripple <= 0.0:
				_ripple = 0.22
				Fx.shockwave(global_position, WATER, 0.9)
				Fx.magic(global_position + Vector3.UP * 0.2, WATER, 2)
			if _timer <= 0.0 or to.length() < 0.8:
				_mode = Mode.RISING
				_timer = RISE
				var at := global_position
				track(Telegraph.circle(at, 1.2, RISE, func(): _burst_up(at)))
		Mode.RISING:
			visual.position.y = -DEPTH
			if randf() < delta * 12.0:
				Fx.magic(global_position + Vector3.UP * 0.2, WATER, 3)


func _sink() -> void:
	_mode = Mode.SINKING
	_timer = SINK
	contact_damage = 0.0
	Sfx.play("splash", 0.45, 0.9)
	Fx.magic(global_position + Vector3.UP * 0.3, WATER, 14)
	Fx.shockwave(global_position, WATER, 1.6)


## Bursts out of the water where the warning was, hurting the hero if they stayed in it.
func _burst_up(at: Vector3) -> void:
	if dead:
		return
	_mode = Mode.UP
	_timer = randf_range(2.8, 3.6)
	contact_damage = _touch_damage
	visual.visible = true
	visual.position.y = 0.0
	visual.attack()
	Sfx.play("splash", 0.7, 1.1)
	Fx.magic(at + Vector3.UP * 0.5, WATER, 26)
	Fx.shockwave(at, WATER, 1.8)
	var hero := Game.hero
	if hero == null:
		return
	var d := hero.global_position - at
	d.y = 0.0
	if d.length() < 1.2 + hero.radius * 0.5:
		Game.hit_source = kind_name()
		hero.take_damage(12.0, d, 9.0)


func _on_death() -> void:
	visual.visible = true
	visual.position.y = 0.0
	super._on_death()
	Fx.magic(center(), WATER, 18)
