class_name FireSeam
extends Node3D
## Version 291 (the Ember Catacomb's own danger): fire seams. Two long charred cracks run
## across the floor of the catacomb's rooms, and they take turns erupting: a seam glows,
## rumbles and spits embers first, then a wall of fire roars up along it for a moment. The
## wall burns whoever stands in it (hero and skeletons alike, so lure them in) and burns up
## every shot that tries to cross it, yours and theirs: while it is up it splits the room,
## and it is cover from archers. A dash leaps through it unhurt.
##
## One FireSeam node is one crack; FireSeam.all holds the room's, and the first one keeps
## the turn-taking.

const HOT := Color(1.0, 0.55, 0.15)
const CALM := 2.4           # seconds between one seam dying down and the next one warning
const WARN := 1.2           # the glow and rumble before it erupts
const BURN := 2.0           # how long the wall of fire stays up
const FIRST := 3.0          # the first warning, once the skeletons have climbed out
const HALF_W := 0.6         # this close to the seam's line: in the fire
const DAMAGE := 11.0        # to the hero, before the floor's damage scale (x1.7 on floor 3: about 19)
const FOE_SHARE := 0.3      # to skeletons: this share of their full health
const STEP := 0.34          # metres between the flames of the wall

## Every seam in the room (projectile.gd asks them whether a shot is burned up).
static var all: Array[FireSeam] = []
static var _said := false

var length := 6.0
var heat := 0.0             # 0 calm, rising to 1 through the warning, 1 + while burning
var burning := false
var warning := false
var _mat: ShaderMaterial
var _flames: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _burnt := {}
## Only the room's first seam keeps the clock.
var _clock := false
var _t := 0.0
var _which := 0


## Lays two seams across `room`, apart from each other and clear of cover.
static func lay(room: Room) -> void:
	_said = false
	var placed: Array[FireSeam] = []
	for attempt in 80:
		if placed.size() >= 2:
			break
		var ln := randf_range(5.0, 7.0) if attempt < 50 else randf_range(3.8, 5.0)
		var c := Vector3(randf_range(-1.6, 1.6), 0, randf_range(-6.5, 2.5))
		var ang := randf_range(-0.55, 0.55)
		var along := Vector3(cos(ang), 0, -sin(ang))
		var ok := true
		for s in placed:
			if absf(s.position.z - c.z) < 3.6:
				ok = false
		if ok:
			for k in 9:
				var p := c + along * ln * (k / 8.0 - 0.5)
				if absf(p.x) > Room.HALF_W - 0.4:
					ok = false
					break
				for o: Dictionary in room.obstacles:
					if Vector2(p.x - o.pos.x, p.z - o.pos.z).length() < float(o.r) + 0.75:
						ok = false
				for sp: Dictionary in room.spawns:
					if Vector2(p.x - sp.pos.x, p.z - sp.pos.z).length() < 0.9:
						ok = false
				if not ok:
					break
		if not ok:
			continue
		var s := FireSeam.new()
		s.name = "FireSeam"
		s.length = ln
		room.add_child(s)
		s.position = c
		s.rotation.y = ang
		s._build()
		placed.append(s)
	if placed.is_empty():
		return
	var first := placed[0]
	first._clock = true
	first._which = randi() % placed.size()
	first._t = -FIRST + CALM   # so the first warning comes FIRST seconds in


## For the shader warm-up (warmup.gd): a seam with its fire up, standing still.
static func warm(parent: Node, at: Vector3) -> void:
	var s := FireSeam.new()
	s.length = 2.0
	s.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(s)
	s.position = at
	s._build()
	s._show(1.5)


func _enter_tree() -> void:
	all.append(self)


func _exit_tree() -> void:
	all.erase(self)


func _build() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = _shader()
	_mat.set_shader_parameter("seed", randf() * 100.0)
	_mat.set_shader_parameter("seam_len", length)
	U.floor_quad(self, Vector2(length + 0.6, 1.8), _mat, Vector3(0, 0.025, 0))
	# Broken black rock heaped along its lips.
	var rock := U.mat(Color(0.09, 0.07, 0.07), 0.95)
	var n := int(length / 0.4)
	for i in n:
		var x := (i + 0.5) / n * length - length * 0.5
		var side := 1.0 if i % 2 == 0 else -1.0
		var r := U.sphere(self, randf_range(0.1, 0.19), rock, Vector3(x + randf_range(-0.15, 0.15), 0.0, side * randf_range(0.5, 0.66)))
		r.scale.y = 0.55
	# The flames of the wall, hidden until it erupts.
	var m := int(length / STEP)
	for i in m:
		var x := (i + 0.5) / m * length - length * 0.5
		var f := Fx.flame(self, Vector2(0.9, 1.0), Vector3(x, 0, randf_range(-0.06, 0.06)))
		f.visible = false
		_flames.append(f)
	_light = OmniLight3D.new()
	_light.light_color = HOT
	_light.omni_range = length * 0.6 + 1.5
	_light.light_energy = 0.0
	_light.position = Vector3(0, 0.8, 0)
	add_child(_light)


func _process(delta: float) -> void:
	if not _clock or Game.state == Game.State.PAUSED:
		return
	delta = minf(delta, Actor.MAX_STEP)
	var seams: Array[FireSeam] = []
	for s in all:
		if is_instance_valid(s) and s.get_parent() == get_parent():
			seams.append(s)
	if seams.is_empty():
		return
	_which = _which % seams.size()
	var s: FireSeam = seams[_which]
	if not (Game.state == Game.State.PLAYING and Game.fight_on()):
		for o in seams:
			o._calm()
		return
	_t += delta
	if _t < CALM:
		s._calm()
	elif _t < CALM + WARN:
		var k := (_t - CALM) / WARN
		if not s.warning:
			s.warning = true
			Sfx.play("ignite", 0.35, 0.6)
			if not _said:
				_said = true
				Game.hud.callout("FIRE SEAM! IT BURNS SHOTS AND YOU!", HOT, true)
		s._show(k)
	elif _t < CALM + WARN + BURN:
		if not s.burning:
			s.burning = true
			s.warning = false
			s._burnt.clear()
			Sfx.play("ignite", 0.8, 0.9)
			Fx.shockwave(s.global_position, HOT, s.length * 0.5)
		s._show(1.0 + (_t - CALM - WARN))
		s._scorch()
	else:
		s._calm()
		_t = 0.0
		_which = (_which + 1) % seams.size()


## How the seam looks at `k`: 0-1 warning (glowing up, a few low tongues of fire), 1+ the
## wall of fire.
func _show(k: float) -> void:
	heat = k
	_mat.set_shader_parameter("heat", minf(k, 1.0))
	var t := Time.get_ticks_msec() / 1000.0
	if k < 1.0:
		_light.light_energy = 0.9 * k * (0.7 + 0.3 * sin(t * 25.0))
		for i in _flames.size():
			var f := _flames[i]
			f.visible = i % 3 == 0 and k > 0.35
			f.scale = Vector3(0.45, 0.3 + 0.5 * k, 1.0)
			f.position.y = f.scale.y * 0.5
		if randf() < 0.3:
			Fx.sparks(to_global(Vector3(randf_range(-0.5, 0.5) * length, 0.1, 0)), HOT)
		return
	var rise := clampf((k - 1.0) / 0.18, 0.0, 1.0)
	var fall := clampf((1.0 + BURN - k) / 0.3, 0.0, 1.0)
	var h := 2.3 * minf(rise, fall)
	_light.light_energy = 2.6 * minf(rise, fall) + 0.3 * sin(t * 31.0)
	for i in _flames.size():
		var f := _flames[i]
		f.visible = h > 0.05
		var wob := 0.8 + 0.4 * sin(t * 9.0 + i * 1.7)
		f.scale = Vector3(0.95, maxf(h * wob, 0.05), 1.0)
		f.position.y = f.scale.y * 0.5


func _calm() -> void:
	if heat == 0.0 and not burning and not warning:
		return
	heat = 0.0
	burning = false
	warning = false
	_mat.set_shader_parameter("heat", 0.0)
	_light.light_energy = 0.0
	for f in _flames:
		f.visible = false


## Burns whoever stands in the wall of fire (once each eruption) and throws them out of it.
func _scorch() -> void:
	if heat < 1.1:
		return   # the flames are still climbing
	for a: Actor in Actor.all.duplicate():
		if a.dead or _burnt.has(a) or (a is Enemy and (a as Enemy).is_boss):
			continue
		if a is Hero and (a as Hero).is_dashing():
			continue
		var l := to_local(a.global_position)
		if absf(l.x) > length * 0.5 + 0.1 or absf(l.z) > HALF_W + a.radius * 0.5:
			continue
		if not a.can_be_hit():
			continue
		_burnt[a] = true
		var out := global_transform.basis * Vector3(0, 0, 1.0 if l.z >= 0.0 else -1.0)
		out.y = 0.0
		Fx.impact(a.center(), HOT, 1.4)
		Fx.sparks(a.center(), HOT)
		if a is Hero:
			Game.hit_source = "Fire seam"
			a.take_damage(DAMAGE, out.normalized(), 11.0)
			Game.buzz(60)
		else:
			a.take_damage(a.max_health * FOE_SHARE, out.normalized(), 9.0)


## Whether a shot flying from `a` to `b` this frame goes into a wall of fire that is up
## (projectile.gd burns it up).
static func burns(a: Vector3, b: Vector3) -> bool:
	for s in all:
		if not is_instance_valid(s) or not s.burning or s.heat < 1.1:
			continue
		var la := s.to_local(Vector3(a.x, 0, a.z))
		var lb := s.to_local(Vector3(b.x, 0, b.z))
		if absf(lb.x) > s.length * 0.5 + 0.1:
			continue
		if absf(lb.z) < 0.25 or signf(la.z) != signf(lb.z):
			return true
	return false


## Which way to step to get out of a seam that is warning or burning, if `p` is near it
## (for the test robot), or zero.
static func away(p: Vector3) -> Vector3:
	for s in all:
		if not is_instance_valid(s) or not (s.burning or (s.warning and s.heat > 0.3)):
			continue
		var l := s.to_local(Vector3(p.x, 0, p.z))
		if absf(l.x) < s.length * 0.5 + 0.4 and absf(l.z) < HALF_W + 0.9:
			var out := s.global_transform.basis * Vector3(0, 0, 1.0 if l.z >= 0.0 else -1.0)
			out.y = 0.0
			return out.normalized()
	return Vector3.ZERO


static var _sh: Shader

## A long charred crack: a dark scorched band with ragged edges, and down its middle a
## jagged molten line that brightens from a dull red to white-hot as `heat` rises.
static func _shader() -> Shader:
	if _sh != null:
		return _sh
	_sh = Shader.new()
	_sh.code = """
shader_type spatial;
render_mode blend_mix, unshaded, cull_back, depth_draw_never, shadows_disabled;
uniform float seed = 0.0;
uniform float seam_len = 6.0;
uniform float heat = 0.0;
float hash(float x) { return fract(sin(x * 127.1 + seed) * 43758.5453); }
float n1(float x) { float i = floor(x); float f = fract(x); f = f * f * (3.0 - 2.0 * f); return mix(hash(i), hash(i + 1.0), f); }
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453); }
void fragment() {
	float total = seam_len + 0.6;
	float x = (UV.x - 0.5) * total;          // metres along the seam
	float z = (UV.y - 0.5) * 1.8;            // metres across
	float ends = 1.0 - smoothstep(seam_len * 0.5 - 0.4, seam_len * 0.5 + 0.15, abs(x));
	// The jagged line down the middle, and a thinner split that wanders off it.
	float mid = (n1(x * 1.6) - 0.5) * 0.4 + (n1(x * 5.0 + 7.0) - 0.5) * 0.1;
	float d = abs(z - mid);
	float d2 = abs(z - mid - (n1(x * 2.3 + 30.0) - 0.5) * 0.7);
	float branch = step(0.55, n1(x * 0.9 + 50.0));
	float w = 0.06 + heat * 0.07;
	float core = (1.0 - smoothstep(w * 0.4, w, d)) * ends;
	float split = (1.0 - smoothstep(0.008, 0.02 + heat * 0.015, d2)) * branch * ends * 0.8;
	float glow = (1.0 - smoothstep(0.0, 0.18 + heat * 0.2, d)) * ends;
	// The scorched band, ragged at its edges.
	float edge = 0.62 + (n1(x * 3.0 + 13.0) - 0.5) * 0.22;
	float band = (1.0 - smoothstep(edge - 0.12, edge, abs(z))) * ends;
	float ash = h2(floor(vec2(x, z) * 18.0)) * 0.06;
	vec3 molten = mix(vec3(0.95, 0.18, 0.03), mix(vec3(1.0, 0.45, 0.08), vec3(1.0, 0.95, 0.7), smoothstep(0.6, 1.0, heat)), smoothstep(0.0, 0.5, heat));
	float m = max(core, split);
	vec3 charred = vec3(0.035 + ash, 0.025 + ash * 0.5, 0.025);
	ALBEDO = mix(charred + molten * glow * (0.35 + heat * 0.9), molten * (1.3 + heat * 0.6), m);
	ALPHA = clamp(max(band * 0.96, max(m, glow * 0.6)), 0.0, 1.0);
}
"""
	return _sh
