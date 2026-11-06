class_name MasteryBar
extends HBoxContainer
## A hero's Hero Mastery (hero_mastery.gd): a rank badge with the level in it, the hero's
## name, and a bar to the next level with what that level gives.
##
## On the end screen (play) the bar fills with the points the run earned; each level reached
## on the way pops the badge, plays a chime and names its rewards in gold underneath. On the
## Heroes screen (set_points) it just shows where the hero is, and can be tapped.

signal tapped

const TEXT := Color(0.88, 0.87, 0.92)
const DIM := Color(0.62, 0.6, 0.68)
## How long the bar takes to fill on the end screen, and how long it waits first (the score
## counts up meanwhile).
const FILL_TIME := 1.3
const WAIT := 0.45

var _id := ""
var _color := Color.WHITE
var _badge: Badge
var _name: Label
var _gain: Label
var _bar: Fill
var _sub: Label
var _news: Label
## Animation: points shown now, from and to.
var _from := 0
var _to := 0
var _t := -1.0
var _shown_level := 1
var _lines: Array[String] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 14)
	var row := self
	_badge = Badge.new()
	_badge.custom_minimum_size = Vector2(66, 72)
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_badge)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	_name = Hud.label("", 19, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_name)
	_gain = Hud.label("", 19, Hud.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	_gain.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(_gain)
	_bar = Fill.new()
	_bar.custom_minimum_size = Vector2(0, 16)
	col.add_child(_bar)
	_sub = Hud.label("", 15, DIM, HORIZONTAL_ALIGNMENT_LEFT)
	_sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_sub.clip_text = true
	_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_sub)
	_news = Hud.label("", 17, Hud.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	_news.visible = false
	col.add_child(_news)
	set_process(false)


## The end screen: `info` from Game._bank_mastery ({id, name, color, before, after, gained,
## levels}); the bar fills from `before` to `after`.
func play(info: Dictionary) -> void:
	_setup(str(info.id), str(info.name), info.color)
	_from = int(info.before)
	_to = int(info.after)
	_gain.text = "+%d" % int(info.gained) if int(info.gained) > 0 else ""
	_gain.label_settings.font_size = 19
	_lines.clear()
	_news.visible = false
	_show(_from)
	_shown_level = HeroMastery.level_for(_from)
	_t = -WAIT if _to > _from else -1.0
	set_process(_to > _from)


## The Heroes screen: where hero `id` stands now. `header` replaces "<HERO> MASTERY" over the
## bar; a tappable bar says so on the right.
func set_points(id: String, hero_name: String, col: Color, p: int, header := "") -> void:
	_setup(id, hero_name, col)
	if header != "":
		_name.text = header
	_gain.text = "LEVELS  >" if mouse_filter == Control.MOUSE_FILTER_STOP else ""
	_gain.label_settings.font_size = 15 if _gain.text != "" else 19
	_news.visible = false
	_t = -1.0
	set_process(false)
	_show(p)
	_shown_level = HeroMastery.level_for(p)


func _setup(id: String, hero_name: String, col: Color) -> void:
	_id = id
	_color = col
	_name.text = "%s MASTERY" % hero_name.to_upper()
	_bar.color = col


func _show(p: int) -> void:
	var pr := HeroMastery.progress(p)
	var lv: int = pr.level
	var rank := HeroMastery.rank(lv)
	_badge.set_level(lv, rank.color, lv >= HeroMastery.MAX_LEVEL)
	_bar.frac = pr.frac
	_bar.gold = lv >= HeroMastery.MAX_LEVEL
	_bar.queue_redraw()
	if lv >= HeroMastery.MAX_LEVEL:
		_sub.text = "%s  ·  Every reward earned" % rank.name.to_upper()
	else:
		_sub.text = "%d / %d  ·  Level %d: %s" % [pr.into, pr.need, lv + 1, HeroMastery.level_text(lv + 1, _id)]


func _process(delta: float) -> void:
	if _t < 0.0:
		_t += delta
		if _t < 0.0:
			return
		_t = 0.0
	_t = minf(1.0, _t + delta / FILL_TIME)
	var p := roundi(lerpf(_from, _to, ease(_t, 0.45)))
	_show(p)
	var lv := HeroMastery.level_for(p)
	while _shown_level < lv:
		_shown_level += 1
		_level_up(_shown_level)
	if _t >= 1.0:
		set_process(false)


func _level_up(lv: int) -> void:
	_badge.pop()
	Sfx.play("upgrade", 0.8, 1.0 + 0.04 * lv)
	if lv >= HeroMastery.MAX_LEVEL:
		Sfx.play("victory", 0.6)
	_lines.append("LEVEL %d!  %s" % [lv, HeroMastery.level_text(lv, _id)])
	# Two lines at most: a run that climbs three levels says so in the first.
	var shown := _lines.slice(-2)
	if _lines.size() > 2:
		shown[0] = "+%d levels  ·  %s" % [_lines.size() - 1, shown[0]]
	_news.text = "\n".join(shown)
	_news.visible = true
	_news.pivot_offset = Vector2(0, _news.size.y * 0.5)
	_news.scale = Vector2(1.12, 1.12)
	create_tween().tween_property(_news, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		tapped.emit()
		accept_event()


## Makes it a button (the Heroes screen): taps open the Mastery screen.
func make_tappable() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


## The rank badge: a six-sided shield in Bronze, Silver, Gold or Master gold, with the level.
class Badge extends Control:
	var level := 1
	var color := Color.WHITE
	var master := false
	## A green tick in the corner (earned levels on the Mastery screen).
	var tick := false
	var _num: Label
	var _pop := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_num = Hud.label("1", 28, Color.WHITE)
		_num.autowrap_mode = TextServer.AUTOWRAP_OFF
		Hud.full(_num)
		add_child(_num)
		set_process(false)

	func set_level(lv: int, col: Color, is_master: bool) -> void:
		var changed := lv != level or col != color or is_master != master
		level = lv
		color = col
		master = is_master
		_num.text = str(lv)
		_num.label_settings.font_size = 26 if lv >= 10 else 30
		_num.label_settings.outline_color = col.darkened(0.75)
		set_process(master or _pop > 0.0)
		if changed:
			queue_redraw()

	func pop() -> void:
		_pop = 1.0
		set_process(true)

	func _process(delta: float) -> void:
		_pop = maxf(0.0, _pop - delta * 3.0)
		pivot_offset = size * 0.5
		var s := 1.0 + 0.28 * _pop * _pop
		scale = Vector2(s, s)
		queue_redraw()
		if _pop <= 0.0 and not master:
			set_process(false)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		if master or _pop > 0.0:
			# Soft rays behind the shield, turning slowly.
			var t := Time.get_ticks_msec() / 1000.0
			var glow := Color(color, 0.18 + 0.25 * _pop)
			for i in 8:
				var a := t * 0.5 + i * TAU / 8.0
				var d := Vector2(cos(a), sin(a))
				var side := Vector2(-d.y, d.x) * r * 0.16
				draw_colored_polygon(PackedVector2Array([c + side, c - side, c + d * r * 1.25]), glow)
		var pts := _shield(c, r)
		draw_colored_polygon(pts, color.darkened(0.55))
		draw_colored_polygon(_shield(c, r * 0.78), color.darkened(0.25))
		# A lighter top half, like light falling on metal.
		var top := _shield(c + Vector2(0, -r * 0.08), r * 0.66)
		var half := PackedVector2Array()
		for p in top:
			half.append(Vector2(p.x, minf(p.y, c.y)))
		draw_colored_polygon(half, Color(color.lightened(0.25), 0.55))
		var line := pts.duplicate()
		line.append(pts[0])
		draw_polyline(line, color.lightened(0.35), 3.0, true)
		if _pop > 0.0:
			draw_circle(c, r * (1.0 + 0.5 * (1.0 - _pop)), Color(1, 1, 1, 0.35 * _pop), false, 3.0, true)
		if tick:
			var k := c + Vector2(r * 0.72, r * 0.62)
			var kr := r * 0.36
			draw_circle(k, kr, Color(0.2, 0.62, 0.3))
			draw_circle(k, kr, Color(0.75, 1.0, 0.8), false, 2.0, true)
			draw_polyline(PackedVector2Array([k + Vector2(-kr * 0.5, 0), k + Vector2(-kr * 0.1, kr * 0.4), k + Vector2(kr * 0.55, -kr * 0.42)]), Color.WHITE, 3.0, true)

	## A six-sided shield, pointed at the bottom.
	static func _shield(c: Vector2, r: float) -> PackedVector2Array:
		return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.86, -r * 0.55), c + Vector2(r * 0.86, r * 0.3),
			c + Vector2(0, r), c + Vector2(-r * 0.86, r * 0.3), c + Vector2(-r * 0.86, -r * 0.55)])


## The progress bar, in the hero's color (gold at Master).
class Fill extends Control:
	var frac := 0.0
	var color := Color.WHITE
	var gold := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.6)
		bg.border_color = Color(1, 1, 1, 0.12)
		bg.set_border_width_all(1)
		bg.set_corner_radius_all(8)
		draw_style_box(bg, r)
		var w := (size.x - 4.0) * clampf(frac, 0.0, 1.0)
		if w < 3.0:
			return
		var fill := StyleBoxFlat.new()
		fill.bg_color = Hud.GOLD if gold else color
		fill.set_corner_radius_all(6)
		draw_style_box(fill, Rect2(2, 2, w, size.y - 4))
		# A bright line along the top of the fill.
		var shine := StyleBoxFlat.new()
		shine.bg_color = Color(1, 1, 1, 0.3)
		shine.set_corner_radius_all(3)
		draw_style_box(shine, Rect2(4, 3, maxf(0.0, w - 4.0), (size.y - 6) * 0.35))
