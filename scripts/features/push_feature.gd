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
	feature_name = "Push"
	_setup_tweakables()

func _setup_tweakables() -> void:
	push_slowdown_factor = FeatureConstants.get_value("Push", "push_slowdown_factor")
	push_force_multiplier = FeatureConstants.get_value("Push", "push_force_multiplier")
	FeatureConstants.value_changed.connect(_on_tweakable_changed)

func _on_tweakable_changed(category: String, key: String, value: Variant) -> void:
	if category == "Push":
		match key:
			"push_slowdown_factor": push_slowdown_factor = float(value)
			"push_force_multiplier": push_force_multiplier = float(value)

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
