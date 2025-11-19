## GrapplingFeature - Implements swinging on nearby nails
##
## This feature allows the character to swing on nails like a rope/pendulum.
## Activates when a Nail is in nearby_interactions and input is pressed.
## Implements rope constraint physics for realistic swinging.
class_name GrapplingFeature
extends Feature

# === SIGNALS ===
signal grapple_started(target: Vector2)
signal grapple_ended()

# === EXPORTED VARIABLES ===
# Removed exports in favor of Tweakables

# === PUBLIC VARIABLES ===
var rope_length: float
var max_boost_force: float
var max_swing_speed_for_boost: float
var tension_strength: float
var swing_pump_force: float
var damping: float
var initial_pull_strength: float

# === PRIVATE VARIABLES ===
var _grapple_target: Vector2 = Vector2.ZERO
var _target_nail: Interaction = null
var _has_reached_rope_length: bool = false  # Track if we've reached the rope length once

# === BUILT-IN METHODS ===
func _ready() -> void:
	feature_name = "Grappling"
	_setup_tweakables()

# === PUBLIC METHODS ===

func _setup_tweakables() -> void:
	rope_length = FeatureConstants.get_value("Grappling", "rope_length")
	max_boost_force = FeatureConstants.get_value("Grappling", "max_boost_force")
	max_swing_speed_for_boost = FeatureConstants.get_value("Grappling", "max_swing_speed")
	tension_strength = FeatureConstants.get_value("Grappling", "tension_strength")
	swing_pump_force = FeatureConstants.get_value("Grappling", "swing_pump_force")
	damping = FeatureConstants.get_value("Grappling", "damping")
	initial_pull_strength = FeatureConstants.get_value("Grappling", "initial_pull_strength")

	FeatureConstants.value_changed.connect(_on_tweakable_changed)

func _on_tweakable_changed(category: String, key: String, value: Variant) -> void:
	if category == "Grappling":
		match key:
			"rope_length": rope_length = float(value)
			"max_boost_force": max_boost_force = float(value)
			"max_swing_speed": max_swing_speed_for_boost = float(value)
			"tension_strength": tension_strength = float(value)
			"swing_pump_force": swing_pump_force = float(value)
			"damping": damping = float(value)
			"initial_pull_strength": initial_pull_strength = float(value)

## Set the grapple target position (called by character)
func set_target(target_position: Vector2, nail: Interaction = null) -> void:
	_grapple_target = target_position
	_target_nail = nail
	_has_reached_rope_length = false  # Reset flag for new grapple

	if nail:
		nail.set_used(true)

	activate()
	grapple_started.emit(target_position)

## Release the grapple
func release() -> void:
	if _target_nail:
		_target_nail.set_used(false)

	# Apply boost based on swing speed
	var character: BaseCharacter = get_character()
	if character:
		var speed: float = character.velocity.length()
		var boost_factor: float = clamp(speed / max_swing_speed_for_boost, 0.0, 1.0)

		if speed > 0:
			var boost_vector: Vector2 = character.velocity.normalized() * max_boost_force * boost_factor
			character.velocity += boost_vector

	_target_nail = null
	_has_reached_rope_length = false
	deactivate()
	grapple_ended.emit()

## Get current grapple target
func get_target() -> Vector2:
	return _grapple_target

## Get the nail being grappled to
func get_target_nail() -> Interaction:
	return _target_nail

# === OVERRIDDEN METHODS ===

func _on_activated() -> void:
	pass

func _on_deactivated() -> void:
	_grapple_target = Vector2.ZERO
	_has_reached_rope_length = false

func _calculate_movement_factor(delta: float, character_position: Vector2) -> Vector2:
	if _grapple_target == Vector2.ZERO:
		return Vector2.ZERO

	# Vector from character to grapple point
	var to_grapple: Vector2 = _grapple_target - character_position
	var distance: float = to_grapple.length()

	# Initial pull: Strong pull ONLY until we reach rope_length for the first time
	if not _has_reached_rope_length and distance > rope_length:
		var direction: Vector2 = to_grapple.normalized()
		var pull_force: Vector2 = direction * initial_pull_strength * delta
		return pull_force

	# Once we've reached rope_length, mark it
	if distance <= rope_length:
		_has_reached_rope_length = true

	# After initial pull: NO FORCE - constraint is handled in BaseCharacter
	return Vector2.ZERO
