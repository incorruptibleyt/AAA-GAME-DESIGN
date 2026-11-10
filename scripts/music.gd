class_name Music
extends Node
## Background music: the game's own soundtrack, one Bone Chain tune played as a spooky music
## box in a different way for each crypt (made by tools/music/score.py, credits in
## audio/music/CREDITS.md). Every track loops. Each crypt track has an in-sync fight layer
## (low strings, cello rhythm, war drums) that swells in while enemies are alive and fades
## out once the room is clear. Changing track cross-fades.

const TRACKS := {
	"title": [preload("res://audio/music/bc_title.ogg")],
	"crypt": [preload("res://audio/music/bc_crypt.ogg"), preload("res://audio/music/bc_crypt_fight.ogg")],
	"ice": [preload("res://audio/music/bc_ice.ogg"), preload("res://audio/music/bc_ice_fight.ogg")],
	"ember": [preload("res://audio/music/bc_ember.ogg"), preload("res://audio/music/bc_ember_fight.ogg")],
	"drowned": [preload("res://audio/music/bc_drowned.ogg"), preload("res://audio/music/bc_drowned_fight.ogg")],
	"grotto": [preload("res://audio/music/bc_grotto.ogg"), preload("res://audio/music/bc_grotto_fight.ogg")],
	"boss": [preload("res://audio/music/bc_boss.ogg")],
	# The Blood Moon event (version 134): its crypt and the title while it's on, and the Queen.
	"moon": [preload("res://audio/music/bc_moon.ogg"), preload("res://audio/music/bc_moon_fight.ogg")],
	"queen": [preload("res://audio/music/bc_queen.ogg")],
}
## One track per floor theme, in the order of Floors.THEMES.
const THEMES := ["crypt", "ice", "ember", "drowned", "grotto", "moon"]
const VOLUME_DB := -6.0
## Seconds of overlap when one track hands over to the next.
const FADE := 1.5
## Seconds for the fight layer to swell in, and to die away after the last kill.
const FIGHT_IN := 1.2
const FIGHT_OUT := 3.5

static var _instance: Music
static var enabled := true

## How far the music is muffled: 0 clear, 1 fully (paused, picking a blessing, dead).
var _muffle := 0.0
## Decibels the music is dipped by after a big hit to the hero; it comes back in about half
## a second.
var _duck := 0.0
## 0 .. 1: how far game sounds are dulled during slow motion (a perfect dodge, a room's
## finishing kill), so the moment feels stretched.
var _slow := 0.0
var _slow_on := false
var _shown_muffle := 0.0
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _current: AudioStream
var _list := ""
## Each track as one stream: a crypt's calm and fight layers play in sync.
var _streams := {}
## 0 .. 1: how loud the fight layer is.
var _fight := 0.0


## "dungeon" plays the current floor's track, "boss" the boss theme, "title" the title theme.
static func play(track: String) -> void:
	if _instance:
		_instance._play_list(track if track in ["boss", "title", "moon", "queen"] else THEMES[Floors.index(Game.floor_num) % THEMES.size()])


static func set_enabled(on: bool) -> void:
	enabled = on
	if _instance:
		for p in [_instance._a, _instance._b]:
			p.stream_paused = not on


func _ready() -> void:
	_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key: String in TRACKS:
		var list: Array = TRACKS[key]
		for s: AudioStreamOggVorbis in list:
			s.loop = true
		if list.size() == 1:
			_streams[key] = list[0]
		else:
			var sync := AudioStreamSynchronized.new()
			sync.stream_count = list.size()
			for i in list.size():
				sync.set_sync_stream(i, list[i])
				sync.set_sync_stream_volume(i, 0.0 if i == 0 else -60.0)
			_streams[key] = sync
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	Sfx.make_buses()
	for p in [_a, _b]:
		p.volume_db = -60.0
		p.bus = &"Music"
		add_child(p)


func _play_list(list: String) -> void:
	if list == _list:
		return
	_list = list
	_fight = 0.0
	_switch(_streams[list])


func _process(delta: float) -> void:
	_update_muffle(delta)
	_update_fight(delta)


## The fight layer follows the room: in while enemies are alive, out once it is clear.
func _update_fight(delta: float) -> void:
	var sync := _current as AudioStreamSynchronized
	if sync == null:
		return
	var want := 1.0 if Game.state == Game.State.PLAYING and Game.alive_enemies > 0 else 0.0
	if is_equal_approx(_fight, want) and sync.get_sync_stream_volume(1) == (0.0 if want > 0.5 else -60.0):
		return
	_fight = move_toward(_fight, want, delta / (FIGHT_IN if want > _fight else FIGHT_OUT))
	# An eased curve in decibels, so the swell sounds even rather than jumping at the end.
	sync.set_sync_stream_volume(1, -60.0 if _fight <= 0.0 else linear_to_db(_fight * _fight))


## Paused, picking a blessing or dead: the music sounds as if heard through a wall, and
## clears again when play goes on. The filter is switched off when not in use.
func _update_muffle(delta: float) -> void:
	# Slow motion is the game's time running at 0.1 to 0.6. The tiny freeze on each kill
	# runs at 0.05 and is too short to hear, so it doesn't count.
	var real := delta / maxf(Engine.time_scale, 0.01)
	var slow_want := 1.0 if Game.state == Game.State.PLAYING and Engine.time_scale >= 0.1 and Engine.time_scale < 0.6 else 0.0
	_slow = move_toward(_slow, slow_want, real * (6.0 if slow_want > _slow else 2.5))
	if _slow > 0.0 or _slow_on:
		_slow_on = _slow > 0.0
		var fx := AudioServer.get_bus_index(&"Effects")
		if fx != -1 and AudioServer.get_bus_effect_count(fx) > 1:
			var dull := AudioServer.get_bus_effect(fx, 1) as AudioEffectLowPassFilter
			dull.cutoff_hz = 20000.0 * pow(1400.0 / 20000.0, _slow)   # 20 kHz down to 1.4 kHz
			AudioServer.set_bus_effect_enabled(fx, 1, _slow_on)
	var want := 1.0 if Game.state in [Game.State.PAUSED, Game.State.UPGRADE, Game.State.DEAD] else 0.0
	if is_equal_approx(_muffle, want) and _duck <= 0.0 and not _slow_on and _shown_muffle <= 0.0:
		return
	_muffle = move_toward(_muffle, want, delta * (3.0 if want > _muffle else 1.5))
	_duck = move_toward(_duck, 0.0, delta * 12.0)
	var bus := AudioServer.get_bus_index(&"Music")
	if bus == -1:
		return
	# Slow motion muffles the music halfway too.
	_shown_muffle = maxf(_muffle, _slow * 0.5)
	var low := AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
	low.cutoff_hz = 20000.0 * pow(700.0 / 20000.0, _shown_muffle)   # 20 kHz down to 700 Hz
	AudioServer.set_bus_effect_enabled(bus, 0, _shown_muffle > 0.001)
	AudioServer.set_bus_volume_db(bus, -3.0 * _muffle - _duck)
	if _shown_muffle <= 0.001:
		_shown_muffle = 0.0


## A big hit to the hero: the music dips for a moment so the hit lands.
static func duck(db: float) -> void:
	if _instance:
		_instance._duck = maxf(_instance._duck, db)


func _switch(stream: AudioStream) -> void:
	if stream == _current:
		return
	_current = stream
	# Fade the old track out on one player while the new one fades in on the other.
	var old := _a
	_a = _b
	_b = old
	_a.stream = stream
	_a.play()
	_a.stream_paused = not enabled
	var tw := create_tween().set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_a, "volume_db", VOLUME_DB, FADE).from(-40.0)
	tw.tween_property(_b, "volume_db", -60.0, FADE)
	tw.chain().tween_callback(_b.stop)
