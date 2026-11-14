class_name DoorArch
extends Control
## One door on the CHOOSE YOUR DOOR screen (version 161): a stone archway of carved blocks
## round a doorway that glows with the door's own colour, light rising from beyond the
## threshold with motes drifting up through it, a keystone set with a gem of that colour,
## and a stone step at its foot. Drawn with plain polygons (no textures or shaders), so it
## costs next to nothing on a cheap phone; it only redraws while it is on screen.

var color := Color(0.6, 0.75, 1.0)
## 0..1: brighter while a thumb is on the door.
var press := 0.0
## 0..1: the doorway's light coming on as the screen opens (below 0 waits a moment first).
var lit := 1.0
var _press_to := 0.0
var _t := 0.0
var _seed := 0.0

const STONE := Color(0.29, 0.27, 0.34)
const MORTAR := Color(0.06, 0.05, 0.08)
const DARK := Color(0.025, 0.018, 0.04)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seed = randf() * 10.0


func set_pressed(on: bool) -> void:
	_press_to = 1.0 if on else 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	press = move_toward(press, _press_to, delta * 8.0)
	lit = minf(lit + delta * 1.8, 1.0)
	queue_redraw()


func _h(x: float) -> float:
	return fposmod(sin(x * 12.9898 + _seed * 3.7) * 43758.5453, 1.0)


## Geometry: the frame's thickness, the step's height, and the doorway's inner radius.
func _dims() -> Array:
	var w := size.x
	var t := w * 0.12
	var step := t * 0.75
	var ro := w * 0.5
	var ri := ro - t
	return [w, t, step, ro, ri]


## Left and right x of the doorway (inner) at height y.
func _inner_span(y: float, ri: float, cx: float, cy: float) -> Vector2:
	if y >= cy:
		return Vector2(cx - ri, cx + ri)
	var dy := cy - y
	var dx := sqrt(maxf(ri * ri - dy * dy, 0.0))
	return Vector2(cx - dx, cx + dx)


func _draw() -> void:
	var d := _dims()
	var w: float = d[0]
	var t: float = d[1]
	var step: float = d[2]
	var ro: float = d[3]
	var ri: float = d[4]
	var h := size.y
	var cx := w * 0.5
	var cy := ro + t * 0.35   # the arch's centre (room above for the keystone)
	var floor_y := h - step
	var on := smoothstep(0.0, 1.0, clampf(lit, 0.0, 1.0))
	var glow := (0.25 + 0.75 * on) * (1.0 + 0.35 * press)

	# The doorway: dark at the top, the door's colour rising from below, in horizontal strips.
	var top := cy - ri
	var strips := 28
	for k in strips:
		var y0 := lerpf(top, floor_y, float(k) / strips)
		var y1 := lerpf(top, floor_y, float(k + 1) / strips)
		var s0 := _inner_span(y0, ri, cx, cy)
		var s1 := _inner_span(y1, ri, cx, cy)
		var c0 := _fill((y0 - top) / (floor_y - top), glow)
		var c1 := _fill((y1 - top) / (floor_y - top), glow)
		draw_polygon(PackedVector2Array([Vector2(s0.x, y0), Vector2(s0.y, y0), Vector2(s1.y, y1), Vector2(s1.x, y1)]),
				PackedColorArray([c0, c0, c1, c1]))
	# Motes of light drifting up from the threshold.
	for m in 9:
		var life := fposmod(_t * (0.16 + 0.06 * _h(m + 1.0)) + _h(m + 7.0), 1.0)
		var y := lerpf(floor_y - 6.0, top + ri * 0.6, life)
		var span := _inner_span(y, ri, cx, cy)
		var x := lerpf(span.x + 8.0, span.y - 8.0, _h(m + 3.0)) + sin(_t * 1.3 + m) * 6.0
		var a := sin(life * PI) * 0.75 * glow
		draw_circle(Vector2(x, y), 2.0 + 1.6 * _h(m + 5.0), Color(color.lightened(0.4), a))
	# A soft line of light where the doorway meets the stone.
	var rim := PackedVector2Array()
	rim.append(Vector2(cx - ri, floor_y))
	for i in 25:
		var ang := PI + PI * i / 24.0
		rim.append(Vector2(cx + cos(ang) * ri, cy + sin(ang) * ri))
	rim.append(Vector2(cx + ri, floor_y))
	draw_polyline(rim, Color(color, 0.55 * glow), 3.0, true)

	# The stone frame: mortar first, then each block a little different.
	_ring(cx, cy, ri, ro, MORTAR, 0.0)
	draw_rect(Rect2(cx - ro, cy, t, floor_y - cy), MORTAR)
	draw_rect(Rect2(cx + ri, cy, t, floor_y - cy), MORTAR)
	var n := 9
	for i in n:
		if i == n / 2:
			continue   # the keystone, drawn last and bigger
		var a0 := PI + PI * i / n + 0.025
		var a1 := PI + PI * (i + 1) / n - 0.025
		_block_arc(cx, cy, ri + 2.0, ro - 2.0, a0, a1, _stone(i))
	# The jambs: courses of blocks down each side, long and short in turn.
	var course := t * 1.25
	var y := cy + 2.0
	var row := 0
	while y < floor_y - 4.0:
		var y2 := minf(y + course, floor_y) - 2.0
		for side in [-1, 1]:
			var x_out: float = cx + side * ro
			var x_in: float = cx + side * ri
			var inset := 2.0 if (row + (1 if side > 0 else 0)) % 2 == 0 else 5.0
			var r := Rect2(minf(x_out, x_in) + 2.0, y, t - 2.0 - inset * 0.3, y2 - y)
			_block_rect(r, _stone(20 + row * 2 + (1 if side > 0 else 0)), side)
		y += course
		row += 1
	# The keystone, with a gem of the door's colour.
	var ka0 := PI * 1.5 - PI / n * 0.62
	var ka1 := PI * 1.5 + PI / n * 0.62
	_block_arc(cx, cy, ri - 3.0, ro + t * 0.35, ka0, ka1, STONE.lightened(0.12))
	var gem := Vector2(cx, cy - (ri + ro + t * 0.35) * 0.5)
	draw_circle(gem, t * 0.32, MORTAR)
	draw_circle(gem, t * 0.25, color.darkened(0.25))
	draw_circle(gem + Vector2(-t * 0.07, -t * 0.08), t * 0.09, Color(1, 1, 1, 0.6))
	draw_circle(gem, t * 0.55, Color(color, 0.12 * glow))
	# The step: a stone slab a little wider than the arch, lit from the doorway.
	var slab := Rect2(cx - ro - 6.0, floor_y, w + 12.0, step)
	draw_rect(slab, MORTAR)
	draw_rect(slab.grow(-2.0), STONE.darkened(0.15))
	draw_rect(Rect2(cx - ri, floor_y + 2.0, ri * 2.0, step * 0.4), Color(color, 0.28 * glow))


func _fill(f: float, glow: float) -> Color:
	var c := DARK.lerp(color.darkened(0.35), pow(clampf(f, 0.0, 1.0), 1.8) * 0.75 * glow)
	return c.lerp(color.lightened(0.2), pow(clampf(f, 0.0, 1.0), 6.0) * 0.35 * glow)


func _stone(i: int) -> Color:
	var v := 0.86 + 0.24 * _h(i * 1.7 + 0.3)
	var c := Color(STONE.r * v, STONE.g * v, STONE.b * v)
	return c.lerp(color, 0.08)


func _ring(cx: float, cy: float, r0: float, r1: float, c: Color, _x: float) -> void:
	_block_arc(cx, cy, r0, r1, PI, TAU, c, false)


## A carved block between radii r0 and r1, angles a0 to a1: the face, a lit inner edge
## (the doorway's light) and a dark outer edge.
func _block_arc(cx: float, cy: float, r0: float, r1: float, a0: float, a1: float, c: Color, edges := true) -> void:
	var pts := PackedVector2Array()
	var segs := 6
	for i in segs + 1:
		var a := lerpf(a0, a1, float(i) / segs)
		pts.append(Vector2(cx + cos(a) * r1, cy + sin(a) * r1))
	for i in range(segs, -1, -1):
		var a := lerpf(a0, a1, float(i) / segs)
		pts.append(Vector2(cx + cos(a) * r0, cy + sin(a) * r0))
	draw_colored_polygon(pts, c)
	if not edges:
		return
	var inner := PackedVector2Array()
	var outer := PackedVector2Array()
	for i in segs + 1:
		var a := lerpf(a0, a1, float(i) / segs)
		inner.append(Vector2(cx + cos(a) * (r0 + 1.5), cy + sin(a) * (r0 + 1.5)))
		outer.append(Vector2(cx + cos(a) * (r1 - 1.5), cy + sin(a) * (r1 - 1.5)))
	draw_polyline(inner, Color(color.lightened(0.3), 0.35), 2.0, true)
	draw_polyline(outer, Color(0, 0, 0, 0.35), 2.0, true)


func _block_rect(r: Rect2, c: Color, side: int) -> void:
	draw_rect(r, c)
	# The edge facing the doorway catches its light; the outer edge is in shadow.
	var lit_x := r.position.x if side > 0 else r.end.x - 2.0
	var dark_x := r.end.x - 2.0 if side > 0 else r.position.x
	draw_rect(Rect2(lit_x, r.position.y, 2.0, r.size.y), Color(color.lightened(0.3), 0.35))
	draw_rect(Rect2(dark_x, r.position.y, 2.0, r.size.y), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2.0), Color(1, 1, 1, 0.06))
