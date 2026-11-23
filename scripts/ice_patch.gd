class_name IcePatch
extends Node3D
## Version 290 (the Frozen Ossuary's own danger): sheets of black ice on the floor. On ice the
## hero slides: the stick only slowly turns and speeds them (hero.gd, Hero._ice_vel), and when
## they let go they keep gliding, still shooting, so it is easy to slide into a skeleton, a
## spike trap or a Frost Wraith's beam. A dash that ends on ice carries on as a long slide.
## Skeletons slip on it too and walk slowly (enemy.gd), so leading them across it buys time.

const ICE := Color(0.7, 0.9, 1.0)
const GRIP := 6.0           # m/s/s: how fast the hero can change speed on ice
const DRAG := 1.6           # m/s/s: how fast a slide dies away with the stick let go
const FOE_SLOW := 0.6       # skeletons' speed on ice

## Every patch in the room.
static var all: Array[IcePatch] = []
static var _mat: ShaderMaterial

var half := Vector2(2.0, 1.4)   # the ellipse's half sizes (x, z)


## Lays two or three sheets of ice on open floor in `room`, clear of where the hero walks in.
static func lay(room: Room) -> void:
	var count := 3 if randf() < 0.4 else 2
	var placed: Array[Vector3] = []
	for attempt in 60:
		if placed.size() >= count:
			break
		var h := Vector2(randf_range(1.6, 2.4), randf_range(1.2, 1.8))
		var p := Vector3(randf_range(-Room.HALF_W + h.x * 0.6, Room.HALF_W - h.x * 0.6), 0, randf_range(-7.0, 4.0))
		var ok := true
		for q in placed:
			if q.distance_to(p) < 4.0:
				ok = false
		if not ok:
			continue
		placed.append(p)
		var ice := IcePatch.new()
		ice.name = "IcePatch"
		ice.half = h
		room.add_child(ice)
		ice.position = p
		ice.rotation.y = randf_range(-0.5, 0.5)
		ice._build()


## For the shader warm-up (warmup.gd).
static func warm(parent: Node, at: Vector3) -> void:
	var ice := IcePatch.new()
	parent.add_child(ice)
	ice.position = at
	ice._build()


## The sheet of ice under `p`, or null.
static func under(p: Vector3) -> IcePatch:
	for ice in all:
		if is_instance_valid(ice) and ice.covers(p):
			return ice
	return null


func covers(p: Vector3) -> bool:
	var l := global_transform.affine_inverse() * Vector3(p.x, 0, p.z)
	return Vector2(l.x / half.x, l.z / half.y).length_squared() < 0.92


func _enter_tree() -> void:
	all.append(self)


func _exit_tree() -> void:
	all.erase(self)


func _build() -> void:
	if _mat == null:
		var sh := Shader.new()
		sh.code = SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = sh
	U.floor_quad(self, Vector2(half.x * 2.2, half.y * 2.2), _mat, Vector3(0, 0.02, 0))
	# Frost on its rim: little white lumps of snow pushed up round the edge.
	var snow := U.mat(Color(0.88, 0.94, 1.0), 0.9)
	for i in 9:
		var a := TAU * i / 9.0 + randf() * 0.4
		var s := U.sphere(self, randf_range(0.08, 0.16), snow, Vector3(cos(a) * half.x * 0.98, 0.0, sin(a) * half.y * 0.98))
		s.scale.y = 0.45


## Clear black ice: dark, glossy, the floor faint beneath it, white cracks and trapped bubbles,
## a pale frosted rim, and a sheen that slides across it.
const SHADER := """
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	vec2 q = (UV - 0.5) * 2.2;                     // the ellipse is the unit circle
	float wob = (noise(q * 3.0) - 0.5) * 0.12;
	float r = length(q) + wob;
	float inside = 1.0 - smoothstep(0.9, 0.97, r);
	float rim = smoothstep(0.7, 0.93, r) * inside;
	// White cracks: thin bands where a stretched noise crosses one value.
	float c1 = abs(noise(q * vec2(2.5, 6.0) + 3.0) - 0.5);
	float c2 = abs(noise(q * vec2(5.5, 2.0) + 9.0) - 0.5);
	float crack = (1.0 - smoothstep(0.0, 0.025, c1)) * 0.8 + (1.0 - smoothstep(0.0, 0.018, c2)) * 0.5;
	float bubble = step(0.985, hash(floor(q * 26.0))) * 0.7;
	float sheen = smoothstep(0.88, 1.0, sin((q.x + q.y) * 2.2 - TIME * 0.6)) * 0.25;
	vec3 col = mix(vec3(0.05, 0.1, 0.17), vec3(0.55, 0.7, 0.85), rim * 0.75);
	col += vec3(0.7, 0.85, 1.0) * (crack + bubble) * (1.0 - rim) * 0.6;
	col += vec3(1.0) * sheen;
	ALBEDO = col;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	ALPHA = inside * (0.8 + 0.15 * rim);
}
"""
