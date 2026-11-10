class_name Sporeling
extends Enemy
## Glowcap Grotto floors only. A small mossy skeleton with a glowing pink toadstool growing
## out of its skull. It toddles at you like a minion, and when it dies its cap bursts into
## a cloud of spores that hurts anyone standing in it. The cloud takes a moment to puff
## up: kill it at a distance, or step back after the last hit.

const PINK := Color(1.0, 0.42, 0.82)

var _wobble := randf() * 10.0
var _cap: Node3D


func _setup() -> void:
	init_health(26.0)
	move_speed = 2.8
	contact_damage = 10.0
	swipe_time = 0.45   # a short warning before each swipe
	drop_chance = 0.07
	radius = 0.45
	center_height = 0.8
	var look := bones(Art.SKELETON_MINION, 1.55, Color(1.0, 0.55, 0.9))
	look.overlay = FungalLook.overlay(0.0)
	look.accent = Color(0.3, 0.22, 0.34)
	# No cloak: bare mossy bones (and the toadstool for a hat) keep it apart from the
	# plain minions.
	look.hide = ["Skeleton_Minion_Cloak"]
	make_visual(look)
	_dress()


## The toadstool on its head, a little crooked.
func _dress() -> void:
	var skel := Art._find_skeleton(visual)
	if skel == null or skel.find_bone("head") < 0:
		return
	var att := BoneAttachment3D.new()
	skel.add_child(att)
	att.bone_name = "head"
	_cap = Node3D.new()
	# The minion's skull is big: the cap sits on its crown, wide enough to cover it.
	_cap.position = Vector3(0.04, 0.8, -0.02)
	_cap.rotation = Vector3(0.08, 0.4, -0.16)
	att.add_child(_cap)
	var mi := MeshInstance3D.new()
	mi.mesh = FungalLook.cap_mesh(0.52, 5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cap.add_child(mi)


func _think(hero: Hero, delta: float) -> void:
	_wobble += delta
	var to := (hero.global_position - global_position).normalized()
	var side := to.cross(Vector3.UP) * sin(_wobble * 2.6) * 0.45
	walk(to + side, delta)
	if _cap:
		# The cap bobs as it walks.
		_cap.scale = Vector3.ONE * (1.0 + 0.05 * sin(_wobble * 9.0))
	if randf() < delta * 2.0:
		Fx.magic(center() + Vector3.UP * 0.5, PINK, 1)


func _on_death() -> void:
	super._on_death()
	Sfx.play("spore", 0.8)
	if _cap:
		var tw := _cap.create_tween()
		tw.tween_property(_cap, "scale", Vector3.ONE * 1.6, 0.18).set_ease(Tween.EASE_OUT)
		tw.tween_property(_cap, "scale", Vector3.ZERO, 0.25)
	Fx.magic(center() + Vector3.UP * 0.4, PINK, 22)
	SporeCloud.spawn(global_position, 1.5 if elite else 1.25, 3.2, 5.0 * elite_mult())
