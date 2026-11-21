class_name TrapHall
extends Node3D
## The Trap Hall (version 242, whole-game review fix 13): a door that leads to a different
## room. Three rows of spikes cross the hall from wall to wall and fire one after another,
## far to near, again and again while the fight lasts. Each row glows red before it fires.
## They hurt skeletons as much as the hero, so a skeleton led onto a glowing row is a
## skeleton half dead. The reward is a full heal once the hall is won.

const ROWS := [-6.0, -2.0, 2.0]   # the hero starts near z = 5.5, clear of them
const DEPTH := 1.25
const REST := 1.9
const WARN := 0.8
const UP := 0.55
const STAGGER := 0.85             # each row fires this long after the one further away
const DELAY := 2.0                # before the first row, while the skeletons climb out
const DAMAGE := 12.0              # to the hero, before the floor's damage scale
const FOE_SHARE := 0.35           # to skeletons: this share of their full health
const STEEL := Color(0.72, 0.72, 0.78)

var _rows: Array[Dictionary] = []   # {z, t, glow, spikes, hit}
var _done := false


static func lay(room: Node3D) -> TrapHall:
	var h := TrapHall.new()
	h.name = "TrapHall"
	room.add_child(h)
	h._build()
	return h


func _build() -> void:
	var w := Room.HALF_W * 2.0
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.11
	cone.height = 0.6
	cone.radial_segments = 5
	var steel := U.mat(STEEL, 0.3)
	var plate := U.mat(Color(0.1, 0.09, 0.11), 0.6)
	var per := int(w / 0.42)
	for i in ROWS.size():
		var z: float = ROWS[i]
		var row := Node3D.new()
		row.position = Vector3(0, 0, z)
		add_child(row)
		var base := U.floor_quad(row, Vector2(w, DEPTH), plate, Vector3(0, 0.015, 0))
		base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Hazard teeth along both edges, so a row reads as a trap even at rest.
		for side: float in [-1.0, 1.0]:
			var edge := U.floor_quad(row, Vector2(w, 0.08), U.unlit(Color(0.75, 0.2, 0.15, 0.8)), Vector3(0, 0.02, side * (DEPTH * 0.5 - 0.04)))
			edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var glow_mat := U.unlit(Color(1, 0.15, 0.1, 0.0)).duplicate() as StandardMaterial3D
		var glow := U.floor_quad(row, Vector2(w, DEPTH + 0.2), glow_mat, Vector3(0, 0.025, 0))
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# All the row's spikes in one draw: two staggered lines of cones.
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = cone
		mm.instance_count = per * 2
		for k in per * 2:
			var line := k / per
			var x := -w * 0.5 + 0.21 + (k % per) * 0.42 + (0.21 if line == 1 else 0.0)
			x = minf(x, w * 0.5 - 0.15)
			mm.set_instance_transform(k, Transform3D(Basis(), Vector3(x, 0.3, (line - 0.5) * 0.5)))
		var spikes := MultiMeshInstance3D.new()
		spikes.multimesh = mm
		spikes.material_override = steel
		spikes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spikes.position.y = -0.65
		row.add_child(spikes)
		# The far row starts to glow DELAY seconds in, the next STAGGER later, and so on.
		_rows.append({"z": z, "t": REST - DELAY - i * STAGGER, "glow": glow_mat, "spikes": spikes, "hit": false})


func _process(delta: float) -> void:
	if Game.state == Game.State.PAUSED:
		return
	if not _done and (Game.state != Game.State.PLAYING or not Game.fight_on()):
		_done = true
	var cycle := REST + WARN + UP
	for r: Dictionary in _rows:
		var spikes: Node3D = r.spikes
		var glow: StandardMaterial3D = r.glow
		if _done:
			spikes.position.y = move_toward(spikes.position.y, -0.65, delta * 3.0)
			glow.albedo_color.a = move_toward(glow.albedo_color.a, 0.0, delta * 2.0)
			continue
		r.t += delta
		if r.t < 0.0:
			continue   # waiting for its first turn
		var k := fmod(r.t, cycle)
		if k < REST:
			spikes.position.y = move_toward(spikes.position.y, -0.65, delta * 3.0)
			glow.albedo_color.a = 0.0
			r.hit = false
		elif k < REST + WARN:
			var w := (k - REST) / WARN
			glow.albedo_color.a = 0.3 + 0.3 * sin(w * 22.0) + 0.2 * w
			spikes.position.y = -0.5
		else:
			glow.albedo_color.a = 0.3
			spikes.position.y = move_toward(spikes.position.y, 0.0, delta * 14.0)
			if not r.hit and spikes.position.y > -0.25:
				r.hit = true
				_fire(float(r.z))


## A row's spikes are up: everything standing on it is hurt.
func _fire(z: float) -> void:
	Sfx.play("slam", 0.3, 1.4)
	var half := DEPTH * 0.5
	var hero := Game.hero
	if hero and hero.can_be_hit() and absf(hero.global_position.z - z) < half + hero.radius * 0.5:
		Game.hit_source = "Trap Hall"
		hero.take_damage(DAMAGE, Vector3(0, 0, signf(hero.global_position.z - z + 0.01)), 6.0)
	for a: Actor in Actor.all.duplicate():
		if a is Enemy and not (a as Enemy).is_boss and a.can_be_hit() and absf(a.global_position.z - z) < half + a.radius * 0.6:
			a.take_damage(a.max_health * FOE_SHARE, Vector3(0, 0, signf(a.global_position.z - z + 0.01)), 5.0)
