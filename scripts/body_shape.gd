class_name BodyShape
extends SkeletonModifier3D
## Version 343 (visual review fix 7, "enemies with their own bodies"): the 33 kinds of
## skeleton were drawn on 4 bodies. This gives a kind its own build on top of the shared
## animations: a bigger or smaller skull, long arms, short legs, a broad or narrow chest, a
## hunch. It runs after the animation every frame (a SkeletonModifier3D), so every walk,
## swing and death keeps the new shape.
##
## shape = {
##   "scale": {"head": 1.3, "upperleg.l": 0.8, ...}   # a bone and everything on it (a number,
##                                                     # or a Vector3 for one axis)
##   "turn": {"spine": Vector3(18, 0, 0)}              # degrees, added to the animation's pose
##   "lift": 0.2                                       # raised off the floor (a hovering mage)
## }
## Legs made shorter or longer keep the feet on the floor by themselves.

var scales := {}   # bone index -> Vector3
var turns := {}    # bone index -> Quaternion added on top of the animation
var _wrote := {}   # bone index -> the rotation written last frame


## Adds the shape to `model` (a KayKit character, already sized by Art.fit_height).
static func apply(model: Node3D, shape: Dictionary) -> BodyShape:
	var skel := Art._find_skeleton(model)
	if skel == null:
		return null
	var m := BodyShape.new()
	var sc: Dictionary = shape.get("scale", {})
	for b: String in sc:
		var i := skel.find_bone(b)
		if i >= 0:
			var v: Variant = sc[b]
			m.scales[i] = v if v is Vector3 else Vector3.ONE * float(v)
	var tu: Dictionary = shape.get("turn", {})
	for b: String in tu:
		var i := skel.find_bone(b)
		if i >= 0:
			var d: Vector3 = tu[b]
			m.turns[i] = Quaternion.from_euler(d * (PI / 180.0))
	skel.add_child(m)
	# Feet back on the floor: shorter legs would leave them in the air, longer ones in it.
	var to_parent := _to_parent(model, skel)
	var unit := to_parent.basis.get_scale().y
	var leg := skel.find_bone("upperleg.l")
	var drop := 0.0
	if leg >= 0 and m.scales.has(leg):
		drop = (1.0 - (m.scales[leg] as Vector3).y) * skel.get_bone_global_rest(leg).origin.y * unit
	model.position.y += float(shape.get("lift", 0.0)) * unit - drop
	return m


## The skeleton's transform in the model's parent's space (without needing the tree).
static func _to_parent(model: Node3D, skel: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = skel
	while n != null and n != model.get_parent():
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _process_modification_with_delta(_delta: float) -> void:
	var s := get_skeleton()
	if s == null:
		return
	for i: int in scales:
		s.set_bone_pose_scale(i, scales[i])
	for i: int in turns:
		var now := s.get_bone_pose_rotation(i)
		if _wrote.has(i) and now.is_equal_approx(_wrote[i]):
			continue   # the animation left it alone since (a held death pose): already turned
		var q: Quaternion = now * turns[i]
		s.set_bone_pose_rotation(i, q)
		_wrote[i] = q
