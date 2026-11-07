class_name UpdateGate
extends CanvasLayer
## Updates. At launch the game asks Google Play whether a newer version of Bone Chain is
## out (Google's in-app update library, through addons/PlayUpdate). If one is, the title
## screen first offers it (UPDATE or LATER) for GRACE_DAYS days; after that, Google's own
## full-screen update page opens straight away and backing out of it leaves only this
## UPDATE NEEDED screen, so nobody keeps playing a version that is days old. The days count
## from when this phone first heard of an update (Play's own count, or the game's, whichever
## is longer). Copies that didn't come from Google Play (the test APK, the robot) and phones
## that can't reach Play (offline, say) find no update and play as normal.
##
## The class must not be called PlayUpdate: on Android the Java plugin registers an engine
## singleton with that name, GDScript looks engine singletons up before script classes, and
## PlayUpdate.new() then quietly gave null ("rp_child is null" at every launch, versions 66-70),
## so the check never ran. Never give a class_name the name of an Android plugin.

const PLUGIN := "PlayUpdate"
const STORE_URL := "https://play.google.com/store/apps/details?id=com.Bone_Chain_Dungeon_Roguelite.myapp"

## How many days an update can be put off with LATER before it must be done.
const GRACE_DAYS := 3
const SAVE_SECTION := "update"

static var instance: UpdateGate

## True once an update must be done (GRACE_DAYS have passed): the game can't be played.
var needed := false
## An update is out but can still wait: offered once on the title screen.
var _soft_waiting := false
var _days_left := GRACE_DAYS
var _play: Object
var _box: ColorRect
var _heading: Label
var _text: Label
var _later: Button
var _store: Button
var _status: Label


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120   # above the HUD (10) and the opening animation (100)
	_build()
	var args := OS.get_cmdline_user_args()
	if "autoplay" in args:
		if "fakeupdate" in args:
			_on_checked.call_deferred(1, "robot test", 0, GRACE_DAYS)   # to picture the screen
		elif "fakesoftupdate" in args:
			_on_checked.call_deferred(1, "robot test", 0, 0)
		return
	if OS.get_name() != "Android" or not Engine.has_singleton(PLUGIN):
		return
	_play = Engine.get_singleton(PLUGIN)
	_play.connect("update_checked", _on_checked)
	_play.connect("update_finished", _on_finished)
	_play.check()


## The UPDATE screen is up: nothing underneath should get touches.
func showing() -> bool:
	return _box.visible


## The update can't wait any more: Android's back button leaves the game instead of LATER.
func forced() -> bool:
	return needed


## LATER (or Android's back button on the offer): play on for now.
func later() -> void:
	if needed:
		return
	_box.visible = false


func _build() -> void:
	_box = Hud.overlay(Color(0.02, 0.01, 0.03, 1.0))
	add_child(_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 30
	col.offset_right = -30
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	_box.add_child(col)
	_heading = Hud.label("UPDATE NEEDED", 40, Hud.GOLD)
	col.add_child(_heading)
	_text = Hud.label("", 21, Color(0.9, 0.88, 0.84))
	col.add_child(_text)
	var update := Hud.button("UPDATE", 30, Color(0.2, 0.32, 0.18, 0.97), Color(0.6, 0.95, 0.55))
	update.custom_minimum_size = Vector2(360, 84)
	update.pressed.connect(_update)
	col.add_child(_centered(update))
	_later = Hud.button("LATER", 22)
	_later.custom_minimum_size = Vector2(360, 70)
	_later.pressed.connect(later)
	col.add_child(_centered(_later))
	_store = Hud.button("OPEN GOOGLE PLAY", 22)
	_store.custom_minimum_size = Vector2(360, 70)
	_store.pressed.connect(func(): OS.shell_open(STORE_URL))
	col.add_child(_centered(_store))
	_status = Hud.label("", 18, Color(0.75, 0.72, 0.68))
	col.add_child(_status)


## The screen as an offer (UPDATE or LATER) or as a must (UPDATE or OPEN GOOGLE PLAY).
func _show(must: bool) -> void:
	_heading.text = "UPDATE NEEDED" if must else "UPDATE READY"
	if must:
		_text.text = "A new version of Bone Chain is out.\nUpdate to keep playing.\n\nYour heroes, coins and Crypt Pass are kept."
	else:
		_text.text = "A new version of Bone Chain is out.\nUpdate now, or play on for %s.\n\nYour heroes, coins and Crypt Pass are kept." \
			% ("today" if _days_left <= 1 else "%d more days" % _days_left)
	_later.visible = not must
	_store.visible = must
	_status.text = ""
	_box.visible = true


static func _centered(c: Control) -> Control:
	var box := CenterContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(c)
	return box


## state: 1 = an update is out, 2 = one was started earlier (carry on with it), 0 = none,
## -1 = Play couldn't be asked. `version`: the update's version code. `stale`: how many days
## ago Play on this phone learned of it (-1 when Play doesn't say).
func _on_checked(state: int, detail: String, version := 0, stale := -1) -> void:
	print("[update] Google Play check: %d (%s, version %d, %d days)" % [state, detail, version, stale])
	if state != 1 and state != 2:
		return
	var days := maxi(stale, _days_known())
	_days_left = GRACE_DAYS - days
	if state == 2 or days >= GRACE_DAYS:
		needed = true
		_soft_waiting = false
		_show(true)
		if Game.state == Game.State.PLAYING:
			Game._pause()
		_update()
	else:
		_soft_waiting = true   # offered on the title screen, once the opening has played


## Days since this installed version first heard that an update is out. Saved, because Play
## doesn't always say, and it starts again for each version the player installs.
func _days_known() -> int:
	var cfg := Game._load_save()
	var now := int(Time.get_unix_time_from_system())
	if str(cfg.get_value(SAVE_SECTION, "build", "")) != Game.BUILD:
		cfg.set_value(SAVE_SECTION, "build", Game.BUILD)
		cfg.set_value(SAVE_SECTION, "since", now)
		Game.write_save(cfg)
	return maxi(0, (now - int(cfg.get_value(SAVE_SECTION, "since", now))) / 86400)


func _process(_delta: float) -> void:
	# The offer waits for the title screen: not over the opening, the loading or a run.
	if _soft_waiting and Game.state == Game.State.TITLE and Game.hud and Game.hud.title_visible() \
			and not is_instance_valid(Game.intro):
		_soft_waiting = false
		_show(false)


func _update() -> void:
	_status.text = ""
	if _play:
		_play.start()


## What came back from Google's update page.
func _on_finished(result: int) -> void:
	print("[update] Google Play update page: %d" % result)
	match result:
		-1:
			_status.text = "Updating..."   # Play installs it and restarts the game
		0:
			_status.text = ""   # backed out: this screen stays (with LATER, if it can still wait)
		2:
			# Play no longer offers an update (it was withdrawn), so there's nothing to wait for.
			needed = false
			_box.visible = false
		_:
			_status.text = "Google Play's update page didn't open. Tap UPDATE to try again, or update Bone Chain in Google Play."
