class_name Blizzard
extends Node
## The Blizzard (version 243): the Frostfall event's own rule, as the Moon Surge is the Blood
## Moon's. Every EVERY seconds of fighting in the Frostfall Hall a blizzard blows for TIME
## seconds, after WARN seconds of warning (the wind rises and the screen's edges frost over).
## Out in it the hero gets colder (a ring of ice fills round their feet) and slower, and at
## full cold they freeze solid for a moment (a dash breaks the ice). Each room has two
## braziers, and inside a brazier's warm ring the cold melts away fast. Every skeleton killed
## while it blows is worth an extra snowflake, so the brave fight out in it. Krampus calls
## one up himself when he is angry (call_now).

const EVERY := 20.0
const WARN := 2.5
const TIME := 7.0
const WARM_R := 2.3        # the warm ring round a brazier (metres)
const COLD_IN := 4.0       # seconds out in a full blizzard to freeze from warm
const THAW := 0.8          # cold lost a second in a warm ring (0.15 anywhere when it's calm)
const FREEZE := 1.4
const SLOW := 0.35         # the hero is this much slower at full cold
const EMBER := Color(1.0, 0.55, 0.2)
const SNOW := Color(0.82, 0.93, 1.0)

static var instance: Blizzard

var k := 0.0               # how hard it blows, 0..1
var cold := 0.0            # the hero's cold, 0..1
var _t := 0.0
var _on := false
var _call := 0.0           # a blizzard called up now (Krampus): seconds left of warning + blow
var _room: Room
var _ring: MeshInstance3D  # the cold ring round the hero's feet
var _ring_mat: ShaderMaterial
var _snow: CPUParticles3D
var _fog := -1.0
var _fog_col := Color.BLACK
var _sat := 1.0


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS


## True while a blizzard is blowing hard enough to count (kills pay a snowflake more).
static func blowing() -> bool:
	return instance != null and instance.k > 0.5


## Krampus calls the storm down: a blizzard now, after a short warning.
static func call_now() -> void:
	if instance and instance._call <= 0.0:
		instance._call = TIME + 1.5


func _process(delta: float) -> void:
	if Game.state == Game.State.PAUSED:
		return
	var room := Room.current
	var here: bool = Game.state == Game.State.PLAYING and Game.event != "" and Floors.frostfall() \
			and room != null and is_instance_valid(room)
	if Game.state == Game.State.TITLE:
		_t = 0.0   # a new run starts calm
	if room != _room:
		_room = room
		_ring = null
		_snow = null
		_call = 0.0
		cold = 0.0
		if _fog >= 0.0 and Game._env:
			Game._env.fog_density = _fog
			Game._env.adjustment_saturation = _sat
		_fog = -1.0
	var want := false
	var warn := false
	if here and _call > 0.0:
		_call -= delta
		want = _call < TIME
		warn = not want
	elif here and Game.alive_enemies > 0 and not Game._in_boss_room():
		_t += delta
		var t := fmod(_t, EVERY + TIME)
		want = t >= EVERY
		warn = t >= EVERY - WARN and not want
	if want and not _on:
		_on = true
		Game.hud.callout("BLIZZARD! GET TO A FIRE!", SNOW, true)
		Sfx.play("gust", 0.9)
		Game.shake(0.25)
		Game.buzz(40)
	elif not want:
		_on = false
	k = move_toward(k, 1.0 if want else 0.0, delta * (1.6 if want else 0.7))
	if not here:
		k = 0.0 if Game.state != Game.State.PLAYING else k
		cold = move_toward(cold, 0.0, delta)
	_update_hero(delta, here)
	_show(delta, here, warn)


## The hero's cold: up out in the blizzard, down by a fire (fast) or when it's calm (slowly).
func _update_hero(delta: float, here: bool) -> void:
	var hero: Hero = Game.hero
	if hero == null or not is_instance_valid(hero):
		return
	if here and not hero.dead:
		if warm(hero.global_position):
			cold = move_toward(cold, 0.0, THAW * delta)
		elif k > 0.3:
			cold = minf(1.0, cold + delta / COLD_IN * k)
		else:
			cold = move_toward(cold, 0.0, 0.15 * delta)
		if cold >= 1.0 and hero.can_be_snared():
			hero.freeze(FREEZE)
			cold = 0.55
	hero.cold = cold if here else 0.0


## True inside the warm ring of one of the room's braziers.
func warm(p: Vector3) -> bool:
	if _room == null or not is_instance_valid(_room):
		return false
	for b in _room.get_meta("braziers", []):
		var d: Vector3 = p - (b as Node3D).global_position
		d.y = 0.0
		if d.length() < WARM_R:
			return true
	return false


## The nearest brazier's spot (the robot walks to it), or Vector3.INF with none.
func nearest_fire(p: Vector3) -> Vector3:
	var best := Vector3.INF
	if _room == null or not is_instance_valid(_room):
		return best
	for b in _room.get_meta("braziers", []):
		var q: Vector3 = (b as Node3D).global_position
		if best == Vector3.INF or p.distance_to(q) < p.distance_to(best):
			best = q
	return best


## Everything you see and hear of it: the frosted screen edges, the blowing snow, the fog,
## the wind, the braziers' rings, and the ring of ice round the hero.
func _show(delta: float, here: bool, warn: bool) -> void:
	var hud = Game.hud
	if hud and hud.frost_edge:
		var a := k * 0.55 + cold * 0.45
		if warn:
			a = maxf(a, 0.3 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 12.0)))
		hud.frost_edge.modulate.a = move_toward(hud.frost_edge.modulate.a, a, delta * 3.0)
	Ambience.gust = k
	var env: Environment = Game._env
	# A white-out: thicker, paler fog and the colour drained from the room (the fires stay warm).
	if env and here:
		if _fog < 0.0:
			_fog = env.fog_density
			_fog_col = env.fog_light_color
			_sat = env.adjustment_saturation
		env.fog_density = _fog + 0.03 * k
		env.fog_light_color = _fog_col.lerp(Color(0.3, 0.38, 0.52), k * 0.75)
		env.adjustment_saturation = _sat * (1.0 - 0.3 * k)
	elif env and _fog >= 0.0:
		env.fog_density = _fog
		env.fog_light_color = _fog_col
		env.adjustment_saturation = _sat
		_fog = -1.0
	if not here:
		if _ring:
			_ring.visible = false
		return
	if _snow == null:
		_make_snow()
	_snow.emitting = k > 0.15
	for b in _room.get_meta("braziers", []):
		var m: ShaderMaterial = (b as Node3D).get_meta("ring")
		m.set_shader_parameter("k", k)
	_update_ring()


func _update_ring() -> void:
	var hero: Hero = Game.hero
	if hero == null or not is_instance_valid(hero) or hero.dead:
		if _ring:
			_ring.visible = false
		return
	if _ring == null or not is_instance_valid(_ring):
		if _ring_mat == null:
			_ring_mat = ShaderMaterial.new()
			_ring_mat.shader = _cold_shader()
		var q := QuadMesh.new()
		q.size = Vector2(2.4, 2.4)
		q.orientation = PlaneMesh.FACE_Y
		_ring = MeshInstance3D.new()
		_ring.mesh = q
		_ring.material_override = _ring_mat
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_room.add_child(_ring)
	_ring.visible = cold > 0.01
	_ring.global_position = Vector3(hero.global_position.x, 0.07, hero.global_position.z)
	_ring_mat.set_shader_parameter("fill", cold)
	_ring_mat.set_shader_parameter("hot", 1.0 if warm(hero.global_position) else 0.0)


## Snow blown sideways across the room while it blows.
func _make_snow() -> void:
	_snow = CPUParticles3D.new()
	_snow.amount = [90, 150, 220, 300][clampi(Game.graphics_level, 0, 3)]
	_snow.lifetime = 1.1
	_snow.emitting = false
	_snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_snow.emission_box_extents = Vector3(Room.HALF_W + 2.0, 1.5, Room.HALF_L)
	_snow.position = Vector3(-4.0, 3.2, 0.0)
	_snow.direction = Vector3(1.0, -0.35, 0.15)
	_snow.spread = 8.0
	_snow.initial_velocity_min = 9.0
	_snow.initial_velocity_max = 14.0
	_snow.gravity = Vector3(0, -2.0, 0)
	_snow.scale_amount_min = 0.5
	_snow.scale_amount_max = 1.4
	var q := QuadMesh.new()
	q.size = Vector2(0.2, 0.2)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.92, 0.97, 1.0, 0.9)
	m.albedo_texture = U.soft_circle()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	_snow.mesh = q
	_room.add_child(_snow)


## The warm-up (warmup.gd): a brazier with its warm ring, the cold ring, the ice and a flake.
static func warm_up(holder: Node3D, at: Vector3) -> void:
	var n := Node3D.new()
	holder.add_child(n)
	n.position = at
	var m := MeshInstance3D.new()
	m.mesh = _mesh()
	n.add_child(m)
	if _warm_shader == null:
		_warm_shader = Shader.new()
		_warm_shader.code = WARM_CODE
	for r: Array in [[_warm_shader, 3.0], [_cold_shader(), 2.0]]:
		var mat := ShaderMaterial.new()
		mat.shader = r[0]
		var q := QuadMesh.new()
		q.size = Vector2(r[1], r[1])
		q.orientation = PlaneMesh.FACE_Y
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = mat
		mi.position = Vector3(0, 0.05, 0)
		n.add_child(mi)


## Two braziers in each room of the Frostfall Hall in an event, one on each side, one further
## up the hall than the other, clear of pillars, crates, spikes and where skeletons come in.
static func dress(room: Room) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(room.name) + str(Game.floor_num))
	var spikes: Array = []
	for c in room.get_children():
		if c is SpikeTrap:
			spikes.append((c as Node3D).position)
	var up := rng.randf() < 0.5
	var placed: Array = []
	for side in [-1.0, 1.0]:
		var far: bool = (side < 0.0) == up
		var tries: Array = []
		var start := rng.randi_range(0, 4)
		for band in ([true, false] if far else [false, true]):   # its own half of the hall first
			for x in [4.3, 3.9, 3.4, 2.8]:
				for i in 13:
					var z: float = (-7.0 + (i + start) % 13 * 0.5) if band else (-2.0 + (i + start) % 13 * 0.45)
					tries.append(Vector3(side * x, 0, z))
		for j in tries.size():
			var p: Vector3 = tries[j]
			if not room.is_walkable(p, 1.2):
				continue
			var ok := true
			for q in spikes + placed:
				if (q as Vector3).distance_to(p) < 2.2:
					ok = false
			for sp in room.spawns:
				if (sp.pos as Vector3).distance_to(p) < 1.3:
					ok = false
			if ok:
				_add_brazier(room, p)
				placed.append(p)
				break


static var _bowl: ArrayMesh
static var _warm_shader: Shader
static var _cold: Shader


static func _cold_shader() -> Shader:
	if _cold == null:
		_cold = Shader.new()
		_cold.code = RING_CODE
	return _cold


static func _add_brazier(room: Room, p: Vector3) -> void:
	var n := Node3D.new()
	n.position = p
	room.add_child(n)
	room.obstacles.append({"pos": p, "r": 0.45})
	var m := MeshInstance3D.new()
	m.mesh = _mesh()
	m.rotation.y = randf() * TAU
	n.add_child(m)
	Fx.flame(n, Vector2(0.9, 1.3), Vector3(0, 0.95, 0))
	Fx.flame(n, Vector2(0.55, 0.85), Vector3(0.16, 0.95, 0.1))
	Fx.flame(n, Vector2(0.5, 0.75), Vector3(-0.15, 0.95, -0.08))
	if Game.graphics_level >= 1:
		var light := Flicker.new()
		light.light_color = Color(1.0, 0.55, 0.25)
		light.omni_range = 4.5
		light.light_energy = 1.5
		light.position = Vector3(0, 1.4, 0)
		n.add_child(light)
	# The warm ring on the floor: where the cold can't reach.
	if _warm_shader == null:
		_warm_shader = Shader.new()
		_warm_shader.code = WARM_CODE
	var mat := ShaderMaterial.new()
	mat.shader = _warm_shader
	var q := QuadMesh.new()
	q.size = Vector2(WARM_R * 2.0, WARM_R * 2.0)
	q.orientation = PlaneMesh.FACE_Y
	var ring := MeshInstance3D.new()
	ring.mesh = q
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(0, 0.05, 0)
	n.add_child(ring)
	n.set_meta("ring", mat)
	var list: Array = room.get_meta("braziers", [])
	list.append(n)
	room.set_meta("braziers", list)


## An iron fire bowl on three legs over a stone ring, full of glowing coals.
static func _mesh() -> ArrayMesh:
	if _bowl:
		return _bowl
	var iron := U.mat(Color(0.16, 0.15, 0.15), 0.55, 0.0)
	var stone := U.mat(Color(0.42, 0.42, 0.46), 0.9)
	var coal := U.mat(Color(1.0, 0.42, 0.1), 0.6, 3.0)
	var snow := U.mat(Color(0.9, 0.94, 1.0), 0.8)
	var parts := []
	parts.append([Props._cone(0.44, 0.5, 0.12, 10), Props._xf(Vector3(0, 0.06, 0), Vector3.ONE), stone])
	parts.append([Props._cone(0.36, 0.42, 0.03, 10), Props._xf(Vector3(0, 0.135, 0), Vector3.ONE), snow])
	for i in 3:
		var a := TAU * i / 3.0
		var leg := Basis(Vector3(cos(a + PI / 2.0), 0, sin(a + PI / 2.0)), -0.25)
		parts.append([Props._cone(0.05, 0.06, 0.8, 6), Props._xf(Vector3(cos(a) * 0.32, 0.5, sin(a) * 0.32), Vector3.ONE, leg), iron])
	parts.append([Props._cone(0.6, 0.26, 0.36, 12), Props._xf(Vector3(0, 0.86, 0), Vector3.ONE), iron])
	parts.append([Props._cone(0.63, 0.63, 0.07, 12), Props._xf(Vector3(0, 1.05, 0), Vector3.ONE), iron])
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		parts.append([Props._cube(), Props._xf(Vector3(cos(a) * 0.62, 1.1, sin(a) * 0.62), Vector3(0.09, 0.14, 0.09), Basis(Vector3.UP, -a)), iron])
	parts.append([Props._sphere(), Props._xf(Vector3(0, 1.03, 0), Vector3(0.55, 0.14, 0.55)), coal])
	_bowl = Props._bake(parts)
	return _bowl


const WARM_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float k = 0.0;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float glow = (1.0 - smoothstep(0.0, 1.0, d)) * 0.16;
	float edge = 1.0 - smoothstep(0.0, 0.035, abs(d - 0.955));
	float a = atan(UV.y - 0.5, UV.x - 0.5);
	float dash = step(0.0, sin(a * 18.0 + TIME * 1.5));
	vec3 warm = vec3(1.0, 0.5, 0.16);
	ALBEDO = warm * (glow * (0.6 + 0.8 * k) + edge * dash * (0.18 + 0.55 * k));
	ALPHA = 1.0;
}
"""

## The ring of ice round the hero's feet: it fills round as the cold rises, and glows warm
## while they stand by a fire.
const RING_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float fill = 0.0;
uniform float hot = 0.0;
void fragment() {
	vec2 p = UV - 0.5;
	float d = length(p) * 2.0;
	float band = smoothstep(0.74, 0.78, d) * (1.0 - smoothstep(0.92, 0.96, d));
	float a = (atan(p.x, -p.y) + 3.14159265) / 6.2831853;
	float on = step(a, fill);
	vec3 ice = vec3(0.55, 0.85, 1.0);
	float pulse = fill > 0.75 ? 0.75 + 0.25 * sin(TIME * 14.0) : 1.0;
	vec3 c = mix(ice * 0.9 * pulse, vec3(1.0, 0.55, 0.2) * 0.7, hot);
	ALBEDO = band * (c * on + vec3(0.12, 0.18, 0.25) * (1.0 - on));
	ALPHA = 1.0;
}
"""
