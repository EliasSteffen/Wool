## GlideFeature - Lets you glide (slower falling) while holding jump in air
##
## This feature reduces fall speed when the jump button is held in mid-air.
## Activates only when in air and jump is held.
class_name GlideFeature
extends Feature

# === EXPORTED VARIABLES ===
@export var glide_input_action: String = "jump"  # Input action to trigger gliding

# === PUBLIC VARIABLES ===
var glide_fall_multiplier: float

# === PRIVATE VARIABLES ===
var _is_gliding: bool = false

# === BUILT-IN METHODS ===
func _ready() -> void:
	super._ready()
	feature_name = "Glide"
	_setup_tweakables()
	# Glide activates/deactivates based on input and air state
	activate()

func _setup_tweakables() -> void:
	glide_fall_multiplier = FeatureConstants.get_value("Glide", "glide_fall_multiplier")
	FeatureConstants.value_changed.connect(_on_tweakable_changed)

func _on_tweakable_changed(category: String, key: String, value: Variant) -> void:
	if category == "Glide" and key == "glide_fall_multiplier":
		glide_fall_multiplier = float(value)

# === PUBLIC METHODS ===

## Check if currently gliding
func is_gliding() -> bool:
	return _is_gliding

## Get fall speed multiplier when gliding
func get_glide_multiplier() -> float:
	if _is_gliding:
		return glide_fall_multiplier
	return 1.0

## Get gravity multiplier (implements Feature base method)
func get_gravity_multiplier() -> float:
	return get_glide_multiplier()

# === OVERRIDDEN METHODS ===

func handle_input(character: BaseCharacter) -> void:
	if not is_active():
		return

	# Can only glide in the air (not on floor)
	# Usually only when falling, unless terrain allows upward gliding (e.g. Upwind)
	var is_falling: bool = character.velocity.y > 0

	# Check if current terrain allows upward gliding OR if we seem to be in an upwind zone
	# We check strictly for UpwindTerrain type as a fallback if current_terrain priority didn't switch yet
	var terrain_allows_upward: bool = false
	if character.current_terrain and character.current_terrain.can_glide_upwards:
		terrain_allows_upward = true
	elif character.get_active_terrain_of_type(UpwindTerrain) != null:
		terrain_allows_upward = true

	var can_glide: bool = not character.is_on_floor() and (is_falling or terrain_allows_upward)
	var input_held: bool = Input.is_action_pressed(glide_input_action)

	# For Player: Input determines gliding
	# For AI: Method calls determine gliding (so we don't override AI decisions with Input result if false)
	if character.is_in_group("player"):
		_is_gliding = can_glide and input_held
	else:
		# For AI/Enemies, _is_gliding is managed via start_gliding/stop_gliding
		# But we still enforce physical possibility
		if _is_gliding and not can_glide:
			_is_gliding = false

## Start gliding (for AI control)
func start_gliding() -> void:
	if is_active():
		_is_gliding = true

## Stop gliding (for AI control)
func stop_gliding() -> void:
	_is_gliding = false

func _calculate_movement_factor(delta: float, character_position: Vector2) -> Vector2:
	# Gliding doesn't add movement
	# It modifies gravity through get_glide_multiplier()
	# This is handled in BaseCharacter._calculate_gravity()
	return Vector2.ZERO
