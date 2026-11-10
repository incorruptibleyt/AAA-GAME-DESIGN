class_name QueenShade
extends Enemy
## The Blood Moon Queen's Eclipse (blood_queen.gd): while she hides in the dark, three or
## four Shades of her stand round the room, dark red ghosts of her that fire slow fans of
## blood orbs. Destroy them all to drag her back out.

const RED := Color(1.0, 0.22, 0.18)

var _cast := 0.0


func _setup() -> void:
	init_health(55.0)
	move_speed = 0.9
	contact_damage = 0.0
	drop_chance = 0.0
	radius = 0.7
	center_height = 1.4
	knockback_scale = 0.2
	var look := bones(Art.SKELETON_MAGE, 3.0, RED)
	look.tint = Color(0.45, 0.02, 0.05)
	look.accent = Color(0.2, 0.02, 0.04)
	look.weapon = "Skeleton_Staff"
	look.attack_anim = "Spellcast_Shoot"
	look.hide = ["Skeleton_Mage_Hat"]
	make_visual(look)
	_cast = randf_range(1.0, 1.8)


func display_name() -> String:
	return "Shade of the Queen"


func coin_value() -> int:
	return 0


func _think(hero: Hero, delta: float) -> void:
	var to := hero.global_position - global_position
	to.y = 0.0
	stand(delta)
	face(to, 8.0, delta)
	if randf() < delta * 4.0:
		Fx.magic(center() + Vector3(randf_range(-0.5, 0.5), randf_range(-0.6, 0.8), randf_range(-0.5, 0.5)), RED, 1)
	_cast -= delta
	if _cast <= 0.0:
		_cast = randf_range(2.0, 2.6)
		visual.attack(true)
		Sfx.play("shimmer", 0.35, 0.7)
		var d := to.normalized() if to.length() > 0.01 else Vector3.FORWARD
		for i in 3:
			var dir := d.rotated(Vector3.UP, (i - 1) * 0.35)
			Projectile.fire(Team.UNDEAD, center() + dir * 0.6, dir, 10.0, 6.0, RED, 0.34, "The Blood Moon Queen")
