class_name BlessingIcon
extends Control
## A small drawn badge for a blessing. Every blessing has its own picture (an eye for
## Keen Eye, a magnet for Treasure Magnet...) inside a ring in its family colour.
## Synergies get a gold star behind the picture. A blessing with no picture of its own
## falls back to its family's: a bolt, a flame, a snowflake or a bone.

const DARK := Color(0.1, 0.08, 0.12)
const HOT := Color(1, 0.92, 0.5)

var id := ""
var family := "bolt"
var color := Color.WHITE
var synergy := false
## Draws the badge bigger (the doors use 1.6). Set before adding it to a container.
var zoom := 1.0:
	set(v):
		zoom = v
		custom_minimum_size = Vector2(64, 64) * v
		size = custom_minimum_size
		queue_redraw()
# Where and how big the picture is drawn; the helpers below work in a 40 x 40 box around it.
var _c := Vector2.ZERO
var _k := 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(64, 64)
	size = Vector2(64, 64)


func show_for(u: Dictionary) -> void:
	id = u.id
	family = u.family
	color = Upgrades.color(u)
	synergy = u.rarity == "synergy"
	queue_redraw()


## A picture that isn't a blessing's own: the doors (doors.gd) use these. An empty
## `icon_id` draws the family's picture.
func show_icon(icon_id: String, fam: String, col: Color) -> void:
	id = icon_id
	family = fam
	color = col
	synergy = false
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(zoom, zoom))
	var c := size / 2.0 / zoom
	draw_circle(c, 30.0, Color(0, 0, 0, 0.45))
	if synergy:
		var star := PackedVector2Array()
		for i in 16:
			var r := 31.0 if i % 2 == 0 else 22.0
			var a := TAU * i / 16.0 - PI / 2.0
			star.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(star, Color(1.0, 0.78, 0.25, 0.85))
		draw_circle(c, 21.0, Color(0.1, 0.08, 0.12))
	draw_arc(c, 29.0, 0.0, TAU, 40, color.darkened(0.3), 2.0)
	_c = c
	_k = 0.72 if synergy else 1.0
	match id:
		"damage": _damage()
		"speed": _speed()
		"crit": _eye()
		"multishot": _twin()
		"rear": _u_turn()
		"pierce": _pierce()
		"diagonal": _fan()
		"fire": _flame(Vector2.ZERO, 1.0)
		"kindling": _kindling()
		"pyre": _pyre()
		"frost": _snowflake()
		"frostbite": _icicles()
		"deepfreeze": _ice_block()
		"vitality": _heart()
		"boots": _boot()
		"magnet": _magnet()
		"greed": _coins()
		"harvest": _scythe()
		"ward": _shield()
		"links": _chain()
		"marrow": _spine()
		"shatter": _shards()
		"bonestorm": _shard_ring()
		"ossuary": _skull()
		"nimble": _nimble()
		"backstab": _dagger()
		"quiver": _rings()
		"bulwark": _tower_shield()
		"broad": _sword()
		"aftershock": _quake()
		"bloodlust": _blood_drop()
		"heavy": _axe()
		"whirl": _spiral()
		"volatile": _orb_burst()
		"flow": _orb_flow()
		"meteors": _meteor_storm()
		"wildfire": _wildfire()
		"glacier": _glacier()
		"deadeye": _crosshair()
		"siphon": _siphon()
		"frozen_ground": _frozen_ground()
		"executioner": _executioner()
		"flashfire": _flashfire()
		"splinters": _splinters()
		"overcharge": _overcharge()
		"door_shrine": _shrine()
		"door_champion": _crown()
		_:
			match family:
				"bolt": _bolt()
				"flame": _flame(Vector2.ZERO, 1.0)
				"frost": _snowflake()
				"bone": _bone()


# ---------------------------------------------------------------- drawing helpers

func _v(p: Vector2) -> Vector2:
	return _c + p * _k


func _ln(a: Vector2, b: Vector2, w: float, col := color) -> void:
	draw_line(_v(a), _v(b), col, w * _k, true)


func _poly(pts: Array, col := color) -> void:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(_v(p))
	draw_colored_polygon(out, col)


func _outline(pts: Array, w: float, col := color) -> void:
	var out := PackedVector2Array()
	for p: Vector2 in pts + [pts[0]]:
		out.append(_v(p))
	draw_polyline(out, col, w * _k, true)


func _dot(p: Vector2, r: float, col := color) -> void:
	draw_circle(_v(p), r * _k, col)


func _arc(p: Vector2, r: float, from: float, to: float, w: float, col := color) -> void:
	draw_arc(_v(p), r * _k, from, to, 24, col, w * _k, true)


func _oval(p: Vector2, rx: float, ry: float, rot: float, w: float, col := color) -> void:
	var pts := []
	for i in 24:
		var t := TAU * i / 24.0
		pts.append(p + Vector2(cos(t) * rx, sin(t) * ry).rotated(rot))
	_outline(pts, w, col)


## A bolt from a to b with a pointed head at b.
func _arrow(a: Vector2, b: Vector2, w: float, head: float, col := color) -> void:
	var d := (b - a).normalized()
	var n := d.orthogonal()
	_ln(a, b - d * head * 0.6, w, col)
	_poly([b, b - d * head + n * head * 0.55, b - d * head - n * head * 0.55], col)


## A four-pointed twinkle.
func _sparkle(p: Vector2, r: float, col := Color.WHITE) -> void:
	var s := r * 0.25
	_poly([p + Vector2(0, -r), p + Vector2(s, -s), p + Vector2(r, 0), p + Vector2(s, s),
		p + Vector2(0, r), p + Vector2(-s, s), p + Vector2(-r, 0), p + Vector2(-s, -s)], col)


## A ring of `points` spikes, alternating between radius r1 and r2.
func _star(p: Vector2, points: int, r1: float, r2: float, turn: float, col: Color) -> void:
	var pts := []
	for i in points * 2:
		var a := TAU * i / (points * 2.0) + turn
		pts.append(p + Vector2(cos(a), sin(a)) * (r1 if i % 2 == 0 else r2))
	_poly(pts, col)


# ---------------------------------------------------------------- family pictures

func _bolt() -> void:
	# A crossbow bolt flying up and to the right.
	_arrow(Vector2(-13, 13), Vector2(17, -17), 4.0, 10.0)
	_ln(Vector2(-13, 13), Vector2(-19, 11), 3.0)
	_ln(Vector2(-13, 13), Vector2(-11, 19), 3.0)


func _flame(at: Vector2, s: float) -> void:
	var outer := []
	var inner := []
	for i in 24:
		var t := TAU * i / 24.0
		# A teardrop: round at the bottom, pulled to a point at the top.
		var p := Vector2(sin(t) * (1.0 - 0.55 * max(0.0, -cos(t))), cos(t))
		outer.append(at + Vector2(p.x * 13.0, p.y * 11.0 + 4.0 - max(0.0, -p.y) * 9.0) * s)
		inner.append(at + Vector2(p.x * 6.5, p.y * 6.0 + 8.0 - max(0.0, -p.y) * 4.0) * s)
	_poly(outer)
	_poly(inner, HOT)


func _snowflake() -> void:
	for i in 3:
		var d := Vector2.UP.rotated(PI / 3.0 * i) * 17.0
		_ln(-d, d, 3.5)
		for s in [-1.0, 1.0]:
			var tip: Vector2 = d * s
			var mid: Vector2 = d * s * 0.6
			_ln(mid, mid + (tip - mid).rotated(0.8) * 0.9, 2.5)
			_ln(mid, mid + (tip - mid).rotated(-0.8) * 0.9, 2.5)
	_dot(Vector2.ZERO, 3.5)


func _bone() -> void:
	var a := Vector2(-11, 11)
	var b := Vector2(11, -11)
	_ln(a, b, 7.0)
	var side := (b - a).normalized().orthogonal() * 4.5
	for e: Vector2 in [a, b]:
		_dot(e + side, 5.0)
		_dot(e - side, 5.0)


# ---------------------------------------------------------------- one picture per blessing

func _damage() -> void:
	# Sharpened Shots: a bolt with a big gleaming head.
	_ln(Vector2(-14, 14), Vector2(4, -4), 4.0)
	_poly([Vector2(16, -16), Vector2(-1, -9), Vector2(5, -5), Vector2(9, 1)])
	_ln(Vector2(-14, 14), Vector2(-19, 12), 3.0)
	_ln(Vector2(-14, 14), Vector2(-12, 19), 3.0)
	_sparkle(Vector2(-7, -10), 7.0)


func _speed() -> void:
	# Quick Draw: a bolt racing right, with speed lines behind it.
	_arrow(Vector2(-3, 0), Vector2(18, 0), 4.0, 11.0)
	var trail := Color(color, 0.75)
	_ln(Vector2(-17, -7), Vector2(-5, -7), 2.5, trail)
	_ln(Vector2(-19, 0), Vector2(-7, 0), 2.5, trail)
	_ln(Vector2(-17, 7), Vector2(-5, 7), 2.5, trail)


func _eye() -> void:
	# Keen Eye: an open eye with a gleam.
	var pts := []
	for i in 13:
		var t := i / 12.0
		pts.append(Vector2(lerpf(-17, 17, t), -sin(t * PI) * 10.0))
	for i in range(11, 0, -1):
		var t := i / 12.0
		pts.append(Vector2(lerpf(-17, 17, t), sin(t * PI) * 10.0))
	_poly(pts)
	_dot(Vector2.ZERO, 7.0, DARK)
	_dot(Vector2.ZERO, 3.0, color.darkened(0.2))
	_dot(Vector2(2.5, -2.5), 2.0, Color.WHITE)
	_ln(Vector2(0, -13), Vector2(0, -18), 2.5)
	_ln(Vector2(0, 13), Vector2(0, 18), 2.5)


func _twin() -> void:
	# Twin Shots: two bolts side by side.
	for x in [-7.0, 7.0]:
		_arrow(Vector2(x, 15), Vector2(x, -17), 3.5, 9.0)
		_ln(Vector2(x, 15), Vector2(x - 3.5, 18.5), 2.5)
		_ln(Vector2(x, 15), Vector2(x + 3.5, 18.5), 2.5)


func _u_turn() -> void:
	# Eyes in the Back: an arrow that turns round.
	_arc(Vector2(0, -3), 9.0, PI, TAU, 4.0)
	_ln(Vector2(9, -3), Vector2(9, 15), 4.0)
	_arrow(Vector2(-9, -3), Vector2(-9, 17), 4.0, 10.0)


func _pierce() -> void:
	# Piercing Shot: a bolt straight through a target.
	_arc(Vector2.ZERO, 10.0, 0.0, TAU, 3.0)
	_dot(Vector2.ZERO, 3.5)
	_arrow(Vector2(-17, 11), Vector2(18, -11), 3.5, 10.0, HOT)


func _fan() -> void:
	# Fan of Shots: three bolts spreading out.
	for tip: Vector2 in [Vector2(-15, -10), Vector2(0, -18), Vector2(15, -10)]:
		_arrow(Vector2(0, 15), tip, 3.0, 8.0)


func _kindling() -> void:
	# Kindling: crossed logs with a fire on top.
	var wood := color.darkened(0.45)
	_ln(Vector2(-15, 15), Vector2(10, 5), 6.0, wood)
	_ln(Vector2(15, 15), Vector2(-10, 5), 6.0, wood)
	_dot(Vector2(-15, 15), 3.0, HOT.darkened(0.2))
	_dot(Vector2(15, 15), 3.0, HOT.darkened(0.2))
	_flame(Vector2(0, -5), 0.65)


func _pyre() -> void:
	# Pyre: an explosion.
	_star(Vector2.ZERO, 8, 19.0, 9.0, 0.2, color)
	_star(Vector2.ZERO, 8, 10.0, 5.0, 0.6, HOT)


func _icicles() -> void:
	# Frostbite: icicles hanging from a ledge.
	_ln(Vector2(-16, -12), Vector2(16, -12), 6.0)
	_poly([Vector2(-15, -10), Vector2(-6, -10), Vector2(-10.5, 6)])
	_poly([Vector2(-5, -10), Vector2(5, -10), Vector2(0, 17)])
	_poly([Vector2(6, -10), Vector2(15, -10), Vector2(10.5, 2)])
	_dot(Vector2(10.5, 8), 1.8)


func _ice_block() -> void:
	# Deep Freeze: a cracked block of ice.
	var hex := []
	for i in 6:
		var a := -PI / 2.0 + i * PI / 3.0
		hex.append(Vector2(cos(a), sin(a)) * 16.0)
	_poly(hex, Color(color, 0.4))
	_outline(hex, 3.0)
	var crack := Color(1, 1, 1, 0.9)
	_ln(Vector2(-2, -15), Vector2(2, -5), 2.0, crack)
	_ln(Vector2(2, -5), Vector2(-3, 2), 2.0, crack)
	_ln(Vector2(-3, 2), Vector2(3, 9), 2.0, crack)
	_ln(Vector2(3, 9), Vector2(1, 15), 2.0, crack)
	_ln(Vector2(2, -5), Vector2(10, -2), 2.0, crack)
	_ln(Vector2(-3, 2), Vector2(-11, 5), 2.0, crack)


func _heart() -> void:
	# Vitality: a red heart with a plus.
	var pts := []
	for i in 32:
		var t := TAU * i / 32.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(Vector2(x, y) * 0.95 + Vector2(0, -2))
	_poly(pts, Color(0.95, 0.3, 0.35))
	_ln(Vector2(-6, 0), Vector2(6, 0), 3.5, Color.WHITE)
	_ln(Vector2(0, -6), Vector2(0, 6), 3.5, Color.WHITE)


func _boot() -> void:
	# Swift Boots: a boot with a little wing.
	_poly([Vector2(-6, -15), Vector2(5, -15), Vector2(5, 2), Vector2(16, 6), Vector2(17, 13), Vector2(-6, 13)])
	_ln(Vector2(-7, 14), Vector2(17, 14), 3.0, color.darkened(0.45))
	_ln(Vector2(-6, -11), Vector2(5, -11), 2.0, color.darkened(0.35))
	var wing := Color(1, 1, 1, 0.9)
	_ln(Vector2(-9, -12), Vector2(-18, -16), 2.5, wing)
	_ln(Vector2(-9, -6), Vector2(-19, -7), 2.5, wing)
	_ln(Vector2(-9, 0), Vector2(-17, 2), 2.5, wing)


func _magnet() -> void:
	# Treasure Magnet: a horseshoe magnet.
	_arc(Vector2(0, 2), 10.0, 0.0, PI, 7.0)
	_ln(Vector2(-10, 2), Vector2(-10, -11), 7.0)
	_ln(Vector2(10, 2), Vector2(10, -11), 7.0)
	_ln(Vector2(-10, -11), Vector2(-10, -17), 7.0, Color.WHITE)
	_ln(Vector2(10, -11), Vector2(10, -17), 7.0, Color.WHITE)


func _coins() -> void:
	# Golden Touch: a pile of shining coins.
	var gold := Color(1.0, 0.8, 0.3)
	_dot(Vector2(-5, 5), 11.0, gold.darkened(0.3))
	_dot(Vector2(4, -3), 11.0, gold)
	_arc(Vector2(4, -3), 7.5, 0.0, TAU, 2.0, gold.darkened(0.35))
	_ln(Vector2(4, -7), Vector2(4, 1), 2.5, gold.darkened(0.35))
	_sparkle(Vector2(13, -13), 6.0)


func _scythe() -> void:
	# Bone Harvest: a scythe.
	_ln(Vector2(-11, 17), Vector2(8, -14), 3.5, color.darkened(0.35))
	_poly([Vector2(9, -14), Vector2(2, -19), Vector2(-6, -19), Vector2(-13, -15), Vector2(-17, -8), Vector2(-18, 1),
		Vector2(-12, -5), Vector2(-7, -9), Vector2(0, -10), Vector2(6, -8)])


func _shield() -> void:
	# Bone Ward: a shield.
	var pts := [Vector2(-14, -13), Vector2(0, -17), Vector2(14, -13), Vector2(14, 0), Vector2(8, 10),
		Vector2(0, 17), Vector2(-8, 10), Vector2(-14, 0)]
	_poly(pts)
	var inner := pts.map(func(p: Vector2): return p * 0.6 + Vector2(0, 0.5))
	_outline(inner, 2.0, DARK)


func _chain() -> void:
	# Long Links: three chain links.
	_oval(Vector2(-10, 10), 7.5, 4.5, -PI / 4.0, 3.5)
	_oval(Vector2(0, 0), 7.5, 2.5, PI / 4.0, 3.5)
	_oval(Vector2(10, -10), 7.5, 4.5, -PI / 4.0, 3.5)


func _spine() -> void:
	# Marrow: a stack of vertebrae.
	for y in [-12.0, 0.0, 12.0]:
		_ln(Vector2(-6, y), Vector2(6, y), 7.0)
		_dot(Vector2(-6, y), 3.5)
		_dot(Vector2(6, y), 3.5)
		_ln(Vector2(-7, y), Vector2(-14, y - 3), 3.0)
		_ln(Vector2(7, y), Vector2(14, y - 3), 3.0)
		_dot(Vector2(0, y), 2.0, DARK)


func _shards() -> void:
	# Shatter: ice and fire shards bursting outwards.
	for i in 6:
		var d := Vector2.UP.rotated(TAU * i / 6.0 + 0.3)
		var n := d.orthogonal()
		var col := color if i % 2 == 0 else Color(1.0, 0.52, 0.2)
		_poly([d * 19.0, d * 6.0 + n * 3.5, d * 6.0 - n * 3.5], col)
	_dot(Vector2.ZERO, 4.0, Color.WHITE)


func _shard_ring() -> void:
	# Bone Storm: a ring of bone shards flying out.
	for i in 8:
		var d := Vector2.UP.rotated(TAU * i / 8.0)
		var n := d.orthogonal()
		_poly([d * 19.0, d * 12.0 + n * 3.0, d * 6.0, d * 12.0 - n * 3.0], color if i % 2 == 0 else Color(0.88, 0.92, 0.72))
	_dot(Vector2.ZERO, 3.5, HOT)


func _skull() -> void:
	# Ossuary: a skull.
	_dot(Vector2(0, -4), 13.0)
	_poly([Vector2(-8, 3), Vector2(8, 3), Vector2(7, 14), Vector2(-7, 14)])
	_dot(Vector2(-5, -3), 4.0, DARK)
	_dot(Vector2(5, -3), 4.0, DARK)
	_poly([Vector2(0, 2), Vector2(-2.5, 6), Vector2(2.5, 6)], DARK)
	for x in [-3.5, 0.0, 3.5]:
		_ln(Vector2(x, 9), Vector2(x, 14), 1.5, DARK)


# ---------------------------------------------------------------- hero blessings

const STEEL := Color(0.86, 0.9, 0.96)
const ARCANE := Color(0.8, 0.5, 1.0)
const BLOOD := Color(0.88, 0.14, 0.18)
const EMBER := Color(1.0, 0.55, 0.2)


func _nimble() -> void:
	# Nimble: dash chevrons.
	for x in [-9.0, 4.0]:
		_ln(Vector2(x - 5, -12), Vector2(x + 6, 0), 5.0)
		_ln(Vector2(x + 6, 0), Vector2(x - 5, 12), 5.0)
	_dot(Vector2(14, 0), 2.5, Color.WHITE)


func _dagger() -> void:
	# Backstab: a dagger.
	var d := Vector2(1, -1).normalized()
	var n := d.orthogonal()
	_poly([d * 19.0, n * 4.5, -n * 4.5], STEEL)
	_ln(n * 8.0 - d * 1.0, -n * 8.0 - d * 1.0, 3.5)
	_ln(-d * 2.0, -d * 13.0, 4.0, color.darkened(0.35))
	_dot(-d * 14.5, 3.0)


func _rings() -> void:
	# Shadow Quiver: rings of shots spreading out.
	for r in [6.0, 11.0, 16.0]:
		_arc(Vector2.ZERO, r, 0.0, TAU, 2.5, ARCANE if r == 11.0 else color)
	for i in 6:
		var d := Vector2.UP.rotated(TAU * i / 6.0)
		_dot(d * 16.0, 2.5, Color.WHITE)
	_dot(Vector2.ZERO, 3.0, Color.WHITE)


func _tower_shield() -> void:
	# Bulwark: a big square shield with a cross.
	_poly([Vector2(-13, -16), Vector2(13, -16), Vector2(13, 5), Vector2(0, 17), Vector2(-13, 5)])
	_ln(Vector2(0, -14), Vector2(0, 14), 3.0, DARK)
	_ln(Vector2(-11, -4), Vector2(11, -4), 3.0, DARK)
	for p: Vector2 in [Vector2(-9, -12), Vector2(9, -12), Vector2(-9, 4), Vector2(9, 4)]:
		_dot(p, 1.6, DARK)


func _sword() -> void:
	# Broad Swing: a sword with a sweeping arc.
	_arc(Vector2(0, 3), 17.0, PI + 0.35, TAU - 0.35, 3.0, Color(1, 1, 1, 0.75))
	_poly([Vector2(0, -16), Vector2(3, -12), Vector2(3, 5), Vector2(-3, 5), Vector2(-3, -12)], STEEL)
	_ln(Vector2(-8, 6), Vector2(8, 6), 3.5)
	_ln(Vector2(0, 7), Vector2(0, 14), 3.0, color.darkened(0.35))
	_dot(Vector2(0, 15.5), 2.5)


func _quake() -> void:
	# Aftershock: shockwaves over a cracked floor.
	_arc(Vector2(0, 8), 8.0, PI, TAU, 3.0, Color.WHITE)
	_arc(Vector2(0, 8), 15.0, PI + 0.15, TAU - 0.15, 3.0)
	_ln(Vector2(-18, 9), Vector2(18, 9), 3.0)
	_ln(Vector2(0, 9), Vector2(3, 13), 2.5)
	_ln(Vector2(3, 13), Vector2(-1, 17), 2.5)
	_ln(Vector2(-9, 9), Vector2(-11, 14), 2.0)
	_ln(Vector2(9, 9), Vector2(12, 13), 2.0)


func _blood_drop() -> void:
	# Bloodlust: a drop of blood.
	var pts := []
	for i in 24:
		var t := TAU * i / 24.0
		var p := Vector2(sin(t) * (1.0 - 0.55 * max(0.0, -cos(t))), cos(t))
		pts.append(Vector2(p.x * 12.0, p.y * 10.0 + 5.0 - max(0.0, -p.y) * 9.0))
	_poly(pts, BLOOD)
	_dot(Vector2(-4, 6), 2.5, Color(1, 1, 1, 0.8))


func _axe() -> void:
	# Heavy Axes: a big axe.
	_ln(Vector2(-11, 17), Vector2(9, -13), 4.0, color.darkened(0.4))
	_poly([Vector2(3, -9), Vector2(9, -19), Vector2(17, -15), Vector2(19, -5), Vector2(13, 3), Vector2(7, -3)], STEEL)
	_ln(Vector2(9, -19), Vector2(19, -5), 2.0, Color.WHITE)


func _spiral() -> void:
	# Endless Whirl: a spinning spiral.
	var pts := PackedVector2Array()
	for i in 41:
		var a := i * 0.36
		pts.append(_v(Vector2(cos(a), sin(a)) * (2.0 + i * 0.4)))
	draw_polyline(pts, color, 3.5 * _k, true)
	var end := Vector2(cos(40 * 0.36), sin(40 * 0.36)) * 18.0
	_dot(end, 3.0, Color.WHITE)


func _orb_burst() -> void:
	# Volatile Orbs: an orb bursting.
	for i in 8:
		var d := Vector2.UP.rotated(TAU * i / 8.0 + 0.2)
		_ln(d * 10.0, d * 18.0, 3.0, EMBER)
	_dot(Vector2.ZERO, 8.0, ARCANE)
	_dot(Vector2(-2.5, -2.5), 2.5, Color.WHITE)


func _orb_flow() -> void:
	# Arcane Flow: an orb streaking along.
	var trail := Color(color, 0.75)
	_ln(Vector2(-18, -6), Vector2(-2, -6), 2.5, trail)
	_ln(Vector2(-19, 0), Vector2(-2, 0), 2.5, trail)
	_ln(Vector2(-18, 6), Vector2(-2, 6), 2.5, trail)
	_dot(Vector2(7, 0), 9.0, ARCANE)
	_dot(Vector2(4.5, -2.5), 2.5, Color.WHITE)


func _meteor_storm() -> void:
	# Meteor Storm: falling meteors with fiery tails.
	for m in [[Vector2(7, -7), 7.0], [Vector2(-9, -12), 3.5], [Vector2(13, 7), 3.5]]:
		var at: Vector2 = m[0]
		var r: float = m[1]
		var d := Vector2(-1, 1).normalized()
		var n := d.orthogonal()
		_poly([at + n * r, at - n * r, at + d * r * 3.2], Color(EMBER, 0.75))
		_dot(at, r, EMBER)
		_dot(at - Vector2(r, r) * 0.25, r * 0.45, HOT)


func _wildfire() -> void:
	# Wildfire: one flame catching another.
	_flame(Vector2(-6, 2), 0.75)
	_flame(Vector2(8, -2), 0.6)
	_ln(Vector2(-1, -8), Vector2(5, -12), 2.0, HOT)


func _glacier() -> void:
	# Glacier: a shield of ice.
	var pts := [Vector2(-14, -13), Vector2(0, -17), Vector2(14, -13), Vector2(14, 0), Vector2(8, 10),
		Vector2(0, 17), Vector2(-8, 10), Vector2(-14, 0)]
	_poly(pts, Color(color, 0.35))
	_outline(pts, 2.5)
	for i in 3:
		var d := Vector2.UP.rotated(PI / 3.0 * i) * 9.0
		_ln(-d, d, 2.5, Color.WHITE)


func _crosshair() -> void:
	# Deadeye: a crosshair locked on.
	_arc(Vector2.ZERO, 13.0, 0.0, TAU, 3.0)
	for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		_ln(d * 8.0, d * 19.0, 3.0)
	_dot(Vector2.ZERO, 3.5, Color(1, 0.3, 0.3))


# ---------------------------------------------------------------- Vault blessings

func _siphon() -> void:
	# Soul Siphon: a pale wisp curling down into a heart.
	var pts := []
	for i in 32:
		var t := TAU * i / 32.0
		pts.append(Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))) * 0.55 + Vector2(3, 7))
	_poly(pts, Color(0.95, 0.3, 0.35))
	var wisp := Color(0.75, 0.95, 1.0, 0.9)
	_arc(Vector2(-6, -8), 8.0, PI * 0.9, PI * 2.2, 3.0, wisp)
	_arc(Vector2(-1, -6), 13.0, PI * 1.05, PI * 1.6, 2.5, Color(wisp, 0.6))
	_dot(Vector2(-13, -12), 3.0, wisp)


func _frozen_ground() -> void:
	# Frozen Ground: ice spikes bursting out of the floor.
	_oval(Vector2(0, 11), 18.0, 5.0, 0.0, 2.5)
	_poly([Vector2(-13, 10), Vector2(-9, -6), Vector2(-5, 10)], Color(color, 0.85))
	_poly([Vector2(-5, 10), Vector2(0, -17), Vector2(5, 10)])
	_poly([Vector2(5, 10), Vector2(10, -4), Vector2(14, 10)], Color(color, 0.85))
	_ln(Vector2(0, -12), Vector2(0, 4), 1.5, Color.WHITE)


func _executioner() -> void:
	# Executioner: a heavy blade over a nearly empty health bar.
	_poly([Vector2(-15, 9), Vector2(15, 9), Vector2(15, 16), Vector2(-15, 16)], DARK)
	_poly([Vector2(-14, 10), Vector2(-6, 10), Vector2(-6, 15), Vector2(-14, 15)], Color(0.9, 0.2, 0.2))
	_ln(Vector2(-15, -2), Vector2(9, -16), 3.5, color.darkened(0.4))
	_poly([Vector2(2, -14), Vector2(13, -20), Vector2(19, -8), Vector2(10, 0)], STEEL)
	_ln(Vector2(13, -20), Vector2(19, -8), 2.0, Color.WHITE)


func _flashfire() -> void:
	# Flashfire: a critical spark lighting a flame.
	_flame(Vector2(4, 4), 0.85)
	_sparkle(Vector2(-11, -11), 9.0, Color(1, 1, 0.8))
	_ln(Vector2(-6, -6), Vector2(-1, -1), 2.0, HOT)


func _splinters() -> void:
	# Bone Splinters: a skull bursting into three shards.
	_dot(Vector2(0, 1), 8.0, Color(0.92, 0.9, 0.82))
	_dot(Vector2(-3, 0), 2.5, DARK)
	_dot(Vector2(3, 0), 2.5, DARK)
	for i in 3:
		var d := Vector2.UP.rotated(TAU * i / 3.0 + 0.5)
		var n := d.orthogonal()
		_poly([d * 20.0, d * 12.0 + n * 3.5, d * 12.0 - n * 3.5], color)


func _overcharge() -> void:
	# Overcharge: a lightning bolt through a chain link.
	_oval(Vector2(-4, 4), 9.0, 6.0, -0.6, 3.0, Color(0.88, 0.92, 0.72))
	_poly([Vector2(4, -19), Vector2(-6, -1), Vector2(1, -1), Vector2(-4, 18), Vector2(10, -4), Vector2(3, -4), Vector2(9, -19)], HOT)


# ---------------------------------------------------------------- doors

func _shrine() -> void:
	# Shrine: two arrows chasing each other round a circle (a reroll).
	for start: float in [-0.95 * PI, 0.05 * PI]:
		var end := start + 0.8 * PI
		_arc(Vector2.ZERO, 13.0, start, end, 3.5)
		var tip := Vector2(cos(end), sin(end)) * 13.0
		var along := Vector2(-sin(end), cos(end))
		var out := tip.normalized()
		_poly([tip + along * 7.0, tip + out * 5.5, tip - out * 5.5])
	_dot(Vector2.ZERO, 3.5, Color.WHITE)


func _crown() -> void:
	# Champion's Door: a golden crown.
	var gold := Color(1.0, 0.8, 0.3)
	_poly([Vector2(-16, 10), Vector2(-16, -10), Vector2(-8, -1), Vector2(0, -15), Vector2(8, -1), Vector2(16, -10), Vector2(16, 10)], gold)
	_poly([Vector2(-16, 10), Vector2(16, 10), Vector2(16, 15), Vector2(-16, 15)], gold.darkened(0.25))
	_dot(Vector2(0, 4), 3.0, Color(0.9, 0.2, 0.25))
	_dot(Vector2(-9, 5), 2.0, Color(0.4, 0.7, 1.0))
	_dot(Vector2(9, 5), 2.0, Color(0.4, 0.7, 1.0))
