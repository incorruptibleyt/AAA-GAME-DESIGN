class_name RootCrawl
extends Node3D
## A line of roots crawling along the floor after the hero (the Rootbinder's attack, and
## the Sporemother's). The tip glows lime and kicks up dirt, and roots burst out of the
## floor behind it and sink again. It turns towards the hero, but slowly, so a step to the
## side is enough. If the tip reaches the hero they are hurt and held in place for a moment
## by a cage of roots: a dash tears free at once. Roots that reach a hero who is already held
## (or only just free) sink harmlessly.

const LIME := Color(0.72, 1.0, 0.3)
## Metres apart that roots burst out along the trail, and how long each one stays up.
const STEP := 0.45
const STAY := 0.9

var dir := Vector3.FORWARD
var speed := 4.4
var turn := 1.3
var life := 2.3
var damage := 8.0
var hold := 1.0
var source := "Rootbinder"
var _age := 0.0
var _since := 0.0
var _tip: MeshInstance3D
var _tip_mat: StandardMaterial3D

## Every crawling tip (the test robot steps away from them).
static var all: Array[RootCrawl] = []
static var _spikes: ArrayMesh


static func spawn(from: Vector3, toward: Vector3, who: String, hurt := 8.0, held := 1.0) -> RootCrawl:
	var parent: Node = Room.current if Room.current else Game.world
	if parent == null:
		return null
	var r := RootCrawl.new()
	var d := toward - from
	d.y = 0.0
	r.dir = d.normalized() if d.length_squared() > 0.01 else Vector3.BACK
	r.source = who
	r.damage = hurt
	r.hold = held
	parent.add_child(r)
	r.global_position = Vector3(from.x, 0.0, from.z)
	r._build()
	return r


func _enter_tree() -> void:
	all.append(self)


func _exit_tree() -> void:
	all.erase(self)


func _build() -> void:
	_tip_mat = U.unlit(Color(LIME.r, LIME.g, LIME.b, 0.75), U.soft_circle()).duplicate()
	_tip_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_tip = U.floor_quad(self, Vector2(1.5, 1.5), _tip_mat, Vector3(0, 0.05, 0))
	# A dark ring under the glow, so the tip reads on the pale Frozen floor and the pink glow.
	U.floor_quad(self, Vector2(1.25, 1.25), U.unlit(Color(0.08, 0.05, 0.02, 0.7), U.ring()), Vector3(0, 0.04, 0))
	Sfx.play("roots", 0.55, randf_range(0.9, 1.1))


func _process(delta: float) -> void:
	if Game.state != Game.State.PLAYING:
		if Game.state != Game.State.PAUSED and Game.state != Game.State.UPGRADE:
			queue_free()
		return
	_age += delta
	if _age >= life:
		_end()
		return
	var hero := Game.hero
	if hero and not hero.dead:
		var want := hero.global_position - global_position
		want.y = 0.0
		if want.length_squared() > 0.01:
			var a := dir.signed_angle_to(want.normalized(), Vector3.UP)
			dir = dir.rotated(Vector3.UP, clampf(a, -turn * delta, turn * delta))
	var next := global_position + dir * speed * delta
	if absf(next.x) > Room.HALF_W - 0.3 or absf(next.z) > Room.HALF_L - 0.3:
		_end()
		return
	global_position = next
	_tip.scale = Vector3.ONE * (0.9 + 0.15 * sin(_age * 18.0))
	_since += speed * delta
	if _since >= STEP:
		_since = 0.0
		_burst(global_position - dir * 0.2, 1.0)
		if randf() < 0.5:
			Fx.dust(global_position, 3)
	if hero and hero.can_be_hit():
		var d := hero.global_position - global_position
		d.y = 0.0
		if d.length() < 0.55 + hero.radius * 0.5:
			if not hero.can_be_snared():
				# Already held, or only just free: these roots can't take hold, so they
				# sink harmlessly (no pinning the hero under the next attack).
				Fx.dust(global_position, 6)
				_end()
				return
			Game.hit_source = source
			hero.take_damage(damage, dir, 2.0)
			hero.snare(hold)
			_cage(hero)
			_end()


func _end() -> void:
	set_process(false)
	var tw := create_tween()
	tw.tween_property(_tip_mat, "albedo_color:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


## A clump of roots bursting out of the floor at `at` that sinks again after a moment.
static func _burst(at: Vector3, size: float, stay := STAY) -> MeshInstance3D:
	var parent: Node = Room.current if Room.current else Game.world
	if parent == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = _spike_mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = Vector3(at.x, 0.0, at.z)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3(size, 0.05, size)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(size, size, size), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(stay)
	tw.tween_property(mi, "scale", Vector3(size, 0.02, size), 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi


## Roots wrapping round the hero's feet while they are held; they sink when the hero gets
## free (time up or a dash).
func _cage(hero: Hero) -> void:
	Fx.magic(hero.center(), LIME, 14)
	Sfx.play("roots", 0.8, 0.8)
	var parent: Node = Room.current if Room.current else Game.world
	var cage := Node3D.new()
	parent.add_child(cage)
	cage.global_position = Vector3(hero.global_position.x, 0.0, hero.global_position.z)
	for i in 5:
		var a := i / 5.0 * TAU
		var root := MeshInstance3D.new()
		root.mesh = _spike_mesh()
		root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.position = Vector3(cos(a), 0, sin(a)) * 0.42
		root.rotation = Vector3(0, -a, 0.35)
		root.scale = Vector3(0.8, 0.05, 0.8)
		cage.add_child(root)
		root.create_tween().tween_property(root, "scale", Vector3(0.8, 1.15, 0.8), 0.1).set_trans(Tween.TRANS_BACK)
	var watch := func() -> void:
		while is_instance_valid(hero) and hero.snare_left > 0.0 and not hero.dead:
			await cage.get_tree().process_frame
		if not is_instance_valid(cage):
			return
		var tw := cage.create_tween()
		tw.tween_property(cage, "scale", Vector3(1, 0.02, 1), 0.2)
		tw.tween_callback(cage.queue_free)
	watch.call()


## Three crooked roots, dark bark with pale lime tips, baked into one mesh.
static func _spike_mesh() -> ArrayMesh:
	if _spikes:
		return _spikes
	var bark := U.mat(Color(0.2, 0.14, 0.1), 0.9)
	var tip := U.mat(Color(0.72, 1.0, 0.35), 0.6, 1.2)
	var parts := []
	var plan := [[0.0, 0.0, 0.55, 0.0], [0.12, 2.1, 0.4, 0.35], [0.12, 4.2, 0.34, -0.4]]
	for p in plan:
		var at := Vector3(cos(p[1]) * p[0], 0, sin(p[1]) * p[0])
		var h: float = p[2]
		var b := Basis(Vector3.UP, p[1]) * Basis(Vector3.FORWARD, p[3])
		parts.append([Props._cone(0.02, 0.08, h, 6), Transform3D(b, at + b * Vector3(0, h * 0.5, 0)), bark])
		parts.append([Props._cone(0.0, 0.025, h * 0.3, 5), Transform3D(b, at + b * Vector3(0, h * 1.12, 0)), tip])
	_spikes = Props._bake(parts)
	return _spikes
