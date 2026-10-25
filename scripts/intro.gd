class_name Intro
extends CanvasLayer
## The opening animation when the game starts. Bone links fly in and lock into a ring, two
## eyes light up inside it, BONE CHAIN slams down in a burst of embers, then the words glide
## up onto the title screen's logo while everything else fades away. About three seconds,
## and a tap skips to the glide. The background is the purple of Android's own launch
## screen, so that runs straight into it.

signal handoff    # the glide to the title screen begins
signal finished

const BG := Color(0.094, 0.063, 0.149)
const BONE := Color(0.96, 0.93, 0.84)
const INK := Color(0.07, 0.04, 0.08)
const GOLD := Color(1, 0.85, 0.55)
const EMBER := Color(1.0, 0.55, 0.15)
const LINKS := 12
const RING_R := 140.0
const TAGLINE := "Dash. Chain. Descend."

# When each beat happens, in seconds.
const LINK_START := 0.15
const LINK_GAP := 0.04
const LINK_FLY := 0.28
const LOCK := 0.9
const EYES := 1.0
const SLAM := 1.25
const SLAM_LEN := 0.15
const TAG := 1.6
const HANDOFF := 2.3
const HANDOFF_LEN := 0.5

## The title screen's logo, which the words land on.
var logo: Label
var t := 0.0
var _canvas: Control
var _glow: GradientTexture2D
var _embers: Array = []   # {p, v, life, size}
var _shake := 0.0
var _flash := 0.0
var _ember_spawn := 0.0
var _handed := false
var _off := Vector2.ZERO   # this frame's shake


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.4, Color(1, 1, 1, 0.35))
	_glow = GradientTexture2D.new()
	_glow.gradient = g
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	_glow.width = 128
	_glow.height = 128
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_paint)
	add_child(_canvas)


## Jump to the glide onto the title screen.
func skip() -> void:
	t = maxf(t, HANDOFF)


func _input(event: InputEvent) -> void:
	# Nothing underneath gets a touch while the intro plays; a tap skips it.
	var press := (event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey) and event.is_pressed()
	if press:
		skip()
	if press or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var was := t
	t += minf(delta, 1.0 / 30.0)   # a slow first frame slows the intro instead of skipping part of it
	if t < HANDOFF:
		for i in LINKS:
			if _crossed(was, _link_time(i) + LINK_FLY):
				Sfx.play("click", 0.35)
		if _crossed(was, LOCK):
			Sfx.play("crack", 0.7)
		if _crossed(was, EYES):
			Sfx.play("ignite", 0.6)
		if _crossed(was, SLAM + SLAM_LEN):
			Sfx.play("slam")
			_shake = 14.0
			_flash = 0.3
			_burst()
	if t >= HANDOFF and not _handed:
		_handed = true
		handoff.emit()
	_shake = move_toward(_shake, 0.0, delta * 45.0)
	_flash = move_toward(_flash, 0.0, delta * 2.4)
	# Embers drift up once the words are down.
	if t > SLAM + SLAM_LEN and t < HANDOFF:
		_ember_spawn += delta * 22.0
		var vp := _canvas.size
		while _ember_spawn >= 1.0:
			_ember_spawn -= 1.0
			_embers.append({"p": Vector2(randf() * vp.x, vp.y + 10), "v": Vector2(randf_range(-20, 20), randf_range(-160, -70)),
				"life": randf_range(1.2, 2.4), "size": randf_range(1.5, 3.5)})
	for e in _embers:
		e.v *= 1.0 - minf(delta * 2.5, 0.5) if e.v.length() > 200.0 else 1.0
		e.v.y -= 40.0 * delta
		e.p += e.v * delta
		e.life -= delta
	_embers = _embers.filter(func(e): return e.life > 0.0)
	if logo:
		logo.modulate.a = _logo_swap()
	_canvas.queue_redraw()
	if t >= HANDOFF + HANDOFF_LEN:
		if logo:
			logo.modulate.a = 1.0
		finished.emit()
		queue_free()


func _crossed(was: float, at: float) -> bool:
	return was < at and t >= at


func _link_time(i: int) -> float:
	return LINK_START + i * LINK_GAP


## 0 to 1 over the glide to the title screen.
func _glide() -> float:
	return smoothstep(0.0, 1.0, clampf((t - HANDOFF) / HANDOFF_LEN, 0.0, 1.0))


## The title's own logo fades in over the last moment of the glide, as these words fade out.
func _logo_swap() -> float:
	return clampf((t - (HANDOFF + HANDOFF_LEN - 0.12)) / 0.12, 0.0, 1.0)


func _ring_center() -> Vector2:
	return _canvas.size * 0.5 + Vector2(0, -60)


func _words_center() -> Vector2:
	return _ring_center() + Vector2(0, RING_R + 64)


func _burst() -> void:
	var c := _words_center()
	var w := Hud.LOGO_FONT.get_string_size("BONE CHAIN", HORIZONTAL_ALIGNMENT_LEFT, -1, Hud.LOGO_SIZE).x * 1.12
	for i in 46:
		var p := c + Vector2(randf_range(-w * 0.5, w * 0.5), randf_range(-18, 18))
		var dir := (p - c + Vector2(0, randf_range(-30, 10))).normalized()
		_embers.append({"p": p, "v": dir * randf_range(180, 520) + Vector2(0, -80),
			"life": randf_range(0.5, 1.1), "size": randf_range(2.0, 4.5)})


func _paint() -> void:
	var vp := _canvas.size
	var glide := _glide()
	var fade := clampf(1.0 - glide * 2.5, 0.0, 1.0)   # the ring, eyes and words below go first
	_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(BG.r, BG.g, BG.b, 1.0 - glide))
	_off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_canvas.draw_set_transform(_off)
	var rc := _ring_center()
	# A warm glow wakes up behind the ring as it locks.
	var warm := clampf((t - LOCK) / 0.4, 0.0, 1.0) * 0.3 + clampf(1.0 - (t - SLAM - SLAM_LEN) / 0.5, 0.0, 1.0) * float(t > SLAM + SLAM_LEN) * 0.25
	if warm > 0.0:
		var r := RING_R * 2.1
		_canvas.draw_texture_rect(_glow, Rect2(rc - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.35, 0.1, warm * fade))
	_draw_ring(rc, fade)
	_draw_eyes(rc, fade)
	_draw_words(vp, glide)
	# The line under the logo.
	var tag_a := clampf((t - TAG) / 0.3, 0.0, 1.0) * fade
	if tag_a > 0.0:
		var f := ThemeDB.fallback_font
		var ts := 22
		var tw := f.get_string_size(TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
		var tp := _words_center() + Vector2(-tw * 0.5, 58)
		_canvas.draw_string_outline(f, tp, TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, 5, Color(0, 0, 0, 0.8 * tag_a))
		_canvas.draw_string(f, tp, TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(0.88, 0.84, 0.92, tag_a))
	for e in _embers:
		var a := clampf(e.life * 1.5, 0.0, 1.0) * (1.0 - glide)
		_canvas.draw_texture_rect(_glow, Rect2(e.p - Vector2(e.size, e.size) * 3.0, Vector2(e.size, e.size) * 6.0), false, Color(1.0, 0.45, 0.1, a * 0.5))
		_canvas.draw_circle(e.p, e.size * 0.6, Color(1.0, 0.85, 0.4, a), true, -1.0, true)
	_canvas.draw_set_transform(Vector2.ZERO)
	if _flash > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(1.0, 0.9, 0.75, _flash))


## Twelve links, ovals and bones in turn, each flying in on a curve and snapping into place.
func _draw_ring(rc: Vector2, fade: float) -> void:
	if fade <= 0.0:
		return
	var pulse := maxf(0.0, 1.0 - (t - LOCK) / 0.3) * float(t >= LOCK) + maxf(0.0, 1.0 - (t - SLAM - SLAM_LEN) / 0.35) * float(t >= SLAM + SLAM_LEN)
	var spin := maxf(t - LOCK, 0.0) * 0.12
	var radius := RING_R * (1.0 + 0.05 * pulse)
	var col := BONE.lerp(Color(1, 1, 0.92), clampf(pulse, 0.0, 1.0) * 0.7)
	# Rings first, then the bones over them with their knobbly ends hooked through the rings.
	for pass_ovals: bool in [true, false]:
		for i in LINKS:
			if (i % 2 == 0) != pass_ovals:
				continue
			var p := clampf((t - _link_time(i)) / LINK_FLY, 0.0, 1.0)
			if p <= 0.0:
				continue
			var e := _ease_out_back(p)
			var ang := -PI * 0.5 + TAU * i / LINKS + spin - (1.0 - e) * 1.6
			var pos := rc + Vector2(cos(ang), sin(ang)) * lerpf(RING_R * 4.5, radius, e)
			var rot := ang + PI * 0.5 + (1.0 - e) * 4.0
			var a := clampf(p * 3.0, 0.0, 1.0) * fade
			if pass_ovals:
				_oval(pos, rot, Color(col.r, col.g, col.b, a), a)
			else:
				_bone(pos, rot, Color(col.r, col.g, col.b, a), a)


func _oval(c: Vector2, rot: float, col: Color, a: float) -> void:
	var pts := PackedVector2Array()
	for k in 25:
		var q := TAU * k / 24.0
		pts.append(c + Vector2(cos(q) * 40.0, sin(q) * 22.0).rotated(rot))
	_canvas.draw_polyline(pts, Color(INK.r, INK.g, INK.b, a), 17.0, true)
	_canvas.draw_polyline(pts, col, 10.0, true)


func _bone(c: Vector2, rot: float, col: Color, a: float) -> void:
	var along := Vector2.RIGHT.rotated(rot)
	var across := along.orthogonal()
	var ends := [c - along * 46.0, c + along * 46.0]   # the knobs sit inside the ovals
	for layer_col: Color in [Color(INK.r, INK.g, INK.b, a), col]:
		var grow := 3.5 if layer_col == col else 6.5
		_canvas.draw_line(ends[0], ends[1], layer_col, 5.0 + grow * 2.0, true)
		for end: Vector2 in ends:
			for side: float in [-1.0, 1.0]:
				_canvas.draw_circle(end + across * side * 7.0, 4.5 + grow, layer_col, true, -1.0, true)


## Two angry eyes light up inside the ring, flickering as they catch.
func _draw_eyes(rc: Vector2, fade: float) -> void:
	var since := t - EYES
	if since < 0.0 or fade <= 0.0:
		return
	var on := clampf(since / 0.12, 0.0, 1.0)
	if since < 0.3:
		on *= 0.55 + 0.45 * signf(sin(since * 95.0))
	on *= (0.92 + 0.08 * sin(t * 13.0)) * fade
	for side: float in [-1.0, 1.0]:
		var c := rc + Vector2(side * 28.0, 4.0)
		var g := 48.0
		_canvas.draw_texture_rect(_glow, Rect2(c - Vector2(g, g), Vector2(g, g) * 2.0), false, Color(1.0, 0.65, 0.12, 0.6 * on))
		var tilt := 0.38 * -side
		var eye := PackedVector2Array()
		var core := PackedVector2Array()
		for k in 16:
			var q := TAU * k / 16.0
			eye.append(c + Vector2(cos(q) * 14.0, sin(q) * 7.5).rotated(tilt))
			core.append(c + Vector2(cos(q) * 7.0, sin(q) * 3.5).rotated(tilt))
		_canvas.draw_colored_polygon(eye, Color(1.0, 0.82, 0.3, on))
		eye.append(eye[0])
		_canvas.draw_polyline(eye, Color(1.0, 0.82, 0.3, on), 1.5, true)   # smooth edge
		_canvas.draw_colored_polygon(core, Color(1.0, 1.0, 0.85, on))


## BONE CHAIN: slams down from big, then glides up onto the title screen's logo.
func _draw_words(vp: Vector2, glide: float) -> void:
	var land := SLAM + SLAM_LEN
	var k := clampf((t - SLAM) / SLAM_LEN, 0.0, 1.0)
	var alpha := maxf(k, glide) * (1.0 - _logo_swap())
	if alpha <= 0.0:
		return
	var scale := lerpf(2.6, 1.12, k * k)
	if t > land:
		scale = 1.12 * (1.0 - 0.05 * exp(-(t - land) * 9.0) * cos((t - land) * 30.0))
	var centre := _words_center()
	if glide > 0.0 and logo:
		var r := logo.get_global_rect()
		centre = centre.lerp(r.get_center(), glide)
		scale = lerpf(1.12, 1.0, glide)
	var font := Hud.LOGO_FONT
	var size := Hud.LOGO_SIZE
	var w := font.get_string_size("BONE CHAIN", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var asc := font.get_ascent(size)
	var desc := font.get_descent(size)
	var hot := clampf(1.0 - (t - land) / 0.4, 0.0, 1.0) * float(t > land)
	var gw := w * 0.75 * scale
	_canvas.draw_texture_rect(_glow, Rect2(centre - Vector2(gw, 80 * scale), Vector2(gw, 80 * scale) * 2.0), false,
		Color(1.0, 0.4, 0.1, (0.35 + hot * 0.4) * alpha * (1.0 - glide)))
	# Drawn around the middle of the words, so they grow and shrink in place.
	_canvas.draw_set_transform(centre + _off, 0.0, Vector2(scale, scale))
	var at := Vector2(-w * 0.5, (asc - desc) * 0.5)
	_canvas.draw_string_outline(font, at, "BONE CHAIN", HORIZONTAL_ALIGNMENT_LEFT, -1, size, Hud.logo_outline(), Color(0, 0, 0, 0.85 * alpha))
	_canvas.draw_string(font, at, "BONE CHAIN", HORIZONTAL_ALIGNMENT_LEFT, -1, size, GOLD.lerp(Color(1, 1, 0.9), hot * 0.8) * Color(1, 1, 1, alpha))
	_canvas.draw_set_transform(_off)


static func _ease_out_back(x: float) -> float:
	var c1 := 1.70158
	return 1.0 + (c1 + 1.0) * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
