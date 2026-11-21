class_name EventScreen
extends ColorRect
## The event screen (events.gd, version 134): the Blood Moon's own lobby. Its second page is
## the event road, every step with its prize and a CLAIM button.
## Version 222 (design critique of the live screen): the top is the event's picture, your
## hero in the whole Blood Moon set in front of the moon with the four pieces around them,
## the chapter and the time left, and one gold PLAY. Under it the road bar, the Moon Caskets,
## the Queen Hunt and the chapters, on near-black cards: red is kept for the moon and the
## shards (red cards on the red wall read as one smear). The story is the splash's; the
## how-to paragraphs are gone. The road page is a track (see EventArt.RoadTrack).

signal run_pressed
signal hunt_pressed(tier: int)
signal claim(index: int)
signal caskets_pressed
signal pass_pressed   # v219: the Crypt Pass card, from the run card or the road's Pass row
signal closed

const GOLD := Color(1.0, 0.8, 0.42)
const DONE := Color(0.45, 0.85, 0.5)
## Version 222: the cards' near-black, their edge, and the warm white of their headings.
## Version 243: each event's own (Frostfall's are night blue and ice), set in _init.
var CRIMSON := Color(1.0, 0.3, 0.26)
var TEXT := Color(0.92, 0.86, 0.88)
var DIM := Color(0.62, 0.55, 0.6)
var CARD := Color(0.075, 0.05, 0.065, 0.95)
var EDGE := Color(0.3, 0.19, 0.21)
var HEAD := Color(1.0, 0.87, 0.78)
var _hunt_head: Label
var _hunt_text: Label

var _main: Control
var _road_page: Control
var _moon: EventArt.Moon
var _title: Label
var _chapter: Label
var _clock: Label
var _double: Label
var _road_bar: EventArt.RoadBar
var _road_sub: Label
var _run_btn: Button
var _run_sub: Label
var _pass_btn: Button
var _tiers: VBoxContainer
var _locked: Label
var _caskets: Button
var _casket_note: Label
var _chapters: HBoxContainer
var _chapter_note: Label
var _scroll: ScrollContainer
var _road_count: Label
var _road_note: Label
var _road_scroll: ScrollContainer
var _track: EventArt.RoadTrack
var _road_list: VBoxContainer
var _t := 0.0
## Version 143: the Blood Moon set, worn by your hero, at the top of the event screen
## (version 222: in front of the moon, its four pieces around them).
var _set_stage: HeroStage
var _set_title: Label
var _badges: Array[VBoxContainer] = []


func _init() -> void:
	color = Color(0.04, 0.01, 0.02, 0.98)
	if Events.frost():
		color = Color(0.01, 0.02, 0.05, 0.98)
		CRIMSON = Color(0.4, 0.78, 1.0)
		TEXT = Color(0.86, 0.91, 0.97)
		DIM = Color(0.55, 0.62, 0.72)
		CARD = Color(0.04, 0.06, 0.11, 0.95)
		EDGE = Color(0.2, 0.3, 0.45)
		HEAD = Color(0.85, 0.94, 1.0)
	Hud.backdrop(self, str(EventArt.pal().menu))
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
	col.add_theme_constant_override("separation", 14)
	_scroll.add_child(col)
	_build_head(col)
	# The one big button, gold like every way into a fight on this screen (it was red, the
	# game's danger colour, on red cards).
	var play := _tight(col)
	_double = Hud.label("DOUBLE MOON SHARDS TODAY!", 22, Color(1.0, 0.85, 0.3))
	play.add_child(_double)
	_run_btn = Hud.button("PLAY THE BLOOD MOON", 28)
	Hud.paint(_run_btn, "gold")
	_run_btn.custom_minimum_size = Vector2(440, 86)
	_run_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_run_btn.pressed.connect(func(): _confirm(_run_btn, run_pressed.emit))
	play.add_child(_run_btn)
	_run_sub = Hud.label("", 16, GOLD)
	play.add_child(_run_sub)
	# The road: the bar (its stars are the set's pieces) and the next prize under it.
	var road := _tight(col)
	_road_bar = EventArt.RoadBar.new()
	_road_bar.custom_minimum_size = Vector2(470, 68)
	_road_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_road_bar.pressed.connect(func():
		Sfx.play("click")
		show_road())
	road.add_child(_road_bar)
	_road_sub = Hud.label("", 16, DIM)
	road.add_child(_road_sub)
	# Version 219 (review 4 fix 26): the Pass's event perk, a button that opens the Pass
	# (free players only).
	_pass_btn = Hud.button("CRYPT PASS: +50% SHARDS", 18, Color(0.3, 0.2, 0.06, 0.97), Hud.GOLD)
	_pass_btn.custom_minimum_size = Vector2(320, 56)
	_pass_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_pass_btn.pressed.connect(func():
		Sfx.play("click")
		pass_pressed.emit())
	road.add_child(_pass_btn)
	# Moon Caskets: a gold button with some to open, one plain line on the next one without.
	_caskets = Hud.button("MOON CASKETS", 22, Color(0.3, 0.2, 0.06, 0.97), Hud.GOLD)
	_caskets.custom_minimum_size = Vector2(360, 64)
	_caskets.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_caskets.pressed.connect(func(): caskets_pressed.emit())
	col.add_child(_caskets)
	_casket_note = Hud.label("", 16, DIM)
	col.add_child(_casket_note)
	# The Queen Hunt: the open tiers, then the locked ones in one line.
	var hunt := _card(col, "QUEEN HUNT", "Straight to the Queen, with blessings to start. Each tier pays in full once a day.")
	_hunt_head = hunt.get_child(0)
	_hunt_text = hunt.get_child(1)
	_tiers = VBoxContainer.new()
	_tiers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tiers.add_theme_constant_override("separation", 6)
	hunt.add_child(_tiers)
	_locked = Hud.label("", 16, DIM, HORIZONTAL_ALIGNMENT_LEFT)
	hunt.add_child(_locked)
	# The chapters: three side by side, and what the next one brings.
	var ch := _card(col, "CHAPTERS", "")
	_chapters = HBoxContainer.new()
	_chapters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chapters.add_theme_constant_override("separation", 6)
	ch.add_child(_chapters)
	_chapter_note = Hud.label("", 16, TEXT)
	ch.add_child(_chapter_note)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 8)
	col.add_child(pad)
	var back := Hud.button("BACK", 26)
	back.pressed.connect(func():
		visible = false
		_set_stage.set_active(false)
		closed.emit())
	_main.add_child(Hud.back_corner(back))


## A column with its parts close together (a button and the line under it).
func _tight(parent: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	parent.add_child(v)
	return v


## Version 222 (design critique fix 1): the top of the screen is the event's picture: its
## name, the chapter and the time left, then your hero in the whole Blood Moon set in front
## of the moon (the whole moon: it was cut off at the top), with the set's four pieces
## around them, each found or the shards it waits at. Version 143's set card (the hero
## beside a list of the pieces, fourth on the screen) was this, further down.
func _build_head(col: VBoxContainer) -> void:
	var head := Control.new()
	head.custom_minimum_size = Vector2(0, 400)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	_moon = EventArt.Moon.new()
	_moon.anchor_left = 0.5
	_moon.anchor_right = 0.5
	_moon.offset_left = -150
	_moon.offset_right = 150
	_moon.offset_top = 46
	_moon.offset_bottom = 346
	head.add_child(_moon)
	_title = Hud.label("BLOOD MOON", 54, Color(1.0, 0.9, 0.84) if not Events.frost() else Color(0.92, 0.97, 1.0))
	_title.label_settings.outline_color = EventArt.c("ink")
	_title.label_settings.shadow_color = Color(EventArt.c("shadow"), 0.6)
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 0
	_title.offset_bottom = 60
	head.add_child(_title)
	# The chapter and the time left, on one dark tag under the name.
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.02, 0.035, 0.88) if not Events.frost() else Color(0.02, 0.04, 0.09, 0.88)
	sb.border_color = Color(0.45, 0.3, 0.22) if not Events.frost() else Color(0.3, 0.45, 0.62)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	tag.add_theme_stylebox_override("panel", sb)
	tag.anchor_left = 0.5
	tag.anchor_right = 0.5
	tag.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tag.offset_top = 60
	tag.offset_bottom = 92
	head.add_child(tag)
	var tag_row := HBoxContainer.new()
	tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_row.add_theme_constant_override("separation", 10)
	tag.add_child(tag_row)
	_chapter = Hud.label("", 18, GOLD)
	_chapter.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag_row.add_child(_chapter)
	_clock = Hud.label("", 18, TEXT)
	_clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag_row.add_child(_clock)
	_set_stage = HeroStage.new(Vector2(220, 272))
	_set_stage.custom_minimum_size = Vector2(220, 272)
	_set_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_stage.anchor_left = 0.5
	_set_stage.anchor_right = 0.5
	_set_stage.offset_left = -110
	_set_stage.offset_right = 110
	_set_stage.offset_top = 96
	_set_stage.offset_bottom = 368
	head.add_child(_set_stage)
	# The four pieces: the first two on the left, the last two on the right.
	for i in 4:
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		var right := i % 2 == 1
		v.anchor_left = 1.0 if right else 0.0
		v.anchor_right = v.anchor_left
		v.offset_left = -136.0 if right else 0.0
		v.offset_right = 0.0 if right else 136.0
		v.offset_top = 96.0 if i < 2 else 232.0
		v.offset_bottom = v.offset_top + 130.0
		head.add_child(v)
		_badges.append(v)
	_set_title = Hud.label("", 20, GOLD)
	_set_title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_set_title.offset_top = -34
	_set_title.offset_bottom = 0
	head.add_child(_set_title)


## The set filled from the save: the hero in all four pieces, each piece found or not.
func _fill_set(cfg: ConfigFile) -> void:
	var id := Heroes.selected(cfg)
	var base := Heroes.get_hero(id)
	var p := HeroStyle.picks(cfg, id)
	var found := 0
	var s := Events.shards(cfg)
	var k := 0
	for st: Dictionary in Events.road():
		if str(st.kind) != "look":
			continue
		p[str(st.look[0])] = str(st.look[1])
		var got := Events.has_look(cfg, str(st.look[0]), str(st.look[1]))
		found += 1 if got else 0
		if k >= _badges.size():
			continue
		var v: VBoxContainer = _badges[k]
		k += 1
		for c in v.get_children():
			v.remove_child(c)
			c.queue_free()
		var reached := s >= int(st.at)
		var badge := EventArt.SetBadge.new(64.0)
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		badge.setup(id, str(st.look[0]), str(st.look[1]), base, got, reached)
		v.add_child(badge)
		v.add_child(Hud.label(HeroStyle.item_label(id, str(st.look[0]), str(st.look[1])), 16, TEXT if got or reached else DIM.lightened(0.2)))
		var need := Hud.label("FOUND" if got else ("ON THE ROAD!" if reached else Hud.thousands(int(st.at))), 16, GOLD if got or reached else DIM)
		need.autowrap_mode = TextServer.AUTOWRAP_OFF
		v.add_child(need)
	_set_title.text = "%s  %d/4  ·  for every hero" % [Events.word("set").to_upper(), found]
	_set_stage.show_hero(HeroStyle.dressed(Heroes.get_hero(id), p), found >= 4, CRIMSON)
	_set_stage.set_active(visible and _main.visible)


## A near-black card with a heading and a line of text; returns its column.
func _card(parent: Control, heading: String, text: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.border_color = EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(Hud.label(heading, 28, HEAD))
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
	col.add_child(Hud.label("EVENT ROAD", 44, Color(1.0, 0.82, 0.74)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	row.add_child(EventArt.ShardIcon.new(32.0))
	_road_count = Hud.label("", 28, Color(1.0, 0.8, 0.78))
	_road_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_road_count)
	col.add_child(row)
	_road_note = Hud.label("", 18, GOLD)
	col.add_child(_road_note)
	# Version 222 (critique fix 6): the road scrolls inside a dark window that fades at its
	# edges (the rows slid hard under the header before).
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(frame)
	var well := Color(0.035, 0.018, 0.03, 0.86)
	var bg := Panel.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = well
	sb.border_color = Color(0.22, 0.13, 0.15)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	bg.add_theme_stylebox_override("panel", sb)
	frame.add_child(Hud.full(bg))
	_road_scroll = ScrollContainer.new()
	_road_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	Hud.full(_road_scroll)
	_road_scroll.offset_left = 4
	_road_scroll.offset_top = 6
	_road_scroll.offset_right = -6
	_road_scroll.offset_bottom = -6
	frame.add_child(_road_scroll)
	_track = EventArt.RoadTrack.new()
	_road_scroll.add_child(_track)
	_road_list = _track.list
	for top in [true, false]:
		var g := Gradient.new()
		g.set_color(0, Color(well.r, well.g, well.b, 1.0) if top else Color(well.r, well.g, well.b, 0.0))
		g.set_color(1, Color(well.r, well.g, well.b, 0.0) if top else Color(well.r, well.g, well.b, 1.0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.width = 4
		gt.height = 32
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(0, 1)
		var fade := TextureRect.new()
		fade.texture = gt
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fade.stretch_mode = TextureRect.STRETCH_SCALE
		fade.anchor_right = 1.0
		fade.anchor_top = 0.0 if top else 1.0
		fade.anchor_bottom = fade.anchor_top
		fade.offset_left = 6
		fade.offset_right = -16
		fade.offset_top = 6.0 if top else -34.0
		fade.offset_bottom = 34.0 if top else -6.0
		frame.add_child(fade)
	var back := Hud.button("BACK", 26)
	back.pressed.connect(func():
		Sfx.play("click")
		_road_page.visible = false
		_main.visible = true
		_set_stage.set_active(true))
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
	_set_stage.set_active(false)
	_fill_road(Game._load_save())


## BACK on Android: the road page goes back to the event, the event to the title.
func back() -> void:
	if _road_page.visible:
		_road_page.visible = false
		_main.visible = true
		_set_stage.set_active(true)
	else:
		visible = false
		_set_stage.set_active(false)
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
		_clock.text = "Ends in %s" % Events.time_text(Events.seconds_left(e))
	else:
		_clock.text = "Begins in %s" % Events.time_text(Events.seconds_left(e))
	_double.visible = live and Events.double_today(e)
	var s := Events.shards(cfg, e)
	var ni := Events.next_index(cfg, e)
	var ready := Events.ready_count(cfg, e)
	# version 212 (critic fix #6): the whole road on the bar ("0 / 2,400", the set at the end),
	# not the next step ("0 / 40" read like a 40-step road). The line under it names the next prize.
	var road_end := int(Events.road()[Events.road().size() - 1].at)
	_road_bar.set_road(s, road_end if ni < Events.road().size() else 0, clampf(float(s) / float(road_end), 0.0, 1.0), ready)
	var marks := []
	for st: Dictionary in Events.road():
		if str(st.kind) == "look":
			marks.append([float(st.at) / float(road_end), s >= int(st.at)])
	_road_bar.marks = marks
	if ready > 0:
		_road_sub.text = "%d prize%s ready to claim. Tap the road!" % [ready, "" if ready == 1 else "s"]
	elif ni < Events.road().size():
		_road_sub.text = "Next prize: %s in %s %s" % [Events.step_text(Events.road()[ni]), Hud.thousands(int(Events.road()[ni].at) - s), Events.word("unit")]
	else:
		var bl := Events.bonus_line(cfg)
		_road_sub.text = "Road walked! " + bl.left(1).to_upper() + bl.substr(1)
	_fill_set(cfg)
	_pass_btn.visible = not Store.owned()   # (v219: was the line "Crypt Pass: +50% shards")
	# version 213 (hardest review fix #3): the measured full run is ~200, ~300 with the Pass
	_run_sub.text = (("About 300 %s a full run, with your Crypt Pass" if Store.owned() else "About 200 %s a full run") % Events.word("unit", e)) \
		+ ("  ·  double today" if live and Events.double_today(e) else "")
	_run_btn.disabled = not live
	_run_btn.text = ("PLAY " + ("FROSTFALL" if Events.frost(e) else "THE BLOOD MOON")) if live else "OPENS IN %s" % Events.time_text(Events.seconds_left(e)).to_upper()
	_title.text = str(e.name)
	_double.text = "DOUBLE %s TODAY!" % Events.word("shards", e).to_upper()
	_pass_btn.text = "CRYPT PASS: +50%% %s" % Events.word("unit", e).to_upper()
	_hunt_head.text = Events.word("hunt", e).to_upper()
	_hunt_text.text = "Straight to %s, with blessings to start. Each tier pays in full once a day." % Events.word("foe", e)
	# Tiers: the open ones as rows, the locked ones in one line under them.
	for c in _tiers.get_children():
		_tiers.remove_child(c)
		c.queue_free()
	var open_n := Events.tiers_open(cfg, e) if live else 0
	for t in open_n:
		_tiers.add_child(_tier_row(cfg, e, t, open_n, live))
	_locked.text = _locked_line(e, open_n, live)
	_locked.visible = _locked.text != ""
	var n := Events.caskets(cfg, e)
	_caskets.text = ("OPEN " + Events.word("casket", e) if n == 1 else "OPEN %d %s" % [n, Events.word("caskets", e)]).to_upper()
	_caskets.visible = n > 0
	# Version 219 (review 4 fix 18) gave an empty casket button a grey "NO CASKET YET"; version
	# 222 (critique fix 5): one plain line instead, true to what is left today.
	_casket_note.text = _casket_line(cfg, e, live)
	_casket_note.visible = n <= 0 and _casket_note.text != ""
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
		_chapters.add_child(_chapter_box(i, str(chp.name), when, now, past))
	var nxt := ci + 1 if live else 0
	if nxt < e.chapters.size():
		var d := int(e.chapters[nxt].day) - Events.day(e)
		_chapter_note.text = ("Next, in %d day%s: " % [d, "" if d == 1 else "s"] if live else "") + str(e.chapters[nxt].text)
	else:
		_chapter_note.text = "The final chapter: " + str(e.chapters[ci].text)
	if _road_page.visible:
		_fill_road(cfg)


## One chapter, a small box: its number and name over when it comes (NOW in gold).
func _chapter_box(i: int, title: String, when: String, now: bool, past: bool) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.13, 0.05, 0.95) if now else Color(0.04, 0.025, 0.035, 0.9)
	sb.border_color = GOLD if now else Color(0.22, 0.15, 0.17)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	panel.add_child(v)
	var nm := Hud.label("%d. %s" % [i + 1, title], 18, GOLD if now else (DIM if past else TEXT))
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(nm)
	v.add_child(Hud.label(when, 16, GOLD if now else DIM))
	return panel


## Version 222 (critique fix 5): the locked tiers in one line, not a grey card each:
## "LOCKED: TIERS III-IV in 5 days  ·  ECLIPSE (Blood Eclipse glow) in 10 days".
func _locked_line(e: Dictionary, open_n: int, live: bool) -> String:
	if not live:
		return "The Hunt opens with the event"
	var parts := []
	var beat := []
	var by_day := {}
	var days := []
	for t in range(open_n, Events.tiers().size()):
		var needed := -1
		for i in e.chapters.size():
			if int(e.chapters[i].tiers) > t:
				needed = i
				break
		if needed > Events.chapter(e):
			var d := int(e.chapters[needed].day) - Events.day(e)
			if not by_day.has(d):
				by_day[d] = []
				days.append(d)
			by_day[d].append(t)
		else:
			beat.append(t)
	if not beat.is_empty():
		var first := int(beat[0])
		var line := "Beat %s to open %s" % [str(Events.tiers()[first - 1].name), str(Events.tiers()[first].name)]
		if beat.size() > 1:
			line += ", then %s" % _tier_span(beat.slice(1))
		parts.append(line)
	for d: int in days:
		parts.append("%s in %d day%s" % [_tier_span(by_day[d]), d, "" if d == 1 else "s"])
	return ("LOCKED:  " if beat.is_empty() else "") + "  ·  ".join(parts)


## "TIER III", "TIERS III-IV", "TIERS III-IV and ECLIPSE (Blood Eclipse glow)": tiers in a
## row, the last one named with its own prize.
func _tier_span(ts: Array) -> String:
	var numbered := []
	var named := []
	for t: int in ts:
		var n := str(Events.tiers()[t].name)
		if n.begins_with("TIER "):
			numbered.append(n.trim_prefix("TIER "))
		else:
			named.append(n + ((" (%s glow)" % Events.word("top")) if t == Events.tiers().size() - 1 else ""))
	var parts := []
	if numbered.size() == 1:
		parts.append("TIER " + str(numbered[0]))
	elif numbered.size() > 1:
		parts.append("TIERS %s-%s" % [numbered[0], numbered[numbered.size() - 1]])
	parts.append_array(named)
	return " and ".join(parts)


## Version 222 (critique fix 5): how the next Moon Casket comes, true to what is left today
## (the old grey button said "First Hunt win each day holds one" after today's was won, and
## never named the run's).
func _casket_line(cfg: ConfigFile, e: Dictionary, live: bool) -> String:
	if not live:
		return ""
	var hunt := Events.casket_ready(cfg, "hunt", e)
	var run := Events.casket_ready(cfg, "run", e)
	var one := Events.word("casket", e)
	var two := Events.word("caskets", e)
	var foe := Events.word("foe", e)
	if hunt and run:
		return "2 %s today: beat %s in a run and in a Hunt" % [two, foe]
	if run:
		return "1 more %s today: beat %s in a run" % [one, foe]
	if hunt:
		return "1 more %s today: win a %s" % [one, Events.word("hunt", e)]
	return "Today's 2 %s are won. 2 more tomorrow" % two


func _tier_row(cfg: ConfigFile, e: Dictionary, t: int, open_n: int, live: bool) -> Control:
	var tier: Dictionary = Events.tiers()[t]
	var open := t < open_n
	var won := live and Events.won_today(cfg, t + 1, e)
	var beaten := Events.best_tier(cfg, e) > t
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	var eclipse := t == Events.tiers().size() - 1
	var fr := Events.frost(e)
	sb.bg_color = (Color(0.13, 0.08, 0.09, 0.97) if not fr else Color(0.06, 0.1, 0.17, 0.97)) if open else CARD.darkened(0.2)
	sb.border_color = ((Color(1.0, 0.45, 0.2) if not fr else Color(0.75, 0.92, 1.0)) if eclipse else EDGE.lightened(0.25)) if open else EDGE.darkened(0.25)
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
	texts.add_child(Hud.label(name_text, 22, ((Color(1.0, 0.6, 0.3) if not fr else Color(0.75, 0.95, 1.0)) if eclipse else HEAD) if open else DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var shards := int(tier.shards)
	# (Version 192: "Queen health x0.6" on the hardest tier read as the easiest. The number
	# is a factor on health that already grows with the floor. Say how hard it is instead,
	# and name the Eclipse tier's own prize, which nothing on this screen mentioned.)
	var unit := Events.word("unit", e)
	var line := "Like floor %d  ·  %d blessings  ·  %d %s" % [int(tier.floor), int(tier.gifts), shards, unit]
	if eclipse:
		var gk: Array = Events.top_look(e)
		line += "\nPrize: %s glow" % Events.word("top", e) + ("  ·  OWNED" if Events.has_look(cfg, str(gk[0]), str(gk[1])) else "")
	texts.add_child(Hud.label(line, 14, TEXT if open else DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var note := ""
	if open:
		note = ("Won today  ·  pays %d %s again" % [roundi(shards / 3.0), unit]) if won else ("First win today: +50%% %s" % unit + ((" and a " + Events.word("casket", e)) if Events.casket_ready(cfg, "hunt", e) else ""))
	elif not live:
		note = "Opens with the event"
	texts.add_child(Hud.label(note, 14, GOLD if open and not won else DIM, HORIZONTAL_ALIGNMENT_LEFT))
	if open:
		var b := Hud.button("FIGHT", 22, Color(0.45, 0.16, 0.12, 0.97), Color(1, 0.75, 0.4))
		# (version 222: a tier won today was red, the danger colour; now a quieter slate)
		Hud.paint(b, "gold" if not won else "slate")
		b.custom_minimum_size = Vector2(112, 62)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func(): _confirm(b, hunt_pressed.emit.bind(t + 1)))
		h.add_child(b)
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
	_track.clear()
	var s := Events.shards(cfg)
	_track.shards = s
	_road_count.text = "%s %s" % [Hud.thousands(s), Events.word("shards")]
	var ready := Events.ready_count(cfg)
	var ni := Events.next_index(cfg)
	if ready > 0:
		_road_note.text = "%d prize%s ready to claim!" % [ready, "" if ready == 1 else "s"]
	elif ni < Events.road().size():
		_road_note.text = "Next prize: %s in %s %s" % [Events.step_text(Events.road()[ni]), Hud.thousands(int(Events.road()[ni].at) - s), Events.word("unit")]
	else:
		var bl := Events.bonus_line(cfg)
		_road_note.text = "Road walked! " + bl.left(1).to_upper() + bl.substr(1)
	var id := Heroes.selected(cfg)
	var base := Heroes.get_hero(id)
	var focus: Control = null
	for i in Events.road().size():
		var st: Dictionary = Events.road()[i]
		var got := Events.claimed(cfg, i)
		var row := _road_row(cfg, i, s, id, base)
		_road_list.add_child(row)
		_track.stops.append({"row": row, "at": int(st.at), "look": str(st.kind) == "look",
			"state": "got" if got else ("ready" if s >= int(st.at) else "next")})
		if focus == null and (i == ni or (s >= int(st.at) and not got)):
			focus = row
		for j in Events.pass_road().size():
			if int(Events.pass_road()[j].at) == int(st.at):
				var pr := _pass_row(cfg, j, s, id, base)
				_road_list.add_child(pr)
				var pgot := Events.pass_claimed(cfg, j)
				_track.branches.append({"row": pr, "state": "got" if pgot else ("ready" if Store.owned() and s >= int(st.at) else "next")})
				if focus == null and Store.owned() and s >= int(Events.pass_road()[j].at) and not pgot:
					focus = pr
	# The bonus caskets after the road, once, at its end (they were a second line of the
	# header, which wrapped to a lone "day).").
	var after := Hud.label("After the road: a bonus %s every %d %s, one a day." % [Events.word("casket"), Events.BONUS_EVERY, Events.word("unit")], 16, DIM)
	_road_list.add_child(after)
	_track.queue_redraw()
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
	_road_scroll.scroll_vertical = int(maxf(0.0, _road_list.position.y + row.position.y - _road_scroll.size.y * 0.35))


## Version 222 (design critique fix 4): one step of the road. Claimed steps sink back (their
## green DONE edges outshone the prizes still to come); a step reached glows gold with its
## CLAIM; a piece of the set is a big row with its picture.
func _road_row(cfg: ConfigFile, i: int, s: int, id: String, base: Dictionary) -> Control:
	var st: Dictionary = Events.road()[i]
	var reached := s >= int(st.at)
	var got := Events.claimed(cfg, i)
	var look := str(st.kind) == "look"
	# Found early in a Legendary casket: this step pays coins instead (a plain row).
	var early := look and not got and Events.has_look(cfg, str(st.look[0]), str(st.look[1]))
	var big := look and not early
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	if got:
		sb.bg_color = Color(0.06, 0.045, 0.055, 0.8)
		sb.border_color = Color(0.17, 0.12, 0.14)
		sb.set_border_width_all(1)
	elif reached:
		sb.bg_color = Color(0.22, 0.14, 0.04, 0.97)
		sb.border_color = Hud.GOLD
		sb.set_border_width_all(3)
	elif big:
		sb.bg_color = Color(0.15, 0.1, 0.045, 0.97)
		sb.border_color = Color(0.78, 0.55, 0.22)
		sb.set_border_width_all(3)
	else:
		sb.bg_color = Color(0.1, 0.065, 0.08, 0.95)
		sb.border_color = Color(0.26, 0.17, 0.2)
		sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 10 if big else 6
	sb.content_margin_bottom = 10 if big else 6
	panel.add_theme_stylebox_override("panel", sb)
	if got:
		panel.modulate = Color(1, 1, 1, 0.6)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	var to_go := "%s %s to go" % [Hud.thousands(int(st.at) - s), Events.word("unit")]
	if big:
		var badge := EventArt.SetBadge.new(88.0)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.setup(id, str(st.look[0]), str(st.look[1]), base, got, reached)
		h.add_child(badge)
		var texts := VBoxContainer.new()
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.add_theme_constant_override("separation", 0)
		h.add_child(texts)
		texts.add_child(Hud.label("%s  ·  %s" % [Events.word("set").to_upper(), Hud.thousands(int(st.at))], 16, CRIMSON.lightened(0.3) if not got else DIM, HORIZONTAL_ALIGNMENT_LEFT))
		texts.add_child(Hud.label(HeroStyle.item_label(id, str(st.look[0]), str(st.look[1])), 24, GOLD if not got else TEXT, HORIZONTAL_ALIGNMENT_LEFT))
		texts.add_child(Hud.label("Claimed" if got else ("Ready!" if reached else to_go + "  ·  every hero"), 16, Hud.GOLD if reached and not got else DIM, HORIZONTAL_ALIGNMENT_LEFT))
		if reached and not got:
			var c := Hud.button("CLAIM", 20, Color(0.3, 0.2, 0.06, 0.97), Hud.GOLD)
			c.custom_minimum_size = Vector2(150, 60)
			c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			c.pressed.connect(func(): claim.emit(i))
			texts.add_child(c)
		return panel
	var at := Hud.label(Hud.thousands(int(st.at)), 20, Color(1.0, 0.72, 0.66) if reached and not got else DIM)
	at.custom_minimum_size = Vector2(54, 0)
	at.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(at)
	var icon := EventArt.RoadIcon.new("coins" if early else str(st.kind), 44.0, got)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(icon)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	h.add_child(texts)
	var what := "%d COINS (%s found early)" % [Events.EARLY_LOOK_COINS, Events.step_text(st)] if early else Events.step_text(st)
	texts.add_child(Hud.label(what, 20, TEXT if reached and not got else (Color(0.85, 0.8, 0.82) if not got else DIM), HORIZONTAL_ALIGNMENT_LEFT))
	texts.add_child(Hud.label(("Claimed" if got else "Ready!") if reached else to_go, 16, Hud.GOLD if reached and not got else DIM, HORIZONTAL_ALIGNMENT_LEFT))
	if reached and not got:
		var c := Hud.button("CLAIM", 20, Color(0.3, 0.2, 0.06, 0.97), Hud.GOLD)
		c.custom_minimum_size = Vector2(108, 60)
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		c.pressed.connect(func(): claim.emit(i))
		h.add_child(c)
	return panel


## Version 219 (review 4 fix 26): a Crypt Pass step under its road step: a Silver Moon look,
## claimed with the Pass (CLAIM), or a button that opens the Pass for everyone else.
## Its CLAIM sends index PASS_INDEX + j through the same claim signal. Version 222: a silver
## branch off the track, with the look's picture.
const PASS_INDEX := 1000
const SILVER := Color(0.8, 0.88, 1.0)

func _pass_row(cfg: ConfigFile, j: int, s: int, id: String, base: Dictionary) -> Control:
	var st: Dictionary = Events.pass_road()[j]
	var owned := Store.owned()
	var reached := s >= int(st.at)
	var got := Events.pass_claimed(cfg, j)
	var indent := MarginContainer.new()
	indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indent.add_theme_constant_override("margin_left", int(EventArt.RoadTrack.INDENT))
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indent.add_child(panel)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.22, 0.97) if owned and reached and not got else Color(0.05, 0.06, 0.13, 0.95)
	sb.border_color = Hud.GOLD if owned and reached and not got else (Color(0.25, 0.28, 0.36) if got else SILVER.darkened(0.35))
	sb.set_border_width_all(1 if got else 3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 8
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	if got:
		panel.modulate = Color(1, 1, 1, 0.6)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	var badge := EventArt.SetBadge.new(58.0)
	badge.tint = SILVER
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.setup(id, str(st.look[0]), str(st.look[1]), base, got, owned and reached)
	h.add_child(badge)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	h.add_child(texts)
	texts.add_child(Hud.label("CRYPT PASS", 16, SILVER.darkened(0.2) if not got else DIM, HORIZONTAL_ALIGNMENT_LEFT))
	texts.add_child(Hud.label(HeroStyle.item_label(id, str(st.look[0]), str(st.look[1])), 20, SILVER if not got else DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var need := ("Claimed" if got else ("Ready!" if owned else "Reached: claim it with the Pass")) if reached else "%s %s to go" % [Hud.thousands(int(st.at) - s), Events.word("unit")]
	texts.add_child(Hud.label(need, 16, Hud.GOLD if owned and reached and not got else DIM, HORIZONTAL_ALIGNMENT_LEFT))
	if got:
		pass
	elif owned and reached:
		var c := Hud.button("CLAIM", 20, Color(0.3, 0.2, 0.06, 0.97), Hud.GOLD)
		c.custom_minimum_size = Vector2(108, 60)
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		c.pressed.connect(func(): claim.emit(PASS_INDEX + j))
		h.add_child(c)
	elif not owned:
		var p := Hud.button("PASS", 20, Color(0.3, 0.2, 0.06, 0.97), Hud.GOLD)
		p.custom_minimum_size = Vector2(108, 60)
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		p.pressed.connect(func():
			Sfx.play("click")
			pass_pressed.emit())
		h.add_child(p)
	return indent


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# The countdown ticks; the double-shards line glows.
	if _double.visible:
		var g := 0.85 + 0.15 * sin(_t * 4.0)
		_double.modulate = Color(g, g, g)
