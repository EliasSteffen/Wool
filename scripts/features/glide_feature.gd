## GlideFeature - Lets you glide (slower falling) while holding jump in air
##
## This feature reduces fall speed when the jump button is held in mid-air.
## Activates only when in air and jump is held.
class_name GlideFeature
extends Feature

# === EXPORTED VARIABLES ===
@export var glide_fall_multiplier: float = 0.3  # Fall at 30% speed while gliding
@export var glide_input_action: String = "jump"  # Input action to trigger gliding

# === PRIVATE VARIABLES ===
var _is_gliding: bool = false

# === BUILT-IN METHODS ===
func _ready() -> void:
	feature_name = "Glide"
	enabled = true
	# Glide activates/deactivates based on input and air state
	activate()

# === PUBLIC METHODS ===

## Check if currently gliding
func is_gliding() -> bool:
	return _is_gliding

## Get fall speed multiplier when gliding
func get_glide_multiplier() -> float:
	if _is_gliding:
		return glide_fall_multiplier
	return 1.0

## Get gravity multiplier (implements Feature base method)
func get_gravity_multiplier() -> float:
	return get_glide_multiplier()

# === OVERRIDDEN METHODS ===

func handle_input(character: BaseCharacter) -> void:
	if not is_active():
		return

	# Can only glide in the air (not on floor)
	var can_glide: bool = not character.is_on_floor() and character.velocity.y > 0  # Falling down
	var input_held: bool = Input.is_action_pressed(glide_input_action)

	_is_gliding = can_glide and input_held

func _calculate_movement_factor(delta: float, character_position: Vector2) -> Vector2:
	# Gliding doesn't add movement
	# It modifies gravity through get_glide_multiplier()
	# This is handled in BaseCharacter._calculate_gravity()
	return Vector2.ZERO
