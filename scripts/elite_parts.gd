class_name EliteParts
extends RefCounted
## Version 372 (visual review of 366, fix 5): what makes each kind of elite look like itself.
## Until now an elite was its skeleton washed purple, with a flat sign floating over its
## health bar. Now the skeleton keeps its own colours (a purple glow round its edges and a
## purple pool under it still say "elite"), and each kind has pieces of its own and a sign
## drawn on the floor round its feet, which no hat or helmet can hide from the run camera:
## split: a glowing crack over its skull, cracked ground and a ring broken in two.
## burst: a collar of gold bone spikes, and six spikes on the floor (its six darts).
## fury: two great horns, and once it rages a mane of flames and a ring of fire.
## mender: a green halo over its head, and a ring of green crosses.
## ward: its bubble (bright at the edge now, clear in the middle) on a ring of runes.

const KIND := {"split": 1, "burst": 2, "fury": 3, "mender": 4, "ward": 5}
const POOL := Color(0.7, 0.3, 1.0)
## How wide the floor sign is, in metres (the pool alone was 2.4).
const SIGN := 3.3

static var _shader: Shader
static var _signs := {}
static var _mats := {}


## The floor sign for an elite's move ("" = the plain purple pool; "fury_hot" = raging).
static func sign_mat(move: String) -> ShaderMaterial:
	if _signs.has(move):
		return _signs[move]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform vec3 pool : source_color = vec3(0.7, 0.3, 1.0);
uniform int kind = 0;
uniform float hot = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	// the purple pool every elite stands in
	float g = 1.0 - smoothstep(0.0, 0.72, r);
	float s = 0.0;   // the sign
	if (kind == 1) {
		// cracks running out from its feet, and a ring broken in two
		float n = TAU / 5.0;
		float aa = mod(a + 0.22 * sin(r * 9.0 + floor((a + PI) / n) * 2.3), n) - n * 0.5;
		s = (1.0 - smoothstep(0.012, 0.045, abs(aa) * r)) * smoothstep(0.16, 0.26, r) * (1.0 - smoothstep(0.62, 0.74, r));
		float ring = 1.0 - smoothstep(0.025, 0.05, abs(r - 0.84));
		s = max(s, ring * smoothstep(0.16, 0.26, abs(sin(a))));
	} else if (kind == 2) {
		// six spikes pointing out, the way its darts will fly
		float n = TAU / 6.0;
		float aa = mod(a + n * 0.5, n) - n * 0.5;
		float w = 0.11 * (0.95 - r) / 0.42;
		s = (1.0 - smoothstep(w - 0.012, w + 0.012, abs(aa) * r)) * step(0.53, r) * step(r, 0.95);
		s = max(s, 1.0 - smoothstep(0.02, 0.04, abs(r - 0.5)));
	} else if (kind == 3) {
		// a ring of flames, licking faster once it rages
		float t = TIME * (2.5 + hot * 4.0);
		float lick = 0.5 + 0.5 * sin(a * 7.0 + t) * sin(a * 3.0 - t * 0.7);
		float outer = 0.62 + (0.2 + 0.12 * hot) * lick;
		s = smoothstep(0.44, 0.52, r) * (1.0 - smoothstep(outer - 0.08, outer, r)) * (0.55 + 0.45 * hot);
	} else if (kind == 4) {
		// four crosses going slowly round
		float n = TAU / 4.0;
		float aa = mod(a + TIME * 0.5 + n * 0.5, n) - n * 0.5;
		vec2 c = vec2(r * cos(aa) - 0.72, r * sin(aa));
		float plus = min(max(abs(c.x) - 0.15, abs(c.y) - 0.05), max(abs(c.x) - 0.05, abs(c.y) - 0.15));
		s = 1.0 - smoothstep(-0.01, 0.012, plus);
		s = max(s, (1.0 - smoothstep(0.015, 0.035, abs(r - 0.46))) * 0.8);
	} else if (kind == 5) {
		// two rings with rune marks between them
		float n = TAU / 8.0;
		float aa = mod(a - TIME * 0.3 + n * 0.5, n) - n * 0.5;
		vec2 c = vec2(r * cos(aa) - 0.75, r * sin(aa));
		s = 1.0 - smoothstep(-0.01, 0.012, abs(c.x) + abs(c.y) * 0.6 - 0.07);
		s = max(s, 1.0 - smoothstep(0.015, 0.03, abs(r - 0.62)));
		s = max(s, 1.0 - smoothstep(0.015, 0.03, abs(r - 0.9)));
	}
	ALBEDO = mix(pool, mix(col.rgb, vec3(1.0), 0.25 * s), smoothstep(0.0, 0.3, s));
	ALPHA = max(g * g * 0.5, s * 0.9);
}
"""
	var m := ShaderMaterial.new()
	m.shader = _shader
	var key := "fury" if move == "fury_hot" else move
	m.set_shader_parameter("pool", POOL)
	m.set_shader_parameter("kind", KIND.get(key, 0))
	m.set_shader_parameter("col", Enemy.ELITE_MOVES[key].col if KIND.has(key) else POOL)
	m.set_shader_parameter("hot", 1.0 if move == "fury_hot" else 0.0)
	_signs[move] = m
	return m


static func _m(key: String) -> Material:
	if not _mats.has(key):
		match key:
			"crack": _mats[key] = U.unlit(Color(1.0, 0.45, 0.9))
			"crack_hot": _mats[key] = U.unlit(Color(1.0, 0.9, 1.0))
			"spike": _mats[key] = U.mat(Color(0.95, 0.78, 0.45), 0.5, 0.2)
			"spike_root": _mats[key] = U.mat(Color(0.5, 0.3, 0.12), 0.7)
			"horn": _mats[key] = U.mat(Color(0.3, 0.07, 0.05), 0.5)
			"horn_tip": _mats[key] = U.mat(Color(1.0, 0.4, 0.12), 0.4, 1.2)
			"flame": _mats[key] = U.unlit(Color(1.0, 0.42, 0.1))
			"flame_hot": _mats[key] = U.unlit(Color(1.0, 0.85, 0.35))
			"halo": _mats[key] = U.unlit(Color(0.5, 1.0, 0.42))
			"halo_hot": _mats[key] = U.unlit(Color(0.9, 1.0, 0.8))
	return _mats[key]


## A place for parts on one of the skeleton's bones, or (a spider, a bat: no such bone) a
## holder on the elite itself at about that height.
static func _spot(e: Enemy, skel: Skeleton3D, bone: String, height: float) -> Node3D:
	var att: Node3D = FoeBodies._on(skel, bone) if skel else null
	if att == null:
		att = Node3D.new()
		e.add_child(att)
		att.position.y = height
		att.scale = Vector3.ONE * 1.2
	return att


static func _keep(root: Node3D) -> void:
	for c in root.get_children():
		c.set_meta("fx", true)   # (the hit flash and overlays leave the pieces alone)
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Puts `move`'s pieces on elite `e`. Returns the ones the elite moves itself:
## "flames" (Fury: shown once it rages) and "halo" (Mender: bobs).
static func dress(e: Enemy, move: String) -> Dictionary:
	var out := {}
	if not KIND.has(move) or e.visual == null:
		return out
	var skel: Skeleton3D = Art._find_skeleton(e.visual._model) if e.visual._model else null
	var top := e.center_height * 2.0
	match move:
		"split":
			# A jagged crack from brow to nape, standing a little proud of the skull (and of
			# most hats), with two short branches.
			var h := _spot(e, skel, "head", top - 0.6)
			var pts: Array[Vector3] = []
			for i in 9:
				var t := -1.25 + 2.5 * i / 8.0   # brow (-z) over the top to the nape
				pts.append(Vector3((0.09 if i % 2 == 0 else -0.09) * (1.0 if i > 0 and i < 8 else 0.0), 0.5 + 0.62 * cos(t), 0.62 * sin(t)))
			pts.append(pts[3] + Vector3(0.3, -0.12, 0.05))
			pts.append(pts[5] + Vector3(-0.3, -0.14, 0.0))
			var pairs := [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 7], [7, 8], [3, 9], [5, 10]]
			for pr: Array in pairs:
				var a: Vector3 = pts[pr[0]]
				var b: Vector3 = pts[pr[1]]
				var d := b - a
				var mid := (a + b) * 0.5
				var along := d.normalized()
				var side := along.cross((mid - Vector3(0, 0.5, 0)).normalized()).normalized()
				var bs := Basis(side, along, side.cross(along).normalized())
				for k in 2:
					var seg := U.box(h, Vector3(0.11 - 0.06 * k, d.length() + 0.05, 0.06 + 0.02 * k), _m("crack" if k == 0 else "crack_hot"))
					seg.transform = Transform3D(bs, mid)
			FeatHeads.bake(h, "elite split")
			_keep(h)
		"burst":
			# A collar of bone spikes, wider than any skull, pointing out and a little up.
			var c := _spot(e, skel, "chest", top * 0.6)
			for i in 8:
				var a := TAU * (i + 0.5) / 8.0
				var dir := Vector3(sin(a), 0.45, cos(a)).normalized()
				var from := Vector3(sin(a) * 0.38, 0.2, cos(a) * 0.38)
				OutfitShapes._ray(c, 0.1, 0.52, _m("spike"), from, dir)
				U.sphere(c, 0.11, _m("spike_root"), from)
			FeatHeads.bake(c, "elite burst")
			_keep(c)
		"fury":
			# Two great horns out of the sides of its skull, dark at the root, burning at the
			# tip; and a mane of flames on its shoulders for when it rages.
			var h := _spot(e, skel, "head", top - 0.6)
			for side: float in [-1.0, 1.0]:
				var dir := Vector3(side * 0.8, 0.6, -0.1).normalized()
				var from := Vector3(side * 0.36, 0.55, 0.0)
				OutfitShapes._ray(h, 0.18, 0.48, _m("horn"), from, dir, 0.1)
				OutfitShapes._ray(h, 0.1, 0.38, _m("horn_tip"), from + dir * 0.48, (dir + Vector3(0, 0.7, 0)).normalized())
			FeatHeads.bake(h, "elite fury horns")
			_keep(h)
			var c := _spot(e, skel, "chest", top * 0.6)
			var flames := Node3D.new()
			c.add_child(flames)
			for i in 7:
				var a := TAU * (i + 0.5) / 7.0
				var from := Vector3(sin(a) * 0.5, 0.12, cos(a) * 0.42)
				var dir := Vector3(sin(a) * 0.35, 1.0, cos(a) * 0.35).normalized()
				OutfitShapes._ray(flames, 0.17, 0.7 if i % 2 == 0 else 0.52, _m("flame"), from, dir)
				OutfitShapes._ray(flames, 0.09, 0.45 if i % 2 == 0 else 0.34, _m("flame_hot"), from + Vector3(0, 0.02, 0), dir)
			FeatHeads.bake(flames, "elite fury flames")
			_keep(flames)
			flames.set_meta("fx", true)
			flames.visible = false
			out["flames"] = flames
		"mender":
			# A halo floating over its head (over the tallest hat), a small cross at its heart.
			var halo := Node3D.new()
			e.add_child(halo)
			halo.position.y = top + 0.75
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.42
			tm.outer_radius = 0.56
			tm.rings = 24
			tm.ring_segments = 8
			ring.mesh = tm
			ring.material_override = _m("halo")
			halo.add_child(ring)
			U.box(halo, Vector3(0.36, 0.09, 0.11), _m("halo_hot"))
			U.box(halo, Vector3(0.11, 0.09, 0.36), _m("halo_hot"))
			_keep(halo)
			halo.rotation.x = 0.25   # tipped a little toward the camera, so the ring shows as a ring
			out["halo"] = halo
	return out
