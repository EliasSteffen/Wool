## DoubleJumpFeature - Allows jumping once more in mid-air
##
## This feature allows the character to perform an additional jump while airborne.
## Tracks jump count and resets when landing on the floor.
class_name DoubleJumpFeature
extends Feature

# === EXPORTED VARIABLES ===
@export var jump_input_action: String = "jump"

# === PUBLIC VARIABLES ===
var max_air_jumps: int
var air_jump_power_multiplier: float

# === PRIVATE VARIABLES ===
var _jumps_remaining: int = 0
var _was_on_floor: bool = false

# === BUILT-IN METHODS ===
func _ready() -> void:
	feature_name = "DoubleJump"
	setup_tweakables_generic({
		"max_air_jumps": "max_air_jumps",
		"air_jump_power_multiplier": "air_jump_power_multiplier"
	})
	activate()

# === PUBLIC METHODS ===

## Trigger the double jump action (used by AI or input)
func trigger(explicit_character: Node = null) -> void:
	if not is_active():
		return

	var character = explicit_character
	if not character:
		character = get_character()

	if not character:
		print("DoubleJump: No character found in trigger!")
		return

	if not character.is_on_floor():
		if _jumps_remaining > 0:
			_perform_air_jump(character)
		else:
			print("DoubleJump: No jumps remaining (%s)" % _jumps_remaining)
	else:
		print("DoubleJump: Character is on floor")

## Get remaining air jumps
func get_jumps_remaining() -> int:
	return _jumps_remaining

## Reset jump counter (called when landing)
func reset_jumps() -> void:
	_jumps_remaining = max_air_jumps

# === OVERRIDDEN METHODS ===

func handle_input(character: BaseCharacter) -> void:
	if not is_active():
		# print("DoubleJump: handle_input called but not active")
		return

	# Reset jumps when landing on floor
	if character.is_on_floor():
		if not _was_on_floor:
			reset_jumps()
			print("DoubleJump: Reset jumps (Landed)")
		_was_on_floor = true
	else:
		_was_on_floor = false

	# Check for jump input while in air
	if Input.is_action_just_pressed(jump_input_action):
		print("DoubleJump: Input detected. Active: %s, OnFloor: %s, Jumps: %s" % [is_active(), character.is_on_floor(), _jumps_remaining])
		trigger(character)

func _calculate_movement_factor(delta: float, character_position: Vector2) -> Vector2:
	# Double jump doesn't add passive movement
	# It triggers instant velocity changes via handle_input()
	return Vector2.ZERO

# === PRIVATE METHODS ===

func _perform_air_jump(character: BaseCharacter) -> void:
	var jump_vel: float = 0.0

	# Safely retrieve jump_velocity from the character (Player or Enemy)
	var val = character.get("jump_velocity")
	if val != null:
		jump_vel = float(val)

	print("DoubleJump: Attempting jump. Character: %s, JumpVel: %s, Multiplier: %s" % [character.name, jump_vel, air_jump_power_multiplier])

	if jump_vel > 0:
		# Negate jump_velocity because Y-up is negative in Godot
		var jump_power: float = -jump_vel * air_jump_power_multiplier
		character.velocity.y = jump_power
		_jumps_remaining -= 1
		print("DoubleJump: Performed air jump! New Velocity Y: %s, Remaining: %s" % [character.velocity.y, _jumps_remaining])
	else:
		push_warning("DoubleJump: Character has no jump_velocity or it is 0")
