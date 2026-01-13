## UnderWaterTerrain - Slows down character movement
##
## Makes the character move slower when underwater.
## Should be compensated by the FishTail feature (if character has it).
class_name UnderWaterTerrain
extends Terrain

# === EXPORTED VARIABLES ===
# Removed exports in favor of Tweakables

# === PUBLIC VARIABLES ===
var slowdown_factor: float
var buoyancy_force: float
var water_resistance: float

# === BUILT-IN METHODS ===
func _init() -> void:
	terrain_name = "UnderWater"
	# Water should now use standard gravity, which we counteract with buoyancy
	uses_standard_gravity = true
	priority = 10 # Water overrides standard zones

func _ready() -> void:
	super._ready()
	affects_movement = true
	_setup_tweakables()

func _setup_tweakables() -> void:
	slowdown_factor = 0.5
	buoyancy_force = -300.0
	water_resistance = 0.8
	# TerrainConstants.value_changed.connect(_on_tweakable_changed)

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

func _should_character_enter(character: CharacterBody2D) -> bool:
	# Only enter if character center is below water surface
	var surface_y = _get_water_surface_y()
	return character.global_position.y > surface_y

func _get_water_surface_y() -> float:
	var top_y = INF
	var found = false

	if detection_area:
		for child in detection_area.get_children():
			if child is CollisionShape2D:
				var shape = child.shape
				if shape is RectangleShape2D:
					var top = child.global_position.y - (shape.size.y * 0.5)
					if top < top_y:
						top_y = top
						found = true
				elif shape is CircleShape2D:
					var top = child.global_position.y - shape.radius
					if top < top_y:
						top_y = top
						found = true
			elif child is CollisionPolygon2D:
				for point in child.polygon:
					var global_point = child.to_global(point)
					if global_point.y < top_y:
						top_y = global_point.y
						found = true

	if not found:
		return global_position.y

	return top_y


