class_name SkeletonArcher
extends Enemy
## Keeps its distance and fires aimed arrows after a short warning line.

var _shot_timer := 1.5
var _aiming := false
var _strafe := 1.0


func _setup() -> void:
	init_health(28.0)
	move_speed = 2.4
	contact_damage = 8.0
	radius = 0.5
	center_height = 1.0
	var look := bones(Art.SKELETON_ROGUE, 2.0, Color(1.0, 0.85, 0.2))
	look.bow = true
	look.hood = true
	look.accent = Color(0.2, 0.35, 0.2)
	make_visual(look)


func _think(hero: Hero, delta: float) -> void:
	var to := hero.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	_shot_timer -= delta
	if _aiming:
		stand(delta)
		face(to, 20.0, delta)
		return

	if dist < 5.0:
		walk(-to, delta)          # too close: back off
	elif dist > 9.0:
		walk(to, delta)           # too far: close in
	else:
		if randf() < delta * 0.5:
			_strafe = -_strafe
		walk(to.normalized().cross(Vector3.UP) * _strafe, delta, 0.6)

	if _shot_timer <= 0.0 and dist < 12.0:
		_aiming = true
		var d := to.normalized()
		track(Telegraph.line(global_position, d, minf(dist + 2.0, 12.0), 0.35, 0.55, func(): _release(d)))


func _release(d: Vector3) -> void:
	_aiming = false
	_shot_timer = randf_range(2.0, 2.6)
	if dead:
		return
	visual.attack()
	var p := Projectile.fire(Team.UNDEAD, global_position + Vector3.UP * 0.9 + d * 0.5, d, 12.0, 10.0, Color(1, 0.8, 0.3), 0.2)
	p.push = 5.0
