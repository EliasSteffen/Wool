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
const NAME_ATTEMPTS: int = 6

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

# === BUILT-IN METHODS ===
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_player_state()
	_initialize.call_deferred()

# === PUBLIC METHODS ===

func has_player_name() -> bool:
	return not player_name.is_empty()

## True when the player should be asked for a name before submitting.
func should_prompt_for_name() -> bool:
	return is_available and not has_player_name() and not _name_declined

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

	_submit_pending()

func refresh_top(force: bool = false) -> void:
	if _fetching:
		return
	if not is_available:
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

func is_using_remote_backend() -> bool:
	return is_remote

## A generated name nobody else is using yet.
##
## Uniqueness is best-effort: the check and the later write are not atomic, so
## two players generating at the same instant could still collide. Enforcing
## true uniqueness would need a second collection and a transaction, which the
## Firestore rules alone cannot express.
func generate_unique_name() -> String:
	var candidate: String = _random_name()

	for _attempt in range(NAME_ATTEMPTS):
		if await is_name_available(candidate):
			return candidate
		candidate = _random_name()

	# Give up on pretty and lean on entropy instead.
	return LeaderboardEntry.sanitize_name("%s%d" % [candidate, randi() % 100])

func is_name_available(candidate: String) -> bool:
	var cleaned: String = LeaderboardEntry.sanitize_name(candidate)
	if cleaned.is_empty():
		return false
	if not is_available or _backend == null:
		# Offline we cannot know - do not block the player over it.
		return true

	var result: LeaderboardResult = await _backend.find_by_name(cleaned)
	if not result.ok:
		return true

	return result.entries.is_empty()

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

	var result: LeaderboardResult = await _backend.initialize(_config)
	is_available = result.ok

	if not result.ok:
		push_warning("LeaderboardManager: backend unavailable (%s)" % result.message)
	elif _pending_score > 0 and has_player_name():
		# A run from a previous session never made it up - retry now.
		_submit_pending()

	availability_changed.emit(is_available)

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
		push_warning("LeaderboardManager: submit deferred (%s)" % result.message)

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
