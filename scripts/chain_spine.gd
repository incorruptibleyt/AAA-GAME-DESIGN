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
var _shards: Array = []   # {p, v, rot, spin, col, life}
var _pop := 0.0


static func color_for(m: float) -> Color:
	var t := clampf((m - 1.0) / 3.0, 0.0, 1.0)
	return BONE.lerp(GOLD, t / 0.5) if t < 0.5 else GOLD.lerp(HOT, (t - 0.5) / 0.5)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_chain(m: float) -> void:
	if m > mult + 0.01:
		_pop = 1.0
	mult = m


## Every lit vertebra flies apart.
func shatter() -> void:
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
	return Vector2(_step() * (i + 0.5), size.y * 0.42)


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
	var lit := _lit()
	var col := color_for(mult)
	var at_cap := mult >= Game.chain_max() - 0.01 and mult > 1.01
	var glow := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012) if at_cap else 0.0
	var h := size.y * 0.62
	# The spinal cord behind the bones, which drains like a fuse.
	var cord_y := size.y * 0.42
	draw_line(Vector2(6, cord_y), Vector2(size.x - 6, cord_y), Color(0, 0, 0, 0.6), 8.0)
	if mult > 1.01:
		draw_line(Vector2(6, cord_y), Vector2(6 + (size.x - 12) * drain, cord_y), Color(col.r, col.g, col.b, 0.9), 4.0)
	for i in COUNT:
		var amount := clampf(lit - i, 0.0, 1.0)
		var c := _center(i)
		var s := 1.0
		if amount >= 1.0 and i == floori(lit) - 1:
			s += _pop * 0.35
		s += glow * 0.08 * amount
		var w := _step() * 0.62 * s
		var hh := h * s
		var dark := Color(0.08, 0.06, 0.07, 0.85)
		var fill := dark.lerp(col, amount)
		if amount > 0.0 and amount < 1.0:
			fill = dark.lerp(col, 0.25 + amount * 0.35)
		_vertebra(c, w, hh, fill, Color(0, 0, 0, 0.9) if amount < 1.0 else col.lerp(Color.WHITE, 0.4 + glow * 0.4))
	for sh in _shards:
		var a: float = sh.life
		var pts := PackedVector2Array()
		for k in 3:
			pts.append(sh.p + Vector2(9, 0).rotated(sh.rot + TAU * k / 3.0) * (0.6 + k * 0.3))
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
