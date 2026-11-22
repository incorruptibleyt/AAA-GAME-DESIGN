class_name SandMound
extends Node3D
## A mound of sand left where a column of the Sand Pharaoh's Sandfall lands (version 274, the
## Sandfall Tomb's own boss). Wading through it slows the hero (Hero.mire) until they are out;
## a dash is never slowed. It sinks back into the floor after a few seconds, so the room
## fills up with sand the longer the fight goes on between its falls, then clears again.

const SAND := Color(0.98, 0.82, 0.5)
## How fast the hero wades through it (of their usual speed), and how long a mound lasts.
const SLOW := 0.5
const LIFE := 6.0
const HEIGHT := 0.5

## Every mound on the floor (the test robot walks out of them).
static var all: Array[SandMound] = []
static var _mesh: SphereMesh
static var _mat: ShaderMaterial

var radius := 1.2
var _age := 0.0
var _body: MeshInstance3D


static func spawn(at: Vector3, r: float) -> SandMound:
	var parent := Telegraph._parent()
	if parent == null:
		return null
	var m := SandMound.new()
	m.radius = r
	parent.add_child(m)
	m.global_position = Vector3(at.x, 0.0, at.z)
	m._build()
	return m


## For the shader warm-up (warmup.gd): a mound that just sits there.
static func warm(parent: Node, at: Vector3) -> void:
	var m := SandMound.new()
	m.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(m)
	m.position = at
	m._build()
	m._body.scale = Vector3(m.radius, HEIGHT, m.radius)


func _enter_tree() -> void:
	all.append(self)


func _exit_tree() -> void:
	all.erase(self)


## Whether `p` (a body `r` round) is standing in the sand.
func covers(p: Vector3, r := 0.0) -> bool:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length() <= radius * 0.92 + r


func _build() -> void:
	if _mesh == null:
		_mesh = SphereMesh.new()
		_mesh.radius = 1.0
		_mesh.height = 1.0
		_mesh.is_hemisphere = true
		_mesh.radial_segments = 24
		_mesh.rings = 6
		var sh := Shader.new()
		sh.code = SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = sh
	_body = MeshInstance3D.new()
	_body.mesh = _mesh
	_body.material_override = _mat
	_body.scale = Vector3(radius * 0.8, 0.02, radius * 0.8)
	add_child(_body)


func _process(delta: float) -> void:
	_age += delta
	var k := minf(_age / 0.22, 1.0)
	if _age > LIFE:
		k = 1.0 - (_age - LIFE) / 0.7
		if k <= 0.0:
			queue_free()
			return
	var w := radius * (0.8 + 0.2 * k)
	_body.scale = Vector3(w, maxf(HEIGHT * k, 0.02), w)
	var hero := Game.hero
	if k > 0.5 and hero and not hero.dead and Game.state == Game.State.PLAYING and covers(hero.global_position):
		hero.mire(0.15)


## Pale desert sand blown into ripples, grains glinting, shaded darker down to a dark foot
## where it meets the floor, so it stands up off the sandstone as a heap, not a flat disc.
const SHADER := """
shader_type spatial;
render_mode cull_back;
varying vec3 lp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { lp = VERTEX; }
void fragment() {
	float r = length(lp.xz);
	float ripple = 0.5 + 0.5 * sin(lp.x * 13.0 + lp.z * 4.0 + sin(lp.z * 6.0) * 1.6);
	float grain = hash(floor(lp.xz * 60.0));
	vec3 sand = vec3(0.9, 0.72, 0.45) * (0.86 + 0.14 * ripple) * (0.9 + 0.1 * grain);
	// A heap: lightest on its crown, falling away darker to the foot.
	sand *= mix(1.08, 0.6, smoothstep(0.15, 1.0, r));
	sand = mix(sand, vec3(0.38, 0.25, 0.13), smoothstep(0.82, 1.0, r) * 0.6);
	ALBEDO = sand;
	ROUGHNESS = 0.95;
	EMISSION = vec3(1.0, 0.85, 0.5) * step(0.985, grain) * 0.4;
}
"""
