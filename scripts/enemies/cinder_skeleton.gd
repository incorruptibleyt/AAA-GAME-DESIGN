class_name CinderSkeleton
extends Enemy
## Ember Catacomb floors only. A charred skeleton with glowing cracks, black horns and a
## burning skull, that runs at you leaving patches of fire behind it, and bursts into a
## bigger one when it dies. Kill it fast, keep moving, and don't stand in the flames.

var _drop := 0.9
var _flame: MeshInstance3D
static var _char_mat: ShaderMaterial


func _setup() -> void:
	init_health(30.0)
	move_speed = 3.1
	contact_damage = 10.0
	radius = 0.45
	center_height = 0.9
	var look := bones(Art.SKELETON_MINION, 1.75, Color(1.0, 0.6, 0.15))
	look.overlay = _charred()
	look.horns = true
	look.accent = Color(0.5, 0.2, 0.1)
	# Bare burnt bones: no cloak, so it doesn't look like a plain Skeleton.
	look.hide = ["Skeleton_Minion_Cloak"]
	make_visual(look)
	_dress()


## Burnt black bones with cracks of fire that pulse: a darkening pass, then the glow.
static func _charred() -> ShaderMaterial:
	if _char_mat:
		return _char_mat
	var dark := Shader.new()
	dark.code = """
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_back;
void fragment() {
	ALBEDO = vec3(0.3, 0.22, 0.2);
}
"""
	var glow := Shader.new()
	glow.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 glow : source_color = vec4(1.0, 0.42, 0.06, 1.0);
varying vec3 p;
void vertex() {
	p = VERTEX;
}
float h(vec3 q) {
	return fract(sin(dot(q, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}
float vn(vec3 q) {
	vec3 i = floor(q);
	vec3 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h(i), h(i + vec3(1, 0, 0)), f.x), mix(h(i + vec3(0, 1, 0)), h(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h(i + vec3(0, 0, 1)), h(i + vec3(1, 0, 1)), f.x), mix(h(i + vec3(0, 1, 1)), h(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void fragment() {
	float n = vn(p * 6.0) * 0.65 + vn(p * 13.0) * 0.35;
	float crack = smoothstep(0.86, 0.97, 1.0 - abs(n * 2.0 - 1.0));
	float pulse = 0.7 + 0.3 * sin(TIME * 3.0 + p.y * 4.0);
	ALBEDO = glow.rgb * (crack * 1.8 + 0.06) * pulse;
}
"""
	_char_mat = ShaderMaterial.new()
	_char_mat.shader = dark
	var cracks := ShaderMaterial.new()
	cracks.shader = glow
	_char_mat.next_pass = cracks
	return _char_mat


func _dress() -> void:
	var skel := Art._find_skeleton(visual)
	if skel == null or skel.find_bone("head") < 0:
		return
	var att := BoneAttachment3D.new()
	skel.add_child(att)
	att.bone_name = "head"
	var horn_mat := U.mat(Color(0.1, 0.07, 0.06), 0.6)
	for side in [-1.0, 1.0]:
		var horn := U.capsule(att, 0.07, 0.5, horn_mat, Vector3(side * 0.42, 0.85, -0.05))
		horn.rotation.z = -side * 0.55
	# The skull burns.
	_flame = Fx.flame(att, Vector2(0.75, 1.1), Vector3(0, 0.75, 0))


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
	Sfx.play("ignite", 0.8)
	if _flame:
		_flame.create_tween().tween_property(_flame, "scale", Vector3.ZERO, 0.4)
	Fx.magic(center(), Color(1, 0.55, 0.15), 24)
	FirePatch.spawn(global_position, 1.4, 3.5)
