## GrapplingFeature - Implements swinging on nearby nails
##
## This feature allows the character to swing on nails like a rope/pendulum.
## Activates when a Nail is in nearby_interactions and input is pressed.
## Implements rope constraint physics for realistic swinging.
class_name GrapplingFeature
extends Feature

# === SIGNALS ===
signal grapple_started(target: Vector2)
signal grapple_ended()

# === EXPORTED VARIABLES ===
@export var rope_length: float = 150.0  # Maximum rope length (matches Nail detection range)
@export var tension_strength: float = 2000.0  # How strong the rope pulls when stretched
@export var swing_pump_force: float = 400.0  # Force added when pumping the swing
@export var damping: float = 0.995  # Air resistance (0.99 = slight damping, 1.0 = no damping)
@export var initial_pull_strength: float = 1500.0  # Initial pull force to reach rope length

# === PRIVATE VARIABLES ===
var _grapple_target: Vector2 = Vector2.ZERO
var _target_nail: Interaction = null
var _has_reached_rope_length: bool = false  # Track if we've reached the rope length once

# === BUILT-IN METHODS ===
func _ready() -> void:
	feature_name = "Grappling"

# === PUBLIC METHODS ===

## Set the grapple target position (called by character)
func set_target(target_position: Vector2, nail: Interaction = null) -> void:
	_grapple_target = target_position
	_target_nail = nail
	_has_reached_rope_length = false  # Reset flag for new grapple

	if nail:
		nail.set_used(true)

	activate()
	grapple_started.emit(target_position)

## Release the grapple
func release() -> void:
	if _target_nail:
		_target_nail.set_used(false)

	_target_nail = null
	_has_reached_rope_length = false
	deactivate()
	grapple_ended.emit()

## Get current grapple target
func get_target() -> Vector2:
	return _grapple_target

## Get the nail being grappled to
func get_target_nail() -> Interaction:
	return _target_nail

# === OVERRIDDEN METHODS ===

func _on_activated() -> void:
	pass

func _on_deactivated() -> void:
	_grapple_target = Vector2.ZERO
	_has_reached_rope_length = false

func _calculate_movement_factor(delta: float, character_position: Vector2) -> Vector2:
	if _grapple_target == Vector2.ZERO:
		return Vector2.ZERO

	# Vector from character to grapple point
	var to_grapple: Vector2 = _grapple_target - character_position
	var distance: float = to_grapple.length()

	# Initial pull: Strong pull ONLY until we reach rope_length for the first time
	if not _has_reached_rope_length and distance > rope_length:
		var direction: Vector2 = to_grapple.normalized()
		var pull_force: Vector2 = direction * initial_pull_strength * delta
		return pull_force

	# Once we've reached rope_length, mark it
	if distance <= rope_length:
		_has_reached_rope_length = true

	# After initial pull: NO FORCE - constraint is handled in BaseCharacter
	return Vector2.ZERO
