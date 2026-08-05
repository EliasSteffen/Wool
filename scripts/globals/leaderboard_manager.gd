extends Node

## LeaderboardManager - Global Leaderboard Access
##
## The only leaderboard surface gameplay code touches. All storage work happens
## behind LeaderboardBackend, so swapping Firebase out means changing
## _create_backend() and nothing else.
##
## Nothing here ever blocks gameplay: submits are fire-and-forget, a failed
## submit is queued for the next launch, and fetches are cached so reopening the
## window does not burn Firestore quota.

# === SIGNALS ===
signal top_updated(entries: Array[LeaderboardEntry])
signal submit_finished(result: LeaderboardResult)
signal player_name_changed(new_name: String)
signal availability_changed(available: bool)
signal player_rank_updated(rank: int)

# === CONSTANTS ===
const CONFIG_PATH: String = "res://resources/leaderboard_config.tres"
const PLAYER_PATH: String = "user://player.cfg"
const LOCAL_BACKEND_SCRIPT: GDScript = preload("res://scripts/leaderboard/backends/local_leaderboard_backend.gd")
const FIREBASE_BACKEND_SCRIPT: GDScript = preload("res://scripts/leaderboard/backends/firebase_leaderboard_backend.gd")

## Kept short so "noun + 4 digits" always fits LeaderboardEntry.MAX_NAME_LENGTH.
const NAME_NOUNS: Array[String] = [
	"Schaf", "Knäuel", "Faden", "Masche", "Socke", "Wolke", "Nadel", "Zopf",
	"Flausch", "Pompom", "Filz", "Strick", "Garn", "Troddel", "Bommel", "Docke",
]

## Backoff between reconnect attempts, in seconds; the last value repeats forever.
## Godot exposes no connectivity API, so polling is the only way to notice the
## radio came back - the long tail keeps that from costing battery all session.
const RETRY_DELAYS_SECONDS: Array[int] = [5, 15, 60, 180, 600]

## Floor between manual retries. Dying over and over with no signal should not
## turn into one auth round-trip per death.
const MANUAL_RETRY_COOLDOWN_SECONDS: int = 20

# === PUBLIC VARIABLES ===
var player_name: String = ""
var is_available: bool = false
var is_remote: bool = false

# === PRIVATE VARIABLES ===
var _config: LeaderboardConfig = null
var _backend: LeaderboardBackend = null
var _cached_top: Array[LeaderboardEntry] = []
var _player_entry: LeaderboardEntry = null
var _last_fetch_unix: int = 0
var _name_declined: bool = false
var _pending_score: int = 0
var _pending_time_ms: int = 0
var _fetching: bool = false
var _submitting: bool = false
var _renaming: bool = false
var _connecting: bool = false
var _availability_settled: bool = false
var _retry_index: int = 0
var _retry_timer: Timer = null
var _last_attempt_unix: int = 0

# === BUILT-IN METHODS ===
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_player_state()
	_build_retry_timer()
	_initialize.call_deferred()

func _notification(what: int) -> void:
	# Returning from the background is the likeliest moment for connectivity to
	# have changed, and it is the closest thing to a connection event we get.
	if what == NOTIFICATION_APPLICATION_RESUMED:
		retry_now()

# === PUBLIC METHODS ===

func has_player_name() -> bool:
	return not player_name.is_empty()

## True when the player should be asked for a name before submitting.
##
## Deliberately does not require a connection: names are not unique - the
## document id is - so nothing about picking one needs the network. Choosing a
## name offline lets the queued run travel with it the moment we reconnect.
func should_prompt_for_name() -> bool:
	return not has_player_name() and not _name_declined

func set_player_name(new_name: String) -> void:
	var cleaned: String = LeaderboardEntry.sanitize_name(new_name)
	if cleaned.is_empty() or cleaned == player_name:
		return

	player_name = cleaned
	_name_declined = false
	_save_player_state()
	player_name_changed.emit(player_name)

	# Push the new label to the already-published row, otherwise it would keep
	# the old name until the player next beats their own record.
	_push_rename()

## Player dismissed the prompt - do not ask again, but keep the score locally.
func decline_name_prompt() -> void:
	_name_declined = true
	_save_player_state()

## Queue a run for upload. Safe to call at any time; returns immediately.
func submit_run(score: int, duration_ms: int) -> void:
	if score <= 0 or duration_ms <= 0:
		return

	_remember_pending(score, duration_ms)

	# Without a name there is nothing valid to write - hold it until they pick one.
	if not has_player_name():
		return

	if not is_available:
		# Already banked to disk. A run just ended, so this is a natural moment
		# to check whether the connection came back; the queued score goes up as
		# soon as it does.
		retry_now()
		return

	_submit_pending()

## Drop the backoff and try to reach the backend right now, flushing anything
## queued if it works. Rate-limited by MANUAL_RETRY_COOLDOWN_SECONDS.
func retry_now() -> void:
	if is_available:
		_flush_pending()
		return

	# An attempt is already running and will arm the next backoff itself. Bailing
	# out here matters: the reset below would otherwise cancel a scheduled retry
	# on behalf of an attempt that never starts, killing the loop entirely.
	if _connecting:
		return

	var now: int = int(Time.get_unix_time_from_system())
	if now - _last_attempt_unix < MANUAL_RETRY_COOLDOWN_SECONDS:
		return

	_retry_index = 0
	if _retry_timer:
		_retry_timer.stop()
	_try_connect()

func refresh_top(force: bool = false) -> void:
	if _fetching:
		return
	if not is_available:
		# Opening the window is a deliberate "show me the board" - worth probing
		# the connection. The result arrives via availability_changed.
		retry_now()
		top_updated.emit(_cached_top)
		return

	var now: int = int(Time.get_unix_time_from_system())
	var cache_age: int = now - _last_fetch_unix
	if not force and not _cached_top.is_empty() and cache_age < _config.cache_seconds:
		top_updated.emit(_cached_top)
		return

	_fetch_top_async()

func get_cached_top() -> Array[LeaderboardEntry]:
	return _cached_top

func get_player_entry() -> LeaderboardEntry:
	return _player_entry

func get_player_id() -> String:
	if _backend == null:
		return ""
	return _backend.get_player_id()

## 0 when the player has no ranked entry.
func get_player_rank() -> int:
	if _player_entry == null:
		return 0
	return _player_entry.rank

## Re-reads this player's standing straight from the backend and returns the
## rank (0 when unranked). Waits out an in-flight submit so the rank reflects
## the run that was just sent.
func refresh_player_rank() -> int:
	if not is_available or _backend == null:
		return 0

	while _submitting:
		await get_tree().process_frame

	var result: LeaderboardResult = await _backend.fetch_player()
	if not result.ok or result.entries.is_empty():
		return 0

	_player_entry = result.entries[0]
	player_rank_updated.emit(_player_entry.rank)
	return _player_entry.rank

func is_using_remote_backend() -> bool:
	return is_remote

## A suggested display name.
##
## Purely local and instant: rows are keyed by document id, so two players
## sharing a name collide on screen at worst, and the leaderboard marks your own
## row with "(You)" to keep that unambiguous.
func generate_name() -> String:
	return _random_name()

func _push_rename() -> void:
	if not is_available or _backend == null or _renaming:
		return

	_renaming = true
	var target: String = player_name
	var result: LeaderboardResult = await _backend.rename(target)
	_renaming = false

	if not result.ok:
		push_warning("LeaderboardManager: rename failed (%s)" % result.message)
		return

	# The visible row changed - do not serve a stale cached list.
	_last_fetch_unix = 0
	if _player_entry != null:
		_player_entry.player_name = target

	# The name moved on while we were waiting; run it again.
	if player_name != target:
		_push_rename()

func _random_name() -> String:
	return "%s%04d" % [NAME_NOUNS[randi() % NAME_NOUNS.size()], randi() % 10000]

# === PRIVATE METHODS ===

func _initialize() -> void:
	_config = _load_config()
	_backend = _create_backend()
	add_child(_backend)
	_try_connect()

## Brings the backend online and flushes anything queued. Safe to call
## repeatedly - initialize() is idempotent on every backend, so this doubles as
## the reconnect path.
func _try_connect() -> void:
	if _connecting or is_available or _backend == null:
		return

	_connecting = true
	_last_attempt_unix = int(Time.get_unix_time_from_system())
	var result: LeaderboardResult = await _backend.initialize(_config)
	_connecting = false

	if not result.ok:
		push_warning("LeaderboardManager: backend unavailable (%s)" % result.message)
		_set_available(false)
		# A missing API key is not going to appear by waiting - only retry the
		# failures that a working connection would actually fix.
		if result.code != LeaderboardResult.Code.NOT_CONFIGURED:
			_schedule_retry()
		return

	_retry_index = 0
	# Our standing may have moved while we were offline; do not serve stale data.
	_last_fetch_unix = 0
	_set_available(true)
	_flush_pending()

## Emits availability_changed on every flip, and once when the first connection
## attempt resolves so listeners get an initial value either way.
func _set_available(value: bool) -> void:
	if is_available == value and _availability_settled:
		return
	is_available = value
	_availability_settled = true
	availability_changed.emit(is_available)

func _build_retry_timer() -> void:
	_retry_timer = Timer.new()
	_retry_timer.one_shot = true
	# Modal windows pause the tree, so a plain Timer would stall while the
	# leaderboard or pause menu is open - exactly when a retry matters most.
	_retry_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_retry_timer.timeout.connect(_try_connect)
	add_child(_retry_timer)

func _schedule_retry() -> void:
	if is_available or _retry_timer == null:
		return

	var index: int = mini(_retry_index, RETRY_DELAYS_SECONDS.size() - 1)
	_retry_index += 1
	_retry_timer.start(float(RETRY_DELAYS_SECONDS[index]))

## Push a queued run, if there is one and it has a name to travel under.
func _flush_pending() -> void:
	if _pending_score > 0 and has_player_name():
		_submit_pending()

## A failed call is the only connectivity signal available. Drop back to offline
## on the codes a returning connection would fix, so the backoff loop takes over
## and the queued run gets retried; a rejected write is not a network problem.
func _handle_connectivity_failure(result: LeaderboardResult) -> void:
	match result.code:
		LeaderboardResult.Code.NETWORK, LeaderboardResult.Code.TIMEOUT, LeaderboardResult.Code.AUTH:
			_set_available(false)
			_schedule_retry()

func _load_config() -> LeaderboardConfig:
	if ResourceLoader.exists(CONFIG_PATH):
		var loaded: Resource = load(CONFIG_PATH)
		if loaded is LeaderboardConfig:
			return loaded
		push_warning("LeaderboardManager: %s is not a LeaderboardConfig" % CONFIG_PATH)
	return LeaderboardConfig.new()

func _create_backend() -> LeaderboardBackend:
	if _config.is_valid():
		is_remote = true
		return FIREBASE_BACKEND_SCRIPT.new()

	is_remote = false
	return LOCAL_BACKEND_SCRIPT.new()

func _fetch_top_async() -> void:
	_fetching = true
	var result: LeaderboardResult = await _backend.fetch_top(_config.top_limit)

	if result.ok:
		_cached_top = result.entries
		_last_fetch_unix = int(Time.get_unix_time_from_system())
		await _refresh_player_entry()
	else:
		push_warning("LeaderboardManager: fetch_top failed (%s)" % result.message)
		_handle_connectivity_failure(result)

	_fetching = false
	top_updated.emit(_cached_top)

func _refresh_player_entry() -> void:
	var own_id: String = get_player_id()
	if own_id.is_empty():
		return

	# If we are already in the fetched page, no extra read is needed.
	for entry in _cached_top:
		if entry.player_id == own_id:
			_player_entry = entry
			return

	var result: LeaderboardResult = await _backend.fetch_player()
	if result.ok and not result.entries.is_empty():
		_player_entry = result.entries[0]

func _submit_pending() -> void:
	if _submitting or not is_available or _pending_score <= 0:
		return

	_submitting = true
	var entry: LeaderboardEntry = LeaderboardEntry.create(
		get_player_id(), player_name, _pending_score, _pending_time_ms
	)
	var result: LeaderboardResult = await _backend.submit(entry)
	_submitting = false

	# REJECTED means the rules refused it - virtually always "not an
	# improvement". Retrying would fail identically, so drop it.
	if result.ok or result.code == LeaderboardResult.Code.REJECTED:
		_clear_pending()
		# Our standing changed; next open should re-read rather than show stale data.
		_last_fetch_unix = 0
	else:
		# Stays queued in player.cfg, so it survives even if the app is killed.
		push_warning("LeaderboardManager: submit deferred (%s)" % result.message)
		_handle_connectivity_failure(result)

	submit_finished.emit(result)

func _remember_pending(score: int, duration_ms: int) -> void:
	# Keep only the best queued run, using the same rule the leaderboard sorts by.
	if not LeaderboardEntry.is_better(score, duration_ms, _pending_score, _pending_time_ms):
		return
	_pending_score = score
	_pending_time_ms = duration_ms
	_save_player_state()

func _clear_pending() -> void:
	_pending_score = 0
	_pending_time_ms = 0
	_save_player_state()

func _load_player_state() -> void:
	var config_file: ConfigFile = ConfigFile.new()
	if config_file.load(PLAYER_PATH) != OK:
		return
	player_name = str(config_file.get_value("player", "name", ""))
	_name_declined = bool(config_file.get_value("player", "name_declined", false))
	_pending_score = int(config_file.get_value("player", "pending_score", 0))
	_pending_time_ms = int(config_file.get_value("player", "pending_time_ms", 0))

func _save_player_state() -> void:
	var config_file: ConfigFile = ConfigFile.new()
	config_file.set_value("player", "name", player_name)
	config_file.set_value("player", "name_declined", _name_declined)
	config_file.set_value("player", "pending_score", _pending_score)
	config_file.set_value("player", "pending_time_ms", _pending_time_ms)
	config_file.save(PLAYER_PATH)
