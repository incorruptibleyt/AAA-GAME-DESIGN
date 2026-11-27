class_name LegendGrand
extends Node3D
## Version 315 (Legend Vault, legends.gd): the grand sets, a whole new look worn over the hero.
##   starfall: Starfall Mantle. A long mantle that is a window into the night sky: the stars
##             behind it stay still on the screen while the hero moves, twinkle, and now and
##             then one shoots across it; silver edges, a star clasp on each shoulder, and
##             a tall collar of the same sky standing up behind the head, its tips beside the
##             ears so the set shows from the front. It takes the place of the hero's own
##             cape. With it a crown: a dome of the same night sky over the head, a silver
##             band with five dark points tipped with bright stars, and a comet circling it
##             (HeroStyle._extra "starfall_crown": a grand set's crown takes the place of the
##             hero's hat and head look, see HeroStyle.grand_head).
##             Version 328: a brighter sky of violet, teal and rose nebula; silver crown points
##             with glowing stars and a comet you can see; stars fall from the mantle's hem,
##             and a dash calls down a shower of falling stars round the hero.
## The mantle hangs from the chest bone, so it turns and bobs with the body. This node, on the
## hero's visual, blows it back as the hero runs; in a run (seen from far above) it always
## streams out behind.

var kind := "starfall"
var _hero: Node3D
var _last := Vector3.ZERO
var _blow := 0.0
var _cape_mat: ShaderMaterial
var _collar_mat: ShaderMaterial
var _was_dashing := false
var _fall: CPUParticles3D   # (the stars falling from the Starfall Mantle's hem)

## Where the mantle hangs from, in the visual's own space: the top of the back.
const CAPE_TOP := Vector3(0.0, 1.17, 0.19)


static func make(visual: Node3D, model: Node3D, grand: String) -> void:
	var g := LegendGrand.new()
	g.kind = grand
	g.name = "LegendGrand"
	visual.add_child(g)
	match grand:
		"starfall":
			g._starfall(visual, model)
		"emperor":
			g._emperor(visual, model)


var _looked := false


## Worn by a hero in the world (not on a pedestal)?
func _find_hero() -> void:
	_looked = true
	_staged = get_viewport() is SubViewport
	var n := get_parent()
	while n != null and not (n is Hero):
		n = n.get_parent()
	if n == null:
		return
	_hero = n as Node3D
	_last = _hero.global_position
	# In a run the camera looks down from far above, where a mantle hanging straight down is
	# only a line: there it always streams out behind, and further at a run, so its night sky
	# is seen.
	_cape_mat.set_shader_parameter("reach", 0.8)
	_cape_mat.set_shader_parameter("rise", 0.42)
	# ... and the sky has more stars, as the mantle and crown are small on the screen there.
	var skies: Array = [_cape_mat, _collar_mat]
	for c in get_parent().find_children("StarfallCrown", "", true, false):
		skies.append((c as StarCrown).sky)
	for m in skies:
		if m:
			(m as ShaderMaterial).set_shader_parameter("star_k", 1.6)
			(m as ShaderMaterial).set_shader_parameter("bright", 1.4)   # (version 328: it read as black there)
	if kind == "starfall":
		_cape_mat.set_shader_parameter("edge_w", 0.06)
	if _fall:
		# (the mantle streams out behind in a run: the stars fall from its hem out there)
		_fall.position = Vector3(0, 0.55, 0.95)
		_fall.emission_box_extents = Vector3(0.55, 0.25, 0.25)
		_fall.amount = 12


func _process(delta: float) -> void:
	if _cape_mat == null or delta <= 0.0:
		return
	if not _looked:
		_find_hero()
	var want := 0.0
	if _hero and is_instance_valid(_hero):
		var v := (_hero.global_position - _last) / delta
		_last = _hero.global_position
		v.y = 0.0
		want = clampf(v.length() / 6.0, 0.45, 1.0) if v.length() < 40.0 else 0.45
	_blow = move_toward(_blow, want, delta * (3.0 if want > _blow else 1.5))
	_cape_mat.set_shader_parameter("blow", _blow)
	if _hero and is_instance_valid(_hero):
		var dashing := (_hero as Hero).is_dashing()
		if dashing and not _was_dashing:
			if kind == "starfall":
				_meteors()
			else:
				_bone_spikes()
		_was_dashing = dashing
	if kind == "emperor":
		_throne_now()


## The hero's own cape comes off, and a holder for the grand set's mantle goes on the chest
## bone, placed so that at rest its origin is at CAPE_TOP in the visual (the top of the back);
## it then turns and bobs with the body.
func _back_holder(visual: Node3D, model: Node3D, holder_name: String) -> Node3D:
	var skel := Art._find_skeleton(model)
	for c in model.find_children("*_Cape", "MeshInstance3D", true, false):
		(c as Node3D).visible = false
	var holder := Node3D.new()
	holder.name = holder_name
	var at := Transform3D(Basis.IDENTITY, CAPE_TOP)
	if skel and skel.find_bone("chest") >= 0:
		var att := HeroStyle._attachment(skel, "chest")
		att.add_child(holder)
		var to_skel := _chain(visual, skel)
		holder.transform = skel.get_bone_global_rest(skel.find_bone("chest")).affine_inverse() * to_skel.affine_inverse() * at
	else:
		visual.add_child(holder)
		holder.transform = at
	return holder


# ---------------------------------------------------------------- The Bone Emperor

var _throne: Node3D
var _staged := false

func _emperor(visual: Node3D, model: Node3D) -> void:
	var holder := _back_holder(visual, model, "SpineCape")
	_cape_mat = LegendEmperor.cape_material()
	var cape := MeshInstance3D.new()
	cape.mesh = LegendEmperor.cape_mesh()
	cape.material_override = _cape_mat
	cape.set_meta("fx", true)   # (its outline would not sway with it)
	holder.add_child(cape)
	LegendEmperor.nape(holder)
	var skel := Art._find_skeleton(model)
	if skel:
		LegendEmperor.pauldrons(skel)
		LegendEmperor.breastplate(skel)


## Version 329: a dash raises a row of bone spikes out of the floor along its path: clumps of
## three curved fangs of bone bursting up through a dark crack, one after another as the hero
## passes, leaning out from the path; they stand a moment and sink back.
func _bone_spikes() -> void:
	var world := Game.world
	var h := _hero as Hero
	if world == null or h._dash_dir.length() < 0.1:
		return
	var dir := Vector3(h._dash_dir.x, 0, h._dash_dir.z).normalized()
	var across := Vector3(-dir.z, 0, dir.x)
	var start := h.global_position
	var bone := LegendEmperor.bone_mat()
	var dark := LegendEmperor.dark_mat()
	for i in 6:
		var clump := Node3D.new()
		world.add_child(clump)
		clump.global_position = start + dir * (0.35 + i * 0.62) + across * (0.1 if i % 2 == 0 else -0.1)
		clump.rotation.y = atan2(-dir.x, -dir.z)   # (its x across the path)
		clump.scale = Vector3(1.0, 0.05, 1.0)
		clump.visible = false
		U.cylinder(clump, 0.46, 0.012, dark, Vector3(0, 0.006, 0))
		for k in 3:
			var tall := 1.1 if k == 1 else 0.8
			var rb := 0.17 if k == 1 else 0.13
			var sp := Node3D.new()
			sp.position = Vector3((k - 1) * 0.26, 0, randf_range(-0.08, 0.08))
			sp.rotation = Vector3(randf_range(-0.15, 0.15), 0, -(k - 1) * 0.42)
			clump.add_child(sp)
			U.cone(sp, rb, tall * 0.58, bone, Vector3.ZERO, rb * 0.55)
			var tip := Node3D.new()
			tip.position = Vector3(0, tall * 0.56, 0)
			tip.rotation.z = -(k - 1) * 0.35 if k != 1 else 0.0
			tip.rotation.x = 0.0 if k != 1 else 0.3
			sp.add_child(tip)
			U.cone(tip, rb * 0.56, tall * 0.48, bone, Vector3.ZERO, 0.0)
		var tw := clump.create_tween()
		tw.tween_interval(i * 0.03)
		tw.tween_callback(clump.show)
		tw.tween_callback(func() -> void:
			Fx._burst(clump.global_position + Vector3(0, 0.1, 0), 6, Color(0.88, 0.82, 0.7), 0.3, 2.2, 0.45, 0.8, true, "soft"))
		tw.tween_property(clump, "scale", Vector3.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.55)
		tw.tween_property(clump, "scale", Vector3(1.0, 0.05, 1.0), 0.22).set_ease(Tween.EASE_IN)
		tw.tween_callback(clump.queue_free)


## The bone throne stands behind the hero on the title screen and on a pedestal (built the
## first time it is wanted).
func _throne_now() -> void:
	var want := _staged or (_hero != null and Game.state == Game.State.TITLE)
	if want and _throne == null:
		_throne = LegendEmperor.throne()
		# On a pedestal the hero turns (they sway, are dragged round, spin for a reveal) while
		# the throne stays put behind them, square to the camera: it goes on the stage itself
		# (HeroStage: the visual's turning pivot, then the stage's root, where the camera looks
		# down -Z). Facing the other way here would put the throne in front of the hero.
		if _staged:
			# Version 397 (visual review of 388, fix 7): on a pedestal the Emperor sits on the
			# throne, face to the camera, and it turns with them (it stood square behind a
			# hero seen from the side, whose face the cape hid).
			get_parent().add_child(_throne)
			_throne.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * SEAT_SIZE), SEAT_AT - Vector3(0, SEAT_LIFT, 0))
			(get_parent() as Node3D).position.y = SEAT_LIFT   # (the hero is lifted onto the cushion)
		else:
			get_parent().add_child(_throne)
			_throne.position = Vector3(0, 0, 0.8)
	if _throne:
		_throne.visible = want
	if _staged and _throne:
		_sit()


const SEAT_SIZE := 0.86
const SEAT_AT := Vector3(0, 0, 0.1)
const SEAT_LIFT := 0.29
var _sit_name := ""

## Sits the hero down (and again after a cheer or a wave has stood them up).
func _sit() -> void:
	var v := get_parent() as CharacterVisual
	if v == null or v._anim == null:
		return
	if _sit_name == "":
		_sit_name = "-"
		for n: String in v._anim.get_animation_list():
			if n.ends_with("Sit_Chair_Idle"):
				_sit_name = n
				v._anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	if _sit_name == "-" or v._anim.current_animation == _sit_name:
		return
	if v._anim.current_animation in [str(v._anim_names.get("idle", "")), ""]:
		v._anim.play(_sit_name, 0.15)


func _exit_tree() -> void:
	# (On a pedestal the throne is the stage's, not the hero's: it goes when they do.)
	if _throne and is_instance_valid(_throne):
		_throne.queue_free()
	_throne = null


# ---------------------------------------------------------------- Starfall Mantle

func _starfall(visual: Node3D, model: Node3D) -> void:
	# The hero's own cape comes off: the mantle takes its place.
	var holder := _back_holder(visual, model, "StarMantle")
	_cape_mat = ShaderMaterial.new()
	_cape_mat.shader = _sky_shader()
	_cape_mat.set_shader_parameter("edge_w", 0.04)
	var cape := MeshInstance3D.new()
	cape.mesh = _cape_mesh()
	cape.material_override = _cape_mat
	cape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cape.set_meta("fx", true)   # (no outline, rim light or hit flash over the night sky)
	holder.add_child(cape)
	# The standing collar: its own copy of the sky, so it sways a little but never blows back.
	var collar_mat := _cape_mat.duplicate() as ShaderMaterial
	_collar_mat = collar_mat
	collar_mat.set_shader_parameter("edge_w", 0.07)
	var collar := MeshInstance3D.new()
	collar.mesh = _collar_mesh()
	collar.material_override = collar_mat
	collar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	collar.position = Vector3(0, -0.04, 0)
	collar.set_meta("fx", true)
	holder.add_child(collar)
	# A star clasp on each shoulder.
	var silver := LegendPet._mat("star_silver", Color(0.86, 0.88, 0.98), 0.25, Color(0.6, 0.7, 1.0), 0.35)
	silver.metallic = 0.8
	var gem := LegendPet._mat("star_gem", Color(1.0, 0.95, 0.8), 0.2, Color(1.0, 0.92, 0.7), 3.0)
	for side in [-1.0, 1.0]:
		var clasp := Node3D.new()
		clasp.position = Vector3(0.37 * side, 0.02, -0.12)
		holder.add_child(clasp)
		var disc := U.sphere(clasp, 0.085, silver, Vector3.ZERO)
		disc.scale = Vector3(1.0, 1.0, 0.45)
		var st := MeshInstance3D.new()
		st.mesh = star_mesh(0.1, 0.045, 0.03)
		st.material_override = gem
		st.position = Vector3(0, 0, -0.04)
		st.set_meta("fx", true)
		clasp.add_child(st)
		var glow := _glow(clasp, 0.17, Color(0.75, 0.8, 1.0), 0.6)
		glow.position = Vector3(0, 0, -0.03)
	# Version 328: stars fall from the mantle as the hero goes (on a pedestal they drift down
	# off the cloth; in a run they fall from its hem, see _find_hero).
	_fall = CPUParticles3D.new()
	_fall.mesh = Fx._shaped("glint")
	_fall.amount = 8
	_fall.lifetime = 1.1
	_fall.local_coords = false
	_fall.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fall.emission_box_extents = Vector3(0.42, 0.4, 0.08)
	_fall.position = Vector3(0, 0.62, 0.42)
	_fall.direction = Vector3.DOWN
	_fall.spread = 25.0
	_fall.initial_velocity_min = 0.15
	_fall.initial_velocity_max = 0.4
	_fall.gravity = Vector3(0, -1.2, 0)
	_fall.scale_amount_min = 0.16
	_fall.scale_amount_max = 0.3
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.3))
	grow.add_point(Vector2(0.25, 1.0))
	grow.add_point(Vector2(1, 0))
	_fall.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.8))
	ramp.set_color(1, Color(0.6, 0.72, 1.0))
	_fall.color_ramp = ramp
	add_child(_fall)


## A soft ball of added starlight under `parent`, `r` across (version 328: the billboard quads
## these were barely showed, and not at all in a run).
static func _glow(parent: Node3D, r: float, tint: Color, k: float) -> MeshInstance3D:
	var g := MeshInstance3D.new()
	g.mesh = LegendPet._glow_ball()
	g.material_override = star_glow(tint, k)
	g.scale = Vector3.ONE * r
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.set_meta("fx", true)
	parent.add_child(g)
	return g


static var _glow_sh: Shader
static var _glows := {}

## Added starlight on a ball, brightest at its middle (it writes ALPHA: see the Godot notes on
## additive shaders over a see-through picture).
static func star_glow(tint: Color, k: float) -> ShaderMaterial:
	var key := "%s/%.2f" % [tint.to_html(false), k]
	if _glows.has(key):
		return _glows[key]
	if _glow_sh == null:
		_glow_sh = Shader.new()
		_glow_sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
uniform vec3 tint = vec3(0.8, 0.85, 1.0);
uniform float k = 1.0;
void fragment() {
	float f = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 c = tint * f * k;
	float glow_a = max(max(c.r, c.g), c.b);
	ALBEDO = c / max(glow_a, 0.001);
	ALPHA = clamp(glow_a, 0.0, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = _glow_sh
	m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	m.set_shader_parameter("k", k)
	_glows[key] = m
	return m


## Version 328: a dash calls down a shower of falling stars. Five fat gold stars, spinning,
## with long blue tails of light, streak down out of the sky at a slant one after another
## and burst into glints where they land round the hero.
func _meteors() -> void:
	var world := Game.world
	if world == null:
		return
	var at := _hero.global_position
	var side := 1.0 if randf() < 0.5 else -1.0
	var gem := LegendPet._mat("star_gem", Color(1.0, 0.95, 0.8), 0.2, Color(1.0, 0.92, 0.7), 3.0)
	for i in 5:
		var land := at + Vector3(randf_range(-1.8, 1.8), 0.2, randf_range(-1.7, 1.2))
		var from := land + Vector3(1.4 * side, 4.4, -1.5)
		var m := Node3D.new()
		world.add_child(m)
		m.global_position = from
		m.visible = false
		var star := MeshInstance3D.new()
		star.mesh = star_mesh(0.26, 0.11, 0.07)
		star.material_override = gem
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		star.rotation.x = -1.0   # (its face to the run camera, above and behind)
		m.add_child(star)
		_glow(m, 0.34, Color(1.0, 0.9, 0.6), 0.85)
		var back := (from - land).normalized()
		for j in 10:
			var q := _glow(m, 0.2 - j * 0.015, Color(0.45, 0.65, 1.0), 0.85 - j * 0.075)
			q.position = back * (0.28 + j * 0.19)
		var tw := m.create_tween()
		tw.tween_interval(i * 0.09)
		tw.tween_callback(m.show)
		tw.tween_property(m, "global_position", land, 0.42).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(star, "rotation:z", TAU * 1.5 * side, 0.42)
		tw.tween_callback(func() -> void:
			Fx._burst(land + Vector3(0, 0.15, 0), 12, Color(1.0, 0.92, 0.7), 0.45, 3.0, 0.55, 0.25, true, "glint")
			m.queue_free())


## The transform from `to`'s space into `from`'s (from a node down to one of its descendants).
static func _chain(from: Node3D, to: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = to
	while n != null and n != from:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static var _cape: Mesh

## The mantle: narrow across the shoulders, flaring wide at the hem so it shows round the legs
## from the front, curving out round the back and falling away from the legs; the hem is cut
## into five pointed rays like a star's. Its own space: the top in the middle at the origin,
## hanging down -Y, the outside towards +Z.
static func _cape_mesh() -> Mesh:
	if _cape:
		return _cape
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 20   # (the five ray tips fall on columns 2, 6, 10, 14 and 18)
	var rows := 14
	var length := 1.1
	var pts := []
	for r in rows + 1:
		var row := []
		for c in cols + 1:
			var u := float(c) / cols
			var hem := 1.0 - 0.15 * absf(sin((u - 0.5) * PI * 5.0))
			var v := float(r) / rows * hem
			var w := lerpf(0.68, 1.85, pow(v, 1.2))
			var x := (u - 0.5) * w
			var wrap := 1.0 - pow(2.0 * u - 1.0, 2.0)
			var z := 0.11 * wrap * (1.0 - v * 0.5) + 0.3 * v * v + 0.05 * sin(u * TAU * 3.0) * v
			row.append([Vector3(x, -length * v, z), Vector2(u, float(r) / rows)])
		pts.append(row)
	_grid(st, pts)
	_cape = st.commit()
	return _cape


## Two triangles for each square of a grid of [position, uv] points, flat shaded.
static func _grid(st: SurfaceTool, pts: Array) -> void:
	for r in pts.size() - 1:
		for c in (pts[0] as Array).size() - 1:
			var a: Array = pts[r][c]
			var b: Array = pts[r][c + 1]
			var d: Array = pts[r + 1][c]
			var e: Array = pts[r + 1][c + 1]
			for tri in [[a, d, b], [b, d, e]]:
				var n: Vector3 = ((tri[1][0] - tri[0][0]) as Vector3).cross(tri[2][0] - tri[0][0]).normalized()
				for p: Array in tri:
					st.set_normal(n)
					st.set_uv(p[1])
					st.add_vertex(p[0])


static var _collar: Mesh

## A tall collar of night sky standing up behind the head and flaring out round it, so the
## set reads from the front too. Its own space like the mantle's: the bottom middle at the
## origin, rising +Y, the outside towards +Z. UV.y runs 0 at the bottom (still) to 1 at the
## scalloped top edge (the end the sky shader sways, and edges in silver).
static func _collar_mesh() -> Mesh:
	if _collar:
		return _collar
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 18
	var rows := 5
	var pts := []
	for r in rows + 1:
		var row := []
		for c in cols + 1:
			var u := float(c) / cols
			var k := (u - 0.5) * 2.0   # -1 .. 1 across
			# Tallest at the back and rising again into a point by each ear; three soft scallops.
			var top := 0.54 + 0.26 * pow(absf(k), 5.0) - 0.06 * absf(sin(k * PI * 1.5))
			var v := float(r) / rows
			var h := top * v
			var ang := k * 1.75   # (about 100 degrees each way round the back of the neck)
			var rad := lerpf(0.3, 0.86, pow(v, 0.8))   # (its tips stand out beside the big head)
			var p := Vector3(sin(ang) * rad, h, -0.19 + cos(ang) * rad + 0.16 * v)
			row.append([p, Vector2(u, v)])
		pts.append(row)
	_grid(st, pts)
	_collar = st.commit()
	return _collar


## A flat five-pointed star facing -Z and +Z, `thick` deep.
static func star_mesh(outer: float, inner: float, thick: float) -> Mesh:
	return U._cached("legendstar%.3f/%.3f/%.3f" % [outer, inner, thick], func():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var ring: Array[Vector3] = []
		for i in 10:
			var a := PI / 2.0 + TAU * i / 10.0
			var r := outer if i % 2 == 0 else inner
			ring.append(Vector3(cos(a) * r, sin(a) * r, 0.0))
		var h := thick * 0.5
		for i in 10:
			var p0 := ring[i]
			var p1 := ring[(i + 1) % 10]
			# (front faces turn clockwise as seen from outside)
			for face in [-1.0, 1.0]:
				var z := Vector3(0, 0, h * face)
				var c := Vector3(0, 0, h * face * 1.6)
				var tri := [c, p1 + z, p0 + z] if face > 0.0 else [c, p0 + z, p1 + z]
				for v: Vector3 in tri:
					st.set_normal(Vector3(0, 0, face))
					st.add_vertex(v)
			var out := ((p0 + p1) * 0.5).normalized()
			for q in [p0 - Vector3(0, 0, h), p0 + Vector3(0, 0, h), p1 + Vector3(0, 0, h), p0 - Vector3(0, 0, h), p1 + Vector3(0, 0, h), p1 - Vector3(0, 0, h)]:
				st.set_normal(out)
				st.add_vertex(q)
		return st.commit())


# ---------------------------------------------------------------- the Starfall crown

## The Starfall Mantle's crown, in the head bone's space (`y` the top of the head): a dome of
## the same night sky over the head (in place of the Knight's coif and the Barbarian's cap; from
## the run camera above, the head and the mantle are one window into the sky), a silver band
## round it with five dark points leaning out, each tipped with a bright star, and a comet
## circling above with a tail of sparks.
static func starfall_crown(id: String, y: float) -> Node3D:
	var crown := StarCrown.new()
	crown.name = "StarfallCrown"
	# (as big as the Knight's coif, and over the Rogue's hood)
	var dome_r := 0.6 if id != "mage" else 0.54
	var dome_h := dome_r * (1.12 if id == "knight" else 1.0)   # (over the Knight's hair)
	var base := y - 0.2   # (where the coif sits, see HeroStyle.CAP_Y)
	crown.position = Vector3(0, 0, -0.06)
	var sky := ShaderMaterial.new()
	sky.shader = _sky_shader()
	sky.set_shader_parameter("edge_w", 0.0)
	crown.sky = sky
	var silver := LegendPet._mat("star_silver", Color(0.86, 0.88, 0.98), 0.25, Color(0.6, 0.7, 1.0), 0.35)
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = dome_r
	sm.height = dome_h
	sm.is_hemisphere = true
	sm.radial_segments = 24
	sm.rings = 8
	dome.mesh = sm
	dome.material_override = sky
	dome.position = Vector3(0, base, 0)
	crown.add_child(dome)
	var band_y := base + 0.1
	var r := dome_r * sqrt(1.0 - pow(0.1 / dome_r, 2.0)) + 0.03
	var band := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r * 0.97
	cyl.height = 0.14
	cyl.radial_segments = 24
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	band.mesh = cyl
	band.material_override = sky
	band.position = Vector3(0, band_y, 0)
	crown.add_child(band)
	for k in [-0.075, 0.075]:
		var rim := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = r - 0.02
		tor.outer_radius = r + 0.03
		tor.rings = 24
		tor.ring_segments = 6
		rim.mesh = tor
		rim.material_override = silver
		rim.position = Vector3(0, band_y + k, 0)
		crown.add_child(rim)
	var gem := LegendPet._mat("star_gem", Color(1.0, 0.95, 0.8), 0.2, Color(1.0, 0.92, 0.7), 3.0)
	# Version 334: the sky dome over the head read as a purple hat. Two silver arches now cross
	# over it, studded with little stars, to a great star on top (an imperial crown's shape, the
	# sky its velvet cap), and sapphires and pearls of starlight ring the band.
	var arch_m := LegendPet._mat("star_silver_vc", Color.WHITE, 0.25, Color(0.6, 0.7, 1.0), 0.35)
	arch_m.vertex_color_use_as_albedo = true
	var ast := SurfaceTool.new()
	ast.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ar := dome_r + 0.035
	var ah := dome_h + 0.035
	var silver_c := Color(0.86, 0.88, 0.98)
	for turn in [PI / 4.0, PI * 0.75]:   # (crossing on the slant, so both show from the front)
		var pts := []
		var rr := []
		for k in 17:
			var t := lerpf(0.14, PI - 0.14, k / 16.0)
			var hz := Vector3(cos(t) * ar, 0, 0).rotated(Vector3.UP, turn)
			pts.append(hz + Vector3(0, base + sin(t) * ah, 0))
			rr.append(0.044)
		LegendPet._loft(ast, pts, rr, rr, [silver_c], 8)
		# (little studs along it)
		for k in [3, 5, 7, 9, 11, 13]:
			var on: Vector3 = pts[k]
			LegendPet._ball(ast, on + (on - Vector3(0, base, 0)).normalized() * 0.03, Vector3.ONE * 0.032, Color(1.0, 0.97, 0.88), 6)
	var arches := MeshInstance3D.new()
	arches.mesh = ast.commit()
	arches.material_override = arch_m
	crown.add_child(arches)
	var top := Node3D.new()
	top.position = Vector3(0, base + ah + 0.09, 0)
	crown.add_child(top)
	var ts := MeshInstance3D.new()
	ts.mesh = star_mesh(0.12, 0.05, 0.045)
	ts.material_override = gem
	top.add_child(ts)
	_glow(top, 0.2, Color(0.85, 0.9, 1.0), 0.85)
	top.set_meta("g", 0.2)
	crown._tips.append(top)
	var sapphire := LegendPet._mat("star_sapphire", Color(0.25, 0.45, 1.0), 0.15, Color(0.3, 0.5, 1.0), 1.6)
	for i in 5:
		var a := TAU * (i + 0.5) / 5.0
		var g := U.sphere(crown, 0.042, sapphire, Vector3(sin(a) * (r + 0.035), band_y, cos(a) * (r + 0.035)))
		g.scale = Vector3(1.0, 1.25, 0.7)
		g.rotation.y = a
		for side in [-1.0, 1.0]:
			var b2: float = a + side * 0.2
			U.sphere(crown, 0.022, gem, Vector3(sin(b2) * (r + 0.03), band_y, cos(b2) * (r + 0.03)))
	for i in 5:
		var a := TAU * i / 5.0
		# (tall enough to rise well above the dome; leaning out, so the camera above sees them)
		var tall := 0.68 if i == 0 else 0.56
		var lean := 0.22
		var arm := Node3D.new()
		arm.position = Vector3(sin(a) * r, band_y + 0.06, cos(a) * r)
		arm.rotation.y = a
		crown.add_child(arm)
		arm.rotate_object_local(Vector3.RIGHT, lean)
		var pt := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.075   # (version 334: slimmer, a crown's points, not a spiked helmet's)
		cone.height = tall
		cone.radial_segments = 4
		cone.rings = 1
		pt.mesh = cone
		pt.material_override = silver   # (version 328: dark sky points were lost on dark floors)
		pt.position = Vector3(0, tall * 0.5, 0)
		pt.rotation.y = PI / 4.0
		arm.add_child(pt)
		# A star at the tip, turned to face out, with a soft light round it.
		var tip := Node3D.new()
		tip.position = Vector3(0, tall + 0.07, 0.02)
		arm.add_child(tip)
		var st := MeshInstance3D.new()
		st.mesh = star_mesh(0.11 if i == 0 else 0.09, 0.045, 0.035)
		st.material_override = gem
		tip.add_child(st)
		var gr := 0.15 if i == 0 else 0.12
		_glow(tip, gr, Color(0.8, 0.85, 1.0), 0.75)
		tip.set_meta("g", gr)
		crown._tips.append(tip)
	# The comet: a bright head and a tail of fading sparks that follows it round.
	crown._orbit = Node3D.new()
	crown._orbit.position = Vector3(0, base + dome_h + 0.3, 0)
	crown.add_child(crown._orbit)
	crown.R = dome_r + 0.12
	var head := _glow(crown._orbit, 0.16, Color(0.95, 0.97, 1.0), 1.0)
	var core := U.sphere(crown._orbit, 0.05, gem, Vector3.ZERO)
	crown._comet = [head, core]
	for i in 8:
		var q := _glow(crown._orbit, 0.11 - i * 0.009, Color(0.55, 0.72, 1.0), 0.8 - i * 0.08)
		crown._tail.append(q)
	# The night sky, the stars and the lights take no outline, rim light or hit flash (a hero's
	# rim light drawn over a glow quad made it a black square on the pedestal).
	for mi in crown.find_children("*", "MeshInstance3D", true, false):
		if not (mi as MeshInstance3D).material_override in [silver, arch_m, sapphire]:
			mi.set_meta("fx", true)
	return crown


## The crown's moving parts: the tip stars turning, the comet going round.
class StarCrown extends Node3D:
	var _tips: Array[Node3D] = []
	var _orbit: Node3D
	var _comet: Array = []
	var _tail: Array[Node3D] = []
	var _t := 0.0
	var R := 0.62
	var sky: ShaderMaterial

	func _process(delta: float) -> void:
		_t += delta
		for i in _tips.size():
			var tip := _tips[i]
			tip.get_child(0).rotation.z = _t * 1.2 + i
			tip.get_child(1).scale = Vector3.ONE * float(tip.get_meta("g", 0.12)) * (0.85 + 0.25 * sin(_t * 3.0 + i * 1.7))
		var a := _t * 1.6
		var at := Vector3(sin(a) * R, 0.06 * sin(a * 2.0), cos(a) * R)
		for c: Node3D in _comet:
			c.position = at
		for i in _tail.size():
			var b := a - 0.16 * (i + 1)
			_tail[i].position = Vector3(sin(b) * R, 0.06 * sin(b * 2.0), cos(b) * R)


# ---------------------------------------------------------------- the night sky

static var _sky: Shader

## A window into the night sky: the stars are fixed on the screen (not on the cloth), so the
## cloth seems to open onto a sky behind it. Deep blue-violet with drifting nebula, three sizes
## of twinkling stars (the biggest with a cross of light), a shooting star now and then across
## the cloth, and folds that darken as they turn away. A silver edge where `edge_w` > 0.
static func _sky_shader() -> Shader:
	if _sky:
		return _sky
	_sky = Shader.new()
	_sky.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// (Marked as the hero's own body, like CharacterVisual's x-ray mark: else in a run the hero's
// see-through silhouette is drawn over the mantle and the crown, which hide the hero.)
stencil_mode write, compare_always, 2;
uniform float blow = 0.0;
uniform float star_k = 1.0;   // more stars (in a run, where the mantle is small on the screen)
uniform float reach = 0.34;   // how far back a full blow throws the hem (further in a run)
uniform float rise = 0.14;    // and how far up
uniform float edge_w = 0.04;
uniform float bright = 1.0;   // (brighter in a run, version 328)
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
vec3 stars(vec2 uv, float scale, float t, float big) {
	vec2 g = uv * scale * star_k;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id);
	if (h < 0.58) {
		return vec3(0.0);
	}
	vec2 d = f - (vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5) * 0.6;
	float tw = 0.55 + 0.45 * sin(t * (1.3 + h * 3.0) + h * 50.0);
	float s = smoothstep(0.075 * big * star_k * 0.9, 0.0, length(d));
	if (big > 1.5) {
		s += (smoothstep(0.025, 0.0, abs(d.x)) * smoothstep(0.4, 0.0, abs(d.y)) + smoothstep(0.025, 0.0, abs(d.y)) * smoothstep(0.4, 0.0, abs(d.x))) * 0.7;
	}
	return mix(vec3(0.72, 0.82, 1.0), vec3(1.0, 0.92, 0.75), hash(id + 1.3)) * s * tw;
}
void vertex() {
	float k = UV.y;
	float ripple = sin(TIME * 3.0 - UV.y * 5.0 + UV.x * 2.5) * (0.03 + blow * 0.05);
	VERTEX.z += ripple * k * k + blow * reach * pow(k, 1.4);
	VERTEX.y += blow * rise * k * k;
}
void fragment() {
	vec2 s = SCREEN_UV;
	s.x *= VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	float t = TIME;
	vec2 drift = vec2(t * 0.004, t * 0.001);
	float n = noise((s + drift) * 3.0) * 0.6 + noise((s + drift) * 7.0) * 0.4;
	// Version 328: a richer sky, deep blue with clouds of violet, teal and rose nebula.
	vec3 col = mix(vec3(0.04, 0.05, 0.17), vec3(0.42, 0.13, 0.66), smoothstep(0.35, 0.95, n));
	col += vec3(0.05, 0.26, 0.5) * smoothstep(0.45, 1.0, noise((s + drift * 2.0) * 2.0 + 4.0));
	col += vec3(0.5, 0.1, 0.32) * smoothstep(0.62, 1.0, noise((s - drift) * 4.0 + 9.0)) * 0.7;
	col *= bright;
	col += stars(s + drift, 52.0, t, 1.0) + stars(s + drift, 24.0, t + 3.0, 1.25) + stars(s + drift, 10.0, t + 7.0, 2.0) * 1.6;
	// A shooting star across the cloth every few seconds.
	float cyc = floor(t / 2.6);
	float ph = fract(t / 2.6);
	vec2 a = vec2(0.15 + 0.7 * hash(vec2(cyc, 1.0)), 0.1 + 0.5 * hash(vec2(cyc, 2.0)));
	vec2 dir = normalize(vec2(hash(vec2(cyc, 3.0)) > 0.5 ? 1.0 : -1.0, 0.8));
	vec2 head = a + dir * ph * 1.2;
	vec2 rel = UV - head;
	float along = dot(rel, -dir);
	float across = abs(dot(rel, vec2(-dir.y, dir.x)));
	col += vec3(0.9, 0.95, 1.0) * smoothstep(0.012, 0.0, across) * smoothstep(0.3, 0.0, along) * step(0.0, along) * (1.0 - smoothstep(0.4, 0.55, ph)) * 2.0;
	// Folds turned away are darker, with a violet sheen at the very edge.
	float facing = abs(dot(NORMAL, VIEW));
	col *= 0.6 + 0.4 * facing;
	col += vec3(0.3, 0.22, 0.7) * pow(1.0 - facing, 3.0) * 0.5;
	if (edge_w > 0.0) {
		float e = min(min(UV.x, 1.0 - UV.x), 1.0 - UV.y);
		col = mix(col, vec3(0.86, 0.9, 1.0) * (0.9 + 0.2 * sin(t * 3.0 + UV.y * 12.0)), smoothstep(edge_w, edge_w * 0.55, e));
	}
	ALBEDO = col;
}
"""
	return _sky
