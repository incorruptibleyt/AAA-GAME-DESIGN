class_name Hud
extends CanvasLayer
## Everything on screen that isn't the 3D world: the floating thumb joystick, health,
## room counter, boss bar, blessing cards, title and end screens, and fades.
## Laid out for a portrait phone.

signal tutorial_pressed
signal card_picked(index: int)
signal reroll_pressed
signal door_picked(index: int)
signal special_pressed
signal dash_pressed
signal screen_tapped
signal pause_pressed
signal play_pressed
signal armory_pressed
signal armory_buy(id: String)
## Version 152: a look on the Bone Bazaar tab was tapped (its preview), or bought there.
signal bazaar_look(slot: String, key: String)
signal bazaar_buy(slot: String, key: String)
signal heroes_pressed
signal records_pressed
signal drops_pressed
signal road_pressed
signal road_claim(index: int)
signal road_claim_all
signal road_closed
signal drops_closed
signal mastery_pressed(id: String)
## Training on the Mastery screen (version 132): coins buy this hero mastery points.
signal mastery_train(id: String)
signal style_pressed(id: String)
signal feats_pressed
signal found_wear(id: String, slot: String, key: String)
signal feats_hero_pressed(id: String)
signal see_looks(id: String, level: int)
signal style_wear(id: String, slot: String, key: String)
signal style_closed(id: String)   # the Style screen shut: its new looks have been seen
signal hero_pick(id: String)
signal copy_report_pressed
signal resume_pressed
signal quit_run_pressed
signal retry_pressed
signal start_floor_pressed   # version 309: the title's start-floor button
signal quick_pressed   # version 310: the title's QUICK PLAY button
signal today_chest_pressed   # version 311: OPEN THE CHEST on TODAY'S GOALS
signal music_toggled(on: bool)
signal sounds_toggled(on: bool)
signal graphics_toggled(level: int)
signal speed_test_pressed
signal shake_changed(level: int)
# Version 219 (review 4 fix 32): more comfort settings.
signal flashes_changed(level: int)
signal left_hand_toggled(on: bool)
signal button_size_changed(level: int)
signal darkness_toggled(light: bool)
signal vibration_toggled(on: bool)
signal colorblind_toggled(on: bool)
signal reports_toggled(on: bool)
signal dash_flicked(dir: Vector2)
signal pass_pressed
signal pass_buy
signal pass_restore
signal pass_dive   # version 280: FREE DIVE on the Crypt Pass screen
signal daily_pressed
signal curses_pressed
signal curse_toggled(id: String)
signal title_pressed
signal daily_start
signal continue_pressed
signal hero_trial(id: String)
signal share_pressed
signal loop_deeper
signal loop_bank
signal omen_picked(id: String)
signal reports_answered(on: bool)
## Version 143: phone reminders, asked once and switched in Settings.
signal reminders_answered(on: bool)
signal pass_lost_restore   # version 213: RESTORE on the "Crypt Pass not found" note
signal reminders_toggled(on: bool)
## The Blood Moon event (events.gd, version 134).
signal event_pressed
signal event_run
signal event_hunt(tier: int)
signal event_claim(index: int)
signal event_caskets
signal event_closed
## The Crypt Race (race.gd, version 153).
signal race_pressed
signal race_find
signal race_go
signal race_again
signal race_claim(index: int)
signal race_to_title
signal race_surge_pressed

## A quick flick of the thumb (short and fast) is a dash rather than a step.
const FLICK_TIME := 0.22
const FLICK_DISTANCE := 70.0   # 45 before version 140: a small step often dashed

const BAZAAR_AMBER := Color(1.0, 0.62, 0.3)   # the Bone Bazaar (version 152)
const SHOP_WELL := Color(0.04, 0.03, 0.06, 0.88)   # the Armory's card window (version 225)
const DOOR_TEXT_PAD := 34.0   # the door's words keep this far in from the archway's sides (v227)
const END_TEXT_W := 468.0   # the end screen's lines wrap at this width, clear of the edges (v227)
## Each Armory upgrade's picture on its card (version 225): a BlessingIcon picture and colour.
const ARMORY_ICONS := {
	"vigor": ["vitality", Color(0.95, 0.38, 0.42)],
	"might": ["damage", Color(1.0, 0.56, 0.28)],
	"haste": ["speed", Color(1.0, 0.84, 0.32)],
	"swift": ["boots", Color(0.42, 0.82, 1.0)],
	"luck": ["marrow", Color(0.52, 0.92, 0.56)],
	"blessed": ["door_shrine", Color(0.76, 0.58, 1.0)],
	"second_wind": ["ward", Color(0.6, 0.92, 0.95)],
	"buy_drop": ["ossuary", Color(0.93, 0.88, 0.76)],
}
const GOLD := Color(1.0, 0.8, 0.3)
## The chunky cartoon font for titles, buttons and big numbers (fonts/OFL-LilitaOne.txt).
const UI_FONT := preload("res://fonts/LilitaOne-Regular.ttf")
## The dark outline round chunky text and buttons.
const INK := Color(0.1, 0.05, 0.14)
## Button colours by job: [face, dark edge]. green = go, gold = buy and rewards, blue = normal,
## purple = looks, slate = quiet choices (later, back to title), red = danger.
const ROLES := {
	"green": [Color(0.36, 0.76, 0.2), Color(0.1, 0.32, 0.05)],
	"gold": [Color(1.0, 0.7, 0.12), Color(0.48, 0.24, 0.02)],
	"blue": [Color(0.22, 0.5, 0.94), Color(0.06, 0.15, 0.42)],
	"purple": [Color(0.58, 0.32, 0.92), Color(0.22, 0.07, 0.42)],
	"slate": [Color(0.3, 0.31, 0.43), Color(0.1, 0.1, 0.17)],
	"red": [Color(0.88, 0.26, 0.2), Color(0.4, 0.06, 0.04)],
}
## The game's name on the title screen (and in the opening animation, which lands on it), drawn
## by tools/store/make_logo.py at twice the size it is shown, glow and edge included.
const LOGO := preload("res://art/ui/logo.png")
const LOGO_WIDTH := 490.0

const STICK_RADIUS := 70.0

var joystick := Vector2.ZERO
## Where the stick last pointed, and when (Time.get_ticks_msec()): DASH uses it for a moment
## after the thumb lifts, since one thumb can't hold the stick and tap the button.
var last_move := Vector2.ZERO
var last_move_ms := -100000

var _safe: MarginContainer
var _hp_shown := Vector2i(-1, -1)
var _hp_fill: Control
var _hp_label: Label
var _room_label: Label
var _heroic_crest: Label   # version 152: a gold HEROIC under the pause button while Heroic is on
var _title_play_badge: Label   # HEROIC on PLAY while it's switched on
const BOSS_BADGE_ROOM := 52.0
var _boss_badge: BossBadge
var _boss_box: Control
var _boss_fill: Control
## Version 386 (visual review of v383, fix 4): a pale trail behind the boss bar's fill that
## catches up a moment after each hit, so every hit shows as a chunk coming off, and the
## health left as a number on the bar.
var _boss_trail: Panel
var _boss_hp: Label
var _trail_hold := 0.0
var _trail_last := 1.0
var _banner: Label
var _banner_w := 0.0   # the banner's text width, so its pop-in can stay on screen
var _wave_label: Label
var _wave_pips: Control
var _wave_now := 0
var _wave_total := 0
var _banner_time := 0.0
var _shown_hp := 1.0

var _stick: Joystick
var _stick_touch := -1
## Version 164: touches that began on DASH, the special or SURGE. Sliding off a button
## no longer turns that thumb into the stick.
var _button_touches := {}
var _stick_origin := Vector2.ZERO

var _cards_box: Control
var _cards_mastery: Label   # "WIZARD MASTERY 3!" over the cards after a mid-run level-up
var _cards_clock: Label     # in a race (version 156): the race clock, still running
var _cards: Array[Button] = []
var _cards_have: PanelContainer   # the row of blessings already held, over the cards
var _cards_row: HBoxContainer
var _cards_ready: Array[bool] = [false, false, false]   # a card can be picked once it's face up
var _cards_picking := false
var _cards_tweens: Array = []
const CARD_SIZE := Vector2(160, 368)
const CARD_GAP := 10
var _cards_have_row: HFlowContainer
var _reroll_button: Button
## Doors (doors.gd): two to pick from after a blessing.
var _doors_box: Control
var _door_buttons: Array[Button] = []
var _door_arches: Array[DoorArch] = []
var _doors_next: Label
var _doors_clock: Label     # in a race: the race clock, as on the blessing cards
var _doors_age := 0.0
var _special: SpecialButton
var _dash_button: DashButton
var _quit_button: Button
var _rate_button: Button   # v220: hidden in the tutorial
## Version 221 (v219 review): the pause menu shows RESUME, Music, Sounds, MORE SETTINGS and
## Quit; MORE SETTINGS opens the rest in place (the title's Settings always shows them all).
var _pause_more := false
var _pause_rows: Array[Control] = []
var _more_button: Button
var _quit_armed := false
var _pause_title: Label
const PAUSE_VEIL := Color(0.02, 0.015, 0.06, 0.5)   # v374: over a paused room (was black at 0.7 and a purple wash)
var _pause_run: Control       # v374: the run card (hero, place, room, coins, blessings)
var _pause_hero: Label
var _pause_where: Label
var _pause_room: Label
var _pause_coins: Label
var _pause_score: Label
var _pause_bless_head: Label
var _pause_bless: HFlowContainer
var _pause_hp: Label
var _pause_hp_fill: Control
var _room_text := ""          # "Room 3 / 5" or "Boss room", as the top bar counts it
var _hud_before_pause := true
var _pause_head: Label   # SETTINGS over the switches' card (hidden on the title's Settings)
var _resume_button: Button
var _settings_back: Button
## The pause menu opened from the title screen as Settings: BACK instead of RESUME, no Quit run.
var _settings_only := false
var _title_box: Control
var _title_logo: TextureRect
var _title_best: Label
## Gold lines under the best score: the Daily streak, today's coin bonus, the next goal.
var _title_goal: Label
var _end_box: Control
var _end_col: VBoxContainer
var _pause_build: Label
var _end_title: Label
var _end_stats: Label
## A gold line under the stats: the next goal after a death, the streak after the Daily.
var _end_goal: Label
var _pause_box: Control
var _pause_button: Button
var _score_shown := -1
var _danger: TextureRect
## The dark edge shade round the screen. Low graphics goes without it (v398): it is a
## see-through layer over every pixel of the screen, every frame.
var _vignette: TextureRect
var _beat_phase := 0.0
var _hint: Label
var _end_tap: Label
var _boss_name: Label
var _boss_flash: ColorRect
var _phase_box: Control
var _phase_title: Label
var _phase_sub: Label
var _phase_tw: Tween
var _cards_age := 0.0
var _fade: ColorRect
var _coin_label: Label
var _coins_box: Control
var _title_coins: Label
var _armory_box: Control
var _armory_coins: Label
var _armory_rows: VBoxContainer
var _shop_title: Label
var _shop_sub: Label
## The Armory's two tabs: UPGRADES and the VAULT (new blessings), and the rows last shown.
var _armory_tabs: Control
## Version 225: the cards scroll in a window; the coins sit in a purse by BACK.
var _armory_scroll: ScrollContainer
var _armory_purse: Control
var _armory_fades: Array = []
var _shop_down_at := 0
var _tab_buttons := {}
var _armory_tab := "upgrades"
var _bazaar_tab_badge: Label
var _shop_rows: Array = []
var _shop_coins := 0
var _title_hero: Label
var _copy_button: Button
var _end_buttons: Control
var _end_title_button: Control
var _end_title_btn: Button
var _music_button: Button
var _sounds_button: Button
var _music_on := true
var _sounds_on := true
var _graphics_button: Button
var _graphics_level := 3
var _speed_button: Button
var _shake_button: Button
var _shake_level := 2
var _flashes_button: Button
var _flashes_level := 2
var _left_button: Button
var _left_on := false
var _size_button: Button
var _size_level := 0
var _dark_button: Button
var _dark_light := false
var _vibration_button: Button
var _vibration_on := true
var _colorblind_button: Button
var _colorblind_on := false
var _reports_button: Button
var _fb_box: Control
var _fb_text: TextEdit
var _fb_note: Label
var _fb_send: Button
var _reports_on := false
var _hud_before_end := false
var _stick_start := Vector2.ZERO
## When the stick's touch began (Time.get_ticks_msec()). Real time, not game time: in slow
## motion a slow drag used to count as a quick flick and fire a dash (audit fix 2).
var _stick_start_ms := 0
var _chain_box: Control
## Where the slim chain row sits under the top bar, and how tall it is (version 135).
const TOP_SHADE := 118.0   # v380: how far down the shade behind the top row reaches
const CHAIN_TOP := 52.0   # v358: up in the top bar, beside the coins (v338: 90)
const CHAIN_H := 46.0   # v416: 34 -> 46, a bigger number over a fuse the whole width
const CHAIN_X := 158.0
const CHAIN_W := 216.0   # v392: 200 -> 216, the score on one line
var _chain_label: Label
var _chain_pop := 0.0
var _spine: ChainSpine
var _score_label: Label
var _chain_pill: Panel   # v392: grows with the score, so no empty end on the pill
var _broken_label: Label
var _broken_time := 0.0
var _top_shade: TextureRect
var _boss_broken: Label   # v380: CHAIN BROKEN in a boss fight, under the boss bar
var _tip: Label
var _tip_time := 0.0
var _tip_tag: Label
var _tip_pic: TextureRect
var _tip_sb: StyleBoxFlat
var _tip_delay := 0.0
var _shown_score := 0.0
var _end_score: Label
var _end_best: Label
var _end_target := 0
var _end_count := -1.0
var _end_best_value := 0
## Version 280: the Free Dive's score is no best, so its end screen shows no "Best" line.
var end_hide_best := false
## Version 122: the run's numbers fill in one line at a time after the score, each counting
## up with ticks and a little buzz, the way Archero and Brawl Stars hand out rewards.
var _tally: PackedStringArray = []
var _tally_i := -1          # the line counting up now (-1: not started or done)
var _tally_t := 0.0
var _tally_wait := false    # waiting for the score to finish counting
## Version 388 (v383 review fix 10): after a boss win the end screen is a reward moment: the
## hero cheering on a pedestal in gold light, the run's numbers in tiles that count up, and
## DESCEND as the one big button (the looks and Bone Drop buttons are small, side by side).
## Game sets `end_hero_def` (the hero as dressed) just before show_end of a win.
var end_hero_def := {}
var _end_hero: HeroStage
var _end_hero_box: Control
var _end_tiles: HBoxContainer
var _end_tile_vals: Array = []   # [value Label, note Label] per tile
var _end_after: Label   # the lines under the tiles (tips, unlocks)
var _end_extras: HFlowContainer   # SEE NEW LOOKS, OPEN BONE DROP and SHARE, side by side (v389: wraps)
var _tile_of := {}   # tally line index -> tile index (this end screen)
const END_TILES := {"Time": "TIME", "Skeletons destroyed": "SKELETONS", "Coins this run": "COINS", "Bone Road": "BONES"}
var _title_heroes: Control
var _title_armory: Control
var _title_lock: Label
var _title_shop_row: Control
var _title_pass_row: Control
var _title_modes_row: Control
var _title_modes_badge: Label
var _title_heroes_badge: Label
var _end_heroes_badge: Label   # the same tag on the end screen's HEROES button
var _title_armory_badge: Label   # UPGRADE: something in the Armory is affordable (version 150)
var _end_armory_badge: Label
var _modes_box: Control
var _records_box: Control
var _records_grid: GridContainer
var _records_note: Label
var _title_records: Control
var _leaders: LeaderScreen   # version 137: Daily Crypt and best-run leaderboards
var _rw_leaders: Control
var _daily_board: Button
var _title_settings: Control
var _title_drops: Button
var _end_drop: Button
var _end_looks: Button   # SEE 3 NEW LOOKS after a run that reached a Mastery level
var _end_looks_for := {}
var _end_mastery: MasteryBar
var _mastery: MasteryScreen
var _style: StyleScreen
var _drops: DropScreen
var _event: EventScreen
var _splash: EventArt.Splash   # version 135: an event or chapter beginning
var _title_event: EventArt.Banner
var _shard_box: Control
var _shard_label: Label
var _shard_icon: EventArt.ShardIcon
var _shard_pop := 0.0
var _surge_edge: TextureRect
var frost_edge: TextureRect   # version 243: the Blizzard
var _eclipse_dim: ColorRect
var _surge_warn := false
var _feats: FeatsScreen
var _toast: PanelContainer
var _toast_name: Label
var _toast_look: Label
var _toast_tween: Tween
var _title_road: RoadScreen.Bar
var _title_hint: Label
var _title_top: Control   # the words at the top of the title screen
var _title_bottom: Control   # the hero's name and the buttons at the bottom
var _title_gap: Control
var _road: RoadScreen
var _mode_daily_text: Label
var _mode_daily_tag: Label
var _mode_curses_tag: Label
var _mode_race_line: Label
var _mode_race_tag: Label
## The Crypt Race's screens, and its track on the left of the screen in a race.
var race_screen: RaceScreen
var race_bar: RaceScreen.Bar
var race_surge: SurgeButton   # the Crypt Race's SURGE button, left of the special
var _mode_curses_line: Label
var _modes_tutorial: Button
var _heroes_box: HeroScreen
var _end_offer: Control
var _end_offer_back: Button   # version 280: its words change for the Free Dive
var _end_get_pass: Button   # v218: shows the price
var _pass_card_btn: Control
var _pass_more: Label
var _pass_box: Control
var _pass_buy: Button
var _pass_status: Label
var _pass_restore: Button
var _pass_col: VBoxContainer   # v279: shrunk to fit on short phones
var _pass_deal: PanelContainer   # v279: the Early Access Deal ribbon
var _pass_was: Control   # v279: "Normally $4.99", struck through
var _pass_was_price: Label
var _deal_ribbons: Array[PanelContainer] = []   # v279: every deal ribbon, beating while shown
var _deal_tick := 0.0
var _title_pass_badge: Label   # v279: "40% OFF · 13 DAYS LEFT" on the title's CRYPT PASS
var _end_pass_badge: Label
var _end_deal: PanelContainer   # v279: the deal over the end-of-free-game offer
var _shop_curses := false
var _title_free: Label
var _title_play: Button
var _title_start: Button   # version 309
var _title_quick: Button   # version 310
var _title_small_row: Control   # version 310: START ON FLOOR and QUICK PLAY side by side
## Version 311: TODAY'S GOALS (today.gd), a row on REWARDS and its own screen.
var _rw_today: Button
var _rw_today_sub: Label
var _today_box: Control
var _today_rows: VBoxContainer
var _today_chest: Button
var _today_chest_note: Label
var _today_clock: Label
var _end_retry: Button   # version 309
var _title_continue: Control
var _continue_where: Label
var _title_spacer: Control
var _timer_label: Label
var _share_button: Button
var _share_card: ShareCard
var _end_pass: Control
var _pass_card: Control
var _pass_card_line: Label
var _end_spacer: Control
var _daily_box: Control
var _daily_title: Label
var _daily_theme: Label
var _daily_info: Label
var _daily_hero: HeroStage   # v396: the day's hero on the Daily screen
var _daily_hero_box: Control
var _daily_sky: Label   # the day's weather
var _daily_sky_icon: BlessingIcon
var _daily_rules: VBoxContainer
var _daily_status: Label
var _daily_go: Button
var _daily_next: Label
var _daily_open := false
var _pass_tiles: Array[Label] = []
var _pass_dev: Label
var _pass_back: Button
var _pass_dive: Button   # version 280
var _end_loop: Control
var _loop_deeper_button: Button
var _loop_bank_button: Button
var _omen_box: Control
var _ask_box: Control
var _rem_box: Control
var _lost_box: Control   # version 213: "Crypt Pass not found"
var _rem_text: Label
var _reminders_button: Button
var _reminders_on := false
var _omen_info: Label
var _omen_rows: VBoxContainer
var _omen_have: Label
var _callout: Label
var _callout_time := 0.0
var _boss_card: Control
var _boss_card_title: Label
var _boss_card_sub: Label
var _flash: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build_danger()
	_build_hud()
	_stick = Joystick.new()
	_stick.radius = STICK_RADIUS
	_stick.visible = false
	add_child(_stick)
	_build_cards()
	_build_doors()
	_build_title()
	_build_rewards()
	_build_end()
	_build_pause()
	_build_feedback()
	_build_modes()
	_build_records()
	_build_today()
	_build_armory()
	_build_heroes()
	_event = EventScreen.new()
	add_child(_event)
	_event.run_pressed.connect(func(): event_run.emit())
	_event.hunt_pressed.connect(func(t: int): event_hunt.emit(t))
	_event.claim.connect(func(i: int): event_claim.emit(i))
	_event.pass_pressed.connect(func(): pass_pressed.emit())
	_event.caskets_pressed.connect(func(): event_caskets.emit())
	_event.closed.connect(func(): event_closed.emit())
	_splash = EventArt.Splash.new()
	add_child(_splash)
	_splash.enter.connect(func():
		_splash.visible = false
		event_pressed.emit())
	_splash.later.connect(func():
		Sfx.play("click")
		_splash.visible = false)
	_splash.hunt.connect(func():
		_splash.visible = false
		event_hunt.emit(maxi(1, Events.tiers_open(Game._load_save()))))
	_drops = DropScreen.new()
	add_child(_drops)
	_drops.closed.connect(func(): drops_closed.emit())
	_drops.wear.connect(func(id: String, slot: String, key: String): found_wear.emit(id, slot, key))
	_drops.buy_look.connect(func(slot: String, key: String): bazaar_buy.emit(slot, key))
	_road = RoadScreen.new()
	add_child(_road)
	_road.claim.connect(func(i: int): road_claim.emit(i))
	_road.claim_all.connect(func(): road_claim_all.emit())
	_road.closed.connect(func(): road_closed.emit())
	race_screen = RaceScreen.new()
	add_child(race_screen)
	race_screen.race_pressed.connect(func(): race_find.emit())
	race_screen.go.connect(func(): race_go.emit())
	race_screen.again.connect(func(): race_again.emit())
	race_screen.claim.connect(func(i: int): race_claim.emit(i))
	race_screen.to_title.connect(func(): race_to_title.emit())
	race_screen.closed.connect(func(): show_modes(true))
	_mastery = MasteryScreen.new()
	add_child(_mastery)
	_mastery.style.connect(func(id: String): style_pressed.emit(id))
	_mastery.see_new.connect(func(id: String, lv: int): see_looks.emit(id, lv))
	_mastery.train.connect(func(id: String): mastery_train.emit(id))
	_style = StyleScreen.new()
	add_child(_style)
	_style.wear.connect(func(id: String, slot: String, key: String): style_wear.emit(id, slot, key))
	_style.get_pass.connect(func(): pass_pressed.emit())
	_style.feats.connect(func(): feats_pressed.emit())
	_feats = FeatsScreen.new()
	add_child(_feats)
	# Back on the Style screen after the Feats screen: its button no longer says NEW!.
	_feats.closed.connect(func():
		if _style.visible:
			_style.refresh_feats_button()
		refresh_rewards())
	_style.closed.connect(func():
		# The Heroes screen's pedestal draws again once the Style screen is gone.
		if _heroes_box.visible:
			_heroes_box._stage.set_active(true)
		style_closed.emit(_style.hero_id()))
	_build_daily()
	_leaders = LeaderScreen.new()
	add_child(_leaders)
	_build_omens()
	_build_reports_ask()
	_build_reminders_ask()
	_build_pass_lost()
	_build_pass()
	_build_boss_card()
	_build_phase_banner()
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Big hits flash the edges of the screen, not the middle, so the hero never vanishes
	# in a white wash.
	var fsh := Shader.new()
	fsh.code = """
shader_type canvas_item;
void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	COLOR.a *= mix(0.2, 1.0, smoothstep(0.35, 1.15, r));
}
"""
	var fm := ShaderMaterial.new()
	fm.shader = fsh
	_flash.material = fm
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()


# ---------------------------------------------------------------- building

## The smallest text size (version 148, accessibility review item 2): 16 game px is about
## 12 sp on a phone, Android's smallest size for reading text. 14-15 px lines were ~10-11 sp.
const MIN_TEXT := 16


static func label(text: String, size: int, col := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	size = maxi(size, MIN_TEXT)
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := LabelSettings.new()
	s.font_size = size
	s.font_color = col
	s.outline_size = maxi(4, size / 8)
	s.outline_color = Color(0, 0, 0, 0.85)
	if size >= 26:
		chunky(s)   # titles and big numbers: the cartoon font with a thick edge and a drop shadow
	l.label_settings = s
	return l


## Big text in the chunky look: the cartoon font, a thick dark edge and a soft drop shadow.
static func chunky(s: LabelSettings) -> void:
	s.font = UI_FONT
	s.outline_size = maxi(6, s.font_size / 5)
	s.outline_color = INK
	s.shadow_size = s.outline_size
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_offset = Vector2(0, maxf(2.0, s.font_size / 11.0))


## Behind a full-screen menu (solid, `r.color.a` over 0.93): the lit crypt wall, in
## `theme`'s light (MenuBackdrop, version 130). Behind a see-through one (pause, the end of a
## run, cards and doors over the room): a deep blue-purple glow, so the room still shows.
## Version 159: the glow takes the moment's mood: "crypt" blue-purple, "death" a deep blood
## red from the top (YOU DIED), "victory" warm gold. Three tiny cached textures, no shader.
static var _glow_tex := {}
const GLOWS := {
	"crypt": [Color(0.22, 0.16, 0.4), Color(0.05, 0.035, 0.11)],
	"death": [Color(0.27, 0.045, 0.08), Color(0.04, 0.012, 0.035)],
	"victory": [Color(0.42, 0.28, 0.1), Color(0.07, 0.04, 0.06)],
}

static func glow_texture(mood: String) -> GradientTexture2D:
	if not GLOWS.has(mood):
		mood = "crypt"
	if not _glow_tex.has(mood):
		var g := Gradient.new()
		g.set_color(0, GLOWS[mood][0])
		g.set_color(1, GLOWS[mood][1])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.28 if mood == "crypt" else 0.12)
		t.fill_to = Vector2(1.15, 1.0)
		t.width = 128
		t.height = 256
		_glow_tex[mood] = t
	return _glow_tex[mood]


## Swaps the mood of a see-through overlay's glow (see backdrop).
static func set_glow(r: ColorRect, mood: String) -> void:
	var t := r.get_node_or_null("Glow") as TextureRect
	if t:
		t.texture = glow_texture(mood)


static func backdrop(r: ColorRect, theme := "crypt") -> void:
	if r.color.a > 0.93:
		MenuBackdrop.add_to(r, theme)
		return
	var t := TextureRect.new()
	t.name = "Glow"
	t.texture = glow_texture("crypt")
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.modulate.a = r.color.a
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.add_child(t)


## A soft dark panel behind teaching text, so it reads on any floor.
## Version 360 (review of 357, fix 3): tips are a designed card, not a black box: deep
## violet with a warm gold edge and a soft shadow, a little name tag on top (Hud.tip).
static func _tip_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.08, 0.22, 0.94)
	sb.set_corner_radius_all(18)
	sb.border_color = Color(0.98, 0.78, 0.42, 0.95)
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 9
	return sb


static func _text_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.01, 0.04, 0.62)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


## The logo picture's size on screen.
static func logo_size() -> Vector2:
	return Vector2(LOGO_WIDTH, LOGO_WIDTH * LOGO.get_height() / LOGO.get_width())


## The logo picture, at its size on screen.
static func logo_rect() -> TextureRect:
	var r := TextureRect.new()
	r.texture = LOGO
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.custom_minimum_size = logo_size()
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func title_logo() -> Control:
	return _title_logo


static func full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


static func overlay(dim: Color, theme := "crypt") -> ColorRect:
	var r := ColorRect.new()
	r.color = dim
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	r.visible = false
	if dim.a > 0.69:   # (not 0.7: colours are stored as 32-bit floats)
		backdrop(r, theme)
	return r


static func button(text: String, size := 28, bg := Color(0.16, 0.12, 0.2, 0.95), border := Color(1, 0.8, 0.45, 0.6)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(300, 74)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(1, 0.93, 0.8))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1, 0.93, 0.8))
	var role := _role_for(text, bg, border)
	if role != "":
		# A chunky cartoon button: bright face, dark edge and lip, white outlined letters.
		b.add_theme_font_override("font", UI_FONT)
		b.add_theme_font_size_override("font_size", size + 2)
		b.add_theme_constant_override("outline_size", maxi(6, size / 4))
		b.add_theme_color_override("font_outline_color", INK)
		for c in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, Color.WHITE)
		b.add_theme_color_override("font_disabled_color", Color(0.8, 0.8, 0.85))
		paint(b, role)
		squash(b)
		return b
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.set_corner_radius_all(14)
	normal.set_border_width_all(2)
	normal.border_color = border
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.lightened(0.2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", normal)
	return b


## Which colour job a button has, from the colours the screen asked for (rows and cards
## with their own content, "" or several lines on a dark box, keep their flat look).
static func _role_for(text: String, bg: Color, border: Color) -> String:
	if text == "" or ("\n" in text and bg.v < 0.25):
		return ""
	if bg.g > bg.r and bg.g > bg.b and bg.s > 0.3:
		return "green"
	if bg.r >= 0.28 and bg.b < 0.15 and bg.g >= 0.5 * bg.r:
		return "gold"
	if bg.r >= 0.3 and bg.g < 0.5 * bg.r:
		return "green"   # PLAY, TRY AGAIN, RESUME: the main way on
	if bg.b > bg.r and bg.r > bg.g and bg.s > 0.45:
		return "purple"
	if bg.v < 0.13 and border.v < 0.7:
		return "slate"
	return "blue"


## Gives button `b` the chunky look in colour `role` (see ROLES); used again to recolour
## tabs and the hero screen's action button.
static func paint(b: Button, role: String) -> void:
	var face: Color = ROLES[role][0]
	var edge: Color = ROLES[role][1]
	var normal := StyleBoxFlat.new()
	normal.bg_color = face
	normal.border_color = edge
	normal.set_corner_radius_all(18)
	normal.set_border_width_all(3)
	normal.border_width_bottom = 9   # the lip under the face, like a thick toy button
	normal.shadow_color = Color(0, 0, 0, 0.35)
	normal.shadow_size = 2
	normal.shadow_offset = Vector2(0, 4)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.anti_aliasing_size = 1.2
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = face.darkened(0.1)
	pressed.border_width_bottom = 4
	pressed.border_width_top = 7   # the face sinks into its lip
	pressed.shadow_offset = Vector2(0, 1)
	var off := normal.duplicate() as StyleBoxFlat
	off.bg_color = face.lerp(Color(0.35, 0.35, 0.4), 0.7)
	off.border_color = edge.lerp(Color(0.1, 0.1, 0.12), 0.6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# A soft shine across the top half of the face.
	var gloss := b.get_node_or_null("Gloss") as Panel
	if gloss == null:
		gloss = Panel.new()
		gloss.name = "Gloss"
		gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g := StyleBoxFlat.new()
		g.bg_color = Color(1, 1, 1, 0.14)
		g.corner_radius_top_left = 14
		g.corner_radius_top_right = 14
		g.corner_radius_bottom_left = 6
		g.corner_radius_bottom_right = 6
		gloss.add_theme_stylebox_override("panel", g)
		gloss.anchor_right = 1.0
		gloss.anchor_bottom = 0.42
		gloss.offset_left = 6
		gloss.offset_top = 5
		gloss.offset_right = -6
		b.add_child(gloss, false, Node.INTERNAL_MODE_FRONT)
	if not b.has_meta("gloss_hooked"):
		b.set_meta("gloss_hooked", true)
		b.button_down.connect(func(): gloss.offset_top = 9)
		b.button_up.connect(func(): gloss.offset_top = 5)


## A quick squash when pressed and a bounce back on release.
static func squash(b: Button) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	b.button_down.connect(func():
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2(0.95, 0.93), 0.06))
	b.button_up.connect(func():
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))


## A chunky round button drawn on `c` (the DASH and special buttons): a darker lip under a
## coloured face, an ink edge and a shine on top. `lit` false draws it dark and quiet.
static func draw_round_button(c: CanvasItem, centre: Vector2, r: float, face: Color, lit: bool) -> void:
	var f := face if lit else Color(0.16, 0.13, 0.22, 0.85)
	var lip := f.darkened(0.45)
	lip.a = f.a
	c.draw_circle(centre + Vector2(0, 5), r + 3.0, Color(0, 0, 0, 0.3))   # shadow
	c.draw_circle(centre + Vector2(0, 4), r, lip)
	c.draw_circle(centre, r, f)
	# The shine: a soft lighter cap on the top half of the face.
	var cap := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		cap.append(centre + Vector2(cos(a) * r * 0.8, sin(a) * r * 0.72 - r * 0.02))
	c.draw_colored_polygon(cap, Color(1, 1, 1, 0.16 if lit else 0.06))
	c.draw_arc(centre, r, 0.0, TAU, 48, INK, 3.5, true)
	c.draw_arc(centre + Vector2(0, 4), r, 0.15, PI - 0.15, 32, INK, 3.5, true)


## A little gold coin drawn with a rounded box.
static func coin_icon(size: float) -> Control:
	var p := Control.new()
	p.custom_minimum_size = Vector2(size, size)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.draw.connect(func(): draw_coin(p, p.size * 0.5, minf(p.size.x, p.size.y) * 0.5))
	return p


## A shaded gold coin: an ink edge, a darker rim, a raised face with a ring pressed into it
## and a shine on its upper left.
static func draw_coin(c: CanvasItem, centre: Vector2, r: float) -> void:
	c.draw_circle(centre + Vector2(0, r * 0.12), r, Color(0, 0, 0, 0.35))
	c.draw_circle(centre, r, INK)
	c.draw_circle(centre, r * 0.86, Color(0.82, 0.5, 0.06))
	c.draw_circle(centre + Vector2(0, -r * 0.06), r * 0.72, GOLD)
	c.draw_arc(centre + Vector2(0, -r * 0.04), r * 0.5, 0.0, TAU, 24, Color(0.85, 0.55, 0.08), maxf(1.0, r * 0.1), true)
	c.draw_arc(centre, r * 0.62, PI * 1.05, PI * 1.6, 12, Color(1, 1, 0.9, 0.85), maxf(1.0, r * 0.13), true)


## A coin icon with a number next to it.
## A small "Privacy policy" button that opens the policy page in the browser.
static func privacy_button(text_size := 18) -> Button:
	var b := button("Privacy policy", text_size, Color(0.08, 0.07, 0.1, 0.85), Color(0.6, 0.55, 0.6, 0.4))
	b.add_theme_color_override("font_color", Color(0.75, 0.72, 0.78))
	b.custom_minimum_size = Vector2(200, 64)
	b.pressed.connect(func(): OS.shell_open(Game.PRIVACY_URL))
	return b


static func coin_row(text_size: int, parent: Control, centered := false) -> Label:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	if centered:
		row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	var icon := coin_icon(text_size * 0.9)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var l := label("0", text_size, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(l)
	return l


## A chunky bar (the hero's health, a boss's health): a dark rounded trough with an ink
## edge, a glossy fill with a darker lip under it. Returns the fill; its anchor_right is
## how full the bar is.
func _bar(parent: Control, fill_col: Color) -> Control:
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fb := StyleBoxFlat.new()
	fb.bg_color = Color(0.12, 0.08, 0.16, 0.92)
	fb.border_color = INK
	fb.set_border_width_all(3)
	fb.set_corner_radius_all(10)
	fb.shadow_color = Color(0, 0, 0, 0.35)
	fb.shadow_size = 2
	fb.shadow_offset = Vector2(0, 3)
	frame.add_theme_stylebox_override("panel", fb)
	parent.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var trough := Control.new()
	trough.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trough.clip_contents = true
	frame.add_child(trough)
	trough.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trough.offset_left = 4
	trough.offset_top = 4
	trough.offset_right = -4
	trough.offset_bottom = -4
	var fill := Panel.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill_col
	sb.border_color = fill_col.darkened(0.35)
	sb.border_width_bottom = 4   # the darker lip
	sb.set_corner_radius_all(6)
	fill.add_theme_stylebox_override("panel", sb)
	trough.add_child(fill)
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shine := ColorRect.new()
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.color = Color(1, 1, 1, 0.22)
	fill.add_child(shine)
	shine.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shine.offset_left = 4
	shine.offset_right = -4
	shine.offset_top = 2
	shine.offset_bottom = 5
	return fill


func _build_hud() -> void:
	add_child(EdgeMarkers.new())
	_safe = MarginContainer.new()
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(_safe)
	add_child(_safe)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(root)
	# Version 380 (visual review of 375, fix 5): a soft dark shade behind the top row, so
	# health, coins, chain, score and the room's name read as one bar instead of stickers
	# over whatever walks under them. It reaches up past the top (the notch strip).
	var shade := TextureRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.01, 0.05, 0.62))
	grad.set_color(1, Color(0.02, 0.01, 0.05, 0.0))
	grad.add_point(0.55, Color(0.02, 0.01, 0.05, 0.4))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shade.offset_top = -80
	shade.offset_bottom = TOP_SHADE
	root.add_child(shade)
	_top_shade = shade

	var hp := Control.new()
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Version 338 (visual review fix 3, clean HUD): the bar starts under the hero badge.
	hp.position = Vector2(46, 14)
	hp.size = Vector2(212, 36)
	root.add_child(hp)
	_hp_fill = _bar(hp, Color(0.92, 0.2, 0.24))
	_hp_label = label("100 / 100", 20)
	chunky(_hp_label.label_settings)
	_hp_label.label_settings.outline_size = 5
	_hp_label.label_settings.shadow_size = 0
	full(_hp_label)
	hp.add_child(_hp_label)
	# The hero's face at the left end of the health bar (hero_badge.gd).
	var badge := HeroBadge.new()
	badge.position = Vector2(6, 5)
	badge.size = Vector2(54, 54)
	root.add_child(badge)

	var coins := Control.new()
	_coins_box = coins
	coins.z_index = 2   # (v404: drawn over the boss plate, which it sits in during a boss fight)
	coins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coins.position = Vector2(64, 54)
	coins.size = Vector2(200, 30)
	root.add_child(coins)
	_coin_label = coin_row(24, coins)
	chunky(_coin_label.label_settings)
	_coin_label.label_settings.outline_size = 6

	# Moon Shards earned this run, in an event (events.gd), under the coins.
	_shard_box = HBoxContainer.new()
	_shard_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shard_box.position = Vector2(64, 86)   # v358: under the coins (the chain strip sits beside them)
	_shard_box.size = Vector2(200, 32)
	(_shard_box as HBoxContainer).add_theme_constant_override("separation", 6)
	_shard_box.visible = false
	root.add_child(_shard_box)
	_shard_icon = EventArt.ShardIcon.new(30.0)
	_shard_icon.glow = 1.0
	_shard_box.add_child(_shard_icon)
	_shard_label = label("0", 24, Color(1.0, 0.78, 0.76), HORIZONTAL_ALIGNMENT_LEFT)
	chunky(_shard_label.label_settings)
	_shard_label.label_settings.outline_size = 6
	_shard_label.label_settings.outline_color = Color(0.25, 0.0, 0.04)
	_shard_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_shard_label.pivot_offset = Vector2(0, 16)
	_shard_box.add_child(_shard_label)

	_heroic_crest = label("HEROIC", 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	chunky(_heroic_crest.label_settings)
	_heroic_crest.label_settings.outline_size = 5
	_heroic_crest.label_settings.outline_color = Color(0.25, 0.14, 0.0)
	_heroic_crest.autowrap_mode = TextServer.AUTOWRAP_OFF
	_heroic_crest.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_heroic_crest.offset_left = -92
	_heroic_crest.offset_right = 0
	_heroic_crest.offset_top = 72
	_heroic_crest.offset_bottom = 94
	_heroic_crest.visible = false
	root.add_child(_heroic_crest)
	_room_label = label("", 24, Color(1, 0.97, 0.9), HORIZONTAL_ALIGNMENT_RIGHT)   # v388: 22 -> 24
	chunky(_room_label.label_settings)
	_room_label.label_settings.outline_size = 6
	_room_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_room_label.offset_left = -284
	_room_label.offset_right = -84
	_room_label.offset_top = 12
	_room_label.offset_bottom = 48
	root.add_child(_room_label)
	race_bar = RaceScreen.Bar.new()
	race_bar.position = Vector2(4, 92)   # v358: under the top bar (the chain strip moved up into it)
	race_bar.visible = false
	root.add_child(race_bar)

	_wave_label = label("", 20, Color(1, 0.62, 0.45), HORIZONTAL_ALIGNMENT_RIGHT)
	chunky(_wave_label.label_settings)
	_wave_label.label_settings.outline_size = 5
	_wave_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_wave_label.offset_left = -284
	_wave_label.offset_right = -84
	_wave_label.offset_top = 44
	_wave_label.offset_bottom = 74
	_wave_label.visible = false
	root.add_child(_wave_label)
	# Version 338: waves as a row of pips under the room name instead of "Wave 2 / 3" words.
	_wave_pips = Control.new()
	_wave_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_pips.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_wave_pips.offset_left = -284
	_wave_pips.offset_right = -84
	_wave_pips.offset_top = 47
	_wave_pips.offset_bottom = 71
	_wave_pips.visible = false
	_wave_pips.draw.connect(_draw_wave_pips)
	root.add_child(_wave_pips)

	# The Hourglass curse's countdown, under the wave counter.
	_timer_label = label("", 20, Color(1, 0.75, 0.5), HORIZONTAL_ALIGNMENT_RIGHT)
	_timer_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_timer_label.offset_left = -284
	_timer_label.offset_right = -84
	_timer_label.offset_top = 72
	_timer_label.offset_bottom = 100
	_timer_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_timer_label.visible = false
	root.add_child(_timer_label)

	_special = SpecialButton.new()
	_special.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_special.offset_left = -124
	_special.offset_right = -24
	# Version 213 (hardest review fix #7): the buttons sit in the dark strip under the room's
	# near wall, so the hero is never fighting under them (they were at y 820-1040, where the
	# hero stands near the bottom of a room).
	_special.offset_top = -144
	_special.offset_bottom = -44
	root.add_child(_special)
	race_surge = SurgeButton.new()
	race_surge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	race_surge.offset_left = -318
	race_surge.offset_right = -234
	race_surge.offset_top = -136
	race_surge.offset_bottom = -52
	race_surge.visible = false
	root.add_child(race_surge)

	_dash_button = DashButton.new()
	_dash_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_dash_button.offset_left = -224
	_dash_button.offset_right = -144
	_dash_button.offset_top = -134
	_dash_button.offset_bottom = -54
	root.add_child(_dash_button)

	_pause_button = Button.new()
	_pause_button.text = "II"
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.add_theme_font_size_override("font_size", 22)
	_pause_button.add_theme_font_override("font", UI_FONT)
	_pause_button.add_theme_constant_override("outline_size", 6)
	_pause_button.add_theme_color_override("font_outline_color", INK)
	paint(_pause_button, "slate")
	for st in ["normal", "hover", "pressed"]:
		var pb := _pause_button.get_theme_stylebox(st).duplicate() as StyleBoxFlat
		pb.set_corner_radius_all(16)
		pb.content_margin_left = 0
		pb.content_margin_right = 0
		_pause_button.add_theme_stylebox_override(st, pb)
	squash(_pause_button)
	_pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_button.offset_left = -78   # 64 x 64 (version 147; 60 in version 125, audit #9): a thumb-sized target
	_pause_button.offset_right = -14
	_pause_button.offset_top = 6
	_pause_button.offset_bottom = 70
	_pause_button.mouse_filter = Control.MOUSE_FILTER_IGNORE   # v282: _input takes its presses (any finger)
	_pause_button.pressed.connect(func():
		if Game.state == Game.State.PLAYING:
			Sfx.play("click")
		pause_pressed.emit())
	root.add_child(_pause_button)

	# A tip in the empty space at the bottom of the screen during the first room.
	_hint = label("", 27, Color(1, 0.94, 0.78))
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -210
	_hint.offset_right = 210
	# (Version 211, Tweaks report #3: 48 px lower. At -128 it covered the hero where each
	# run starts, and the special button's name.)
	# (Version 216: DASH and the special sit at y ~1066-1156 and the hero just above them, so
	# the tip goes above the hero.)
	# (Version 360, review of 357 fix 3: down in the tip's place, over the strip past the near
	# wall; at -446 it sat on the hero's head where each run starts. A tip takes its place
	# while one shows.)
	_hint.offset_top = -198
	_hint.offset_bottom = -158
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN   # two lines grow up, never off the bottom
	_hint.label_settings.outline_size = 7
	_hint.add_theme_stylebox_override("normal", _tip_panel())
	_hint.set_script(Pulse)
	_hint.set("low", 0.75)   # a lesson must stay readable at every point of the pulse
	_hint.visible = false
	root.add_child(_hint)

	_boss_box = Control.new()
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_box.offset_left = 30
	_boss_box.offset_right = -30
	_boss_box.offset_top = 60
	_boss_box.offset_bottom = 112
	root.add_child(_boss_box)
	# Version 404 (re-review of v400, fix 4): the name and bar sit on a solid dark plate, so a
	# bright boss or a flash behind never washes the bar out (the Lich's did, mid-fight).
	var plate := Panel.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plsb := StyleBoxFlat.new()
	plsb.bg_color = Color(0.05, 0.02, 0.05, 0.9)
	plsb.set_corner_radius_all(14)
	plsb.border_color = Color(1.0, 0.8, 0.6, 0.35)
	plsb.set_border_width_all(2)
	plate.add_theme_stylebox_override("panel", plsb)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.offset_left = -10
	plate.offset_right = 10
	plate.offset_top = -4
	plate.offset_bottom = 8
	_boss_box.add_child(plate)
	_boss_name = label(SkeletonKing.DISPLAY_NAME, 20, Color(1, 0.8, 0.6))
	chunky(_boss_name.label_settings)
	_boss_name.label_settings.outline_size = 5
	_boss_name.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_name.offset_bottom = 26
	_boss_name.offset_right = -BOSS_BADGE_ROOM
	_boss_box.add_child(_boss_name)
	# Version 413 (re-review of v410, fix 3): the boss's own badge at the plate's right end,
	# a crowned skull in its colour, so the bar says whose it is at a glance.
	_boss_badge = BossBadge.new()
	_boss_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_badge.anchor_left = 1.0
	_boss_badge.anchor_right = 1.0
	_boss_badge.offset_left = -BOSS_BADGE_ROOM + 4.0
	_boss_badge.offset_right = 4.0
	_boss_badge.offset_top = -2.0
	_boss_badge.offset_bottom = BOSS_BADGE_ROOM - 6.0
	_boss_box.add_child(_boss_badge)
	var bar_holder := Control.new()
	bar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_holder.offset_top = -26
	bar_holder.offset_right = -BOSS_BADGE_ROOM
	_boss_box.add_child(bar_holder)
	_boss_fill = _bar(bar_holder, Color(0.75, 0.1, 0.12))
	_boss_trail = Panel.new()
	_boss_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(1.0, 0.93, 0.8, 0.9)
	tsb.set_corner_radius_all(6)
	_boss_trail.add_theme_stylebox_override("panel", tsb)
	_boss_fill.get_parent().add_child(_boss_trail)
	_boss_fill.get_parent().move_child(_boss_trail, 0)
	_boss_trail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boss_hp = label("", 18, Color(1, 0.98, 0.95))
	chunky(_boss_hp.label_settings)
	_boss_hp.label_settings.outline_size = 6
	_boss_hp.label_settings.outline_color = Color(0.1, 0.02, 0.03)
	_boss_hp.autowrap_mode = TextServer.AUTOWRAP_OFF
	full(_boss_hp)
	_boss_hp.offset_top = -2
	_boss_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT   # (v413: off the middle, where Phase 2's tick runs)
	_boss_hp.offset_right = -10
	# Version 121: a notch at half health shows from the start where Phase 2 begins, and a
	# white flash lights the bar when it does.
	# v389 (review v388 fix 1): a small gold diamond under the bar's middle marks Phase 2; a
	# line from edge to edge ran through the HP number there.
	# A dark edge round it keeps it seen over a bright boss (the Star Eater's gold crown).
	for d: Array in [[8.0, Color(0.1, 0.02, 0.03)], [5.0, Color(1.0, 0.86, 0.5)]]:
		var r: float = d[0]
		var notch := ColorRect.new()
		notch.color = d[1]
		notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		notch.anchor_left = 0.5
		notch.anchor_right = 0.5
		notch.anchor_top = 1.0
		notch.anchor_bottom = 1.0
		notch.offset_left = -r
		notch.offset_right = r
		notch.offset_top = 5.0 - r
		notch.offset_bottom = 5.0 + r
		notch.pivot_offset = Vector2(r, r)
		notch.rotation = PI / 4.0
		bar_holder.add_child(notch)
	# (v413: and a tick right across the bar at half, where Phase 2 begins)
	for d: Array in [[3.0, Color(0.1, 0.02, 0.03)], [1.5, Color(1.0, 0.86, 0.5)]]:
		var w: float = d[0]
		var tick := ColorRect.new()
		tick.color = d[1]
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.anchor_left = 0.5
		tick.anchor_right = 0.5
		tick.anchor_bottom = 1.0
		tick.offset_left = -w
		tick.offset_right = w
		tick.offset_top = -3.0
		tick.offset_bottom = 3.0
		bar_holder.add_child(tick)
	_boss_flash = ColorRect.new()
	_boss_flash.color = Color(1, 1, 1, 0)
	_boss_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(_boss_flash)
	bar_holder.add_child(_boss_flash)
	bar_holder.add_child(_boss_hp)
	# Version 380 (visual review of 375, fix 5): a broken chain in a boss fight is told just
	# under the boss bar. Before, the chain strip faded in over the boss's name to say it.
	_boss_broken = label("", 18, Color(1, 0.38, 0.32))
	chunky(_boss_broken.label_settings)
	_boss_broken.label_settings.outline_size = 6
	_boss_broken.autowrap_mode = TextServer.AUTOWRAP_OFF
	_boss_broken.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_boss_broken.offset_top = 4
	_boss_broken.offset_bottom = 30
	_boss_broken.modulate.a = 0.0
	_boss_box.add_child(_boss_broken)
	_boss_box.visible = false

	# Bone Chain: a spine of six vertebrae across the top with the multiplier beside it, and
	# the run score under them. The cord behind the bones drains until the next kill.
	# Version 135: one slim row (it used to stack three rows down into the room).
	_chain_box = Control.new()
	_chain_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Version 358 (review of 357, fix 2): the strip moved up into the top bar, between the
	# coins and the room's name, at about half its old size, so nothing of it hangs over
	# the far end of the room where skeletons walk in (it sat 180-276 px down the phone).
	_chain_box.position = Vector2(CHAIN_X, CHAIN_TOP)
	_chain_box.size = Vector2(CHAIN_W, CHAIN_H)
	_chain_box.modulate.a = 0.0
	root.add_child(_chain_box)
	var pill := Panel.new()
	_chain_pill = pill
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.03, 0.02, 0.06, 0.72)   # v386: was 0.42, the bones were lost on the floor
	psb.set_corner_radius_all(16)
	psb.border_color = Color(1.0, 0.85, 0.55, 0.28)
	psb.set_border_width_all(2)
	pill.add_theme_stylebox_override("panel", psb)
	pill.position = Vector2(-4, -2)
	pill.size = Vector2(CHAIN_W + 8, CHAIN_H + 4)
	_chain_box.add_child(pill)
	# v392 (review v388 fix 4): the chain is one big number with a fuse bar under it (seven
	# little grey bones read as nothing on a phone), and the score sits on one line,
	# "SCORE 1,234", instead of a tiny word over a small number.
	_spine = ChainSpine.new()
	_spine.bar = true
	# (v404, re-review of v400 fix 4: a thicker fuse and a bigger number)
	# Version 416 (re-review of v410, fix 6: "the chain number is the dimmest thing on the top
	# bar"): the fuse runs the whole width of the pill under the number and the score, 12 px
	# thick, and the number is bigger, always in the chain's colour.
	_spine.position = Vector2(4, CHAIN_H - 13)
	_spine.size = Vector2(CHAIN_W - 4, 12)
	_chain_box.add_child(_spine)
	_chain_label = label("x1.0", 38, ChainSpine.BONE, HORIZONTAL_ALIGNMENT_CENTER)
	chunky(_chain_label.label_settings)   # v386: big chunky number, like the score
	_chain_label.label_settings.outline_size = 8
	_chain_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_chain_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chain_label.position = Vector2(0, -8)
	_chain_label.size = Vector2(84, 42)
	_chain_label.pivot_offset = Vector2(42, 22)
	_chain_box.add_child(_chain_label)
	var divider := ColorRect.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.color = Color(1, 1, 1, 0.14)
	divider.position = Vector2(85, 4)
	divider.size = Vector2(2, 26)
	_chain_box.add_child(divider)
	var caption := label("SCORE", 13, Color(1.0, 0.85, 0.55, 0.95))
	chunky(caption.label_settings)
	caption.label_settings.outline_size = 3
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.position = Vector2(91, 2)
	caption.size = Vector2(46, 30)
	_chain_box.add_child(caption)
	_score_label = label("", 21, Color(1.0, 0.97, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
	chunky(_score_label.label_settings)
	_score_label.label_settings.outline_size = 5
	_score_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score_label.position = Vector2(139, 1)
	_score_label.size = Vector2(CHAIN_W - 141, 32)
	_chain_box.add_child(_score_label)
	# Version 227: chunky and edged like the number it replaces (thin red letters were hard
	# to read over a busy floor).
	_broken_label = label("", 19, Color(1, 0.38, 0.32))
	chunky(_broken_label.label_settings)
	_broken_label.label_settings.outline_size = 6
	_broken_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_broken_label.position = Vector2(0, 0)
	_broken_label.size = Vector2(CHAIN_W, CHAIN_H)
	_broken_label.modulate.a = 0.0
	_chain_box.add_child(_broken_label)

	# First-run tips ("Kill fast. Your chain grows.") and the first-meeting lines ("BOMBER:
	# runs in and explodes"). Big, short and on a dark panel, so young players and anyone on
	# a small screen can read them over the fight. Version 240 (whole-game review fix 15):
	# low on the screen, just over DASH and the special. Under the chain meter they were a
	# dark strip over the top of the room, just where new skeletons come in.
	# Version 338 (clean HUD): a smaller pill (was 27 over 500 wide) so it covers less fight.
	_tip = label("", 23, Color(1, 0.96, 0.84))
	_tip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tip.offset_left = -220
	_tip.offset_right = 220
	_tip.offset_top = -198
	_tip.offset_bottom = -158
	_tip.grow_vertical = Control.GROW_DIRECTION_BEGIN   # longer tips grow up, clear of the buttons
	_tip.label_settings.outline_size = 5
	_tip.label_settings.outline_color = Color(0.06, 0.02, 0.1, 0.9)
	_tip.autowrap_mode = TextServer.AUTOWRAP_OFF   # v373: a tip is one line (_fit_tip)
	_tip_sb = _tip_panel()
	_tip.add_theme_stylebox_override("normal", _tip_sb)
	_tip.visible = false
	root.add_child(_tip)
	# Version 373 (visual review v366 fix 6): a small round picture of the skeleton, danger
	# or hero the tip is about, standing out of the card's left end.
	_tip_pic = TextureRect.new()
	_tip_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tip_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tip_pic.size = TIP_PIC
	_tip_pic.visible = false
	_tip.add_child(_tip_pic)
	_tip_tag = label("", 15, Color(1, 0.97, 0.9))
	chunky(_tip_tag.label_settings)
	_tip_tag.label_settings.outline_size = 4
	_tip_tag.label_settings.outline_color = Color(0.2, 0.04, 0.04)
	_tip_tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tip_tag.position = Vector2(16, -15)
	_tip.add_child(_tip_tag)

	_callout = label("", 46, Color(0.6, 0.95, 1.0))
	# v392 (review v388 fix 4): callouts have their own lane just under the top bar (or the
	# boss bar), where no hero or skeleton number goes; in the middle of the room they sat
	# on the skeletons coming in. See _show_callout.
	_callout.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_callout.offset_left = 40
	_callout.offset_right = -40
	_callout.offset_top = CALLOUT_LANE
	_callout.offset_bottom = CALLOUT_LANE + 56
	# On a dark see-through strip, so a word over a boss's head still reads and the boss
	# still shows through (critic of fix 4).
	var cb := StyleBoxFlat.new()
	cb.bg_color = Color(0.03, 0.02, 0.06, 0.62)
	cb.set_corner_radius_all(18)
	cb.content_margin_left = 18
	cb.content_margin_right = 18
	cb.content_margin_top = 2
	cb.content_margin_bottom = 2
	_callout.add_theme_stylebox_override("normal", cb)
	_callout.autowrap_mode = TextServer.AUTOWRAP_OFF
	_callout.modulate.a = 0.0
	root.add_child(_callout)

	_banner = label("", 48, Color(1, 0.9, 0.7))
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -260
	_banner.offset_right = 260
	_banner.offset_top = -250
	_banner.offset_bottom = -150
	_banner.modulate.a = 0.0
	root.add_child(_banner)


## The big title card when a boss appears: black bars, the name, and a line under it.
## Version 366 (visual review fix 8, boss entrances): the black bars slide in like a film,
## and the name rides in on a slanted band in the boss's own colour, under a BOSS tag,
## with a shine passing over it.
var _boss_bars: Array[ColorRect] = []
var _boss_slide: Control
var _boss_band_sb: StyleBoxFlat
var _boss_tag: Label
var _boss_tag_sb: StyleBoxFlat
var _boss_shine: ColorRect
var _boss_tw: Tween
const BOSS_BAR := 110.0

func _build_boss_card() -> void:
	_boss_card = Control.new()
	_boss_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(_boss_card)
	_boss_card.visible = false
	add_child(_boss_card)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 0.9)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		_boss_card.add_child(bar)
		_boss_bars.append(bar)
	_boss_slide = Control.new()
	_boss_slide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(_boss_slide)
	_boss_card.add_child(_boss_slide)
	var band := Panel.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.clip_contents = true
	band.set_anchors_preset(Control.PRESET_CENTER)
	band.offset_left = -430
	band.offset_right = 430
	band.offset_top = 30
	band.offset_bottom = 160
	_boss_band_sb = StyleBoxFlat.new()
	_boss_band_sb.bg_color = Color(0.035, 0.02, 0.05, 0.9)
	_boss_band_sb.border_width_top = 5
	_boss_band_sb.border_width_bottom = 5
	_boss_band_sb.skew = Vector2(0.2, 0.0)
	_boss_band_sb.shadow_color = Color(0, 0, 0, 0.5)
	_boss_band_sb.shadow_size = 10
	band.add_theme_stylebox_override("panel", _boss_band_sb)
	_boss_slide.add_child(band)
	_boss_shine = ColorRect.new()
	_boss_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_shine.size = Vector2(70, 260)
	_boss_shine.position = Vector2(-200, -60)
	_boss_shine.rotation = 0.35
	band.add_child(_boss_shine)
	_boss_tag = label("BOSS", 20, Color(0.08, 0.03, 0.04))
	_boss_tag.set_anchors_preset(Control.PRESET_CENTER)
	_boss_tag.offset_left = -62
	_boss_tag.offset_right = 62
	_boss_tag.offset_top = 10
	_boss_tag.offset_bottom = 46
	_boss_tag.label_settings.outline_size = 0
	_boss_tag_sb = StyleBoxFlat.new()
	_boss_tag_sb.set_corner_radius_all(8)
	_boss_tag_sb.skew = Vector2(0.2, 0.0)
	_boss_tag.add_theme_stylebox_override("normal", _boss_tag_sb)
	_boss_slide.add_child(_boss_tag)
	_boss_card_title = label("", 50, Color(1, 0.35, 0.25))
	_boss_card_title.set_anchors_preset(Control.PRESET_CENTER)
	_boss_card_title.offset_left = -300
	_boss_card_title.offset_right = 300
	_boss_card_title.offset_top = 46
	_boss_card_title.offset_bottom = 112
	_boss_slide.add_child(_boss_card_title)
	_boss_card_sub = label("", 20, Color(0.93, 0.89, 0.84))
	_boss_card_sub.set_anchors_preset(Control.PRESET_CENTER)
	_boss_card_sub.offset_left = -300
	_boss_card_sub.offset_right = 300
	_boss_card_sub.offset_top = 110
	_boss_card_sub.offset_bottom = 150
	_boss_slide.add_child(_boss_card_sub)


## Version 121: Phase 2 gets its own banner across the screen, on a dark plate so it reads
## over bullet rings and the lava floor (it used to share the small callout with the tutorial).
func _build_phase_banner() -> void:
	_phase_box = Control.new()
	_phase_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_box.set_anchors_preset(Control.PRESET_CENTER)
	_phase_box.offset_left = -340
	_phase_box.offset_right = 340
	_phase_box.offset_top = -330
	_phase_box.offset_bottom = -190
	_phase_box.pivot_offset = Vector2(340, 70)
	_phase_box.visible = false
	add_child(_phase_box)
	var plate := Panel.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.7)
	sb.set_corner_radius_all(18)
	sb.border_width_top = 4
	sb.border_width_bottom = 4
	sb.border_color = Color(1.0, 0.3, 0.2)
	plate.add_theme_stylebox_override("panel", sb)
	full(plate)
	_phase_box.add_child(plate)
	_phase_title = label("PHASE 2", 64, Color.WHITE)
	chunky(_phase_title.label_settings)
	_phase_title.label_settings.outline_size = 12
	_phase_title.label_settings.outline_color = Color(0.55, 0.05, 0.05)
	_phase_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_phase_title.offset_top = 6
	_phase_title.offset_bottom = 92
	_phase_box.add_child(_phase_title)
	_phase_sub = label("", 24, Color(1.0, 0.85, 0.6))
	chunky(_phase_sub.label_settings)
	_phase_sub.label_settings.outline_size = 6
	_phase_sub.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_phase_sub.offset_top = -48
	_phase_sub.offset_bottom = -10
	_phase_box.add_child(_phase_sub)


## The boss reached half health: the banner pops in (scale 1.6 to 1.0), holds, and fades;
## the boss bar flashes white and the boss's name turns red for the rest of the fight.
## `move` names the new attack that comes next.
func phase_banner(move: String, col := Color(1.0, 0.3, 0.2)) -> void:
	_callout_time = 0.0
	_callout.modulate.a = 0.0
	_phase_sub.text = ("NEW ATTACK: " + move.to_upper()) if move != "" else ""
	(_phase_box.get_child(0).get_theme_stylebox("panel") as StyleBoxFlat).border_color = col
	_phase_title.label_settings.outline_color = col.darkened(0.55)
	_phase_box.visible = true
	_phase_box.modulate.a = 1.0
	_phase_box.scale = Vector2(1.6, 1.6)
	if _phase_tw:
		_phase_tw.kill()
	_phase_tw = create_tween()
	_phase_tw.tween_property(_phase_box, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_phase_tw.tween_interval(1.4)
	_phase_tw.tween_property(_phase_box, "modulate:a", 0.0, 0.3)
	_phase_tw.tween_callback(func(): _phase_box.visible = false)
	_boss_flash.color.a = 0.85 * Game.flash_scale   # v219 review: the Flashes setting covers it
	create_tween().tween_property(_boss_flash, "color:a", 0.0, 0.25)
	_boss_name.label_settings.font_color = Color(1.0, 0.35, 0.3)


## A soft dark vignette round the screen edges, under everything else on the HUD (it
## frames the crypt like a lantern's reach), then a red glow there when health is low.
func _build_danger() -> void:
	var v := Gradient.new()
	v.set_color(0, Color(0, 0, 0, 0))
	v.set_color(1, Color(0, 0, 0, 0.5))
	v.add_point(0.55, Color(0, 0, 0, 0))
	v.add_point(0.8, Color(0, 0, 0, 0.16))
	var vt := GradientTexture2D.new()
	vt.gradient = v
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(0.97, 0.97)
	vt.width = 128
	vt.height = 128
	var vig := TextureRect.new()
	_vignette = vig
	vig.texture = vt
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(vig)
	add_child(vig)
	var g := Gradient.new()
	g.set_color(0, Color(0.7, 0, 0, 0))
	g.set_color(1, Color(0.7, 0, 0, 0.75))
	g.add_point(0.6, Color(0.7, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 128
	tex.height = 128
	_danger = TextureRect.new()
	_danger.texture = tex
	_danger.stretch_mode = TextureRect.STRETCH_SCALE
	_danger.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(_danger)
	_danger.modulate.a = 0.0
	add_child(_danger)
	# The Blood Moon's Eclipse darkens the screen; a Moon Surge burns red at the edges.
	_eclipse_dim = ColorRect.new()
	_eclipse_dim.color = Color(0.03, 0.0, 0.02, 0.0)
	_eclipse_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(_eclipse_dim)
	_eclipse_dim.visible = false
	add_child(_eclipse_dim)
	var sg := Gradient.new()
	sg.set_color(0, Color(1.0, 0.08, 0.05, 0))
	sg.set_color(1, Color(1.0, 0.08, 0.05, 0.8))
	sg.add_point(0.5, Color(1.0, 0.08, 0.05, 0))
	sg.add_point(0.78, Color(1.0, 0.1, 0.05, 0.22))
	var st := GradientTexture2D.new()
	st.gradient = sg
	st.fill = GradientTexture2D.FILL_RADIAL
	st.fill_from = Vector2(0.5, 0.5)
	st.fill_to = Vector2(1.02, 1.02)
	st.width = 128
	st.height = 128
	_surge_edge = TextureRect.new()
	_surge_edge.texture = st
	_surge_edge.stretch_mode = TextureRect.STRETCH_SCALE
	_surge_edge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_surge_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(_surge_edge)
	_surge_edge.modulate.a = 0.0
	add_child(_surge_edge)
	# Version 243, Frostfall's Blizzard: the edges of the screen frost over (blizzard.gd).
	var fg := Gradient.new()
	fg.set_color(0, Color(0.85, 0.95, 1.0, 0))
	fg.set_color(1, Color(0.9, 0.97, 1.0, 0.95))
	fg.add_point(0.55, Color(0.8, 0.92, 1.0, 0))
	fg.add_point(0.8, Color(0.82, 0.94, 1.0, 0.3))
	var ft := GradientTexture2D.new()
	ft.gradient = fg
	ft.fill = GradientTexture2D.FILL_RADIAL
	ft.fill_from = Vector2(0.5, 0.5)
	ft.fill_to = Vector2(1.02, 1.02)
	ft.width = 128
	ft.height = 128
	frost_edge = TextureRect.new()
	frost_edge.texture = ft
	frost_edge.stretch_mode = TextureRect.STRETCH_SCALE
	frost_edge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frost_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(frost_edge)
	frost_edge.modulate.a = 0.0
	add_child(frost_edge)


func _build_cards() -> void:
	# Version 143 (review change 4): the room stays in view behind the cards, dimmed, so the
	# pick feels like a moment in the crypt rather than a menu (it was an opaque purple
	# page). Below 0.7 the overlay gets no painted backdrop.
	_cards_box = overlay(Color(0.02, 0.01, 0.04, 0.42))
	add_child(_cards_box)
	# Version 157: the room shows more, with candlelight pooled behind the cards and the
	# corners sunk in shadow, so the pick happens in the lit crypt.
	_cards_box.add_child(_radial_light(Color(0, 0, 0, 0.0), Color(0.01, 0.0, 0.03, 0.72), Vector2(0.5, 0.55), Vector2(1.25, 1.1)))
	_cards_box.add_child(_radial_light(Color(1.0, 0.62, 0.28, 0.2), Color(1.0, 0.5, 0.2, 0.0), Vector2(0.5, 0.56), Vector2(0.5, 0.86)))
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 16
	col.offset_right = -16
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	_cards_box.add_child(col)
	# What you already hold, as a row of small badges, so a card's "completes" badge and
	# the build it adds to can be read at a glance.
	_cards_have = PanelContainer.new()
	_cards_have.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards_have.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_cards_have.custom_minimum_size = Vector2(440, 0)   # (a flow row has no width of its own)
	var hb := StyleBoxFlat.new()
	hb.bg_color = Color(0.05, 0.03, 0.08, 0.82)
	hb.border_color = Color(1, 0.85, 0.55, 0.35)
	hb.set_border_width_all(2)
	hb.set_corner_radius_all(14)
	hb.content_margin_left = 12
	hb.content_margin_right = 12
	hb.content_margin_top = 4
	hb.content_margin_bottom = 6
	_cards_have.add_theme_stylebox_override("panel", hb)
	var hv := VBoxContainer.new()
	hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hv.add_theme_constant_override("separation", 0)
	_cards_have.add_child(hv)
	var have_t := label("YOUR BLESSINGS", 14, Color(0.8, 0.74, 0.9))
	have_t.autowrap_mode = TextServer.AUTOWRAP_OFF
	hv.add_child(have_t)
	_cards_have_row = HFlowContainer.new()
	_cards_have_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards_have_row.alignment = FlowContainer.ALIGNMENT_CENTER
	_cards_have_row.add_theme_constant_override("h_separation", 2)
	_cards_have_row.add_theme_constant_override("v_separation", 0)
	_cards_have_row.custom_minimum_size = Vector2(0, 40)
	hv.add_child(_cards_have_row)
	_cards_have.visible = false
	col.add_child(_cards_have)
	_cards_mastery = label("", 28, GOLD)
	_cards_mastery.visible = false
	col.add_child(_cards_mastery)
	col.add_child(label("CHOOSE A BLESSING", 40, Color(1, 0.85, 0.55)))
	_cards_clock = label("", 20, Color(1.0, 0.62, 0.62))
	chunky(_cards_clock.label_settings)
	_cards_clock.label_settings.outline_size = 5
	_cards_clock.visible = false
	col.add_child(_cards_clock)
	# Version 157 (review fix 5): three tall cards side by side, dealt face down over the
	# lit crypt and flipped over one by one (they were a list of wide rows).
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", CARD_GAP)
	for i in 3:
		var holder := Control.new()   # keeps the card's place in the row while it flies in
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.custom_minimum_size = CARD_SIZE
		row.add_child(holder)
		var b := Button.new()
		b.size = CARD_SIZE
		b.pivot_offset = CARD_SIZE * 0.5
		b.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st, StyleBoxFlat.new())
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		holder.add_child(b)
		# A soft glow round the card: gold and breathing for a synergy, the rarity colour
		# for rare and epic ones.
		var aura := Panel.new()
		aura.name = "Aura"
		aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		aura.position = Vector2(4, 6)
		aura.size = CARD_SIZE - Vector2(8, 12)
		aura.show_behind_parent = true
		b.add_child(aura)
		# Version 162: light of the blessing's own colour falls from the top of the card and
		# glows behind its badge, so even a common card has colour (two tiny shared textures).
		var sheen := TextureRect.new()
		sheen.name = "Sheen"
		sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sheen.texture = _card_sheen_tex()
		sheen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sheen.stretch_mode = TextureRect.STRETCH_SCALE
		sheen.position = Vector2(4, 30)
		sheen.size = Vector2(CARD_SIZE.x - 8, CARD_SIZE.y * 0.62)
		b.add_child(sheen)
		var halo := TextureRect.new()
		halo.name = "Halo"
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		halo.texture = _card_halo_tex()
		halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		halo.stretch_mode = TextureRect.STRETCH_SCALE
		halo.size = Vector2(196, 196)
		halo.position = Vector2((CARD_SIZE.x - 196) * 0.5, 16)
		b.add_child(halo)
		var band := Panel.new()
		band.name = "Band"
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.position = Vector2(4, 4)
		band.size = Vector2(CARD_SIZE.x - 8, 38)
		b.add_child(band)
		var kind := label("", 16, INK)
		kind.name = "Kind"
		kind.label_settings.outline_size = 0
		kind.autowrap_mode = TextServer.AUTOWRAP_OFF
		kind.clip_text = true
		kind.position = Vector2(6, 4)
		kind.size = Vector2(CARD_SIZE.x - 12, 38)
		b.add_child(kind)
		# The badge sits on a lit disc, like a relic in a niche.
		var niche := Panel.new()
		niche.name = "Niche"
		niche.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# (Version 357: a bigger badge, and the words centred in the space under it: the
		# bottom half of every card stood empty.)
		niche.size = Vector2(136, 136)
		niche.position = Vector2((CARD_SIZE.x - 136) * 0.5, 46)
		b.add_child(niche)
		var icon := BlessingIcon.new()
		icon.name = "Icon"
		icon.zoom = 1.85
		icon.position = Vector2((CARD_SIZE.x - 64 * 1.85) * 0.5, 55)
		b.add_child(icon)
		# The name (one or two lines) with the words straight under it.
		var words := VBoxContainer.new()
		words.name = "Words"
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_theme_constant_override("separation", 4)
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.position = Vector2(6, 186)
		words.size = Vector2(CARD_SIZE.x - 12, CARD_SIZE.y - 186 - 52)
		b.add_child(words)
		var t := label("", 24, Color.WHITE)
		t.name = "Title"
		chunky(t.label_settings)   # (the cartoon font, below its usual size)
		t.label_settings.line_spacing = -5
		t.custom_minimum_size.x = CARD_SIZE.x - 12
		words.add_child(t)
		var d := label("", 16, Color(0.9, 0.88, 0.95))
		d.name = "Desc"
		d.label_settings.line_spacing = -2
		d.custom_minimum_size.x = CARD_SIZE.x - 12
		words.add_child(d)
		var r := label("", 16, INK)
		r.name = "Rarity"
		r.autowrap_mode = TextServer.AUTOWRAP_OFF
		r.label_settings.outline_size = 0
		var pill := StyleBoxFlat.new()
		pill.set_corner_radius_all(12)
		pill.content_margin_left = 12
		pill.content_margin_right = 12
		r.add_theme_stylebox_override("normal", pill)
		b.add_child(r)
		# "UNLOCKS WILDFIRE": this card is the missing half of a synergy you half own. A
		# gold sticker hung over the card's top edge.
		var combo := label("", 16, INK)
		combo.name = "Combo"
		combo.autowrap_mode = TextServer.AUTOWRAP_OFF
		combo.label_settings.outline_size = 0
		combo.label_settings.line_spacing = -3
		var cp := StyleBoxFlat.new()
		cp.bg_color = GOLD
		cp.border_color = Color(1, 0.96, 0.75)
		cp.set_border_width_all(2)
		cp.set_corner_radius_all(12)
		cp.content_margin_left = 10
		cp.content_margin_right = 10
		cp.content_margin_top = 1
		cp.content_margin_bottom = 2
		cp.shadow_color = Color(0, 0, 0, 0.45)
		cp.shadow_size = 2
		cp.shadow_offset = Vector2(0, 3)
		combo.add_theme_stylebox_override("normal", cp)
		combo.visible = false
		b.add_child(combo)
		var shine := Panel.new()
		shine.name = "Shine"
		shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ss := StyleBoxFlat.new()
		ss.bg_color = Color(1, 1, 1, 0.2)
		ss.skew = Vector2(-0.5, 0)
		shine.add_theme_stylebox_override("panel", ss)
		shine.size = Vector2(40, CARD_SIZE.y + 20)
		shine.position = Vector2(-90, -10)
		shine.visible = false
		var clip := Control.new()   # keeps the glint inside the card
		clip.name = "ShineClip"
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.clip_contents = true
		clip.position = Vector2(4, 4)
		clip.size = CARD_SIZE - Vector2(8, 14)
		clip.add_child(shine)
		b.add_child(clip)
		# The back, shown while the card is dealt: bone-gold frame, crossed bones and chain.
		var back := Control.new()
		back.name = "Back"
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.size = CARD_SIZE
		back.draw.connect(_draw_card_back.bind(back))
		b.add_child(back)
		var idx := i
		b.pressed.connect(func(): _on_card(idx))
		_cards.append(b)
	var gap := Control.new()   # room for a synergy sticker over a card's top edge
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size = Vector2(0, 10)
	col.add_child(gap)
	col.add_child(row)
	_cards_row = row
	_reroll_button = button("Reroll", 22)
	_reroll_button.custom_minimum_size = Vector2(220, 64)
	_reroll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reroll_button.pressed.connect(func():
		if _cards_age >= 0.45 and not _cards_picking:
			reroll_pressed.emit())
	col.add_child(_reroll_button)


## A full-screen radial glow (or shadow) from `from` (0-1 across the screen) to `to`.
static func _radial_light(inner: Color, outer: Color, from: Vector2, to: Vector2) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = from
	tex.fill_to = to
	tex.width = 128
	tex.height = 228
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	return t


## A blessing card's back: deep purple, a bone-gold frame, crossed bones in a ring and a
## chain running top to bottom.
func _draw_card_back(c: Control) -> void:
	var sz := c.size
	var r := Rect2(Vector2(2, 2), sz - Vector2(4, 10))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.1, 0.24)
	sb.border_color = Color(0.93, 0.8, 0.52)
	sb.set_border_width_all(4)
	sb.border_width_bottom = 10
	sb.border_color = Color(0.82, 0.68, 0.42)
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 5)
	sb.anti_aliasing_size = 1.2
	c.draw_style_box(sb, r)
	var bone := Color(0.93, 0.85, 0.66)
	var dim := Color(0.93, 0.85, 0.66, 0.28)
	# an inner frame with little diamonds at the corners
	var ir := r.grow(-12)
	ir.size.y -= 6
	c.draw_rect(ir, dim, false, 2.0)
	for p: Vector2 in [ir.position, ir.position + Vector2(ir.size.x, 0), ir.position + Vector2(0, ir.size.y), ir.end]:
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(6, 0), p + Vector2(0, 6), p + Vector2(-6, 0)]), bone)
	var mid := Vector2(sz.x * 0.5, r.get_center().y)
	# the chain: links above and below the ring
	for k in range(-5, 6):
		if absi(k) < 2:
			continue
		var y := mid.y + k * 24.0
		var w := 7.0 if k % 2 == 0 else 3.0
		c.draw_rect(Rect2(Vector2(mid.x - w, y - 10), Vector2(w * 2, 20)), dim if absi(k) > 3 else Color(bone, 0.55), false, 3.0)
	c.draw_circle(mid, 40, Color(0.1, 0.06, 0.16))
	c.draw_arc(mid, 40, 0, TAU, 40, bone, 4.0, true)
	c.draw_arc(mid, 32, 0, TAU, 40, dim, 2.0, true)
	for dir: Vector2 in [Vector2(1, 1).normalized(), Vector2(1, -1).normalized()]:
		var a := mid - dir * 20
		var b := mid + dir * 20
		c.draw_line(a, b, bone, 6.0, true)
		var n := Vector2(-dir.y, dir.x) * 4.5
		for e: Vector2 in [a, b]:
			c.draw_circle(e + n, 5.0, bone)
			c.draw_circle(e - n, 5.0, bone)


## Two tall arched doors side by side, each with a picture, a name and what it promises.
## Version 374 (visual review of 366, fix 7): the doors are real archways now, standing in a
## hall of the floor's own stone (DoorHall, seen by the game's camera); this screen only
## writes the words into the two doorways. The drawn arches on a dark screen stay as the
## fallback when there is no hall.
var _doors_head: VBoxContainer
var _doors_shade: TextureRect
var _doors_curtain: ColorRect
var _door_names: Array[Label] = []
var _door_texts: Array[Label] = []
var _door_plates: Array[StyleBoxFlat] = []

func _build_doors() -> void:
	_doors_box = overlay(Color(0.02, 0.01, 0.04, 0.8))
	add_child(_doors_box)
	# Over the hall: the top of the screen darkens behind the title.
	_doors_shade = TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.01, 0.05, 0.92))
	grad.set_color(1, Color(0.02, 0.01, 0.05, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	_doors_shade.texture = gt
	_doors_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_doors_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_doors_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_doors_shade.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_doors_box.add_child(_doors_shade)
	var col := VBoxContainer.new()
	_doors_head = col
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_preset(Control.PRESET_TOP_WIDE)
	col.offset_left = 20
	col.offset_right = -20
	col.add_theme_constant_override("separation", 8)
	_doors_box.add_child(col)
	col.add_child(label("CHOOSE YOUR DOOR", 40, Color(1, 0.85, 0.55)))
	_doors_next = label("", 18, Color(0.86, 0.86, 0.93))
	col.add_child(_doors_next)
	_doors_clock = label("", 20, Color(1.0, 0.62, 0.62))
	chunky(_doors_clock.label_settings)
	_doors_clock.label_settings.outline_size = 5
	_doors_clock.visible = false
	col.add_child(_doors_clock)
	for i in 2:
		# Version 161: each door is a carved stone archway (DoorArch) glowing with the
		# colour of what waits behind it; the button itself is invisible, only for the tap.
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		for sb_name in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(sb_name, StyleBoxEmpty.new())
		var arch := DoorArch.new()
		full(arch)
		b.add_child(arch)
		var idx := i
		b.button_down.connect(func(): _door_press(idx, true))
		b.button_up.connect(func(): _door_press(idx, false))
		_door_arches.append(arch)
		var inner := VBoxContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		full(inner)
		inner.add_theme_constant_override("separation", 12)
		b.add_child(inner)
		var icon := BlessingIcon.new()
		icon.zoom = 1.6
		inner.add_child(_centered(icon))
		# Version 410 (re-review fix 10): the words sit on a dark plate, so they read over the
		# hall's light and over the hero standing in front of the doors.
		var plate := PanelContainer.new()
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var psb := StyleBoxFlat.new()
		psb.bg_color = Color(0.03, 0.02, 0.06, 0.78)
		psb.border_color = Color(1, 1, 1, 0.14)
		psb.set_border_width_all(2)
		psb.set_corner_radius_all(12)
		psb.content_margin_left = 6
		psb.content_margin_right = 6
		psb.content_margin_top = 4
		psb.content_margin_bottom = 8
		plate.add_theme_stylebox_override("panel", psb)
		inner.add_child(plate)
		_door_plates.append(psb)
		var words := VBoxContainer.new()
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_theme_constant_override("separation", 2)
		plate.add_child(words)
		var name_l := label("", 25, Color.WHITE)
		chunky(name_l.label_settings)
		name_l.label_settings.outline_size = 6
		words.add_child(name_l)
		_door_names.append(name_l)
		var text_l := label("", 16, Color(0.93, 0.93, 0.97))
		text_l.label_settings.outline_size = 5
		text_l.label_settings.outline_color = Color(0.03, 0.02, 0.06, 0.95)
		words.add_child(text_l)
		_door_texts.append(text_l)
		b.pressed.connect(func(): _on_door(idx))
		_doors_box.add_child(b)
		_door_buttons.append(b)
	# The hall comes up out of the dark.
	_doors_curtain = ColorRect.new()
	_doors_curtain.color = Color(0.01, 0.005, 0.02, 0.0)
	_doors_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(_doors_curtain)
	_doors_box.add_child(_doors_curtain)


func _door_press(i: int, on: bool) -> void:
	_door_arches[i].set_pressed(on)
	if DoorHall.showing():
		DoorHall.current.press(i, on)


## doors: Doors.describe() of each door. `boss_next`: the boss waits behind them.
func show_doors(doors: Array, boss_next := false) -> void:
	DamageNumber.clear_all()
	_doors_next.text = "The boss waits beyond either one" if boss_next else "Both lead on to the next room"
	var screen := get_viewport().get_visible_rect().size
	# Where each doorway is: in the hall the camera shows (DoorHall), or two drawn arches
	# side by side in the middle of a dark screen.
	var hall := DoorHall.showing() and get_viewport().get_camera_3d() != null
	var rects: Array[Rect2] = []
	if hall:
		var cam := get_viewport().get_camera_3d()
		DoorHall.current.pose(cam, true)
		for i in 2:
			rects.append(DoorHall.current.door_rect(cam, i))
	else:
		# Version 160: on a tall phone the doors stand taller (up to half the screen).
		var tall := clampf(screen.y * 0.5, 400.0, 620.0)
		for i in 2:
			rects.append(Rect2(screen.x * 0.5 - 246.0 + 252.0 * i, (screen.y - tall) * 0.5 + 50.0, 240.0, tall))
	(_doors_box as ColorRect).color.a = 0.0 if hall else 0.8
	var bg := _doors_box.get_node_or_null("Glow") as CanvasItem
	if bg:
		bg.visible = not hall
	_doors_shade.visible = hall
	_doors_shade.offset_bottom = maxf(rects[0].position.y - 10.0, 160.0)
	# The title sits over the stone above the doorways.
	_doors_head.offset_top = maxf(rects[0].position.y - (150.0 if hall else 130.0), _safe.offset_top + 54.0)
	for i in _door_buttons.size():
		var b := _door_buttons[i]
		b.visible = i < doors.size()
		if not b.visible:
			continue
		var d: Dictionary = doors[i]
		var r := rects[i]
		b.position = r.position
		b.size = r.size
		var inner := b.get_child(1) as Control
		_door_arches[i].visible = not hall
		# Version 227: the words stay inside the doorway (they ran onto the stones).
		var pad := 10.0 if hall else DOOR_TEXT_PAD
		inner.offset_left = pad
		inner.offset_right = -pad
		# (a door with four lines of words, the Cursed Door, starts higher with a smaller
		# badge, so its last line stays inside the doorway; the door beside it matches)
		var long: bool = hall and doors.any(func(x: Dictionary) -> bool: return str(x.text).count("\n") >= 3)
		inner.offset_top = r.size.y * (0.1 if long else 0.15) if hall else 62.0   # (v410: was 0.19; clear of the hero's head)
		inner.offset_bottom = -30.0
		inner.add_theme_constant_override("separation", 7 if long else 12)
		(inner.get_child(0).get_child(0) as BlessingIcon).zoom = 1.3 if long else 1.6
		(inner as VBoxContainer).alignment = BoxContainer.ALIGNMENT_BEGIN
		_door_arches[i].color = d.color
		_door_arches[i].press = 0.0
		_door_arches[i].lit = -0.2 * i   # the light comes on behind each door in turn
		(inner.get_child(0).get_child(0) as BlessingIcon).show_icon(d.icon, d.family, d.color)
		var t := _door_names[i]
		t.text = d.title
		_door_plates[i].border_color = Color((d.color as Color).lightened(0.2), 0.55)
		# (v411 re-review: a dark door colour, the Healing Spring's green, left its name dim on
		# the black plate: lightened until it reads)
		var nc := (d.color as Color).lightened(0.25)
		while nc.get_luminance() < 0.62:
			nc = nc.lightened(0.15)
		t.label_settings.font_color = nc
		# a long name ("Champion's Door") shrinks to one line inside the doorway
		var fs := 25
		var font: Font = t.label_settings.font if t.label_settings.font else ThemeDB.fallback_font
		var room := r.size.x - pad * 2.0 - 20.0
		while fs > 17 and font.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + t.label_settings.outline_size > room:
			fs -= 1
		t.label_settings.font_size = fs
		# (v410: both doors' words the same size and their plates the same height)
		var fs_all := 25
		var lines_all := 0
		for j in doors.size():
			var tj := str(doors[j].title)
			var fj := 25
			while fj > 17 and font.get_string_size(tj, HORIZONTAL_ALIGNMENT_LEFT, -1, fj).x + t.label_settings.outline_size > room:
				fj -= 1
			fs_all = mini(fs_all, fj)
			lines_all = maxi(lines_all, str(doors[j].text).count("\n"))
		t.label_settings.font_size = fs_all
		_door_texts[i].text = str(d.text) + "\n".repeat(lines_all - str(d.text).count("\n"))
		if hall:
			# the words come up as the light does
			inner.modulate.a = 0.0
			var tw := inner.create_tween()
			tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_interval(0.25 + 0.1 * i)
			tw.tween_property(inner, "modulate:a", 1.0, 0.35)
		else:
			inner.modulate.a = 1.0
	_doors_curtain.color.a = 1.0 if hall else 0.0
	if hall:
		var cw := _doors_curtain.create_tween()
		cw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		cw.tween_property(_doors_curtain, "color:a", 0.0, 0.35)
	_doors_box.visible = true
	_doors_age = 0.0


func doors_visible() -> bool:
	return _doors_box.visible


func _on_door(i: int) -> void:
	# The same short guard as the blessing cards, so a moving thumb doesn't pick by accident.
	if not _doors_box.visible or _doors_age < 0.45:
		return
	_doors_box.visible = false
	door_picked.emit(i)


func _build_title() -> void:
	_title_box = overlay(Color(0.01, 0.01, 0.03, 0.55))
	add_child(_title_box)
	# The hero stands in the middle of the screen, so the words sit above them (anchored
	# to the top) and the buttons below (anchored to the bottom), on any phone shape.
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(holder)
	_title_box.add_child(holder)
	# Sound, screen shake, vibration and reports can be set before the first run too.
	# Version 342 (visual review fix 6): a gear, not a word, so the top bar has room for the
	# Crypt Pass and the middle of the screen stays the hero's.
	var settings := button(" ", 18)
	settings.custom_minimum_size = Vector2(66, 66)
	settings.position = Vector2(20, 20)
	settings.draw.connect(func(): _draw_gear(settings))
	settings.pressed.connect(func(): show_settings(true))
	holder.add_child(settings)
	# REWARDS (version 116): the Bone Road, Bone Drops, Feats and Records in one place, so
	# the returning title has 7 buttons, not 9.
	var records := button("REWARDS", 18, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	records.custom_minimum_size = Vector2(134, 66)
	records.position = Vector2(96, 20)
	records.pressed.connect(func(): show_rewards(true))
	holder.add_child(records)
	_rewards_badge = _badge_pill("")
	_rewards_badge.offset_left = -84
	records.add_child(_rewards_badge)
	_title_records = records
	_title_settings = settings
	# The Crypt Pass sits in the top bar (version 342), its deal tag hanging under it.
	var pass_button := button("PASS", 20, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	pass_button.custom_minimum_size = Vector2(100, 66)
	pass_button.position = Vector2(240, 20)
	pass_button.pressed.connect(func(): pass_pressed.emit())
	holder.add_child(pass_button)
	_title_pass_badge = _deal_pill()
	_title_pass_badge.label_settings.font_size = 13
	_title_pass_badge.anchor_left = 0.0
	_title_pass_badge.anchor_right = 0.0
	_title_pass_badge.offset_left = -10
	_title_pass_badge.offset_right = 110
	_title_pass_badge.offset_top = 50
	_title_pass_badge.offset_bottom = 72
	pass_button.z_index = 1   # (its tag hangs over the event strip)
	_title_pass_badge.grow_horizontal = Control.GROW_DIRECTION_END
	pass_button.add_child(_title_pass_badge)
	_title_pass_row = pass_button
	_place_title_buttons()
	var top := VBoxContainer.new()
	_title_top = top
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 30
	top.add_theme_constant_override("separation", 10)
	holder.add_child(top)
	_title_coins = coin_row(26, top)
	(_title_coins.get_parent() as HBoxContainer).alignment = BoxContainer.ALIGNMENT_END
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	top.add_child(gap)
	_title_gap = gap
	_title_logo = logo_rect()
	top.add_child(_title_logo)
	# The Blood Moon (events.gd): the event's banner under the logo while it's on, and a
	# countdown to it the week before.
	# Version 342: a slim strip above the logo, not a big card over the hero's head.
	_title_event = EventArt.Banner.new()
	_title_event.slim()
	_title_event.visible = false
	_title_event.pressed.connect(func(): event_pressed.emit())
	top.add_child(_title_event)
	top.move_child(_title_event, _title_gap.get_index() + 1)
	_title_hint = label("Drag to move. Lift to shoot.", 20, Color(0.85, 0.85, 0.9))
	top.add_child(_title_hint)
	# Said up front, so nobody is surprised when the free floors end.
	_title_free = label("Free to try: floors 1-%d. The Crypt Pass opens the rest." % Store.FREE_FLOORS, 17, Color(0.95, 0.78, 0.45))
	top.add_child(_title_free)
	_title_best = label("", 18, Color(0.7, 0.7, 0.8))
	top.add_child(_title_best)
	# The Bone Road's bar (bone_road.gd): bones so far, and the next reward.
	# Side by side, so the hero below stays in view on short phones.
	_title_road = RoadScreen.Bar.new()
	_title_road.custom_minimum_size = Vector2(250, 64)
	_title_road.pressed.connect(func(): road_pressed.emit())
	# Bone Drops waiting to be opened (drops.gd).
	_title_drops = _drop_button()
	_title_drops.custom_minimum_size = Vector2(240, 64)
	_title_drops.add_theme_font_size_override("font_size", 17)
	var row := _pair(_title_road, _title_drops)
	(row as HBoxContainer).add_theme_constant_override("separation", 10)
	row.visible = false   # (in the REWARDS screen now)
	_title_rewards_row = row
	top.add_child(row)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	col.offset_top = -40
	col.offset_bottom = -40
	col.add_theme_constant_override("separation", 14)
	holder.add_child(col)
	_title_bottom = col
	# Gold lines under the hero, just above PLAY: why to play today and what's next.
	_title_goal = label("", 18, Color(1.0, 0.82, 0.42))
	col.add_child(_title_goal)
	_title_hero = label("", 26, Color(0.75, 0.85, 1.0))
	col.add_child(_title_hero)
	_title_spacer = Control.new()
	_title_spacer.custom_minimum_size = Vector2(0, 24)
	col.add_child(_title_spacer)
	# A saved run (run_save.gd) can be picked up again.
	var cont_col := VBoxContainer.new()
	cont_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont_col.add_theme_constant_override("separation", 2)
	var cont := button("CONTINUE", 36, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	cont.custom_minimum_size = Vector2(300, 86)
	cont.pressed.connect(func(): continue_pressed.emit())
	cont_col.add_child(_centered(cont))
	_continue_where = label("", 17, Color(0.95, 0.85, 0.6))
	cont_col.add_child(_continue_where)
	_title_continue = cont_col
	col.add_child(cont_col)
	var play := button("PLAY", 38, Color(0.45, 0.16, 0.12, 0.97), Color(1, 0.75, 0.4))
	play.custom_minimum_size = Vector2(300, 92)
	play.pressed.connect(func(): _guarded(play, play_pressed))
	_title_play = play
	_title_play_badge = _badge_pill("HEROIC")
	_title_play_badge.offset_left = -84
	play.add_child(_title_play_badge)
	col.add_child(_centered(play))
	# Version 309: which floor a new run starts on, once floor 3 has been reached (a tap
	# goes on to the next open floor, then back to floor 1).
	var start := button("START ON FLOOR 1  >", 17, Color(0.1, 0.09, 0.12, 0.95), Color(0.55, 0.5, 0.45))   # (slate: a quiet choice)
	start.custom_minimum_size = Vector2(238, 50)
	start.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	start.pressed.connect(func(): start_floor_pressed.emit())
	start.visible = false
	_title_start = start
	# Version 310 (short sessions, part 2): QUICK PLAY beside it, two rooms and a boss.
	var quick := button("QUICK PLAY  2 MIN", 17, Color(0.25, 0.1, 0.6, 0.95), Color(0.85, 0.7, 1.0))   # (purple)
	quick.custom_minimum_size = Vector2(238, 50)
	quick.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	quick.pressed.connect(func(): quick_pressed.emit())   # (no guard: a saved run stays saved)
	quick.visible = false
	_title_quick = quick
	var small := HBoxContainer.new()
	small.alignment = BoxContainer.ALIGNMENT_CENTER
	small.mouse_filter = Control.MOUSE_FILTER_IGNORE
	small.add_theme_constant_override("separation", 10)
	small.custom_minimum_size.y = 58   # (room under it for the HEROES and ARMORY tags)
	small.add_child(start)
	small.add_child(quick)
	small.visible = false
	_title_small_row = small
	col.add_child(small)
	# Version 342: HEROES, ARMORY and MODES in one row (two rows of big buttons covered the
	# hero's feet; the Pass moved to the top bar).
	var heroes := button("HEROES", 21)
	heroes.custom_minimum_size = Vector2(152, 72)
	heroes.pressed.connect(func(): heroes_pressed.emit())
	_title_heroes = heroes
	# A gold tag when a hero has new looks to try on the Style screen.
	_title_heroes_badge = _badge_pill("NEW LOOKS")
	heroes.add_child(_title_heroes_badge)
	var armory := button("ARMORY", 21)
	armory.custom_minimum_size = Vector2(152, 72)
	armory.pressed.connect(func(): armory_pressed.emit())
	_title_armory = armory
	_title_armory_badge = _badge_pill("UPGRADE")
	armory.add_child(_title_armory_badge)
	_title_shop_row = _pair(heroes, armory)
	(_title_shop_row as HBoxContainer).add_theme_constant_override("separation", 10)
	col.add_child(_title_shop_row)
	# MODES holds the Daily Crypt, Curses and the tutorial run; then the Crypt Pass.
	var modes := button("MODES", 21)
	modes.custom_minimum_size = Vector2(152, 72)
	modes.pressed.connect(func(): show_modes(true))
	# A little gold tag when today's Daily Crypt is waiting.
	_title_modes_badge = _badge_pill("DAILY READY")
	modes.add_child(_title_modes_badge)
	_title_shop_row.add_child(modes)
	_title_modes_row = modes
	_title_lock = label("Finish the tutorial to open\nHeroes and the Armory", 20, Color(0.7, 0.68, 0.62))
	col.add_child(_title_lock)


## The gold OPEN BONE DROP button (title and end screens), hidden until one is earned.
func _drop_button() -> Button:
	var b := button("OPEN BONE DROP", 22, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	b.custom_minimum_size = Vector2(320, 64)
	b.visible = false
	b.pressed.connect(func(): drops_pressed.emit())
	return b


## Shows or hides the OPEN BONE DROP buttons for `n` waiting drops.
func set_drops(n: int) -> void:
	for b in [_title_drops, _end_drop]:
		b.visible = n > 0
		b.text = "OPEN BONE DROP" if n == 1 else "OPEN %d BONE DROPS" % n
	if _rewards_box and (_rewards_box.visible or _title_box.visible):
		refresh_rewards()
	_fit_end_soon()


## The Bone Drop screen (drop_screen.gd); `opener` opens one and returns what was inside.
func open_drops(n: int, opener: Callable) -> void:
	_drops.opener = opener
	_drops.open_screen(n)
	_park_toast()   # v218


## The Bone Road screen (road_screen.gd), filled from `cfg`.
func open_road(cfg: ConfigFile) -> void:
	_road.open_road(cfg)


func close_road() -> void:
	if _road.visible:
		_road.visible = false
		road_closed.emit()


func road_visible() -> bool:
	return _road.visible


func close_drops() -> void:
	_drops.close()


func drops_visible() -> bool:
	return _drops.visible


## Daily Crypt, Curses and the tutorial run, all behind MODES on the title screen.
## The screens they open sit on top, so BACK from them lands here again.
func _build_modes() -> void:
	_modes_box = overlay(Color(0.03, 0.02, 0.05, 0.95), "gate")
	add_child(_modes_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 20
	col.offset_right = -20
	col.offset_top = 24
	col.offset_bottom = -24
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	_modes_box.add_child(col)
	col.add_child(label("MODES", 46, Color(1, 0.85, 0.55)))
	col.add_child(label("More ways to run the crypt.", 18, Color(0.8, 0.8, 0.85)))
	var race := _mode_card("race", "CRYPT RACE", RaceScreen.TEAL, func(): race_pressed.emit())
	col.add_child(race[0])
	_mode_race_line = race[1]
	_mode_race_tag = race[2]
	var daily := _mode_card("daily", "DAILY CRYPT", GOLD, func(): daily_pressed.emit())
	col.add_child(daily[0])
	_mode_daily_text = daily[1]
	_mode_daily_tag = daily[2]
	var curses := _mode_card("curses", "CURSES", Color(0.95, 0.35, 0.4), func(): curses_pressed.emit())
	col.add_child(curses[0])
	_mode_curses_line = curses[1]
	_mode_curses_tag = curses[2]
	_modes_tutorial = button("Replay tutorial", 20, Color(0.1, 0.08, 0.12, 0.9), Color(0.6, 0.55, 0.6, 0.5))
	_modes_tutorial.custom_minimum_size = Vector2(260, 62)
	_modes_tutorial.pressed.connect(func(): _guarded(_modes_tutorial, tutorial_pressed))
	col.add_child(_centered(_modes_tutorial))
	var back := button("BACK", 26)
	back.pressed.connect(func(): show_modes(false))
	_frame(_modes_box, col, back)


## A big mode button: a picture (art/ui/pass_<pic>.png), the name, a line about it and a tag.
## Returns [button, line, tag].
func _mode_card(pic: String, title: String, col: Color, on_press: Callable) -> Array:
	var b := button("", 20, Color(0.12, 0.1, 0.16, 0.98), Color(col, 0.75))
	b.custom_minimum_size = Vector2(0, 200)   # 228 before the Crypt Race made it three cards
	# Version 159: on a tall phone the cards share the empty space below them, and the
	# picture grows with its card, so the heroes' heads are no longer cut off.
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for state in ["normal", "pressed"]:
		var sb := b.get_theme_stylebox(state) as StyleBoxFlat
		sb.set_border_width_all(3)
	b.pressed.connect(on_press)
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 8)
	full(m)
	b.add_child(m)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	m.add_child(v)
	var img := TextureRect.new()
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.custom_minimum_size = Vector2(0, 92)
	img.size_flags_vertical = Control.SIZE_EXPAND_FILL
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var path := "res://art/ui/pass_%s.png" % pic
	if ResourceLoader.exists(path):
		img.texture = load(path)
	v.add_child(img)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	h.add_child(texts)
	var t := label(title, 26, col.lightened(0.15), HORIZONTAL_ALIGNMENT_LEFT)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	texts.add_child(t)
	var line := label("", 15, Color(0.8, 0.8, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	texts.add_child(line)
	var tag := label("", 18, col)
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Version 159: the tag (READY, LOCKED...) sits in a little pill of the card's colour.
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(col.darkened(0.6), 0.85)
	psb.border_color = Color(col, 0.8)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(14)
	psb.content_margin_left = 12
	psb.content_margin_right = 12
	psb.content_margin_top = 2
	psb.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", psb)
	pill.add_child(tag)
	h.add_child(pill)
	return [b, line, tag]


func show_modes(v: bool) -> void:
	if v and not _modes_box.visible:
		Sfx.play("click")
	_modes_box.visible = v
	# The title's own buttons would show faintly through; hide them while MODES is open.
	_title_box.get_child(0).visible = not v
	if not v:
		_disarm(_modes_tutorial)
		return
	var owned := Store.owned()
	var cfg := Game._load_save()
	var theme := Curses.theme()
	_mode_daily_text.text = "%s: %s.\nThe same crypt for everyone, once a day." % [theme.name, theme.text]
	_mode_daily_tag.text = "PLAYED" if Curses.official_used(cfg) else "READY"
	var level := Curses.level_of(Curses.chosen(cfg, owned))
	_mode_curses_tag.text = "NEW" if Game.heroic_new() else ("LEVEL %d" % level if level > 0 else "OFF")
	if Race.unlocked(cfg):
		var t := Race.trophies(cfg)
		_mode_race_line.text = "Race a rival through the same crypt.\n%s League  ·  %d trophies" % [str(Race.league(t).name).capitalize(), t]
		_mode_race_tag.text = "NEW" if Race.stat(cfg, "races") == 0 else ("CLAIM!" if Race.road_ready(cfg) > 0 else "RACE!")
	else:
		_mode_race_line.text = "Race a rival through the same crypt.\nOpens after %d floor 1 wins." % Race.UNLOCK_CLEARS
		_mode_race_tag.text = "LOCKED"
	_mode_curses_line.text = ("HEROIC is open, free: tougher skeletons,\n+50% coins. Curses add more." if Curses.unlocked("heroic", cfg)
			else "Turn on curses for harder runs, more score\nand rewards for your hero.")


## RECORDS on the title: lifetime bests and totals (rows of [name, value] from game.gd).
func _build_records() -> void:
	_records_box = overlay(Color(0.03, 0.02, 0.05, 0.95), "library")
	add_child(_records_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 28
	col.offset_right = -28
	col.offset_top = 24
	col.offset_bottom = -24
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	_records_box.add_child(col)
	col.add_child(label("RECORDS", 46, Color(1, 0.85, 0.55)))
	col.add_child(label("Everything you've done in the crypt.", 18, Color(0.8, 0.8, 0.85)))
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.13, 0.95)
	sb.border_color = Color(GOLD, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	col.add_child(panel)
	_records_grid = GridContainer.new()
	_records_grid.columns = 2
	_records_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_records_grid.add_theme_constant_override("h_separation", 12)
	_records_grid.add_theme_constant_override("v_separation", 10)
	panel.add_child(_records_grid)
	_records_note = label("", 15, Color(0.65, 0.63, 0.7))
	col.add_child(_records_note)
	var back := button("BACK", 26)
	back.pressed.connect(func(): show_records(false))
	_frame(_records_box, col, back)


func show_records(v: bool, rows := [], note := "") -> void:
	_records_box.visible = v   # (_process hides the title's buttons behind it)
	if not v:
		return
	for c in _records_grid.get_children():
		c.free()
	for r: Array in rows:
		var what := label(str(r[0]), 21, Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		what.autowrap_mode = TextServer.AUTOWRAP_OFF
		_records_grid.add_child(what)
		var value := label(str(r[1]), 22, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		_records_grid.add_child(value)
	_records_note.text = note
	_records_note.visible = note != ""


func records_visible() -> bool:
	return _records_box.visible


# ---------------------------------------------------------------- today's goals (version 311)

func _build_today() -> void:
	_today_box = overlay(Color(0.03, 0.02, 0.05, 1.0), "board")
	add_child(_today_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 28
	col.offset_right = -28
	col.add_theme_constant_override("separation", 14)
	_today_box.add_child(col)
	col.add_child(label("TODAY'S GOALS", 46, GOLD))
	col.add_child(label("Three new goals a day. Every run counts.", 18, Color(0.8, 0.78, 0.85)))
	_today_rows = VBoxContainer.new()
	_today_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_today_rows.add_theme_constant_override("separation", 12)
	col.add_child(_today_rows)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	# Version 363 (visual review v357 fix 5): what the Today Chest holds, as pictures: a heap of
	# coins and a Bone Drop.
	var inside := HBoxContainer.new()
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.alignment = BoxContainer.ALIGNMENT_CENTER
	inside.add_theme_constant_override("separation", -10)
	col.add_child(inside)
	inside.add_child(LookShots.prize_rect("coins", 120))
	inside.add_child(LookShots.prize_rect("drop", 170))
	_today_chest = button("OPEN THE TODAY CHEST", 24, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	_today_chest.custom_minimum_size = Vector2(420, 78)
	_today_chest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_today_chest.pressed.connect(func(): today_chest_pressed.emit())
	col.add_child(_today_chest)
	_today_chest_note = label("", 18, Color(1.0, 0.85, 0.5))
	col.add_child(_today_chest_note)
	_today_clock = label("", 16, Color(0.65, 0.63, 0.7))
	col.add_child(_today_clock)
	var back := button("BACK", 26)
	back.pressed.connect(func(): show_today(false))
	_frame(_today_box, col, back)
	_today_box.visible = false


func show_today(v: bool) -> void:
	if v:
		Sfx.play("click")
		refresh_today()
	_today_box.visible = v
	if not v and _rewards_box.visible:
		refresh_rewards()


func today_visible() -> bool:
	return _today_box != null and _today_box.visible


## The three goal cards, each with its bar and a tick once it's done, and the chest.
func refresh_today() -> void:
	var cfg := Game._load_save()
	for c in _today_rows.get_children():
		c.free()
	for g: Dictionary in Today.goals(cfg):
		_today_rows.add_child(_today_card(g, Today.done(cfg, g), Today.progress_text(cfg, g),
			clampf(float(Today.have(cfg, g.id)) / maxf(float(g.need), 1.0), 0.0, 1.0)))
	var ready := Today.chest_ready(cfg)
	var opened := Today.chest_open(cfg)
	_today_chest.disabled = not ready
	_today_chest.text = "CHEST OPENED" if opened else "OPEN THE TODAY CHEST"
	_today_chest_note.text = "Come back tomorrow for three new goals." if opened else \
		("Inside: %d coins and a Bone Drop" % Today.CHEST_COINS if ready else \
		"Finish all 3 to open it: %d coins and a Bone Drop" % Today.CHEST_COINS)
	_today_clock.text = "New goals in %s" % _clock_text(Curses.seconds_left())


func _today_card(g: Dictionary, done: bool, progress: String, k: float) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.16, 0.09, 0.97) if done else Color(0.1, 0.08, 0.13, 0.95)
	sb.border_color = Color(0.5, 1.0, 0.6, 0.85) if done else Color(GOLD, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var what := label(("DONE  " if done else "") + str(g.text), 22, Color(0.6, 1.0, 0.65) if done else Color(0.95, 0.93, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(what)
	top.add_child(LookShots.prize_rect("coin", 30))   # (v363: the prize as a picture)
	var pay := label("+%d" % Today.GOAL_COINS, 20, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	pay.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(pay)
	var bar_row := HBoxContainer.new()
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_theme_constant_override("separation", 12)
	v.add_child(bar_row)
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = k
	bar.custom_minimum_size = Vector2(0, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	back.set_corner_radius_all(8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.45, 0.95, 0.5) if done else Color(1.0, 0.75, 0.25)
	fill.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	bar_row.add_child(bar)
	var p := label(progress, 18, Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_RIGHT)
	p.autowrap_mode = TextServer.AUTOWRAP_OFF
	p.custom_minimum_size = Vector2(100, 0)
	bar_row.add_child(p)
	return panel


## After OPEN THE TODAY CHEST: the screen again, and a banner.
func today_opened(chest_coins: int) -> void:
	refresh_today()
	set_drops(Drops.waiting(Game._load_save()))
	banner("TODAY CHEST!  +%d coins  +1 Bone Drop" % chest_coins, GOLD)


## 18000 -> "5h 0m", 600 -> "10m".
static func _clock_text(seconds: int) -> String:
	var h := seconds / 3600
	var m := (seconds % 3600) / 60
	return "%dh %dm" % [h, m] if h > 0 else "%dm" % maxi(m, 1)


func modes_visible() -> bool:
	return _modes_box.visible


## The Heroes screen (hero_screen.gd).
func _build_heroes() -> void:
	_heroes_box = HeroScreen.new()
	add_child(_heroes_box)
	_heroes_box.pick.connect(func(id: String): hero_pick.emit(id))
	_heroes_box.trial.connect(func(id: String): hero_trial.emit(id))
	_heroes_box.closed.connect(func(): show_heroes(false))
	_heroes_box.mastery.connect(func(id: String): mastery_pressed.emit(id))
	_heroes_box.style.connect(func(id: String): style_pressed.emit(id))
	_heroes_box.feats.connect(func(id: String): feats_hero_pressed.emit(id))


## With a saved run waiting, starting a new one asks first: the first tap warns, and a
## second tap within 3 seconds starts it (giving up the saved run).
func _guarded(b: Button, sig: Signal) -> void:
	if not _title_continue.visible or b.has_meta("armed"):
		_disarm(b)
		sig.emit()
		return
	b.set_meta("armed", [b.text, b.get_theme_font_size("font_size")])
	b.text = "Tap again: new run"
	b.add_theme_font_size_override("font_size", 20)
	get_tree().create_timer(3.0, true, false, true).timeout.connect(_disarm.bind(b))


## Puts a `_guarded` button's own text and size back.
func _disarm(b: Button) -> void:
	if b.has_meta("armed"):
		var was: Array = b.get_meta("armed")
		b.text = was[0]
		b.add_theme_font_size_override("font_size", was[1])
		b.remove_meta("armed")


## Two buttons side by side, centred.
func _pair(a: Control, b: Control) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.add_child(a)
	row.add_child(b)
	return row


## Version 342: the title's settings gear, drawn on its button: eight teeth and a hole.
func _draw_gear(b: Control) -> void:
	var c := b.size * 0.5 - Vector2(0, 3)
	var pts := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		var tooth := fmod(i, 6.0) < 3.0
		pts.append(c + Vector2.from_angle(a) * (19.0 if tooth else 14.5))
	b.draw_colored_polygon(pts, Color.WHITE)
	pts.append(pts[0])
	b.draw_polyline(pts, INK, 3.0, true)
	b.draw_circle(c, 6.5, INK)


func _centered(c: Control) -> Control:
	var box := CenterContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(c)
	return box


func _build_end() -> void:
	_end_box = overlay(Color(0.02, 0, 0.02, 0.75))
	add_child(_end_box)
	var col := VBoxContainer.new()
	full(col)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 24)
	_end_box.add_child(col)
	_end_col = col
	_end_box.resized.connect(_fit_end)
	_end_title = label("", 60)
	col.add_child(_end_title)
	_end_hero_box = Control.new()
	_end_hero_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_hero_box.custom_minimum_size = Vector2(360, 250)
	_end_hero_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_end_hero_box.draw.connect(_draw_end_rays)
	_end_hero = HeroStage.new(Vector2(260, 260))
	_end_hero.soft_edge = true
	_end_hero.custom_minimum_size = Vector2(260, 260)
	_end_hero.size = Vector2(260, 260)
	_end_hero.position = Vector2(50, -6)
	_end_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_hero_box.add_child(_end_hero)
	_end_hero_box.visible = false
	col.add_child(_end_hero_box)
	_end_score = label("", 40, Color(1, 0.85, 0.45))
	col.add_child(_end_score)
	_end_best = label("", 20, Color(0.8, 0.78, 0.7))
	col.add_child(_end_best)
	_end_stats = label("", 23, Color(0.97, 0.94, 0.88))   # v388: whiter (it read as grey)
	col.add_child(_end_stats)
	# Version 227: the words keep clear of the screen's edges (a long death tip ran from
	# edge to edge and left one word alone on the last line).
	_end_tiles = HBoxContainer.new()
	_end_tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	_end_tiles.add_theme_constant_override("separation", 10)
	_end_tiles.visible = false
	col.add_child(_end_tiles)
	_end_after = label("", 22, Color(0.95, 0.93, 0.88))
	_end_after.visible = false
	col.add_child(_end_after)
	for l: Label in [_end_best, _end_stats, _end_after]:
		l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		l.custom_minimum_size.x = END_TEXT_W
	# Hero Mastery: the run's points filling the hero's bar (mastery_bar.gd).
	_end_mastery = MasteryBar.new()
	_end_mastery.custom_minimum_size = Vector2(470, 84)
	_end_mastery.visible = false
	col.add_child(_centered(_end_mastery))
	_end_looks = button("SEE 3 NEW LOOKS", 18, Color(0.22, 0.14, 0.3, 0.97), GOLD)
	_end_looks.custom_minimum_size = Vector2(226, 58)
	_end_looks.visible = false
	_end_looks.pressed.connect(func():
		if not _end_looks_for.is_empty():
			see_looks.emit(str(_end_looks_for.id), int(_end_looks_for.level)))
	_end_goal = label("", 22, Color(1.0, 0.82, 0.42))
	_end_goal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_end_goal.custom_minimum_size.x = END_TEXT_W
	_end_goal.visible = false
	col.add_child(_end_goal)
	_end_drop = _drop_button()
	_end_drop.add_theme_font_size_override("font_size", 20)
	_end_drop.custom_minimum_size = Vector2(226, 58)
	# v389 (fix 1 critic): SHARE RESULT joins this row (it was a row of its own), so the
	# column has fewer stacked buttons and DESCEND stands out; three wrap onto two rows.
	_end_extras = HFlowContainer.new()
	_end_extras.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_extras.alignment = FlowContainer.ALIGNMENT_CENTER
	_end_extras.add_theme_constant_override("h_separation", 14)
	_end_extras.add_theme_constant_override("v_separation", 12)
	_end_extras.add_child(_end_looks)
	_end_extras.add_child(_end_drop)
	# Daily Crypt: the result card (above its SHARE button), and the same as text to paste anywhere.
	_share_card = ShareCard.new()
	_share_card.visible = false
	col.add_child(_share_card)
	col.add_child(_end_extras)
	_share_button = button("SHARE RESULT", 18, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	paint(_share_button, "slate")   # v388: a quiet extra, so DESCEND stays the one big button
	_share_button.custom_minimum_size = Vector2(226, 58)
	_end_extras.add_child(_share_button)
	_share_button.pressed.connect(func():
		_share_button.disabled = true
		share_pressed.emit())
	# Copies a detailed report of the run (with the install number the privacy policy asks
	# for), for players who send reports and want to share one.
	_copy_button = button("COPY REPORT", 20, Color(0.1, 0.12, 0.18, 0.95), Color(0.5, 0.75, 1.0, 0.7))
	_copy_button.custom_minimum_size = Vector2(240, 64)
	_copy_button.pressed.connect(func():
		_copy_button.text = "Copied!"
		copy_report_pressed.emit())
	col.add_child(_centered(_copy_button))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 100)
	_end_spacer = spacer
	col.add_child(spacer)
	_end_tap = label("Tap to try again", 30)
	_end_tap.set_script(Pulse)
	col.add_child(_end_tap)
	var buttons := VBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.add_theme_constant_override("separation", 18)
	col.add_child(buttons)
	var retry := button("TRY AGAIN", 32, Color(0.45, 0.16, 0.12, 0.97), Color(1, 0.75, 0.4))
	retry.custom_minimum_size = Vector2(300, 86)
	_end_retry = retry
	retry.pressed.connect(func(): retry_pressed.emit())
	buttons.add_child(_centered(retry))
	var heroes := button("HEROES", 26)
	heroes.custom_minimum_size = Vector2(222, 74)
	heroes.pressed.connect(func(): heroes_pressed.emit())
	_end_heroes_badge = _badge_pill("NEW LOOKS")
	heroes.add_child(_end_heroes_badge)
	var armory := button("ARMORY", 26)
	armory.custom_minimum_size = Vector2(222, 74)
	armory.pressed.connect(func(): armory_pressed.emit())
	_end_armory_badge = _badge_pill("UPGRADE")
	armory.add_child(_end_armory_badge)
	buttons.add_child(_pair(heroes, armory))
	var end_pass := button("CRYPT PASS", 24, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	end_pass.pressed.connect(func(): pass_pressed.emit())
	_end_pass_badge = _deal_pill()
	end_pass.add_child(_end_pass_badge)
	_end_pass = _centered(end_pass)
	_end_pass.visible = false
	buttons.add_child(_end_pass)
	_end_buttons = buttons
	_build_pass_card(col)   # v389: a slim strip under the buttons (it pushed the hero off before)
	# Back to the title from the death screen, or after a win (the run stays saved).
	_end_title_btn = button("TITLE", 22, Color(0.1, 0.08, 0.12, 0.9), Color(0.6, 0.55, 0.6, 0.5))
	_end_title_btn.custom_minimum_size = Vector2(222, 66)
	_end_title_btn.pressed.connect(func():
		Sfx.play("click")
		title_pressed.emit())
	_end_title_button = _centered(_end_title_btn)
	_end_title_button.visible = false
	col.add_child(_end_title_button)
	# After the last free floor: the Crypt Pass, or back to the title.
	var offer := VBoxContainer.new()
	offer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	offer.add_theme_constant_override("separation", 18)
	col.add_child(offer)
	_end_deal = _deal_ribbon(26)   # version 279
	offer.add_child(_centered(_end_deal))
	var get_pass := button("GET THE CRYPT PASS", 28, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	get_pass.custom_minimum_size = Vector2(340, 86)
	_end_get_pass = get_pass
	get_pass.pressed.connect(func(): pass_pressed.emit())
	offer.add_child(_centered(get_pass))
	var to_title := button("BACK TO TITLE  (RUN SAVED)", 22, Color(0.1, 0.08, 0.12, 0.9), Color(0.6, 0.55, 0.6, 0.5))
	to_title.pressed.connect(func(): title_pressed.emit())
	offer.add_child(_centered(to_title))
	_end_offer_back = to_title
	_end_offer = offer
	# End of an endless loop: go deeper, or leave with a coin bonus.
	var loop := VBoxContainer.new()
	loop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loop.add_theme_constant_override("separation", 18)
	col.add_child(loop)
	_loop_deeper_button = button("DESCEND DEEPER", 28, Color(0.45, 0.16, 0.12, 0.97), Color(1, 0.75, 0.4))
	_loop_deeper_button.custom_minimum_size = Vector2(380, 86)
	_loop_deeper_button.pressed.connect(func(): loop_deeper.emit())
	loop.add_child(_centered(_loop_deeper_button))
	_loop_bank_button = button("BANK AND LEAVE", 24, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	_loop_bank_button.custom_minimum_size = Vector2(380, 74)
	_loop_bank_button.pressed.connect(func(): loop_bank.emit())
	loop.add_child(_centered(_loop_bank_button))
	_end_loop = loop
	_end_loop.visible = false


func _build_pause() -> void:
	_pause_box = overlay(Color(0, 0, 0, 0.7))
	add_child(_pause_box)
	var col := VBoxContainer.new()
	full(col)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	# Tight enough that the whole menu fits a 16:9 phone.
	col.add_theme_constant_override("separation", 12)
	_pause_box.add_child(col)
	_pause_title = label("PAUSED", 52, Color(1, 0.85, 0.55))
	col.add_child(_pause_title)
	# Version 374 (visual review of 366, fix 7): whose run this is, over the frozen fight.
	_pause_run = _build_pause_run()
	col.add_child(_centered(_pause_run))
	var resume := button("RESUME", 32, Color(0.45, 0.16, 0.12, 0.97), Color(1, 0.75, 0.4))
	resume.custom_minimum_size = Vector2(300, 86)
	resume.pressed.connect(_on_resume_pressed)
	_resume_button = resume
	col.add_child(_centered(resume))
	# Version 159: the switches sit together on one dark card, so the menu reads as
	# "Resume, your settings, leave" instead of a wall of blue buttons.
	var card := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.06, 0.045, 0.1, 0.82)
	csb.border_color = Color(1, 0.8, 0.45, 0.28)
	csb.set_border_width_all(2)
	csb.set_corner_radius_all(22)
	csb.content_margin_left = 16
	csb.content_margin_right = 16
	csb.content_margin_top = 8
	csb.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", csb)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sc := VBoxContainer.new()
	sc.add_theme_constant_override("separation", 10)
	sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(sc)
	_pause_head = label("SETTINGS", 16, Color(1, 0.85, 0.55, 0.75))
	sc.add_child(_pause_head)
	col.add_child(_centered(card))
	# Version 219: Music and Sounds share a row, to make room for the comfort settings.
	_music_button = button("Music: On", 18)
	_music_button.custom_minimum_size = Vector2(212, 66)
	_music_button.pressed.connect(func(): music_toggled.emit(not _music_on))
	_sounds_button = button("Sounds: On", 18)
	_sounds_button.custom_minimum_size = Vector2(212, 66)
	_sounds_button.pressed.connect(func(): sounds_toggled.emit(not _sounds_on))
	var mpair := _pair(_music_button, _sounds_button)
	mpair.add_theme_constant_override("separation", 12)
	sc.add_child(mpair)
	_more_button = button("MORE SETTINGS", 18)
	_more_button.custom_minimum_size = Vector2(436, 66)
	_more_button.pressed.connect(func():
		Sfx.play("click")
		_pause_more = true
		_show_pause_rows())
	sc.add_child(_centered(_more_button))
	_graphics_button = button("Graphics: High", 26)
	# High, Medium, Low, Low at a steady 30, then back to High.
	_graphics_button.pressed.connect(func(): graphics_toggled.emit((_graphics_level + 3) % 4))
	sc.add_child(_centered(_graphics_button))
	_pause_rows.append(sc.get_child(sc.get_child_count() - 1))
	# Full, Reduced, Off, then back to Full.
	_shake_button = button("Shake: Full", 18)
	_shake_button.custom_minimum_size = Vector2(212, 66)
	_shake_button.pressed.connect(func(): shake_changed.emit((_shake_level + 2) % 3))
	# Version 219 (review 4 fix 32): screen flashes on their own setting (they followed shake).
	_flashes_button = button("Flashes: Full", 18)
	_flashes_button.custom_minimum_size = Vector2(212, 66)
	_flashes_button.pressed.connect(func(): flashes_changed.emit((_flashes_level + 2) % 3))
	var spair := _pair(_shake_button, _flashes_button)
	spair.add_theme_constant_override("separation", 12)
	sc.add_child(spair)
	_pause_rows.append(spair)
	# Vibration and Colour-blind share a row (version 148), so the menu still fits a 16:9 phone.
	_vibration_button = button("Vibration: On", 18)
	_vibration_button.custom_minimum_size = Vector2(212, 66)
	_vibration_button.pressed.connect(func(): vibration_toggled.emit(not _vibration_on))
	# Colour-blind warnings (accessibility review item 1): attack warnings in a colour that
	# stands out from each floor for every kind of colour blindness.
	_colorblind_button = button("Colour-blind: Off", 18)
	_colorblind_button.custom_minimum_size = Vector2(212, 66)
	_colorblind_button.pressed.connect(func(): colorblind_toggled.emit(not _colorblind_on))
	var vpair := _pair(_vibration_button, _colorblind_button)
	vpair.add_theme_constant_override("separation", 12)
	sc.add_child(vpair)
	_pause_rows.append(vpair)
	# Version 219 (review 4 fix 32): DASH and the special on the left, bigger fight buttons,
	# and a lighter Eclipse.
	_left_button = button("Left hand: Off", 16)
	_left_button.custom_minimum_size = Vector2(140, 66)
	_left_button.pressed.connect(func(): left_hand_toggled.emit(not _left_on))
	_size_button = button("Buttons: Normal", 16)
	_size_button.custom_minimum_size = Vector2(140, 66)
	_size_button.pressed.connect(func(): button_size_changed.emit((_size_level + 1) % 3))
	_dark_button = button("Darkness: Full", 16)
	_dark_button.custom_minimum_size = Vector2(140, 66)
	_dark_button.pressed.connect(func(): darkness_toggled.emit(not _dark_light))
	var trio := HBoxContainer.new()
	trio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trio.alignment = BoxContainer.ALIGNMENT_CENTER
	trio.add_theme_constant_override("separation", 8)
	for b: Button in [_left_button, _size_button, _dark_button]:
		trio.add_child(b)
	sc.add_child(trio)
	_pause_rows.append(trio)
	# Reports and reminders share a row (version 143), so the menu still fits a 16:9 phone.
	_reports_button = button("Send reports: Off", 18)
	_reports_button.custom_minimum_size = Vector2(212, 66)
	_reports_button.pressed.connect(func(): reports_toggled.emit(not _reports_on))
	_reminders_button = button("Reminders: Off", 18)
	_reminders_button.custom_minimum_size = Vector2(212, 66)
	_reminders_button.pressed.connect(func(): reminders_toggled.emit(not _reminders_on))
	var pair := _pair(_reports_button, _reminders_button)
	pair.add_theme_constant_override("separation", 12)
	sc.add_child(pair)
	_pause_rows.append(pair)
	# Three small buttons side by side, so the menu still fits a 16:9 phone.
	var small := HBoxContainer.new()
	small.alignment = BoxContainer.ALIGNMENT_CENTER
	small.add_theme_constant_override("separation", 8)
	small.add_child(privacy_button(16))
	var fb := button("SEND FEEDBACK", 16, Color(0.08, 0.07, 0.1, 0.85), Color(1, 0.8, 0.45, 0.5))
	fb.add_theme_color_override("font_color", Color(1, 0.88, 0.62))
	fb.custom_minimum_size = Vector2(160, 64)
	fb.pressed.connect(show_feedback.bind(true))
	small.add_child(fb)
	# Rate us: opens the game's Google Play page (the in-app rating card is only for happy moments).
	var rate := button("RATE US", 16, Color(0.08, 0.07, 0.1, 0.85), Color(1, 0.8, 0.45, 0.5))
	rate.add_theme_color_override("font_color", Color(1, 0.88, 0.62))
	rate.custom_minimum_size = Vector2(150, 64)
	rate.pressed.connect(func():
		Sfx.play("click")
		UpdateGate.open_store_page())
	small.add_child(rate)
	_rate_button = rate
	(small.get_child(0) as Control).custom_minimum_size = Vector2(160, 64)
	col.add_child(small)
	_pause_rows.append(small)
	_quit_button = button("QUIT RUN", 24, Color(0.1, 0.08, 0.12, 0.9), Color(0.6, 0.55, 0.6, 0.5))
	_quit_button.pressed.connect(_on_quit_pressed)
	col.add_child(_centered(_quit_button))
	_toggle_look(_graphics_button, true)
	_toggle_look(_shake_button, true)
	_toggle_look(_flashes_button, true)
	_toggle_look(_size_button, true)
	_toggle_look(_dark_button, true)
	# SPEED TEST, in the same place on the title's Settings (where there's no run to quit).
	_speed_button = button("SPEED TEST", 22, Color(0.1, 0.08, 0.12, 0.9), Color(0.6, 0.55, 0.6, 0.5))
	_speed_button.pressed.connect(func():
		Sfx.play("click")
		speed_test_pressed.emit())
	col.add_child(_centered(_speed_button))
	(_speed_button.get_parent() as Control).visible = false   # (no gap for it in the pause menu)
	# Testers can say which build they were playing; the install number is what the privacy
	# policy asks for to delete someone's reports (shown even with reports off).
	_pause_build = label("Build " + Game.BUILD, 16, Color(0.6, 0.57, 0.65))
	col.add_child(_pause_build)
	# Version 227: the title's Settings has BACK in the bottom-left corner like every other
	# screen (it used to be the pause menu's big RESUME button, renamed, at the top).
	_settings_back = back_corner(button("BACK", 26))
	_settings_back.pressed.connect(_on_resume_pressed)
	_settings_back.visible = false
	_pause_box.add_child(_settings_back)


## The pause menu's run card (version 374): the hero's face and name, where the run stands
## (place, floor, room), what it has earned, and every blessing taken so far. The fight
## stays in sight behind a lighter veil, so pausing reads as "the game holds its breath",
## not "a menu opened".
func _build_pause_run() -> Control:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(452, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.07, 0.19, 0.93)
	sb.border_color = Color(1, 0.8, 0.45, 0.8)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 14)
	v.add_child(top)
	var face := HeroBadge.new()
	face.custom_minimum_size = Vector2(88, 88)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(face)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override("separation", 3)
	top.add_child(words)
	_pause_hero = label("", 24, Color(1, 0.93, 0.8), HORIZONTAL_ALIGNMENT_LEFT)
	chunky(_pause_hero.label_settings)
	_pause_hero.label_settings.outline_size = 6
	_pause_hero.autowrap_mode = TextServer.AUTOWRAP_OFF
	_pause_hero.clip_text = true
	words.add_child(_pause_hero)
	# the health, as the bar the fight shows it (the fight's own bars are away while paused)
	var hp := Control.new()
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.custom_minimum_size = Vector2(0, 28)
	words.add_child(hp)
	_pause_hp_fill = _bar(hp, Color(0.92, 0.2, 0.24))
	_pause_hp = label("", 17)
	chunky(_pause_hp.label_settings)
	_pause_hp.label_settings.outline_size = 5
	_pause_hp.label_settings.shadow_size = 0
	_pause_hp.autowrap_mode = TextServer.AUTOWRAP_OFF
	full(_pause_hp)
	hp.add_child(_pause_hp)
	_pause_where = label("", 17, Color(0.86, 0.82, 0.98), HORIZONTAL_ALIGNMENT_LEFT)
	_pause_where.autowrap_mode = TextServer.AUTOWRAP_OFF
	_pause_where.clip_text = true
	words.add_child(_pause_where)
	var stats := HBoxContainer.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_theme_constant_override("separation", 16)
	words.add_child(stats)
	_pause_room = label("", 17, Color(1, 0.95, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
	_pause_room.autowrap_mode = TextServer.AUTOWRAP_OFF
	stats.add_child(_pause_room)
	_pause_coins = coin_row(17, stats)
	_pause_score = label("", 17, Color(0.75, 0.9, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	_pause_score.autowrap_mode = TextServer.AUTOWRAP_OFF
	stats.add_child(_pause_score)
	# the blessings taken this run
	_pause_bless_head = label("YOUR BLESSINGS", 14, Color(1, 0.85, 0.55, 0.8), HORIZONTAL_ALIGNMENT_LEFT)
	v.add_child(_pause_bless_head)
	_pause_bless = HFlowContainer.new()
	_pause_bless.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_bless.add_theme_constant_override("h_separation", 3)
	_pause_bless.add_theme_constant_override("v_separation", 3)
	v.add_child(_pause_bless)
	return card


## Fills the run card for the run as it stands now.
func _fill_pause_run() -> void:
	var h := Game.hero
	if h == null or not is_instance_valid(h):
		return
	_pause_hero.text = Heroes.full_name(Heroes.get_hero(h.hero_id))
	var look := Floors.current()
	_pause_where.text = "Floor %d  ·  %s" % [Game.floor_num, str(look.get("name", "Crypt"))]
	_pause_room.text = _room_text
	_pause_hp.text = "%d / %d" % [ceili(h.health), roundi(h.max_health)]
	_pause_hp_fill.anchor_right = clampf(h.health / maxf(h.max_health, 1.0), 0.0, 1.0)
	_pause_coins.text = "+" + Hud.thousands(Game.run_coins)
	_pause_score.text = "Score %d" % Game.score
	for c in _pause_bless.get_children():
		_pause_bless.remove_child(c)
		c.queue_free()
	var taken: Dictionary = Game._taken
	for id in taken:
		var u := Upgrades.get_def(str(id))
		if u.is_empty():
			continue
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.custom_minimum_size = Vector2(40, 40)
		var ic := BlessingIcon.new()
		ic.show_for(u)
		ic.scale = Vector2(0.62, 0.62)
		holder.add_child(ic)
		if int(taken[id]) > 1:
			var n := label("x%d" % int(taken[id]), 13, Color.WHITE)
			n.position = Vector2(20, 22)
			n.size = Vector2(24, 18)
			holder.add_child(n)
		_pause_bless.add_child(holder)
	var any := _pause_bless.get_child_count() > 0
	_pause_bless.visible = any
	_pause_bless_head.text = "YOUR BLESSINGS" if any else "No blessings yet: clear a room to choose one."


## SEND FEEDBACK (pause menu and settings): testers type a note that goes to the
## developer's reports sheet with the build, phone and where they are in the game.
## It sits near the top so the phone's keyboard doesn't cover the box.
const FEEDBACK_MAX := 1500


func _build_feedback() -> void:
	_fb_box = overlay(Color(0.03, 0.02, 0.05, 0.96))
	_fb_box.visible = false
	add_child(_fb_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	col.offset_left = 24
	col.offset_right = -24
	col.offset_top = 56
	col.add_theme_constant_override("separation", 12)
	_fb_box.add_child(col)
	col.add_child(label("SEND FEEDBACK", 40, Color(1, 0.85, 0.55)))
	col.add_child(label("What did you enjoy? What felt too hard, unfair or broken? Every note is read.", 19, Color(0.85, 0.83, 0.9)))
	_fb_text = TextEdit.new()
	_fb_text.custom_minimum_size = Vector2(0, 210)
	_fb_text.placeholder_text = "Type your note here..."
	_fb_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_fb_text.add_theme_font_size_override("font_size", 22)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.13)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 0.8, 0.45, 0.5)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	_fb_text.add_theme_stylebox_override("normal", sb)
	_fb_text.add_theme_stylebox_override("focus", sb)
	_fb_text.text_changed.connect(_on_feedback_changed)
	col.add_child(_fb_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var cancel := button("CANCEL", 24)
	cancel.custom_minimum_size = Vector2(190, 72)
	cancel.pressed.connect(show_feedback.bind(false))
	row.add_child(cancel)
	_fb_send = button("SEND", 26, Color(0.45, 0.16, 0.12, 0.97), Color(1, 0.75, 0.4))
	_fb_send.custom_minimum_size = Vector2(190, 72)
	_fb_send.pressed.connect(_on_feedback_send)
	row.add_child(_fb_send)
	col.add_child(row)
	_fb_note = label("", 16, Color(0.65, 0.62, 0.7))
	col.add_child(_fb_note)


const FEEDBACK_NOTE := "Sent with the build, your phone model and where you are in the game, even with reports off. No name or account, so please leave out personal details."


func show_feedback(on: bool) -> void:
	_fb_box.visible = on
	if on:
		_fb_note.text = FEEDBACK_NOTE
		_fb_note.label_settings.font_color = Color(0.65, 0.62, 0.7)
		_on_feedback_changed()
		_fb_text.grab_focus()
	else:
		_fb_text.release_focus()
		DisplayServer.virtual_keyboard_hide()


func feedback_visible() -> bool:
	return _fb_box.visible


func _on_feedback_changed() -> void:
	if _fb_text.text.length() > FEEDBACK_MAX:
		_fb_text.text = _fb_text.text.left(FEEDBACK_MAX)
		_fb_text.set_caret_line(_fb_text.get_line_count() - 1)
		_fb_text.set_caret_column(_fb_text.get_line(_fb_text.get_line_count() - 1).length())
	_fb_send.disabled = _fb_text.text.strip_edges().length() < 3


func _on_feedback_send() -> void:
	var note := _fb_text.text.strip_edges()
	if note.length() < 3:
		return
	if Telemetry.instance == null or not Telemetry.instance.send_feedback(note):
		_fb_note.text = "Feedback can only be sent from the Google Play version of the game."
		_fb_note.label_settings.font_color = Color(1, 0.6, 0.5)
		return
	_fb_text.text = ""
	_fb_send.disabled = true
	_fb_text.release_focus()
	DisplayServer.virtual_keyboard_hide()
	_fb_note.text = "Thanks! Your note is on its way (it waits on your phone if you're offline)."
	_fb_note.label_settings.font_color = Color(0.6, 1, 0.65)
	get_tree().create_timer(1.8, true, false, true).timeout.connect(func():
		if _fb_text.text == "":
			show_feedback(false))


func _on_resume_pressed() -> void:
	Sfx.play("click")
	if _settings_only:
		show_settings(false)
	else:
		resume_pressed.emit()


## The blessing cards and doors, put away at once (a Crypt Race ended while they showed).
func hide_choices() -> void:
	_cards_box.visible = false
	_doors_box.visible = false


## In a Crypt Race the rival doesn't stop, and leaving counts as a loss.
func _quit_text() -> String:
	# v392 (review v388 fix 4, one capitals rule): a button that does something is in
	# capitals (DASH, RESUME, QUIT RUN); a setting is "Name: Value".
	return "LEAVE RACE (A LOSS)" if Game.race else "QUIT RUN"


## Quitting loses the run, so the first tap only asks; a second tap within 3 s quits.
func _on_quit_pressed() -> void:
	Sfx.play("click")
	if _quit_armed:
		_disarm_quit()
		quit_run_pressed.emit()
		return
	_quit_armed = true
	_quit_button.text = "TAP AGAIN TO QUIT"
	_quit_button.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
	get_tree().create_timer(3.0, true, false, true).timeout.connect(_disarm_quit)


func _disarm_quit() -> void:
	_quit_armed = false
	_quit_button.text = _quit_text()
	_quit_button.add_theme_color_override("font_color", Color(1, 0.93, 0.8))


## The shop for permanent upgrades, opened from the title or death screen.
func _build_armory() -> void:
	_armory_box = overlay(Color(0.03, 0.02, 0.05, 0.94), "forge")
	add_child(_armory_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 20
	col.offset_right = -20
	col.offset_top = 24
	col.offset_bottom = -24
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	_armory_box.add_child(col)
	_shop_title = label("ARMORY", 46, Color(1, 0.85, 0.55))
	col.add_child(_shop_title)
	_shop_sub = label("Upgrades bought here last forever.", 18, Color(0.8, 0.8, 0.85))
	col.add_child(_shop_sub)
	var tabs := []
	# Version 312: a fourth tab, the Legend Vault (legends.gd); the four share the width.
	for tab in [["upgrades", "UPGRADES"], ["vault", "VAULT"], ["bazaar", "BAZAAR"], ["legends", "LEGENDS"]]:
		var tb := button(tab[1], 17)
		tb.custom_minimum_size = Vector2(114, 64)
		var id: String = tab[0]
		tb.pressed.connect(func():
			Sfx.play("click")
			_armory_tab = id
			_fill_shop(_shop_rows, _shop_coins)
			_armory_scroll.scroll_vertical = 0)
		_tab_buttons[id] = tb
		if id == "bazaar":
			_bazaar_tab_badge = _badge_pill("NEW")
			_bazaar_tab_badge.offset_left = -52
			tb.add_child(_bazaar_tab_badge)
		tabs.append(tb)
	_armory_tabs = _pair(tabs[0], tabs[1])
	_armory_tabs.add_theme_constant_override("separation", 8)
	_armory_tabs.add_child(tabs[2])
	_armory_tabs.add_child(tabs[3])
	col.add_child(_armory_tabs)
	# Version 225 (Jesse: "I can't even scroll down"): the cards scroll inside a dark window
	# that fills the screen down to BACK, so BACK never covers a card. The window fades at
	# an edge only while there is more to see past it.
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(frame)
	var bg := Panel.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = SHOP_WELL
	sb.border_color = Color(0.24, 0.18, 0.26)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	bg.add_theme_stylebox_override("panel", sb)
	frame.add_child(full(bg))
	_armory_scroll = ScrollContainer.new()
	_armory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	full(_armory_scroll)
	_armory_scroll.offset_left = 4
	_armory_scroll.offset_top = 4
	_armory_scroll.offset_right = -4
	_armory_scroll.offset_bottom = -4
	frame.add_child(_armory_scroll)
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 8)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 14)
	_armory_scroll.add_child(pad)
	_armory_rows = VBoxContainer.new()
	_armory_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_armory_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_armory_rows.add_theme_constant_override("separation", 8)
	pad.add_child(_armory_rows)
	_armory_fades = []
	for top: bool in [true, false]:
		var g := Gradient.new()
		g.set_color(0, Color(SHOP_WELL, 1.0) if top else Color(SHOP_WELL, 0.0))
		g.set_color(1, Color(SHOP_WELL, 0.0) if top else Color(SHOP_WELL, 1.0))
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
		fade.offset_left = 4
		fade.offset_right = -4
		fade.offset_top = 4.0 if top else -40.0
		fade.offset_bottom = 40.0 if top else -4.0
		frame.add_child(fade)
		_armory_fades.append(fade)
	var bar := _armory_scroll.get_v_scroll_bar()
	bar.value_changed.connect(func(_v: float): _shop_fades())
	bar.changed.connect(_shop_fades)
	var back := button("BACK", 26)
	back.pressed.connect(func(): show_armory(false))
	_frame(_armory_box, col, back)
	# Your coins sit in a purse in the bottom corner, level with BACK (they took a row
	# above the cards before).
	_armory_purse = PanelContainer.new()
	_armory_purse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.1, 0.07, 0.04, 0.95)
	ps.border_color = Color(GOLD, 0.8)
	ps.set_border_width_all(2)
	ps.border_width_bottom = 4
	ps.set_corner_radius_all(18)
	ps.content_margin_left = 14
	ps.content_margin_right = 18
	ps.content_margin_top = 6
	ps.content_margin_bottom = 8
	_armory_purse.add_theme_stylebox_override("panel", ps)
	_armory_coins = coin_row(28, _armory_purse)
	_armory_purse.anchor_left = 1.0
	_armory_purse.anchor_right = 1.0
	_armory_purse.anchor_top = 1.0
	_armory_purse.anchor_bottom = 1.0
	_armory_purse.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_armory_purse.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_armory_purse.offset_left = -24
	_armory_purse.offset_right = -24
	_armory_purse.offset_top = -36
	_armory_purse.offset_bottom = -36
	_armory_box.add_child(_armory_purse)


## The window's edge fades show only while there are more cards past that edge.
func _shop_fades() -> void:
	if _armory_scroll == null or _armory_fades.size() < 2:
		return
	var bar := _armory_scroll.get_v_scroll_bar()
	var v := bar.value
	(_armory_fades[0] as Control).visible = v > 2.0
	(_armory_fades[1] as Control).visible = v + bar.page < bar.max_value - 2.0


## A tap on a card in the Armory window counts only if the list wasn't dragged with it
## (the finger can drag the list from on top of a card).
func _shop_tap(b: Button, act: Callable) -> void:
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.button_down.connect(func(): _shop_down_at = _armory_scroll.scroll_vertical)
	b.pressed.connect(func():
		if absi(_armory_scroll.scroll_vertical - _shop_down_at) <= 6:
			act.call())


## The Crypt Pass screen. Version 279: the Early Access Deal ribbon on top while a sale runs
## in Play Console, the Pass's four own bosses in their own places (the biggest thing it
## opens, which the old screen never showed), three smaller tiles, then the price (the full
## one struck through during the deal) and buy / restore. Pictures in art/ui.
func _build_pass() -> void:
	_pass_box = overlay(Color(0.03, 0.02, 0.05, 0.97), "vault")
	add_child(_pass_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 16
	col.offset_right = -16
	col.offset_top = 16
	col.offset_bottom = -16
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	_pass_box.add_child(col)
	_pass_col = col
	_pass_deal = _deal_ribbon(28)
	col.add_child(_centered(_pass_deal))
	col.add_child(label("CRYPT PASS", 48, GOLD))
	col.add_child(label("One-time purchase. No ads. No subscription.\nYours forever.", 18, Color(0.88, 0.85, 0.78)))
	col.add_child(_centered(_pass_bosses()))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	for tile in [["looks", "Crypt King set"], ["daily", "Daily practice"], ["curses", "All %d Curses" % Curses.LIST.size()]]:
		row.add_child(_pass_tile(tile[0], tile[1]))
	_pass_more = label("", 16, Color(0.88, 0.85, 0.78))
	col.add_child(_pass_more)
	# During the deal: "Normally $4.99", the price struck through in red.
	var was := HBoxContainer.new()
	was.mouse_filter = Control.MOUSE_FILTER_IGNORE
	was.alignment = BoxContainer.ALIGNMENT_CENTER
	was.add_theme_constant_override("separation", 10)
	var normally := label("Normally", 20, Color(0.8, 0.78, 0.74))
	normally.autowrap_mode = TextServer.AUTOWRAP_OFF
	was.add_child(normally)
	_pass_was_price = label("", 24, Color(0.85, 0.83, 0.8))
	_pass_was_price.autowrap_mode = TextServer.AUTOWRAP_OFF
	var strike := ColorRect.new()
	strike.color = Color(1.0, 0.25, 0.2)
	strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strike.anchor_right = 1.0
	strike.anchor_top = 0.5
	strike.anchor_bottom = 0.5
	strike.offset_left = -4
	strike.offset_right = 4
	strike.offset_top = -2
	strike.offset_bottom = 2
	_pass_was_price.add_child(strike)
	was.add_child(_pass_was_price)
	_pass_was = was
	col.add_child(was)
	_pass_buy = button("UNLOCK", 32, Color(0.45, 0.3, 0.08, 0.98), GOLD)
	_pass_buy.custom_minimum_size = Vector2(320, 86)
	_pass_buy.pressed.connect(func(): pass_buy.emit())
	col.add_child(_centered(_pass_buy))
	_pass_status = label("", 18, Color(1, 0.75, 0.6))
	col.add_child(_pass_status)
	_pass_dev = label("Bone Chain is made by one developer.\nThank you for keeping it going!", 15, Color(0.7, 0.68, 0.74))
	col.add_child(_pass_dev)
	_pass_back = button("NOT NOW", 26)
	_pass_back.custom_minimum_size = Vector2(320, 70)
	_pass_back.pressed.connect(func(): show_pass(false))
	_pass_restore = button("Restore purchase", 18, Color(0.1, 0.08, 0.12, 0.9), Color(0.6, 0.55, 0.6, 0.5))
	_pass_restore.custom_minimum_size = Vector2(220, 64)
	_pass_restore.pressed.connect(func(): pass_restore.emit())
	# Version 280: FREE DIVE beside NOT NOW, while this save can still take it (Game.dive_ready).
	_pass_dive = button("FREE DIVE", 26)
	paint(_pass_dive, "green")   # a way in (as PLAY); NOT NOW goes quiet beside it
	_pass_dive.custom_minimum_size = Vector2(240, 70)
	_pass_dive.pressed.connect(func():
		Sfx.play("click")
		pass_dive.emit())
	var last := HBoxContainer.new()
	last.mouse_filter = Control.MOUSE_FILTER_IGNORE
	last.alignment = BoxContainer.ALIGNMENT_CENTER
	last.add_theme_constant_override("separation", 14)
	last.add_child(_pass_dive)
	last.add_child(_pass_back)
	col.add_child(last)
	col.add_child(_pair(_pass_restore, privacy_button()))


## Version 279: the Early Access Deal's ribbon: deep red with a gold edge and glow, the deal
## on top ("EARLY ACCESS DEAL · 40% OFF") and the time left under it (filled in by
## _show_deal). It beats gently while it shows (_beat_deals).
func _deal_ribbon(size: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.6, 0.07, 0.09, 0.98)
	sb.border_color = GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(1.0, 0.7, 0.2, 0.45)
	sb.shadow_size = 12
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	panel.add_child(v)
	var t := label("EARLY ACCESS DEAL", size, Color(1.0, 0.92, 0.55))
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(t)
	var left := label("", maxi(15, size - 10), Color(1, 0.96, 0.9))
	left.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(left)
	panel.visible = false
	_deal_ribbons.append(panel)
	return panel


## Fills a deal ribbon from Store.deal_now() (hidden when no deal runs).
func _show_deal(panel: PanelContainer) -> void:
	var d := Store.deal_now()
	panel.visible = not d.is_empty()
	if d.is_empty():
		return
	var v := panel.get_child(0)
	(v.get_child(0) as Label).text = "EARLY ACCESS DEAL  ·  %d%% OFF" % int(d.pct)
	var left := Store.deal_left(d)
	(v.get_child(1) as Label).text = ("Ends in " + left) if left != "" else "For a short time only"


## Version 279: the deal ribbons beat gently, their countdowns tick, and when the deal ends
## while one shows, the screens under it are filled again (prices back to normal).
func _beat_deals(delta: float) -> void:
	_deal_tick += delta
	# The title's CRYPT PASS button beats with its deal tag too.
	if _title_pass_badge.visible and _title_pass_row.is_visible_in_tree():
		_title_pass_row.pivot_offset = _title_pass_row.size * 0.5
		var kb := 1.0 + 0.04 * maxf(0.0, sin(_deal_tick * 4.2))
		_title_pass_row.scale = Vector2(kb, kb)
	elif _title_pass_row.scale != Vector2.ONE:
		_title_pass_row.scale = Vector2.ONE
	var any := false
	for r: PanelContainer in _deal_ribbons:
		if r.is_visible_in_tree():
			any = true
			r.pivot_offset = r.size * 0.5
			var k := 1.0 + 0.035 * maxf(0.0, sin(_deal_tick * 4.2))
			r.scale = Vector2(k, k)
	if not any or fmod(_deal_tick, 0.5) > delta:
		return
	var d := Store.deal_now()
	if d.is_empty():
		# It just ended: the ribbons go and every screen shows the plain price again.
		for r: PanelContainer in _deal_ribbons:
			r.visible = false
		for l: Label in [_title_pass_badge, _end_pass_badge]:
			l.visible = false
		_tb(_title_pass_badge, false)
		_trim_title_badges()
		if Store.instance:
			Store.instance.changed.emit()
		return
	for r: PanelContainer in _deal_ribbons:
		if r.is_visible_in_tree():
			_show_deal(r)


## Version 279: the bosses only the Pass opens, each in its own place (pictures taken in the
## game, art/ui/pass_boss_*.png), under "5 NEW PLACES, 5 NEW BOSSES" (version 281: the
## Forgemaster made it five; it was four while the Foundry borrowed the Cinder Colossus).
func _pass_bosses() -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.08, 0.13, 1)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 0.8, 0.3, 0.55)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	v.add_child(label("5 NEW PLACES, 5 NEW BOSSES", 26, GOLD))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	v.add_child(row)
	for b in [["tidecaller", "Tidecaller", "Vault"], ["tyrant", "Crystal Tyrant", "Mine"],
			["archivist", "Archivist", "Library"], ["forgemaster", "Forgemaster", "Foundry"],
			["star_eater", "Star Eater", "Abyss"]]:
		var cell := VBoxContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_theme_constant_override("separation", 0)
		# Five across (version 281): each as wide as its picture, a two-word name on two lines
		# (every name gets room for two, so the places line up), the place in one word.
		cell.custom_minimum_size.x = 95
		var frame := PanelContainer.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fs := StyleBoxFlat.new()
		fs.bg_color = Color(0.05, 0.04, 0.06)
		fs.border_color = Color(1, 0.8, 0.3, 0.8)
		fs.set_border_width_all(2)
		fs.set_corner_radius_all(10)
		fs.set_content_margin_all(2)
		frame.add_theme_stylebox_override("panel", fs)
		var img := TextureRect.new()
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.custom_minimum_size = Vector2(95, 95)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var path := "res://art/ui/pass_boss_%s.png" % b[0]
		if ResourceLoader.exists(path):
			img.texture = load(path)
		frame.add_child(img)
		cell.add_child(frame)
		var n := label(b[1], 16, Color(1, 0.93, 0.8))
		n.custom_minimum_size = Vector2(95, 50)
		if not " " in str(b[1]):
			n.autowrap_mode = TextServer.AUTOWRAP_OFF   # one word is never broken
		n.add_theme_constant_override("line_spacing", -4)
		cell.add_child(n)
		var where := label(b[2], 16, Color(0.72, 0.72, 0.8))
		where.autowrap_mode = TextServer.AUTOWRAP_OFF
		cell.add_child(where)
		row.add_child(cell)
	v.add_child(label("Plus 5 new skeletons, then endless loops", 16, Color(0.85, 0.85, 0.9)))
	return panel


## Version 122: the Crypt Pass on the end screen showed your hero in the Crypt King set.
## v389 (review v388 fix 1): it is a slim gold strip under the buttons, words and a small
## SEE button, so the win screen's own hero on its rays always shows (the card hid it).
func _build_pass_card(col: Control) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.11, 0.04, 0.95)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	row.add_child(v)
	var t := label("CRYPT PASS", 24, GOLD)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(t)
	_pass_card_line = label("", 17, Color(0.97, 0.93, 0.84))
	_pass_card_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	_pass_card_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(_pass_card_line)
	var b := button("SEE", 22, Color(0.45, 0.3, 0.08, 0.98), GOLD)
	b.custom_minimum_size = Vector2(120, 58)
	b.pressed.connect(func(): pass_pressed.emit())
	_pass_card_btn = b
	row.add_child(b)
	_pass_card = _centered(panel)
	_pass_card.visible = false
	col.add_child(_pass_card)


## Shows the strip (`def`, the hero dressed in the set, says the Pass is worth showing), or hides it.
func show_pass_card(v: bool, def := {}) -> void:
	_pass_card.visible = v and not def.is_empty()
	# v218: on the free-end offer the big priced button below is the only way to the Pass.
	_pass_card_btn.visible = not _end_offer.visible
	if _pass_card.visible:
		_pass_card_line.text = "Endless floors and every hero"
		var deal := Store.deal_now()
		if not deal.is_empty():   # version 279
			_pass_card_line.text = "%d%% OFF for a short time!" % int(deal.pct)
	_fit_end_soon()


## One picture tile: the picture, a title and a line of text (filled in by show_pass).
## Version 279: three in a row under the bosses (two rows of two before).
func _pass_tile(pic: String, title: String) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(164, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.08, 0.13, 1)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 0.8, 0.3, 0.45)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 5
	sb.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	var img := TextureRect.new()
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.custom_minimum_size = Vector2(154, 74)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var path := "res://art/ui/pass_%s.png" % pic
	if ResourceLoader.exists(path):
		img.texture = load(path)
	v.add_child(img)
	var t := label(title, 17, Color(1, 0.93, 0.8))
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(t)
	var d := label("", 13, Color(0.78, 0.78, 0.84))
	d.custom_minimum_size = Vector2(154, 0)
	v.add_child(d)
	_pass_tiles.append(d)
	return panel


## `price` is Google Play's price text ("" until it arrives), `status` a line under the button.
func show_pass(v: bool, owned := false, price := "", status := "") -> void:
	_pass_box.visible = v
	if v:
		_park_toast()   # v218
	if not v:
		if Store.instance:
			Store.instance.cancel_wait()
		return
	var coins_of_heroes := 0
	for h: Dictionary in Heroes.LIST:
		coins_of_heroes += int(h.cost)
	_pass_tiles[0].text = "The grandest looks,\nfor every hero"
	_pass_tiles[1].text = "Play today's Daily\nagain and again"
	_pass_tiles[2].text = "Curse Level %d,\nplus hero rewards" % Curses.max_level()
	_pass_more.text = "Plus all 4 heroes now (no need to spend %s coins)." % Hud.thousands(coins_of_heroes)
	# v220 (v219 review): the event perks while an event runs.
	if not Events.current().is_empty():
		_pass_more.text = "Plus all 4 heroes now, and while the event runs:\n%s, +50%% %s." % [Events.word("pass_set"), Events.word("unit")]
	_pass_buy.disabled = owned
	# On a Play install the button waits for Play's price in the player's own currency;
	# elsewhere (the test build, which can't buy) it shows the US price.
	# Version 279: during the Early Access Deal, the deal's price.
	var d := Store.deal_now()
	var shown_price := price if price != "" else ("" if Store.can_buy() else Store.FALLBACK_PRICE)
	if not d.is_empty():
		shown_price = str(d.price)
	_pass_buy.text = "OWNED - THANK YOU!" if owned else ("UNLOCK  " + shown_price).strip_edges()
	_pass_buy.add_theme_font_size_override("font_size", 26 if owned else 32)
	_show_deal(_pass_deal)
	_pass_was.visible = not owned and not d.is_empty() and str(d.get("full", "")) != ""
	_pass_was_price.text = str(d.get("full", ""))
	_pass_status.text = status
	_pass_status.visible = status != ""
	_pass_dev.visible = not owned
	# Version 280: the Free Dive, from the title only (an end screen's run is still on).
	var dive := not owned and Game.state == Game.State.TITLE and Game.dive_ready()
	_pass_dive.visible = dive
	_pass_back.custom_minimum_size.x = 240 if dive else 320
	paint(_pass_back, "slate" if dive else "blue")
	_pass_dev.text = "Not sure yet? Dive into floor 6 once for free:\nthe Drowned Vault and its Tidecaller." if dive \
		else "Bone Chain is made by one developer.\nThank you for keeping it going!"
	_pass_back.text = "BACK" if owned else "NOT NOW"
	_pass_restore.visible = not owned
	_fit_pass.call_deferred()


## Version 279: short phones (16:9) shrink the whole Pass screen a little so its last row of
## buttons stays on screen (it grew with the bosses and the deal).
func _fit_pass() -> void:
	if not _pass_box.visible:
		return
	_pass_col.scale = Vector2.ONE
	_pass_col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pass_col.offset_left = 16
	_pass_col.offset_right = -16
	_pass_col.offset_top = 16
	_pass_col.offset_bottom = -16
	var room := _pass_box.size.y - 32.0
	var need := _pass_col.get_combined_minimum_size().y
	var k := minf(1.0, room / maxf(need, 1.0))
	_pass_col.pivot_offset = Vector2(_pass_col.size.x * 0.5, 0.0)
	_pass_col.scale = Vector2(k, k)
	if k < 1.0:
		_pass_col.position.y = 16.0 + (room - need * k) * 0.5


## The Daily Crypt screen: today's theme, hero and three rules, and START.
func _build_daily() -> void:
	_daily_box = overlay(Color(0.03, 0.02, 0.05, 0.96), "sundial")   # (version 408: the Sundial Court)
	add_child(_daily_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 22
	col.offset_right = -22
	col.offset_top = 24
	col.offset_bottom = -24
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	_daily_box.add_child(col)
	_daily_title = label("DAILY CRYPT", 46, GOLD)
	col.add_child(_daily_title)
	# Version 396 (visual review of v388, fix 9): the screen was all words. The day's hero
	# stands on the left in front of a sun, with the day's theme, floors and weather beside.
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	_daily_hero_box = Control.new()
	_daily_hero_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_daily_hero_box.custom_minimum_size = Vector2(176, 176)
	_daily_hero_box.draw.connect(_draw_daily_sun)
	_daily_hero = HeroStage.new(Vector2(176, 176))
	_daily_hero.soft_edge = true
	_daily_hero.custom_minimum_size = Vector2(176, 176)
	_daily_hero.size = Vector2(176, 176)
	_daily_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_daily_hero_box.add_child(_daily_hero)
	top.add_child(_daily_hero_box)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.custom_minimum_size = Vector2(290, 0)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 6)
	top.add_child(words)
	_daily_theme = label("", 24, Color(1, 0.93, 0.8), HORIZONTAL_ALIGNMENT_LEFT)
	words.add_child(_daily_theme)
	_daily_info = label("", 18, Color(0.8, 0.8, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	words.add_child(_daily_info)
	var sky := HBoxContainer.new()
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.add_theme_constant_override("separation", 8)
	words.add_child(sky)
	_daily_sky_icon = BlessingIcon.new()
	_daily_sky_icon.zoom = 0.7
	_daily_sky_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sky.add_child(_daily_sky_icon)
	_daily_sky = label("", 18, Color(1.0, 0.85, 0.5), HORIZONTAL_ALIGNMENT_LEFT)
	_daily_sky.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sky.add_child(_daily_sky)
	_daily_rules = VBoxContainer.new()
	_daily_rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_daily_rules.add_theme_constant_override("separation", 8)
	col.add_child(_daily_rules)
	_daily_status = label("", 18, Color(1, 0.8, 0.6))
	col.add_child(_daily_status)
	_daily_go = button("START", 30, Color(0.45, 0.3, 0.08, 0.98), GOLD)
	_daily_go.custom_minimum_size = Vector2(340, 86)
	_daily_go.pressed.connect(func():
		if _daily_open:
			_guarded(_daily_go, daily_start)
		else:
			pass_pressed.emit())
	col.add_child(_centered(_daily_go))
	_daily_next = label("", 16, Color(0.65, 0.63, 0.7))
	col.add_child(_daily_next)
	_daily_board = button("TODAY'S LEADERBOARD", 22, Color(0.05, 0.2, 0.1, 0.97), Color(0.5, 1.0, 0.65))
	_daily_board.custom_minimum_size = Vector2(340, 66)
	_daily_board.pressed.connect(func():
		Sfx.play("click")
		show_leaders("daily"))
	_daily_board.visible = false
	col.add_child(_centered(_daily_board))
	var back := button("BACK", 26)
	back.pressed.connect(func(): show_daily(false))
	_frame(_daily_box, col, back)


## info: {title, theme, theme_text, hero, mult, rules: [{title, text, kind}], status, open, practice, next}
func show_daily(v: bool, info := {}) -> void:
	_daily_box.visible = v
	_disarm(_daily_go)   # a first tap from before (then BACK) mustn't make the next tap start
	var def: Dictionary = info.get("hero_def", {})
	_daily_hero.set_active(v and not def.is_empty())
	if not v:
		return
	_daily_open = info.open
	_daily_title.text = info.title
	_daily_theme.text = "%s\n%s" % [info.theme, info.theme_text]
	_daily_info.text = "Hero: %s\n%d floors  ·  Score x%s" % [info.hero, Curses.DAILY_FLOORS, info.mult]
	if not def.is_empty():
		_daily_hero.show_hero(def)
	var sky: Dictionary = info.get("weather", {})
	_daily_sky.text = "%s\n%s" % [sky.get("name", ""), sky.get("text", "")]
	_daily_sky_icon.show_icon("w_" + str(sky.get("id", "clear")), "bolt", Color(1.0, 0.8, 0.4))
	for c in _daily_rules.get_children():
		c.queue_free()
	for r: Dictionary in info.rules:
		_daily_rules.add_child(_rule_row(r))
	_daily_status.text = info.status
	_daily_go.text = ("PLAY PRACTICE" if info.practice else "START OFFICIAL RUN") if info.open else "GET THE CRYPT PASS"
	_daily_go.add_theme_font_size_override("font_size", 26)
	_daily_next.text = info.next
	_daily_board.visible = Leaders.available()


## Version 137: the leaderboard screen, on "daily" or "best".
func show_leaders(key := "daily") -> void:
	_leaders.open(key)


func leaders_visible() -> bool:
	return _leaders.visible


func close_leaders() -> void:
	_leaders.close()


func daily_visible() -> bool:
	return _daily_box.visible


# ---------------------------------------------------------------- Omens

func _build_omens() -> void:
	_omen_box = overlay(Color(0.03, 0.01, 0.03, 0.96), "blood")
	add_child(_omen_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 22
	col.offset_right = -22
	col.offset_top = 24
	col.offset_bottom = -24
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	_omen_box.add_child(col)
	col.add_child(label("CHOOSE AN OMEN", 44, Color(0.95, 0.4, 0.42)))
	_omen_info = label("", 20, Color(1, 0.9, 0.8))
	col.add_child(_omen_info)
	_omen_rows = VBoxContainer.new()
	_omen_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_omen_rows.add_theme_constant_override("separation", 12)
	col.add_child(_omen_rows)
	_omen_have = label("", 17, Color(0.75, 0.72, 0.8))
	col.add_child(_omen_have)
	var back := button("BACK", 24)
	back.pressed.connect(func(): show_omens(false))
	_frame(_omen_box, col, back)


## choices: three Omens ({id, title, text}); `have` lists the Omens already in play.
func show_omens(v: bool, choices := [], next_loop := 2, have := "") -> void:
	_omen_box.visible = v
	if not v:
		return
	_omen_info.text = "Loop %d. Omens stack, and each adds +%d%% score.\nIn between loops: full health and +%d rerolls." % [next_loop,
		roundi(Loops.OMEN_SCORE * 100.0), Loops.LOOP_REROLLS]
	for c in _omen_rows.get_children():
		c.queue_free()
	for o: Dictionary in choices:
		# v241: the rule Omens say more, so their line breaks (an unbroken line widened the
		# whole screen past the phone's edge).
		var text := _break_line(str(o.text), 34)
		var b := button("%s  ·  +%d%% score\n%s" % [o.title, roundi(Loops.OMEN_SCORE * 100.0), text], 22, Color(0.16, 0.06, 0.09, 0.98), Color(0.95, 0.4, 0.42, 0.8))
		b.custom_minimum_size = Vector2(0, 92 + 28 * text.count("\n"))
		b.pressed.connect(func(): omen_picked.emit(o.id))
		_omen_rows.add_child(b)
	_omen_have.text = "Your Omens: " + have if have != "" else "No Omens yet"


func omens_visible() -> bool:
	return _omen_box.visible


## Breaks `text` into lines of at most about `width` letters, at spaces.
static func _break_line(text: String, width: int) -> String:
	var lines: Array[String] = []
	var line := ""
	for w in text.split(" "):
		if line != "" and line.length() + 1 + w.length() > width:
			lines.append(line)
			line = w
		else:
			line = w if line == "" else line + " " + w
	if line != "":
		lines.append(line)
	return "\n".join(lines)


# ---------------------------------------------------------------- Reports question

## Asked once, at the end of a run: reports stay off unless the player says yes.
func _build_reports_ask() -> void:
	_ask_box = overlay(Color(0.02, 0.01, 0.03, 1.0))
	add_child(_ask_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 30
	col.offset_right = -30
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	_ask_box.add_child(col)
	col.add_child(label("HELP FIX BUGS?", 40, GOLD))
	var text := label("Send anonymous crash and run reports?\nNo name, account or ad ID. Change it any time in Settings.", 21, Color(0.9, 0.88, 0.84))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text)
	# The full list, for anyone who wants it, one tap away.
	var more := label("Sent: a run summary, a short daily note, a random install number, your phone model, Android version and memory, and error messages with the game's recent log.", 16, Color(0.7, 0.68, 0.66))
	more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	more.visible = false
	var what := button("WHAT'S SENT?", 18, Color(0.08, 0.07, 0.1, 0.9), Color(0.5, 0.48, 0.5, 0.6))
	what.custom_minimum_size = Vector2(240, 64)
	what.pressed.connect(func():
		more.visible = not more.visible
		Sfx.play("click"))
	col.add_child(_centered(what))
	col.add_child(more)
	var yes := button("YES, SEND REPORTS", 26, Color(0.2, 0.32, 0.18, 0.97), Color(0.6, 0.95, 0.55))
	yes.custom_minimum_size = Vector2(360, 80)
	yes.pressed.connect(func(): reports_answered.emit(true))
	col.add_child(_centered(yes))
	var no := button("NO THANKS", 24)
	no.custom_minimum_size = Vector2(360, 70)
	no.pressed.connect(func(): reports_answered.emit(false))
	col.add_child(_centered(no))
	col.add_child(_centered(privacy_button()))


## Version 143: phone reminders, asked once on the title (see Game._ask_reminders_on_title).
func _build_reminders_ask() -> void:
	_rem_box = overlay(Color(0.02, 0.01, 0.03, 0.94))
	add_child(_rem_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 30
	col.offset_right = -30
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	_rem_box.add_child(col)
	col.add_child(label("NEVER MISS A NIGHT", 40, GOLD))
	_rem_text = label("", 22, Color(0.92, 0.9, 0.86))
	_rem_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_rem_text)
	var small := label("At most one a day, in the evening. Turn them off any time in Settings.", 17, Color(0.7, 0.68, 0.66))
	small.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(small)
	var yes := button("YES, REMIND ME", 26, Color(0.2, 0.32, 0.18, 0.97), Color(0.6, 0.95, 0.55))
	yes.custom_minimum_size = Vector2(360, 80)
	yes.pressed.connect(func(): reminders_answered.emit(true))
	col.add_child(_centered(yes))
	var no := button("NO THANKS", 24)
	no.custom_minimum_size = Vector2(360, 70)
	no.pressed.connect(func(): reminders_answered.emit(false))
	col.add_child(_centered(no))
	_rem_box.visible = false


## Version 213 (hardest review fix #14): the Pass was taken away after Google Play stopped
## showing it for 3 days (a refund, or a different Google account). It used to vanish
## without a word.
func _build_pass_lost() -> void:
	_lost_box = overlay(Color(0.02, 0.01, 0.03, 0.94))
	add_child(_lost_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 30
	col.offset_right = -30
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	_lost_box.add_child(col)
	col.add_child(label("CRYPT PASS NOT FOUND", 36, GOLD))
	var t := label("Google Play no longer shows the Crypt Pass on this phone's Google account, so it has been turned off.\n\nIf you bought it, open the Play Store, switch to the account you used, then tap RESTORE.", 21, Color(0.92, 0.9, 0.86))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	var yes := button("RESTORE", 26, Color(0.2, 0.32, 0.18, 0.97), Color(0.6, 0.95, 0.55))
	yes.custom_minimum_size = Vector2(360, 80)
	yes.pressed.connect(func():
		_lost_box.visible = false
		pass_lost_restore.emit())
	col.add_child(_centered(yes))
	var ok := button("OK", 24)
	ok.custom_minimum_size = Vector2(360, 70)
	ok.pressed.connect(func(): _lost_box.visible = false)
	col.add_child(_centered(ok))
	_lost_box.visible = false


func show_pass_lost(v: bool) -> void:
	_lost_box.visible = v


func pass_lost_visible() -> bool:
	return _lost_box != null and _lost_box.visible


## `event_name`: an event on now or coming soon, named in the question.
func show_reminders_ask(v: bool, event_name := "") -> void:
	if v:
		_rem_text.text = ("Get a reminder when the %s begins, when each new chapter opens, and when your Daily streak is about to end?" % event_name) \
				if event_name != "" else "Get a reminder when the Daily Crypt is ready, when events begin, and when your streak is about to end?"
	_rem_box.visible = v


func reminders_ask_visible() -> bool:
	return _rem_box.visible


## `blocked`: on in the game, but the phone won't show them (see PhoneReminders.blocked).
func set_reminders_label(on: bool, blocked := false) -> void:
	_reminders_on = on
	_reminders_button.text = ("Reminders: Blocked" if blocked else "Reminders: On") if on else "Reminders: Off"
	_toggle_look(_reminders_button, on and not blocked)


func show_reports_ask(v: bool) -> void:
	_ask_box.visible = v


func reports_ask_visible() -> bool:
	return _ask_box.visible


## A daily rule: green helps, red is a curse, gold is a trade-off.
func _rule_row(r: Dictionary) -> Control:
	var kinds := {"help": ["HELP", Color(0.5, 0.95, 0.55)], "harm": ["CURSE", Color(0.95, 0.4, 0.42)], "trade": ["TRADE", GOLD]}
	var k: Array = kinds.get(r.kind, kinds.harm)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.16, 0.98)
	sb.set_corner_radius_all(10)
	sb.border_width_left = 8
	sb.border_color = k[1]
	sb.content_margin_left = 18
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	if r.has("id"):   # version 396: each rule's own picture
		var icon := BlessingIcon.new()
		icon.zoom = 0.72
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.show_icon("c_" + str(r.id), "bone", k[1])
		h.add_child(icon)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	h.add_child(texts)
	var t := label(r.title, 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	texts.add_child(t)
	texts.add_child(label(r.text, 16, Color(0.78, 0.78, 0.84), HORIZONTAL_ALIGNMENT_LEFT))
	var tag := label(k[0], 18, k[1])
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(tag)
	return panel


func pass_visible() -> bool:
	return _pass_box.visible


## Test hook: pretend the phone has these notch margins (left, top, right, bottom, UI units).
static var fake_safe := Vector4.ZERO


## The space a notch, camera hole or rounded corners take on each side, in UI units:
## x = left, y = top, z = right, w = bottom. Zero off phones.
static func safe_margins(vp: Viewport) -> Vector4:
	if fake_safe != Vector4.ZERO:
		return fake_safe
	if not OS.has_feature("mobile") or vp == null:
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var size := vp.get_visible_rect().size
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0:
		return Vector4.ZERO
	var sx := size.x / win.x
	var sy := size.y / win.y
	return Vector4(maxf(0.0, safe.position.x * sx), maxf(0.0, safe.position.y * sy),
		maxf(0.0, (win.x - safe.end.x) * sx), maxf(0.0, (win.y - safe.end.y) * sy))


## Version 125 (audit #8): moves a control's edges in by the safe margins. The first call
## remembers the control's own offsets, so it can run every time a screen opens. An edge
## anchored to the left or top moves right or down, one anchored right or bottom moves back.
static func safe_pad(c: Control) -> void:
	if c == null or not c.is_inside_tree():
		return
	if not c.has_meta("safe_base"):
		c.set_meta("safe_base", Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom))
	var b: Vector4 = c.get_meta("safe_base")
	var m := safe_margins(c.get_viewport())
	c.offset_left = b.x + (m.x if c.anchor_left < 0.5 else -m.z)
	c.offset_right = b.z + (m.x if c.anchor_right < 0.5 else -m.z)
	c.offset_top = b.y + (m.y if c.anchor_top < 0.5 else -m.w)
	c.offset_bottom = b.w + (m.y if c.anchor_bottom < 0.5 else -m.w)


func _apply_safe_area() -> void:
	# Keep the HUD clear of notches and rounded corners (phones only).
	var m := safe_margins(get_viewport())
	if m == Vector4.ZERO and not OS.has_feature("mobile"):
		return
	_safe.add_theme_constant_override("margin_left", int(m.x))
	_safe.add_theme_constant_override("margin_top", int(m.y))
	_safe.add_theme_constant_override("margin_right", int(m.z))
	_safe.add_theme_constant_override("margin_bottom", int(m.w))
	_place_title_buttons()
	# Version 123: the framed menus (title at the top, BACK in the corner) keep clear of a
	# camera hole or rounded corners too; they used to sit in the middle, away from the edges.
	var top := float(_safe.get_theme_constant("margin_top"))
	var bottom := float(_safe.get_theme_constant("margin_bottom"))
	var left := float(_safe.get_theme_constant("margin_left"))
	for f: Array in _framed:
		var col: Control = f[0]
		var back: Control = f[1]
		col.offset_top = FRAME_TOP + top
		col.offset_bottom = -FRAME_BOTTOM - bottom
		back.offset_left = 24 + left
		back.offset_right = 204 + left
		back.offset_top = -96 - bottom
		back.offset_bottom = -24 - bottom
	if _settings_back != null:
		_settings_back.offset_left = 24 + left
		_settings_back.offset_right = 204 + left
		_settings_back.offset_top = -96 - bottom
		_settings_back.offset_bottom = -24 - bottom
	if _armory_purse != null:
		# (grows up and left from its corner, so only that corner moves)
		var right := float(_safe.get_theme_constant("margin_right"))
		_armory_purse.offset_right = -24 - right
		_armory_purse.offset_left = _armory_purse.offset_right
		_armory_purse.offset_bottom = -36 - bottom
		_armory_purse.offset_top = _armory_purse.offset_bottom


## The title's SETTINGS and RECORDS sit in the top corner, so they move below a notch or
## camera hole (the game runs full screen; the margins are 0 off phones).
func _place_title_buttons() -> void:
	if _safe == null or _title_settings == null or not is_instance_valid(_title_settings):
		return
	var left := float(_safe.get_theme_constant("margin_left"))
	var top := float(_safe.get_theme_constant("margin_top"))
	_title_settings.position = Vector2(20 + left, 20 + top)
	if is_instance_valid(_title_records):
		_title_records.position = Vector2(96 + left, 20 + top)
	if is_instance_valid(_title_pass_row):
		var rec_on := is_instance_valid(_title_records) and _title_records.visible
		_title_pass_row.position = Vector2((240.0 if rec_on else 96.0) + left, 20 + top)
	# Version 125: the coins, logo and the button column keep clear of the notch and the
	# gesture bar too (the corner buttons above already did).
	if is_instance_valid(_title_top):
		safe_pad(_title_top)
	if is_instance_valid(_title_bottom):
		safe_pad(_title_bottom)


# ---------------------------------------------------------------- input

func _overlay_open() -> bool:
	return _cards_box.visible or _doors_box.visible or _title_box.visible or _end_box.visible or _pause_box.visible or _armory_box.visible or _pass_box.visible \
		or _daily_box.visible or _omen_box.visible or _ask_box.visible or _rem_box.visible or _modes_box.visible or _heroes_box.visible \
		or _fb_box.visible or _records_box.visible or (_today_box != null and _today_box.visible) or _drops.visible or _road.visible or _mastery.visible or _style.visible \
		or _rewards_box.visible or _feats.visible or _event.visible or _splash.visible or _leaders.visible or race_screen.visible


func _input(event: InputEvent) -> void:
	if UpdateGate.instance and UpdateGate.instance.showing():
		return   # the UPDATE screen covers everything
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_button_touches.erase(t.index)
			if _end_box.visible and not _end_buttons.visible and not _end_offer.visible and not _end_loop.visible \
					and not _armory_box.visible and not _pass_box.visible and not _omen_box.visible and not _ask_box.visible and not _rem_box.visible \
					and not _heroes_box.visible and not _drops.visible \
					and not (_end_drop.visible and _end_drop.get_global_rect().has_point(t.position)) \
					and not (_end_looks.visible and _end_looks.get_global_rect().has_point(t.position)) and not _style.visible \
					and not _copy_button.get_global_rect().has_point(t.position) \
					and not (_end_title_button.visible and _end_title_btn.get_global_rect().has_point(t.position)) \
					and not (_share_button.visible and _share_button.get_global_rect().has_point(t.position)) \
					and not (_pass_card.visible and _pass_card_btn.is_visible_in_tree() and _pass_card_btn.get_global_rect().has_point(t.position)):
				screen_tapped.emit()
				return
			# The pause button looks small but answers a little way around it too. Version 282
			# (Tweaks report #8): every press is taken here, by any finger. The Button itself
			# ignores touches: Godot gives Buttons a pretend mouse click only from the first finger
			# down, so with a thumb on the stick a second finger's tap on II did nothing.
			if _safe.visible and _pause_button.get_global_rect().grow(12.0).has_point(t.position):
				if _pause_button.is_visible_in_tree() and not _overlay_open():
					Sfx.play("click")
					var bt := _pause_button.create_tween()
					bt.tween_property(_pause_button, "scale", Vector2(0.95, 0.93), 0.06)
					bt.tween_property(_pause_button, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
					pause_pressed.emit()
				return
			# Version 163 (Tweaks report #7): an empty SURGE lets the touch through to the stick.
			if _safe.visible and race_surge.visible and not _overlay_open() and race_surge.ready_now() \
					and race_surge.get_global_rect().grow(6.0).has_point(t.position):
				_button_touches[t.index] = true
				race_surge_pressed.emit()
				return
			# Version 213 (hardest review fix #12): a button faded for the hero under it lets the
			# touch through to the stick, so steering there never fires a dash or the special.
			if _safe.visible and _special.visible and not _overlay_open() and not _special.get_meta("hero_under", false) \
					and _special.get_global_rect().grow(4.0).has_point(t.position):
				_button_touches[t.index] = true
				special_pressed.emit()
				return
			if _safe.visible and _dash_button.visible and not _overlay_open() and not _dash_button.get_meta("hero_under", false) \
					and _dash_button.get_global_rect().grow(4.0).has_point(t.position):
				_button_touches[t.index] = true
				dash_pressed.emit()
				return
			if _stick_touch == -1 and not _overlay_open() and Game.state == Game.State.PLAYING:
				_stick_touch = t.index
				_stick_origin = t.position
				_stick_start = t.position
				_stick_start_ms = Time.get_ticks_msec()
				_stick.visible = true
				_stick.position = _stick_origin
				_stick.knob = Vector2.ZERO
				joystick = Vector2.ZERO
		elif _button_touches.erase(t.index):
			pass   # a thumb lifted off a button
		elif t.index == _stick_touch:
			var flick := t.position - _stick_start
			if Time.get_ticks_msec() - _stick_start_ms < int(FLICK_TIME * 1000.0) and flick.length() > FLICK_DISTANCE:
				dash_flicked.emit(flick.normalized())
			_release_stick()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		# Version 163 (Tweaks report #2): a thumb already down when the fight began (the race's
		# 3-2-1, a room fade) takes the stick as soon as it moves, instead of having to lift.
		if _stick_touch == -1 and not _overlay_open() and Game.state == Game.State.PLAYING and _safe.visible \
				and not _button_touches.has(d.index) \
				and not (_special.visible and not _special.get_meta("hero_under", false) and _special.get_global_rect().grow(4.0).has_point(d.position)) \
				and not (_dash_button.visible and not _dash_button.get_meta("hero_under", false) and _dash_button.get_global_rect().grow(4.0).has_point(d.position)) \
				and not (race_surge.visible and race_surge.get_global_rect().grow(6.0).has_point(d.position)) \
				and not _pause_button.get_global_rect().grow(12.0).has_point(d.position):
			_stick_touch = d.index
			_stick_origin = d.position
			_stick_start = d.position
			_stick_start_ms = Time.get_ticks_msec()
			_stick.visible = true
			_stick.position = _stick_origin
			_stick.knob = Vector2.ZERO
			joystick = Vector2.ZERO
		if d.index == _stick_touch:
			var delta := d.position - _stick_origin
			if delta.length() > STICK_RADIUS:
				# If the thumb drags past the edge, the stick follows it.
				_stick_origin += delta - delta.normalized() * STICK_RADIUS
				_stick.position = _stick_origin
				delta = delta.normalized() * STICK_RADIUS
			_stick.knob = delta
			var v := delta / STICK_RADIUS
			joystick = Vector2.ZERO if v.length() < 0.15 else v
			if joystick != Vector2.ZERO:
				last_move = joystick.normalized()
				last_move_ms = Time.get_ticks_msec()


func _release_stick() -> void:
	if joystick != Vector2.ZERO:
		last_move_ms = Time.get_ticks_msec()
	_stick_touch = -1
	_stick.visible = false
	joystick = Vector2.ZERO


func _on_card(i: int) -> void:
	# Ignore taps in the first moment so a thumb that was moving doesn't pick by accident.
	if not _cards_box.visible or _cards_age < 0.45 or _cards_picking or i >= _cards.size() or not _cards_ready[i]:
		return
	# Version 157: the chosen card rises and flares while the others drop away.
	_cards_picking = true
	for tw in _cards_tweens:
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).kill()
	_cards_tweens.clear()
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel()
	for k in _cards.size():
		var b := _cards[k]
		if k == i:
			b.get_node("Aura").visible = true
			b.get_node("Aura").modulate.a = 1.0
			tw.tween_property(b, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(b, "position:y", -14.0, 0.12)
			tw.tween_property(b, "modulate", Color(1.5, 1.4, 1.2), 0.1)
		else:
			tw.tween_property(b, "position:y", 90.0, 0.22).set_ease(Tween.EASE_IN)
			tw.tween_property(b, "modulate:a", 0.0, 0.2)
	tw.chain().tween_interval(0.12)
	tw.chain().tween_callback(func():
		_cards_picking = false
		if _cards_box.visible:   # (not if something closed the cards meanwhile)
			_cards_box.visible = false
			card_picked.emit(i))


# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	_event_process(delta)
	_place_status(delta)
	_beat_deals(delta)
	_cards_age += delta
	# Version 158: "SURGE READY!" (or PERFECT!) caught by the pause menu, the cards or an end
	# screen stayed on top of it, frozen.
	if _perfect_lbl and _perfect_lbl.visible and Game.state != Game.State.PLAYING:
		_perfect_lbl.visible = false
	_doors_age += delta
	# The title's words and buttons would show faintly through the screens opened over it.
	if _title_box.visible:
		_title_box.get_child(0).visible = not (_modes_box.visible or _daily_box.visible or _armory_box.visible \
			or _pass_box.visible or _heroes_box.visible or _records_box.visible or _omen_box.visible or _drops.visible or _road.visible \
			or _event.visible or _splash.visible or _leaders.visible or (_settings_only and _pause_box.visible))
		# v375: the PASS button is lifted over the event strip (z 1), which also lifted it
		# over a screen opened straight over the title (Rewards, Today's Goals, Mastery).
		if is_instance_valid(_title_pass_row):
			# (v408: and over the Crypt Race lobby, which isn't one of covers_world's screens)
			_title_pass_row.z_index = 0 if covers_world() or race_screen.visible else 1
	# The OPEN BONE DROP buttons glow gently, so a drop waiting isn't missed.
	if _title_drops.is_visible_in_tree() or _end_drop.is_visible_in_tree():
		var glow := 1.0 + 0.16 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 3.2))
		_title_drops.modulate = Color(glow, glow, glow)
		_end_drop.modulate = Color(glow, glow, glow)
	if _flash.color.a > 0.0:
		_flash.color.a = move_toward(_flash.color.a, 0.0, delta * 2.5)
	# Version 384: a see-through full-screen layer still costs a pass over every pixel, so
	# each one is hidden while it shows nothing.
	_flash.visible = _flash.color.a > 0.003
	_see_through(delta)
	_chain_box.position.y = CHAIN_TOP + (64.0 if _boss_box.visible else 0.0)
	# Version 404: in a boss fight the coins sit in the boss plate's top left corner (under
	# the plate they were hidden), beside the boss's name.
	if _coins_box:
		_coins_box.position = Vector2(40, 58) if _boss_box.visible else Vector2(64, 54)
	# Hidden behind the pause menu, where it would cross "Paused".
	var meter := Game.chain_unlocked() and Game.state in [Game.State.PLAYING, Game.State.UPGRADE]
	# With no chain going it stays faint (it sits over the far end of the room).
	# Version 213: never fainter than 0.7, so the score can be read (0.35 was too faint).
	var want := (1.0 if Game.chain > 1.01 or _broken_time > 0.0 else 0.7) if meter else 0.0
	# Version 219 (review 4 fix 19): a boss at the top of the room (the Queen's throne end)
	# stood under the chain and score. Then they go see-through so she can be read.
	if want > 0.0 and _boss_near_top():
		want = 0.4
	# Version 305 (Supercell review fix 2): in a boss fight the chain, x1.0 and SCORE stood
	# right over the boss in every boss picture. They step aside until the boss is down (the
	# chain still counts; a break still flashes CHAIN BROKEN under the boss bar).
	if Game.boss_fight_on():
		want = 0.0   # (v380: a break is told under the boss bar instead, _boss_broken)
	_chain_box.modulate.a = move_toward(_chain_box.modulate.a, want, delta * (8.0 if want > 0.0 else 3.0))
	_spine.drain = clampf(Game._combo_left / Game.chain_time(), 0.0, 1.0) if Game.chain > 1.01 else 0.0
	_chain_pop = move_toward(_chain_pop, 0.0, delta * 3.0)
	var pulse := 1.0 + _chain_pop * 0.5 + (0.05 * sin(Time.get_ticks_msec() * 0.012) if Game.chain >= Game.chain_max() else 0.0)
	# (v416: the last third of the fuse, the number beats like a heart: keep killing)
	if Game.chain > 1.01 and _spine.drain < 0.34:
		pulse += 0.09 * maxf(0.0, sin(Time.get_ticks_msec() * 0.016))
	_chain_label.scale = Vector2(pulse, pulse)
	_shown_score = move_toward(_shown_score, Game.score, maxf(40.0, absf(Game.score - _shown_score) * 8.0) * delta)
	var shown := roundi(_shown_score)
	if shown != _score_shown:   # version 147: new text only when the number changes
		_score_shown = shown
		_score_label.text = Hud.thousands(shown)
		var sf: Font = _score_label.label_settings.font if _score_label.label_settings.font else ThemeDB.fallback_font
		var tw: float = sf.get_string_size(_score_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _score_label.label_settings.font_size).x
		_chain_pill.size.x = clampf(139.0 + tw + 14.0, 190.0, CHAIN_W + 8.0)
		_spine.size.x = _chain_pill.size.x - 16.0   # (v416: the fuse spans the pill)
	if _broken_time > 0.0:
		_broken_time -= delta
		var fade := clampf(_broken_time / 0.4, 0.0, 1.0)
		var in_boss := Game.boss_fight_on() and _boss_box.visible
		_broken_label.modulate.a = 0.0 if in_boss else fade
		_boss_broken.modulate.a = fade if in_boss else 0.0
		_chain_label.modulate.a = 1.0 - _broken_label.modulate.a
	# Tips, hints and callouts belong to the action: hide them while a menu or the
	# blessing cards cover it, so they never show through ("PERFECT!" over the cards).
	var covered := 0.0 if _overlay_open() else 1.0
	_tip.self_modulate.a = covered
	_tip_tag.self_modulate.a = covered
	_hint.self_modulate.a = covered
	_hint.visible = _hint_on and not _tip.visible
	_callout.self_modulate.a = covered
	if _tip_delay > 0.0:
		_tip_delay -= delta
		_tip.visible = _tip_delay <= 0.0
		if _tip.visible:
			_pop_tip()
	elif _tip_time > 0.0:
		_tip_time -= delta
		# Version 404 (re-review of v400, fix 4): with the hero behind it, the tip card slides
		# up to just under the top lane instead of fading out across the hero.
		var vh := get_viewport().get_visible_rect().size.y
		var goal := maxf(0.0, (vh - 198.0) - (_callout_lane() + 62.0)) if _tip_over_hero() else 0.0
		_tip_see = move_toward(_tip_see, goal, delta * 2600.0)
		_tip.offset_top = -198.0 - _tip_see
		_tip.offset_bottom = -158.0 - _tip_see
		_tip.modulate.a = clampf(_tip_time / 0.4, 0.0, 1.0)
		if _tip_time <= 0.0:
			_tip.visible = false
	_update_end_count(delta)
	_update_tally(delta)
	if _end_hero_box.visible:
		_end_hero_box.queue_redraw()
	if _daily_box.visible:
		_daily_hero_box.queue_redraw()
	# Version 213 (hardest review fix #9): one word at a time over the action. A callout that
	# came while another word, the room banner or the phase card was up waits its turn.
	# (v216: only during play, and only once the banner is fully gone.)
	if _callout_time <= 0.0 and not _callout_queue.is_empty() and _banner_time <= 0.0 \
			and not _phase_showing() and Game.state == Game.State.PLAYING:
		var q: Array = _callout_queue.pop_front()
		_show_callout(q[0], q[1], q[2])
	if _callout_fight and _callout_time > 0.25 and Game.state != Game.State.PLAYING \
			and Game.state != Game.State.PAUSED:
		_callout_time = 0.25
	if _callout_time > 0.0:
		_callout_time -= delta
		_callout.modulate.a = clampf(_callout_time / 0.3, 0.0, 1.0)
		var cs := 1.0 + maxf(0.0, _callout_time - 0.8) * 3.0
		# Never let the pop grow past the screen edges (long callouts on narrow phones).
		cs = minf(cs, maxf(1.0, (get_viewport().get_visible_rect().size.x - 24.0) / maxf(_callout.size.x, 1.0)))
		_callout.pivot_offset = _callout.size / 2
		_callout.scale = Vector2(cs, cs)
	if Game.state != Game.State.PLAYING and _stick_touch != -1:
		_release_stick()
	var hero := Game.hero
	if hero:
		_shown_hp = move_toward(_shown_hp, hero.health / hero.max_health, delta * 1.5)
		_hp_fill.anchor_right = clampf(_shown_hp, 0.0, 1.0)
		var hp_text := Vector2i(ceili(hero.health), roundi(hero.max_health))
		if hp_text != _hp_shown:   # format the text only when the numbers change
			_hp_shown = hp_text
			_hp_label.text = "%d / %d" % [hp_text.x, hp_text.y]
		var low := 1.0 - clampf(hero.health / hero.max_health / 0.35, 0.0, 1.0)
		if hero.dead or not _safe.visible:
			low = 0.0
		var beat := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
		_danger.modulate.a = move_toward(_danger.modulate.a, low * beat, delta * 3.0)
		# Below about a fifth of health a quiet heartbeat keeps time with the red glow.
		var phase := fmod(Time.get_ticks_msec() * 0.008 / TAU, 1.0)
		if low > 0.4 and Game.state == Game.State.PLAYING and phase < _beat_phase:
			Sfx.play("heart", 0.35 + 0.4 * low)
		_beat_phase = phase
	var boss := Game.boss
	if boss and is_instance_valid(boss):
		var k := Game.boss_bar()
		_boss_fill.anchor_right = k
		# Version 386: the pale trail waits a moment after a hit, then slides down to the fill.
		if k < _trail_last - 0.0005:
			_trail_hold = 0.45
		elif k > _boss_trail.anchor_right:
			_boss_trail.anchor_right = k   # (healed, or a new boss)
		_trail_last = k
		_trail_hold -= delta
		if _trail_hold <= 0.0:
			_boss_trail.anchor_right = move_toward(_boss_trail.anchor_right, k, delta * 0.7)
		_boss_trail.anchor_right = maxf(_boss_trail.anchor_right, k)
		_boss_hp.text = Hud.thousands(ceili(Game.boss_hp_left()))
	if _banner_time > 0.0:
		_banner_time -= delta
		_banner.modulate.a = clampf(_banner_time / 0.4, 0.0, 1.0)
		var s := 1.0 + maxf(0.0, _banner_time - 1.6)
		# The pop-in never pushes a wide banner off the screen edges.
		s = minf(s, maxf(1.0, (get_viewport().get_visible_rect().size.x - 24.0) / maxf(_banner_w, 1.0)))
		_banner.scale = Vector2(s, s)
		_banner.pivot_offset = _banner.size / 2


## A-8: the DASH and special buttons and the boss bar sit over the arena. When the hero, an
## enemy, an enemy shot or the hero's own body goes behind one, it turns see-through so the
## fight under it stays readable. The buttons still answer taps.
## Version 143: this used to be two functions (this one and _fade_buttons_over_hero) pulling
## the same alpha in opposite directions, so a hero half under DASH kept it solid.
var _see_pts := PackedVector2Array()


## True when the boss's body is on screen under the chain meter and score (top centre).
func _boss_near_top() -> bool:
	var cam := get_viewport().get_camera_3d()
	var b = Game.boss
	if cam == null or b == null or not is_instance_valid(b) or b.dead:
		return false
	var box := _chain_box.get_global_rect().grow(30.0)
	for h in [0.0, 1.2, 2.4]:
		var at: Vector3 = b.global_position + Vector3.UP * h
		if not cam.is_position_behind(at) and box.has_point(cam.unproject_position(at)):
			return true
	return false


func _see_through(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var fighting := Game.state == Game.State.PLAYING and cam != null
	var hero_box := Rect2()
	var hero_ok := fighting and Game.hero != null and is_instance_valid(Game.hero)
	if hero_ok:
		var feet := cam.unproject_position(Game.hero.global_position)
		var head := cam.unproject_position(Game.hero.global_position + Vector3.UP * 1.6)
		hero_box = Rect2(head, Vector2.ZERO).expand(feet).grow(22.0)
	# Version 166 (Tweaks report #9): every skeleton, enemy shot and warning is put on the
	# screen once a frame, then each button checks that list (it was once per button).
	_see_pts.clear()
	if fighting:
		for a in Actor.all:
			if is_instance_valid(a) and not a.dead and not cam.is_position_behind(a.center()):
				_see_pts.append(cam.unproject_position(a.center()))
		for p in Projectile.danger:
			if is_instance_valid(p) and not cam.is_position_behind(p.global_position):
				_see_pts.append(cam.unproject_position(p.global_position))
		for t in Telegraph.active:
			if is_instance_valid(t) and t.elapsed < t.duration and not cam.is_position_behind(t.global_position):
				_see_pts.append(cam.unproject_position(t.global_position))
	for c: Control in [_special, _dash_button, race_surge, _boss_box]:
		if c == null:
			continue
		var want := 1.0
		# Version 158: while the blessing cards or the doors are up, DASH and the special
		# step back out of the way (they showed through the dimmed room under the cards).
		if c != _boss_box and (_cards_box.visible or _doors_box.visible):
			want = 0.0
		elif fighting and c.is_visible_in_tree():
			var r := c.get_global_rect().grow(14.0)
			if hero_ok and c != _boss_box and r.intersects(hero_box):
				want = 0.3
			if want > 0.5:
				for q in _see_pts:
					if r.has_point(q):
						want = 0.35
						break
		# Version 213: only the hero under a button lets its touches through (a skeleton or a
		# shot passing over it fades it too, but DASH must still work then).
		c.set_meta("hero_under", want == 0.3)
		if c == _boss_box:
			want = maxf(want, 0.88)   # (v404: the boss's bar stays solid; it washed out under shots)
		c.modulate.a = move_toward(c.modulate.a, want, delta * (6.0 if want < c.modulate.a else 3.0))


# ---------------------------------------------------------------- API used by game.gd

func set_room(index: int, total: int, boss: bool, floor_num := 1) -> void:
	_room_label.text = "Boss" if boss else "Room %d / %d" % [index, total]
	_room_text = "Boss room" if boss else _room_label.text
	var heroic := Game.curses.has("heroic")
	_heroic_crest.visible = heroic
	_room_label.label_settings.font_color = Color(1.0, 0.86, 0.5) if heroic else Color(1, 0.95, 0.85)
	if floor_num > 1:
		_room_label.text = "F%d · %s" % [floor_num, _room_label.text]
	_boss_box.visible = boss


func set_boss_name(n: String) -> void:
	_boss_name.text = n
	if is_instance_valid(Game.boss):
		_boss_badge.col = Game.boss.boss_color()
		_boss_badge.queue_redraw()
	_boss_trail.anchor_right = 1.0
	_trail_last = 1.0
	_boss_name.label_settings.font_color = Color(1, 0.8, 0.6)


func hide_boss() -> void:
	_boss_box.visible = false
	_hide_phase()


## Version 123: the Phase 2 banner is drawn above the pause menu and the end screen, so it
## goes at once when either opens (it stayed up to 2 s over YOU DIED or PAUSED).
func _hide_phase() -> void:
	if _phase_tw:
		_phase_tw.kill()
	_phase_box.visible = false


## "Wave 2 / 3" under the room name; hidden in one-wave rooms.
func set_wave(wave: int, total: int) -> void:
	_wave_label.visible = false
	_wave_label.text = "Wave %d / %d" % [wave, total]
	_wave_pips.visible = total > 1
	if wave != _wave_now and wave > 1 and _wave_pips.visible:
		var tw := _wave_pips.create_tween()
		_wave_pips.pivot_offset = Vector2(_wave_pips.size.x, 10)
		_wave_pips.scale = Vector2(1.25, 1.25)
		tw.tween_property(_wave_pips, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	_wave_now = wave
	_wave_total = total
	_wave_pips.queue_redraw()


## One pip per wave, right-aligned: done waves dim, this wave big and lit, later ones hollow.
func _draw_wave_pips() -> void:
	var n := _wave_total
	if n < 2:
		return
	# Version 358: closer together for long rooms, so they stay clear of the chain strip.
	# v392 (review v388 fix 4, "room dots too small"): a third bigger, further apart.
	var gap := minf(26.0, 66.0 / float(n - 1))
	var y := 11.0
	# Version 404 (re-review of v400, fix 4): the word WAVES under the pips (under "Room 1/5"
	# they read as rooms; beside them there is no room left of the score).
	var font: Font = UI_FONT if UI_FONT else ThemeDB.fallback_font
	var mid := _wave_pips.size.x - 12.0 - float(n - 1) * gap * 0.5
	var word := "WAVE %d/%d" % [mini(_wave_now, n), n]
	var tw := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var at := Vector2(minf(mid - tw * 0.5, _wave_pips.size.x - 4.0 - tw), y + 32.0)
	_wave_pips.draw_string_outline(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 6, INK)
	_wave_pips.draw_string(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.93, 0.82))
	for i in n:
		var x := _wave_pips.size.x - 12.0 - float(n - 1 - i) * gap
		var w := i + 1
		var p := Vector2(x, y)
		if w < _wave_now:
			_wave_pips.draw_circle(p, 9.0, INK)
			_wave_pips.draw_circle(p, 6.5, Color(1, 0.62, 0.45, 0.6))
		elif w == _wave_now:
			_wave_pips.draw_circle(p, 12.0, INK)
			_wave_pips.draw_circle(p, 9.2, Color(1, 0.62, 0.45))
			_wave_pips.draw_circle(p + Vector2(-2.4, -2.6), 2.9, Color(1, 0.92, 0.8))
		else:
			_wave_pips.draw_circle(p, 9.0, INK)
			_wave_pips.draw_arc(p, 5.8, 0.0, TAU, 20, Color(1, 0.62, 0.45, 0.85), 2.6, true)


## The Hourglass countdown. Below zero hides it.
func set_timer(seconds: float) -> void:
	_timer_label.visible = seconds > -0.5 and Game.curses.has("hourglass")
	if not _timer_label.visible:
		return
	if seconds <= 0.0:
		_timer_label.text = "TIME'S UP"
		_timer_label.label_settings.font_color = Color(1, 0.35, 0.3)
	else:
		_timer_label.text = "Time %d:%02d" % [int(seconds) / 60, int(seconds) % 60]
		_timer_label.label_settings.font_color = Color(1, 0.45, 0.35) if seconds < 10.0 else Color(1, 0.75, 0.5)


func clear_banner() -> void:
	_banner_time = 0.0
	_banner.modulate.a = 0.0


func banner(text: String, col := Color(1, 0.9, 0.7)) -> void:
	# A-7: the banner takes the spot, so a callout still showing there fades out now.
	_callout_time = minf(_callout_time, 0.25)
	_banner.text = text
	_banner.label_settings.font_color = col
	var fs := 48 if text.length() <= 16 else 38
	# Long banners ("Loop 2 · Floor 6: Drowned Vault") shrink until they fit the screen.
	var room := get_viewport().get_visible_rect().size.x - 40.0
	var font: Font = _banner.label_settings.font if _banner.label_settings.font else ThemeDB.fallback_font
	var outline := _banner.label_settings.outline_size
	while fs > 22 and font and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + outline > room:
		fs -= 2
	_banner.label_settings.font_size = fs
	_banner_w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + outline if font else 0.0
	_banner_time = 2.0


## Updates the spine and the big "x2.4" under it. Each step up punches the number.
func show_chain(mult: float) -> void:
	if Game.score == 0:
		_shown_score = 0.0   # a new run starts from zero instead of counting down
	var col := ChainSpine.color_for(mult)
	if mult > _spine.mult + 0.01:
		_chain_pop = 0.35 if mult < Game.chain_max() else 0.6
	_spine.set_chain(mult)
	_chain_label.text = "x%.1f" % mult
	_chain_label.label_settings.font_color = col


## The chain ran out: the spine shatters and the number it reached flashes in red.
func chain_broken(was: float) -> void:
	_spine.shatter()
	_chain_label.text = "x1.0"
	_chain_label.label_settings.font_color = ChainSpine.BONE
	if was >= 2.0:
		_broken_label.text = "CHAIN BROKEN  x%.1f" % was
		_boss_broken.text = _broken_label.text
		_broken_time = 1.3


## A short line under the chain meter, for teaching the first run. 0 seconds clears it.
## `delay` waits for the room banner to clear first, so the two don't overlap.
## Version 373 (visual review v366 fix 6, "tips are a paragraph in the middle of a fight"):
## a tip is ONE line, sized to fit the phone, with a small picture of what it is about.
## `pic`: "foe_<class>", "elite_<move>", "danger_<key>" (art/ui/tips/<pic>.png) or "hero"
## (the hero in play); "" for none.
const TIP_PIC := Vector2(68, 76)   # the picture on screen (the files are twice that)
const TIP_FONT := 23
const TIP_FONT_MIN := 18
const TIP_WIDE := 508.0

func tip(text: String, seconds := 5.0, delay := 0.0, foe := false, pic := "") -> void:
	var parts := Hud.tip_parts(text)
	var tag: String = parts[0]
	_tip.text = parts[1]
	_tip_tag.text = tag
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.78, 0.2, 0.2) if foe else Color(0.86, 0.6, 0.16)
	tsb.set_corner_radius_all(9)
	tsb.content_margin_left = 9
	tsb.content_margin_right = 9
	tsb.content_margin_top = 1
	tsb.content_margin_bottom = 1
	tsb.border_color = Color(0.06, 0.02, 0.1, 0.9)
	tsb.set_border_width_all(2)
	_tip_tag.add_theme_stylebox_override("normal", tsb)
	_tip_tag.size = Vector2.ZERO
	_tip_pic.texture = Hud.tip_picture(pic) if text != "" else null
	_tip_pic.visible = _tip_pic.texture != null
	_fit_tip()
	_tip_delay = delay if text != "" and seconds > 0.0 else 0.0
	var was := _tip.visible
	_tip.visible = text != "" and seconds > 0.0 and _tip_delay <= 0.0
	_tip.modulate.a = 1.0
	_tip_see = 0.0
	_tip_time = seconds if text != "" else 0.0
	if _tip.visible and not was:
		_pop_tip()


## A tip's name tag and its one line. "BOMBER: runs in..." or "Dark Room: lantern..." puts
## the name in the tag (a short name before the first colon of the first line); a card with
## a title line of its own ("DAILY CRYPT #12  ·  Score x1.5", then the curses) puts that
## line in the tag; anything else gets a TIP tag. Later lines join the one line.
static func tip_parts(text: String) -> Array:
	var lines := text.split("\n", false)
	if lines.is_empty():
		return ["TIP", ""]
	var tag := "TIP"
	var first: String = lines[0]
	var colon := first.find(": ")
	var name := first.substr(0, maxi(colon, 0))
	if colon > 0 and colon < 28 and not (name.contains(".") or name.contains("!") or name.contains("?")):
		tag = first.substr(0, colon).to_upper()
		lines[0] = first.substr(colon + 2)
	elif lines.size() > 1:
		tag = first
		lines.remove_at(0)
	var body := " ".join(lines)
	return [tag, body.substr(0, 1).to_upper() + body.substr(1)]


## The picture for a tip (see tip), or null: the file is small and loaded when first shown.
static func tip_picture(pic: String) -> Texture2D:
	if pic == "":
		return null
	if pic == "hero":
		pic = "hero_" + (str(Game.hero.hero_id) if Game.hero and is_instance_valid(Game.hero) else "")
	var path := "res://art/ui/tips/%s.png" % pic
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Sizes the tip card to its one line: the text shrinks (to TIP_FONT_MIN) until it fits the
## phone; only a line too long even then (a long list of curses) wraps to a second line.
func _fit_tip() -> void:
	var has_pic := _tip_pic.visible
	var left := 60.0 if has_pic else 18.0
	_tip_sb.content_margin_left = left
	# (a centred Label centres on its whole width, margins or not: beside a picture the line
	# starts at the margin instead)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if has_pic else HORIZONTAL_ALIGNMENT_CENTER
	var font := _tip.get_theme_font("font")
	var edge := float(_tip.label_settings.outline_size) * 2.0
	var wide := minf(get_viewport().get_visible_rect().size.x - 28.0, TIP_WIDE)
	var room := wide - left - 18.0
	var fs := TIP_FONT
	var w := font.get_string_size(_tip.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + edge
	while w > room and fs > TIP_FONT_MIN:
		fs -= 1
		w = font.get_string_size(_tip.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + edge
	var wrap := w > room
	if wrap:
		fs = 20
		w = room
	_tip.label_settings.font_size = fs
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	var tag_font := _tip_tag.label_settings.font if _tip_tag.label_settings.font else font
	var tag_w := tag_font.get_string_size(_tip_tag.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _tip_tag.label_settings.font_size).x + 40.0
	var card := clampf(maxf(w, tag_w) + left + 18.0, 200.0, wide)
	_tip.offset_left = -card * 0.5 + (7.0 if has_pic else 0.0)   # (the picture stands 14 out on the left)
	_tip.offset_right = card * 0.5 + (7.0 if has_pic else 0.0)
	_tip.offset_top = -198
	_tip.offset_bottom = -158
	_tip_tag.position = Vector2(left - 2.0 if has_pic else 16.0, -15)
	# The picture's ring (64 across, its middle 44 down the picture) sits on the card's
	# middle line, standing out above, below and to the left of the card.
	var card_h := font.get_height(fs) * (2.0 if wrap else 1.0) + _tip_sb.content_margin_top + _tip_sb.content_margin_bottom
	_tip_pic.position = Vector2(-16.0, card_h * 0.5 - 44.0)


## The tip card springs up into place when it appears.
func _pop_tip() -> void:
	_tip.pivot_offset = Vector2(_tip.size.x * 0.5, _tip.size.y)
	_tip.scale = Vector2(0.82, 0.82)
	var tw := _tip.create_tween()
	tw.tween_property(_tip, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A tip is showing, or waiting to show.
func tip_busy() -> bool:
	return _tip_time > 0.0 or _tip_delay > 0.0


## 12345 -> "12,345"
static func thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## A short punchy word over the action, like "PERFECT!".
## fight = true: a word about the fight itself (a cast, CHILLED, WARD). It is never shown
## outside play, and it fades the moment play stops (version 219, review 4 fix 15: the
## SHADOW VOLLEY! word leaked onto the victory screen).
func callout(text: String, col := Color(0.6, 0.95, 1.0), fight := false) -> void:
	if fight and Game.state != Game.State.PLAYING:
		return
	if Game.state == Game.State.PLAYING and (_callout_time > 0.35 or _banner_time > 0.0 or _phase_showing()):
		for q in _callout_queue:
			if q[0] == text:
				return
		if _callout_queue.size() < 2:
			_callout_queue.append([text, col, fight])
		return
	_show_callout(text, col)


var _callout_queue: Array = []

## Version 213: true while the boss's half-health card is up.
func _phase_showing() -> bool:
	return _phase_box != null and _phase_box.visible and _phase_box.modulate.a > 0.05


## True while the room banner is up (a teaching line waits for it).
func banner_busy() -> bool:
	return _banner_time > 0.0


var _callout_fight := false

func _show_callout(text: String, col: Color, fight := false) -> void:
	_callout_fight = fight
	_callout.text = text
	_callout.label_settings.font_color = col
	# Version 416 (re-review of v410, fix 6): a slim strip at the top, not a big word over the
	# fight: smaller letters on a thinner band.
	_callout.label_settings.font_size = 30 if text.length() <= 10 else 25
	var top := _callout_lane()
	_callout.offset_top = top
	_callout.offset_bottom = top + 40.0
	# The strip hugs the word (centred), never the whole width.
	var cf: Font = _callout.label_settings.font if _callout.label_settings.font else ThemeDB.fallback_font
	var vw := get_viewport().get_visible_rect().size.x
	var half := minf(vw * 0.5 - 12.0, cf.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _callout.label_settings.font_size).x * 0.5 + 30.0)
	_callout.offset_left = vw * 0.5 - half
	_callout.offset_right = -(vw * 0.5 - half)
	_callout_time = 1.1


## The callout lane (v392): under the top bar, the boss bar or the race bar, whichever is
## lowest. Nothing else of the fight's words sits there.
const CALLOUT_LANE := 106.0   # v416: under the taller chain pill

func _callout_lane() -> float:
	var y := CALLOUT_LANE
	if _boss_box.visible:
		y = _boss_box.offset_bottom + 54.0   # (v416: under the chain pill there)
	if race_bar != null and race_bar.visible:
		y = maxf(y, race_bar.position.y + race_bar.size.y + 6.0)
	return y


## Version 387 (visual review of v383, fix 8): the camera now lets a hero by the near wall
## stand lower on the screen, where the tip card sits; the card turns see-through while the
## hero is behind it. (Version 404: it slides up out of the way instead.)
var _tip_see := 0.0   # (v404: how far the card has slid up, in pixels)


func _tip_over_hero() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null or Game.hero == null or not is_instance_valid(Game.hero) or not _tip.visible:
		return false
	var head := cam.unproject_position(Game.hero.global_position + Vector3.UP * 2.0)
	var feet := cam.unproject_position(Game.hero.global_position)
	var box := _tip.get_global_rect().grow(6.0)
	box.position.y += _tip_see   # where it sits when not slid up (see _process)
	return box.position.y < feet.y + 8.0 and box.end.y > head.y \
		and absf(feet.x - box.get_center().x) < box.size.x * 0.5 + 24.0


## The hero talking in a run (version 129): one of their lines ("hello" at the start of a
## run, "win" over a beaten boss) in a speech bubble over their head. It sits under every
## other part of the HUD, so a menu or the victory card covers it, never the other way round.
var _hero_bubble: SpeechBubble

func hero_says(kind: String) -> void:
	var h := Game.hero
	if h == null or not is_instance_valid(h) or h.dead:
		return
	var def := Heroes.get_hero(h.hero_id)
	var text := Heroes.line(def, kind)
	if text == "":
		return
	if _hero_bubble == null:
		_hero_bubble = SpeechBubble.new()
		add_child(_hero_bubble)
		move_child(_hero_bubble, 0)
	_hero_bubble.say(str(def.get("name", def.title)), text, def.ring, float(def.get("voice", 1.0)), h, 2.6)


func hero_quiet() -> void:
	if _hero_bubble:
		_hero_bubble.hide_now()


## Version 404 (re-review of v400, fix 4, "quieter fight words"): what is happening to the
## hero (CHILLED, ROOTED, CAUGHT...) is a small dark tag just under their feet, where the eye
## already is, not a wide strip across the top of the fight that covered the enemy. The top
## lane is kept for the rare big moments.
var _status_box: PanelContainer
var _status_lbl: Label
var _status_time := 0.0

func status_at_hero(text: String, col := Color(0.6, 0.95, 1.0)) -> void:
	if Game.state != Game.State.PLAYING:
		return
	if Game.hero == null or not is_instance_valid(Game.hero):
		callout(text, col, true)
		return
	if _status_box == null:
		_status_box = PanelContainer.new()
		_status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.03, 0.08, 0.86)
		sb.set_corner_radius_all(14)
		sb.set_border_width_all(2)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		_status_box.add_theme_stylebox_override("panel", sb)
		_status_lbl = label("", 19, col)
		chunky(_status_lbl.label_settings)
		_status_lbl.label_settings.outline_size = 5
		_status_lbl.label_settings.outline_color = Color(0.02, 0.02, 0.06)
		_status_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		_status_box.add_child(_status_lbl)
		add_child(_status_box)
		move_child(_status_box, 0)   # under the rest of the HUD
	_status_lbl.text = text
	# Lethal ones (stuck: dash or step out now) are bigger, with a red edge and a pulse.
	var urgent := text.contains("DASH") or text.contains("OUT!")
	_status_urgent = urgent
	_status_lbl.label_settings.font_size = 23 if urgent else 19
	var sbx := _status_box.get_theme_stylebox("panel") as StyleBoxFlat
	sbx.set_border_width_all(3 if urgent else 2)
	sbx.bg_color = Color(0.16, 0.02, 0.03, 0.9) if urgent else Color(0.04, 0.03, 0.08, 0.86)
	col = Color.from_hsv(col.h, minf(col.s, 0.55), maxf(col.v, 0.97))   # (bright on the dark tag, even sand's dull colour)
	_status_lbl.label_settings.font_color = col
	sbx.border_color = Color(1.0, 0.25, 0.2, 0.95) if urgent else Color(col, 0.7)
	_status_box.reset_size()
	if _status_time <= 0.0:
		_status_box.pivot_offset = _status_box.size * 0.5
		_status_box.scale = Vector2(1.25, 1.25)
	_status_time = 1.3
	_status_box.visible = true
	_place_status(0.0)


var _status_urgent := false

func _place_status(delta: float) -> void:
	if _status_box == null or not _status_box.visible:
		return
	_status_time -= delta
	var cam := get_viewport().get_camera_3d()
	if _status_time <= 0.0 or Game.state != Game.State.PLAYING or cam == null or Game.hero == null or not is_instance_valid(Game.hero):
		_status_box.visible = false
		_status_time = 0.0
		return
	_status_box.scale = _status_box.scale.move_toward(Vector2.ONE, delta * 2.5)
	if _status_urgent and _status_box.scale.is_equal_approx(Vector2.ONE):
		_status_box.self_modulate.v = 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.012)
	_status_box.modulate.a = clampf(_status_time / 0.18, 0.0, 1.0)
	var feet := cam.unproject_position(Game.hero.global_position)
	var w := get_viewport().get_visible_rect().size.x
	var pos := feet + Vector2(-_status_box.size.x * 0.5, 22.0)
	pos.x = clampf(pos.x, 8.0, w - _status_box.size.x - 8.0)
	_status_box.position = pos


## PERFECT! just above the hero's head, where the eye already is (it used to show at the top
## of the screen, over the gold hero and the pink shots).
var _perfect_lbl: Label
var _perfect_tw: Tween

func callout_at_hero(text: String, col := Color(0.6, 0.95, 1.0), big := false) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or Game.hero == null:
		callout(text, col)
		return
	if _perfect_lbl == null:
		_perfect_lbl = label("", 40, col)
		_perfect_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		_perfect_lbl.label_settings.outline_size = 10
		_perfect_lbl.label_settings.outline_color = Color(0.02, 0.05, 0.12)
		_perfect_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_perfect_lbl)
	_perfect_lbl.text = text
	_perfect_lbl.label_settings.font_color = col
	# (v406: a special's total is twice a hit number and punches in)
	_perfect_lbl.label_settings.font_size = 62 if big else 40
	_perfect_lbl.label_settings.outline_size = 14 if big else 10
	_perfect_lbl.reset_size()
	_perfect_lbl.pivot_offset = _perfect_lbl.size * 0.5
	_place_perfect(0.0)
	_perfect_lbl.visible = true
	_perfect_lbl.modulate.a = 1.0
	_perfect_lbl.scale = Vector2(2.0, 2.0) if big else Vector2(1.5, 1.5)
	if _perfect_tw:
		_perfect_tw.kill()
	_perfect_tw = create_tween().set_ignore_time_scale(true)
	_perfect_tw.tween_property(_perfect_lbl, "scale", Vector2.ONE, 0.24 if big else 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# It rides above the hero as they dash (version 119: it was left behind at the old spot).
	_perfect_tw.parallel().tween_method(_place_perfect, 0.0, 40.0, 1.3 if big else 0.9)
	_perfect_tw.tween_property(_perfect_lbl, "modulate:a", 0.0, 0.25)
	_perfect_tw.tween_callback(func(): _perfect_lbl.visible = false)


func _place_perfect(rise: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or Game.hero == null or not is_instance_valid(Game.hero) or _perfect_lbl == null:
		return
	var at := cam.unproject_position(Game.hero.global_position + Vector3.UP * 2.3)
	_perfect_lbl.position = at - Vector2(_perfect_lbl.size.x * 0.5, _perfect_lbl.size.y + rise)
	# Version 213: kept inside the screen ("PERFE" was cut off by the edge).
	var w := get_viewport().get_visible_rect().size.x
	_perfect_lbl.position.x = clampf(_perfect_lbl.position.x, 8.0, maxf(8.0, w - _perfect_lbl.size.x - 8.0))


## A quick white (or coloured) flash over the whole screen.
## Flashes are softer with Screen shake reduced or off, for anyone who finds them too much.
func flash(col := Color(1, 1, 1), strength := 0.6) -> void:
	# Version 213: with Screen shake off, flashes are almost gone (30% stayed before).
	_flash.color = Color(col.r, col.g, col.b, strength * Game.flash_scale)   # v219: its own setting
	_flash.visible = _flash.color.a > 0.003


func show_boss_card(title: String, subtitle: String, col := Color(1, 0.35, 0.25)) -> void:
	clear_banner()   # a blessing banner from the last pick would sit on top of the card
	_boss_card_title.text = title.to_upper()
	_boss_card_sub.text = subtitle
	var bright := col.lerp(Color.WHITE, 0.18)
	_boss_card_title.label_settings.font_color = bright
	_boss_band_sb.border_color = bright
	_boss_tag_sb.bg_color = bright
	_boss_shine.color = Color(bright.r, bright.g, bright.b, 0.3)
	_boss_card.visible = true
	_boss_card.modulate.a = 1.0
	if _boss_tw:
		_boss_tw.kill()
	var w := get_viewport().get_visible_rect().size.x
	_boss_slide.position.x = -w * 1.2
	_boss_slide.modulate.a = 1.0
	_boss_bars[0].offset_top = 0.0
	_boss_bars[0].offset_bottom = 0.0
	_boss_bars[1].offset_top = 0.0
	_boss_bars[1].offset_bottom = 0.0
	_boss_card_title.scale = Vector2(1.5, 1.5)
	_boss_card_title.pivot_offset = _boss_card_title.size * 0.5
	_boss_shine.position.x = -200.0
	_boss_tw = create_tween().set_parallel(true)
	_boss_tw.set_ignore_time_scale(true)
	_boss_tw.tween_property(_boss_bars[0], "offset_bottom", BOSS_BAR, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_boss_tw.tween_property(_boss_bars[1], "offset_top", -BOSS_BAR, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_boss_tw.tween_property(_boss_slide, "position:x", 0.0, 0.32).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_boss_tw.tween_property(_boss_card_title, "scale", Vector2.ONE, 0.4).set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_boss_tw.tween_property(_boss_shine, "position:x", 1000.0, 0.55).set_delay(0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func hide_boss_card() -> void:
	if not _boss_card.visible:
		return
	if _boss_tw:
		_boss_tw.kill()
	var w := get_viewport().get_visible_rect().size.x
	_boss_tw = create_tween().set_parallel(true)
	_boss_tw.set_ignore_time_scale(true)
	_boss_tw.tween_property(_boss_slide, "position:x", w * 1.2, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_boss_tw.tween_property(_boss_bars[0], "offset_bottom", 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_boss_tw.tween_property(_boss_bars[1], "offset_top", 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_boss_tw.chain().tween_callback(func(): _boss_card.visible = false)


## Version 366: the fight bars fade away while a boss makes its entrance, and come back.
var _hud_tw: Tween

func fade_hud(on: bool) -> void:
	if _hud_tw:
		_hud_tw.kill()
	if on:
		_safe.visible = true
	_hud_tw = _safe.create_tween()
	_hud_tw.set_ignore_time_scale(true)
	_hud_tw.tween_property(_safe, "modulate:a", 1.0 if on else 0.0, 0.25)


func show_hud(v: bool) -> void:
	if _hud_tw:
		_hud_tw.kill()
	_safe.modulate.a = 1.0
	_safe.visible = v


## How far down the screen the top bar reaches (health, coins, room counter, chain and
## score), so damage numbers can keep below it.
func top_band() -> float:
	return float(_safe.get_theme_constant("margin_top")) + 225.0


## Each card shows the family icon, the title in the family colour, and the rarity
## as a tag and border colour. `rerolls` is how many free rerolls are left.
## `mastery` is a mid-run Hero Mastery level-up line to show over the cards ("" for none;
## null keeps what shows, for a reroll).
## The race clock under the blessing title ("" hides it): the race doesn't stop while you
## read the cards, and now the cards say so.
func set_cards_clock(text: String) -> void:
	for l: Label in [_cards_clock, _doors_clock]:
		if l == null:
			continue
		l.visible = text != ""
		if text != "" and l.text != text:
			l.text = text


## Version 388 (v383 review fix 10): a card's words always fit. The last two words of each
## line of text are held together (no word alone on the last line), a name with a word too
## long for the card steps down in size, and words that would run past the card's bottom
## step down a size or two (never below 14).
const CARD_WORDS_H := CARD_SIZE.y - 186.0 - 52.0


static func no_widow(text: String) -> String:
	var out := []
	for line: String in text.split("\n"):
		var i := line.rfind(" ")
		if i > 0 and line.count(" ") >= 2:
			line = line.substr(0, i) + "\u00a0" + line.substr(i + 1)
		out.append(line)
	return "\n".join(out)


func _fit_card_words(b: Control) -> void:
	var words := b.get_node("Words") as VBoxContainer
	var t := words.get_node("Title") as Label
	var d := words.get_node("Desc") as Label
	t.text = no_widow(t.text)
	d.text = no_widow(d.text)
	var w := CARD_SIZE.x - 12.0
	var font: Font = t.label_settings.font if t.label_settings.font else ThemeDB.fallback_font
	var ts := 24
	while ts > 18:
		var widest := 0.0
		for word: String in t.text.replace("\u00a0", " ").replace("\n", " ").split(" ", false):
			widest = maxf(widest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x + t.label_settings.outline_size)
		if widest <= w:
			break
		ts -= 2
	t.label_settings.font_size = ts
	var ds := 16
	d.label_settings.font_size = ds
	while ds > 14 and _words_height(t, d, ts, ds, w) > CARD_WORDS_H:
		ds -= 1
		d.label_settings.font_size = ds
	while ts > 18 and _words_height(t, d, ts, ds, w) > CARD_WORDS_H:
		ts -= 2
		t.label_settings.font_size = ts


## How tall the card's name and words are at these sizes (what the labels will wrap to).
func _words_height(t: Label, d: Label, ts: int, ds: int, w: float) -> float:
	var h := 4.0
	for pair: Array in [[t, ts], [d, ds]]:
		var l := pair[0] as Label
		var f: Font = l.label_settings.font if l.label_settings.font else ThemeDB.fallback_font
		var sz := f.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, w, int(pair[1]), -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND)
		var lines := maxf(1.0, roundf(sz.y / maxf(1.0, f.get_height(int(pair[1])))))
		h += sz.y + l.label_settings.line_spacing * (lines - 1.0)
	return h


func show_cards(choices: Array, rerolls := 0, tags := true, mastery: Variant = null, taken: Dictionary = {}) -> void:
	DamageNumber.clear_all()
	_fill_have(taken)
	if mastery != null:
		_cards_mastery.text = str(mastery)
		_cards_mastery.visible = str(mastery) != ""
		if _cards_mastery.visible:
			_cards_mastery.pivot_offset = Vector2(_cards_mastery.size.x * 0.5, 34)
			_cards_mastery.scale = Vector2(1.35, 1.35)
			var tw := _cards_mastery.create_tween()
			tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(_cards_mastery, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for tw in _cards_tweens:
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).kill()
	_cards_tweens.clear()
	_cards_picking = false
	var partners := {}   # held blessings a card would complete: their badges glow too
	for i in _cards.size():
		var b := _cards[i]
		var holder := b.get_parent() as Control
		holder.visible = i < choices.size()
		_cards_ready[i] = false
		if not holder.visible:
			continue
		var u: Dictionary = choices[i]
		var rar: Dictionary = Upgrades.RARITIES[u.rarity]
		var title := b.get_node("Words/Title") as Label
		title.text = u.title
		title.label_settings.font_color = Upgrades.color(u)
		(b.get_node("Words/Desc") as Label).text = Upgrades.card_text(u)
		_fit_card_words(b)
		(b.get_node("Icon") as BlessingIcon).show_for(u)
		var kind: String = Heroes.get_hero(u.hero).title.to_upper() if u.has("hero") else Upgrades.FAMILIES[u.family].name.to_upper()
		(b.get_node("Kind") as Label).text = kind
		var rl := b.get_node("Rarity") as Label
		rl.visible = tags
		rl.text = str(rar.name)
		var col: Color = rar.color if tags else Color(0.62, 0.64, 0.7)
		var bright: bool = tags and u.rarity != "common"
		var syn := Upgrades.completes(u, taken) if tags else {}
		_paint_card(b, col, bright, not syn.is_empty())
		var rs := rl.get_minimum_size()
		rl.size = rs
		rl.position = Vector2((CARD_SIZE.x - rs.x) * 0.5, CARD_SIZE.y - 22 - rs.y)
		var combo := b.get_node("Combo") as Label
		combo.visible = not syn.is_empty()
		if combo.visible:
			# hung over the card's top edge, above the band; two lines if one is too wide
			combo.text = "★ UNLOCKS %s" % str(syn.title).to_upper()
			if combo.get_minimum_size().x > CARD_SIZE.x + 6:
				combo.text = "★ UNLOCKS\n%s" % str(syn.title).to_upper()
			combo.size = combo.get_minimum_size()
			combo.position = Vector2((CARD_SIZE.x - combo.size.x) * 0.5, 8 - combo.size.y)
			combo.pivot_offset = combo.size * 0.5
			for part in syn.parts:
				if part != u.id:
					partners[str(part)] = true
		var shine := b.get_node("ShineClip/Shine") as Panel
		shine.visible = false
		var back := b.get_node("Back") as Control
		back.visible = true
		var face: Array[Node] = []
		for n in ["Band", "Kind", "Niche", "Icon", "Words", "Rarity", "Combo", "ShineClip", "Sheen", "Halo"]:
			face.append(b.get_node(n))
		# (what shows once it's face up: set here, as a reroll mid-deal finds them hidden)
		var face_vis: Array = [true, true, true, true, true, tags, combo.visible, true, true, true]
		var fam_col := Upgrades.color(u)
		(b.get_node("Sheen") as CanvasItem).modulate = Color(fam_col, 0.55 if bright else 0.4)
		(b.get_node("Halo") as CanvasItem).modulate = Color(fam_col, 0.7 if bright else 0.5)
		for n in face:
			(n as CanvasItem).visible = false
		var aura := b.get_node("Aura") as Panel
		aura.visible = false
		aura.modulate.a = 1.0
		# Dealt face down from below, one after another, then each flips over with a tick that
		# climbs, a shimmer for a rare one and a gold flare for a synergy.
		b.position = Vector2(0, 300 + 40 * i)
		b.rotation = deg_to_rad(-7.0 + 7.0 * i)
		b.scale = Vector2(0.92, 0.92)
		b.modulate = Color(1, 1, 1, 0)
		var tw := b.create_tween()
		_cards_tweens.append(tw)
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_interval(0.04 + 0.1 * i)
		tw.tween_property(b, "modulate:a", 1.0, 0.08)
		tw.parallel().tween_property(b, "position", Vector2.ZERO, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(b, "rotation", 0.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(b, "scale", Vector2.ONE, 0.24)
		tw.tween_interval(0.04 + 0.04 * (choices.size() - 1 - i))
		tw.tween_property(b, "scale:x", 0.0, 0.08).set_ease(Tween.EASE_IN)
		var idx := i
		tw.tween_callback(func():
			back.visible = false
			for k in face.size():
				(face[k] as CanvasItem).visible = face_vis[k]
			aura.visible = bright or combo.visible
			Sfx.play("chest_tick", 0.7, 1.0 + 0.15 * idx))
		tw.tween_property(b, "scale:x", 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func(): _cards_ready[idx] = true)
		if bright or combo.visible:
			tw.tween_callback(Sfx.play.bind("shimmer", 0.5, 1.1 + 0.1 * i))
		if combo.visible:
			combo.scale = Vector2(0.2, 0.2)
			tw.tween_property(combo, "scale", Vector2(1.15, 1.15), 0.14).set_ease(Tween.EASE_OUT)
			tw.tween_property(combo, "scale", Vector2.ONE, 0.12)
			# the synergy's gold glow breathes while the cards are up
			var pulse := aura.create_tween().set_loops()
			pulse.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			pulse.tween_property(aura, "modulate:a", 0.45, 0.6).set_trans(Tween.TRANS_SINE)
			pulse.tween_property(aura, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
			_cards_tweens.append(pulse)
		if bright:
			# A glint sweeps across rare, epic and synergy cards as they land.
			tw.tween_callback(func():
				shine.visible = true
				shine.position.x = -90.0)
			tw.tween_property(shine, "position:x", CARD_SIZE.x + 60.0, 0.4).set_ease(Tween.EASE_IN_OUT)
	_glow_partners(partners)
	_reroll_button.visible = rerolls > 0
	_reroll_button.text = "Reroll (%d left)" % rerolls
	_cards_box.visible = true
	_cards_age = 0.0


## The "YOUR BLESSINGS" row over the cards: one small badge per blessing held (a stacked one
## shows once with its count). Hidden before the first pick.
func _fill_have(taken: Dictionary) -> void:
	for c in _cards_have_row.get_children():
		_cards_have_row.remove_child(c)
		c.queue_free()
	for id in taken:
		var u := Upgrades.get_def(str(id))
		if u.is_empty():
			continue
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.custom_minimum_size = Vector2(40, 40)
		holder.set_meta("id", str(id))
		var ic := BlessingIcon.new()
		ic.show_for(u)
		ic.scale = Vector2(0.62, 0.62)
		holder.add_child(ic)
		if int(taken[id]) > 1:
			var n := label("x%d" % int(taken[id]), 13, Color.WHITE)
			n.position = Vector2(20, 22)
			n.size = Vector2(24, 18)
			holder.add_child(n)
		_cards_have_row.add_child(holder)
	_cards_have.visible = _cards_have_row.get_child_count() > 0


## A blessing card in its rarity colour: the frame and the thick lip under it, a band across
## the top, the lit niche behind the badge, the ribbon. `bright` (rare and up) gets a deeper
## tint and a glow; `synergy` (it completes one) a gold frame and a gold glow.
func _paint_card(b: Button, col: Color, bright: bool, synergy := false) -> void:
	var face := Color(0.13, 0.1, 0.19).lerp(col.darkened(0.55), 0.45 if bright else 0.3)   # (v357: every card its rarity's colour)
	var edge := GOLD if synergy else (col if bright else col.darkened(0.15))
	var normal := StyleBoxFlat.new()
	normal.bg_color = face
	normal.border_color = edge
	normal.set_border_width_all(4)
	normal.border_width_bottom = 10   # the card's thick lip
	normal.set_corner_radius_all(18)
	normal.shadow_color = Color(0, 0, 0, 0.45)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 5)
	normal.anti_aliasing_size = 1.2
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = face.lightened(0.08)
	pressed.border_width_bottom = 5
	pressed.border_width_top = 9
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal.duplicate())
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(GOLD if synergy else col, 0.35)
	glow.set_corner_radius_all(20)
	glow.shadow_color = Color(GOLD if synergy else col, 0.75 if synergy else 0.5)
	glow.shadow_size = 26 if synergy else 16
	(b.get_node("Aura") as Panel).add_theme_stylebox_override("panel", glow)
	var band := StyleBoxFlat.new()
	band.bg_color = col if bright else col.darkened(0.25)
	band.corner_radius_top_left = 14
	band.corner_radius_top_right = 14
	(b.get_node("Band") as Panel).add_theme_stylebox_override("panel", band)
	var niche := StyleBoxFlat.new()
	niche.bg_color = Color(col.lightened(0.2), 0.16 if bright else 0.1)
	niche.set_corner_radius_all(56)
	niche.border_color = Color(col, 0.35)
	niche.set_border_width_all(2)
	(b.get_node("Niche") as Panel).add_theme_stylebox_override("panel", niche)
	var r := b.get_node("Rarity") as Label
	(r.get_theme_stylebox("normal") as StyleBoxFlat).bg_color = col


static var _sheen_tex: GradientTexture2D
static var _halo_tex: GradientTexture2D

static func _card_sheen_tex() -> GradientTexture2D:
	if _sheen_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.5))
		g.set_color(1, Color(1, 1, 1, 0.0))
		_sheen_tex = GradientTexture2D.new()
		_sheen_tex.gradient = g
		_sheen_tex.fill_from = Vector2(0, 0)
		_sheen_tex.fill_to = Vector2(0, 1)
		_sheen_tex.width = 4
		_sheen_tex.height = 64
	return _sheen_tex


static func _card_halo_tex() -> GradientTexture2D:
	if _halo_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.6))
		g.set_color(1, Color(1, 1, 1, 0.0))
		_halo_tex = GradientTexture2D.new()
		_halo_tex.gradient = g
		_halo_tex.fill = GradientTexture2D.FILL_RADIAL
		_halo_tex.fill_from = Vector2(0.5, 0.5)
		_halo_tex.fill_to = Vector2(1.0, 0.5)
		_halo_tex.width = 64
		_halo_tex.height = 64
	return _halo_tex


## The held blessings a card on offer would complete glow gold in YOUR BLESSINGS, so the
## pair reads at a glance.
func _glow_partners(partners: Dictionary) -> void:
	for h in _cards_have_row.get_children():
		if not partners.has(str(h.get_meta("id", ""))):
			continue
		var ring := Panel.new()
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(GOLD, 0.0)
		sb.border_color = GOLD
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(20)
		sb.shadow_color = Color(GOLD, 0.6)
		sb.shadow_size = 8
		ring.add_theme_stylebox_override("panel", sb)
		ring.position = Vector2(-1, -1)
		ring.size = Vector2(42, 42)
		h.add_child(ring)
		h.move_child(ring, 0)
		var pulse := ring.create_tween().set_loops()
		pulse.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		pulse.tween_property(ring, "modulate:a", 0.35, 0.6).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(ring, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)


## A little gold tag for the top right corner of a title button.
func _badge_pill(text: String) -> Label:
	var l := label(text, 13, Color(0.12, 0.08, 0.02))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.label_settings.outline_size = 0
	var pill := StyleBoxFlat.new()
	pill.bg_color = GOLD
	pill.set_corner_radius_all(9)
	pill.content_margin_left = 8
	pill.content_margin_right = 8
	l.add_theme_stylebox_override("normal", pill)
	l.anchor_left = 1.0
	l.anchor_right = 1.0
	l.offset_left = -104
	l.offset_right = 4
	l.offset_top = -10
	l.offset_bottom = 10
	# Version 226: a long tag ("12 NEW LOOKS") grows to the left, over its own button; it
	# grew to the right before and ran onto the next button.
	l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	return l


## Version 279: the Early Access Deal's tag on a CRYPT PASS button: red with gold letters
## ("40% OFF · 13 DAYS LEFT"), filled in by _fill_deal_pill.
func _deal_pill() -> Label:
	var l := _badge_pill("")
	l.label_settings.font_color = Color(1.0, 0.92, 0.55)
	l.label_settings.font_size = 16
	var pill := (l.get_theme_stylebox("normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
	pill.bg_color = Color(0.7, 0.08, 0.1)
	pill.border_color = GOLD
	pill.set_border_width_all(2)
	l.add_theme_stylebox_override("normal", pill)
	l.offset_left = -170
	l.offset_top = -16
	l.offset_bottom = 12
	l.visible = false
	return l


func _fill_deal_pill(l: Label) -> void:
	var d := Store.deal_now()
	l.visible = not d.is_empty()
	if d.is_empty():
		# Version 280: without a deal, the title's tag points at the Free Dive while it's there.
		if l == _title_pass_badge and Game.dive_ready():
			l.text = "TRY FLOOR 6 FREE"
			l.visible = true
		return
	var end := int(d.get("end_ms", 0))
	var left := ""
	if end > 0:
		var days := int((float(end) - Time.get_unix_time_from_system() * 1000.0) / 86400000.0)
		left = "  ·  ENDS TODAY" if days < 1 else ("  ·  1 DAY LEFT" if days == 1 else "  ·  %d DAYS LEFT" % days)
	l.text = "%d%% OFF%s" % [int(d.pct), left]


## Version 398 (visual review of 388, fix 10): the title wore six or seven tags at once
## ("77 DROPS", "TRY FLOOR 6 FREE", "+50% COINS", "139 NEW LOOKS", "NEW LOOKS", "HEROIC!"),
## so none of them read as the thing to do. Every tag says whether it has news (_tb), and
## only the two that matter most are shown (_trim_title_badges).
func _tb(l: Label, on: bool) -> void:
	l.set_meta("want", on)
	l.visible = on


const TITLE_TAGS := 2
func _trim_title_badges() -> void:
	if _title_play_badge == null or _title_modes_badge == null or _rewards_badge == null \
			or _title_armory_badge == null or _title_heroes_badge == null or _title_pass_badge == null:
		return
	var deal := not Store.deal_now().is_empty()
	var up := _title_armory_badge.text == "UPGRADE"
	var heroic := _title_play_badge.text == "HEROIC"
	# Most important first: Heroic is switched on, a deal that ends, things to collect,
	# coins that can buy an upgrade, today's coin bonus, then the rest.
	var order: Array = []
	if heroic:
		order.append(_title_play_badge)
	if deal:
		order.append(_title_pass_badge)
	order.append(_rewards_badge)
	# (Version 400: the one-time free floor-6 try outranks the daily coin tag.)
	if not deal:
		order.append(_title_pass_badge)
	if up:
		order.append(_title_armory_badge)
	if not heroic:
		order.append(_title_play_badge)
	order.append(_title_modes_badge)
	order.append(_title_heroes_badge)
	if not up:
		order.append(_title_armory_badge)
	var shown := 0
	for l: Label in order:
		var on: bool = bool(l.get_meta("want", false)) and shown < TITLE_TAGS
		l.visible = on
		if on:
			shown += 1


## The title's NEW LOOKS tag: shown while any hero has looks the Style screen hasn't shown.
func refresh_looks_badge() -> void:
	var cfg := Game._load_save()
	if HeroStyle.migrate_seen(cfg):
		Game.write_save(cfg)
	var n := HeroStyle.new_count_all(cfg)
	for pill: Label in [_title_heroes_badge, _end_heroes_badge]:
		pill.text = "%d NEW LOOKS" % n if n > 1 else "NEW LOOK"
	_tb(_title_heroes_badge, n > 0)
	_end_heroes_badge.visible = n > 0
	refresh_armory_badge()


## Version 150 (coins review, fix 1): a tester kept about 900 coins unspent while falling on
## floor 1 again and again. The ARMORY buttons wear a gold UPGRADE tag whenever something in
## the Armory or the Vault is affordable.
func refresh_armory_badge() -> void:
	var up := Game.armory_ready()
	# Version 152: with nothing to upgrade, the day's new Bazaar looks get the pill instead.
	var cfg := Game._load_save()
	var fresh := not up and Game.f1_clears(cfg) >= Game.NEWCOMER_CLEARS and Bazaar.unseen(cfg)
	for pill: Label in [_title_armory_badge, _end_armory_badge]:
		if pill:
			pill.visible = up or fresh
			pill.text = "UPGRADE" if up else "NEW LOOKS"
	if _title_armory_badge:
		_tb(_title_armory_badge, up or fresh)
	_trim_title_badges()
	if _bazaar_tab_badge:
		_bazaar_tab_badge.visible = Bazaar.unseen(cfg)


var _rewards_box: ColorRect
var _rewards_badge: Label
var _title_rewards_row: Control
var _rw_road: Button
var _rw_drops: Button
var _rw_feats: Button
var _rw_drops_sub: Label
var _rw_feats_sub: Label
var _rw_road_sub: Label


func _build_rewards() -> void:
	_rewards_box = overlay(Color(0.03, 0.02, 0.05, 1.0), "trophy")
	add_child(_rewards_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 30
	col.offset_right = -30
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	_rewards_box.add_child(col)
	col.add_child(label("REWARDS", 46, GOLD))
	col.add_child(label("Everything you've earned, all free.", 19, Color(0.8, 0.78, 0.85)))
	# Version 408 (re-review of v400, fix 8: "the hub is five stacked buttons"): four picture
	# tiles, two by two, each showing the prize it leads to: the Today Chest's coins, the next
	# Bone Road prize, a Bone Drop, the next Feat's look. Records and leaderboards stay rows.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	col.add_child(grid)
	_rw_today = _reward_tile(grid, "today", "TODAY'S GOALS", Color(0.05, 0.24, 0.11, 0.97), Color(0.5, 1.0, 0.65))
	_rw_today.pressed.connect(func(): show_today(true))
	_rw_road = _reward_tile(grid, "road", "BONE ROAD", Color(0.36, 0.22, 0.04, 0.97), GOLD)
	_rw_road.pressed.connect(func(): road_pressed.emit())
	_rw_drops = _reward_tile(grid, "drops", "BONE DROPS", Color(0.24, 0.1, 0.3, 0.97), Color(0.9, 0.7, 1.0))
	_rw_drops.pressed.connect(func(): drops_pressed.emit())
	_rw_feats = _reward_tile(grid, "feats", "FEATS", Color(0.04, 0.17, 0.24, 0.97), Color(0.5, 0.95, 1.0))
	_rw_feats.pressed.connect(func(): feats_pressed.emit())
	_rw_today_sub = _rw_tiles.today.s
	_rw_road_sub = _rw_tiles.road.s
	_rw_drops_sub = _rw_tiles.drops.s
	_rw_feats_sub = _rw_tiles.feats.s
	_tile_pic("today", LookShots.prize_rect("coin", 112))
	_tile_pic("drops", LookShots.prize_rect("drop", 124))
	var rec := button("RECORDS", 24)
	rec.pressed.connect(func(): records_pressed.emit())
	col.add_child(_reward_row(rec, "Best runs, bosses beaten and totals"))
	# Version 137: the leaderboards (only once Google Play Games is set up on this phone).
	var lb := button("LEADERBOARDS", 24, Color(0.05, 0.2, 0.1, 0.97), Color(0.5, 1.0, 0.65))
	lb.pressed.connect(func():
		Sfx.play("click")
		show_leaders("best"))
	_rw_leaders = _reward_row(lb, "Today's Daily Crypt and this week's best runs")
	_rw_leaders.visible = false
	col.add_child(_rw_leaders)
	# The same blue BACK as the Feats, Mastery and Armory screens (version 119: it was grey).
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	var close := button("BACK", 26)
	close.pressed.connect(func(): show_rewards(false))
	_frame(_rewards_box, col, close)
	_rewards_box.visible = false


## Version 122: one screen frame for the menus. The title sits at the top (44 px gold
## capitals), the list starts under it, and BACK is always the same 180 x 72 button,
## 24 px from the bottom-left corner (it used to be in four different places).
const FRAME_TOP := 40.0
const FRAME_BOTTOM := 112.0

var _framed: Array = []   # [col, back] of each framed screen, moved clear of a notch

func _frame(box: Control, col: VBoxContainer, back: Button) -> void:
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.offset_top = FRAME_TOP
	col.offset_bottom = -FRAME_BOTTOM
	_framed.append([col, back])
	var title := col.get_child(0) as Label
	if title:
		title.text = title.text.to_upper()
		title.label_settings.font_size = 44
	box.add_child(back_corner(back))


## `back` in the bottom-left corner of a full-screen box.
## Version 227 (the "look harder" sweep): every scrolling list sits in the same dark window
## as the Armory, so the list has a clear edge and BACK never seems to cut a card in half.
## The window fades at an edge only while there is more to see past it. Returns the frame
## to add in place of the scroll; the scroll's own content is added to it as before.
static func scroll_window(scroll: ScrollContainer, well := SHOP_WELL) -> Control:
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := Panel.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = well
	sb.border_color = Color(0.24, 0.18, 0.26)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	bg.add_theme_stylebox_override("panel", sb)
	frame.add_child(full(bg))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_FILL
	full(scroll)
	scroll.offset_left = 8
	scroll.offset_top = 8
	scroll.offset_right = -8
	scroll.offset_bottom = -8
	frame.add_child(scroll)
	var fades: Array[Control] = []
	for top: bool in [true, false]:
		var g := Gradient.new()
		g.set_color(0, Color(well, 1.0) if top else Color(well, 0.0))
		g.set_color(1, Color(well, 0.0) if top else Color(well, 1.0))
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
		fade.offset_left = 4
		fade.offset_right = -4
		fade.offset_top = 4.0 if top else -40.0
		fade.offset_bottom = 40.0 if top else -4.0
		fade.visible = false
		frame.add_child(fade)
		fades.append(fade)
	var bar := scroll.get_v_scroll_bar()
	var show_fades := func() -> void:
		fades[0].visible = bar.value > 2.0
		fades[1].visible = bar.value + bar.page < bar.max_value - 2.0
	bar.value_changed.connect(func(_v: float): show_fades.call())
	bar.changed.connect(show_fades)
	return frame


static func back_corner(back: Button) -> Button:
	back.custom_minimum_size = Vector2(180, 72)
	back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back.offset_left = 24
	back.offset_right = 204
	back.offset_top = -96
	back.offset_bottom = -24
	return back


## Version 408: one REWARDS tile: a picture of its prize over a word and a status line.
var _rw_tiles := {}

func _reward_tile(grid: GridContainer, key: String, title: String, bg: Color, fg: Color) -> Button:
	var b := button("", 22, bg, Color(fg, 0.75))
	b.custom_minimum_size = Vector2(232, 262)
	grid.add_child(b)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_BEGIN   # (every tile's name on the same line)
	v.add_theme_constant_override("separation", 2)
	full(v)
	v.offset_left = 8
	v.offset_right = -8
	v.offset_top = 6
	v.offset_bottom = -8
	b.add_child(v)
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(0, 128)
	v.add_child(holder)
	var t := label(title, 24, fg)
	chunky(t.label_settings)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(t)
	var sub := label("", 16, Color(0.9, 0.88, 0.94))
	sub.custom_minimum_size = Vector2(200, 0)
	v.add_child(sub)
	_rw_tiles[key] = {"b": b, "t": t, "s": sub, "pic": holder}
	if key == "drops":
		# Drops waiting: an orange OPEN button on the tile, so it reads as the thing to tap.
		var go := label("OPEN", 20, Color.WHITE)
		chunky(go.label_settings)
		go.autowrap_mode = TextServer.AUTOWRAP_OFF
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.98, 0.55, 0.12)
		sb.border_color = Color(1.0, 0.85, 0.4)
		sb.set_border_width_all(2)
		sb.border_width_bottom = 5
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 2
		sb.content_margin_bottom = 4
		go.add_theme_stylebox_override("normal", sb)
		go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		go.visible = false
		v.add_child(go)
		_rw_tiles[key]["go"] = go
	return b


## The tile's picture (replacing the one before).
func _tile_pic(key: String, pic: Control) -> void:
	var holder: Control = _rw_tiles[key].pic
	for c in holder.get_children():
		c.queue_free()
	holder.add_child(pic)


## Version 363: a prize's picture over a REWARDS button's left end, sticking out of it.
func _reward_pic(b: Control, kind: String) -> void:
	var pic := LookShots.prize_rect(kind, 84)
	pic.position = Vector2(-34, -6)
	pic.size = Vector2(84, 84)
	b.add_child(pic)


## One REWARDS row: the 420 x 78 button and a small status line under it.
func _reward_row(b: Control, sub: Variant) -> Control:
	b.custom_minimum_size = Vector2(420, 78)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	v.add_child(b)
	var l := label(str(sub) if sub != null else "", 17, Color(0.78, 0.75, 0.84))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(l)
	return v


func show_rewards(v: bool) -> void:
	if v:
		Sfx.play("click")
		refresh_rewards()
	_rewards_box.visible = v
	_rw_leaders.visible = Leaders.available()


func rewards_visible() -> bool:
	return _rewards_box.visible


## The REWARDS screen's rows and the title button's badge ("CLAIM", "2 DROPS", "NEW").
func refresh_rewards() -> void:
	var cfg := Game._load_save()
	var ni := BoneRoad.next_index(cfg)
	# (v408: the road's tile shows the prize at its next step)
	var road_kind := str(BoneRoad.STEPS[ni].kind) if ni < BoneRoad.STEPS.size() else "coins"
	if str(_rw_tiles.road.get("kind", "")) != road_kind:
		_rw_tiles.road.kind = road_kind
		_tile_pic("road", LookShots.prize_rect(road_kind, 120))
	_rw_tiles.road.t.text = "CLAIM!" if BoneRoad.ready_count(cfg) > 0 else "BONE ROAD"
	var n := Drops.waiting(cfg)
	_rw_tiles.drops.t.text = "BONE DROPS"
	_rw_tiles.drops.go.text = "OPEN %d" % n
	_rw_tiles.drops.go.visible = n > 0
	_rw_drops.disabled = n <= 0
	var fnew := bool(cfg.get_value(Feats.SECTION, "new", false))
	_rw_tiles.feats.t.text = "FEATS %d/%d" % [Feats.count(cfg), Feats.LIST.size()]
	# (the Feats tile shows the look the next Feat still to do wins, on the chosen hero)
	var next_feat := {}
	for f: Dictionary in Feats.LIST:
		if not Feats.done(cfg, str(f.id)):
			next_feat = f
			break
	var fkey := str(next_feat.get("look", [])) + Heroes.selected(cfg)
	if str(_rw_tiles.feats.get("key", "")) != fkey:
		_rw_tiles.feats.key = fkey
		var fp := TextureRect.new()
		fp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fp.material = HeroStage._see_through()
		# (the look picture has room round the hero: drawn bigger than its box, so the hero
		# stands as big as the other tiles' prizes)
		var fbox := Control.new()
		fbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fbox.custom_minimum_size = Vector2(128, 128)
		fp.position = Vector2(-22, -16)
		fp.size = Vector2(172, 172)
		fbox.add_child(fp)
		_tile_pic("feats", fbox)
		if not next_feat.is_empty():
			var lk: Array = next_feat.look
			LookShots.want(Heroes.selected(cfg), str(lk[0]), str(lk[1]), func(t: Texture2D) -> void:
				if is_instance_valid(fp):
					fp.texture = t)
		else:
			_tile_pic("feats", LookShots.prize_rect("coins", 120))
	var ready := BoneRoad.ready_count(cfg)
	if ready > 0:
		_rw_road_sub.text = "%d prize%s ready" % [ready, "" if ready == 1 else "s"]
	elif ni < BoneRoad.STEPS.size():
		_rw_road_sub.text = "%s / %s bones" % [thousands(BoneRoad.bones(cfg)), thousands(int(BoneRoad.STEPS[ni].at))]
	else:
		_rw_road_sub.text = "All claimed"
	var pity := Drops.pity_text(cfg)
	_rw_drops_sub.text = (pity if pity != "" else "%d waiting" % n) if n > 0 else "Win runs to earn more"
	_rw_feats_sub.text = ("NEW look won!" if fnew else (str(next_feat.get("name", "")) + " wins this" if not next_feat.is_empty() else "All done"))
	var tdone := Today.done_count(cfg)
	var chest := Today.chest_ready(cfg)
	_rw_tiles.today.t.text = "OPEN CHEST!" if chest else "TODAY %d/%d" % [tdone, Today.COUNT]
	_rw_today_sub.text = ("%d coins and a Bone Drop" % Today.CHEST_COINS) if chest else \
		("New goals in %s" % _clock_text(Curses.seconds_left()) if Today.chest_open(cfg) else \
		"+%d coins each goal" % Today.GOAL_COINS)
	var badge := ""
	if chest:
		badge = "CHEST!"
	elif BoneRoad.ready_count(cfg) > 0:
		badge = "CLAIM"
	elif n > 0:
		badge = "%d DROP%s" % [n, "" if n == 1 else "S"]
	elif fnew:
		badge = "NEW"
	elif tdone < Today.COUNT and not Game.first_run_pending():
		badge = "TODAY %d/%d" % [tdone, Today.COUNT]   # version 311: a reason to look in each day
	_rewards_badge.text = badge
	_tb(_rewards_badge, badge != "")
	_trim_title_badges()


func show_title(v: bool, best := "", coins := 0) -> void:
	if v:
		_callout_queue.clear()   # v216: old words never show over the next screen
	_title_box.visible = v
	var locked := Game.first_run_pending()
	var has_pass := Store.owned()
	# Version 166 (Tweaks report #10): the save is read once here, not five times.
	var tcfg := Game._load_save()
	# Version 170 (teaching review, change 4): one thing opens at a time after the tutorial.
	var stage := Game.unlock_stage(tcfg)
	if v:
		print("[title] open stage %d, note '%s'" % [stage, Game.unlock_note(tcfg)])
	_title_shop_row.visible = stage >= 1
	# Version 218 (review 4): the Pass shows from the second run (it hid until the fourth),
	# and a Pass owner always reaches the Daily Crypt and Curses they bought (MODES).
	_title_pass_row.visible = stage >= 2 and not has_pass
	_fill_deal_pill(_title_pass_badge)
	_tb(_title_pass_badge, _title_pass_badge.visible)
	_title_modes_row.visible = stage >= 3 or has_pass
	_title_records.visible = stage >= 3
	_place_title_buttons()
	_title_road.visible = stage >= 2
	if v:
		var cfg := tcfg
		set_drops(0 if locked else Drops.waiting(cfg))
		refresh_rewards()
		var ni := BoneRoad.next_index(cfg)
		_title_road.set_road(BoneRoad.bones(cfg), int(BoneRoad.STEPS[ni].at) if ni < BoneRoad.STEPS.size() else 0,
				BoneRoad.progress(cfg), BoneRoad.ready_count(cfg))
	var heroic_new := Curses.unlocked("heroic", tcfg) and not bool(tcfg.get_value(Curses.SAVE_SECTION, "heroic_seen", false))
	var race_new := Race.unlocked(tcfg) and Race.stat(tcfg, "races") == 0
	_title_modes_badge.text = "HEROIC!" if heroic_new else ("NEW: RACE" if race_new else "DAILY READY")
	_tb(_title_modes_badge, heroic_new or race_new or not Curses.official_used(tcfg))
	refresh_looks_badge()
	_title_lock.visible = locked
	if not v:
		show_modes(false)
		show_records(false)
		_rewards_box.visible = false
		_road.visible = false
		_event.visible = false
		_splash.visible = false
		if not _end_box.visible:
			_drops.visible = false
	_title_free.visible = not has_pass and stage >= 4   # not before the Pass row shows (version 170)
	refresh_event_banner()
	if _title_event.visible:
		_title_free.visible = false   # (the banner takes its line; the Pass screen still says it)
	_title_best.text = best
	_title_coins.text = Hud.thousands(coins)
	var where := Game.continue_text()
	_title_continue.visible = where != "" and not locked
	# On short screens a saved run's CONTINUE button leaves room for one gold line only.
	var goal := Game.title_goal() if v else ""
	# Version 342: today's first-run bonus is a tag on PLAY, not a line over the hero.
	var heroic := v and not locked and Curses.chosen(tcfg, has_pass).has("heroic")
	var day_tag := v and not locked and not heroic and Game.day_bonus_ready()
	if day_tag:
		var keep := []
		for line in goal.split("\n"):
			if not line.begins_with("Today's first run"):
				keep.append(line)
		goal = "\n".join(keep)
	var view := get_viewport().get_visible_rect().size
	if _title_continue.visible and view.y < view.x * 1.9:
		goal = goal.get_slice("\n", 0).trim_suffix(",")
	_title_goal.text = goal
	_title_goal.visible = goal != ""
	# Short screens: the how-to line makes room for the Bone Road row, so the hero shows.
	var tight := view.y < view.x * 1.9 and _title_rewards_row.visible
	_title_hint.visible = locked and not tight   # the lobby keeps words few once the tutorial is done
	# Version 342: the records line is in REWARDS > Records; the lobby keeps it off the hero.
	_title_best.visible = not tight and locked and best != ""
	# Version 342: with the event's strip above the logo, the gap only clears the top bar.
	_title_gap.custom_minimum_size.y = 8.0 if _title_event.visible else (14.0 if tight else 40.0)
	_continue_where.text = where
	_title_spacer.visible = not _title_continue.visible
	_title_play.text = "NEW RUN" if _title_continue.visible else "PLAY"
	# Version 309: the start-floor button under PLAY. With a saved run's CONTINUE there is no
	# room for it (the hero would be hidden), so NEW RUN names the floor instead.
	var start_line := Game.start_text() if v and not locked else ""
	var show_start := start_line != "" and not _title_continue.visible
	_title_start.text = start_line.replace("START ON FLOOR", "START: FLOOR")
	_title_start.visible = show_start
	# Version 310: QUICK PLAY from the second run, also beside a saved run's CONTINUE.
	_title_quick.visible = v and not locked and Game.quick_open(tcfg)
	_title_small_row.visible = show_start or _title_quick.visible
	if _title_small_row.visible:
		_title_spacer.visible = false
	if start_line != "" and _title_continue.visible and Game.chosen_start(tcfg) > 1:
		_title_play.text = "NEW RUN: FLOOR %d" % Game.chosen_start(tcfg)
	_title_play_badge.text = "HEROIC" if heroic else "+%d%% COINS" % roundi(Game.DAY_BONUS * 100)
	_tb(_title_play_badge, heroic or day_tag)
	_trim_title_badges()
	_title_play.add_theme_font_size_override("font_size", (26 if _title_play.text.length() > 8 else 32) if _title_continue.visible else 38)
	_title_play.remove_meta("armed")


func title_visible() -> bool:
	return _title_box.visible


## Version 309: TRY AGAIN names the floor it starts on when that isn't floor 1.
func set_retry_floor(f: int) -> void:
	if _end_retry == null:
		return
	_end_retry.text = "TRY AGAIN" if f <= 1 else "TRY AGAIN: FLOOR %d" % f
	_end_retry.add_theme_font_size_override("font_size", 32 if f <= 1 else 27)


## Version 279: true while another screen (or the splash) covers the title.
func title_covered() -> bool:
	return not _title_box.get_child(0).visible


## The free space on the title screen between the words at the top and the buttons at the
## bottom, where the lobby camera puts the hero (in the viewport's pixels).
func title_hero_space() -> Rect2:
	var top := _title_top.get_global_rect().end.y + 10.0
	var bottom := _title_bottom.get_global_rect().position.y - 4.0
	var w := get_viewport().get_visible_rect().size.x
	return Rect2(0, top, w, maxf(bottom - top, 1.0))


func set_coins(n: int) -> void:
	_coin_target = n
	_coin_label.text = Hud.thousands(n - _coins_flying)
	_title_coins.text = Hud.thousands(n)


var _coin_target := 0
var _coins_flying := 0
var _flights := 0
const MAX_FLIGHTS := 14


## A coin picked up in the room flies up to the coin counter, and the counter ticks up and
## bounces when it lands. Call before the coins are added (Game.add_coins).
func fly_coin(world_pos: Vector3, value: int) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not visible or _flights >= MAX_FLIGHTS or cam.is_position_behind(world_pos):
		return
	var from := cam.unproject_position(world_pos)
	var to: Vector2 = (_coin_label.get_parent() as Control).get_global_rect().position + Vector2(11, 14)
	var dot := Control.new()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.size = Vector2(32, 32)
	dot.pivot_offset = dot.size * 0.5
	dot.draw.connect(func(): draw_coin(dot, dot.size * 0.5, 15.0))
	add_child(dot)
	dot.position = from - dot.size * 0.5
	_flights += 1
	_coins_flying += value
	# Up and to the side first, then a swoop into the counter.
	var mid := from.lerp(to, 0.35) + Vector2(randf_range(-60.0, 60.0), -50.0)
	var tw := dot.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(func(t: float):
		var a := from.lerp(mid, t)
		var b := mid.lerp(to, t)
		dot.position = a.lerp(b, t) - dot.size * 0.5
		dot.scale = Vector2.ONE * lerpf(1.25, 0.8, t), 0.0, 1.0, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		dot.queue_free()
		_flights -= 1
		_coins_flying = maxi(0, _coins_flying - value)
		_coin_label.text = Hud.thousands(_coin_target - _coins_flying)
		_bump_coins())


func _bump_coins() -> void:
	var row := _coin_label.get_parent() as Control
	row.pivot_offset = Vector2(14, 15)
	var tw := row.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(row, "scale", Vector2(1.25, 1.25), 0.05)
	tw.tween_property(row, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_toggles(music: bool, sounds: bool) -> void:
	_music_on = music
	_sounds_on = sounds
	_music_button.text = "Music: On" if music else "Music: Off"
	_sounds_button.text = "Sounds: On" if sounds else "Sounds: Off"
	_toggle_look(_music_button, music)
	_toggle_look(_sounds_button, sounds)


## Version 159: a switch reads at a glance, blue when on and grey when off.
static func _toggle_look(b: Button, on: bool) -> void:
	if b and not (b.has_meta("toggle_on") and b.get_meta("toggle_on") == on):
		b.set_meta("toggle_on", on)
		paint(b, "blue" if on else "slate")


## Anonymous run and crash reports (see telemetry.gd). Hidden if no form is set up.
func set_reports_label(on: bool, available: bool) -> void:
	_reports_on = on
	_reports_button.text = "Send reports: On" if on else "Send reports: Off"
	_toggle_look(_reports_button, on)
	_reports_button.get_parent().visible = available


func set_graphics_label(level: int) -> void:
	_graphics_level = level
	_graphics_button.text = "Graphics: " + Game.GRAPHICS_NAMES[level]
	if _vignette:
		_vignette.visible = level >= 2


## Screen shake level: 2 full, 1 reduced, 0 off.
func set_shake_label(level: int) -> void:
	_shake_level = level
	_shake_button.text = "Shake: " + ["Off", "Reduced", "Full"][clampi(level, 0, 2)]


func set_flashes_label(level: int) -> void:
	_flashes_level = level
	_flashes_button.text = "Flashes: " + ["Off", "Reduced", "Full"][clampi(level, 0, 2)]


func set_left_hand(on: bool) -> void:
	_left_on = on
	_left_button.text = "Left hand: On" if on else "Left hand: Off"
	_toggle_look(_left_button, on)
	_place_fight_buttons()


func set_button_size(level: int) -> void:
	_size_level = level
	_size_button.text = "Buttons: " + ["Normal", "Big", "Huge"][clampi(level, 0, 2)]
	_place_fight_buttons()


func set_darkness_label(light: bool) -> void:
	_dark_light = light
	_dark_button.text = "Darkness: Light" if light else "Darkness: Full"


## DASH, the special and the Race's Surge in the bottom corner: right (or left, mirrored,
## for the left hand), at 100, 115 or 130% (version 219, review 4 fix 32).
func _place_fight_buttons() -> void:
	var k: float = [1.0, 1.15, 1.3][clampi(_size_level, 0, 2)]
	# v219 review: laid out in a row from the corner with their scaled widths (each grew from
	# its own corner before, so Huge pushed the special over DASH and DASH over the Surge).
	# [button, width, gap after it]
	var x := 24.0
	for spec: Array in [[_special, 100.0, 20.0], [_dash_button, 80.0, 10.0], [race_surge, 84.0, 0.0]]:
		var c: Control = spec[0]
		var w: float = spec[1]
		if c == null:
			x += w * k + float(spec[2])
			continue
		c.set_anchors_preset(Control.PRESET_BOTTOM_LEFT if _left_on else Control.PRESET_BOTTOM_RIGHT, true)
		var l := -x - w
		var r := -x
		c.offset_left = -r if _left_on else l
		c.offset_right = -l if _left_on else r
		# Bigger buttons grow from their corner-side edge, so they push inward, not off screen.
		c.pivot_offset = Vector2(0.0 if _left_on else w, c.offset_bottom - c.offset_top)
		c.scale = Vector2(k, k)
		x += w * k + float(spec[2])


func set_colorblind_label(on: bool) -> void:
	_colorblind_on = on
	_colorblind_button.text = "Colour-blind: On" if on else "Colour-blind: Off"
	_toggle_look(_colorblind_button, on)


func set_vibration_label(on: bool) -> void:
	_vibration_on = on
	_vibration_button.text = "Vibration: On" if on else "Vibration: Off"
	_toggle_look(_vibration_button, on)


func armory_visible() -> bool:
	return _armory_box.visible


## rows: [{id, title, text, level, max, cost}] where cost is -1 once maxed out.
func show_armory(v: bool, rows := [], coins := 0) -> void:
	var opening := v and (not _armory_box.visible or _shop_curses)
	_armory_box.visible = v
	if not v:
		refresh_armory_badge()
		return
	_shop_curses = false
	_shop_title.text = "ARMORY"
	MenuBackdrop.of(_armory_box).set_look("forge")
	# After a buy the list stays where it was; a fresh open starts at the top.
	var keep := 0 if opening else _armory_scroll.scroll_vertical
	_fill_shop(rows, coins)
	_armory_scroll.scroll_vertical = keep
	if keep > 0:
		_armory_scroll.set_deferred("scroll_vertical", keep)


## rows: [{id, name, badge, mastery, cost, unlocked, selected, trial, trying}]
func show_heroes(v: bool, rows := [], coins := 0) -> void:
	if v:
		_heroes_box.open(rows, coins)
	else:
		_heroes_box.close()


func heroes_visible() -> bool:
	return _heroes_box.visible


## rows: [{id, title, text, level, on, locked}]. `info` is the Curse Level line, `goal` the
## next hero reward.
func show_curses(v: bool, rows := [], info := "", goal := "") -> void:
	var again := v and _armory_box.visible and _shop_curses   # a curse switched on or off
	_armory_box.visible = v
	if not v:
		return
	_shop_curses = true
	_shop_title.text = "CURSES"
	MenuBackdrop.of(_armory_box).set_look("curse")   # (version 408: a cursed shrine of its own)
	_shop_sub.text = "%s\n%s" % [info, goal]
	_armory_tabs.visible = false
	_armory_purse.visible = false
	var keep := _armory_scroll.scroll_vertical if again else 0
	for c in _armory_rows.get_children():
		c.queue_free()
	for r: Dictionary in rows:
		_armory_rows.add_child(_curse_row(r))
	_armory_scroll.scroll_vertical = keep
	if keep > 0:
		_armory_scroll.set_deferred("scroll_vertical", keep)


## "Playing as the Mage  ·  Mastery 4" (in gold once they're a Master, at level 10).
func set_title_hero(hero_name: String, mastery := 0, master := false) -> void:
	_title_hero.text = hero_name.to_upper() + ("  ·  MASTERY %d" % mastery if mastery > 1 else "")
	# A Master's name in gold; on the Legend road (version 132) in that rank's colour.
	_title_hero.label_settings.font_color = (GOLD if mastery <= HeroMastery.FRAME_LEVEL else HeroMastery.frame_color(mastery)) if master else Color(0.75, 0.85, 1.0)


## Shows the rows of the open tab: Armory upgrades, the Vault's blessings or the Bazaar.
## Version 225: what you can still buy comes first (Vault by price), then what you already
## have under its own heading, so an all-bought tab reads as done at a glance.
func _fill_shop(rows: Array, coins: int) -> void:
	_shop_rows = rows
	_shop_coins = coins
	var vault := _armory_tab == "vault"
	var bazaar := _armory_tab == "bazaar"
	var legends := _armory_tab == "legends"
	_shop_title.text = "LEGEND VAULT" if legends else ("BONE BAZAAR" if bazaar else "ARMORY")
	_shop_title.label_settings.font_color = Legends.GOLD if legends else (BAZAAR_AMBER if bazaar else Color(1, 0.85, 0.55))
	_shop_sub.text = "Legendary looks. Bought once, worn by every hero." if legends else \
			(("Three new looks a day  ·  %s" % Bazaar.refresh_text()) if bazaar \
			else ("New blessings for your runs. Buy each one once." if vault else "Upgrades bought here last forever."))
	if bazaar:
		var cfg := Game._load_save()
		if Bazaar.unseen(cfg):
			Bazaar.mark_seen(cfg)
			Game.write_save(cfg)
	refresh_armory_badge()
	_armory_tabs.visible = true
	for id: String in _tab_buttons:
		paint(_tab_buttons[id], "gold" if id == _armory_tab else "slate")
	_armory_purse.visible = true
	_armory_coins.text = thousands(coins)
	for c in _armory_rows.get_children():
		c.queue_free()
	if legends:
		_fill_legends(rows, coins)
		return
	if bazaar:
		var shown := 0
		# Version 397 (visual review of 388, fix 7): the day's dearest look not yet owned is
		# the featured look: a big card with the hero wearing it, alive, above the other two.
		# (The Bazaar was three small cards and a third of an empty panel.)
		var star := {}
		for r: Dictionary in rows:
			if r.has("look") and r.has("preview") and int(r.cost) >= 0 and (star.is_empty() or int(r.cost) > int(star.cost)):
				star = r
		if not star.is_empty():
			_armory_rows.add_child(_bazaar_feature(star, coins))
			shown += 1
		for r: Dictionary in rows:
			if r.has("look") and not is_same(r, star):
				_armory_rows.add_child(_bazaar_row(r, coins))
				shown += 1
		if shown == 0:
			_armory_rows.add_child(label("Every look is yours!\nNew ones may come in later updates.", 20, Color(0.8, 0.8, 0.85)))
		else:
			_armory_rows.add_child(_shop_note("Feat looks are never sold: win them in runs."))
		return
	var spare := []
	var buy := []
	var have := []
	for r: Dictionary in rows:
		if r.has("look") or r.has("legend") or r.has("vault") != vault:
			continue
		if r.id == "buy_drop":
			spare.append(r)
		elif int(r.cost) < 0:
			have.append(r)
		else:
			buy.append(r)
	if vault:
		buy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.cost) < int(b.cost))
	var all := buy.size() + have.size()
	if not spare.is_empty():
		_armory_rows.add_child(_shop_head("SPARE COINS", "Every upgrade is maxed"))
		for r: Dictionary in spare:
			_armory_rows.add_child(_shop_card(r, coins))
	if not buy.is_empty():
		_armory_rows.add_child(_shop_head("TO BUY", "%d left" % buy.size()))
		for r: Dictionary in buy:
			_armory_rows.add_child(_shop_card(r, coins))
	if not vault and buy.is_empty() and not have.is_empty():
		# Version 408 (re-review of v400, fix 8: "a veteran's Upgrades tab is seven grey MAX
		# pills"): every upgrade maxed folds into one trophy strip, and the room it frees shows
		# what the coins can buy now: the Bazaar's look of the day and the next Legend look.
		_armory_rows.add_child(_shop_head("MAXED", "%d / %d" % [have.size(), all]))
		_armory_rows.add_child(_trophy_strip(have))
		var star := {}
		var legend := {}
		for r: Dictionary in rows:
			if r.has("look") and r.has("preview") and int(r.cost) >= 0 and (star.is_empty() or int(r.cost) > int(star.cost)):
				star = r
			if r.has("legend") and int(r.cost) >= 0 and r.get("ready", false) and (legend.is_empty() or int(r.cost) < int(legend.cost)):
				legend = r
		if not star.is_empty() or not legend.is_empty():
			_armory_rows.add_child(_shop_head("SPEND YOUR COINS"))
		if not star.is_empty():
			_armory_rows.add_child(_bazaar_feature(star, coins))
		if not legend.is_empty():
			_armory_rows.add_child(_legend_row(legend, coins))
		return
	if not have.is_empty():
		_armory_rows.add_child(_shop_head("IN YOUR RUNS" if vault else "MAXED", "%d / %d" % [have.size(), all]))
		if vault and buy.is_empty():
			_armory_rows.add_child(_shop_note("All %d are yours. Each one can turn up in your runs." % have.size()))
		for r: Dictionary in have:
			_armory_rows.add_child(_shop_card(r, coins))


## Version 408: every maxed upgrade as a small gold-edged trophy, side by side.
func _trophy_strip(have: Array) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.11, 0.05, 0.96)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 10
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	panel.add_child(row)
	for r: Dictionary in have:
		var pic: Array = ARMORY_ICONS.get(str(r.id), ["", GOLD])
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		var icon := BlessingIcon.new()
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.show_icon(str(pic[0]), "bone", pic[1])
		icon.zoom = 0.86
		v.add_child(icon)
		var m := label("MAX", 14, GOLD)
		v.add_child(m)
		row.add_child(v)
	return panel


## Version 312: the Legend Vault. What is yours first (tap one to wear it or take it off),
## then the looks to buy from the cheapest up, then those still to come.
func _fill_legends(rows: Array, coins: int) -> void:
	var have := []
	var buy := []
	var soon := []
	for r: Dictionary in rows:
		if not r.has("legend"):
			continue
		if int(r.cost) < 0:
			have.append(r)
		elif r.ready:
			buy.append(r)
		else:
			soon.append(r)
	if not have.is_empty():
		_armory_rows.add_child(_shop_head("YOURS", "%d / %d" % [have.size(), Legends.LIST.size()]))
		for r: Dictionary in have:
			_armory_rows.add_child(_legend_row(r, coins))
	if not buy.is_empty():
		_armory_rows.add_child(_shop_head("TO BUY", "%d" % buy.size()))
		for r: Dictionary in buy:
			_armory_rows.add_child(_legend_row(r, coins))
	if not soon.is_empty():
		_armory_rows.add_child(_shop_head("COMING SOON", "%d" % soon.size()))
		for r: Dictionary in soon:
			_armory_rows.add_child(_legend_row(r, coins))
	_armory_rows.add_child(_shop_note("Save your coins: these are the dearest looks in the crypt."))


## A Legend Vault card: its moving picture, name and kind, words, and its huge price (or
## WEARING, OWNED or COMING SOON). A tap shows the hero with it, with BUY or WEAR IT.
func _legend_row(r: Dictionary, coins: int) -> Button:
	var owned: bool = int(r.cost) < 0
	var ready: bool = r.ready
	var afford: bool = ready and not owned and int(r.cost) <= coins
	var gold := Legends.GOLD
	var edge := gold if (afford or r.worn) else (Color(0.5, 0.42, 0.3, 0.8) if ready else Color(0.3, 0.28, 0.34, 0.7))
	var b := button("", 20, Color(0.15, 0.1, 0.04, 0.98) if ready else Color(0.08, 0.07, 0.1, 0.98), edge)
	var n := str(r.text).length()
	b.custom_minimum_size = Vector2(0, 152 if n <= 80 else (176 if n <= 118 else 202))   # (3 or 4 lines of words; v362: the price was cut off under 4)
	(b.get_theme_stylebox("normal") as StyleBoxFlat).set_border_width_all(4 if r.worn else (3 if afford else 2))
	var id: String = r.legend
	if ready:
		_shop_tap(b, func(): bazaar_look.emit("legend", id))
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 12)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	full(m)
	b.add_child(m)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 12)
	m.add_child(h)
	var pic := LegendPet.Icon.new()
	pic.kind = id
	pic.slot = str(r.slot)
	pic.locked = not ready
	pic.custom_minimum_size = Vector2(112, 112)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pic)
	if ready and str(r.get("hero", "")) != "":
		# (Version 362: the chosen hero really wearing it, in place of the drawn symbol.)
		LookShots.want(str(r.hero), "legend", id, func(t: Texture2D) -> void:
			if is_instance_valid(pic):
				pic.picture = t)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 1)
	h.add_child(texts)
	var t := label(r.title, 24, gold.lightened(0.3) if ready else Color(0.62, 0.6, 0.66), HORIZONTAL_ALIGNMENT_LEFT)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	texts.add_child(t)
	var kind := label(Legends.SLOT_NAMES.get(str(r.slot), "") + "  ·  every hero", 14, Color(0.85, 0.7, 0.45) if ready else Color(0.5, 0.48, 0.55), HORIZONTAL_ALIGNMENT_LEFT)
	kind.autowrap_mode = TextServer.AUTOWRAP_OFF
	texts.add_child(kind)
	var d := label(r.text, 15, Color(0.82, 0.8, 0.86) if ready else Color(0.58, 0.56, 0.62), HORIZONTAL_ALIGNMENT_LEFT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(d)
	var price := HBoxContainer.new()
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(price)
	if owned:
		var tag := label("WEARING  ·  tap to take off" if r.worn else "OWNED  ·  tap to wear", 18, Color(0.6, 1, 0.6) if r.worn else Color(0.8, 0.95, 0.8), HORIZONTAL_ALIGNMENT_LEFT)
		tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		price.add_child(tag)
	else:
		var cost_label := coin_row(26, price)
		cost_label.text = thousands(int(r.cost))
		if not afford:
			cost_label.label_settings.font_color = Color(0.62, 0.56, 0.48) if ready else Color(0.45, 0.42, 0.48)
		if not ready:
			var soon := label("   COMING SOON", 15, Color(0.6, 0.56, 0.66), HORIZONTAL_ALIGNMENT_LEFT)
			soon.autowrap_mode = TextServer.AUTOWRAP_OFF
			price.add_child(soon)
	return b


## A heading over a group of cards: its name on the left, a count on the right, a thin line.
func _shop_head(text: String, count := "") -> Control:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 3)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(6, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(gap)
	var t := label(text, 17, Color(1, 0.85, 0.55), HORIZONTAL_ALIGNMENT_LEFT)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var n := label(count, 16, Color(0.66, 0.62, 0.7), HORIZONTAL_ALIGNMENT_RIGHT)
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(n)
	var gap2 := gap.duplicate()
	h.add_child(gap2)
	var line := ColorRect.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.color = Color(1, 0.85, 0.55, 0.18)
	line.custom_minimum_size = Vector2(0, 2)
	v.add_child(line)
	return v


## A quiet line of words in the card window.
func _shop_note(text: String) -> Label:
	var l := label(text, 16, Color(0.66, 0.64, 0.72))
	return l


## The Bone Bazaar's featured look (version 397): the hero wearing it on a small stage, under
## a lantern's glow, its name large, and its price on a gold plate.
func _bazaar_feature(r: Dictionary, coins: int) -> Button:
	var afford: bool = r.cost <= coins
	var amber := BAZAAR_AMBER
	var b := button("", 20, Color(0.22, 0.12, 0.05, 0.98), GOLD if afford else amber)
	b.custom_minimum_size = Vector2(0, 240)
	(b.get_theme_stylebox("normal") as StyleBoxFlat).set_border_width_all(4)
	var look: Array = r.look
	_shop_tap(b, func(): bazaar_look.emit(str(look[0]), str(look[1])))
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 6)
	m.add_theme_constant_override("margin_right", 14)
	full(m)
	b.add_child(m)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 6)
	m.add_child(h)
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(212, 228)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.draw.connect(func() -> void:
		# a lantern's glow behind the hero, and the floor's shadow under them
		var c := Vector2(106, 112)
		for i in 7:
			var k := 1.0 - i / 7.0
			box.draw_circle(c, 40.0 + 70.0 * k, Color(1.0, 0.62, 0.2, 0.05))
		for i in 12:
			var a := TAU * i / 12.0
			box.draw_line(c + Vector2.from_angle(a) * 62.0, c + Vector2.from_angle(a) * (96.0 if i % 2 == 0 else 84.0), Color(1.0, 0.72, 0.3, 0.16), 5.0, true))
	h.add_child(box)
	var stage := HeroStage.new(Vector2(212, 228))
	stage.soft_edge = true
	stage.custom_minimum_size = Vector2(212, 228)
	stage.size = Vector2(212, 228)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(stage)
	stage.show_hero(r.preview)
	stage.set_active(true)
	b.visibility_changed.connect(func() -> void:
		if is_instance_valid(stage):
			stage.set_active(b.is_visible_in_tree()))
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 2)
	h.add_child(texts)
	var tag := label("TODAY'S FEATURED LOOK", 14, Color(0.16, 0.08, 0.02), HORIZONTAL_ALIGNMENT_LEFT)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = amber.lightened(0.15)
	tsb.set_corner_radius_all(8)
	tsb.content_margin_left = 8
	tsb.content_margin_right = 8
	tsb.content_margin_top = 1
	tsb.content_margin_bottom = 1
	tag.add_theme_stylebox_override("normal", tsb)
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	texts.add_child(tag)
	var t := label(r.title, 32, amber.lightened(0.45), HORIZONTAL_ALIGNMENT_LEFT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(t)
	var d := label(r.text, 17, Color(0.86, 0.84, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
	d.autowrap_mode = TextServer.AUTOWRAP_OFF
	texts.add_child(d)
	if r.has("from"):
		var f := label(r.from, 16, r.from_color, HORIZONTAL_ALIGNMENT_LEFT)
		f.autowrap_mode = TextServer.AUTOWRAP_OFF
		texts.add_child(f)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	texts.add_child(gap)
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.09, 0.05, 0.03, 0.95)
	psb.border_color = GOLD if afford else Color(0.5, 0.4, 0.32)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(22)
	psb.content_margin_left = 12
	psb.content_margin_right = 16
	psb.content_margin_top = 3
	psb.content_margin_bottom = 3
	plate.add_theme_stylebox_override("panel", psb)
	texts.add_child(plate)
	var price := HBoxContainer.new()
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(price)
	var cost_label := coin_row(32, price)
	cost_label.text = thousands(int(r.cost))
	if not afford:
		cost_label.label_settings.font_color = Color(0.6, 0.55, 0.5)
	texts.add_child(label("Tap to try it on", 15, Color(0.7, 0.66, 0.7), HORIZONTAL_ALIGNMENT_LEFT))
	return b


## A Bone Bazaar look: its picture, name and kind, and its price (or OWNED). A tap shows the
## hero wearing it, with BUY (drop_screen.gd show_offer).
func _bazaar_row(r: Dictionary, coins: int) -> Button:
	var owned: bool = r.cost < 0
	var afford: bool = not owned and r.cost <= coins
	var amber := BAZAAR_AMBER
	var b := button("", 20, Color(0.16, 0.1, 0.06, 0.98) if not owned else Color(0.1, 0.09, 0.12, 0.98), amber if afford else Color(0.5, 0.4, 0.32, 0.7))
	b.custom_minimum_size = Vector2(0, 140)   # (v397: a little shorter, under the featured look)
	(b.get_theme_stylebox("normal") as StyleBoxFlat).set_border_width_all(3 if afford else 2)
	var look: Array = r.look
	_shop_tap(b, func(): bazaar_look.emit(str(look[0]), str(look[1])))
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 12)
	full(m)
	b.add_child(m)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 12)
	m.add_child(h)
	var sw := StyleScreen.Swatch.new()
	sw.custom_minimum_size = Vector2(116, 116)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.setup(str(r.hero), str(look[0]), str(look[1]), r.base)
	h.add_child(sw)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	h.add_child(texts)
	var t := label(r.title, 26, amber.lightened(0.35) if not owned else Color(0.7, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	texts.add_child(t)
	var d := label(r.text, 16, Color(0.82, 0.8, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	d.autowrap_mode = TextServer.AUTOWRAP_OFF
	texts.add_child(d)
	if r.has("from"):
		var f := label(r.from, 15, r.from_color, HORIZONTAL_ALIGNMENT_LEFT)
		f.autowrap_mode = TextServer.AUTOWRAP_OFF
		texts.add_child(f)
	texts.add_child(label("Tap to try it on" if not owned else "Tap to wear it", 15, Color(0.62, 0.6, 0.66), HORIZONTAL_ALIGNMENT_LEFT))
	if owned:
		var tag := label("OWNED", 22, Color(0.6, 1, 0.6))
		tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(tag)
	else:
		var price := HBoxContainer.new()
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(price)
		var cost_label := coin_row(28, price)
		cost_label.text = thousands(int(r.cost))
		if not afford:
			cost_label.label_settings.font_color = Color(0.6, 0.55, 0.5)
	return b


const CURSE_TINTS := [Color(1.0, 0.74, 0.32), Color(0.8, 0.52, 1.0), Color(1.0, 0.3, 0.36)]


func _curse_row(r: Dictionary) -> Button:
	var on: bool = r.on
	var locked: bool = r.get("locked", false)
	var red := GOLD if r.get("gold", false) else Color(0.95, 0.35, 0.4)
	var on_bg := Color(0.2, 0.15, 0.04, 0.98) if r.get("gold", false) else Color(0.2, 0.06, 0.09, 0.98)
	var b := button("", 20, on_bg if on else Color(0.12, 0.1, 0.16, 0.98), red if on else Color(0.4, 0.35, 0.45, 0.6))
	b.custom_minimum_size = Vector2(0, 80 if r.get("gold", false) else 64)
	if on or r.get("gold", false):
		(b.get_theme_stylebox("normal") as StyleBoxFlat).set_border_width_all(4 if on else 2)
	var cid: String = r.id
	_shop_tap(b, func(): curse_toggled.emit(cid))
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 16)
	full(m)
	b.add_child(m)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 10)
	m.add_child(h)
	# Version 396 (visual review of v388, fix 9): each curse has its own picture, coloured
	# by its level (amber, orange, red; Heroic gold), dim while it is locked.
	var icon := BlessingIcon.new()
	icon.zoom = 0.8
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.show_icon("c_" + cid, "bone", GOLD if r.get("gold", false) else CURSE_TINTS[clampi(int(r.level), 1, 3) - 1])
	if locked:
		icon.modulate = Color(0.6, 0.6, 0.66, 0.75)
	h.add_child(icon)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	h.add_child(texts)
	var t := label("%s   Lv %d%s" % [r.title, r.level, "  ·  FREE" if r.get("gold", false) and not locked else ""], 22 if r.get("gold", false) else 20, red.lightened(0.3) if on else (Color(0.6, 0.58, 0.62) if locked else Color.WHITE), HORIZONTAL_ALIGNMENT_LEFT)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	texts.add_child(t)
	var d := label(r.text, 15, Color(0.78, 0.78, 0.84), HORIZONTAL_ALIGNMENT_LEFT)
	if not r.get("gold", false):   # (v396: Heroic's long line wraps in its taller row, beside its picture)
		d.autowrap_mode = TextServer.AUTOWRAP_OFF
	texts.add_child(d)
	var tag := label(str(r.get("lock", "PASS")) if locked else ("ON" if on else "OFF"), 20, GOLD.darkened(0.2) if locked else (red if on else Color(0.6, 0.58, 0.62)))
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(tag)
	return b


## One Armory or Vault card (version 225): the picture, the name with its level dots, the
## words (they wrap, and the card grows to hold them: they spilled out before) and, on the
## right, the price or what it is now. A PanelContainer holds the button and the words on
## top of it, so the card is always as tall as its words.
func _shop_card(r: Dictionary, coins: int) -> Control:
	var have: bool = int(r.cost) < 0
	var afford: bool = not have and int(r.cost) <= coins
	var blessing: Dictionary = r.get("vault", {})
	var vault := not blessing.is_empty()
	var pic: Array = ARMORY_ICONS.get(str(r.id), ["", GOLD])
	var accent: Color = Upgrades.color(blessing) if vault else pic[1]
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var bg := Color(0.08, 0.07, 0.1, 0.96) if have else Color(0.14, 0.11, 0.18, 0.98)
	var edge := GOLD if afford else (Color(0.4, 0.62, 0.45, 0.45) if have else Color(0.42, 0.37, 0.48, 0.65))
	var b := button("", 20, bg, edge)
	b.custom_minimum_size = Vector2(0, 84)
	(b.get_theme_stylebox("normal") as StyleBoxFlat).set_border_width_all(3 if afford else 2)
	var id := str(r.id)
	_shop_tap(b, func(): armory_buy.emit(id))
	card.add_child(b)
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 9)
	m.add_theme_constant_override("margin_bottom", 10)
	card.add_child(m)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 12)
	m.add_child(h)
	var icon := BlessingIcon.new()
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if vault:
		icon.show_for(blessing)
	else:
		icon.show_icon(str(pic[0]), "bone", accent)
	h.add_child(icon)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 2)
	h.add_child(texts)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 10)
	texts.add_child(top)
	var t := label(str(r.title), 22, accent.lightened(0.25) if not have or vault else Color(0.78, 0.95, 0.78), HORIZONTAL_ALIGNMENT_LEFT)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(t)
	if int(r.max) > 1:
		top.add_child(_level_dots(int(r.level), int(r.max), accent))
	var d := label(str(r.text), 16, Color(0.8, 0.79, 0.86) if not have else Color(0.68, 0.67, 0.74), HORIZONTAL_ALIGNMENT_LEFT)
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(d)
	if have:
		var done: String = r.get("done", "IN RUNS" if vault else ("OWNED" if int(r.max) <= 1 else "MAX"))
		var green := Color(0.55, 0.95, 0.6)
		h.add_child(_shop_chip(done, green if r.get("done", "") == "" else Color(0.75, 0.72, 0.8)))
	else:
		h.add_child(_price_pill(int(r.cost), afford))
	return card


## The level dots after an upgrade's name: lit ones in its colour, the rest dark.
static func _level_dots(level: int, most: int, col: Color) -> Control:
	var p := Control.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(most * 15 - 3, 16)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.draw.connect(func():
		for i in most:
			var c := Vector2(6 + i * 15, p.size.y * 0.5)
			p.draw_circle(c, 6.5, INK)
			if i < level:
				p.draw_circle(c, 5.0, col)
				p.draw_circle(c + Vector2(-1.5, -1.8), 1.6, Color(1, 1, 1, 0.55))
			else:
				p.draw_circle(c, 5.0, Color(0.24, 0.22, 0.28)))
	return p


## A price on a card: a coin and the number in a raised gold pill (grey if you can't pay).
func _price_pill(cost: int, afford: bool) -> Control:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.4, 0.25, 0.04) if afford else Color(0.17, 0.15, 0.2)
	sb.border_color = GOLD if afford else Color(0.38, 0.35, 0.42)
	sb.set_border_width_all(2)
	sb.border_width_bottom = 5
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 9
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(96, 0)   # the prices line up down the list
	var l := coin_row(22, p, true)
	(l.get_parent() as HBoxContainer).add_theme_constant_override("separation", 6)
	l.text = thousands(cost)
	if not afford:
		l.label_settings.font_color = Color(0.62, 0.58, 0.62)
		(l.get_parent().get_child(0) as Control).modulate = Color(1, 1, 1, 0.55)
	return p


## What a card is now, in a small outlined chip: IN RUNS, MAX, OWNED, TOMORROW...
func _shop_chip(text: String, col: Color) -> Label:
	var l := label(text, 16, col)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.12)
	sb.border_color = Color(col, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	l.add_theme_stylebox_override("normal", sb)
	return l


func show_hint(text: String) -> void:
	_hint.text = text
	# Version 373: the standing hint is one line too, shrunk until it fits the phone.
	var font := _hint.label_settings.font if _hint.label_settings.font else _hint.get_theme_font("font")
	var room := minf(get_viewport().get_visible_rect().size.x - 28.0, TIP_WIDE) - 36.0
	var fs := 27
	while fs > 20 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + _hint.label_settings.outline_size * 2.0 > room:
		fs -= 1
	_hint.label_settings.font_size = fs
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	var half := minf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 60.0, room + 36.0) * 0.5
	_hint.offset_left = -half
	_hint.offset_right = half
	_hint.offset_top = -198
	_hint.offset_bottom = -158
	_hint_on = text != ""
	_hint.visible = _hint_on and not _tip.visible


var _hint_on := false


## `score` counts up from zero on the end screen; `best` is the best score before this run.
## `offer` swaps the tap line for the Crypt Pass offer (after the last free floor).
func show_end(v: bool, victory := false, stats := "", tap_text := "Tap to try again", buttons := false, score := -1, best := 0, offer := false) -> void:
	if v:
		_callout_queue.clear()   # v216: old words never show over the next screen
		_park_toast()   # v218: a toast that started just before never stays on top
	# The run's top bar would show through the end screen: hide it while it's up.
	if v and not _end_box.visible:
		_hud_before_end = _safe.visible
		_safe.visible = false
	elif not v and _end_box.visible:
		_safe.visible = _hud_before_end
	_end_box.visible = v
	if v:
		_hide_phase()
		refresh_looks_badge()   # NEW LOOKS and UPGRADE, with this run's coins counted
	_end_offer.visible = v and offer
	_end_offer_back.text = "BACK TO TITLE  (RUN SAVED)"   # (the Free Dive's says set_offer_back)
	if offer and Store.instance:
		# v218 (review 4): one priced button ("GET THE CRYPT PASS" had no price).
		# Play's own price in the player's currency; the US price only on the test build.
		var pr := Store.instance.price if Store.instance.price != "" else ("" if Store.can_buy() else Store.FALLBACK_PRICE)
		var deal := Store.deal_now()
		if not deal.is_empty():
			pr = str(deal.price)   # version 279: the Early Access Deal's price, its ribbon above
		_end_get_pass.text = ("UNLOCK FLOOR 6+  " + pr).strip_edges()
	_show_deal(_end_deal)
	_end_deal.visible = _end_deal.visible and v and offer
	_end_loop.visible = false
	var big := v and victory and not offer and not end_hero_def.is_empty()
	_end_hero_box.visible = big
	_end_hero.set_active(big)
	if big:
		_end_hero.front_turn = 0.6 if str(end_hero_def.get("id", "")) == "knight" else 0.0
		_end_hero.show_hero(end_hero_def)
		_end_hero.emote(end_hero_def.get("emote", ["Cheer"]))
	_end_tiles.visible = v and victory and not offer
	end_hero_def = {}
	if not v:
		end_hide_best = false
		_drops.visible = false   # (never left over a run that's starting)
		if _pass_card.visible:
			show_pass_card(false)
		return
	_end_score.visible = score >= 0
	_end_best.visible = score >= 0
	_end_target = maxi(score, 0)
	_end_best_value = best
	_end_count = 0.0 if score >= 0 else -1.0
	_end_score.text = "SCORE  0"
	_end_best.text = ""
	_set_end_tap(tap_text)
	_copy_button.text = "COPY REPORT"
	# A tool for balancing the game, only for players who chose to send reports.
	_copy_button.visible = _reports_on
	_end_tap.visible = not buttons and not offer
	_end_buttons.visible = buttons
	if v and buttons:
		refresh_looks_badge.call_deferred()   # (after the run's mastery is saved)
	_end_title_button.visible = false
	_end_pass.visible = false
	if _pass_card.visible:
		show_pass_card(false)
	_share_button.visible = false
	_share_card.visible = false
	_end_spacer.custom_minimum_size.y = 100.0 if not buttons else 24.0
	if victory and not offer:
		_end_spacer.custom_minimum_size.y = 12.0   # v388: the hero and the tiles take that room
	_end_title.text = "VICTORY" if victory else "YOU DIED"
	# Version 219 (review 4 fix 19): after a fall TRY AGAIN is the one bright button; the
	# Bone Drop button goes quiet (slate) so the two don't fight. After a win it stays gold.
	paint(_end_drop, "gold" if victory else "slate")
	set_glow(_end_box, "victory" if victory else "death")
	_end_title.label_settings.font_color = Color(1, 0.85, 0.4) if victory else Color(0.9, 0.2, 0.2)
	# Version 213 (hardest review fix #13): after a fall, what hurt most shows at once (a fast
	# TRY AGAIN never saw it after the score's count-up), and a score of 0 isn't shown.
	if not victory:
		_end_score.visible = score > 0
		_end_best.visible = score > 0
		if score <= 0:
			_end_count = -1.0
	# Version 216 (review 2 fix #3): at the end of the free game the score is shown whole and
	# the text (which opens with what the Crypt Pass gives) comes at once, not after a count-up.
	if offer and score >= 0:
		_end_count = -1.0
		_end_score.text = "SCORE  " + thousands(score)
		_end_best.text = "Best  " + thousands(maxi(best, score))
	if end_hide_best:
		_end_best.visible = false
	_start_tally(stats, score >= 0 and victory and not offer)
	_end_goal.visible = false
	_end_mastery.visible = false
	_end_looks.visible = false
	_fit_end_soon()


## The end screen's line after an event run (Game: any tap goes back to the event screen).
const EVENT_TAP := "Tap to return to the event"


## The end screen's "tap anywhere" line. Going deeper after a win is the main way on, so it
## looks like a bright button (DESCEND TO FLOOR 3) instead of a faint line; any tap still works.
func _set_end_tap(tap_text: String) -> void:
	# Version 221 (v219 review): the end of a Queen Hunt or a Blood Moon run had only a faint
	# "Tap to return to the title"; it is now a green BACK TO EVENT button (to the road and
	# the next Hunt). Any tap still works, and goes there too.
	var to_event := tap_text == EVENT_TAP
	var deeper := tap_text.begins_with("Tap to descend") or to_event
	_end_tap.text = ("BACK TO EVENT" if to_event else tap_text.replace("Tap to descend", "DESCEND").to_upper()) if deeper else tap_text
	(_end_tap as Pulse).low = 0.85 if deeper else 0.1
	# Version 147: the green DESCEND button is the main way on, so it is big (about 96 px,
	# 73 dp on a phone; was about 66) with bigger letters.
	_end_tap.label_settings.font_size = 36 if deeper else 30
	_end_tap.custom_minimum_size = Vector2(400, 96) if deeper else Vector2.ZERO
	_end_tap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_end_tap.autowrap_mode = TextServer.AUTOWRAP_OFF if deeper else TextServer.AUTOWRAP_WORD_SMART
	_end_tap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if deeper else Control.SIZE_FILL
	if deeper:
		var sb := StyleBoxFlat.new()   # the chunky green "go" look of the buttons (paint)
		sb.bg_color = ROLES.green[0]
		sb.border_color = ROLES.green[1]
		sb.set_corner_radius_all(18)
		sb.set_border_width_all(3)
		sb.border_width_bottom = 9
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 2
		sb.shadow_offset = Vector2(0, 4)
		sb.content_margin_left = 40
		sb.content_margin_right = 40
		sb.content_margin_top = 16
		sb.content_margin_bottom = 16
		_end_tap.add_theme_stylebox_override("normal", sb)
	else:
		_end_tap.remove_theme_stylebox_override("normal")


## The end screen's Hero Mastery bar, filling with this run's points (`info` from
## Game._bank_mastery; {} hides it).
func show_mastery(info: Dictionary) -> void:
	_end_mastery.visible = not info.is_empty() and _end_box.visible
	if _end_mastery.visible:
		_end_mastery.play(info)
	# A level reached this run: a button that shows the hero wearing what it unlocked.
	_end_looks_for = {}
	if _end_mastery.visible:
		for l: Dictionary in info.get("levels", []):
			var n := HeroStyle.level_items(str(info.id), int(l.level)).size()
			if n > 0:
				_end_looks_for = {"id": info.id, "level": int(l.level), "n": n}
	_end_looks.visible = not _end_looks_for.is_empty()
	if _end_looks.visible:
		var n := int(_end_looks_for.n)
		_end_looks.text = "SEE %d NEW LOOK%s" % [n, "" if n == 1 else "S"]
	_fit_end_soon()


## The Mastery screen for hero `id` (mastery_screen.gd), filled from `cfg`.
## `coins` for Training (-1 hides it).
func open_mastery(cfg: ConfigFile, id: String, coins := -1) -> void:
	_mastery.open_hero(cfg, id, coins)


## After a Training: the bar fills from `before`, levels reached named on the way.
func mastery_trained(cfg: ConfigFile, id: String, before: int, coins: int, levels: Array) -> void:
	_mastery.trained(cfg, id, before, coins, levels)


## The Feats screen (feats_screen.gd), over the Style screen.
## The big reveal for Feats won this run (drop_screen.gd reveal_feats).
func reveal_feats(list: Array) -> void:
	# Version 217 (review 3 fix #4): the big reveal shows these Feats, so their toasts go,
	# and a toast already on screen is put away (it stayed on top of the reveal).
	var names := []
	for it: Dictionary in list:
		names.append(str(it.get("name", "")))
	var keep := []
	for q: Array in _toast_queue:
		if not str(q[0]) in names:
			keep.append(q)
	_toast_queue = keep
	_park_toast(names)
	_drops.reveal_feats(list)
	if not _toast_busy and not _toast_queue.is_empty():
		_next_toast()


## The Bone Bazaar's preview of a look (drop_screen.gd show_offer), and after buying it.
func show_offer(o: Dictionary) -> void:
	_drops.show_offer(o)


func offer_bought(coins_left: int) -> void:
	_drops.offer_bought(coins_left)


func open_feats(cfg: ConfigFile, id: String) -> void:
	_feats.open_screen(cfg, id)


## True while a full-screen, opaque menu covers the dungeon (Style, Feats, Mastery, Bone
## Drops, Heroes...): the game then stops drawing the 3D world behind it (battery and heat).
## Version 131: every menu with the lit crypt wall (MenuBackdrop) is solid, so Modes, the
## Daily Crypt, Omens, Feedback, the Bone Road and the reports question count too.
func covers_world() -> bool:
	return _style.visible or _feats.visible or _mastery.visible or _drops.visible or _heroes_box.visible \
			or (_rewards_box != null and _rewards_box.visible) or _armory_box.visible or _records_box.visible or (_today_box != null and _today_box.visible) \
			or _pass_box.visible or _modes_box.visible or _daily_box.visible or _omen_box.visible \
			or _fb_box.visible or _road.visible or _ask_box.visible or _rem_box.visible or _event.visible or _splash.visible \
			or (_leaders != null and _leaders.visible)


func feats_visible() -> bool:
	return _feats.visible


func close_feats() -> void:
	_feats.close()


## The hero the Style screen is open for ("" when it's closed).
func style_hero() -> String:
	return _style.hero_id() if _style.visible else ""


## A Feat just done: a gold and cyan card drops in at the top, names it and the look it won,
## and goes after a few seconds (it never stops play).
## Feats done close together (a boss kill can finish four at once) wait their turn: one
## toast and one sound each, about 2.5 seconds apart.
var _toast_queue: Array = []
var _toast_busy := false


func feat_toast(feat_name: String, look: String) -> void:
	_toast_queue.append([feat_name, look])
	if not _toast_busy:
		_next_toast()


## Version 218: a Feat toast never covers the action or a screen that asks for a choice:
## a fight with enemies left, a card pick, a room change, the win celebration, a victory,
## an end or Pass screen, the Bone Drop / Feat reveal or the event splash. It waits.
func _toast_held() -> bool:
	if Game.state in [Game.State.PLAYING, Game.State.PAUSED] \
			and (Game.alive_enemies > 0 or Game._cleared_serial != Game._room_serial):
		return true   # the whole fight, waves and all, until the room is cleared
	if Game.state in [Game.State.VICTORY, Game.State.UPGRADE, Game.State.TRANSITION] or Game._celebrating:
		return true
	return _drops.visible or (_end_box != null and _end_box.visible) \
		or (_pass_box != null and _pass_box.visible) or (_splash != null and _splash.visible)


## Version 218: puts away a toast already on screen (it started a moment before a screen
## opened) and keeps its Feat at the front of the queue for later, unless it is in `skip`.
func _park_toast(skip := []) -> void:
	if _toast == null or not _toast.visible:
		return
	if _toast_tween:
		_toast_tween.kill()
	_toast.visible = false
	if not _toast_name.text in skip:
		_toast_queue.push_front([_toast_name.text, _toast_look.text.trim_prefix("New look: ")])
	_toast_busy = false
	_resume_toasts.call_deferred()   # after the screen is up, so it waits for it


func _resume_toasts() -> void:
	if not _toast_busy and not _toast_queue.is_empty():
		_next_toast()


func _next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	# Version 218: one rule, checked again after every wait (the old two loops ran one after
	# the other, so a toast held by the end screen could drop into the next fight).
	while _toast_held():
		await get_tree().create_timer(0.3, false).timeout
	if _toast_queue.is_empty():
		_toast_busy = false
		return
	var item: Array = _toast_queue.pop_front()
	_show_toast(str(item[0]), str(item[1]))
	Sfx.play("victory", 0.6, 1.2)


func _show_toast(feat_name: String, look: String) -> void:
	if _toast == null:
		_toast = PanelContainer.new()
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.12, 0.16, 0.94)
		sb.border_color = Color(0.5, 0.95, 1.0)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(16)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 8
		sb.content_margin_bottom = 10
		sb.shadow_color = Color(0.3, 0.9, 1.0, 0.35)
		sb.shadow_size = 12
		_toast.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		_toast.add_child(v)
		v.add_child(label("FEAT DONE!", 18, Color(0.5, 0.95, 1.0)))
		_toast_name = label("", 32, GOLD)
		v.add_child(_toast_name)
		_toast_look = label("", 19, Color(0.9, 0.95, 1.0))
		v.add_child(_toast_look)
		# One line each (wrapping labels have no width of their own and would stretch it).
		for l: Label in v.get_children():
			l.autowrap_mode = TextServer.AUTOWRAP_OFF
		_toast.custom_minimum_size = Vector2(400, 0)
		add_child(_toast)
	_toast_name.text = feat_name
	_toast_look.text = "New look: " + look
	var vw := get_viewport().get_visible_rect().size.x
	_toast.custom_minimum_size.x = minf(400.0, vw - 32.0)
	_toast.size = Vector2.ZERO
	_toast.reset_size()
	# Version 121: it slides down from the top edge to just under the corner buttons (title)
	# or the room name and boss bar (a run), never over the hero's face.
	var top := float(_safe.get_theme_constant("margin_top")) if _safe else 0.0
	var y := top + (96.0 if Game.state == Game.State.TITLE else 150.0)
	_toast.position = Vector2((vw - _toast.size.x) * 0.5, -_toast.size.y - 8.0)
	_toast.pivot_offset = _toast.size * 0.5
	_toast.visible = true
	_toast.modulate.a = 0.0
	_toast.scale = Vector2.ONE
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween().set_ignore_time_scale(true)
	_toast_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.parallel().tween_property(_toast, "position:y", y, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(2.4 if _toast_queue.is_empty() else 1.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(func():
		_toast.visible = false
		_next_toast())


func close_mastery() -> void:
	_mastery.visible = false


## The Style screen for hero `id` (style_screen.gd). The Heroes screen's pedestal stops
## drawing underneath it.
func open_style(cfg: ConfigFile, id: String) -> void:
	if _heroes_box.visible:
		_heroes_box._stage.set_active(false)
	_style.open_hero(cfg, id)
	refresh_looks_badge()


func style_show_new(lv: int) -> void:
	_style.show_new(lv)


func style_note(text: String) -> void:
	_style.set_note(text)


func close_style() -> void:
	_style.close()


func style_visible() -> bool:
	return _style.visible


func mastery_visible() -> bool:
	return _mastery.visible


## The gold line under the end screen's stats (hidden when empty).
func set_end_goal(text: String) -> void:
	_end_goal.text = text
	_end_goal.visible = text != "" and _end_box.visible
	_fit_end_soon()


## Fits now and again two frames later: a wrapping label that was hidden has no width when it
## first shows and measures one word per line, which shrank the whole end screen for a frame or more.
func _fit_end_soon() -> void:
	_fit_end.call_deferred()
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(self):
		_fit_end()


## Short screens (16:9 phones, tablets): the end screen tightens its gaps and, if it still
## doesn't fit, shrinks as a whole so the last button stays on screen.
func _fit_end() -> void:
	if not _end_box.visible:
		return
	# Version 218 (review 4): the free-end offer is one choice. The looks, drops and share
	# buttons (and the card's own Pass button) wait for the title, so nothing is shrunk.
	if _end_offer.visible:
		for c: Control in [_end_drop, _end_looks, _share_button, _share_card, _pass_card_btn]:
			if c != null:
				c.visible = false
	# Version 219 (review 4 fix 19): the empty SHARE/COPY row took a gap of its own between
	# the Bone Drop button and TRY AGAIN; it now only takes room when it shows something.
	(_copy_button.get_parent() as Control).visible = _copy_button.visible
	_end_extras.visible = _end_looks.visible or _end_drop.visible or _share_button.visible
	# Fill the box again first. Moving the column (below) fixes its size at whatever it was
	# then, so after one tall end screen the next ones stayed stretched past the bottom and
	# their buttons were centred off the screen.
	_end_col.scale = Vector2.ONE
	_end_col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shown := 0
	for c in _end_col.get_children():
		if (c as Control).visible:
			shown += 1
	var room := _end_box.size.y - 32.0
	var need := _end_col.get_combined_minimum_size().y - float(_end_col.get_theme_constant("separation")) * (shown - 1)
	var gap := 24.0 if need + 24.0 * (shown - 1) <= room else 10.0
	_end_col.add_theme_constant_override("separation", int(gap))
	need += gap * (shown - 1)
	var k := minf(1.0, room / maxf(need, 1.0))
	_end_col.pivot_offset = Vector2(_end_box.size.x * 0.5, 0.0)
	_end_col.scale = Vector2(k, k)
	_end_col.position.y = 16.0 if k < 1.0 else 0.0


func _update_end_count(delta: float) -> void:
	if _end_count < 0.0 or not _end_box.visible:
		return
	var was := _end_count
	_end_count = minf(1.0, _end_count + delta / 1.4)
	var shown := roundi(_end_target * ease(_end_count, 0.4))
	_end_score.text = "SCORE  " + thousands(shown)
	if int(was * 20.0) != int(_end_count * 20.0) and _end_count < 1.0:
		Sfx.play("coin", 0.35)
	if _end_count >= 1.0:
		_end_count = -1.0
		if _tally_wait:
			_tally_wait = false
			_tally_i = 0
			_tally_t = 0.0
		if _end_target > _end_best_value and _end_target > 0:
			_end_best.text = "NEW BEST!"
			_end_best.label_settings.font_color = Color(1, 0.8, 0.3)
			Sfx.play("upgrade", 0.6)
		else:
			_end_best.text = "Best  " + thousands(_end_best_value)
			_end_best.label_settings.font_color = Color(0.8, 0.78, 0.7)
		_fit_end.call_deferred()   # the best line has words in it now


func _start_tally(stats: String, after_score: bool) -> void:
	_tally = PackedStringArray()
	# v389 (review v388 fix 1): a tile that would say 0 (BONES +0 on a Daily, COINS 0) is
	# left out with its line; only the time always shows.
	for line: String in stats.split("\n"):
		var cut := line.find("  ")
		if cut > 0 and END_TILES.has(line.substr(0, cut)) and line.substr(0, cut) != "Time":
			var first := line.substr(cut).strip_edges().split(" ", false)
			var num := str(first[0]).trim_prefix("+").replace(",", "") if first.size() > 0 else ""
			if num.is_valid_int() and int(num) == 0:
				continue
		_tally.append(line)
	_tally_wait = after_score
	_tally_i = -1 if after_score else 0
	_tally_t = 0.0
	_tile_of = {}
	for c in _end_tiles.get_children():
		c.queue_free()
	_end_tile_vals = []
	if _end_tiles.visible:
		for i in _tally.size():
			var line: String = _tally[i]
			var cut := line.find("  ")
			if cut > 0 and END_TILES.has(line.substr(0, cut)) and _end_tile_vals.size() < 4:
				_tile_of[i] = _end_tile_vals.size()
				_end_tile_vals.append(_end_tile(str(END_TILES[line.substr(0, cut)])))
	_end_tiles.visible = not _tile_of.is_empty()
	_show_tally(_tally_text(-1, 0.0))


## One of the win screen's number tiles: a dark gold-edged card, the number big, its name under.
func _end_tile(caption: String) -> Array:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.08, 0.04, 0.9)
	sb.border_color = Color(1.0, 0.78, 0.35, 0.85)
	sb.set_border_width_all(2)
	sb.border_width_bottom = 5
	sb.set_corner_radius_all(14)
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(114, 96)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var val := label("0", 34, Color.WHITE)
	val.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(val)
	var cap := label(caption, 16, Color(1.0, 0.84, 0.5))
	cap.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(cap)
	var note := label("", 16, Color(0.95, 0.9, 0.75))
	note.autowrap_mode = TextServer.AUTOWRAP_OFF
	note.visible = false
	v.add_child(note)
	_end_tiles.add_child(p)
	return [val, note]


## Puts the tally's text on the end screen: tile lines into their tiles (the number only,
## with what follows it, like "Heroic +50%", as a small note), the lines before the tiles
## above them and the rest under them.
func _show_tally(text: String) -> void:
	if _tile_of.is_empty():
		_end_stats.text = text
		_end_after.visible = false
		return
	var before := []
	var after := []
	var lines := text.split("\n")
	for i in lines.size():
		var line: String = lines[i]
		if _tile_of.has(i):
			var parts := line.substr(line.find("  ")).strip_edges().split("  ", false)
			var t: Array = _end_tile_vals[int(_tile_of[i])]
			(t[0] as Label).text = str(parts[0]).trim_suffix(" bones") if parts.size() > 0 else ""
			var rest := []
			for k in range(1, parts.size()):
				rest.append(str(parts[k]).strip_edges().trim_prefix("(").trim_suffix(")"))
			(t[1] as Label).text = "\n".join(rest)
			(t[1] as Label).visible = not rest.is_empty()
		elif i < int(_tile_of.keys().min()):
			before.append(line)
		else:
			after.append(line)
	_end_stats.text = "\n".join(before).strip_edges()
	_end_after.text = "\n".join(after).strip_edges()
	_end_after.visible = _end_after.text != ""


## The gold light behind the hero on the win screen: soft rays turning slowly.
func _draw_end_rays() -> void:
	var c := _end_hero_box.size * Vector2(0.5, 0.52)
	var t := Time.get_ticks_msec() / 1000.0
	var glow := Color(1.0, 0.8, 0.38)
	for i in 14:
		var a := t * 0.22 + TAU * i / 14.0
		var w := 0.1
		var r := 220.0 if _end_title.text == "VICTORY" else 190.0
		var pts := PackedVector2Array([c, c + Vector2.from_angle(a - w) * r, c + Vector2.from_angle(a + w) * r])
		_end_hero_box.draw_polygon(pts, PackedColorArray([Color(glow, 0.5 if _end_title.text == "VICTORY" else 0.34), Color(glow, 0.0), Color(glow, 0.0)]))
	for k in 4:
		_end_hero_box.draw_circle(c, 120.0 - k * 26.0, Color(glow, 0.06))
	if _end_title.text != "VICTORY":
		return
	# Version 410 (re-review fix 10, "Victory staged as a reward"): the winner stands in a
	# gold laurel wreath, with stars twinkling round it, like a prize just won.
	var gold := Color(1.0, 0.78, 0.3)
	var dark := Color(0.42, 0.26, 0.05)
	var lc := _end_hero_box.size * Vector2(0.5, 0.56)
	var lr := 134.0   # (wide of the hero's sword and shield)
	for sgn in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for k in 15:
			var a: float = PI * 0.5 + sgn * (0.35 + 2.1 * k / 14.0)
			pts.append(lc + Vector2(cos(a), sin(a)) * lr)
		_end_hero_box.draw_polyline(pts, dark, 7.0, true)
		_end_hero_box.draw_polyline(pts, gold, 3.5, true)
		for k in range(1, 14):
			var a: float = PI * 0.5 + sgn * (0.35 + 2.1 * k / 14.0)
			var p: Vector2 = lc + Vector2(cos(a), sin(a)) * lr
			var along: Vector2 = Vector2(-sin(a), cos(a)) * sgn   # up the branch
			for side in [-1.0, 1.0]:
				var out: Vector2 = Vector2(cos(a), sin(a)) * side
				var tip: Vector2 = p + (along * 0.55 + out * 0.8).normalized() * 22.0
				var mid: Vector2 = (p + tip) * 0.5
				var nrm: Vector2 = (tip - p).normalized().orthogonal() * 6.0
				var leaf := PackedVector2Array([p, mid + nrm, tip, mid - nrm])
				_end_hero_box.draw_colored_polygon(leaf, dark)
				var inner := PackedVector2Array([p.lerp(tip, 0.1), mid + nrm * 0.55, tip.lerp(p, 0.12), mid - nrm * 0.55])
				_end_hero_box.draw_colored_polygon(inner, gold.lightened(0.1 * (k % 2)))
	for i in 7:   # stars twinkling round the wreath
		var a2 := TAU * i / 7.0 + 0.4
		var tw := 0.5 + 0.5 * sin(t * 3.0 + i * 1.9)
		var sp := lc + Vector2(cos(a2) * 168.0, sin(a2) * 118.0)
		var sz := 5.0 + 7.0 * tw
		_end_hero_box.draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -sz), sp + Vector2(sz * 0.3, 0), sp + Vector2(0, sz), sp + Vector2(-sz * 0.3, 0)]), Color(1.0, 0.95, 0.7, 0.4 + 0.6 * tw))
		_end_hero_box.draw_colored_polygon(PackedVector2Array([sp + Vector2(-sz, 0), sp + Vector2(0, sz * 0.3), sp + Vector2(sz, 0), sp + Vector2(0, -sz * 0.3)]), Color(1.0, 0.95, 0.7, 0.4 + 0.6 * tw))


## Version 396: the sun behind the Daily screen's hero, its rays turning slowly.
func _draw_daily_sun() -> void:
	var c := _daily_hero_box.size * Vector2(0.5, 0.5)
	var t := Time.get_ticks_msec() / 1000.0
	var glow := Color(1.0, 0.78, 0.36)
	for i in 12:
		var a := t * 0.18 + TAU * i / 12.0
		var r := 96.0 if i % 2 == 0 else 80.0
		var pts := PackedVector2Array([c + Vector2.from_angle(a - 0.16) * 56.0, c + Vector2.from_angle(a) * r, c + Vector2.from_angle(a + 0.16) * 56.0])
		_daily_hero_box.draw_colored_polygon(pts, Color(glow, 0.5))
	_daily_hero_box.draw_circle(c, 62.0, Color(0.34, 0.22, 0.06, 0.95))
	_daily_hero_box.draw_arc(c, 62.0, 0.0, TAU, 48, Color(glow, 0.9), 4.0, true)
	_daily_hero_box.draw_circle(c, 50.0, Color(glow, 0.12))


## A line like "Coins this run  45" or "Bone Road  +12 bones" counts up; text lines (and
## times, like "1:23") just appear.
static func _tally_number(line: String) -> RegExMatch:
	# The first gap, not the last (version 123): "Coins kept  45  (+50 first run today)"
	# counted the 50 and left the 45 still.
	var cut := line.find("  ")
	if cut < 0 or line.substr(cut).contains(":"):
		return null
	var re := RegEx.create_from_string("\\d[\\d,]*")
	return re.search(line, cut)


## The stats with lines before `upto` in full, line `upto` counted `k` (0..1) of the way,
## and the rest at 0. Version 221 (v219 review): the lines still to come showed blank, a
## big empty hole in the middle of the win screen for the first few seconds; now every line
## is there at once and only the numbers count up, in turn (nothing below jumps either).
func _tally_text(upto: int, k: float) -> String:
	var out := []
	for i in _tally.size():
		var line: String = _tally[i]
		if i < upto or upto >= _tally.size():
			out.append(line)
		else:
			var m := _tally_number(line)
			if m == null:
				out.append(line)
			else:
				var full := int(m.get_string().replace(",", ""))
				var n := roundi(full * ease(k, 0.5)) if i == upto else 0
				out.append(line.substr(0, m.get_start()) + (thousands(n) if m.get_string().contains(",") else str(n)) + line.substr(m.get_end()))
	return "\n".join(out)


func _update_tally(delta: float) -> void:
	if _tally_i < 0 or not _end_box.visible:
		return
	while _tally_i < _tally.size() and _tally[_tally_i].strip_edges() == "":
		_tally_i += 1   # blank lines take no time
	if _tally_i >= _tally.size():
		_show_tally("\n".join(_tally))
		_tally_i = -1
		_fit_end.call_deferred()   # a long line that wraps once shown can make it taller
		return
	var counts := _tally_number(_tally[_tally_i]) != null
	var dur := 0.5 if counts else 0.12
	var was := _tally_t
	_tally_t += delta
	if counts and int(was * 16.0) != int(_tally_t * 16.0) and _tally_t < dur:
		Sfx.play("tick", 0.35, 1.0 + _tally_t)
	if _tally_t >= dur:
		_show_tally(_tally_text(_tally_i + 1, 0.0))
		if counts:
			Sfx.play("coin", 0.5, 1.25)
			if Game.vibration:
				Input.vibrate_handheld(15)
		_tally_i += 1
		_tally_t = 0.0
	else:
		_show_tally(_tally_text(_tally_i, _tally_t / dur))


## Daily Crypt runs get their result card (rows of ShareCard codes) and a SHARE RESULT
## button on the end screen.
## After SHARE RESULT: the share menu opened (the words are copied too), or they were copied.
func share_done(opened: bool) -> void:
	_share_button.disabled = false
	_share_button.text = "Shared! The words are copied too" if opened else "Copied! Paste it anywhere"
	_share_button.add_theme_font_size_override("font_size", 16)


func show_share(v: bool, rows := [], caption := "") -> void:
	_share_button.visible = v
	_share_card.visible = v and not rows.is_empty()
	if _share_card.visible:
		_share_card.show_rows(rows, caption)
	_share_button.text = "SHARE RESULT"
	_share_button.add_theme_font_size_override("font_size", 20)
	_copy_button.custom_minimum_size.x = 240.0 if v else 300.0
	_fit_end_soon()


## Version 280: the words on the offer's way back to the title (the Free Dive saves no run).
func set_offer_back(text: String) -> void:
	_end_offer_back.text = text


## A CRYPT PASS button among the death-screen buttons (after a deep death, once a session).
func show_end_pass(v: bool) -> void:
	_end_pass.visible = v
	_fill_deal_pill(_end_pass_badge)
	_fit_end_soon()


## The end of a loop: DESCEND DEEPER into `next_loop`, or BANK AND LEAVE with `bonus` coins.
## The TITLE button under the end screen's other buttons.
func show_end_title(v: bool, text := "TITLE") -> void:
	_end_title_btn.text = text
	_end_title_button.visible = v and _end_box.visible
	_fit_end_soon()


func end_visible() -> bool:
	return _end_box.visible


func show_end_loop(v: bool, bonus := 0, next_loop := 2, just_bought := false) -> void:
	_end_loop.visible = v
	if not v:
		return
	_end_title_button.visible = false
	_end_offer.visible = false
	_end_tap.visible = false
	_end_spacer.custom_minimum_size.y = 24.0
	_loop_deeper_button.text = "DESCEND INTO LOOP %d" % next_loop
	_loop_bank_button.text = "BANK AND LEAVE  (+%s COINS)" % Hud.thousands(bonus)
	# v219 review: right after buying the Pass at the free end, the one way on is down into the
	# Drowned Vault the offer promised. Banking comes back at the next loop end.
	if just_bought:
		_loop_deeper_button.text = "ENTER THE DROWNED VAULT"
	_loop_bank_button.get_parent().visible = not just_bought
	_fit_end_soon()


## Replaces the end screen's middle text (after buying the Pass at the free end).
func set_end_stats(text: String) -> void:
	_tally_i = -1
	_tally_wait = false
	_tile_of = {}
	_end_tiles.visible = false
	_end_after.visible = false
	_end_stats.text = text
	_fit_end_soon()


## The Pass was bought on the end screen: carry on deeper instead.
func end_offer_done(tap_text: String) -> void:
	_end_offer.visible = false
	# v218: the looks and drops buttons held back during the offer come back.
	_end_looks.visible = not _end_looks_for.is_empty()
	set_drops(Drops.waiting(Game._load_save()))
	_pass_card_btn.visible = true
	_set_end_tap(tap_text)
	_end_tap.visible = true
	_fit_end_soon()


func show_pause(v: bool, settings_only := false) -> void:
	if v:
		_callout_queue.clear()   # v216: old words never show over the next screen
	if v:
		_hide_phase()
	var was_run_pause := _pause_box.visible and not _settings_only
	_settings_only = v and settings_only
	# v374: the fight's own bars and buttons step away while a run is paused (the run card
	# shows the hero's health), so the frozen fight is all there is behind the menu.
	if v and not _settings_only and not was_run_pause:
		_hud_before_pause = _safe.visible
		_safe.visible = false
	elif not v and was_run_pause:
		_safe.visible = _hud_before_pause
	_pause_title.text = "SETTINGS" if _settings_only else ("RACE ON!" if Game.race else "PAUSED")
	_resume_button.text = "BACK" if _settings_only else ("BACK TO THE RACE" if Game.race else "RESUME")
	_quit_button.text = _quit_text()
	_quit_button.visible = not _settings_only
	(_resume_button.get_parent() as Control).visible = not _settings_only
	_settings_back.visible = _settings_only
	if _rate_button:
		_rate_button.visible = not Game.first_run   # v220 (v219 review): no "Rate us" in the tutorial
	_pause_head.visible = not _settings_only
	(_speed_button.get_parent() as Control).visible = _settings_only
	if not v:
		_pause_more = false
	_show_pause_rows()
	# Darker over the busy title screen than over a paused room.
	# v374: a paused room keeps its fight in sight (a lighter, cooler veil with no purple
	# wash); the run card over it says whose run it is.
	(_pause_box as ColorRect).color = Color(0, 0, 0, 0.9) if _settings_only else PAUSE_VEIL
	var wash := _pause_box.get_node_or_null("Glow") as CanvasItem
	if wash:
		wash.visible = _settings_only
	if v and not _settings_only:
		_fill_pause_run()
	_pause_box.visible = v
	if v:
		_pause_build.text = "Build %s  ·  Install %s" % [Game.BUILD, Telemetry.install_id(Game._load_save())]
	if _quit_armed:
		_disarm_quit()


## The pause menu's longer rows: all of them on the title's Settings or after MORE SETTINGS.
func _show_pause_rows() -> void:
	var all := _settings_only or _pause_more
	for r in _pause_rows:
		r.visible = all
	if _pause_run:
		(_pause_run.get_parent() as Control).visible = not all   # (the long list needs the room)
	if _more_button:
		(_more_button.get_parent() as Control).visible = not all


## The pause menu's settings, from the SETTINGS button on the title screen.
func show_settings(v: bool) -> void:
	show_pause(v, true)


func settings_visible() -> bool:
	return _settings_only and _pause_box.visible


func set_fade(a: float) -> void:
	_fade.color.a = a
	_fade.visible = a > 0.003   # version 384: no full-screen pass while it's clear


# ---------------------------------------------------------------- the Blood Moon event

## The event's banner on the title: what's on and the countdown, or the week-before tease.
func refresh_event_banner() -> void:
	if _title_event == null:
		return
	var e := Events.current()
	var live := not e.is_empty()
	if not live:
		e = Events.coming()
	# version 212 (critic fix #2): events from the end of the tutorial (was run 3), so a
	# player who installs because of an event finds it. Version 306 (player panel fix 1):
	# back to run 3; a new player's first titles were an event banner and a splash on top of
	# everything else to learn. (An event installer meets it two short runs later.)
	if e.is_empty() or Game.unlock_stage() < Game.CALM_RUNS:
		_title_event.visible = false
		return
	_title_event.visible = true
	var cfg := Game._load_save()
	var badge := ""
	var sub := ""
	if live:
		var ready := Events.ready_count(cfg, e)
		var n := Events.caskets(cfg, e)
		if ready > 0:
			badge = "CLAIM!"
		elif n > 0:
			badge = "%d %s" % [n, Events.word("casket" if n == 1 else "caskets", e).get_slice(" ", 1).to_upper()]
		elif Events.double_today(e):
			badge = "2X " + Events.word("unit", e).to_upper()
		sub = "%s  ·  ends in %s" % [str(Events.chapter_info(e).name), Events.time_text(Events.seconds_left(e))]
	else:
		badge = "SOON"
		sub = "Event begins in %s" % Events.time_text(Events.seconds_left(e))
	_title_event.set_info(str(e.name), sub, badge, live and Events.eclipse(e))


func show_event(v: bool) -> void:
	if v:
		Sfx.play("click")
		_event.open_event(Game._load_save())
	else:
		_event.visible = false


func event_visible() -> bool:
	return _event.visible


## Version 135: the big splash when an event, or a new chapter of it, begins.
func show_event_splash(kicker: String, title: String, line: String, story: String, clock: String, eclipse: bool) -> void:
	_splash.play(kicker, title, line, story, clock, eclipse)


func splash_visible() -> bool:
	return _splash.visible


func hide_event_splash() -> void:
	_splash.visible = false


## Android back on the event screen: the road page first, then the screen.
func event_back() -> void:
	_event.back()


## After a claim or a casket: the event screen and the title banner again.
func refresh_event() -> void:
	if _event.visible:
		_event.refresh(Game._load_save())
	refresh_event_banner()


## Moon Caskets on the Bone Drop screen (drop_screen.gd in casket mode).
func open_caskets(n: int, opener: Callable) -> void:
	_drops.opener = opener
	_drops.open_screen(n, true)


## Moon Shards this run on the HUD (-1 hides them: not an event run).
func set_shards(n: int) -> void:
	_shard_box.visible = n >= 0
	if n < 0:
		return
	var was := _shard_label.text
	_shard_label.text = Hud.thousands(n)
	if was != _shard_label.text and n > 0:
		_shard_pop = 1.0


## The Moon Surge on screen: `k` (0-1) how strong, `warn` the pulse before one starts, and
## `eclipse` the Queen's Eclipse darkening the screen instead.
func set_surge(k: float, warn: bool, eclipse := false) -> void:
	if eclipse:
		_eclipse_dim.color.a = 0.12 * k   # v217: was 0.5 (with k up to 0.7); v219 review: 0.3 -> 0.12
		_eclipse_dim.visible = _eclipse_dim.color.a > 0.003   # version 384
		return
	_surge_warn = warn
	_surge_edge.set_meta("k", k)


func _event_process(delta: float) -> void:
	if _shard_box.visible:
		_shard_pop = move_toward(_shard_pop, 0.0, delta * 3.0)
		var sc := 1.0 + 0.3 * _shard_pop
		_shard_label.scale = Vector2(sc, sc)
		_shard_icon.queue_redraw()
	var k := float(_surge_edge.get_meta("k", 0.0))
	var want := k * (0.75 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * 7.0))
	if _surge_warn:
		want = maxf(want, 0.35 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 14.0)))
	_surge_edge.modulate.a = want


## Version 413 (re-review of v410, fix 3): the boss bar's badge, a crowned skull on a dark
## disc ringed in the boss's own colour.
class BossBadge extends Control:
	var col := Color(1.0, 0.36, 0.26)

	func _draw() -> void:
		var c := size * 0.5 + Vector2(0, 2)
		var r := minf(size.x, size.y) * 0.5 - 2.0
		draw_circle(c, r, Color(0.06, 0.03, 0.06))
		draw_arc(c, r - 1.5, 0.0, TAU, 40, col, 3.0, true)
		var bone := Color(0.96, 0.92, 0.84)
		var s := r / 22.0
		draw_circle(c + Vector2(0, -1) * s, 11.0 * s, bone)
		draw_rect(Rect2(c + Vector2(-6.5, 5) * s, Vector2(13, 7) * s), bone)
		for sx in [-1.0, 1.0]:
			draw_circle(c + Vector2(sx * 4.4, 0) * s, 3.3 * s, col.darkened(0.55))
			draw_circle(c + Vector2(sx * 4.4, 0) * s, 1.4 * s, col.lightened(0.2))
		for k in 3:
			draw_line(c + Vector2(-3.5 + 3.5 * k, 8) * s, c + Vector2(-3.5 + 3.5 * k, 12) * s, Color(0.06, 0.03, 0.06), 1.5 * s)
		var gold := Color(1.0, 0.8, 0.25)
		var base := c + Vector2(0, -11) * s
		draw_colored_polygon(PackedVector2Array([base + Vector2(-9, 2) * s, base + Vector2(-9, -6) * s, base + Vector2(-4.5, -1) * s,
			base + Vector2(0, -8) * s, base + Vector2(4.5, -1) * s, base + Vector2(9, -6) * s, base + Vector2(9, 2) * s]), gold)
