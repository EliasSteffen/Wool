## UpwindTerrain - Pushes character up when gliding
##
## Applies an upward force to the character, but ONLY if they are currently gliding.
## This allows for "thermal" mechanics where the player can gain height.
class_name UpwindTerrain
extends Terrain

# === PUBLIC VARIABLES ===
var upwind_force: float
var max_upwind_velocity: float

# === BUILT-IN METHODS ===
func _init() -> void:
	terrain_name = "Upwind"

func _ready() -> void:
	super._ready()
	affects_movement = true
	can_glide_upwards = true
	priority = 10 # Upwind overrides standard zones
	_setup_tweakables()

func _setup_tweakables() -> void:
	upwind_force = TerrainConstants.get_value("Upwind", "upwind_force")
	max_upwind_velocity = TerrainConstants.get_value("Upwind", "max_upwind_velocity")
	TerrainConstants.value_changed.connect(_on_tweakable_changed)

func _on_tweakable_changed(category: String, key: String, value: Variant) -> void:
	if category == "Upwind":
		match key:
			"upwind_force": upwind_force = float(value)
			"max_upwind_velocity": max_upwind_velocity = float(value)

# === OVERRIDDEN METHODS ===

func _calculate_terrain_effect(delta: float, _character_position: Vector2) -> Vector2:
	# We need to check if the character is gliding
	# Since we don't have direct access to the character here (only position),
	# we need to iterate over characters in the terrain.
	# However, this method is called by the character itself via get_movement_factor.
	# But get_movement_factor doesn't pass the character instance.

	# Wait, BaseCharacter calls: current_terrain.get_movement_factor(delta, global_position)
	# And Terrain.get_movement_factor calls _calculate_terrain_effect.
	# This design is a bit limiting because we don't know WHICH character is asking.

	# WORKAROUND: Since we can't easily identify the calling character in the current architecture
	# without changing the base class signature (which might break other things),
	# we will return ZERO here and apply the force in a different way.

	# BETTER APPROACH: We can override get_movement_factor in Terrain to accept an optional character?
	# No, BaseCharacter calls it.

	# Let's look at BaseCharacter.gd again.
	# It calls: total_factor += current_terrain.get_movement_factor(delta, global_position)

	# We should probably change PhysicsChanger to accept the character instance instead of just position.
	# But that's a big refactor.

	# Alternative: Since UpwindTerrain tracks characters in _characters_in_terrain,
	# we could apply the force directly to them in _physics_process of the Terrain?
	# But Terrain inherits Node2D, so it has _physics_process.

	return Vector2.ZERO

## Apply force directly to characters in the terrain
func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	for character in _characters_in_terrain:
		if character is BaseCharacter:
			_apply_upwind_force(character, delta)

func _apply_upwind_force(character: BaseCharacter, delta: float) -> void:
	# Check if character has GlideFeature and is gliding
	var glide_feature = character.get_feature_by_type(GlideFeature)

	if glide_feature and glide_feature.is_gliding():
		# Apply upward force with smooth acceleration towards max velocity
		# upwind_force is negative (e.g. -1500), max_upwind_velocity is negative (e.g. -600)

		# Only apply force if we haven't reached max upward speed yet
		# OR if we are falling (velocity.y > max_upwind_velocity)
		if character.velocity.y > max_upwind_velocity:
			character.velocity.y = move_toward(character.velocity.y, max_upwind_velocity, abs(upwind_force) * delta)
			# print("Upwind force applied! Vel Y: ", character.velocity.y)
	# else:
	# 	print("Upwind active but not gliding.")

