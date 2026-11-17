class_name BoneSpitter
extends Enemy
## A squat skeleton that never moves. Every couple of seconds it glows and spits a fan
## of three bone shards at you. Use pillars as cover.

var _timer := 1.5
var _charging := 0.0


func _setup() -> void:
	init_health(45.0)
	move_speed = 0.0
	contact_damage = 8.0
	radius = 0.6
	center_height = 0.8
	knockback_scale = 0.0
	var look := bones(Art.SKELETON_MINION, 1.8, Color(0.5, 1.0, 0.3))
	look.tint = Color(0.1, 0.35, 0.05, 1.0)
	look.horns = true
	look.accent = Color(0.2, 0.35, 0.15)
	look.offhand = "Skeleton_Shield_Small_A"
	look.attack_anim = "Spellcast_Shoot"
	make_visual(look)


func _think(hero: Hero, delta: float) -> void:
	var to := hero.global_position - global_position
	to.y = 0.0
	# Version 180: a Spitter behind a pillar or crate steps round it until it can see the
	# hero (it stood there for good, out of the hero's reach, and the room never ended).
	# (Version 182: it walks at a real pace for this. Its move_speed is 0, so before it only
	# ran on the spot until the 7 s rescue moved it.)
	if hidden_from_hero() and _charging <= 0.0:
		move_speed = 1.3
		walk(to, delta, 1.0)
		move_speed = 0.0
		return
	stand(delta)
	face(to, 6.0, delta)
	if _charging > 0.0:
		_charging -= delta
		if _charging <= 0.0:
			_spit(to.normalized())
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(2.4, 3.0)
		_charging = 0.85   # a longer glow before the spit (was 0.7)
		Fx.magic(center() + Vector3.UP * 0.3, Color(0.5, 1.0, 0.3), 12)
		Sfx.play("warn", 0.4)


func _spit(d: Vector3) -> void:
	visual.attack()
	Sfx.play("shoot", 0.7)
	# Version 168: one shard instead of a fan of three in the tutorial.
	for angle in ([0.0] if Game.first_run else [-0.28, 0.0, 0.28]):
		var dir := d.rotated(Vector3.UP, angle)
		# Shards fly at 7 m/s (were 8), easier to dodge: they were a top-three damage source on
		# floor 3 in every run report.
		Projectile.fire(Team.UNDEAD, global_position + Vector3.UP * 0.9 + dir * 0.6, dir, 10.0, 7.0, Color(0.6, 1.0, 0.4), 0.22, "Bone Spitter")
