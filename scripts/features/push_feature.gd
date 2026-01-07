## PushFeature - Implements pushing of boxes
##
## This feature allows the character to push boxes.
## Activates when a Box is in nearby_interactions.
## Applies resistance when pushing to slow down the character.
class_name PushFeature
extends Feature

# === SIGNALS ===
signal push_started(box: Interaction)
signal push_ended()

# === EXPORTED VARIABLES ===
# Removed exports in favor of Tweakables

# === PUBLIC VARIABLES ===
var push_slowdown_factor: float
var push_force_multiplier: float

# === PRIVATE VARIABLES ===
var _pushing_box: Interaction = null
var _is_pushing: bool = false

# === BUILT-IN METHODS ===
func _ready() -> void:
	super._ready()
	feature_name = "Push"
	setup_tweakables_generic({
		"push_slowdown_factor": "push_slowdown_factor",
		"push_force_multiplier": "push_force_multiplier"
	})

# === PUBLIC METHODS ===

## Start pushing a box
func start_pushing(box: Interaction) -> void:
	_pushing_box = box
	_is_pushing = true

	if box:
		box.set_used(true)

	activate()
	push_started.emit(box)

## Stop pushing
func stop_pushing() -> void:
	if _pushing_box:
		_pushing_box.set_used(false)

	_pushing_box = null
	_is_pushing = false
	deactivate()
	push_ended.emit()

## Check if currently pushing
func is_pushing() -> bool:
	return _is_pushing

## Get the box being pushed
func get_pushing_box() -> Interaction:
	return _pushing_box

# === OVERRIDDEN METHODS ===

func handle_input(character: BaseCharacter) -> void:
	if not enabled:
		return

	# Handle Box Finding and Pushing Logic
	var player_input_x: float = Input.get_axis("move_left", "move_right")

	# Check if moving towards a box
	var box: Box = _find_nearest_box(character)
	if box and player_input_x != 0:
		var direction_to_box: float = sign(box.global_position.x - character.global_position.x)
		if sign(player_input_x) == direction_to_box or (direction_to_box == 0 and player_input_x > 0): # imprecise check
			# More precise check:
			if sign(player_input_x) == sign(box.global_position.x - character.global_position.x):
				start_pushing(box)
			else:
				stop_pushing()
		else:
			stop_pushing()
	else:
		stop_pushing()

func _find_nearest_box(character: BaseCharacter) -> Box:
	var nearest: Box = null
	var nearest_distance: float = INF

	for interaction in character.nearby_interactions:
		if interaction is Box:
			var distance: float = character.global_position.distance_to(interaction.global_position)
			if distance < nearest_distance:
				nearest = interaction as Box
				nearest_distance = distance

	return nearest

func _on_activated() -> void:
	pass

func _on_deactivated() -> void:
	_is_pushing = false

func _calculate_movement_factor(delta: float, character_position: Vector2) -> Vector2:
	if not _is_pushing:
		return Vector2.ZERO

	# Pushing applies a slowdown effect (negative factor)
	# This will be multiplied with the character's velocity
	# Return zero here - slowdown is handled differently in character
	return Vector2.ZERO

## Get the slowdown factor when pushing (called by character)
func get_push_slowdown() -> float:
	if _is_pushing:
		return push_slowdown_factor
	return 1.0
