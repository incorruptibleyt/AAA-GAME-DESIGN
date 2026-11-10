class_name Music
extends Node
## Background music: orchestral CC0 tracks (credits in audio/music/CREDITS.md), two for
## each floor theme played one after the other, and a looping boss theme. Changing track
## cross-fades. To add a track, drop the .ogg in audio/music and add it to PLAYLISTS.

const PLAYLISTS := {
	"crypt": [preload("res://audio/music/crypt_lament_of_the_war.ogg"), preload("res://audio/music/crypt_evil_approach.ogg")],
	"ice": [preload("res://audio/music/ice_fantasy_choir.ogg"), preload("res://audio/music/ice_siberian_intro.ogg")],
	"ember": [preload("res://audio/music/ember_determined_pursuit.ogg"), preload("res://audio/music/ember_prepare_to_fight.ogg")],
	"grotto": [preload("res://audio/music/grotto_unexplored.ogg"), preload("res://audio/music/grotto_col_legno.ogg")],
	"boss": [preload("res://audio/music/boss_epic_boss_battle.ogg")],
}
## One playlist per floor theme, in the order of Floors.THEMES (the Drowned Vault borrows
## the choir, which sounds like it is under water).
const THEMES := ["crypt", "ice", "ember", "ice", "grotto"]
const VOLUME_DB := -6.0
## Seconds of overlap when one track hands over to the next.
const FADE := 1.5

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
## Where each playlist got to, so coming back to a theme plays its next track.
var _next := {}


## "dungeon" plays the current floor's theme; "boss" the boss theme.
static func play(track: String) -> void:
	if _instance:
		_instance._play_list("boss" if track == "boss" else THEMES[Floors.index(Game.floor_num)])


static func set_enabled(on: bool) -> void:
	enabled = on
	if _instance:
		for p in [_instance._a, _instance._b]:
			p.stream_paused = not on


func _ready() -> void:
	_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	for list: Array in PLAYLISTS.values():
		for s: AudioStreamOggVorbis in list:
			s.loop = list.size() == 1   # a lone track loops; playlists move on instead
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
	_switch(_take_next())


func _take_next() -> AudioStream:
	var tracks: Array = PLAYLISTS[_list]
	var i: int = _next.get(_list, 0) % tracks.size()
	_next[_list] = i + 1
	return tracks[i]


func _process(delta: float) -> void:
	_update_muffle(delta)
	# Near the end of a playlist track, cross-fade into the next one.
	if _current == null or _current.get("loop") or not _a.playing or _a.stream_paused:
		return
	if _a.get_playback_position() > _current.get_length() - FADE:
		_current = null
		_switch(_take_next())


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
