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
	_setup_tweakables()

func _setup_tweakables() -> void:
	slowdown_factor = TerrainConstants.get_value("Water", "slowdown_factor")
	buoyancy_force = TerrainConstants.get_value("Water", "buoyancy_force")
	water_resistance = TerrainConstants.get_value("Water", "water_resistance")
	TerrainConstants.value_changed.connect(_on_tweakable_changed)

func _on_tweakable_changed(category: String, key: String, value: Variant) -> void:
	if category == "Water":
		match key:
			"slowdown_factor": slowdown_factor = float(value)
			"buoyancy_force": buoyancy_force = float(value)
			"water_resistance": water_resistance = float(value)

# === OVERRIDDEN METHODS ===

func _calculate_terrain_effect(delta: float, character_position: Vector2) -> Vector2:
	# Apply buoyancy (upward force)
	return Vector2(0, buoyancy_force * delta)

## Get the damping factor for water resistance
func get_damping_factor() -> float:
	return water_resistance

