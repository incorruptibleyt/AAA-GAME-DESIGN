class_name PlayUpdate
extends CanvasLayer
## Forced updates. At launch the game asks Google Play whether a newer version of Bone
## Chain is out (Google's in-app update library, through addons/PlayUpdate). If one is,
## Google's own full-screen update page opens straight away, and backing out of it leaves
## only this UPDATE screen, so nobody keeps playing an old version. Copies that didn't
## come from Google Play (the test APK, the robot) and phones that can't reach Play
## (offline, say) find no update and play as normal: only a yes from Play blocks the game.

const PLUGIN := "PlayUpdate"
const STORE_URL := "https://play.google.com/store/apps/details?id=com.Bone_Chain_Dungeon_Roguelite.myapp"

static var instance: PlayUpdate

## True once Google Play has said a newer version is out.
var needed := false
var _play: Object
var _box: ColorRect
var _status: Label


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120   # above the HUD (10) and the opening animation (100)
	_build()
	var args := OS.get_cmdline_user_args()
	if "autoplay" in args:
		if "fakeupdate" in args:
			_on_checked.call_deferred(1, "robot test")   # to picture the screen
		return
	if OS.get_name() != "Android" or not Engine.has_singleton(PLUGIN):
		return
	_play = Engine.get_singleton(PLUGIN)
	_play.connect("update_checked", _on_checked)
	_play.connect("update_finished", _on_finished)
	_play.check()


## The UPDATE screen is up: nothing underneath should get touches or the back button.
func showing() -> bool:
	return _box.visible


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
	col.add_child(Hud.label("UPDATE NEEDED", 40, Hud.GOLD))
	col.add_child(Hud.label("A new version of Bone Chain is out.\nUpdate to keep playing.\n\nYour heroes, coins and Crypt Pass are kept.", 21, Color(0.9, 0.88, 0.84)))
	var update := Hud.button("UPDATE", 30, Color(0.2, 0.32, 0.18, 0.97), Color(0.6, 0.95, 0.55))
	update.custom_minimum_size = Vector2(360, 84)
	update.pressed.connect(_update)
	col.add_child(_centered(update))
	var store := Hud.button("OPEN GOOGLE PLAY", 22)
	store.custom_minimum_size = Vector2(360, 70)
	store.pressed.connect(func(): OS.shell_open(STORE_URL))
	col.add_child(_centered(store))
	_status = Hud.label("", 18, Color(0.75, 0.72, 0.68))
	col.add_child(_status)


static func _centered(c: Control) -> Control:
	var box := CenterContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(c)
	return box


## state: 1 = an update is out, 2 = one was started earlier (carry on with it), 0 = none,
## -1 = Play couldn't be asked.
func _on_checked(state: int, detail: String) -> void:
	print("[update] Google Play check: %d (%s)" % [state, detail])
	if state != 1 and state != 2:
		return
	needed = true
	_box.visible = true
	if Game.state == Game.State.PLAYING:
		Game._pause()
	_update()


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
			_status.text = ""   # backed out: this screen stays
		2:
			# Play no longer offers an update (it was withdrawn), so there's nothing to wait for.
			needed = false
			_box.visible = false
		_:
			_status.text = "Google Play's update page didn't open. Tap UPDATE to try again, or update Bone Chain in Google Play."
