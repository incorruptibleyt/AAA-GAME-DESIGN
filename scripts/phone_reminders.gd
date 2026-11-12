class_name PhoneReminders
## Version 143 (review change 1): phone reminders that bring players back. Off until the
## player says yes (asked once, after a boss win that isn't the tutorial's, or in Settings).
## At most one a day, in the evening, for the next week:
##   - the Blood Moon begins, a new chapter opens, the last day,
##   - "your N-day Daily streak ends tonight" when today's Daily isn't played yet,
##   - otherwise a gentle "the Daily Crypt is ready" 1, 3 and 7 days after the last visit.
## The list is rebuilt every time the game opens or goes to the background, so it always
## counts from the last visit. The Android side lives in android_plugins/PlayUpdate
## (Reminders.java): alarms that post one notification each, put back after a restart.
##
## The class must not be called like an Android plugin (see UpdateGate): "PlayUpdate" is
## taken, this one isn't.

const PLUGIN := "PlayUpdate"
const PERMISSION := "android.permission.POST_NOTIFICATIONS"
const SECTION := "settings"
const KEY := "reminders"
const ASKED := "reminders_asked"
## Local hour for the evening reminder, and for the streak one.
const EVENING := 18
const STREAK_HOUR := 19
## Days after the last visit with a "come back" reminder (when nothing else is on).
const COME_BACK := [1, 3, 7]
const DAYS_AHEAD := 8
## Event news is worth more: it is set up to two weeks ahead.
const EVENT_AHEAD := 14

## The robot's last list, to check and picture.
static var last_list: Array = []


static func _plugin() -> Object:
	return Engine.get_singleton(PLUGIN) if Engine.has_singleton(PLUGIN) else null


static func on(cfg: ConfigFile) -> bool:
	return bool(cfg.get_value(SECTION, KEY, false))


static func asked(cfg: ConfigFile) -> bool:
	return cfg.has_section_key(SECTION, KEY) or bool(cfg.get_value(SECTION, ASKED, false))


## The player said yes: ask Android (13 and newer) for permission, then schedule.
static func enable(cfg: ConfigFile) -> void:
	cfg.set_value(SECTION, KEY, true)
	cfg.set_value(SECTION, ASKED, true)
	if OS.get_name() == "Android":
		# true when already allowed (or Android 12 and older, which needs no asking).
		OS.request_permission(PERMISSION)


static func disable(cfg: ConfigFile) -> void:
	cfg.set_value(SECTION, KEY, false)
	cfg.set_value(SECTION, ASKED, true)
	var p := _plugin()
	if p:
		p.remindersClear()
	last_list = []


## Rebuilds the phone's reminder list from the save (on launch and when the game leaves the
## screen). Does nothing off Android except remember the list for the robot.
static func refresh(cfg: ConfigFile) -> void:
	if not on(cfg):
		return
	last_list = build(cfg, int(Time.get_unix_time_from_system()))
	var p := _plugin()
	if p:
		p.remindersSchedule(JSON.stringify(last_list))


## The local-time offset in seconds (Central time = -21600).
static func _bias() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


## Unix time of `hour`:00 local on the local day `days` after the one holding `now`.
static func _local_at(now: int, days: int, hour: int) -> int:
	var b := _bias()
	var local_midnight := int(floor(float(now + b) / 86400.0)) * 86400
	return local_midnight + days * 86400 + hour * 3600 - b


## The local day index (days since 1970, local) of unix time `t`.
static func _local_day(t: int) -> int:
	return int(floor(float(t + _bias()) / 86400.0))


## A reminder time for something that starts at unix `t`: an hour after it, moved into
## 10:00-21:00 local so nobody is buzzed at night.
static func _awake(t: int) -> int:
	var at := t + 3600
	var local_hour := int(posmod(at + _bias(), 86400) / 3600)
	if local_hour < 10:
		return _local_at(at, 0, 10)
	if local_hour >= 21:
		return _local_at(at, 1, 10)
	return at


## The list: [{id, at, title, text}], at most one a local day, all in the future.
static func build(cfg: ConfigFile, now: int) -> Array:
	var by_day := {}   # local day index -> reminder
	# 1. The event calendar (the strongest reason to come back).
	for e: Dictionary in Events.LIST:
		var start := Events._unix(e.start) + Curses.DAY_START_HOURS * 3600
		var notes := [[1, "The %s has risen!" % e.name.capitalize(), "A new event crypt is open for %d days. The Queen wakes tonight." % int(e.days)]]
		for i in range(1, e.chapters.size()):
			var c: Dictionary = e.chapters[i]
			notes.append([int(c.day), "%s: chapter %d, %s" % [e.name.capitalize(), i + 1, c.name.capitalize()], str(c.text)])
		notes.append([int(e.days), "Last day of the %s" % e.name.capitalize(), "Spend your Moon Shards and claim the road before the moon sets."])
		for n: Array in notes:
			var at := _awake(start + (int(n[0]) - 1) * 86400)
			if at > now + 600 and at < now + EVENT_AHEAD * 86400:
				by_day[_local_day(at)] = {"at": at, "title": n[1], "text": n[2]}
	# 2. A Daily streak that ends tonight.
	var streak := Curses.streak(cfg)
	if streak >= 2 and not Curses.official_used(cfg):
		var at := _local_at(now, 0, STREAK_HOUR)
		# The Daily day ends at 07:00 UTC; only while today's can still be played.
		var day_end := Curses._unix(Curses.today()) + (24 + Curses.DAY_START_HOURS) * 3600
		if at > now + 600 and at < day_end - 1800 and not by_day.has(_local_day(at)):
			by_day[_local_day(at)] = {"at": at, "title": "Your %d-day streak ends tonight" % streak,
				"text": "Play today's Daily Crypt to keep it going."}
	# 3. Come back: 1, 3 and 7 days after this visit, when nothing else is on that day.
	var come := [
		["Today's Daily Crypt is ready", "New curses, one crypt for everyone. How deep can you go?"],
		["The crypt is waiting", "Your hero misses the skeletons. A quick run fits any break."],
		["The skeletons are back", "A new week of Daily Crypts is open. Come break the chain."],
	]
	for i in COME_BACK.size():
		var at := _local_at(now, int(COME_BACK[i]), EVENING)
		var d := _local_day(at)
		if not by_day.has(d):
			by_day[d] = {"at": at, "title": come[i][0], "text": come[i][1]}
	var days := by_day.keys()
	days.sort()
	var out := []
	for d in days:
		var r: Dictionary = by_day[d]
		if int(r.at) <= now:
			continue
		r["id"] = out.size() + 1
		out.append(r)
		if out.size() >= 12:
			break
	return out


## For the robot: the list as lines with local dates.
static func describe(list: Array) -> String:
	var lines := []
	for r: Dictionary in list:
		lines.append("%s  %s: %s" % [Time.get_datetime_string_from_unix_time(int(r.at) + _bias(), true), r.title, r.text])
	return "\n".join(lines)
