## UnderWaterTerrain - Slows down character movement
##
## Makes the character move slower when underwater.
## Should be compensated by the FishTail feature (if character has it).
class_name UnderWaterTerrain
extends Terrain

# === EXPORTED VARIABLES ===
@export var slowdown_factor: float = 0.5  # Character moves at 50% speed
@export var buoyancy_force: float = -100.0  # Upward force (negative gravity)
@export var water_resistance: float = 0.95  # Higher resistance than air (5% loss per second)

# === BUILT-IN METHODS ===
func _ready() -> void:
	super._ready()
	terrain_name = "UnderWater"
	affects_movement = true

# === OVERRIDDEN METHODS ===

func _calculate_terrain_effect(delta: float, character_position: Vector2) -> Vector2:
	# Apply buoyancy (upward force)
	return Vector2(0, buoyancy_force * delta)

## Get the damping factor for water resistance
func get_damping_factor() -> float:
	return water_resistance

