class_name LeaderScreen
extends ColorRect
## The leaderboard screen (version 137): today's Daily Crypt or this week's best runs, for
## everyone or for the player's Play Games friends. Scores come from Leaders (Google Play
## Games); SEE ALL opens Google's own leaderboard page.

signal closed

var _key := "daily"
var _collection := Leaders.EVERYONE
var _tag := 0
var _tab_daily: Button
var _tab_best: Button
var _tab_all: Button
var _tab_friends: Button
var _sub: Label
var _list: VBoxContainer
var _you: Control
var _status: Label
var _act: Button
var _see_all: Button
var _panel: PanelContainer
var _waiting := 0


func _init() -> void:
	color = Color(0.03, 0.02, 0.05, 0.97)
	Hud.backdrop(self, "gold")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 22
	col.offset_right = -22
	col.offset_top = Hud.FRAME_TOP
	col.offset_bottom = -Hud.FRAME_BOTTOM
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	col.add_child(Hud.label("LEADERBOARD", 44, Hud.GOLD))
	var boards := _row(col)
	_tab_daily = _tab(boards, "DAILY CRYPT", func(): _pick("daily", _collection))
	_tab_best = _tab(boards, "BEST RUN", func(): _pick("best", _collection))
	_sub = Hud.label("", 17, Color(0.78, 0.76, 0.84))
	col.add_child(_sub)
	var who := _row(col)
	_tab_all = _tab(who, "EVERYONE", func(): _pick(_key, Leaders.EVERYONE), 20)
	_tab_friends = _tab(who, "FRIENDS", func(): _pick(_key, Leaders.FRIENDS), 20)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.11, 0.95)
	sb.border_color = Color(Hud.GOLD, 0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	col.add_child(panel)
	_panel = panel
	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)
	_list = VBoxContainer.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_theme_constant_override("separation", 2)
	inner.add_child(_list)
	_you = VBoxContainer.new()
	_you.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_you)
	_status = Hud.label("", 18, Color(0.85, 0.82, 0.9))
	col.add_child(_status)
	_act = Hud.button("SIGN IN", 24, Color(0.05, 0.24, 0.12, 0.97), Color(0.5, 1.0, 0.65))
	_act.custom_minimum_size = Vector2(320, 74)
	_act.pressed.connect(_on_act)
	col.add_child(_center(_act))
	_see_all = Hud.button("SEE ALL ON GOOGLE PLAY", 18)
	_see_all.custom_minimum_size = Vector2(320, 60)
	_see_all.pressed.connect(func():
		Sfx.play("click")
		Leaders.instance.show_board(_key, _span(), _collection))
	col.add_child(_center(_see_all))
	var back := Hud.button("BACK", 26)
	back.pressed.connect(close)
	add_child(Hud.back_corner(back))
	visibility_changed.connect(func():
		if visible:
			Hud.safe_pad(col))


func _row(parent: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_theme_constant_override("separation", 10)
	parent.add_child(r)
	return r


func _tab(parent: Control, text: String, on: Callable, size := 22) -> Button:
	var b := Hud.button(text, size)
	b.custom_minimum_size = Vector2(220, 62)
	b.pressed.connect(func():
		Sfx.play("click")
		on.call())
	parent.add_child(b)
	return b


func _center(c: Control) -> Control:
	var box := CenterContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(c)
	return box


func _span() -> int:
	return Leaders.SPAN_DAILY if _key == "daily" else Leaders.SPAN_WEEKLY


## Opens on `key` ("daily" or "best").
func open(key := "daily") -> void:
	visible = true
	var l := Leaders.instance
	if not l.changed.is_connected(_refresh):
		l.changed.connect(_refresh)
		l.scores.connect(_on_scores)
		l.friends.connect(_on_friends)
	_pick(key, Leaders.EVERYONE)


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func _pick(key: String, collection: int) -> void:
	_key = key
	_collection = collection
	for t: Array in [[_tab_daily, key == "daily"], [_tab_best, key == "best"],
			[_tab_all, collection == Leaders.EVERYONE], [_tab_friends, collection == Leaders.FRIENDS]]:
		(t[0] as Button).modulate = Color.WHITE if t[1] else Color(0.55, 0.53, 0.6)
	_sub.text = "Today's Daily Crypt: everyone plays the same crypt" if key == "daily" \
			else "Your best normal run this week"
	_refresh()


func _refresh() -> void:
	if not visible:
		return
	_clear()
	var l := Leaders.instance
	_see_all.visible = false
	if not l.signed_in:
		_status.text = "Sign in to Google Play Games\nto put your score on the board."
		_act.text = "SIGN IN"
		_act.visible = true
		return
	_act.visible = false
	_status.text = "Loading..."
	_tag += 1
	_waiting = 2
	l.load_scores("top%d" % _tag, _key, _span(), _collection, false, 10)
	l.load_scores("me%d" % _tag, _key, _span(), _collection, true, 1)


func _clear() -> void:
	for c in _list.get_children():
		c.free()
	for c in _you.get_children():
		c.free()
	_panel.visible = false   # no empty box while signing in or loading


var _top: Array = []
var _me: Array = []

func _on_scores(tag: String, list: Array, error: String) -> void:
	if not visible or not tag.ends_with(str(_tag)):
		return
	if error == "friends":
		_clear()
		_status.text = "Let Bone Chain see your Play Games friends\nto race them."
		_act.text = "SHARE FRIENDS"
		_act.visible = true
		return
	if tag.begins_with("top"):
		_top = list
	else:
		_me = list
	_waiting -= 1
	if _waiting > 0:
		return
	if error != "" and _top.is_empty():
		_status.text = "Couldn't reach Google Play. Check your connection."
		return
	_show(_top, _me)


func _show(top: Array, me: Array) -> void:
	_clear()
	_see_all.visible = not Leaders.instance.fake
	_panel.visible = not top.is_empty() or not me.is_empty()
	var mine_shown := false
	for r: Dictionary in top:
		_list.add_child(_line(r))
		mine_shown = mine_shown or bool(r.get("me", false))
	if not mine_shown and not me.is_empty():
		var gap := Hud.label("...", 16, Color(0.6, 0.58, 0.66))
		_you.add_child(gap)
		_you.add_child(_line(me[0]))
	if top.is_empty():
		_status.text = ("None of your Play Games friends has a score here yet." if _collection == Leaders.FRIENDS
				else "No scores yet. Be the first!")
	elif me.is_empty():
		_status.text = "Play a Daily Crypt official run to get on today's board." if _key == "daily" \
				else "Finish a run to get on this week's board."
	else:
		_status.text = ""


func _line(r: Dictionary) -> Control:
	var me := bool(r.get("me", false))
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.45, 0.3, 0.06, 0.85) if me else Color(1, 1, 1, 0.03)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	var rank := int(r.get("rank", 0))
	var rank_col: Color = [Color(1, 0.82, 0.3), Color(0.85, 0.88, 0.95), Color(0.9, 0.6, 0.35)][rank - 1] if rank >= 1 and rank <= 3 \
			else Color(0.7, 0.68, 0.76)
	var rl := Hud.label("#%d" % rank, 20, rank_col, HORIZONTAL_ALIGNMENT_LEFT)
	rl.custom_minimum_size = Vector2(62, 0)
	rl.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(rl)
	var nl := Hud.label(str(r.get("name", "?")) + ("  (you)" if me else ""), 20,
			Color.WHITE if me else Color(0.9, 0.88, 0.94), HORIZONTAL_ALIGNMENT_LEFT)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.autowrap_mode = TextServer.AUTOWRAP_OFF
	nl.clip_text = true
	h.add_child(nl)
	var sl := Hud.label(Hud.thousands(int(r.get("score", 0))), 20, Hud.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	sl.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(sl)
	return row


func _on_act() -> void:
	Sfx.play("click")
	if _act.text == "SHARE FRIENDS":
		Leaders.instance.ask_friends()
	else:
		_status.text = "Signing in..."
		Leaders.instance.sign_in()


func _on_friends(state: int) -> void:
	if not visible or state == 2:
		return
	if state == 1:
		_refresh()
	else:
		_status.text = "Friends stay hidden. The Everyone tab still works."
