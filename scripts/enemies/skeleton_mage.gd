class_name SkeletonMage
extends Enemy
## Marks a circle where you're standing, then blows it up. Keep moving!

var _cast_timer := 1.8
var _casting := 0.0


func _setup() -> void:
	init_health(34.0)
	move_speed = 1.6
	contact_damage = 8.0
	radius = 0.5
	center_height = 1.0
	var look := bones(Art.SKELETON_MAGE, 2.0, Color(0.7, 0.4, 1.0))
	look.hat = true
	look.accent = Color(0.3, 0.18, 0.45)
	look.weapon = "Skeleton_Staff"
	make_visual(look)


func _think(hero: Hero, delta: float) -> void:
	var to := hero.global_position - global_position
	to.y = 0.0
	_cast_timer -= delta
	if _casting > 0.0:
		_casting -= delta
		stand(delta)
		face(to, 10.0, delta)
		return
	if to.length() > 7.0:
		walk(to, delta)
	elif to.length() < 4.0:
		walk(-to, delta)
	else:
		stand(delta)
		face(to, 10.0, delta)

	if _cast_timer <= 0.0:
		_casting = 0.5
		_cast_timer = randf_range(2.8, 3.4)
		visual.attack(true)
		var spot := hero.global_position
		Fx.magic(center() + Vector3.UP * 0.3, Color(0.7, 0.4, 1.0), 14)
		track(Telegraph.circle(spot, 1.7, 1.0, func(): SkeletonMage.explode(spot, 1.7, 18.0)))


static func explode(spot: Vector3, r: float, dmg: float) -> void:
	Fx.magic(spot + Vector3.UP * 0.3, Color(0.75, 0.45, 1.0), 30)
	Sfx.play("boom", 0.7)
	Game.shake(0.15)
	var hero := Game.hero
	if hero == null:
		return
	var d := hero.global_position - spot
	d.y = 0.0
	if d.length() < r + hero.radius * 0.5:
		Game.hit_source = "Magic blast"
		hero.take_damage(dmg, d, 8.0)
