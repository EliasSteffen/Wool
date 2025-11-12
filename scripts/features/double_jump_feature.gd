## DoubleJumpFeature - Allows jumping once more in mid-air
##
## This feature allows the character to perform an additional jump while airborne.
## Tracks jump count and resets when landing on the floor.
class_name DoubleJumpFeature
extends Feature

# === EXPORTED VARIABLES ===
@export var max_air_jumps: int = 1  # Number of extra jumps in air (1 = double jump, 2 = triple jump)
@export var air_jump_power_multiplier: float = 0.9  # Air jumps are 90% as strong as ground jump
@export var jump_input_action: String = "jump"

# === PRIVATE VARIABLES ===
var _jumps_remaining: int = 0
var _was_on_floor: bool = false

# === BUILT-IN METHODS ===
func _ready() -> void:
	feature_name = "DoubleJump"
	enabled = true
	activate()

# === PUBLIC METHODS ===

## Get remaining air jumps
func get_jumps_remaining() -> int:
	return _jumps_remaining

## Reset jump counter (called when landing)
func reset_jumps() -> void:
	_jumps_remaining = max_air_jumps

# === OVERRIDDEN METHODS ===

func handle_input(character: BaseCharacter) -> void:
	if not is_active():
		return

	# Reset jumps when landing on floor
	if character.is_on_floor():
		if not _was_on_floor:
			reset_jumps()
		_was_on_floor = true
	else:
		_was_on_floor = false

	# Check for jump input while in air
	if Input.is_action_just_pressed(jump_input_action):
		if not character.is_on_floor() and _jumps_remaining > 0:
			_perform_air_jump(character)

func _calculate_movement_factor(delta: float, character_position: Vector2) -> Vector2:
	# Double jump doesn't add passive movement
	# It triggers instant velocity changes via handle_input()
	return Vector2.ZERO

# === PRIVATE METHODS ===

func _perform_air_jump(character: BaseCharacter) -> void:
	if character is BasePlayer:
		var jump_power: float = character.JUMP_VELOCITY * air_jump_power_multiplier
		character.velocity.y = jump_power
		_jumps_remaining -= 1

		# Optional: Emit signal or play jump effect
		# character.emit_signal("air_jumped")
