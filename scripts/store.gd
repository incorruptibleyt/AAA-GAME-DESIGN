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

## The price in the player's own currency ("$4.99"), once Google Play has sent it.
var price := ""
## A short line for the Pass screen: what's happening, or what went wrong.
var status := ""

var _play: Object   # the plugin's JNI singleton, only in the Play build
var _have_details := false
var _buy_when_ready := false
var _last_check := -100000
var _connecting := false
var _restoring := false
var _wait_token := 0


static func owned(cfg: ConfigFile = null) -> bool:
	if test_owned:
		return true
	if cfg == null:
		cfg = Game._load_save()
	return bool(cfg.get_value(SAVE_SECTION, "owned", false))


## True when this copy of the game can buy things (installed from Google Play).
static func can_buy() -> bool:
	return Engine.has_singleton(PLUGIN)


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
	elif not _have_details:
		_play.queryProductDetails(PackedStringArray([PASS_ID]), "inapp")


func buy() -> void:
	if owned():
		return
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
	var r: Dictionary = _play.purchase(PASS_ID, "", "", false)
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
		var offers: Array = p.get("one_time_purchase_offer_details_list", [])
		if not offers.is_empty():
			price = str((offers[0] as Dictionary).get("formatted_price", ""))
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


## Everything this account owns. Also takes the Pass away again if it was refunded.
func _on_owned_list(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != OK:
		if _restoring:
			_play_failed("Couldn't reach Google Play (error %d). Check your connection and try again." % int(r.get("response_code", -1)))
		return
	_restoring = false
	var was_pending := status == PENDING_TEXT
	var has_it := _handle(r.get("purchases", []))
	if not has_it and owned() and not test_owned:
		_save_owned(false)
		changed.emit()
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
	_save_owned(true)
	status = ""
	Sfx.play("victory", 0.8)
	changed.emit()


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
