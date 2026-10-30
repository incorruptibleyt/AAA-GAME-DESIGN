class_name SkeletonMinion
extends Enemy
## Small, fast and fragile. Comes in groups and runs straight at you.

var _wobble := 0.0


func _setup() -> void:
	init_health(22.0)
	move_speed = 3.1
	contact_damage = 10.0
	drop_chance = 0.05
	radius = 0.45
	center_height = 0.75
	_wobble = randf() * 10.0
	var look := bones(Art.SKELETON_MINION, 1.55, Color(0.4, 1.0, 0.5))
	look.weapon = "Skeleton_Blade"
	look.attack_anim = "1H_Melee_Attack_Chop"
	make_visual(look)


func _think(hero: Hero, delta: float) -> void:
	_wobble += delta
	var to := (hero.global_position - global_position).normalized()
	# A little side-to-side weave so a pack doesn't move as one blob.
	var side := to.cross(Vector3.UP) * sin(_wobble * 3.0) * 0.4
	walk(to + side, delta)
