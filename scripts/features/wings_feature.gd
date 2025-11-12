## WingsFeature - Lets you jump higher and fall slower
##
## This feature modifies jump height and gravity for the character.
## Always active if enabled (no activation condition needed).
class_name WingsFeature
extends Feature

# === EXPORTED VARIABLES ===
@export var jump_boost_multiplier: float = 1.5  # 50% higher jumps
@export var fall_speed_multiplier: float = 0.6  # Fall 40% slower (60% of normal speed)
@export var glide_threshold: float = 50.0  # Velocity at which gliding starts

# === PRIVATE VARIABLES ===
var _is_gliding: bool = false

# === BUILT-IN METHODS ===
func _ready() -> void:
	feature_name = "Wings"
	# Wings are always active if enabled
	if enabled:
		activate()

# === PUBLIC METHODS ===

## Get jump boost factor (called by character when jumping)
func get_jump_boost() -> float:
	if is_active():
		return jump_boost_multiplier
	return 1.0

## Get fall speed multiplier (called by character during gravity calculation)
func get_fall_speed_multiplier() -> float:
	if is_active():
		return fall_speed_multiplier
	return 1.0

## Check if character is gliding
func is_gliding() -> bool:
	return _is_gliding

# === OVERRIDDEN METHODS ===

func _on_activated() -> void:
	pass

func _on_deactivated() -> void:
	_is_gliding = false

func _calculate_movement_factor(delta: float, character_position: Vector2) -> Vector2:
	# Wings don't directly modify movement vector
	# They modify jump height and fall speed through multipliers
	# Character calls get_jump_boost() and get_fall_speed_multiplier()
	return Vector2.ZERO
