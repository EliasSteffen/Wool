extends Node

## GameManager - Central Game State Manager
##
## Handles game states (MENU, PLAYING, PAUSED) and scene transitions.
## Acts as an Autoload (Singleton).

# === SIGNALS ===
signal state_changed(new_state: GameState)
signal rusty_nail_timer_started(duration: float)
signal rusty_nail_timer_updated(progress: float)
signal rusty_nail_timer_stopped()
signal highscore_beaten()

# === ENUMS ===
# === ENUMS ===
enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }

# ...

func _show_game_over_screen() -> void:
	# Show Game Over Screen immediately as overlay
	var game_over_scene = load("res://scenes/ui/game_over.tscn")
	if game_over_scene:
		# Create a temporary CanvasLayer to ensure UI is drawn on top of the paused game
		var canvas_layer = CanvasLayer.new()
		canvas_layer.layer = 100 # High layer priority
		get_tree().root.add_child(canvas_layer)

		var game_over_instance = game_over_scene.instantiate()
		canvas_layer.add_child(game_over_instance)
	else:
		# Fallback if scene missing
		get_tree().reload_current_scene()

## Trigger Game Over state
func game_over() -> void:
	if current_state == GameState.GAME_OVER:
		return

	call_deferred("_show_game_over_screen")

	current_state = GameState.GAME_OVER
	state_changed.emit(current_state)

## Return to main menu
func return_to_menu() -> void:
	current_state = GameState.MENU
	get_tree().paused = false
	_hide_pause_menu()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	state_changed.emit(current_state)

# === PUBLIC VARIABLES ===
var current_state: GameState = GameState.PLAYING
var current_seed: int = 0
var is_first_game_start: bool = true  # Track if this is the first time starting the game
var highscore: int = 0
var max_run_distance: int = 0
var new_highscore_reached_this_run: bool = false

# === CONSTANTS ===
const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const LEVEL_1_SCENE: String = "res://scenes/levels/level_1.tscn"
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")

const PLAYABLE_HEIGHT_MULTIPLIER: float = 1.5
var PLAYABLE_HEIGHT_TOP: float = -1755.0
const PLAYABLE_HEIGHT_BOTTOM: float = 0.0
const WATER_LEVEL: float = 300.0
const SIDE_MARGIN: float = 300.0

# === PRIVATE VARIABLES ===
var _pause_menu_instance: Node = null

# Short-lived input ignore window (ms) used to prevent taps on UI from also triggering gameplay actions
var _ignore_input_until_ms: int = 0

func ignore_input_for(duration: float) -> void:
	# duration in seconds
	_ignore_input_until_ms = Time.get_ticks_msec() + int(duration * 1000)

func is_input_ignored() -> bool:
	return Time.get_ticks_msec() < _ignore_input_until_ms

# === BUILT-IN METHODS ===
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Calculate playable height based on actual viewport (screen-dependent)
	var viewport_height: float = get_viewport().get_visible_rect().size.y
	PLAYABLE_HEIGHT_TOP = -viewport_height * PLAYABLE_HEIGHT_MULTIPLIER

	# Load highscore
	_load_highscore()

	# Initial seed
	randomize()
	current_seed = randi()


	# Add Generic Touch/Click support to "jump" action
	# This ensures tapping ANYWHERE on screen (emulated as Left Click) triggers jump
	# Note: Now also added to project.godot directly for redundancy and export stability.

	# FORCE MOBILE ASPECT RATIO ON PC (Prevent black bars)
	_enforce_pc_aspect_ratio()

func _enforce_pc_aspect_ratio() -> void:
	if OS.get_name() in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		# Target Height (reasonable for windowed mode)
		var target_height = 600
		# Aspect Ratio from Project Settings (2532 / 1170 ~= 2.164)
		var aspect = 2532.0 / 1170.0
		var target_width = int(target_height * aspect)

		DisplayServer.window_set_size(Vector2i(target_width, target_height))
		# Center window?
		var screen_size = DisplayServer.screen_get_size()
		var center = (screen_size - Vector2i(target_width, target_height)) / 2
		DisplayServer.window_set_position(center)

		# Set Min Size
		DisplayServer.window_set_min_size(Vector2i(640, int(640.0 / aspect)))

# Aspect Ratio Enforcement on PC
var _last_window_size: Vector2i = Vector2i.ZERO
const TARGET_ASPECT: float = 2532.0 / 1170.0

func _enforce_aspect_ratio_runtime() -> void:
	if OS.get_name() in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		var current_size = DisplayServer.window_get_size()
		# Tolerance check to avoid fighting too much or float errors
		if _last_window_size == Vector2i.ZERO:
			_last_window_size = current_size
			return

		if current_size == _last_window_size:
			return

		# If size changed, force aspect ratio
		# We prioritize Width (usually easier for landscape)
		var desired_height = int(current_size.x / TARGET_ASPECT)

		# If huge discrepancy, snap back
		if abs(current_size.y - desired_height) > 2:
			DisplayServer.window_set_size(Vector2i(current_size.x, desired_height))
			_last_window_size = Vector2i(current_size.x, desired_height)
		else:
			_last_window_size = current_size

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if current_state == GameState.PLAYING:
			toggle_pause()
		elif current_state == GameState.PAUSED:
			toggle_pause()

# === PUBLIC METHODS ===

## Start the game (load level 1)
func start_game() -> void:
	# Always generate a new seed for every session/restart to ensure new level layout
	current_seed = randi()
	max_run_distance = 0
	new_highscore_reached_this_run = false

	# Reset tracking state to prevent reading old player position before scene change
	_player_ref = null
	_start_initialized = false
	_start_x = 0.0

	current_state = GameState.PLAYING
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVEL_1_SCENE)
	state_changed.emit(current_state)

## Mark that the game has been started (called by level after first start)
func mark_game_started() -> void:
	is_first_game_start = false

## Quit the application
func quit_game() -> void:
	get_tree().quit()

## Toggle pause state
func toggle_pause() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		_show_pause_menu()
	elif current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false
		_hide_pause_menu()

	state_changed.emit(current_state)



# === PRIVATE METHODS ===


## Update highscore if new distance is higher
func update_highscore(new_distance: int, silent: bool = false) -> void:
	if new_distance > highscore:
		new_highscore_reached_this_run = true
		highscore = new_distance
		_save_highscore()
		highscore_beaten.emit()
		if not silent:
			AudioManager.play_sound(AudioManager.GAME.HIGHSCORE)

func _load_highscore() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://highscore.cfg")
	if err == OK:
		highscore = config.get_value("game", "highscore", 0)
	else:
		highscore = 0

func _save_highscore() -> void:
	var config = ConfigFile.new()
	config.set_value("game", "highscore", highscore)
	config.save("user://highscore.cfg")

## Reset highscore to 0
func reset_highscore() -> void:
	highscore = 0
	_save_highscore()



func _show_pause_menu() -> void:
	if not _pause_menu_instance:
		_pause_menu_instance = PAUSE_MENU_SCENE.instantiate()
		get_tree().root.add_child(_pause_menu_instance)
	_pause_menu_instance.show()
func _hide_pause_menu() -> void:
	if _pause_menu_instance:
		_pause_menu_instance.hide()


# === DISTANCE TRACKING ===
var _start_x: float = 0.0
var _start_initialized: bool = false
var _player_ref: Node2D = null

func _process(delta: float) -> void:
	# Keep a reference to player for distance checking
	if not _player_ref or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player")
		if _player_ref:
			_start_initialized = false # Reset start X when player is (re)found

	if _player_ref and not _start_initialized:
		_start_x = _player_ref.global_position.x
		_start_initialized = true

	# Update max run distance
	var current_dist = get_current_distance()
	if current_dist > max_run_distance:
		max_run_distance = current_dist

	# Enforce PC Window Ratio
	_enforce_aspect_ratio_runtime()

func get_current_distance() -> int:
	if not _player_ref or not is_instance_valid(_player_ref) or not _start_initialized:
		return 0

	# Logic: 10 pixels = 1 meter
	return int(max(_player_ref.global_position.x - _start_x, 0.0) / 10.0)
