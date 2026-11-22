class_name Store
extends Node
## The Crypt Pass: one purchase through Google Play that unlocks floors past FREE_FLOORS,
## the Daily Crypt, Curses and every hero.
##
## Purchases go through the GodotGooglePlayBilling Android plugin, which is only in the
## Play build (the .aab). Elsewhere (the test .apk, the editor) the Pass can't be bought;
## in the editor `buy()` just grants it so the screens can be tested.
## Owning it is saved in save.cfg so it works offline, and checked with Google Play at
## every launch and whenever the game comes back from the background, which also restores
## it after reinstalling or on a new phone.
##
## The product must exist in Play Console as a one-time product with this ID.

signal changed   # owned, price or status changed

const PASS_ID := "crypt_pass"
const FREE_FLOORS := 5
## Shown on the buy button where the Pass can't be bought from Google Play (test builds).
const FALLBACK_PRICE := "$4.99"
## How long "Connecting..." or "Checking..." may wait for Google Play before saying so.
const PLAY_TIMEOUT := 10.0
const SAVE_SECTION := "pass"
const CONNECTING := "Connecting to Google Play..."
const CHECKING := "Checking with Google Play..."
const PENDING_TEXT := "Your payment is pending. The Pass unlocks as soon as it goes through."
const PLUGIN := "GodotGooglePlayBilling"

# Google Play Billing values (see the plugin's BillingClient.gd).
const OK := 0
const USER_CANCELED := 1
const ITEM_ALREADY_OWNED := 7
const PURCHASED := 1
const PENDING := 2

static var instance: Store
## Set by the test robot (`-- autoplay pass`) to play as if the Pass were owned.
static var test_owned := false
static var _owned_cache := -1   # -1 = not read yet, 0 = no, 1 = owned
## Version 212 (critic fix #1): Google Play can answer "no purchases" by mistake (two
## accounts on one phone, a Play cache that hasn't caught up). The Pass is only taken away
## after MISS_CHECKS such answers spread over at least MISS_HOURS, with no "owned" answer
## in between, which is what a refund looks like.
const MISS_CHECKS := 3
const MISS_HOURS := 72

## The price in the player's own currency ("$4.99"), once Google Play has sent it.
var price := ""
## A short line for the Pass screen: what's happening, or what went wrong.
var status := ""
## Version 279: the Early Access Deal, a discounted offer running on the Pass in Play
## Console: {pct, price, full, end_ms, option, offer}, empty when none runs. Everything in it
## comes from Google Play (the percent, both prices, the end time), so the game never shows
## a sale that isn't on. Read it with deal_now().
var deal := {}
## Set by the menu lab to picture the deal screens (no Google Play there).
static var test_deal := {}

var _play: Object   # the plugin's JNI singleton, only in the Play build
var _have_details := false
var _buy_when_ready := false
var _last_check := -100000
var _connecting := false
var _restoring := false
var _wait_token := 0
var _details_at := -10000000   # (ticks of the last price answer: asked again after an hour)


static func owned(cfg: ConfigFile = null) -> bool:
	if test_owned:
		return true
	if cfg != null:
		return bool(cfg.get_value(SAVE_SECTION, "owned", false))
	# Version 212 (critic fix #7): remembered, so a kill during an event doesn't read the
	# save file from the phone's storage. Game.write_save keeps it up to date.
	if _owned_cache < 0:
		_owned_cache = 1 if bool(Game._load_save().get_value(SAVE_SECTION, "owned", false)) else 0
	return _owned_cache == 1


## Called by Game.write_save after every save, so owned() never goes stale.
static func note_saved(cfg: ConfigFile) -> void:
	_owned_cache = 1 if bool(cfg.get_value(SAVE_SECTION, "owned", false)) else 0


## True when this copy of the game can buy things (installed from Google Play).
static func can_buy() -> bool:
	return Engine.has_singleton(PLUGIN)


## Version 279: the Early Access Deal while it runs and the Pass isn't owned, else {}.
static func deal_now() -> Dictionary:
	if instance == null or owned():
		return {}
	var d: Dictionary = instance.deal if instance._play != null else test_deal
	if d.is_empty():
		return {}
	var end := int(d.get("end_ms", 0))
	if end > 0 and Time.get_unix_time_from_system() * 1000.0 >= float(end):
		return {}
	return d


## How long the deal has left: "13 days", "1 day 4 h", "5 h 07 min", "12 min 03 s"
## ("" when Play gave it no end).
static func deal_left(d: Dictionary) -> String:
	var end := int(d.get("end_ms", 0))
	if end <= 0:
		return ""
	var s := maxi(0, int((float(end) - Time.get_unix_time_from_system() * 1000.0) / 1000.0))
	var days := s / 86400
	var h := (s % 86400) / 3600
	var m := (s % 3600) / 60
	if days >= 2:
		return "%d days" % days if days >= 7 else "%d days %d h" % [days, h]
	if days == 1:
		return "1 day %d h" % h
	if h >= 1:
		return "%d h %02d min" % [h, m]
	return "%d min %02d s" % [m, s % 60]


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not can_buy() or "autoplay" in OS.get_cmdline_user_args():
		return
	_play = Engine.get_singleton(PLUGIN)
	_play.initPlugin()
	_play.connect("connected", _on_connected)
	_play.connect("disconnected", func():
		_have_details = false
		_connecting = false)
	_play.connect("connect_error", _on_connect_error)
	_play.connect("query_product_details_response", _on_details)
	_play.connect("query_purchases_response", _on_owned_list)
	_play.connect("on_purchase_updated", _on_purchase_updated)
	_play.connect("acknowledge_purchase_response", _on_acknowledged)
	_last_check = Time.get_ticks_msec()
	_connect()


## Starts connecting to Google Play, unless that's already under way (a second
## startConnection while the first is running fails with an error).
func _connect() -> void:
	if not _connecting:
		_connecting = true
		_play.startConnection()


## Called when the Pass screen opens: fetch the price if we don't have it yet.
func refresh() -> void:
	if _play == null:
		return
	if not _play.isReady():
		_connect()
	elif not _have_details or Time.get_ticks_msec() - _details_at > 3600000:
		# (asked again after an hour, so a deal that starts or ends while the game runs shows)
		_play.queryProductDetails(PackedStringArray([PASS_ID]), "inapp")


func buy() -> void:
	if owned():
		return
	Telemetry.step("pass_buy_tap")   # v218: how many who tap BUY go on to own it
	if _play == null:
		if OS.has_feature("template"):
			_set_status("Install Bone Chain from Google Play to get the Crypt Pass.")
		else:
			print("[store] editor test purchase")
			_grant()
		return
	if not _play.isReady() or not _have_details:
		_buy_when_ready = true
		_wait_for_play(CONNECTING)
		refresh()
		return
	_buy_when_ready = false
	_set_status("")
	# Version 279: during the Early Access Deal, its own offer (at its price).
	var d := deal_now()
	var r: Dictionary = _play.purchase(PASS_ID, str(d.get("option", "")), str(d.get("offer", "")), false)
	if int(r.get("response_code", OK)) != OK and not d.is_empty():
		print("[store] deal offer wouldn't start (%s), buying at the full price" % r.get("debug_message", ""))
		r = _play.purchase(PASS_ID, "", "", false)
	if int(r.get("response_code", OK)) != OK:
		_set_status("Google Play couldn't start the purchase. Try again in a moment.")


## Asks Google Play again what this account owns.
func restore() -> void:
	if _play == null:
		_set_status("Install Bone Chain from Google Play to restore the Crypt Pass.")
		return
	_restoring = true
	_wait_for_play(CHECKING)
	if _play.isReady():
		_play.queryPurchases("inapp", false)
	else:
		_connect()


## The Pass screen closed: a purchase still waiting for Google Play to connect is dropped,
## so Play's buy sheet can't open later over a run. (A restore's answer still counts.)
func cancel_wait() -> void:
	_buy_when_ready = false
	if status == CONNECTING or status == CHECKING:
		_restoring = false
		_wait_token += 1
		status = ""


## Asks Google Play again when the game comes back from the background, so a purchase
## finished (or refunded) while the game was away shows up. At most every 30 seconds.
func recheck() -> void:
	if _play == null or Time.get_ticks_msec() - _last_check < 30000:
		return
	_last_check = Time.get_ticks_msec()
	if _play.isReady():
		_play.queryPurchases("inapp", false)
		if Time.get_ticks_msec() - _details_at > 3600000:
			_play.queryProductDetails(PackedStringArray([PASS_ID]), "inapp")
	else:
		_connect()


func _on_connected() -> void:
	_connecting = false
	_last_check = Time.get_ticks_msec()
	_play.queryProductDetails(PackedStringArray([PASS_ID]), "inapp")
	_play.queryPurchases("inapp", false)


func _on_connect_error(code: int, message: String) -> void:
	_connecting = false
	print("[store] can't connect to Google Play (%d): %s" % [code, message])
	if _buy_when_ready or _restoring:
		_play_failed("Google Play isn't available right now. Check your connection and try again.")


func _on_details(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != OK:
		print("[store] product details failed: %s" % r.get("debug_message", ""))
		if _buy_when_ready:
			_play_failed("Couldn't reach Google Play (error %d). Check your connection and try again." % int(r.get("response_code", -1)))
		return
	for p: Dictionary in r.get("product_details", []):
		if str(p.get("product_id", "")) != PASS_ID:
			continue
		_have_details = true
		_details_at = Time.get_ticks_msec()
		_read_offers(p.get("one_time_purchase_offer_details_list", []))
	if not _have_details:
		print("[store] '%s' isn't set up in Play Console yet" % PASS_ID)
		if _buy_when_ready:
			_buy_when_ready = false
			_set_status("The Crypt Pass isn't on sale yet.")
		return
	changed.emit()
	if _buy_when_ready and Game.hud and Game.hud.pass_visible():
		buy()
	_buy_when_ready = false


## Version 279: the Pass's offers from Google Play. The plain one sets `price`; a
## discounted one (the Early Access Deal, set up in Play Console with an end date) sets
## `deal`, and `price` becomes the deal's price.
func _read_offers(offers: Array) -> void:
	var base := {}
	var best := {}
	for o in offers:
		if not o is Dictionary:
			continue
		var cut := _offer_cut(o)
		if cut > 0:
			if best.is_empty() or int(o.get("price_amount_micros", 0)) < int(best.get("price_amount_micros", 0)):
				best = o
		elif base.is_empty():
			base = o
	if base.is_empty() and best.is_empty() and not offers.is_empty() and offers[0] is Dictionary:
		base = offers[0]
	price = str(base.get("formatted_price", ""))
	deal = {}
	if best.is_empty():
		return
	var full := str(base.get("formatted_price", ""))
	if full == "" and best.get("full_price_micros") != null:
		full = _with_amount(str(best.get("formatted_price", "")), int(best.full_price_micros))
	var end := 0
	var w = best.get("valid_time_window")
	if w is Dictionary and w.get("end_time_millis") != null:
		end = int(w.end_time_millis)
	deal = {"pct": _offer_cut(best), "price": str(best.get("formatted_price", "")), "full": full,
		"end_ms": end, "option": str(best.get("purchase_option_id", "")) if best.get("purchase_option_id") != null else "",
		"offer": str(best.get("offer_id", "")) if best.get("offer_id") != null else ""}
	price = str(deal.price)
	print("[store] Early Access Deal: %d%% off, %s (was %s), ends %d" % [deal.pct, deal.price, full, end])


## The percent an offer takes off (0 for the plain price): Play's own figure, else worked out
## from the full price.
static func _offer_cut(o: Dictionary) -> int:
	var info = o.get("discount_display_info")
	if info is Dictionary and info.get("percentage_discount") != null and int(info.percentage_discount) > 0:
		return int(info.percentage_discount)
	if o.get("full_price_micros") != null:
		var full := float(o.full_price_micros)
		var now := float(o.get("price_amount_micros", 0))
		if full > 0.0 and now < full:
			return maxi(1, roundi(100.0 * (1.0 - now / full)))
	return 0


## `formatted` ("$2.99", "2,99 €") with its number swapped for `micros` in the same style.
static func _with_amount(formatted: String, micros: int) -> String:
	var re := RegEx.create_from_string("[0-9][0-9.,\\s]*[0-9]|[0-9]")
	var m := re.search(formatted)
	if m == null:
		return ""
	var num := m.get_string()
	var comma := num.length() >= 3 and num[num.length() - 3] == ","
	var decimals := 2 if (num.length() >= 3 and num[num.length() - 3] in [",", "."]) else 0
	var v := float(micros) / 1000000.0
	var txt := ("%." + str(decimals) + "f") % v
	if comma:
		txt = txt.replace(".", ",")
	return formatted.substr(0, m.get_start()) + txt + formatted.substr(m.get_end())


## Everything this account owns. Also takes the Pass away again if it was refunded.
func _on_owned_list(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != OK:
		if _restoring:
			_play_failed("Couldn't reach Google Play (error %d). Check your connection and try again." % int(r.get("response_code", -1)))
		return
	_restoring = false
	var was_pending := status == PENDING_TEXT
	var has_it := _handle(r.get("purchases", []))
	if has_it:
		_clear_misses()
	elif owned() and not test_owned:
		_note_miss()
	if status == CHECKING:
		_set_status("" if has_it else "No Crypt Pass found on this Google account.")
	elif was_pending and status == PENDING_TEXT and not _has_pending(r.get("purchases", [])):
		# Google Play dropped the pending payment (it ran out of time, or was declined).
		_set_status("Your pending payment was cancelled. Nothing was charged.")


func _on_purchase_updated(r: Dictionary) -> void:
	var code := int(r.get("response_code", -1))
	match code:
		OK:
			_handle(r.get("purchases", []))
		USER_CANCELED:
			Telemetry.step("pass_cancel")
			_set_status("")
		ITEM_ALREADY_OWNED:
			restore()
		_:
			_set_status("The purchase didn't go through. Nothing was charged.")


## Grants the Pass for a completed purchase and confirms it with Google Play (an
## unconfirmed purchase is refunded after three days). Returns true if the Pass is owned.
func _handle(purchases: Array) -> bool:
	var has_it := false
	for p: Dictionary in purchases:
		if not PASS_ID in Array(p.get("product_ids", [])):
			continue
		match int(p.get("purchase_state", 0)):
			PURCHASED:
				has_it = true
				if not bool(p.get("is_acknowledged", false)):
					_play.acknowledgePurchase(str(p.get("purchase_token", "")))
				if not owned():
					_grant()
			PENDING:
				_set_status(PENDING_TEXT)
	return has_it


func _has_pending(purchases: Array) -> bool:
	for p: Dictionary in purchases:
		if PASS_ID in Array(p.get("product_ids", [])) and int(p.get("purchase_state", 0)) == PENDING:
			return true
	return false


func _on_acknowledged(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != OK:
		print("[store] acknowledge failed, will retry next launch: %s" % r.get("debug_message", ""))


func _grant() -> void:
	if not owned():
		Telemetry.step("pass_bought")
	_save_owned(true)
	status = ""
	Sfx.play("victory", 0.8)
	changed.emit()


## One "owned" answer clears any earlier "not found" answers.
func _clear_misses() -> void:
	var cfg := Game._load_save()
	if not cfg.has_section_key(SAVE_SECTION, "miss_count"):
		return
	cfg.erase_section_key(SAVE_SECTION, "miss_count")
	if cfg.has_section_key(SAVE_SECTION, "miss_since"):
		cfg.erase_section_key(SAVE_SECTION, "miss_since")
	Game.write_save(cfg)


## Google Play said this account doesn't own the Pass. Count it; only a run of such answers
## over MISS_HOURS takes the Pass away.
func _note_miss() -> void:
	var cfg := Game._load_save()
	var now := TrustClock.now()   # v218: Google's time when known (a moved clock skipped the wait)
	var since := int(cfg.get_value(SAVE_SECTION, "miss_since", now))
	if since > now:
		since = now   # the clock went back
	var n := int(cfg.get_value(SAVE_SECTION, "miss_count", 0)) + 1
	print("[store] Pass not found on this account (%d of %d, first %d h ago)" % [n, MISS_CHECKS, (now - since) / 3600])
	if n >= MISS_CHECKS and now - since >= MISS_HOURS * 3600:
		cfg.erase_section_key(SAVE_SECTION, "miss_count")
		cfg.erase_section_key(SAVE_SECTION, "miss_since")
		cfg.set_value(SAVE_SECTION, "owned", false)
		# Version 213 (hardest review fix #14): the title says so once, with RESTORE.
		cfg.set_value(SAVE_SECTION, "removed_note", true)
		Game.write_save(cfg)
		print("[store] Pass taken away (refunded)")
		changed.emit()
		return
	cfg.set_value(SAVE_SECTION, "miss_count", n)
	cfg.set_value(SAVE_SECTION, "miss_since", since)
	Game.write_save(cfg)


func _save_owned(v: bool) -> void:
	var cfg := Game._load_save()
	cfg.set_value(SAVE_SECTION, "owned", v)
	Game.write_save(cfg)


func _set_status(text: String) -> void:
	status = text
	changed.emit()


## Shows a waiting line, and if Google Play still hasn't answered after PLAY_TIMEOUT
## seconds, says so instead of waiting forever.
func _wait_for_play(text: String) -> void:
	_wait_token += 1
	var token := _wait_token
	_set_status(text)
	get_tree().create_timer(PLAY_TIMEOUT, true, false, true).timeout.connect(func():
		if token == _wait_token and status == text:
			_play_failed("Google Play didn't answer. Check your connection and try again."))


func _play_failed(text: String) -> void:
	_buy_when_ready = false
	_restoring = false
	_wait_token += 1
	_set_status(text)
	# A connection that never answered would otherwise block every later try until a
	# restart: drop it so the next tap connects afresh.
	if _connecting and _play:
		_connecting = false
		_play.endConnection()
