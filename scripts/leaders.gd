class_name Leaders
extends Node
## Leaderboards through Google Play Games (version 137; the Android side is
## addons/PlayGames, built from android_plugins/PlayGames). Two boards:
##  - DAILY: today's Daily Crypt official run (shown for today: Play Games' daily board).
##  - BEST: the best score of a normal run (shown for this week, so there's always a fresh race).
## Each has an Everyone and a Friends tab (friends are the player's Play Games friends).
##
## Play Games signs the player in by itself at launch when it can. Scores made while signed
## out wait (the best one per board, in the save) and go up once signed in.
##
## The class must not be called PlayGames: that's the Android plugin's engine singleton name
## (see the note in play_update.gd).

const PLUGIN := "PlayGames"

## The IDs from Play Console (Play Games Services → Leaderboards). Empty until set up; the
## leaderboard buttons stay hidden until then. (The project ID is in
## android_plugins/PlayGames/app_id.txt.)
const DAILY := "CgkI4tupibsDEAIQAQ"   # Daily Crypt (made first)
const BEST := "CgkI4tupibsDEAIQAg"    # Best Run

const SPAN_DAILY := 0
const SPAN_WEEKLY := 1
const SPAN_ALL := 2
const EVERYONE := 0
const FRIENDS := 3

const SAVE_SECTION := "leaders"

signal changed                                   # signed in or out
signal scores(tag: String, list: Array, error: String)
signal friends(state: int)

static var instance: Leaders

var signed_in := false
var player_name := ""
var _pg: Object
## Robot pictures: pretend to be signed in with made-up scores ("fakeboard").
var fake := false


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if "fakeboard" in args:
		fake = true
		signed_in = true
		player_name = "CryptRunner"
		return
	if OS.get_name() != "Android" or not Engine.has_singleton(PLUGIN) or DAILY == "":
		return
	_pg = Engine.get_singleton(PLUGIN)
	_pg.connect("signed_in", _on_signed_in)
	_pg.connect("scores_loaded", func(tag: String, json: String, error: String):
		var list = JSON.parse_string(json)
		scores.emit(tag, list if list is Array else [], error))
	_pg.connect("friends_access", func(state: int): friends.emit(state))
	if _pg.is_ready():
		_pg.check()


## True when leaderboards can be shown at all (set up, and on a phone with Play Games).
static func available() -> bool:
	return instance != null and (instance.fake or instance._pg != null)


static func board_for(key: String) -> String:
	return DAILY if key == "daily" else BEST


func _on_signed_in(ok: int, name: String, detail: String) -> void:
	signed_in = ok == 1
	player_name = name
	print("[leaders] signed in: %d %s (%s)" % [ok, name, detail])
	if signed_in:
		_send_waiting()
	changed.emit()


func sign_in() -> void:
	if _pg:
		_pg.sign_in()


## Sends `score` to the board ("daily" or "best"). Kept in the save until it's sent.
func submit(key: String, score: int) -> void:
	var board := board_for(key)
	if score <= 0 or board == "" or fake:
		return
	var cfg := Game._load_save()
	var waiting := int(cfg.get_value(SAVE_SECTION, key, 0))
	if signed_in and _pg:
		_pg.submit(board, score)
		if waiting > 0:
			cfg.set_value(SAVE_SECTION, key, 0)
			Game.write_save(cfg)
	elif score > waiting:
		cfg.set_value(SAVE_SECTION, key, score)
		Game.write_save(cfg)


func _send_waiting() -> void:
	var cfg := Game._load_save()
	var sent := false
	for key in ["daily", "best"]:
		var s := int(cfg.get_value(SAVE_SECTION, key, 0))
		if s > 0 and board_for(key) != "":
			_pg.submit(board_for(key), s)
			cfg.set_value(SAVE_SECTION, key, 0)
			sent = true
	if sent:
		Game.write_save(cfg)


## Loads scores; they arrive as scores(tag, list, error). list: [{rank, name, score, me}].
func load_scores(tag: String, key: String, span: int, collection: int, centered := false, count := 10) -> void:
	if fake:
		_fake_scores.call_deferred(tag, collection, centered)
		return
	if _pg:
		_pg.load(tag, board_for(key), span, collection, centered, count)
	else:
		scores.emit.call_deferred(tag, [], "not ready")


func ask_friends() -> void:
	if fake:
		friends.emit.call_deferred(1)
	elif _pg:
		_pg.ask_friends()


func show_board(key: String, span: int, collection: int) -> void:
	if _pg:
		_pg.show_board(board_for(key), span, collection)


func _fake_scores(tag: String, collection: int, centered: bool) -> void:
	var names := ["NightOwl", "Bjorn_Main", "CryptQueen", "Skelly42", "Wren4Ever", "DashDancer",
			"Mira", "BoneCollector", "ZedTheDead", "Pip"]
	var list := []
	if centered:
		list.append({"rank": 23, "name": "CryptRunner", "score": 4180, "me": true})
	else:
		var n := 4 if collection == FRIENDS else 10
		for i in n:
			list.append({"rank": i + 1, "name": names[i], "score": 12800 - i * 870 - (i * i * 37), "me": false})
	scores.emit(tag, list, "")
