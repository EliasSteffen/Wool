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
	affects_movement = true

# === OVERRIDDEN METHODS ===

func _calculate_terrain_effect(delta: float, character_position: Vector2) -> Vector2:
	# Air resistance doesn't add force, it reduces velocity (via damping)
	return Vector2.ZERO

## Get the damping factor for air resistance
func get_damping_factor() -> float:
	return air_resistance
