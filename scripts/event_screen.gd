class_name EventScreen
extends ColorRect
## The event screen (events.gd, version 134): the Blood Moon's own lobby. The big moon with
## the chapter and countdown on top, then the Blood Moon run, the five Queen Hunt tiers,
## the event road, the Moon Caskets waiting and the three chapters. Its second page is the
## event road, every step with its prize and a CLAIM button.

signal run_pressed
signal hunt_pressed(tier: int)
signal claim(index: int)
signal caskets_pressed
signal closed

const CRIMSON := Color(1.0, 0.3, 0.26)
const GOLD := Color(1.0, 0.8, 0.42)
const TEXT := Color(0.92, 0.86, 0.88)
const DIM := Color(0.62, 0.55, 0.6)
const DONE := Color(0.45, 0.85, 0.5)

var _main: Control
var _road_page: Control
var _moon: EventArt.Moon
var _title: Label
var _chapter: Label
var _clock: Label
var _double: Label
var _story: Label
var _shard_count: Label
var _road_bar: EventArt.RoadBar
var _road_sub: Label
var _run_btn: Button
var _run_sub: Label
var _tiers: VBoxContainer
var _caskets: Button
var _chapters: VBoxContainer
var _scroll: ScrollContainer
var _road_count: Label
var _road_note: Label
var _road_scroll: ScrollContainer
var _road_list: VBoxContainer
var _t := 0.0


func _init() -> void:
	color = Color(0.04, 0.01, 0.02, 0.98)
	Hud.backdrop(self, "blood")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_main()
	_build_road()


func _page(parent: Control) -> VBoxContainer:
	var col := VBoxContainer.new()
	Hud.full(col)
	col.offset_left = 16
	col.offset_right = -16
	col.offset_top = 14
	col.offset_bottom = -112
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	parent.add_child(col)
	visibility_changed.connect(func(): if visible: Hud.safe_pad(col))
	return col


func _build_main() -> void:
	_main = Control.new()
	_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Hud.full(_main)
	add_child(_main)
	var outer := _page(_main)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	_scroll.add_child(col)
	# The moon, with the event's name across it.
	var head := Control.new()
	head.custom_minimum_size = Vector2(0, 250)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	_moon = EventArt.Moon.new()
	_moon.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_moon.offset_top = 0
	_moon.offset_bottom = 200
	head.add_child(_moon)
	_title = Hud.label("BLOOD MOON", 58, Color(1.0, 0.9, 0.84))
	_title.label_settings.outline_color = Color(0.3, 0.0, 0.03)
	_title.label_settings.shadow_color = Color(1.0, 0.1, 0.05, 0.6)
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 120
	_title.offset_bottom = 196
	head.add_child(_title)
	_chapter = Hud.label("", 22, GOLD)
	_chapter.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_chapter.offset_top = -46
	_chapter.offset_bottom = -12
	head.add_child(_chapter)
	_clock = Hud.label("", 19, TEXT)
	col.add_child(_clock)
	_double = Hud.label("DOUBLE MOON SHARDS TODAY!", 22, Color(1.0, 0.85, 0.3))
	col.add_child(_double)
	_story = Hud.label("", 16, Color(0.85, 0.76, 0.8))
	col.add_child(_story)
	# Shards and the event road.
	var shards_row := HBoxContainer.new()
	shards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	shards_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shards_row.add_theme_constant_override("separation", 8)
	shards_row.add_child(EventArt.ShardIcon.new(34.0))
	_shard_count = Hud.label("", 28, Color(1.0, 0.8, 0.78))
	_shard_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	shards_row.add_child(_shard_count)
	col.add_child(shards_row)
	_road_bar = EventArt.RoadBar.new()
	_road_bar.custom_minimum_size = Vector2(440, 66)
	_road_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_road_bar.pressed.connect(func():
		Sfx.play("click")
		show_road())
	col.add_child(_road_bar)
	_road_sub = Hud.label("", 16, DIM)
	col.add_child(_road_sub)
	# The Blood Moon run.
	var run := _card(col, "BLOOD MOON RUN", "Three floors of the Blood Moon Crypt. Moon Surges make every skeleton faster and worth a shard. Bloodbats, Moon Howlers, and the Queen at the end.")
	_run_sub = Hud.label("", 16, GOLD)
	run.add_child(_run_sub)
	_run_btn = Hud.button("PLAY THE BLOOD MOON", 24, Color(0.45, 0.16, 0.12, 0.97), Color(1, 0.75, 0.4))
	Hud.paint(_run_btn, "red")
	_run_btn.custom_minimum_size = Vector2(380, 76)
	_run_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_run_btn.pressed.connect(func(): _confirm(_run_btn, run_pressed.emit))
	run.add_child(_run_btn)
	# The Queen Hunt.
	var hunt := _card(col, "QUEEN HUNT", "Straight to the Blood Moon Queen, with blessings to start. Every tier pays again each day, and the day's first win holds a Moon Casket.")
	_tiers = VBoxContainer.new()
	_tiers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tiers.add_theme_constant_override("separation", 6)
	hunt.add_child(_tiers)
	# Moon Caskets.
	_caskets = Hud.button("MOON CASKETS", 24, Color(0.3, 0.2, 0.06, 0.97), Hud.GOLD)
	_caskets.custom_minimum_size = Vector2(420, 74)
	_caskets.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_caskets.pressed.connect(func(): caskets_pressed.emit())
	col.add_child(_caskets)
	# The chapters.
	var ch := _card(col, "CHAPTERS", "")
	_chapters = VBoxContainer.new()
	_chapters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chapters.add_theme_constant_override("separation", 6)
	ch.add_child(_chapters)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 8)
	col.add_child(pad)
	var back := Hud.button("BACK", 26)
	back.pressed.connect(func():
		visible = false
		closed.emit())
	_main.add_child(Hud.back_corner(back))


## A dark crimson card with a heading and a line of text; returns its column.
func _card(parent: Control, heading: String, text: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.02, 0.05, 0.93)
	sb.border_color = Color(0.62, 0.1, 0.12)
	sb.set_border_width_all(2)
	sb.border_width_top = 4
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(Hud.label(heading, 28, CRIMSON.lightened(0.2)))
	if text != "":
		v.add_child(Hud.label(text, 16, TEXT))
	return v


func _build_road() -> void:
	_road_page = Control.new()
	_road_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Hud.full(_road_page)
	_road_page.visible = false
	add_child(_road_page)
	var col := _page(_road_page)
	col.add_child(Hud.label("EVENT ROAD", 44, Color(1.0, 0.75, 0.7)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	row.add_child(EventArt.ShardIcon.new(32.0))
	_road_count = Hud.label("", 28, Color(1.0, 0.8, 0.78))
	_road_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_road_count)
	col.add_child(row)
	_road_note = Hud.label("", 16, TEXT)
	col.add_child(_road_note)
	_road_scroll = ScrollContainer.new()
	_road_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_road_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_road_scroll)
	_road_list = VBoxContainer.new()
	_road_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_road_list.add_theme_constant_override("separation", 8)
	_road_scroll.add_child(_road_list)
	var back := Hud.button("BACK", 26)
	back.pressed.connect(func():
		Sfx.play("click")
		_road_page.visible = false
		_main.visible = true)
	_road_page.add_child(Hud.back_corner(back))


## Shows the screen, filled from the save (also after a claim or a casket).
func open_event(cfg: ConfigFile) -> void:
	visible = true
	refresh(cfg)


func road_open() -> bool:
	return visible and _road_page.visible


func show_road() -> void:
	_main.visible = false
	_road_page.visible = true
	_fill_road(Game._load_save())


## BACK on Android: the road page goes back to the event, the event to the title.
func back() -> void:
	if _road_page.visible:
		_road_page.visible = false
		_main.visible = true
	else:
		visible = false
		closed.emit()


func refresh(cfg: ConfigFile) -> void:
	var e := Events.current()
	var live := not e.is_empty()
	if not live:
		e = Events.coming()
	if e.is_empty():
		e = Events.BLOOD_MOON
	_moon.eclipse = live and Events.eclipse(e)
	var info: Dictionary = Events.chapter_info(e) if live else e.chapters[0]
	var ci: int = Events.chapter(e) if live else 0
	_chapter.text = "CHAPTER %d  ·  %s" % [ci + 1, info.name]
	if live:
		var next := Events.days_to_next_chapter(e)
		_clock.text = "Ends in %s" % Events.time_text(Events.seconds_left(e)) \
			+ ("  ·  next chapter in %d day%s" % [next, "" if next == 1 else "s"] if next > 0 else "  ·  the final chapter")
	else:
		_clock.text = "Begins in %s" % Events.time_text(Events.seconds_left(e))
	_double.visible = live and Events.double_today(e)
	_story.text = str(e.story)
	var s := Events.shards(cfg, e)
	_shard_count.text = "%s Moon Shards" % Hud.thousands(s)
	var ni := Events.next_index(cfg, e)
	var ready := Events.ready_count(cfg, e)
	_road_bar.set_road(s, int(Events.ROAD[ni].at) if ni < Events.ROAD.size() else 0, Events.progress(cfg, e), ready)
	if ready > 0:
		_road_sub.text = "%d prize%s ready to claim. Tap the road!" % [ready, "" if ready == 1 else "s"]
	elif ni < Events.ROAD.size():
		_road_sub.text = "Next: %s  ·  the road ends in the Blood Moon set" % Events.step_text(Events.ROAD[ni])
	else:
		_road_sub.text = "Road walked! Next bonus Moon Casket in %d shards" % Events.to_next_bonus(cfg)
	var bonus := []
	if Events.double_today(e) and live:
		bonus.append("double shards today")
	if Store.owned():
		bonus.append("+50% shards with the Crypt Pass")
	_run_sub.text = "About 200 shards a run" + ("  ·  " + ", ".join(bonus) if not bonus.is_empty() else "")
	_run_btn.disabled = not live
	_run_btn.text = "PLAY THE BLOOD MOON" if live else "OPENS IN %s" % Events.time_text(Events.seconds_left(e)).to_upper()
	# Tiers.
	for c in _tiers.get_children():
		_tiers.remove_child(c)
		c.queue_free()
	var open_n := Events.tiers_open(cfg, e) if live else 0
	for t in Events.TIERS.size():
		_tiers.add_child(_tier_row(cfg, e, t, open_n, live))
	var n := Events.caskets(cfg, e)
	_caskets.text = ("OPEN MOON CASKET" if n == 1 else "OPEN %d MOON CASKETS" % n) if n > 0 else "MOON CASKETS: none yet"
	_caskets.disabled = n <= 0
	# Chapters.
	for c in _chapters.get_children():
		_chapters.remove_child(c)
		c.queue_free()
	for i in e.chapters.size():
		var chp: Dictionary = e.chapters[i]
		var now: bool = live and i == ci
		var past: bool = live and i < ci
		var when := ""
		if now:
			when = "NOW"
		elif past:
			when = "DONE"
		else:
			var d := int(chp.day) - (Events.day(e) if live else 1)
			when = "DAY %d" % int(chp.day) if not live else ("in %d day%s" % [d, "" if d == 1 else "s"])
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 10)
		var nm := Hud.label("%d. %s" % [i + 1, chp.name], 20, GOLD if now else (DONE if past else DIM), HORIZONTAL_ALIGNMENT_LEFT)
		nm.custom_minimum_size = Vector2(170, 0)
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(nm)
		var tx := Hud.label(str(chp.text), 15, TEXT if now else DIM, HORIZONTAL_ALIGNMENT_LEFT)
		tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(tx)
		var wl := Hud.label(when, 15, GOLD if now else DIM)
		wl.custom_minimum_size = Vector2(70, 0)
		wl.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(wl)
		_chapters.add_child(h)
	if _road_page.visible:
		_fill_road(cfg)


func _tier_row(cfg: ConfigFile, e: Dictionary, t: int, open_n: int, live: bool) -> Control:
	var tier: Dictionary = Events.TIERS[t]
	var open := t < open_n
	var won := live and Events.won_today(cfg, t + 1, e)
	var beaten := Events.best_tier(cfg, e) > t
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	var eclipse := t == Events.TIERS.size() - 1
	sb.bg_color = Color(0.2, 0.03, 0.06, 0.95) if open else Color(0.08, 0.05, 0.08, 0.9)
	sb.border_color = (Color(1.0, 0.45, 0.2) if eclipse else CRIMSON.darkened(0.2)) if open else Color(0.25, 0.2, 0.26)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 8)
	panel.add_child(h)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	h.add_child(texts)
	var name_text := str(tier.name) + ("  ·  BEATEN" if beaten else "")
	texts.add_child(Hud.label(name_text, 22, (Color(1.0, 0.6, 0.3) if eclipse else Color(1.0, 0.82, 0.78)) if open else DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var shards := int(tier.shards)
	var line := "Queen health x%s  ·  %d blessings  ·  %d shards" % [str(tier.hp), int(tier.gifts), shards]
	texts.add_child(Hud.label(line, 14, TEXT if open else DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var note := ""
	if open:
		note = ("Won today  ·  pays %d shards again" % shards) if won else "First win today: +50% and a Moon Casket"
	elif not live:
		note = "Opens with the event"
	else:
		var needed := -1
		for i in e.chapters.size():
			if int(e.chapters[i].tiers) > t:
				needed = i
				break
		if needed > Events.chapter(e):
			var d := int(e.chapters[needed].day) - Events.day(e)
			note = "Opens in chapter %d (%d day%s)" % [needed + 1, d, "" if d == 1 else "s"]
		else:
			note = "Beat %s first" % str(Events.TIERS[t - 1].name)
	texts.add_child(Hud.label(note, 14, GOLD if open and not won else DIM, HORIZONTAL_ALIGNMENT_LEFT))
	if open:
		var b := Hud.button("FIGHT", 22, Color(0.45, 0.16, 0.12, 0.97), Color(1, 0.75, 0.4))
		Hud.paint(b, "gold" if not won else "red")
		b.custom_minimum_size = Vector2(112, 62)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func(): _confirm(b, hunt_pressed.emit.bind(t + 1)))
		h.add_child(b)
	else:
		var lock := Hud.label("LOCKED", 15, DIM)
		lock.custom_minimum_size = Vector2(112, 0)
		lock.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(lock)
	return panel


## A saved run is given up by starting the event, so with one waiting the first tap asks.
func _confirm(b: Button, f: Callable) -> void:
	if Game.continue_text() == "" or b.has_meta("armed"):
		if b.has_meta("armed"):
			b.text = str(b.get_meta("armed"))
			b.remove_meta("armed")
		f.call()
		return
	b.set_meta("armed", b.text)
	b.text = "TAP AGAIN" if b.custom_minimum_size.x < 200 else "TAP AGAIN: ENDS SAVED RUN"
	get_tree().create_timer(3.0, true, false, true).timeout.connect(func():
		if is_instance_valid(b) and b.has_meta("armed"):
			b.text = str(b.get_meta("armed"))
			b.remove_meta("armed"))


func _fill_road(cfg: ConfigFile) -> void:
	for c in _road_list.get_children():
		_road_list.remove_child(c)
		c.queue_free()
	var s := Events.shards(cfg)
	_road_count.text = "%s Moon Shards" % Hud.thousands(s)
	var ready := Events.ready_count(cfg)
	var ni := Events.next_index(cfg)
	if ready > 0:
		_road_note.text = "%d prize%s ready to claim!" % [ready, "" if ready == 1 else "s"]
	elif ni < Events.ROAD.size():
		_road_note.text = "Shards come from event runs and the Queen Hunt.\nAfter the road, a bonus Moon Casket every %d shards." % Events.BONUS_EVERY
	else:
		_road_note.text = "The whole event road walked!\nBonus Moon Casket every %d shards: next in %d." % [Events.BONUS_EVERY, Events.to_next_bonus(cfg)]
	var focus: Control = null
	for i in Events.ROAD.size():
		var row := _road_row(cfg, i, s)
		_road_list.add_child(row)
		if focus == null and (i == ni or (s >= int(Events.ROAD[i].at) and not Events.claimed(cfg, i))):
			focus = row
	if focus:
		_scroll_to(focus)


var _scroll_ask := 0


func _scroll_to(row: Control) -> void:
	_scroll_ask += 1
	var ask := _scroll_ask
	for i in 2:
		await get_tree().process_frame
	if ask != _scroll_ask or not is_instance_valid(row) or not visible:
		return
	_road_scroll.scroll_vertical = int(maxf(0.0, row.position.y - _road_scroll.size.y * 0.35))


func _road_row(cfg: ConfigFile, i: int, s: int) -> Control:
	var st: Dictionary = Events.ROAD[i]
	var reached := s >= int(st.at)
	var got := Events.claimed(cfg, i)
	var look := str(st.kind) == "look"
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.05, 0.07, 0.97) if reached and not got else Color(0.1, 0.04, 0.07, 0.95)
	if look:
		sb.bg_color = sb.bg_color.lerp(Color(0.3, 0.18, 0.04), 0.35)
	sb.border_color = Hud.GOLD if reached and not got else (DONE.darkened(0.3) if got else (Color(0.8, 0.55, 0.2) if look else Color(0.34, 0.12, 0.16)))
	sb.set_border_width_all(3 if (reached and not got) or look else 2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)
	var at := Hud.label(str(int(st.at)), 22, Color(1.0, 0.7, 0.66) if reached else DIM)
	at.custom_minimum_size = Vector2(64, 0)
	at.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(at)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	h.add_child(texts)
	var what := Events.step_text(st)
	if look:
		what = "BLOOD MOON SET: " + what
	texts.add_child(Hud.label(what, 20 if look else 21, (GOLD if look else TEXT) if reached else (Color(0.85, 0.65, 0.35) if look else DIM), HORIZONTAL_ALIGNMENT_LEFT))
	var need := ("Claimed" if got else "Ready!") if reached else "%d shards to go" % (int(st.at) - s)
	if look:
		need += "  ·  every hero can wear it"
	texts.add_child(Hud.label(need, 14, Hud.GOLD if reached and not got else DIM, HORIZONTAL_ALIGNMENT_LEFT))
	if reached and not got:
		var c := Hud.button("CLAIM", 20, Color(0.3, 0.2, 0.06, 0.97), Hud.GOLD)
		c.custom_minimum_size = Vector2(118, 60)
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		c.pressed.connect(func(): claim.emit(i))
		h.add_child(c)
	else:
		var tag := Hud.label("DONE" if got else "", 16, DONE)
		tag.custom_minimum_size = Vector2(118, 0)
		tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(tag)
	return panel


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# The countdown ticks; the double-shards line glows.
	if _double.visible:
		var g := 0.85 + 0.15 * sin(_t * 4.0)
		_double.modulate = Color(g, g, g)
