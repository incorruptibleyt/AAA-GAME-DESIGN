class_name InkDouble
extends Enemy
## The Archivist's Mirror Page (archivist.gd, version 276): the hero's own double in ink,
## climbing out of a page torn from its tome. It wears the hero's own looks, gone glossy black
## with the whispering glowing at its edges, and it copies the hero's every step as in a
## mirror: across the middle of the room (left for right), so the closer the hero comes to
## the middle, the closer it comes, and it hurts to touch. When the hero stands still to
## fight, it throws ink back at them along a strip (step aside). Fragile: break it, or it dries
## up after a while.

const LIFE := 10.0
## How long the hero must stand still before it throws, the gap between throws, its warning.
const STILL := 0.35
const THROW_GAP := 1.5
const THROW_AIM := 0.5
const BLOT_SPEED := 11.0
const BLOT_DAMAGE := 12.0
const BLOT := Color(0.3, 0.95, 0.8)
## How fast it flows after its mirror spot (metres a second): it keeps up with a walk and
## trails a dash.
const FOLLOW := 15.0

static var _ink_mat: ShaderMaterial

var _life := LIFE
var _still := 0.0
var _throw := 0.8


func _setup() -> void:
	die_sound = "ink"
	init_health(60.0)
	move_speed = 0.0
	contact_damage = 10.0
	drop_chance = 0.0
	radius = 0.45
	center_height = 1.0
	knockback_scale = 0.0
	var id := Game.hero.hero_id if Game.hero else "rogue"
	var def := HeroStyle.styled(Game._load_save(), Heroes.get_hero(id))
	def.style.erase("legend")   # (the ink copies the hero, not their pet)
	var look := Heroes.look(def)
	look.overlay = _ink()
	make_visual(look)


func display_name() -> String:
	return "Ink Double"


func coin_value() -> int:
	return 0


## Glossy black ink over the whole body, a teal edge and drips of light running down it.
static func _ink() -> ShaderMaterial:
	if _ink_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_back;
varying vec3 lp;
float hash(float x) { return fract(sin(x * 91.7) * 43758.5453); }
void vertex() { lp = VERTEX; }
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float col = floor((lp.x + lp.z * 0.7) * 9.0);
	float drip = step(0.72, hash(col)) * smoothstep(0.25, 0.0, fract(lp.y * 0.6 + TIME * 0.35 + hash(col + 3.0)));
	float sheen = pow(clamp(dot(NORMAL, normalize(vec3(0.3, 1.0, 0.4))), 0.0, 1.0), 12.0);
	vec3 ink = vec3(0.015, 0.02, 0.04) + vec3(0.25, 0.32, 0.4) * sheen;
	ALBEDO = mix(ink, vec3(0.35, 1.0, 0.82) * 1.4, clamp(rim * 0.85 + drip * 0.6, 0.0, 1.0));
	ALPHA = 0.94;
}
"""
		_ink_mat = ShaderMaterial.new()
		_ink_mat.shader = sh
	return _ink_mat


func _think(hero: Hero, delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		_dry()
		return
	# Its mirror spot: the hero's, left for right across the middle of the room. Ink flows
	# where it likes (props don't stop it).
	var want := Vector3(-hero.global_position.x, 0.0, hero.global_position.z)
	global_position = global_position.move_toward(want, FOLLOW * delta)
	rotation.y = -hero.rotation.y
	visual.set_moving(hero._moving)
	if randf() < delta * 6.0:
		Fx._burst(global_position + Vector3.UP * randf_range(0.3, 1.6), 1, Color(0.03, 0.04, 0.08, 0.9), 0.15, 0.5, 0.5, 6.0)
	# The hero stands still to fight: it throws ink back at them.
	_still = 0.0 if hero._moving else _still + delta
	_throw -= delta
	if _still >= STILL and _throw <= 0.0:
		var to := hero.global_position - global_position
		to.y = 0.0
		if to.length() > 1.4:
			_throw = THROW_GAP
			var d := to.normalized()
			track(Telegraph.line(global_position, d, to.length() + 1.5, 0.7, THROW_AIM, _fling.bind(d), 0.35))
			visual.attack()


func _fling(d: Vector3) -> void:
	if dead:
		return
	Sfx.play("ink", 0.5, 1.3)
	Projectile.fire(Team.UNDEAD, global_position + Vector3.UP * 1.0 + d * 0.5, d, BLOT_DAMAGE, BLOT_SPEED, BLOT, 0.34, "Ink Double", "quill")


## Its time is up: it runs back into a puddle of ink and is gone (no reward).
func _dry() -> void:
	Fx._burst(global_position + Vector3.UP * 0.5, 16, Color(0.03, 0.04, 0.08, 0.95), 0.3, 2.0, 0.6, 7.0)
	crumble()


func _on_death() -> void:
	Fx._burst(center(), 22, Color(0.03, 0.04, 0.08, 0.95), 0.35, 3.5, 0.6, 8.0)
	Fx.magic(center(), Color(0.35, 1.0, 0.82), 12)
	super._on_death()
