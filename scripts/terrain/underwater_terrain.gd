## UnderWaterTerrain - Slows down character movement
##
## Makes the character move slower when underwater.
## Should be compensated by the FishTail feature (if character has it).
class_name UnderWaterTerrain
extends Terrain

# === EXPORTED VARIABLES ===
@export var slowdown_factor: float = 0.5  # Character moves at 50% speed
@export var buoyancy_force: float = -100.0  # Upward force (negative gravity)

# === BUILT-IN METHODS ===
func _ready() -> void:
	super._ready()
	terrain_name = "UnderWater"

# === OVERRIDDEN METHODS ===

func _calculate_terrain_effect(delta: float, character_position: Vector2) -> Vector2:
	# Apply buoyancy (upward force)
	return Vector2(0, buoyancy_force * delta)

func _on_character_entered(character: CharacterBody2D) -> void:
	# Apply slowdown to character
	# NOTE: This should be handled in BaseCharacter's movement calculation
	pass

func _on_character_exited(character: CharacterBody2D) -> void:
	# Remove slowdown effect
	pass

## Get the slowdown factor for movement (called by character)
func get_slowdown_factor() -> float:
	return slowdown_factor
