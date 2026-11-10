class_name Rootbinder
extends Enemy
## Glowcap Grotto floors only. A mossy skeleton sorcerer with a crown of twisted roots and a
## staff budding with lime shoots. It keeps its distance and, every few seconds, drives its
## staff into the floor: a line of roots crawls along the ground after you. Step aside
## (it turns slowly) or dash through it. If the roots reach you they hold you in place for
## a moment; a dash tears free.

const LIME := Color(0.72, 1.0, 0.3)

var _timer := 2.0
var _casting := 0.0
var _crown: Node3D
static var _crown_baked: ArrayMesh


func _setup() -> void:
	init_health(36.0)
	move_speed = 2.1
	contact_damage = 8.0
	radius = 0.5
	center_height = 1.0
	var look := bones(Art.SKELETON_MAGE, 2.0, LIME)
	look.overlay = FungalLook.overlay(0.12, LIME)
	look.accent = Color(0.24, 0.3, 0.16)
	look.weapon = "Skeleton_Staff"
	look.attack_anim = "Spellcast_Summon"
	# No pointed hat: the root crown instead, so it reads as its own kind, not a mage.
	look.hide = ["Skeleton_Mage_Hat"]
	make_visual(look)
	_dress()


func _dress() -> void:
	var skel := Art._find_skeleton(visual)
	if skel == null:
		return
	if skel.find_bone("head") >= 0:
		var att := BoneAttachment3D.new()
		skel.add_child(att)
		att.bone_name = "head"
		_crown = Node3D.new()
		# The skull is big (its crown is about 0.85 up): the roots grow out of the top of it.
		_crown.position = Vector3(0, 0.78, -0.03)
		att.add_child(_crown)
		var mi := MeshInstance3D.new()
		mi.mesh = _crown_mesh()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_crown.add_child(mi)
	if skel.find_bone("handslot.r") >= 0:
		var hand := BoneAttachment3D.new()
		skel.add_child(hand)
		hand.bone_name = "handslot.r"
		var glow := U.unlit(Color(LIME.r, LIME.g, LIME.b, 0.8), U.soft_circle(), true).duplicate()
		glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var q := QuadMesh.new()
		q.size = Vector2(0.55, 0.55)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = glow
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hand.add_child(mi)
		mi.position = Vector3(0, 0.9, 0)


## Six twisted roots leaning out round the skull, alternately tall and short, each with a
## glowing lime bud, baked into one mesh.
static func _crown_mesh() -> ArrayMesh:
	if _crown_baked:
		return _crown_baked
	var bark := U.mat(Color(0.24, 0.17, 0.11), 0.9)
	var tip := U.mat(Color(0.72, 1.0, 0.35), 0.6, 1.4)
	var parts := []
	for i in 6:
		var a := i / 6.0 * TAU
		var h := 0.58 if i % 2 == 0 else 0.4
		var b := Basis(Vector3.UP, -a) * Basis(Vector3.FORWARD, -0.5)
		var base := Vector3(cos(a), 0, sin(a)) * 0.34
		parts.append([Props._cone(0.03, 0.085, h, 6), Transform3D(b, base + b * Vector3(0, h * 0.5, 0)), bark])
		parts.append([Props._sphere(), Transform3D(Basis.from_scale(Vector3.ONE * 0.09), base + b * Vector3(0, h, 0)), tip])
	_crown_baked = Props._bake(parts)
	return _crown_baked


func _think(hero: Hero, delta: float) -> void:
	var to := hero.global_position - global_position
	to.y = 0.0
	if _casting > 0.0:
		_casting -= delta
		stand(delta)
		face(to, 5.0, delta)
		if randf() < delta * 14.0:
			Fx.magic(global_position + Vector3.UP * 0.2, LIME, 2)
		return
	if to.length() > 7.5:
		walk(to, delta)
	elif to.length() < 4.0:
		walk(-to, delta)
	else:
		stand(delta)
		face(to, 8.0, delta)
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(3.6, 4.4)
		_casting = 0.75
		visual.attack(true)
		Sfx.play("roots", 0.5, 1.2)
		Fx.shockwave(global_position, LIME, 1.3)
		# The roots set off a moment after the staff hits the floor.
		get_tree().create_timer(0.45, false).timeout.connect(func():
			if not dead and Game.hero and Game.state == Game.State.PLAYING:
				RootCrawl.spawn(global_position + to.normalized() * 0.6, Game.hero.global_position, kind_name(), 8.0 * elite_mult(), 1.0))


func _on_death() -> void:
	super._on_death()
	if _crown:
		_crown.create_tween().tween_property(_crown, "scale", Vector3.ZERO, 0.3)
	Fx.magic(center(), LIME, 18)
