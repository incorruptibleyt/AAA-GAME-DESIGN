class_name SkeletonBomber
extends Enemy
## Carries a bomb and runs at you. When it gets close it stops, a red circle appears,
## and then it blows up, hurting everything nearby (other skeletons too). Kill it first,
## or run!

const BLAST_RADIUS := 2.2
var _lit := false
var _exploded := false


func _setup() -> void:
	init_health(18.0)
	move_speed = 3.5
	contact_damage = 0.0
	radius = 0.45
	center_height = 0.75
	drop_chance = 0.1
	var look := bones(Art.SKELETON_MINION, 1.55, Color(1.0, 0.55, 0.1))
	look.bomb = true
	look.tint = Color(0.3, 0.12, 0.0, 1.0)
	look.accent = Color(0.45, 0.25, 0.1)
	look.attack_anim = "Spellcast_Raise"
	make_visual(look)


func _think(hero: Hero, delta: float) -> void:
	if _lit:
		stand(delta)
		return
	var to := hero.global_position - global_position
	to.y = 0.0
	walk(to, delta)
	if to.length() < 2.0:
		_lit = true
		visual.attack()
		var spot := global_position
		track(Telegraph.circle(spot, BLAST_RADIUS, 0.75, func(): _blow_up()))


func coin_value() -> int:
	return 0 if _exploded else super.coin_value()   # no reward if it blew itself up


func _blow_up() -> void:
	if dead:
		return
	var spot := global_position
	Fx.magic(spot + Vector3.UP * 0.5, Color(1.0, 0.5, 0.1), 40)
	Fx.dust(spot, 20)
	Sfx.play("boom")
	Game.shake(0.35)
	for a: Actor in Actor.all.duplicate():
		if a == self or not a.can_be_hit():
			continue
		var d := a.global_position - spot
		d.y = 0.0
		if d.length() < BLAST_RADIUS + a.radius * 0.5:
			if a is Hero:
				Game.hit_source = "Bomber"
			a.take_damage(22.0 if a is Hero else 30.0, d, 10.0)
	# The blast takes the bomber with it.
	drop_chance = 0.0
	_exploded = true
	take_damage(9999.0, Vector3.ZERO, 0.0)
