class_name LegendWings
extends Node3D
## Version 313 (Legend Vault, legends.gd): wings on the hero's back, held half folded and
## swept back, that spread wide and beat once when the hero dashes.
##   bone_wings:  Bone Wings. A bat's wing made of thick knuckled bones (arm, elbow, wrist,
##                four long fingers with hooked claws, a thumb claw, spurs along the arm)
##                with torn dusk skin between them, indigo at the bones to a glowing ember
##                edge (version 324). They stretch now and then, and a dash beats them with
##                a gust of dusk motes.
##   phoenix:     Phoenix Wings. Layers of long burning feathers, gold at the root and red at
##                the tips, their edges flickering like flames (version 317), shedding embers;
##                every few seconds a wave of white fire runs out along the feathers. A dash
##                leaves a firebird behind where it started (version 327: a bird of fire with
##                the phoenix's own wings, a crest and tail streamers) that beats its wings
##                once as it rises and burns away.
## The wing's flat side leans back towards the run camera (above and behind the hero), so from
## up there it is seen spread, not edge on. On a pedestal they are shown spread and beating.

var kind := "bone_wings"

var _hero: Node3D   # (a Hero in a run; nothing on a pedestal)
var _l: Node3D
var _r: Node3D
var _t := 0.0
var _spread := 0.0   # 0 at rest (half folded, swept back), 1 spread wide
var _beat := 0.0
var _was_dashing := false
var _embers: CPUParticles3D
var _stretch := false

## The wing's shape, in its own flat plane (x out from the back, y up): the shoulder, the
## elbow, the wrist and the four finger tips; the skin runs from the shoulder round the
## fingers and back down to the hip.
const ELBOW := Vector2(0.42, 0.2)
const WRIST := Vector2(0.84, 0.36)
const FINGERS := [Vector2(1.42, 0.18), Vector2(1.32, -0.2), Vector2(1.06, -0.5), Vector2(0.64, -0.62)]
const HIP := Vector2(0.14, -0.42)


## Puts wings of `kind` on the hero inside CharacterVisual `visual`: on its upper back. (On the
## chest bone they hung from the waist and pointed at the floor: the KayKit chest bone is low
## and turned. The chunky heroes barely bend, so the wings sit on the visual itself.)
static func make(visual: Node3D, _model: Node3D, wing_kind: String) -> void:
	var w := LegendWings.new()
	w.kind = wing_kind
	w.name = "LegendWings"
	visual.add_child(w)
	w.position = Vector3(0, 1.22, 0.26)
	w.rotation.y = PI   # (the wings are made with the back towards their -Z)


func _ready() -> void:
	var p := get_parent()
	while p and not (p is CharacterVisual):
		p = p.get_parent()
	if p and p.get_parent() is Hero:
		_hero = p.get_parent() as Node3D
		scale = Vector3.ONE * 1.45   # (the run camera is far above: bigger there, as the pets)
	match kind:
		"phoenix":
			_l = _phoenix_wing(-1.0)
			_r = _phoenix_wing(1.0)
			_embers = _ember_fx()
			add_child(_embers)
		_:
			_l = _bone_wing(-1.0)
			_r = _bone_wing(1.0)
	_pose(0.0)


func _process(delta: float) -> void:
	_t += delta
	var dashing := _hero != null and is_instance_valid(_hero) and (_hero as Hero).is_dashing()
	if dashing and not _was_dashing:
		_beat = 1.0
		if kind == "phoenix" and _hero:
			_firebird()
		elif _hero:
			# Version 324: a beat of the bone wings throws a gust of dusk motes.
			Fx._burst(_hero.global_position + Vector3(0, 1.3, 0), 14, Color(0.85, 0.4, 0.55), 0.5, 4.0, 0.55, 0.0, true, "soft")
	_was_dashing = dashing
	var want := 1.0 if (dashing or _beat > 0.0 or _hero == null) else 0.0
	_stretch = kind == "bone_wings" and _hero != null and want == 0.0 and fmod(_t, 8.0) > 6.7
	if _stretch:
		want = 0.6   # (a stretch now and then, with a shake)
	_spread = move_toward(_spread, want, delta * (7.0 if want > _spread else 1.6))
	_beat = maxf(0.0, _beat - delta * 1.6)
	_pose(delta)


## The wings' pose: swept back and drooping at rest, breathing slowly; spread straight out to
## the sides and beating once in a dash.
func _pose(_delta: float) -> void:
	var s := smoothstep(0.0, 1.0, _spread)
	var breathe := sin(_t * 1.8) * 0.06
	var flap := sin((1.0 - _beat) * PI * 2.0) * 0.45 * _beat
	for side in [-1.0, 1.0]:
		var w: Node3D = _l if side < 0.0 else _r
		# y: swept back; z: raised; x: the flat side leaning back to face up and behind.
		if _hero == null:
			flap = sin(_t * 2.2) * 0.22   # (on a pedestal: slow, wide beats)
		elif _stretch:
			flap = sin(_t * 17.0) * 0.07
		# (In a run the wings lean further back, so the camera above sees them spread, not
		# edge on: version 324 for the bone wings, 327 for the phoenix.)
		var lean := -1.05 if _hero != null else -0.7
		var lean_spread := -0.95 if _hero != null else -0.4
		w.rotation = Vector3(lerpf(lean, lean_spread, s), side * lerpf(0.55, 0.12, s), side * (lerpf(0.28, 0.22, s) + breathe + flap))


# ---------------------------------------------------------------- Bone Wings

## Version 324: the wing was thin sticks over a flat purple sheet. Now the bones are thick and
## knuckled (baked shapes, LegendPet._loft), hooked dark claws on every finger, a thumb claw
## and a row of spurs along the arm; the skin between them runs from deep indigo at the bones
## to a glowing dusk orange at its scalloped, torn edge, with amber veins along the fingers
## and slow pulses of light running out to the edge.
const WING_BONE := Color(0.94, 0.9, 0.8)
const WING_KNOB := Color(0.76, 0.69, 0.58)
const WING_CLAW := Color(0.14, 0.08, 0.12)
static var _wing_meshes := {}
static var _dusk_mat: ShaderMaterial
static var _wing_bone_mat: ShaderMaterial


func _bone_wing(side: float) -> Node3D:
	var w := Node3D.new()
	w.position = Vector3(0.1 * side, 0, 0)
	add_child(w)
	var key := int(side)
	if not _wing_meshes.has(key):
		_wing_meshes[key] = [_bone_wing_bones(side), _bone_wing_skin(side)]
	var skin := MeshInstance3D.new()
	skin.mesh = _wing_meshes[key][1]
	skin.material_override = _dusk_skin()
	skin.position.z = -0.012
	w.add_child(skin)
	var bones := MeshInstance3D.new()
	bones.mesh = _wing_meshes[key][0]
	bones.material_override = _wing_bone()
	w.add_child(bones)
	return w


static func _bone_wing_bones(side: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v := func(p: Vector2) -> Vector3: return Vector3(p.x * side, p.y, 0.0)
	# The arm and forearm, thick, a little bowed; round knuckles at the elbow and wrist.
	LegendPet._spike(st, v.call(Vector2.ZERO), v.call(ELBOW), Vector3(0, 0.03, 0), 0.06, WING_BONE, WING_BONE, 5)
	LegendPet._spike(st, v.call(ELBOW), v.call(WRIST), Vector3(0, 0.025, 0), 0.05, WING_BONE, WING_BONE, 5)
	LegendPet._ball(st, v.call(Vector2.ZERO), Vector3.ONE * 0.075, WING_KNOB)
	LegendPet._ball(st, v.call(ELBOW), Vector3.ONE * 0.07, WING_KNOB)
	LegendPet._ball(st, v.call(WRIST), Vector3.ONE * 0.08, WING_KNOB)
	# Spurs along the top of the arm.
	for i in 4:
		var k := 0.2 + i * 0.2
		var at: Vector2 = Vector2.ZERO.lerp(ELBOW, k * 2.0) if k < 0.5 else ELBOW.lerp(WRIST, (k - 0.5) * 2.0)
		LegendPet._spike(st, v.call(at + Vector2(0, 0.03)), v.call(at + Vector2(-0.05, 0.13 - i * 0.015)), Vector3.ZERO, 0.022, WING_BONE, WING_KNOB, 3)
	# Four long fingers, each with a knuckle half way and a hooked dark claw at its tip.
	for tip: Vector2 in FINGERS:
		var d := (tip - WRIST).normalized()
		var bend := Vector2(-d.y, d.x) * 0.04
		var mid := WRIST.lerp(tip, 0.5) + bend
		LegendPet._spike(st, v.call(WRIST), v.call(mid), Vector3.ZERO, 0.034, WING_BONE, WING_BONE, 3)
		LegendPet._spike(st, v.call(mid), v.call(tip), Vector3.ZERO, 0.028, WING_BONE, WING_KNOB, 4)
		LegendPet._ball(st, v.call(mid), Vector3.ONE * 0.034, WING_KNOB, 6)
		LegendPet._spike(st, v.call(tip - d * 0.02), v.call(tip + d * 0.13), Vector3(-d.y * side, d.x, 0.0) * -0.05, 0.03, WING_CLAW, WING_CLAW, 4)
	# The hooked thumb claw at the wrist.
	LegendPet._spike(st, v.call(WRIST + Vector2(0.0, 0.04)), v.call(WRIST + Vector2(0.06, 0.22)), v.call(Vector2(-0.05, 0.0)), 0.04, WING_KNOB, WING_CLAW, 5)
	return st.commit()


## The skin: a panel between each two fingers and one from the last finger back to the hip,
## each scalloped in along its edge. UV.x counts the panels (whole numbers on the fingers),
## UV.y runs 0 at the bones to 1 at the torn edge.
static func _bone_wing_skin(side: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var f: Array = FINGERS
	var panels := [[WRIST, f[0], WRIST, f[1]], [WRIST, f[1], WRIST, f[2]], [WRIST, f[2], WRIST, f[3]], [WRIST, f[3], Vector2.ZERO, HIP]]
	var nu := 6
	var nv := 7
	for k in panels.size():
		var pn: Array = panels[k]
		var grid := []
		for iu in nu + 1:
			var u := float(iu) / nu
			var col := []
			for iv in nv + 1:
				var t := float(iv) / nv
				var a: Vector2 = (pn[0] as Vector2).lerp(pn[1], t)
				var b: Vector2 = (pn[2] as Vector2).lerp(pn[3], t)
				var p := a.lerp(b, u)
				var root: Vector2 = (pn[0] as Vector2).lerp(pn[2], u)
				p = p.lerp(root, 0.26 * sin(PI * u) * t * t)
				col.append([Vector3(p.x * side, p.y, 0.0), Vector2(k + u, t)])
			grid.append(col)
		for iu in nu:
			for iv in nv:
				for c in [grid[iu][iv], grid[iu][iv + 1], grid[iu + 1][iv + 1], grid[iu][iv], grid[iu + 1][iv + 1], grid[iu + 1][iv]]:
					st.set_uv(c[1])
					st.set_normal(Vector3(0, 0, 1))
					st.add_vertex(c[0])
	return st.commit()


## Dusk skin: deep indigo at the bones to violet to a glowing ember orange at the torn edge;
## amber veins along the fingers; slow pulses of light running out to the edge.
static func _dusk_skin() -> ShaderMaterial:
	if _dusk_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode cull_disabled;
void fragment() {
	float k = UV.x;
	float v = UV.y;
	float cell = floor(k * 3.0);
	float h = fract(sin(cell * 71.3 + 1.7) * 4375.85);
	if (v > 0.78 + 0.2 * h && abs(fract(k * 3.0) - 0.5) < 0.16 + 0.12 * h) {
		discard;
	}
	float hole = length(vec2(fract(k * 2.0 + 0.3) - 0.5, (v - 0.55 - 0.1 * h) * 2.2));
	if (hole < 0.07 * h && h > 0.5) {
		discard;
	}
	vec3 deep = vec3(0.2, 0.07, 0.38);
	vec3 mid = vec3(0.6, 0.16, 0.62);
	vec3 edge = vec3(1.0, 0.45, 0.22);
	vec3 c = mix(deep, mid, smoothstep(0.1, 0.6, v));
	c = mix(c, edge, smoothstep(0.62, 0.98, v));
	float f = fract(k);
	float vein = 1.0 - smoothstep(0.0, 0.06, min(f, 1.0 - f));
	float pulse = pow(max(0.0, sin(v * 7.0 - TIME * 2.2 + floor(k) * 1.3)), 8.0) * smoothstep(0.15, 0.5, v);
	ALBEDO = c;
	ROUGHNESS = 0.75;
	EMISSION = c * (0.45 + 0.9 * smoothstep(0.6, 1.0, v)) + vec3(1.0, 0.62, 0.3) * (vein * 0.55 + pulse * 0.35);
}
"""
		_dusk_mat = ShaderMaterial.new()
		_dusk_mat.shader = sh
	return _dusk_mat


## The wing bones: their colour from the mesh, a warm dusk rim round their edges.
static func _wing_bone() -> ShaderMaterial:
	if _wing_bone_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float lit = step(0.3, COLOR.r);
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.6;
	EMISSION = vec3(1.0, 0.5, 0.35) * fres * 0.55 * lit + COLOR.rgb * 0.05;
}
"""
		_wing_bone_mat = ShaderMaterial.new()
		_wing_bone_mat.shader = sh
	return _wing_bone_mat


static func _v(p: Vector2, side: float) -> Vector3:
	return Vector3(p.x * side, p.y, 0)


## A round bone from `a` to `b` in the wing's plane.
static func _bone(w: Node3D, a: Vector2, b: Vector2, r: float, m: Material, side: float) -> void:
	var from := _v(a, side)
	var to := _v(b, side)
	var len := from.distance_to(to)
	var t := LegendPet._tube(w, r, r * 0.8, len, m, (from + to) * 0.5)
	var d := (to - from).normalized()
	t.rotation.z = atan2(-d.x, d.y)


## A flat fan of triangles from the first point round the others, drawn on both sides.
static var _fans := {}


static func _fan(pts: Array[Vector2], side: float, key: String) -> Mesh:
	var k := "%s%d" % [key, int(side)]
	if _fans.has(k):
		return _fans[k]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector3.ZERO
	for p: Vector2 in pts:
		c += _v(p, side)
	c /= pts.size()
	for i in pts.size():
		var a := _v(pts[i], side)
		var b := _v(pts[(i + 1) % pts.size()], side)
		for tri in [[c, a, b], [c, b, a]]:
			for v: Vector3 in tri:
				st.set_normal(Vector3(0, 0, 1))
				st.set_uv(Vector2(v.x * side / 1.5, -v.y))
				st.add_vertex(v)
	var mesh := st.commit()
	_fans[k] = mesh
	return mesh


# ---------------------------------------------------------------- Phoenix Wings

## Version 317: the feathers are real feather shapes (they were flat boxes, which read as a
## fan of cards): each one tapers from its root to a pointed tip that curls up like a flame,
## gold at the root, orange, then red at the tip, with a hot white-gold line down its middle.
## Long flight feathers fan out from the arm, two rows of shorter coverts lie over their roots
## (on both faces: the pedestal sees the front, the run camera the back) with little gold down
## over those, and tongues of flame lick up from the top of the arm. The tips flutter and their
## edges are cut into flickering tongues of fire (PHX_SHADER).
func _phoenix_wing(side: float) -> Node3D:
	var w := Node3D.new()
	w.position = Vector3(0.1 * side, 0, 0)
	add_child(w)
	var feathers := MeshInstance3D.new()
	# (in a run the camera far above often sees the wing at a slant, where the gaps between
	# tapering feathers show: there the feathers are broader, and the glow brighter)
	feathers.mesh = _phoenix_mesh(side, 1.4 if _hero else 1.0)
	feathers.material_override = _phoenix_mat()
	feathers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(feathers)
	var gold := LegendPet._mat("phx_gold", Color(1.0, 0.82, 0.35), 0.4, Color(1.0, 0.7, 0.2), 2.2)
	_bone(w, Vector2.ZERO, ELBOW, 0.05, gold, side)
	_bone(w, ELBOW, WRIST, 0.045, gold, side)
	_bone(w, WRIST, PHX_TIP, 0.035, gold, side)
	# A soft fire-glow over the whole wing in a run (version 327: a flattened ball of added
	# light; the billboard quad it was did not show there). On a pedestal, close up, it only
	# blurred the feathers.
	if _hero == null:
		return w
	var glow := MeshInstance3D.new()
	glow.mesh = LegendPet._glow_ball()
	glow.material_override = LegendPet._wisp_glow()
	glow.position = _v(Vector2(0.7, -0.05), side)
	glow.scale = Vector3(0.85, 0.75, 0.3)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(glow)
	return w


const PHX_TIP := Vector2(1.06, 0.42)

const PHX_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
varying float vt;
varying float vx;
void vertex() {
	vt = UV.y;
	vx = UV.x;
	float ph = COLOR.a * 6.2832;
	float k = vt * vt;
	VERTEX.z += sin(TIME * 6.0 + vt * 5.0 + ph) * 0.05 * k;
	VERTEX.x += sin(TIME * 4.3 + ph * 1.7 + vt * 3.0) * 0.025 * k;
}
void fragment() {
	float ph = COLOR.a * 6.2832;
	float tongues = 0.5 + 0.5 * sin(vt * 22.0 - TIME * 8.0 + ph * 2.0);
	float cut = 1.0 - smoothstep(0.5, 1.0, vt) * (0.2 + 0.45 * tongues);
	if (abs(vx) > cut) {
		discard;
	}
	float flick = 0.9 + 0.1 * sin(TIME * 11.0 + vt * 9.0 + ph * 3.0);
	float core = (1.0 - smoothstep(0.0, 0.32, abs(vx))) * (1.0 - smoothstep(0.15, 0.95, vt));
	vec3 c = mix(COLOR.rgb, vec3(1.0, 0.95, 0.72), core * 0.8);
	// (version 327) every few seconds a wave of white fire runs out from the shoulder to the
	// feather tips, a little later on each feather.
	float run = fract(TIME * 0.2 + ph * 0.03);
	float wave = (1.0 - smoothstep(0.0, 0.14, abs(vt - (run * 1.8 - 0.3)))) * step(run, 0.75);
	c = mix(c, vec3(1.0, 0.96, 0.72), wave * 0.6);
	ALBEDO = c * flick;
}
"""

static var _phx_mat: ShaderMaterial
static var _phx_meshes := {}


static func _phoenix_mat() -> ShaderMaterial:
	if _phx_mat == null:
		var sh := Shader.new()
		sh.code = PHX_SHADER
		_phx_mat = ShaderMaterial.new()
		_phx_mat.shader = sh
	return _phx_mat


## The point `s` (0 to 1) of the way along the wing's arm, shoulder to tip.
static func _arm(s: float) -> Vector2:
	var pts: Array[Vector2] = [Vector2.ZERO, ELBOW, WRIST, PHX_TIP]
	var total := 0.0
	for i in 3:
		total += pts[i].distance_to(pts[i + 1])
	var want := s * total
	for i in 3:
		var l := pts[i].distance_to(pts[i + 1])
		if want <= l or i == 2:
			return pts[i].lerp(pts[i + 1], clampf(want / l, 0.0, 1.0))
		want -= l
	return PHX_TIP


static func _phoenix_mesh(side: float, wide: float) -> Mesh:
	var key := "%d/%.2f" % [int(side), wide]
	if _phx_meshes.has(key):
		return _phx_meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var gold := Color(1.0, 0.8, 0.3)
	var red := Color(0.92, 0.14, 0.04)
	# The long flight feathers, from hanging down at the shoulder to reaching out past the tip.
	for i in 14:
		var f := float(i) / 13.0
		_feather(st, _arm(0.06 + 0.92 * f), lerpf(-1.62, 0.45, pow(f, 1.1)), lerpf(0.62, 1.3, pow(f, 1.2)), 0.1 * wide, 0.12, 0.0, gold, red, fposmod(i * 0.618, 1.0), side)
	# Shorter coverts over their roots, on both faces of the wing.
	for z in [0.025, -0.025]:
		for i in 10:
			var f := float(i) / 9.0
			_feather(st, _arm(0.03 + 0.86 * f), lerpf(-1.5, 0.25, f), lerpf(0.32, 0.52, f), 0.1 * wide, 0.08, z, Color(1.0, 0.9, 0.5), Color(1.0, 0.5, 0.1), fposmod(i * 0.37 + 0.2, 1.0), side)
		# Little gold down over the coverts' roots.
		for i in 8:
			var f := float(i) / 7.0
			var dz: float = z * 1.8
			_feather(st, _arm(0.02 + 0.86 * f) + Vector2(0, 0.02), lerpf(-1.3, 0.1, f), 0.21, 0.075 * wide, 0.05, dz, Color(1.0, 0.96, 0.72), Color(1.0, 0.72, 0.28), fposmod(i * 0.29 + 0.5, 1.0), side)
	# Tongues of flame licking up from the top of the arm.
	for i in 5:
		var f := float(i) / 4.0
		_feather(st, _arm(0.12 + 0.8 * f), lerpf(1.85, 1.05, f), lerpf(0.24, 0.34, f), 0.06 * wide, -0.25, 0.0, Color(1.0, 0.75, 0.25), Color(0.95, 0.2, 0.05), fposmod(i * 0.53 + 0.1, 1.0), side)
	var mesh := st.commit()
	_phx_meshes[key] = mesh
	return mesh


## One feather in the wing's plane (made for the right wing: x out from the back, y up, then
## mirrored for `side`): from `root` along the angle `ang`, `length` long and about twice
## `half_w` wide, its tip curling up by `curl`; `c0` at the root to `c1` at the tip, `ph` the
## phase of its flicker (in the vertex colour's alpha); `z` lifts its layer off the others.
static func _feather(st: SurfaceTool, root: Vector2, ang: float, length: float, half_w: float, curl: float, z: float, c0: Color, c1: Color, ph: float, side: float) -> void:
	var d := Vector2(cos(ang), sin(ang))
	var n := Vector2(-d.y, d.x)
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_t := 0.0
	for i in 9:
		var t := float(i) / 8.0
		var c := root + d * (t * length) + n * (curl * t * t * length)
		var hw := half_w * (0.3 * (1.0 - t) + 0.9 * sin(PI * pow(t, 0.7)))
		var l := _v(c - n * hw, side) + Vector3(0, 0, z)
		var r := _v(c + n * hw, side) + Vector3(0, 0, z)
		if i > 0:
			var col0 := c0.lerp(c1, prev_t)
			col0.a = ph
			var col1 := c0.lerp(c1, t)
			col1.a = ph
			_fv(st, prev_l, Vector2(-1, prev_t), col0)
			_fv(st, prev_r, Vector2(1, prev_t), col0)
			_fv(st, r, Vector2(1, t), col1)
			_fv(st, prev_l, Vector2(-1, prev_t), col0)
			_fv(st, r, Vector2(1, t), col1)
			_fv(st, l, Vector2(-1, t), col1)
		prev_l = l
		prev_r = r
		prev_t = t


static func _fv(st: SurfaceTool, v: Vector3, uv: Vector2, col: Color) -> void:
	st.set_color(col)
	st.set_uv(uv)
	st.set_normal(Vector3(0, 0, 1))
	st.add_vertex(v)


func _ember_fx() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 26
	p.lifetime = 1.1
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(1.0, 0.3, 0.1)
	p.position = Vector3(0, -0.1, -0.05)
	p.direction = Vector3(0, 1, 0)
	p.spread = 25.0
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.scale_amount_min = 0.07
	p.scale_amount_max = 0.14
	p.mesh = Fx._shaped("glow")   # (version 327: a particle billboard; the quad it was did not show in a run)
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.85, 0.4, 1))
	g.set_color(1, Color(1, 0.2, 0.05, 0))
	p.color_ramp = g
	return p


## A dash leaves a firebird where it started (version 327: it was a few flat orange cards): a
## bird of white-gold fire with the phoenix's own feathered wings, a crested head and three
## long tail streamers, laid facing the camera above. It beats its wings once as it rises,
## grows and burns away over most of a second, throwing out a burst of embers.
static var _bird_body: Mesh
static var _bird_shader: Shader


func _firebird() -> void:
	var world := _hero.get_parent() as Node3D
	if world == null:
		return
	var bird := Node3D.new()
	world.add_child(bird)
	bird.global_position = _hero.global_position + Vector3(0, 1.3, 0)
	bird.rotation = Vector3(-1.0, 0, 0)   # (its wings face the camera above, its head up the screen)
	bird.scale = Vector3.ONE * 0.8
	if _bird_shader == null:
		_bird_shader = Shader.new()
		_bird_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float fade = 1.0;
void fragment() {
	float fl = 0.85 + 0.15 * sin(TIME * 17.0 + UV.y * 9.0);
	vec3 c = mix(COLOR.rgb, vec3(1.0, 0.9, 0.6), 0.1) * fade * fl;
	float glow_a = max(max(c.r, c.g), c.b);
	ALBEDO = c / max(glow_a, 0.001);
	ALPHA = clamp(glow_a, 0.0, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = _bird_shader
	if _bird_body == null:
		_bird_body = _firebird_body()
	var body := MeshInstance3D.new()
	body.mesh = _bird_body
	body.material_override = mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bird.add_child(body)
	var tw := bird.create_tween().set_parallel(true)
	for side in [-1.0, 1.0]:
		var w := MeshInstance3D.new()
		w.mesh = _phoenix_mesh(side, 1.4)
		w.material_override = mat
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.position = Vector3(0.08 * side, 0.12, 0)
		w.rotation.z = side * 0.55
		bird.add_child(w)
		tw.tween_property(w, "rotation:z", side * -0.2, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	Fx._burst(bird.global_position, 16, Color(1.0, 0.55, 0.15), 0.22, 3.5, 0.7, -0.1, true, "glow")
	tw.tween_property(bird, "scale", Vector3.ONE * 1.5, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(bird, "global_position", bird.global_position + Vector3(0, 1.2, -0.4), 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.9).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(bird.queue_free)


## The firebird's body: a teardrop of fire with a head and a crest of three flames, and three
## long tail streamers; white-gold at the heart, orange to red at the tips.
static func _firebird_body() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hot := Color(1.0, 0.92, 0.62)
	var orange := Color(1.0, 0.55, 0.12)
	var red := Color(0.95, 0.2, 0.04)
	var pts := [Vector3(0, -0.42, 0), Vector3(0, -0.3, 0), Vector3(0, -0.1, 0), Vector3(0, 0.1, 0), Vector3(0, 0.26, 0), Vector3(0, 0.36, 0), Vector3(0, 0.46, 0), Vector3(0, 0.58, 0)]
	var r := [0.0, 0.09, 0.15, 0.15, 0.1, 0.08, 0.1, 0.0]
	LegendPet._loft(st, pts, r, r, [orange, hot, hot, hot, hot, hot, hot, orange], 10)
	for k in 3:
		var x := (k - 1) * 0.07
		LegendPet._spike(st, Vector3(x, 0.52, 0), Vector3(x * 2.5, 0.78 - absf(x), 0), Vector3(0, 0, 0.0), 0.035, hot, red, 4)
	for k in 3:
		var x := (k - 1) * 0.32
		LegendPet._spike(st, Vector3(0, -0.36, 0), Vector3(x, -1.35 + absf(x) * 0.5, 0), Vector3(-x * 0.4, 0.0, 0.0), 0.06, orange, red, 6)
	return st.commit()
