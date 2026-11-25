class_name EventArt
## Pictures for the big events (events.gd, version 134; Frostfall's ice from version 243,
## pal()), all drawn in code. For the Blood Moon: the Moon
## Shard (the event's own currency, on the HUD and the event screen), the big blood moon at
## the top of the event screen (black with a red corona in the Eclipse chapter), and the
## "+3" that pops out of a skeleton when it pays shards.

const CRIMSON := Color(1.0, 0.24, 0.2)
const SHARD := Color(1.0, 0.32, 0.36)
const SHARD_LIGHT := Color(1.0, 0.72, 0.7)
const SHARD_DARK := Color(0.42, 0.03, 0.08)
## Version 243: each event's own colours (pal()): the Blood Moon's crimson, Frostfall's ice.
const BLOOD_PAL := {"main": CRIMSON, "shard": SHARD, "light": SHARD_LIGHT, "dark": SHARD_DARK,
	"glow": Color(1.0, 0.12, 0.08), "hot": Color(1.0, 0.35, 0.2), "bg": Color(0.22, 0.02, 0.05),
	"edge": Color(0.75, 0.12, 0.12), "shadow": Color(1.0, 0.1, 0.05), "track": Color(0.22, 0.14, 0.17),
	"node": Color(0.5, 0.1, 0.1), "ink": Color(0.3, 0.0, 0.03), "words": Color(1.0, 0.72, 0.62),
	"menu": "blood"}
const FROST_PAL := {"main": Color(0.35, 0.75, 1.0), "shard": Color(0.55, 0.86, 1.0), "light": Color(0.88, 0.97, 1.0),
	"dark": Color(0.03, 0.1, 0.25), "glow": Color(0.3, 0.65, 1.0), "hot": Color(0.65, 0.92, 1.0),
	"bg": Color(0.03, 0.08, 0.2), "edge": Color(0.3, 0.6, 0.95), "shadow": Color(0.25, 0.6, 1.0),
	"track": Color(0.13, 0.17, 0.26), "node": Color(0.12, 0.3, 0.55), "ink": Color(0.0, 0.06, 0.18),
	"words": Color(0.75, 0.9, 1.0), "menu": "frost"}


static func pal(e: Dictionary = {}) -> Dictionary:
	return FROST_PAL if Events.frost(e) else BLOOD_PAL


static func c(key: String) -> Color:
	return pal()[key]


## "+n" in crimson, rising from `at` (a skeleton that paid shards), with a few red glints.
static func shard_pop(at: Vector3, n: int) -> void:
	var world := Game.world
	if world == null or n <= 0:
		return
	var l := Label3D.new()
	l.text = "+%d" % n
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.pixel_size = 0.009
	l.font = Hud.UI_FONT
	l.font_size = 64
	l.outline_size = 14
	l.modulate = c("light")
	l.outline_modulate = c("dark")
	l.render_priority = 3
	l.outline_render_priority = 2
	world.add_child(l)
	l.global_position = at + Vector3(-0.5, 0, 0)
	l.scale = Vector3.ONE * 0.4
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position:y", at.y + 1.1, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.6)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.35).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)
	Fx.sparks(at, c("shard"))


## One Moon Shard: a long crimson crystal with a lit face and a dark one, `h` tall, centred
## on `c`. `glow` (0-1) adds a soft halo behind it.
static func draw_shard(ci: CanvasItem, c: Vector2, h: float, glow := 0.0) -> void:
	if Events.frost():
		draw_flake(ci, c, h, glow)
		return
	var w := h * 0.48
	if glow > 0.0:
		for i in 4:
			var r := h * (0.45 + 0.16 * i)
			ci.draw_circle(c, r, Color(SHARD.r, SHARD.g, SHARD.b, 0.07 * glow))
	var top := c + Vector2(0, -h * 0.5)
	var bottom := c + Vector2(0, h * 0.5)
	var left := c + Vector2(-w * 0.5, -h * 0.08)
	var right := c + Vector2(w * 0.5, -h * 0.08)
	var mid := c + Vector2(w * 0.06, -h * 0.04)
	var edge := maxf(2.0, h * 0.09)
	var outline := PackedVector2Array([top, right, bottom, left, top])
	ci.draw_polyline(outline, Color(0.08, 0.0, 0.03), edge, true)
	ci.draw_colored_polygon(PackedVector2Array([top, mid, bottom, left]), SHARD.lightened(0.15))
	ci.draw_colored_polygon(PackedVector2Array([top, right, bottom, mid]), SHARD.darkened(0.35))
	ci.draw_colored_polygon(PackedVector2Array([top, mid, left]), SHARD_LIGHT)
	# A glint on the lit face.
	ci.draw_line(top.lerp(left, 0.35) + Vector2(w * 0.08, 0), top.lerp(left, 0.35) + Vector2(w * 0.08, h * 0.22),
		Color(1, 1, 1, 0.8), maxf(1.5, h * 0.05), true)


## Version 243, Frostfall's currency: a Snowflake, six ice arms with branches on a dark
## edge, `h` tall, centred on `c`.
static func draw_flake(ci: CanvasItem, c: Vector2, h: float, glow := 0.0) -> void:
	var r := h * 0.5
	var ice: Color = FROST_PAL.shard
	if glow > 0.0:
		for i in 4:
			ci.draw_circle(c, r * (0.9 + 0.3 * i), Color(ice.r, ice.g, ice.b, 0.07 * glow))
	var ink := Color(0.02, 0.06, 0.16)
	for pass_i in 2:
		var w := maxf(2.0, h * (0.17 if pass_i == 0 else 0.09))
		var col: Color = ink if pass_i == 0 else FROST_PAL.light
		for i in 6:
			var d := Vector2.from_angle(-PI / 2.0 + TAU * i / 6.0)
			ci.draw_line(c, c + d * r, col, w, true)
			for k in [0.5, 0.75]:
				var p: Vector2 = c + d * r * k
				var len: float = r * (0.3 if k < 0.6 else 0.2)
				ci.draw_line(p, p + d.rotated(0.8) * len, col, w * 0.85, true)
				ci.draw_line(p, p + d.rotated(-0.8) * len, col, w * 0.85, true)
	ci.draw_circle(c, h * 0.12, ink)
	ci.draw_circle(c, h * 0.08, FROST_PAL.light)


## Version 222: a piece of the event set on the road bar and the road's track: a five-point
## star, gold with a dark edge once `lit` (found or reached), dark with a gold edge before.
static func draw_star(ci: CanvasItem, c: Vector2, r: float, lit: bool, alpha := 1.0) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI / 2 + i * PI / 5
		pts.append(c + Vector2(cos(ang), sin(ang)) * r * (1.0 if i % 2 == 0 else 0.46))
	var edge := pts.duplicate()
	edge.append(pts[0])
	ci.draw_colored_polygon(pts, Color(1.0, 0.78, 0.3, alpha) if lit else Color(0.16, 0.1, 0.06, alpha))
	ci.draw_polyline(edge, Color(0.3, 0.14, 0.02, alpha) if lit else Color(0.85, 0.62, 0.28, alpha), maxf(1.5, r * 0.16), true)


## The Moon Shard as a small Control (for rows of text).
class ShardIcon extends Control:
	var glow := 0.0

	func _init(size_px := 28.0) -> void:
		custom_minimum_size = Vector2(size_px * 0.7, size_px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		EventArt.draw_shard(self, size * 0.5, size.y * 0.92, glow)


## The big blood moon: a red disc with a hot rim, dark seas, a slow pulse and a wide glow.
## In the Eclipse chapter it turns black with a burning red corona.
class Moon extends Control:
	var eclipse := false
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.34
		var pulse := 0.5 + 0.5 * sin(_t * 1.6)
		if Events.frost():
			_draw_frost(c, r, pulse)
			return
		# The glow, widest and faintest first.
		for i in 7:
			var k := float(7 - i) / 7.0
			draw_circle(c, r * (1.0 + 0.55 * k + 0.05 * pulse), Color(1.0, 0.12, 0.08, (0.05 + 0.02 * pulse) * (1.0 - k * 0.5)))
		if eclipse:
			# The corona: a ring of red fire around a black disc, flickering.
			for i in 36:
				var a := TAU * i / 36.0 + _t * 0.15
				var len := r * (0.18 + 0.1 * sin(_t * 3.0 + i * 1.7) + 0.06 * sin(i * 2.3))
				draw_line(c + Vector2.from_angle(a) * r * 0.98, c + Vector2.from_angle(a) * (r + len),
					Color(1.0, 0.35, 0.2, 0.55), maxf(2.0, r * 0.05), true)
			draw_circle(c, r * 1.04, Color(1.0, 0.4, 0.25, 0.95))
			draw_circle(c, r, Color(0.03, 0.0, 0.01))
			draw_arc(c, r * 0.97, -2.4, -0.9, 24, Color(0.4, 0.05, 0.05, 0.6), maxf(2.0, r * 0.05), true)
			return
		draw_circle(c, r, Color(0.62, 0.05, 0.05))
		# Lit from the upper left: lighter there, deep red to the lower right.
		draw_circle(c + Vector2(-r, -r) * 0.12, r * 0.86, Color(0.82, 0.1, 0.07))
		draw_circle(c + Vector2(-r, -r) * 0.22, r * 0.6, Color(0.95, 0.2, 0.1))
		draw_circle(c + Vector2(-r, -r) * 0.3, r * 0.32, Color(1.0, 0.36, 0.2, 0.8))
		# Seas and craters.
		for s: Vector3 in [Vector3(0.3, -0.2, 0.22), Vector3(-0.35, 0.3, 0.16), Vector3(0.1, 0.42, 0.12),
				Vector3(-0.1, -0.45, 0.09), Vector3(0.5, 0.25, 0.1), Vector3(-0.5, -0.1, 0.07)]:
			draw_circle(c + Vector2(s.x, s.y) * r, s.z * r, Color(0.35, 0.02, 0.03, 0.55))
			draw_arc(c + Vector2(s.x, s.y) * r, s.z * r, 3.6, 5.4, 10, Color(1.0, 0.45, 0.3, 0.35), maxf(1.0, r * 0.02), true)
		# A hot rim.
		draw_arc(c, r, 0.0, TAU, 64, Color(1.0, 0.5 + 0.15 * pulse, 0.3, 0.9), maxf(2.0, r * 0.045), true)

	## Version 243, Frostfall: a pale winter moon behind a great turning snowflake, under
	## bands of green and blue northern lights. In WHITEOUT, the last chapter, the storm
	## swallows the moon: only the snowflake shows through whirling snow.
	func _draw_frost(c: Vector2, r: float, pulse: float) -> void:
		for i in 7:
			var k := float(7 - i) / 7.0
			draw_circle(c, r * (1.0 + 0.6 * k + 0.05 * pulse), Color(0.35, 0.7, 1.0, (0.05 + 0.02 * pulse) * (1.0 - k * 0.5)))
		# Northern lights: wavy ribbons across the top.
		for band in 3:
			var pts := PackedVector2Array()
			var cols := PackedColorArray()
			var base := c.y - r * (0.95 - band * 0.28)
			for i in 25:
				var x := c.x - r * 1.6 + r * 3.2 * i / 24.0
				var y := base + sin(i * 0.5 + _t * 0.9 + band * 1.7) * r * 0.12
				pts.append(Vector2(x, y))
			var hue: Color = [Color(0.3, 1.0, 0.6), Color(0.3, 0.8, 1.0), Color(0.6, 0.5, 1.0)][band]
			draw_polyline(pts, Color(hue.r, hue.g, hue.b, 0.16 + 0.06 * pulse), r * 0.16, true)
			draw_polyline(pts, Color(hue.r, hue.g, hue.b, 0.3), r * 0.05, true)
		if not eclipse:
			draw_circle(c, r, Color(0.62, 0.74, 0.9))
			draw_circle(c + Vector2(-r, -r) * 0.12, r * 0.86, Color(0.75, 0.85, 0.97))
			draw_circle(c + Vector2(-r, -r) * 0.22, r * 0.55, Color(0.88, 0.94, 1.0))
			for s: Vector3 in [Vector3(0.3, -0.2, 0.2), Vector3(-0.35, 0.3, 0.15), Vector3(0.12, 0.44, 0.11), Vector3(0.5, 0.22, 0.09)]:
				draw_circle(c + Vector2(s.x, s.y) * r, s.z * r, Color(0.5, 0.62, 0.8, 0.45))
			draw_arc(c, r, 0.0, TAU, 64, Color(0.85, 0.95, 1.0, 0.9), maxf(2.0, r * 0.04), true)
		else:
			# The storm: streaks of snow whirling round where the moon was.
			draw_circle(c, r * 1.05, Color(0.1, 0.16, 0.28, 0.85))
			for i in 30:
				var a := TAU * i / 30.0 + _t * 0.8
				var rr := r * (0.35 + 0.7 * fmod(i * 0.37, 1.0))
				draw_arc(c, rr, a, a + 0.5, 8, Color(0.85, 0.93, 1.0, 0.35), maxf(1.5, r * 0.025), true)
		var flake := Transform2D(_t * 0.15, c)
		draw_set_transform_matrix(flake)
		EventArt.draw_flake(self, Vector2.ZERO, r * 1.45, 0.6 + 0.4 * pulse)
		draw_set_transform_matrix(Transform2D.IDENTITY)


## The event road bar: shards so far and how far to the next prize, crimson and gold.
## Version 222: on a near-black bar (it was dark red on the red wall), with a star on it for
## each piece of the set: gold once found.
class RoadBar extends Button:
	var frac := 0.0
	var waiting := 0
	## [where on the bar (0-1), found] for each piece of the set.
	var marks: Array = []
	var _text: Label

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		flat = true
		_text = Hud.label("", 19, Color.WHITE)
		Hud.chunky(_text.label_settings)
		Hud.full(_text)
		_text.offset_left = 30
		_text.offset_bottom = -5
		add_child(_text)
		Hud.squash(self)

	func set_road(shards: int, next_at: int, f: float, ready_n: int) -> void:
		frac = f
		waiting = ready_n
		if ready_n > 0:
			_text.text = "EVENT ROAD: CLAIM %d!" % ready_n if ready_n > 1 else "EVENT ROAD: CLAIM!"
		elif next_at > 0:
			_text.text = "EVENT ROAD  %s / %s" % [Hud.thousands(shards), Hud.thousands(next_at)]
		else:
			_text.text = "EVENT ROAD: DONE!"
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 4.0) if waiting > 0 else 0.0
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.07, 0.04, 0.06)
		# A prize waiting: a pulsing gold edge (version 222: the bar no longer fills with gold,
		# so PLAY stays the one big gold thing on the screen).
		bg.border_color = Hud.ROLES.gold[0].lerp(Hud.ROLES.gold[1], 0.6 * (1.0 - pulse)) if waiting > 0 else Color(0.3, 0.16, 0.18)
		bg.set_border_width_all(3)
		bg.border_width_bottom = 8
		bg.set_corner_radius_all(18)
		bg.shadow_color = Color(1.0, 0.7, 0.2, 0.15 + 0.25 * pulse) if waiting > 0 else Color(0, 0, 0, 0.35)
		bg.shadow_size = 8 if waiting > 0 else 2
		bg.shadow_offset = Vector2(0, 2 if waiting > 0 else 4)
		draw_style_box(bg, r)
		var inner := Rect2(4, 4, r.size.x - 8.0, r.size.y - 13.0)
		var w := inner.size.x * frac
		if w > 8.0:
			var fill := StyleBoxFlat.new()
			fill.bg_color = EventArt.c("main")
			fill.set_corner_radius_all(14)
			draw_style_box(fill, Rect2(inner.position, Vector2(w, inner.size.y)))
			var shine := StyleBoxFlat.new()
			shine.bg_color = Color(1, 1, 1, 0.18)
			shine.set_corner_radius_all(10)
			draw_style_box(shine, Rect2(inner.position + Vector2(4, 3), Vector2(maxf(w - 8.0, 0.0), inner.size.y * 0.38)))
		# The set's pieces, on the bar's lower edge (under the words).
		for m: Array in marks:
			var x := clampf(inner.position.x + inner.size.x * float(m[0]), inner.position.x + 12.0, inner.end.x - 10.0)
			EventArt.draw_star(self, Vector2(x, r.size.y - 9.0), 10.0, bool(m[1]))
		EventArt.draw_shard(self, Vector2(26, r.size.y * 0.5 - 3.0), r.size.y * 0.62)

	func _process(_d: float) -> void:
		if waiting > 0 and is_visible_in_tree():
			queue_redraw()


## The title screen's event banner: the moon, the event's name and what's on, glowing.
class Banner extends Button:
	var _moon: Moon
	var _name: Label
	var _sub: Label
	var _badge: Label
	var _t := 0.0
	var hot := false
	var _slim := false

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		flat = true
		custom_minimum_size = Vector2(440, 84)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_moon = Moon.new()
		_moon.position = Vector2(-6, -12)
		_moon.size = Vector2(104, 104)
		add_child(_moon)
		_name = Hud.label(str(Events.ev().name), 30, Color(1.0, 0.86, 0.8) if not Events.frost() else Color(0.9, 0.97, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
		_name.label_settings.outline_color = EventArt.c("ink")
		_name.position = Vector2(96, 6)
		_name.size = Vector2(330, 40)
		_name.autowrap_mode = TextServer.AUTOWRAP_OFF
		add_child(_name)
		_sub = Hud.label("", 17, Color(1.0, 0.8, 0.62) if not Events.frost() else Color(0.78, 0.9, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
		_sub.position = Vector2(98, 42)
		_sub.size = Vector2(330, 28)
		_sub.autowrap_mode = TextServer.AUTOWRAP_OFF
		add_child(_sub)
		_badge = Hud.label("", 15, Color.WHITE)
		_badge.autowrap_mode = TextServer.AUTOWRAP_OFF
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.95, 0.62, 0.1)
		sb.border_color = Color(0.4, 0.18, 0.0)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		_badge.add_theme_stylebox_override("normal", sb)
		_badge.position = Vector2(330, -14)
		add_child(_badge)
		Hud.squash(self)

	## Version 342 (visual review fix 6): the title's thin strip above the logo, so the event
	## no longer sits on the hero's head as a big card.
	func slim() -> void:
		_slim = true
		custom_minimum_size = Vector2(400, 54)
		_moon.position = Vector2(-4, -6)
		_moon.size = Vector2(66, 66)
		_name.label_settings.font_size = 22
		_name.position = Vector2(66, 1)
		_name.size = Vector2(300, 28)
		_sub.label_settings.font_size = 16
		_sub.position = Vector2(67, 26)
		_sub.size = Vector2(300, 22)
		_badge.label_settings.font_size = 13
		_badge.position = Vector2(300, -12)

	## `sub`: the line under the name ("Ends in 6d 4h"); `badge`: a gold tag ("CLAIM!", "2X").
	func set_info(title: String, sub: String, badge: String, eclipse: bool) -> void:
		_name.text = title
		_sub.text = sub
		_badge.text = badge
		_badge.visible = badge != ""
		_moon.eclipse = eclipse
		hot = badge != ""
		_badge.reset_size()
		_badge.position.x = size.x - _badge.size.x + 6.0 if size.x > 0.0 else (300.0 if _slim else 330.0)

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2(0, 0), size)
		var glow := 0.5 + 0.5 * sin(_t * 2.4)
		var sb := StyleBoxFlat.new()
		var p := EventArt.pal()
		sb.bg_color = Color(p.bg.r, p.bg.g, p.bg.b, 0.96)
		sb.border_color = (p.hot as Color).lerp(Color.WHITE, 0.25 * glow) if hot else p.edge
		sb.set_border_width_all(2 if _slim else 3)
		sb.border_width_bottom = 4 if _slim else 7
		sb.set_corner_radius_all(14 if _slim else 20)
		sb.shadow_color = Color(p.shadow.r, p.shadow.g, p.shadow.b, 0.25 + 0.2 * glow)
		sb.shadow_size = 6 if _slim else 10
		draw_style_box(sb, r)
		# A gold line along the top, like the event's marble.
		var x0 := 60.0 if _slim else 84.0
		draw_line(Vector2(x0, 5 if _slim else 7), Vector2(r.size.x - 18, 5 if _slim else 7), Color(1.0, 0.78, 0.4, 0.45), 2.0, true)


## Version 135: the big moment when an event (or a new chapter of it) begins, shown once on
## the title: the screen goes dark, the moon rises out of the bottom with rays turning behind
## it and embers drifting up, then the words land one after another, with a sting.
## Like the takeover splash a big mobile game shows when its season starts.
class Splash extends ColorRect:
	signal enter
	signal later
	signal hunt   # v218: straight into the Queen Hunt

	var _rays: Rays
	var _moon: Moon
	var _kicker: Label
	var _title: Label
	var _line: Label
	var _story: Label
	var _clock: Label
	var _go: Button
	var _skip: Button
	var _embers: CPUParticles2D
	var _col: VBoxContainer
	var _tw: Tween

	func _init() -> void:
		color = Color(0.02, 0.0, 0.01, 0.97) if not Events.frost() else Color(0.0, 0.01, 0.03, 0.97)
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		visible = false
		Hud.backdrop(self, str(EventArt.pal().menu))
		_rays = Rays.new()
		add_child(_rays)
		_moon = Moon.new()
		add_child(_moon)
		_embers = CPUParticles2D.new()
		_embers.amount = 40
		_embers.lifetime = 4.0
		_embers.preprocess = 2.0
		_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_embers.direction = Vector2.UP
		_embers.spread = 18.0
		_embers.gravity = Vector2(0, -20)
		_embers.initial_velocity_min = 30.0
		_embers.initial_velocity_max = 80.0
		_embers.scale_amount_min = 2.0
		_embers.scale_amount_max = 5.0
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.55, 0.3, 0.0))
		g.add_point(0.2, Color(1.0, 0.4, 0.25, 0.9))
		g.set_color(g.get_point_count() - 1, Color(0.8, 0.05, 0.05, 0.0))
		if Events.frost():
			# Frostfall: snow drifting down instead of embers rising.
			g = Gradient.new()
			g.set_color(0, Color(0.9, 0.96, 1.0, 0.0))
			g.add_point(0.15, Color(0.92, 0.97, 1.0, 0.9))
			g.set_color(g.get_point_count() - 1, Color(0.7, 0.85, 1.0, 0.0))
			_embers.direction = Vector2(0.3, 1.0)
			_embers.gravity = Vector2(10, 25)
			_embers.amount = 70
		_embers.color_ramp = g
		add_child(_embers)
		_col = VBoxContainer.new()
		_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_col.alignment = BoxContainer.ALIGNMENT_CENTER
		_col.add_theme_constant_override("separation", 10)
		add_child(_col)
		_kicker = Hud.label("", 22, Color(1.0, 0.8, 0.42))
		_col.add_child(_kicker)
		_title = Hud.label("", 66, Color(1.0, 0.9, 0.84))
		_title.label_settings.outline_color = EventArt.c("ink")
		_title.label_settings.outline_size = 14
		_title.label_settings.shadow_color = Color(EventArt.c("shadow"), 0.7)
		_title.label_settings.shadow_size = 18
		_col.add_child(_title)
		_line = Hud.label("", 21, EventArt.c("words"))
		_col.add_child(_line)
		_story = Hud.label("", 17, Color(0.86, 0.78, 0.82))
		_col.add_child(_story)
		_clock = Hud.label("", 18, Color(1.0, 0.8, 0.42))
		_col.add_child(_clock)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 10)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_col.add_child(gap)
		_go = Hud.button("ENTER THE EVENT", 28)
		Hud.paint(_go, "blue" if Events.frost() else "red")
		_go.custom_minimum_size = Vector2(380, 84)
		_go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_go.pressed.connect(func(): enter.emit())
		_col.add_child(_go)
		# Version 218 (review 4): the quick fight right here, not two screens in.
		var hunt_btn := Hud.button(("HUNT %s  ·  1-2 MIN" % Events.word("foe")).to_upper(), 22)
		Hud.paint(hunt_btn, "gold")
		hunt_btn.custom_minimum_size = Vector2(340, 70)
		hunt_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hunt_btn.pressed.connect(func(): hunt.emit())
		_col.add_child(hunt_btn)
		_skip = Hud.button("LATER", 20)
		Hud.paint(_skip, "slate")
		_skip.custom_minimum_size = Vector2(200, 64)
		_skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_skip.pressed.connect(func(): later.emit())
		_col.add_child(_skip)
		resized.connect(_layout)

	func _layout() -> void:
		var safe := Hud.safe_margins(get_viewport())
		var top := 40.0 + safe.y
		var bottom := 30.0 + safe.w
		var m := minf(size.x * 0.82, size.y * 0.36)
		_moon.size = Vector2(m, m)
		_moon.pivot_offset = _moon.size * 0.5
		_rays.size = Vector2(size.x, size.x) * 1.4
		_rays.pivot_offset = _rays.size * 0.5
		_embers.position = Vector2(size.x * 0.5, size.y + 10)
		_embers.emission_rect_extents = Vector2(size.x * 0.5, 4)
		_col.position = Vector2(20, top + m * 0.82)
		_col.size = Vector2(size.x - 40, size.y - top - m * 0.82 - bottom)
		for l: Label in [_kicker, _title, _line, _story, _clock]:
			l.custom_minimum_size.x = size.x - 60
		_moon_rest = Vector2((size.x - m) * 0.5, top)

	var _moon_rest := Vector2.ZERO

	## `kicker` small gold words over the title; `title` the big name; `line` and `story`
	## under it; `clock` the countdown; `eclipse` the black moon of the last chapter.
	func play(kicker: String, title: String, line: String, story: String, clock: String, eclipse: bool) -> void:
		_kicker.text = kicker
		_title.text = title
		_line.text = line
		_story.text = story
		_story.visible = story != ""
		_clock.text = clock
		_moon.eclipse = eclipse
		visible = true
		_layout()
		if _tw:
			_tw.kill()
		_tw = create_tween().set_ignore_time_scale(true)
		_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		# The moon rises from below the screen and grows a little as it settles.
		_moon.position = Vector2(_moon_rest.x, size.y + 20)
		_moon.scale = Vector2.ONE * 0.7
		_rays.modulate.a = 0.0
		_rays.position = _moon_rest + _moon.size * 0.5 - _rays.size * 0.5
		self_modulate.a = 0.0
		for c: Control in [_kicker, _title, _line, _story, _clock, _go, _skip]:
			c.modulate.a = 0.0
		_title.pivot_offset = Vector2(_title.custom_minimum_size.x * 0.5, 40)
		_title.scale = Vector2.ONE * 1.6
		# About a second and a half in all, and a tap finishes it at once.
		_tw.set_parallel(true)
		_tw.tween_property(self, "self_modulate:a", 1.0, 0.25)
		_tw.tween_property(_moon, "position", _moon_rest, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tw.tween_property(_moon, "scale", Vector2.ONE, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.tween_property(_rays, "modulate:a", 1.0, 0.8).set_delay(0.3)
		_tw.tween_callback(func(): Sfx.play("roar", 0.5, 0.6)).set_delay(0.2)
		_tw.tween_property(_kicker, "modulate:a", 1.0, 0.2).set_delay(0.6)
		_tw.tween_callback(func(): Sfx.play("sting", 0.9)).set_delay(0.75)
		_tw.tween_property(_title, "modulate:a", 1.0, 0.15).set_delay(0.75)
		_tw.tween_property(_title, "scale", Vector2.ONE, 0.3).set_delay(0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.tween_callback(func(): Game.buzz(40)).set_delay(0.85)
		var at := 1.0
		for c: Control in [_line, _story, _clock, _go, _skip]:
			_tw.tween_property(c, "modulate:a", 1.0, 0.2).set_delay(at)
			at += 0.12

	## A tap while it plays shows it all at once (the buttons included).
	func _gui_input(event: InputEvent) -> void:
		if _tw and _tw.is_running() and (event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed():
			_tw.custom_step(10.0)
			accept_event()

	func _process(delta: float) -> void:
		if visible:
			_rays.rotation += delta * 0.12


## Soft rays turning slowly behind the rising moon (the splash).
class Rays extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5
		for i in 14:
			var a := TAU * i / 14.0
			var w := 0.09
			var pts := PackedVector2Array([c, c + Vector2.from_angle(a - w) * r, c + Vector2.from_angle(a + w) * r])
			var h: Color = EventArt.c("hot")
			var cols := PackedColorArray([Color(h, 0.22), Color(h, 0.0), Color(h, 0.0)])
			draw_polygon(pts, cols)


## Version 143 (review change 2): a small picture for each Event Road prize, so the road
## reads at a glance: a crimson Moon Casket, a stack of coins, a bone Bone Drop, a green
## Lucky Start clover and a gold star for a piece of the Blood Moon set.
class RoadIcon extends Control:
	var kind := "coins"
	var dim := false

	func _init(k: String, size_px := 48.0, faded := false) -> void:
		kind = k
		dim = faded
		custom_minimum_size = Vector2(size_px, size_px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		var a := 0.45 if dim else 1.0
		draw_circle(c, r, Color(0.05, 0.01, 0.02, 0.85 * a) if not Events.frost() else Color(0.01, 0.03, 0.08, 0.85 * a))
		match kind:
			"casket":
				# (Frostfall's Frost Gift: a blue-white present with a gold ribbon.)
				var fr := Events.frost()
				var body := Rect2(c + Vector2(-r * 0.62, -r * 0.18), Vector2(r * 1.24, r * 0.78))
				draw_rect(body, Color(0.62, 0.08, 0.1, a) if not fr else Color(0.25, 0.55, 0.9, a))
				draw_rect(Rect2(c + Vector2(-r * 0.66, -r * 0.5), Vector2(r * 1.32, r * 0.36)), Color(0.85, 0.16, 0.16, a) if not fr else Color(0.75, 0.9, 1.0, a))
				draw_rect(Rect2(c + Vector2(-r * 0.1, -r * 0.5), Vector2(r * 0.2, r * 1.1)), Color(1.0, 0.78, 0.4, a))
				draw_circle(c + Vector2(0, -r * 0.05), r * 0.13, Color(1.0, 0.9, 0.6, a))
			"coins":
				for i in 3:
					var o := c + Vector2(0, r * (0.32 - i * 0.24))
					draw_circle(o, r * 0.5, Color(0.55, 0.36, 0.06, a))
					draw_circle(o + Vector2(0, -r * 0.06), r * 0.46, Color(1.0, 0.8, 0.28, a))
				draw_circle(c + Vector2(-r * 0.12, -r * 0.3), r * 0.1, Color(1.0, 0.97, 0.8, a))
			"drop":
				var box := Rect2(c + Vector2(-r * 0.6, -r * 0.3), Vector2(r * 1.2, r * 0.78))
				draw_rect(box, Color(0.86, 0.8, 0.66, a))
				draw_rect(Rect2(c + Vector2(-r * 0.64, -r * 0.56), Vector2(r * 1.28, r * 0.3)), Color(0.95, 0.9, 0.78, a))
				for x in [-0.32, 0.0, 0.32]:
					draw_line(c + Vector2(r * x, -r * 0.2), c + Vector2(r * x, r * 0.42), Color(0.5, 0.42, 0.3, a), 2.0)
				draw_circle(c + Vector2(0, -r * 0.4), r * 0.12, Color(0.7, 0.4, 1.0, a))
			"lucky":
				for d in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
					draw_circle(c + d * r * 0.3, r * 0.3, Color(0.35, 0.85, 0.4, a))
				draw_circle(c, r * 0.16, Color(0.85, 1.0, 0.7, a))
			"look":
				var pts := PackedVector2Array()
				for i in 10:
					var ang := -PI / 2 + i * PI / 5
					var rr := r * (0.78 if i % 2 == 0 else 0.34)
					pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
				draw_colored_polygon(pts, Color(1.0, 0.78, 0.3, a))
				draw_circle(c, r * 0.18, Color(EventArt.c("main"), a))
		draw_arc(c, r - 1.5, 0, TAU, 40, Color(1.0, 0.78, 0.4, 0.55 * a), 2.0, true)


## Version 222 (design critique fix 1 and 4): one piece of the event set, as a picture: its
## swatch from the Looks screen in a round frame. Gold with a tick once found, a pulsing gold
## ring when it is reached and waiting on the road, dim before that. `tint` is the frame's
## colour (silver for the Crypt Pass's Silver Moon set).
class SetBadge extends Control:
	var found := false
	var waiting := false
	var tint := Color(1.0, 0.78, 0.3)
	var _sw: Control
	var _tick: Control
	var _t := 0.0

	func _init(size_px := 64.0) -> void:
		custom_minimum_size = Vector2(size_px, size_px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tick = Control.new()
		_tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tick.draw.connect(_draw_tick)
		add_child(_tick)
		resized.connect(func():
			if _sw:
				_sw.position = Vector2(5, 5)
				_sw.size = size - Vector2(10, 10)
			_tick.position = Vector2.ZERO
			_tick.size = size
			_tick.queue_redraw())

	## The look `slot`/`key` as hero `id` wears it (`base` = Heroes.get_hero(id)).
	func setup(id: String, slot: String, key: String, base: Dictionary, got: bool, ready_now: bool) -> void:
		found = got
		waiting = ready_now and not got
		if _sw:
			_sw.queue_free()
		var sw := StyleScreen.Swatch.new()
		sw.setup(id, slot, key, base)
		sw.position = Vector2(5, 5)
		sw.size = size - Vector2(10, 10) if size.x > 10.0 else custom_minimum_size - Vector2(10, 10)
		sw.modulate = Color.WHITE if got or waiting else Color(1, 1, 1, 0.72)
		_sw = sw
		add_child(sw)
		move_child(_tick, -1)
		set_process(waiting)
		queue_redraw()
		_tick.queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		if waiting:
			var p := 0.5 + 0.5 * sin(_t * 4.0)
			draw_circle(c, r + 3.0 + 3.0 * p, Color(tint.r, tint.g, tint.b, 0.18 + 0.12 * p))
		draw_circle(c, r, Color(0.05, 0.03, 0.045, 0.95))
		var ring := tint if found or waiting else tint.darkened(0.55)
		draw_arc(c, r - 1.5, 0, TAU, 48, ring, 3.0 if found or waiting else 2.0, true)

	func _draw_tick() -> void:
		if not found:
			return
		var r := minf(size.x, size.y) * 0.17
		var c := Vector2(size.x - r * 0.9, size.y - r * 0.9)
		_tick.draw_circle(c, r, tint)
		_tick.draw_arc(c, r, 0, TAU, 24, Color(0.25, 0.12, 0.0), 2.0, true)
		_tick.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.5, 0), c + Vector2(-r * 0.12, r * 0.4), c + Vector2(r * 0.52, -r * 0.42)]),
			Color(0.2, 0.08, 0.0), maxf(2.0, r * 0.3), true)


## Version 222 (design critique fix 4): the event road as a track. Its rows sit in `list`;
## a line runs down the left past every step, crimson as far as the shards reach, with a node
## for each step (a big star for a piece of the set, a tick once claimed) and a glowing shard
## where you are. The Crypt Pass's rows branch off it in silver.
class RoadTrack extends MarginContainer:
	const X := 30.0
	const INDENT := 26.0
	var list: VBoxContainer
	## One per road step: {row, at, state ("got", "ready" or "next"), look}.
	var stops: Array = []
	## One per Crypt Pass row: {row, state}.
	var branches: Array = []
	var shards := 0
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_theme_constant_override("margin_left", 62)
		add_theme_constant_override("margin_right", 6)
		add_theme_constant_override("margin_top", 14)
		add_theme_constant_override("margin_bottom", 14)
		list = VBoxContainer.new()
		list.mouse_filter = Control.MOUSE_FILTER_IGNORE
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 10)
		add_child(list)
		list.sort_children.connect(queue_redraw)

	func clear() -> void:
		for c in list.get_children():
			list.remove_child(c)
			c.queue_free()
		stops.clear()
		branches.clear()

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_t += delta
			queue_redraw()

	func _y(row: Control) -> float:
		return list.position.y + row.position.y + row.size.y * 0.5

	## Where you are on the track: between the last step reached and the next, as far as
	## the shards go.
	func _you_y() -> float:
		var first: Dictionary = stops[0]
		if shards <= int(first.at):
			return lerpf(list.position.y, _y(first.row), clampf(float(shards) / float(first.at), 0.0, 1.0))
		for i in range(stops.size() - 1):
			var a: Dictionary = stops[i]
			var b: Dictionary = stops[i + 1]
			if shards < int(b.at):
				return lerpf(_y(a.row), _y(b.row), float(shards - int(a.at)) / float(int(b.at) - int(a.at)))
		return _y(stops[stops.size() - 1].row)

	func _draw() -> void:
		if stops.is_empty():
			return
		var top := list.position.y
		var bottom := _y(stops[stops.size() - 1].row)
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		# The bare track, then the part walked, in crimson.
		draw_line(Vector2(X, top), Vector2(X, bottom), Color(0.03, 0.015, 0.025), 12.0, true)
		draw_line(Vector2(X, top), Vector2(X, bottom), EventArt.c("track"), 6.0, true)
		var you := _you_y()
		if you > top + 1.0:
			draw_line(Vector2(X, top), Vector2(X, you), Color(EventArt.c("main"), 0.25), 16.0, true)
			draw_line(Vector2(X, top), Vector2(X, you), EventArt.c("main"), 7.0, true)
		# The Crypt Pass's rows: a silver branch from the track.
		for b: Dictionary in branches:
			var y := _y(b.row)
			var a := 0.5 if str(b.state) == "got" else 1.0
			var silver := Color(0.75, 0.84, 1.0, a)
			draw_line(Vector2(X, y), Vector2(get_theme_constant("margin_left") + INDENT, y), silver.darkened(0.25), 3.0, true)
			draw_circle(Vector2(X, y), 7.0, silver)
			draw_arc(Vector2(X, y), 7.0, 0, TAU, 20, Color(0.1, 0.12, 0.2, a), 2.0, true)
		# A node for each step.
		for s: Dictionary in stops:
			var c := Vector2(X, _y(s.row))
			var st := str(s.state)
			if bool(s.look):
				if st == "ready":
					draw_circle(c, 24.0 + 4.0 * pulse, Color(1.0, 0.75, 0.3, 0.2 + 0.15 * pulse))
				EventArt.draw_star(self, c, 21.0, st != "next", 0.6 if st == "got" else 1.0)
				if st == "got":
					_tick(c + Vector2(10, 10), 7.0, 0.8)
				continue
			match st:
				"got":
					draw_circle(c, 10.0, EventArt.c("node"))
					_tick(c, 10.0, 0.75)
				"ready":
					draw_circle(c, 15.0 + 3.0 * pulse, Color(1.0, 0.75, 0.3, 0.22 + 0.15 * pulse))
					draw_circle(c, 12.0, Hud.ROLES.gold[0])
					draw_arc(c, 12.0, 0, TAU, 24, Hud.ROLES.gold[1], 2.5, true)
				_:
					draw_circle(c, 9.0, Color(0.1, 0.06, 0.08))
					draw_arc(c, 9.0, 0, TAU, 24, Color(0.45, 0.33, 0.36), 2.0, true)
		# You: a glowing shard on the track, with YOU over it.
		var yc := Vector2(X, you)
		for i in 3:
			draw_circle(yc, 18.0 + 6.0 * i + 3.0 * pulse, Color(EventArt.c("main"), 0.12 - 0.03 * i))
		draw_circle(yc, 17.0, EventArt.c("dark").darkened(0.5))
		draw_arc(yc, 17.0, 0, TAU, 32, EventArt.c("light"), 2.5, true)
		EventArt.draw_shard(self, yc, 24.0)
		var font := Hud.UI_FONT
		var w := font.get_string_size("YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var pill := Rect2(yc + Vector2(-w * 0.5 - 6.0, -42.0), Vector2(w + 12.0, 20.0))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.84, 0.5)
		sb.set_corner_radius_all(8)
		sb.border_color = Color(0.35, 0.12, 0.02)
		sb.set_border_width_all(2)
		draw_style_box(sb, pill)
		draw_string(font, Vector2(pill.position.x + 6.0, pill.position.y + 16.0), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.3, 0.06, 0.02))

	## A small tick in a dark ring (a claimed step).
	func _tick(c: Vector2, r: float, a: float) -> void:
		draw_polyline(PackedVector2Array([c + Vector2(-r * 0.45, 0), c + Vector2(-r * 0.1, r * 0.38), c + Vector2(r * 0.5, -r * 0.4)]),
			Color(1.0, 0.85, 0.75, a), maxf(2.0, r * 0.28), true)
