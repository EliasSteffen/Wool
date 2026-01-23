extends Node2D

## Level 1 Script
##
## Handles start icons removal (instant start)

@onready var hud: CanvasLayer = $HUD

var player: BasePlayer = null

# Only accept start input after the scene has finished loading
var _tutorial_hint_instance: Control = null
var _tutorial_timer: float = 0.0
var _waiting_for_input_after_icons: bool = false
const TUTORIAL_HINT_SCENE = preload("res://scenes/ui/tutorial_hint.tscn")

func _ready() -> void:
	# Mark that the game has been started
	GameManager.mark_game_started()

	if hud:
		hud.visible = true

	# Start waiting for player input (Tutorial logic)
	_waiting_for_input_after_icons = true
	_tutorial_timer = 0.0

	# Add Enemy Spawner
	var spawner_script = load("res://scripts/levels/enemy_spawner.gd")
	if spawner_script:
		var spawner = spawner_script.new()
		spawner.name = "EnemySpawner"
		add_child(spawner)

func _process(delta: float) -> void:
	# Try to find player if not found yet
	if not player:
		player = get_tree().get_first_node_in_group("player")

	# Tutorial Hint Timer Logic
	if _waiting_for_input_after_icons and not _tutorial_hint_instance:
		_tutorial_timer += delta
		if _tutorial_timer >= 1.5:
			_show_tutorial_hint()

	# Note: We only accept unhandled events after the scene has loaded to avoid UI/pause interactions starting the game.


func _show_tutorial_hint() -> void:
	if not TUTORIAL_HINT_SCENE: return

	_tutorial_hint_instance = TUTORIAL_HINT_SCENE.instantiate()

	# Pass context to tutorial hint
	if player:
		var start_pos = player.global_position
		if _tutorial_hint_instance.has_method("setup"):
			_tutorial_hint_instance.setup(start_pos, player)

	if hud:
		hud.add_child(_tutorial_hint_instance)
	else:
		add_child(_tutorial_hint_instance)

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		# Ignore input if the game is paused or not in PLAYING state
		return

	if event.is_action_pressed("jump") and not event.is_echo():
		# Check tutorial dismissal
		if _waiting_for_input_after_icons:
			_waiting_for_input_after_icons = false
			if _tutorial_hint_instance:
				_tutorial_hint_instance.queue_free()
				_tutorial_hint_instance = null
