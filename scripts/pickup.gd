class_name Pickup
extends Node3D
## Things skeletons drop: glowing hearts that heal, and gold coins you keep between runs
## (spend them in the Armory). Walk near to collect. Once a room is cleared, anything
## left on the floor flies to the hero by itself.

## Before the floor's growth (Game.heart_mult) and Treasure Magnet.
const HEAL := 12.0
const MAGNET_HEAL := 1.3
const MAGNET_RANGE := 2.6
const COIN_MAGNET_RANGE := 3.6

static var all: Array[Pickup] = []

var coin := false
var value := 1
var _t := 0.0
var _gem: Node3D
var _homing := false
var _speed := 0.0
var _vel := Vector3.ZERO


static func drop(pos: Vector3) -> void:
	if Room.current == null:
		return
	var p := Pickup.new()
	Room.current.add_child(p)
	p.global_position = Vector3(pos.x, 0.0, pos.z)


## Scatter `total` coins' worth around a spot, in a few pieces.
static func drop_coins(pos: Vector3, total: int) -> void:
	if Room.current == null or total <= 0:
		return
	var pieces := clampi(total, 1, 4)
	for i in pieces:
		var p := Pickup.new()
		p.coin = true
		p.value = total / pieces + (1 if i < total % pieces else 0)
		Room.current.add_child(p)
		p.global_position = Vector3(pos.x, 0.0, pos.z)
		p._vel = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(1.5, 3.5)


func _enter_tree() -> void:
	all.append(self)


func _exit_tree() -> void:
	all.erase(self)


func _ready() -> void:
	_gem = Node3D.new()
	add_child(_gem)
	if coin:
		_build_coin()
		return
	# Green since version 116: pink hearts looked like the pink enemy shots.
	var red := U.mat(Color(0.3, 1.0, 0.45), 0.3, 2.2)
	# Two bumps and a point: a little heart.
	U.sphere(_gem, 0.17, red, Vector3(-0.12, 0.08, 0))
	U.sphere(_gem, 0.17, red, Vector3(0.12, 0.08, 0))
	var tip := U.box(_gem, Vector3(0.27, 0.27, 0.2), red, Vector3(0, -0.07, 0))
	tip.rotation.z = PI / 4
	var glow := U.floor_quad(self, Vector2(1.3, 1.3), U.unlit(Color(0.3, 1.0, 0.45, 0.5), U.soft_circle()), Vector3(0, 0.04, 0))
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Fx.magic(global_position + Vector3.UP * 0.6, Color(0.4, 1.0, 0.5), 8)


static var _gold: ShaderMaterial
static var _twinkle: ShaderMaterial
static var _twinkle_mesh: QuadMesh

## A proper gold coin (since version 136): a thick disc whose faces have a bright rim, a
## darker sunken middle and a stud, so it reads as a coin from every angle as it spins. The
## gold has a bright edge and a shine that sweeps across it, and now and then a star
## twinkles on it. One mesh and one star per coin, to keep the draw count low.
func _build_coin() -> void:
	if _gold == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode specular_schlick_ggx;
varying vec3 lp;
varying vec3 ln;
void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}
void fragment() {
	vec3 gold = vec3(1.0, 0.74, 0.18);
	float glow = 0.55;
	if (abs(ln.y) > 0.5) {
		float r = length(lp.xz);
		float face = smoothstep(0.185, 0.175, r) * smoothstep(0.06, 0.07, r);
		float ring = smoothstep(0.195, 0.186, r) * smoothstep(0.174, 0.183, r);
		gold = mix(gold, vec3(0.8, 0.5, 0.09), face);
		glow += ring * 0.6 - face * 0.25;
	}
	ALBEDO = gold;
	ROUGHNESS = 0.3;
	SPECULAR = 0.9;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float band = smoothstep(0.9, 1.0, sin(wp.x * 5.0 + wp.y * 7.0 - TIME * 4.0));
	EMISSION = gold * (glow + fres * 1.3) + vec3(1.0, 0.95, 0.75) * band * 0.7;
}
"""
		_gold = ShaderMaterial.new()
		_gold.shader = sh
		var tw := Shader.new()
		tw.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
varying float flash;
void vertex() {
	float seed = MODEL_MATRIX[3].x * 2.3 + MODEL_MATRIX[3].z * 1.7;
	flash = pow(max(0.0, sin(TIME * 2.0 + seed)), 30.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float star = max(0.0, 1.0 - abs(p.x) * 9.0) * max(0.0, 1.0 - abs(p.y)) + max(0.0, 1.0 - abs(p.y) * 9.0) * max(0.0, 1.0 - abs(p.x));
	star += max(0.0, 1.0 - length(p) * 3.0);
	ALBEDO = vec3(1.0, 0.95, 0.75);
	ALPHA = clamp(star, 0.0, 1.0) * flash;
}
"""
		_twinkle = ShaderMaterial.new()
		_twinkle.shader = tw
		_twinkle_mesh = QuadMesh.new()
		_twinkle_mesh.size = Vector2(0.6, 0.6)
	var c := U.cylinder(_gem, 0.25, 0.08, _gold, Vector3(0, -0.04, 0))
	c.rotation.x = PI / 2 - 0.55   # leaning back, so the face catches the eye as it spins
	var star := MeshInstance3D.new()
	star.mesh = _twinkle_mesh
	star.material_override = _twinkle
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star.position = Vector3(0.1, 0.12, 0.06)
	_gem.add_child(star)
	var shine := U.floor_quad(self, Vector2(0.9, 0.9), U.unlit(Color(1, 0.8, 0.3, 0.45), U.soft_circle()), Vector3(0, 0.04, 0))
	shine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## What one heart heals. Treasure Magnet's hearts heal 30% more.
static func heart_heal(hero: Hero) -> float:
	return HEAL * Game.heart_mult() * (MAGNET_HEAL if hero.magnet > 1.0 else 1.0)


## Collect everything at once (before leaving a room), so nothing is lost.
static func grant_all() -> void:
	var hero := Game.hero
	for p in all.duplicate():
		if p.coin:
			Game.add_coins(p.value)
		elif hero and not hero.dead:
			hero.heal(heart_heal(hero))
		p.queue_free()
	all.clear()


## Called when a room is cleared: everything left flies to the hero.
static func collect_all() -> void:
	for p in all:
		p._homing = true


func _process(delta: float) -> void:
	_t += delta
	_gem.position.y = (0.55 if coin else 0.75) + sin(_t * 3.0) * 0.12
	_gem.rotation.y = _t * (5.0 if coin else 2.0)
	if _vel.length_squared() > 0.01:
		# Coins skid out a little when they drop.
		var p := global_position + _vel * delta
		if Room.current:
			p = Room.current.resolve_move(global_position, _vel * delta, 0.2)
		global_position = p
		_vel = _vel.move_toward(Vector3.ZERO, 8.0 * delta)
	var hero := Game.hero
	if hero == null or hero.dead:
		return
	var to := hero.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var wanted := coin or hero.health < hero.max_health
	var magnet := (COIN_MAGNET_RANGE if coin else MAGNET_RANGE) * (hero.magnet if hero else 1.0)
	if _homing or (wanted and dist < magnet):
		_speed = minf(_speed + 30.0 * delta, 16.0)
		global_position += to.normalized() * minf(_speed * delta, dist)
	if dist < hero.radius + 0.35 and (wanted or _homing):
		if coin:
			if Game.hud:
				Game.hud.fly_coin(global_position + Vector3.UP * 0.6, value)   # to the coin counter
			Game.add_coins(value)
			Sfx.coin(0.45)
		else:
			hero.heal(heart_heal(hero))
			Sfx.play("pickup", 0.6)
			Fx.magic(hero.center(), Color(1, 0.35, 0.45), 14)
		queue_free()
