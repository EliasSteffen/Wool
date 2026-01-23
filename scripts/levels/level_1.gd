extends Node2D

## Level 1 Script
##
## Handles start icons animation and removal on first input

signal start_icons_animation_started

@onready var start_icons: Node2D = $Starticons
@onready var hud: CanvasLayer = $HUD

var player: BasePlayer = null
var _has_started: bool = false
var _is_animating: bool = false
var _animation_speed: float = 800.0  # Pixels per second upward

# Only accept start input after the scene has finished loading
var _tutorial_hint_instance: Control = null
var _tutorial_timer: float = 0.0
var _waiting_for_input_after_icons: bool = false
const TUTORIAL_HINT_SCENE = preload("res://scenes/ui/tutorial_hint.tscn")

var _accept_start_input: bool = false

func _ready() -> void:
	if not start_icons:
		push_warning("Level1: Starticons node not found!")
		return

	# If this is not the first game start, remove start icons immediately
	if not GameManager.is_first_game_start:
		_remove_start_icons()
	else:
		# Mark that the game has been started (after first load)
		GameManager.mark_game_started()
		# Hide HUD until start icons are gone
		if hud:
			hud.visible = false

	# Enable accepting start input on the next idle frame so only input after the scene load counts
	call_deferred("_enable_start_input")

func _process(delta: float) -> void:
	# Try to find player if not found yet
	if not player:
		player = get_tree().get_first_node_in_group("player")

	# Tutorial Hint Timer Logic
	if _waiting_for_input_after_icons and not _tutorial_hint_instance:
		_tutorial_timer += delta
		if _tutorial_timer >= 1.5:
			_show_tutorial_hint()

	# Check for first input (handled in _unhandled_input) - see _unhandled_input implementation
	# Note: We only accept unhandled events after the scene has loaded to avoid UI/pause interactions starting the game.

	# Animate upward if animation is active
	if _is_animating and start_icons:
		start_icons.position.y -= _animation_speed * delta

		# Check if icons are out of camera view
		if _is_out_of_camera_view():
			_remove_start_icons()

func _start_animation() -> void:
	if not start_icons:
		return

	_has_started = true
	_is_animating = true
	start_icons_animation_started.emit()

func _is_out_of_camera_view() -> bool:
	if not start_icons:
		return true

	# Calculate the actual top and bottom bounds of the icons in global coordinates
	var icons_bounds = _get_icons_bounds()
	var icons_top = icons_bounds["top"]
	var icons_bottom = icons_bounds["bottom"]

	# Try to get player camera if available
	if player and player.camera:
		var camera = player.camera
		var viewport_rect = get_viewport().get_visible_rect()
		var half_height = (viewport_rect.size.y / camera.zoom.y) * 0.5

		var camera_top = camera.global_position.y - half_height

		# Check if icons are completely above camera view (with margin)
		return icons_bottom < camera_top - 500.0  # Increased margin to 500px

	# Fallback: check if icons are far above viewport
	var viewport_rect = get_viewport().get_visible_rect()
	var viewport_top = viewport_rect.position.y
	return icons_bottom < viewport_top - 500.0  # Increased margin

func _get_icons_bounds() -> Dictionary:
	var result = {"top": INF, "bottom": -INF}

	if not start_icons:
		return result

	var icons_center_y = start_icons.global_position.y

	# Get the bounding box of all children in global coordinates
	for child in start_icons.get_children():
		if child is Node2D:
			var child_global_y = child.global_position.y
			var child_height: float = 0.0

			if child is Sprite2D:
				var texture = child.texture
				if texture:
					child_height = texture.get_height() * child.scale.y
			elif child is Label:
				child_height = child.size.y

			var child_top = child_global_y - child_height * 0.5
			var child_bottom = child_global_y + child_height * 0.5

			result["top"] = min(result["top"], child_top)
			result["bottom"] = max(result["bottom"], child_bottom)

	# Fallback if no children found
	if result["top"] == INF or result["bottom"] == -INF:
		result["top"] = icons_center_y
		result["bottom"] = icons_center_y

	return result

func _enable_start_input() -> void:
	# Called deferred to ensure the scene has finished loading
	_accept_start_input = true

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
	# Only start on unhandled 'jump' events that occur after the scene is loaded
	if not _accept_start_input:
		return

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

		if _is_animating:
			# Skip animation
			_remove_start_icons()
		elif not _has_started:
			# Start animation
			_start_animation()

func _remove_start_icons() -> void:
	if start_icons:
		start_icons.visible = false # Hide immediately to prevent freeze frame
		start_icons.queue_free()
		start_icons = null
		_is_animating = false

		# Show HUD now that start icons are gone
		if hud:
			hud.visible = true

		# Start waiting for player input (Tutorial logic)
		_waiting_for_input_after_icons = true
		_tutorial_timer = 0.0

		# Add Enemy Spawner
		# Preload or Load (Script load is fast, but visible=false handles the visual hitch)
		var spawner_script = load("res://scripts/levels/enemy_spawner.gd")
		if spawner_script:
			var spawner = spawner_script.new()
			spawner.name = "EnemySpawner"
			add_child(spawner)

