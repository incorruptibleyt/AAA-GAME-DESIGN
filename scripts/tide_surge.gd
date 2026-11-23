class_name TideSurge
extends Node3D
## Version 293 (the Drowned Vault's own danger): the tide. Every few seconds the sea breaks
## into the vault: a groan and a rumble from the far end, the shallow water draws back, and a
## foaming wave rolls down the whole room towards the door you came in by. Whoever it passes
## over is knocked off their feet and carried a few metres with it (hurt, and maybe swept
## into skeletons or traps), skeletons too. Two ways to beat it: get right behind cover (a
## pillar, a crate, a statue breaks the wave), or dash through the crest.

const SEA := Color(0.35, 0.85, 0.8)
const EVERY := 10.0          # seconds from one wave to the next
const FIRST := 4.0           # the first warning, once the skeletons have climbed out
const WARN := 1.6            # the rumble before the wave appears
const SPEED := 6.0           # m/s down the room
const PUSH := 16.0           # how hard it carries you (about 3 m)
const DAMAGE := 7.0          # to the hero, before the floor's damage scale (x2.9 on floor 6: about 20)
const FOE_SHARE := 0.25      # to skeletons: this share of their full health
const SHELTER := 2.6         # metres behind cover that the wave doesn't reach

## The room's tide, if there is one (for the test robot).
static var current: TideSurge = null

var front := INF             # where the crest is (z), INF when there is no wave
var _t := 0.0
var _hit := {}
var _said := false
var _crest: Node3D
var _crest_mat: ShaderMaterial
var _wash: MeshInstance3D
var _wash_mat: StandardMaterial3D
var _room: Room
var _warned := false


static func lay(room: Room) -> TideSurge:
	var s := TideSurge.new()
	s.name = "TideSurge"
	room.add_child(s)
	s._room = room
	s._build()
	s._t = EVERY - FIRST - WARN
	current = s
	return s


## For the shader warm-up (warmup.gd): a crest standing still.
static func warm(parent: Node, at: Vector3) -> void:
	var s := TideSurge.new()
	s.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(s)
	s.position = at
	s._build()
	s._crest.visible = true
	s._crest.position = Vector3.ZERO


func _exit_tree() -> void:
	if current == self:
		current = null


## The crest: a long curl of green-blue water topped with white foam, standing across the
## whole room and facing the door; behind it a sheet of fresh water that fades out.
func _build() -> void:
	_crest = Node3D.new()
	add_child(_crest)
	_crest.visible = false
	_crest_mat = ShaderMaterial.new()
	_crest_mat.shader = _shader()
	var q := QuadMesh.new()
	q.size = Vector2(Room.HALF_W * 2.0, 1.7)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _crest_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.78, 0)
	mi.rotation.x = 0.35   # leaning forward, like a breaking wave
	_crest.add_child(mi)
	_wash_mat = U.unlit(Color(0.05, 0.3, 0.34, 0.55)).duplicate() as StandardMaterial3D
	_wash = U.floor_quad(_crest, Vector2(Room.HALF_W * 2.0, 3.0), _wash_mat, Vector3(0, 0.04, -1.5))
	# White foam running out in front of the crest.
	var foam := ShaderMaterial.new()
	var fsh := Shader.new()
	fsh.code = FOAM
	foam.shader = fsh
	U.floor_quad(_crest, Vector2(Room.HALF_W * 2.0, 1.0), foam, Vector3(0, 0.05, 0.55))


func _process(delta: float) -> void:
	if Game.state == Game.State.PAUSED:
		return
	delta = minf(delta, Actor.MAX_STEP)
	if front == INF and not (Game.state == Game.State.PLAYING and Game.fight_on()):
		_warned = false
		return
	if front != INF:
		_roll(delta)
		return
	_t += delta
	if _t >= EVERY - WARN and not _warned:
		_warned = true
		Sfx.play("splash", 0.7, 0.5)
		Game.shake(0.25)
		if not _said:
			_said = true
			Game.hud.callout("THE TIDE! GET BEHIND COVER OR DASH!", SEA, true)
		else:
			Game.hud.callout("TIDE!", SEA, false)
	if _warned and randf() < delta * 14.0:
		Fx.magic(Vector3(randf_range(-Room.HALF_W, Room.HALF_W), 0.3, -Room.HALF_L + 0.4), SEA, 3)
	if _t >= EVERY:
		_t = 0.0
		_warned = false
		front = -Room.HALF_L
		_hit.clear()
		_crest.visible = true
		Sfx.play("splash", 1.0, 0.7)


func _roll(delta: float) -> void:
	var before := front
	front += SPEED * delta
	_crest.position = Vector3(0, 0, front)
	_crest_mat.set_shader_parameter("travel", front)
	if randf() < delta * 20.0:
		Fx.magic(Vector3(randf_range(-Room.HALF_W, Room.HALF_W), 0.8, front), Color(0.9, 1.0, 1.0), 4)
	for a: Actor in Actor.all.duplicate():
		if a.dead or _hit.has(a) or (a is Enemy and (a as Enemy).is_boss):
			continue
		var z := a.global_position.z
		if z < before - 0.3 or z > front:
			continue
		_hit[a] = true
		if a is Hero and (a as Hero).is_dashing():
			Fx.magic(a.center(), SEA, 10)
			continue
		if sheltered(a.global_position):
			continue
		if not a.can_be_hit():
			continue
		Fx.impact(a.center(), SEA, 1.6)
		Sfx.play("splash", 0.6, 1.2)
		if a is Hero:
			Game.hit_source = "The tide"
			a.take_damage(DAMAGE, Vector3.BACK, PUSH)
			Game.buzz(50)
		else:
			a.take_damage(a.max_health * FOE_SHARE, Vector3.BACK, PUSH)
	if front > Room.HALF_L + 1.5:
		front = INF
		_crest.visible = false


## Whether `p` is in the lee of cover: something solid just upstream of it (the wave comes
## from the far end, negative z).
func sheltered(p: Vector3) -> bool:
	var room := _room if _room != null else Room.current
	if room == null:
		return false
	for o: Dictionary in room.obstacles:
		var dz := p.z - float(o.pos.z)
		if dz > 0.0 and dz < SHELTER and absf(p.x - float(o.pos.x)) < float(o.r) + 0.15:
			return true
	return false


## For the test robot: where to stand to be out of the coming wave, or INF if no wave is
## coming yet: the spot just behind the nearest cover.
func refuge(p: Vector3) -> Vector3:
	if front == INF and not _warned:
		return Vector3.INF
	if front != INF and front > p.z + 0.5:
		return Vector3.INF   # already past
	var room := _room if _room != null else Room.current
	var best := Vector3.INF
	var best_d := INF
	for o: Dictionary in room.obstacles:
		var spot := Vector3(float(o.pos.x), 0, float(o.pos.z) + float(o.r) + 0.55)
		if front != INF and spot.z < front:
			continue
		var d := spot.distance_to(p)
		if d < best_d:
			best_d = d
			best = spot
	return best


## Broken white foam spilling out ahead of the crest, thinning out towards its edge.
const FOAM := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	float ahead = UV.y;                          // 0 at the crest, 1 at the foam's leading edge
	float n = noise(vec2(UV.x * 40.0, UV.y * 5.0 + TIME * 2.0)) * 0.6 + noise(vec2(UV.x * 90.0, UV.y * 11.0 - TIME)) * 0.4;
	float a = smoothstep(ahead * 0.85, ahead * 0.85 + 0.15, n);
	ALBEDO = mix(vec3(0.5, 0.85, 0.85), vec3(0.95, 1.0, 1.0), n);
	ALPHA = a * (1.0 - smoothstep(0.6, 1.0, ahead)) * 0.9;
}
"""

static var _sh: Shader

## The crest: deep green-blue below, a white rolling lip of foam on top, streaks of foam
## running down it, ragged along the top edge.
static func _shader() -> Shader:
	if _sh != null:
		return _sh
	_sh = Shader.new()
	_sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform float travel = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	float x = UV.x * 12.0;
	float up = 1.0 - UV.y;                       // 0 at the floor, 1 at the top
	float top = 0.82 + (noise(vec2(x * 1.3, TIME * 2.0)) - 0.5) * 0.3;
	float body = 1.0 - smoothstep(top - 0.04, top, up);
	float lip = smoothstep(top - 0.35, top - 0.08, up) * body;
	float streak = smoothstep(0.62, 0.8, noise(vec2(x * 3.0, up * 2.0 - TIME * 3.0))) * body;
	vec3 deep = vec3(0.01, 0.1, 0.14);
	vec3 sea = vec3(0.05, 0.35, 0.4);
	vec3 col = mix(deep, sea, smoothstep(0.0, 0.7, up));
	col = mix(col, vec3(0.92, 1.0, 0.98), max(lip, streak * 0.7));
	ALBEDO = col;
	ALPHA = body * mix(0.75, 0.98, max(lip, up));
}
"""
	return _sh
