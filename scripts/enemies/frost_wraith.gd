class_name FrostWraith
extends Enemy
## Frozen Ossuary floors only. Keeps its distance, marks a line towards you, then fires
## an ice beam down it. Step out of the line: a hit also freezes you slow for a moment.

var _timer := 2.2
var _casting := 0.0


func _setup() -> void:
	init_health(40.0)
	move_speed = 2.0
	contact_damage = 8.0
	radius = 0.5
	center_height = 1.0
	var look := bones(Art.SKELETON_MAGE, 2.0, Color(0.55, 0.9, 1.0))
	look.tint = Color(0.05, 0.2, 0.4, 1.0)
	look.hat = true
	look.accent = Color(0.3, 0.5, 0.75)
	look.weapon = "Skeleton_Staff"
	make_visual(look)


func _think(hero: Hero, delta: float) -> void:
	var to := hero.global_position - global_position
	to.y = 0.0
	if _casting > 0.0:
		_casting -= delta
		stand(delta)
		face(to, 4.0, delta)
		return
	if to.length() > 8.0:
		walk(to, delta)
	elif to.length() < 4.5:
		walk(-to, delta)
	else:
		stand(delta)
		face(to, 8.0, delta)
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(3.3, 4.0)
		_casting = 1.1
		visual.attack(true)
		var dir := to.normalized()
		var from := global_position + dir * 0.6
		Fx.magic(center() + Vector3.UP * 0.3, Color(0.6, 0.9, 1.0), 14)
		track(Telegraph.line(from, dir, 10.0, 1.3, 0.9, func(): _beam(from, dir)))


func _beam(from: Vector3, dir: Vector3) -> void:
	Sfx.play("crack", 0.7)
	for i in 9:
		Fx.magic(from + dir * (i * 1.2) + Vector3.UP * 0.6, Color(0.7, 0.95, 1.0), 4)
	var hero := Game.hero
	if hero == null or hero.dead:
		return
	var rel := hero.global_position - from
	rel.y = 0.0
	var along := rel.dot(dir)
	var side := (rel - dir * along).length()
	if along < -0.5 or along > 10.0 + hero.radius or side > 0.65 + hero.radius * 0.6:
		return
	var before := hero.health
	Game.hit_source = "Frost Wraith"
	hero.take_damage(14.0, dir, 6.0)
	if hero.health < before:
		hero.chill(1.6)
