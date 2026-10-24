class_name BlessingIcon
extends Control
## A small drawn badge for a blessing family: a bolt, a flame, a snowflake or a bone.
## Synergies get a star behind the family badge.

var family := "bolt"
var color := Color.WHITE
var synergy := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(64, 64)
	size = Vector2(64, 64)


func show_for(u: Dictionary) -> void:
	family = u.family
	color = Upgrades.color(u)
	synergy = u.rarity == "synergy"
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
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
	var k := 0.72 if synergy else 1.0
	match family:
		"bolt": _bolt(c, k)
		"flame": _flame(c, k)
		"frost": _snowflake(c, k)
		"bone": _bone(c, k)


func _bolt(c: Vector2, k: float) -> void:
	# A crossbow bolt flying up and to the right.
	var a := c + Vector2(-13, 13) * k
	var b := c + Vector2(11, -11) * k
	draw_line(a, b, color, 4.0 * k)
	var tip := c + Vector2(17, -17) * k
	draw_colored_polygon(PackedVector2Array([tip, b + Vector2(-8, -1) * k, b + Vector2(1, 8) * k]), color)
	draw_line(a, a + Vector2(-6, -2) * k, color, 3.0 * k)
	draw_line(a, a + Vector2(2, 6) * k, color, 3.0 * k)


func _flame(c: Vector2, k: float) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		# A teardrop: round at the bottom, pulled to a point at the top.
		var p := Vector2(sin(t) * (1.0 - 0.55 * max(0.0, -cos(t))), cos(t))
		outer.append(c + Vector2(p.x * 13.0, p.y * 11.0 + 4.0 - max(0.0, -p.y) * 9.0) * k)
		inner.append(c + Vector2(p.x * 6.5, p.y * 6.0 + 8.0 - max(0.0, -p.y) * 4.0) * k)
	draw_colored_polygon(outer, color)
	draw_colored_polygon(inner, Color(1, 0.92, 0.5))


func _snowflake(c: Vector2, k: float) -> void:
	for i in 3:
		var d := Vector2.UP.rotated(PI / 3.0 * i) * 17.0 * k
		draw_line(c - d, c + d, color, 3.5 * k)
		for s in [-1.0, 1.0]:
			var tip: Vector2 = c + d * s
			var mid: Vector2 = c + d * s * 0.6
			draw_line(mid, mid + (tip - mid).rotated(0.8) * 0.9, color, 2.5 * k)
			draw_line(mid, mid + (tip - mid).rotated(-0.8) * 0.9, color, 2.5 * k)
	draw_circle(c, 3.5 * k, color)


func _bone(c: Vector2, k: float) -> void:
	var a := c + Vector2(-11, 11) * k
	var b := c + Vector2(11, -11) * k
	draw_line(a, b, color, 7.0 * k)
	var side := (b - a).normalized().orthogonal() * 4.5 * k
	for e: Vector2 in [a, b]:
		draw_circle(e + side, 5.0 * k, color)
		draw_circle(e - side, 5.0 * k, color)
