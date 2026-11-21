class_name FrostRing
extends Node3D
## A ring of frost spreading out across the floor (version 243): the Bell Ringer's toll. It
## grows from its bell out to REACH; the hero it passes over (not dashing) is hurt and
## chilled, once. A glowing band on the floor with a pale edge, so it reads on wood and snow.

const SPEED := 4.6
const REACH := 8.5
const BAND := 0.42
const DAMAGE := 9.0

var _r := 0.4
var _col := Color(0.55, 0.88, 1.0)
var _source := "Bell Ringer"
var _done := false
var _mesh: MeshInstance3D
var _mat: ShaderMaterial
static var _shader: Shader


static func ring(at: Vector3, col: Color, source: String) -> FrostRing:
	if Room.current == null:
		return null
	var f := FrostRing.new()
	f._col = col
	f._source = source
	Room.current.add_child(f)
	f.global_position = Vector3(at.x, 0.06, at.z)
	f._build()
	Sfx.play("shimmer", 0.8, 0.9)
	Sfx.play("tick", 0.5, 0.6)
	return f


## The warm-up (warmup.gd): one ring standing still, so its shader is ready.
static func warm_up(holder: Node3D, at: Vector3) -> void:
	var f := FrostRing.new()
	f.set_process(false)
	holder.add_child(f)
	f.position = at + Vector3(0, 0.06, 0)
	f._build()


func _build() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODE
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.set_shader_parameter("col", _col)
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	q.orientation = PlaneMesh.FACE_Y
	_mesh = MeshInstance3D.new()
	_mesh.mesh = q
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	_size()


func _size() -> void:
	var outer := _r + BAND
	_mesh.scale = Vector3(outer, 1.0, outer)
	_mat.set_shader_parameter("inner", (_r - BAND) / outer)
	_mat.set_shader_parameter("fade", clampf((REACH - _r) / 1.5, 0.0, 1.0))


func _process(delta: float) -> void:
	if Game.state == Game.State.PAUSED:
		return
	if Game.state != Game.State.PLAYING:
		queue_free()
		return
	_r += SPEED * delta
	_size()
	var hero := Game.hero
	if not _done and hero and hero.can_be_hit():
		var d := hero.global_position - global_position
		d.y = 0.0
		if absf(d.length() - _r) < BAND + hero.radius * 0.4:
			_done = true
			Game.hit_source = _source
			hero.take_damage(DAMAGE, d.normalized() if d.length() > 0.05 else Vector3.BACK, 5.0)
			hero.chill(1.6)
	if _r >= REACH:
		queue_free()


const CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 col : source_color = vec4(0.55, 0.88, 1.0, 1.0);
uniform float inner = 0.8;
uniform float fade = 1.0;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float band = smoothstep(inner - 0.02, inner + 0.06, d) * (1.0 - smoothstep(0.94, 1.0, d));
	float edge = 1.0 - smoothstep(0.0, 0.05, abs(d - 0.96));
	float ripple = 0.65 + 0.35 * sin(d * 60.0 - TIME * 8.0);
	ALBEDO = col.rgb * band * ripple * 0.9 + vec3(1.0) * edge * 0.8;
	ALPHA = 1.0;
	ALBEDO *= fade;
}
"""
