class_name Telegraph
extends Node3D
## A red marker on the floor that warns where an attack will land, then calls back.
## Fair warnings are what make dodging feel skilful instead of random.
## Version 135: one glowing shape drawn by a shader (it used to be three flat red quads): a
## dark outline so it reads on any floor, a bright rim, faint stripes moving the way the
## attack goes, and a fill that grows from the caster (or the middle) with a bright edge, so
## you can see exactly when it lands; it flashes just before. On the red Ember floor its
## middle burns yellow-white. Dashing out of one as it lands is a perfect dodge (dodged()).

## How long after a line warning lands it still counts for a perfect dodge (charges and
## lunges hit just after their strip fills). A circle has already hit once it lands, so
## dashing out of it afterwards is not a dodge.
const AFTER := 0.3

## Warnings on the floor right now, plus ones that landed in the last AFTER seconds.
static var active: Array[Telegraph] = []

var duration := 1.0
var elapsed := 0.0
var on_done: Callable
var _mat: ShaderMaterial
var _is_line := false
var _radius := 0.0
var _width := 0.0
var _length := 0.0
var _fired := false
## A marker that never hurts (the Lich showing where it will reappear): no PERFECT for it.
var harmless := false
## Version 116: an ordinary skeleton's swipe doesn't count for a PERFECT (they were too easy
## to step out of, 19 in two minutes); an elite's counts with a lighter slow-motion.
var perfectable := true
var light := false


static func _parent() -> Node:
	return Room.current if Room.current else Game.world


## The middle of a warning: red, or yellow-white on the Ember floor where red would vanish.
## Version 140: ice white on the Blood Moon floor, where gold melted into the gold inlay.
static func _core(alpha: float) -> Color:
	if Floors.blood_moon():
		return Color(0.85, 0.97, 1.0, alpha)
	return Color(1, 0.86, 0.5, alpha) if Floors.hot() else Color(1, 0.2, 0.1, alpha)


## The faint area a warning covers before its middle fills in. TC-6: on the Ember floor it
## is amber, not red, and each endless loop (darker, redder rooms) makes it a bit stronger,
## so a deep Ember warning reads as clearly as one on floor 3.
static func _area(alpha: float) -> Color:
	var deeper := 1.0 + 0.25 * clampi(Loops.loop_of(Game.floor_num) - 1, 0, 3)
	var a := minf(alpha * deeper, 0.9)
	if Floors.blood_moon():
		return Color(0.45, 0.85, 1.0, minf(a * 1.4, 0.9))   # ice cyan
	return Color(1, 0.62, 0.22, minf(a * 1.4, 0.9)) if Floors.hot() else Color(1, 0.15, 0.1, a)


## Is `pos` (with radius `r`) inside a warning that lands within `window` seconds, or (a
## line) landed less than AFTER seconds ago? The hero's Grave Dash asks this.
## 0: nothing dodged; 1: a light PERFECT (an elite's swipe); 2: a full one (shots, lunges,
## blasts and boss attacks).
static func dodged(pos: Vector3, r: float, window: float) -> int:
	var best := 0
	for t in active:
		if not is_instance_valid(t) or t.is_queued_for_deletion() or t.harmless or not t.perfectable:
			continue
		var left := t.duration - t.elapsed
		var late := -AFTER if t._is_line else 0.0
		if left <= window and left >= late and t._covers(pos, r):
			best = maxi(best, 1 if t.light else 2)
	return best


func _covers(pos: Vector3, r: float) -> bool:
	var p := to_local(Vector3(pos.x, global_position.y, pos.z))
	if _is_line:
		return absf(p.x) <= _width * 0.5 + r and p.z <= r and p.z >= -_length - r
	return Vector2(p.x, p.z).length() <= _radius + r


func _enter_tree() -> void:
	active.append(self)


func _exit_tree() -> void:
	active.erase(self)


## A circle of `r` around a point. `volume`: how loud its warning beep is (0 = none; a
## minion's swipe beeps softly, or a pack would beep all the time).
static func circle(pos: Vector3, r: float, seconds: float, done: Callable, volume := 0.6) -> Telegraph:
	var t := Telegraph.new()
	_parent().add_child(t)
	t.global_position = Vector3(pos.x, 0.03, pos.z)
	t._radius = r
	t._mat = _material(Vector2(r, 0.0), false)
	U.floor_quad(t, Vector2(r * 2 + 0.4, r * 2 + 0.4), t._mat)
	t.duration = seconds
	t.on_done = done
	if volume > 0.0:
		Sfx.play("warn", volume)
	return t


## A strip from `origin` going `length` along `direction` (charges, aimed shots).
static func line(origin: Vector3, direction: Vector3, length: float, width: float, seconds: float, done: Callable) -> Telegraph:
	var t := Telegraph.new()
	t._is_line = true
	_parent().add_child(t)
	direction.y = 0.0
	t.global_position = Vector3(origin.x, 0.03, origin.z)
	t.rotation.y = atan2(-direction.x, -direction.z)
	t._width = width
	t._length = length
	t._mat = _material(Vector2(width, length), true)
	U.floor_quad(t, Vector2(width + 0.4, length + 0.4), t._mat, Vector3(0, 0, -length / 2))
	t.duration = seconds
	t.on_done = done
	Sfx.play("warn", 0.6)
	return t


func _process(delta: float) -> void:
	elapsed += delta
	if _fired:
		if elapsed >= duration + AFTER:
			queue_free()
		return
	_mat.set_shader_parameter("k", clampf(elapsed / duration, 0.0, 1.0))
	if elapsed >= duration:
		# Hidden but kept a moment longer, so a dash just after it lands still counts.
		_fired = true
		visible = false
		var cb := on_done
		on_done = Callable()
		if cb.is_valid():
			cb.call()


## Remove without firing (for example when the caster dies).
func cancel() -> void:
	on_done = Callable()
	queue_free()


static var _shader: Shader


static func _material(size: Vector2, is_line: bool) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("core", _core(1.0))
	m.set_shader_parameter("area", _area(0.3))
	m.set_shader_parameter("size", size)
	m.set_shader_parameter("is_line", 1.0 if is_line else 0.0)
	m.set_shader_parameter("k", 0.0)
	return m


const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 core : source_color = vec4(1.0, 0.2, 0.1, 1.0);
uniform vec4 area : source_color = vec4(1.0, 0.15, 0.1, 0.3);
// A circle: (radius, 0). A strip: (width, length), starting at the caster.
uniform vec2 size = vec2(1.0, 0.0);
uniform float is_line = 0.0;
// How full the warning is: 0 when it appears, 1 when the attack lands.
uniform float k = 0.0;
varying vec2 lp;

void vertex() {
	lp = VERTEX.xz;
}

void over(inout vec4 acc, vec3 c, float a) {
	acc.rgb = c * a + acc.rgb * (1.0 - a);
	acc.a = a + acc.a * (1.0 - a);
}

void fragment() {
	// Metres to the shape's edge (above 0 inside), how far the fill has come and where this
	// point is along the way it fills, and stripes moving the way the attack goes.
	float edge;
	float at;
	float reach;
	float stripe;
	if (is_line > 0.5) {
		float along = size.y * 0.5 - lp.y;
		float across = abs(lp.x);
		edge = min(size.x * 0.5 - across, min(along, size.y - along));
		at = along;
		reach = size.y;
		float ch = fract((along - across * 0.9) / 0.7 - TIME * 2.4);
		stripe = smoothstep(0.0, 0.06, ch) * (1.0 - smoothstep(0.26, 0.34, ch));
	} else {
		float d = length(lp);
		edge = size.x - d;
		at = d;
		reach = size.x;
		float ch = fract(d / 0.55 + TIME * 1.6);
		stripe = smoothstep(0.0, 0.06, ch) * (1.0 - smoothstep(0.22, 0.3, ch));
	}
	float aa = fwidth(edge) + 0.004;
	float inside = smoothstep(-aa, aa, edge);
	float front = k * reach;
	float filled = (1.0 - smoothstep(front - aa, front + aa, at)) * inside;
	// A bright band just behind the fill's edge, so the eye follows it.
	float lead = (1.0 - smoothstep(0.0, 0.22 + 0.1 * reach * 0.1, front - at)) * filled * step(0.02, k);
	// The last moment before it lands: the whole shape flashes.
	float flash = smoothstep(0.82, 1.0, k) * (0.5 + 0.5 * sin(TIME * 40.0));

	vec4 acc = vec4(0.0);
	// A dark outline just outside, so it reads on any floor.
	over(acc, vec3(0.05, 0.0, 0.0), (1.0 - smoothstep(0.0, 0.14, -edge)) * (1.0 - inside) * 0.8);
	over(acc, area.rgb, (0.1 + stripe * 0.14) * inside);
	vec3 hot = mix(core.rgb, vec3(1.0), 0.35);
	over(acc, core.rgb, filled * (0.3 + 0.2 * k + 0.3 * flash));
	over(acc, hot, lead * 0.9);
	// A bright rim just inside the edge, brighter as it fills.
	float rim = (1.0 - smoothstep(0.045, 0.09, edge)) * inside;
	over(acc, mix(core.rgb, hot, flash), rim * (0.85 + 0.15 * k));
	ALBEDO = acc.rgb / max(acc.a, 0.001) * (1.0 + 0.25 * lead + 0.2 * rim);
	ALPHA = acc.a;
}
"""
