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

# === ENUMS ===
enum GameState { MENU, PLAYING, PAUSED }

# === PUBLIC VARIABLES ===
var current_state: GameState = GameState.PLAYING
var current_seed: int = 0
var is_first_game_start: bool = true  # Track if this is the first time starting the game
var highscore: int = 0

# === CONSTANTS ===
const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const LEVEL_1_SCENE: String = "res://scenes/levels/level_1.tscn"
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")

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
	# Initial seed
	randomize()
	current_seed = randi()

	# Load highscore
	_load_highscore()

	# Add Generic Touch/Click support to "jump" action
	# This ensures tapping ANYWHERE on screen (emulated as Left Click) triggers jump
	# Note: Now also added to project.godot directly for redundancy and export stability.

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

## Return to main menu
func return_to_menu() -> void:
	current_state = GameState.MENU
	get_tree().paused = false
	_hide_pause_menu()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	state_changed.emit(current_state)

# === PRIVATE METHODS ===

func _show_pause_menu() -> void:
	if not _pause_menu_instance:
		_pause_menu_instance = PAUSE_MENU_SCENE.instantiate()
		get_tree().root.add_child(_pause_menu_instance)
	_pause_menu_instance.show()

func _hide_pause_menu() -> void:
	if _pause_menu_instance:
		_pause_menu_instance.hide()

## Update highscore if new distance is higher
func update_highscore(new_distance: int) -> void:
	if new_distance > highscore:
		highscore = new_distance
		_save_highscore()

# === PRIVATE METHODS ===

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
