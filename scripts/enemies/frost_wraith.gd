class_name FrostWraith
extends Enemy
## Frozen Ossuary floors only. A hooded ghost in a ragged cloak that floats above the
## floor, with ice shards circling it. It keeps its distance, wails and marks a line
## towards you (the shards spin faster), then fires an ice beam down it. Step out of the
## line: a hit also freezes you slow for a moment.

## How high it floats, in metres.
const HOVER := 0.35

var _timer := 2.2
var _casting := 0.0
var _float := randf() * TAU
var _shards: Node3D
var _mist: MeshInstance3D
static var _cloak_mesh: ArrayMesh


func _setup() -> void:
	init_health(40.0)
	move_speed = 2.0
	contact_damage = 8.0
	radius = 0.5
	center_height = 1.0
	var look := bones(Art.SKELETON_MAGE, 2.0, Color(0.55, 0.9, 1.0))
	look.tint = Color(0.05, 0.2, 0.4, 1.0)
	look.hood = true
	look.accent = Color(0.3, 0.5, 0.75)
	look.weapon = "Skeleton_Staff"
	# No hat and no legs: a hood and a cloak instead, so it reads as a ghost, not a mage.
	look.hide = ["Skeleton_Mage_Hat", "Skeleton_Mage_LegLeft", "Skeleton_Mage_LegRight"]
	make_visual(look)
	_dress()


func _dress() -> void:
	var robe := StandardMaterial3D.new()
	robe.albedo_color = Color(0.1, 0.2, 0.36)
	robe.roughness = 0.7
	robe.emission_enabled = true
	robe.emission = Color(0.1, 0.25, 0.45)
	robe.cull_mode = BaseMaterial3D.CULL_DISABLED
	var frost := CharacterVisual.rim_material(Color(0.3, 0.65, 0.95))
	frost.set_shader_parameter("power", 3.5)
	var cloak := MeshInstance3D.new()
	cloak.mesh = _cloak()
	cloak.material_override = robe
	cloak.material_overlay = frost
	visual.add_child(cloak)

	# A hood over the skull, open at the front so the face and eyes show.
	var skel := Art._find_skeleton(visual)
	if skel and skel.find_bone("head") >= 0:
		var att := BoneAttachment3D.new()
		skel.add_child(att)
		att.bone_name = "head"
		var dome := SphereMesh.new()
		dome.radius = 0.62
		dome.height = 0.62
		dome.is_hemisphere = true
		var hood := MeshInstance3D.new()
		hood.mesh = dome
		hood.material_override = robe
		hood.material_overlay = frost
		hood.position = Vector3(0, 0.5, 0.12)
		hood.rotation.x = -PI / 2   # the dome points back, the open side forward
		att.add_child(hood)
		var tip := CylinderMesh.new()
		tip.top_radius = 0.0
		tip.bottom_radius = 0.28
		tip.height = 0.6
		var peak := MeshInstance3D.new()
		peak.mesh = tip
		peak.material_override = robe
		peak.material_overlay = frost
		peak.position = Vector3(0, 0.95, -0.32)
		peak.rotation.x = -0.75
		att.add_child(peak)

	# Three ice shards circle it at chest height.
	_shards = Node3D.new()
	_shards.position = Vector3(0, 0.85, 0)
	visual.add_child(_shards)
	var ice := U.mat(Color(0.7, 0.95, 1.0), 0.2, 2.0)
	for i in 3:
		var a := i / 3.0 * TAU
		var shard := U.box(_shards, Vector3(0.13, 0.42, 0.13), ice, Vector3(cos(a) * 0.8, 0, sin(a) * 0.8))
		shard.rotation = Vector3(0.5, a, 0.785)

	# Cold mist on the floor under it shows that it floats.
	_mist = U.floor_quad(self, Vector2(1.7, 1.7), U.unlit(Color(0.6, 0.9, 1.0, 0.4), U.soft_circle()), Vector3(0, 0.04, 0))


## A cone from the waist down to a ragged hem of points that stops above the floor.
static func _cloak() -> ArrayMesh:
	if _cloak_mesh:
		return _cloak_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	for i in n:
		var a0 := i / float(n) * TAU
		var a1 := (i + 1) / float(n) * TAU
		var top0 := Vector3(cos(a0) * 0.2, 0.55, sin(a0) * 0.2)
		var top1 := Vector3(cos(a1) * 0.2, 0.55, sin(a1) * 0.2)
		# Every other point of the hem hangs lower: the ragged edge.
		var y0 := -0.22 if i % 2 == 0 else -0.02
		var y1 := -0.22 if (i + 1) % 2 == 0 else -0.02
		var bot0 := Vector3(cos(a0) * 0.46, y0, sin(a0) * 0.46)
		var bot1 := Vector3(cos(a1) * 0.46, y1, sin(a1) * 0.46)
		for v in [top0, bot0, bot1, top0, bot1, top1]:
			st.add_vertex(v)
	st.generate_normals()
	_cloak_mesh = st.commit()
	return _cloak_mesh


func _process(delta: float) -> void:
	super._process(delta)
	if dead:
		return
	# Enemy._process puts the model back on the floor each frame; lift it and bob.
	_float += delta * 2.4
	visual.position.y += HOVER + sin(_float) * 0.07
	_shards.rotation.y += delta * (7.0 if _casting > 0.0 else 2.2)


func _think(hero: Hero, delta: float) -> void:
	var to := hero.global_position - global_position
	to.y = 0.0
	if _casting > 0.0:
		_casting -= delta
		stand(delta)
		face(to, 4.0, delta)
		return
	if to.length() > 8.0:
		walk(to, delta)
	elif to.length() < 4.5:
		walk(-to, delta)
	else:
		stand(delta)
		face(to, 8.0, delta)
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(3.3, 4.0)
		_casting = 1.1
		visual.attack(true)
		Sfx.play("wraith", 0.7)
		var dir := to.normalized()
		var from := global_position + dir * 0.6
		Fx.magic(center() + Vector3.UP * 0.3, Color(0.6, 0.9, 1.0), 14)
		track(Telegraph.line(from, dir, 10.0, 1.3, 0.9, func(): _beam(from, dir)))


func _beam(from: Vector3, dir: Vector3) -> void:
	Sfx.play("beam", 0.8)
	_beam_flash(from, dir)
	for i in 9:
		Fx.magic(from + dir * (i * 1.2) + Vector3.UP * 0.6, Color(0.7, 0.95, 1.0), 4)
	var hero := Game.hero
	if hero == null or hero.dead:
		return
	var rel := hero.global_position - from
	rel.y = 0.0
	var along := rel.dot(dir)
	var side := (rel - dir * along).length()
	if along < -0.5 or along > 10.0 + hero.radius or side > 0.65 + hero.radius * 0.6:
		return
	var before := hero.health
	Game.hit_source = "Frost Wraith"
	hero.take_damage(14.0, dir, 6.0)
	if hero.health < before:
		hero.chill(1.6)


## The beam itself: a bright shaft of ice down the marked line that thins and fades.
func _beam_flash(from: Vector3, dir: Vector3) -> void:
	var beam := Node3D.new()
	Telegraph._parent().add_child(beam)
	beam.global_position = from + Vector3.UP * 0.7
	beam.look_at(beam.global_position + dir, Vector3.UP)
	var mats: Array[StandardMaterial3D] = []
	for part in [[0.2, Color(0.85, 0.97, 1.0, 0.95)], [0.6, Color(0.35, 0.75, 1.0, 0.45)]]:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = part[1]
		U.box(beam, Vector3(part[0], part[0], 10.0), m, Vector3(0, 0, -5.0))
		mats.append(m)
	var tw := beam.create_tween().set_parallel()
	tw.tween_property(beam, "scale", Vector3(0.15, 0.15, 1.0), 0.45).set_ease(Tween.EASE_IN)
	for m in mats:
		tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(beam.queue_free)


func _on_death() -> void:
	super._on_death()
	_shards.visible = false
	_mist.queue_free()
	Fx.magic(center(), Color(0.7, 0.95, 1.0), 20)
