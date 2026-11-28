class_name ChainSpine
extends Control
## The Bone Chain meter across the top: six vertebrae, one lighting up for every 0.5 of
## chain above x1 (four at x3, all six at x4 with Marrow). The next one fills in as you
## kill. Bone-white, then gold, then red-hot. When the chain breaks the spine shatters.

const COUNT := 6
const BONE := Color(0.96, 0.93, 0.84)
const GOLD := Color(1.0, 0.76, 0.28)
const HOT := Color(1.0, 0.28, 0.12)

var mult := 1.0
var drain := 0.0          # 0..1, how long the chain has left
## v392 (review v388 fix 4): the fight's meter is a plain fuse bar under the big number
## (seven grey bones at phone size read as nothing). The bones stay for other screens.
var bar := false
var _shards: Array = []   # {p, v, rot, spin, col, life}
var _pop := 0.0


## (Version 416, re-review of v410 fix 6: gold by x1.25, not still bone-white, so the number
## reads as the chain's colour from the first kills; red-hot by x4.)
static func color_for(m: float) -> Color:
	if m <= 1.5:
		return BONE.lerp(GOLD, clampf((m - 1.0) / 0.25, 0.0, 1.0))
	return GOLD.lerp(HOT, clampf((m - 1.5) / 2.5, 0.0, 1.0))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_chain(m: float) -> void:
	if m > mult + 0.01:
		_pop = 1.0
	mult = m


## Every lit vertebra flies apart.
func shatter() -> void:
	if bar:
		var n := 8
		for k in n:
			_shards.append({"p": Vector2(size.x * (k + 0.5) / n, size.y * 0.5),
				"v": Vector2(randf_range(-120, 120), randf_range(-240, -60)), "rot": randf() * TAU,
				"spin": randf_range(-12, 12), "col": color_for(mult), "life": 1.0})
		mult = 1.0
		return
	var lit := _lit()
	for i in COUNT:
		var amount := clampf(lit - i, 0.0, 1.0)
		if amount <= 0.05:
			continue
		var c := _center(i)
		for k in 4:
			_shards.append({"p": c + Vector2(randf_range(-8, 8), randf_range(-8, 8)),
				"v": Vector2(randf_range(-160, 160), randf_range(-260, -60)), "rot": randf() * TAU,
				"spin": randf_range(-12, 12), "col": color_for(mult), "life": 1.0})
	mult = 1.0


func _lit() -> float:
	return clampf((mult - 1.0) / 0.5, 0.0, COUNT)


func _step() -> float:
	return size.x / COUNT


func _center(i: int) -> Vector2:
	return Vector2(_step() * (i + 0.5), size.y * (0.5 if bar else 0.42))


func _process(delta: float) -> void:
	_pop = move_toward(_pop, 0.0, delta * 4.0)
	for s in _shards:
		s.v.y += 700.0 * delta
		s.p += s.v * delta
		s.rot += s.spin * delta
		s.life -= delta * 1.3
	_shards = _shards.filter(func(s): return s.life > 0.0)
	queue_redraw()


func _draw() -> void:
	if bar:
		_draw_bar()
		return
	var lit := _lit()
	var col := color_for(mult)
	var at_cap := mult >= Game.chain_max() - 0.01 and mult > 1.01
	var glow := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012) if at_cap else 0.0
	var h := size.y * 0.62
	# The spinal cord behind the bones, which drains like a fuse.
	var cord_y := size.y * 0.42
	draw_line(Vector2(6, cord_y), Vector2(size.x - 6, cord_y), Color(0, 0, 0, 0.75), 9.0)
	if mult > 1.01:
		draw_line(Vector2(6, cord_y), Vector2(6 + (size.x - 12) * drain, cord_y), Color(col.r, col.g, col.b, 1.0), 5.0)
	for i in COUNT:
		var amount := clampf(lit - i, 0.0, 1.0)
		var c := _center(i)
		var s := 1.0
		if amount >= 1.0 and i == floori(lit) - 1:
			s += _pop * 0.35
		s += glow * 0.08 * amount
		var w := _step() * 0.62 * s
		var hh := h * s
		# Version 386 (visual review of v383, fix 4): an empty vertebra is a faint bone with a
		# pale edge, not a black one on the dark pill, so the six slots to fill always read;
		# the one filling up now glows brighter as it fills.
		var empty := Color(0.55, 0.5, 0.45, 0.42)
		var fill := empty.lerp(col, amount)
		if amount > 0.0 and amount < 1.0:
			fill = empty.lerp(col, 0.3 + amount * 0.45)
		var edge := Color(0.95, 0.9, 0.8, 0.55) if amount < 1.0 else col.lerp(Color.WHITE, 0.45 + glow * 0.4)
		_vertebra(c, w, hh, fill, edge)
	for sh in _shards:
		var a: float = sh.life
		var pts := PackedVector2Array()
		for k in 3:
			pts.append(sh.p + Vector2(9, 0).rotated(sh.rot + TAU * k / 3.0) * (0.6 + k * 0.3))
		draw_colored_polygon(pts, Color(sh.col.r, sh.col.g, sh.col.b, a))


## The fuse: a dark rounded track; the fill is the time the chain has left, in the chain's
## colour (bone, gold, red-hot), with a white-hot tip. It glows at the cap.
func _draw_bar() -> void:
	var col := color_for(mult)
	var at_cap := mult >= Game.chain_max() - 0.01 and mult > 1.01
	var glow := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012) if at_cap else 0.0
	var r := Rect2(Vector2.ZERO, size)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.8)
	track.set_corner_radius_all(int(size.y * 0.5))
	track.border_color = Color(1.0, 0.92, 0.8, 0.35)
	track.set_border_width_all(1)
	draw_style_box(track, r)
	if mult > 1.01 and drain > 0.0:
		var w := maxf(size.y, (size.x - 2.0) * drain)
		var fill := StyleBoxFlat.new()
		# (v416: the last third of the fuse flashes, so running out is seen, not read)
		var low := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.016) if drain < 0.34 else 0.0
		fill.bg_color = col.lerp(Color.WHITE, glow * 0.35 + low * 0.45)
		fill.set_corner_radius_all(int(size.y * 0.5))
		draw_style_box(fill, Rect2(Vector2(1, 1), Vector2(w, size.y - 2.0)))
		var tip := Vector2(1.0 + w - size.y * 0.5, size.y * 0.5)
		# a burning spark at the fuse's end: a soft halo in the chain's colour round a white core
		var flick := 1.0 + 0.18 * sin(Time.get_ticks_msec() * 0.03)
		draw_circle(tip, size.y * 0.85 * flick, Color(col.r, col.g, col.b, 0.35))
		draw_circle(tip, size.y * 0.42 * (1.0 + _pop * 0.5), Color(1, 1, 0.95, 0.95))
	for sh in _shards:
		var a: float = sh.life
		var pts := PackedVector2Array()
		for k in 3:
			pts.append(sh.p + Vector2(7, 0).rotated(sh.rot + TAU * k / 3.0) * (0.6 + k * 0.3))
		draw_colored_polygon(pts, Color(sh.col.r, sh.col.g, sh.col.b, a))


## One vertebra: a rounded body with a wing on each side and a spike on top.
func _vertebra(c: Vector2, w: float, h: float, fill: Color, edge: Color) -> void:
	var body := PackedVector2Array([
		c + Vector2(-w * 0.28, -h * 0.5), c + Vector2(0, -h * 0.62), c + Vector2(w * 0.28, -h * 0.5),
		c + Vector2(w * 0.32, -h * 0.12), c + Vector2(w * 0.5, -h * 0.2), c + Vector2(w * 0.56, h * 0.05),
		c + Vector2(w * 0.32, h * 0.12), c + Vector2(w * 0.26, h * 0.48), c + Vector2(0, h * 0.4),
		c + Vector2(-w * 0.26, h * 0.48), c + Vector2(-w * 0.32, h * 0.12), c + Vector2(-w * 0.56, h * 0.05),
		c + Vector2(-w * 0.5, -h * 0.2), c + Vector2(-w * 0.32, -h * 0.12)])
	draw_colored_polygon(body, fill)
	var closed := body.duplicate()
	closed.append(body[0])
	draw_polyline(closed, edge, 2.5, true)
