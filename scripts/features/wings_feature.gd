## WingsFeature - Lets you jump higher and fall slower
##
## This feature modifies jump height and gravity for the character.
## Always active if enabled (no activation condition needed).
class_name WingsFeature
extends Feature

# === EXPORTED VARIABLES ===
# Removed exports in favor of Tweakables

# === PUBLIC VARIABLES ===
var jump_boost_multiplier: float
var fall_speed_multiplier: float
var glide_threshold: float

# === PRIVATE VARIABLES ===
var _is_gliding: bool = false

# === BUILT-IN METHODS ===
func _ready() -> void:
	super._ready()
	feature_name = "Wings"
	_setup_tweakables()
	# Wings are always active if enabled
	if enabled:
		activate()

func _setup_tweakables() -> void:
	jump_boost_multiplier = FeatureConstants.get_value("Wings", "jump_boost_multiplier")
	fall_speed_multiplier = FeatureConstants.get_value("Wings", "fall_speed_multiplier")
	glide_threshold = FeatureConstants.get_value("Wings", "glide_threshold")
	FeatureConstants.value_changed.connect(_on_tweakable_changed)

func _on_tweakable_changed(category: String, key: String, value: Variant) -> void:
	if category == "Wings":
		match key:
			"jump_boost_multiplier": jump_boost_multiplier = float(value)
			"fall_speed_multiplier": fall_speed_multiplier = float(value)
			"glide_threshold": glide_threshold = float(value)

# === PUBLIC METHODS ===

## Get jump boost factor (called by character when jumping)
func get_jump_boost() -> float:
	if is_active():
		return jump_boost_multiplier
	return 1.0

## Get fall speed multiplier (called by character during gravity calculation)
func get_fall_speed_multiplier() -> float:
	if is_active():
		return fall_speed_multiplier
	return 1.0

## Get gravity multiplier (implements Feature base method)
func get_gravity_multiplier() -> float:
	return get_fall_speed_multiplier()

## Check if character is gliding
func is_gliding() -> bool:
	return _is_gliding

# === OVERRIDDEN METHODS ===

func _on_activated() -> void:
	pass

func _on_deactivated() -> void:
	_is_gliding = false

func _calculate_movement_factor(delta: float, character_position: Vector2) -> Vector2:
	# Wings don't directly modify movement vector
	# They modify jump height and fall speed through multipliers
	# Character calls get_jump_boost() and get_fall_speed_multiplier()
	return Vector2.ZERO
