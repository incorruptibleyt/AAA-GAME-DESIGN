class_name TrustClock
extends Node
## Version 212 (critic fix #9): the event's days come from Google's clock when the phone is
## online, not only from the phone's own clock, which anyone can move.
##
## - On each launch it asks Google for the time (the "Date" of an empty reply, no data sent)
##   and keeps the difference to the phone's clock in the save.
## - Offline, the days never go back past the latest one this phone has seen, so stepping the
##   date forward and back can't pay an event's daily prizes twice.
## - An event is only wrapped up (its prizes paid out, Events.settle) on Google's word, or a
##   good while after its end, so moving the clock past the end doesn't close it early.
## - Version 213 (hardest review fix #1): once Google answered, time is counted from Google's
##   answer on the game's own stopwatch (which the phone's date setting can't move), the day
##   never goes back past the latest one seen, and the check runs again on every return to
##   the game (the stopwatch can stop while the phone sleeps).

const SECTION := "clock"
const URL := "https://www.google.com/generate_204"
## Without Google's word, an ended event is wrapped up this many days after its end.
const SETTLE_OFFLINE_DAYS := 14

## Seconds to add to the phone's clock (Google's time minus the phone's).
static var offset := 0
## True once Google answered since the game last came back to the front.
static var confirmed := false
## Google's time (unix seconds) and the stopwatch (Time.get_ticks_msec) when it answered.
static var _sync_unix := 0
static var _sync_ticks := 0
## The latest event day (unix seconds of its start) seen on this phone.
static var latest_day := 0

signal synced

var _http: HTTPRequest


## The time to count days by: the phone's clock, put right by Google's when known.
static func now() -> int:
	if confirmed:
		return _sync_unix + int((Time.get_ticks_msec() - _sync_ticks) / 1000)
	return int(Time.get_unix_time_from_system()) + offset


## A day's start (unix seconds) as Curses works it out, never before the latest one seen.
## (Google's answer resets the latest day to the true one, see _on_done.)
static func guard_day(day_start: int) -> int:
	return maxi(day_start, latest_day)


## Called by Game.write_save: remembers the latest day seen, and the offset.
static func note(cfg: ConfigFile, today_start: int) -> void:
	if today_start > latest_day:
		latest_day = today_start
	cfg.set_value(SECTION, "latest_day", latest_day)
	cfg.set_value(SECTION, "offset", offset)


func _ready() -> void:
	var cfg := Game._load_save()
	offset = int(cfg.get_value(SECTION, "offset", 0))
	latest_day = int(cfg.get_value(SECTION, "latest_day", 0))
	if OS.has_feature("editor") and not "clocksync" in OS.get_cmdline_user_args():
		return
	if DisplayServer.get_name() == "headless" and not "clocksync" in OS.get_cmdline_user_args():
		return   # the robot keeps the phone's clock
	_http = HTTPRequest.new()
	_http.timeout = 8.0
	add_child(_http)
	_http.request_completed.connect(_on_done)
	ask()


## Asks Google for the time again. Called on launch and each time the game comes back.
func ask() -> void:
	if _http == null:
		return
	# Until Google answers, the phone's clock (with Google's last offset and the latest-day
	# guard) is used, because the stopwatch may have stopped while the phone slept.
	# (Version 216, review 2 fix #2: the offset is no longer re-measured from the stopwatch here;
	# after a long sleep that put the game hours behind.)
	confirmed = false
	_http.cancel_request()
	if _http.request(URL, [], HTTPClient.METHOD_HEAD) != OK:
		print("[clock] couldn't ask for the time")


func _on_done(result: int, _code: int, headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[clock] offline, using the phone's clock (offset %d s)" % offset)
		return
	var t := -1
	for h in headers:
		if h.to_lower().begins_with("date:"):
			t = parse_http_date(h.substr(5).strip_edges())
	if t <= 0:
		return
	var was := offset
	offset = t - int(Time.get_unix_time_from_system())
	if absi(offset) < 120:
		offset = 0   # a phone a minute out is fine; only a moved clock counts
	_sync_unix = t
	_sync_ticks = Time.get_ticks_msec()
	confirmed = true
	# Google's word replaces whatever latest day a moved clock left behind.
	latest_day = Curses.day_start_now()
	var cfg := Game._load_save()
	Game.write_save(cfg)
	print("[clock] Google's time: phone is %d s off (was %d)" % [offset, was])
	synced.emit()


## "Thu, 19 Nov 2026 06:10:00 GMT" -> unix seconds, or -1.
static func parse_http_date(s: String) -> int:
	var p := s.split(" ", false)
	if p.size() < 5:
		return -1
	var months := ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
	var m := months.find(p[2].to_lower().left(3))
	if m < 0 or not p[1].is_valid_int() or not p[3].is_valid_int():
		return -1
	var iso := "%04d-%02d-%02dT%s" % [int(p[3]), m + 1, int(p[1]), p[4]]
	var t := Time.get_unix_time_from_datetime_string(iso)
	return t if t > 1600000000 else -1
