## AirTerrain - Default terrain for air/no terrain
##
## Applies air resistance (damping) to slow down movement over time.
## This simulates natural energy loss when swinging or moving through air.
class_name AirTerrain
extends Terrain

# === EXPORTED VARIABLES ===
@export var air_resistance: float = 0.98  # Multiplier per second (0.98 = 2% loss per second)
@export var applies_to_grappling: bool = true  # Whether to affect grappling swing

# === BUILT-IN METHODS ===
func _ready() -> void:
	terrain_name = "Air"

# === OVERRIDDEN METHODS ===

func _calculate_movement_factor(delta: float, character_position: Vector2) -> Vector2:
	# Air resistance doesn't add movement, it reduces it
	# This is handled in BaseCharacter by applying damping to velocity
	return Vector2.ZERO

## Get the damping factor for this terrain
func get_damping_factor() -> float:
	return air_resistance
