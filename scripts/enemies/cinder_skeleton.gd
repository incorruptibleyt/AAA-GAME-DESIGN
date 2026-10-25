class_name CinderSkeleton
extends Enemy
## Ember Catacomb floors only. A burning skeleton that runs at you, leaving patches of
## fire behind it, and bursts into a bigger one when it dies. Kill it fast, keep moving,
## and don't stand in the flames.

var _drop := 0.9


func _setup() -> void:
	init_health(30.0)
	move_speed = 3.1
	contact_damage = 10.0
	radius = 0.45
	center_height = 0.9
	var look := bones(Art.SKELETON_MINION, 1.75, Color(1.0, 0.6, 0.15))
	look.tint = Color(0.5, 0.14, 0.0, 1.0)
	look.horns = true
	look.accent = Color(0.5, 0.2, 0.1)
	make_visual(look)


func _think(hero: Hero, delta: float) -> void:
	var to := hero.global_position - global_position
	to.y = 0.0
	walk(to, delta)
	_drop -= delta
	if _drop <= 0.0:
		_drop = 1.1
		FirePatch.spawn(global_position, 0.9, 3.0)
	if randf() < delta * 4.0:
		Fx.magic(center(), Color(1, 0.5, 0.15), 3)


func _on_death() -> void:
	super._on_death()
	FirePatch.spawn(global_position, 1.4, 3.5)
