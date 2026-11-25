class_name SkeletonArcher
extends Enemy
## Keeps its distance and fires aimed arrows after a short warning line.

var _shot_timer := 1.5
var _aiming := false
var _strafe := 1.0
## At most this many archers aim at once (difficulty review fix 7): a third waits its turn, so
## three or four archers never fire one wall of arrows with no gap to dash through.
const MAX_AIMING := 2


func _setup() -> void:
	die_sound = "die_archer"
	init_health(28.0)
	move_speed = 2.4
	contact_damage = 8.0
	radius = 0.5
	center_height = 1.0
	var look := bones(Art.SKELETON_ROGUE, 2.1, Color(1.0, 0.85, 0.2))
	# Version 343: tall and thin, long legs and arms, a quiver of arrows on its back.
	look.shape = {"scale": {"chest": 0.8, "head": 1.1, "upperarm.l": 1.3, "upperarm.r": 1.3, "upperleg.l": 1.5, "upperleg.r": 1.5}}
	look.parts = "quiver"
	look.bow = true
	look.hood = true
	look.accent = Color(0.2, 0.35, 0.2)
	look.weapon = "Skeleton_Crossbow"
	look.attack_anim = "1H_Ranged_Shoot"
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
		if _others_aiming() >= MAX_AIMING:
			_shot_timer = randf_range(0.3, 0.7)   # wait a moment: too many arrows on the way already
			return
		_aiming = true
		var d := to.normalized()
		track(Telegraph.line(global_position, d, minf(dist + 2.0, 12.0), 0.35, 0.55, func(): _release(d)))


func _release(d: Vector3) -> void:
	_aiming = false
	_shot_timer = randf_range(2.0, 2.6)
	if dead:
		return
	visual.attack()
	var p := Projectile.fire(Team.UNDEAD, global_position + Vector3.UP * 0.9 + d * 0.5, d, 8.0 if Game.first_run else 12.0, 10.0, Color(1, 0.8, 0.3), 0.2, "Archer", "arrow")   # slower in the tutorial (version 169)
	p.push = 5.0


func _others_aiming() -> int:
	var n := 0
	for a: Actor in Actor.all:
		if a != self and a is SkeletonArcher and not a.dead and (a as SkeletonArcher)._aiming:
			n += 1
	return n


## Version 211 (Tweaks report #2): a rescue (out of a wall, out of cover, unstuck) cancels
## the aim line, and with it the callback that fires the arrow and ends the aim. Without
## this the archer stood aiming for the rest of the room and never shot again.
func _cancel_attacks() -> void:
	super._cancel_attacks()
	_aiming = false
	_shot_timer = randf_range(1.0, 1.6)
