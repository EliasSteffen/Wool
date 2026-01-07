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
	super._ready()
	feature_name = "Grappling"
	setup_tweakables_generic({
		"max_boost_force": "max_boost_force",
		"max_swing_speed": "max_swing_speed_for_boost",
		"tension_strength": "tension_strength",
		"swing_pump_force": "swing_pump_force",
		"damping": "damping",
		"initial_pull_strength": "initial_pull_strength"
	})

# === PUBLIC METHODS ===

## Set the grapple target position (called by character)
func set_target(target_position: Vector2, nail: Interaction = null) -> void:
	_grapple_target = target_position
	_target_nail = nail
	_has_reached_rope_length = true  # Always true to enforce constraint immediately

	# Set rope length to the Nail's detection radius
	# The "max range" is determined by the Nail's detection area (CollisionShape)
	var character: BaseCharacter = get_character()

	# If we have a nail, use its detection radius as the rope length
	# This means the rope will be as long as the max grapple distance
	if nail is Nail:
		rope_length = nail.get_detection_radius()
		# Safety check: if radius is invalid (0), fallback to distance
		if rope_length <= 1.0:
			push_warning("GrapplingFeature: Nail returned invalid radius, falling back to distance.")
			if character:
				rope_length = character.global_position.distance_to(target_position)
			else:
				rope_length = 100.0 # Absolute fallback
	else:
		# Fallback: use current distance if no nail (shouldn't happen normally)
		if character:
			rope_length = character.global_position.distance_to(target_position)
		else:
			rope_length = 100.0 # Absolute fallback

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

func handle_input(character: BaseCharacter) -> void:
	if Input.is_action_just_pressed("grapple"):
		_try_start_grapple(character)

	if Input.is_action_just_released("grapple"):
		release()

func _try_start_grapple(character: BaseCharacter) -> void:
	var nail: Nail = _find_nearest_nail(character)
	if nail:
		set_target(nail.get_grapple_point(), nail)

func _find_nearest_nail(character: BaseCharacter) -> Nail:
	var nearest: Nail = null
	var nearest_distance: float = INF

	for interaction in character.nearby_interactions:
		var nail := interaction as Nail
		if not nail:
			continue

		# Strict distance check against detection radius
		var distance: float = character.global_position.distance_to(nail.global_position)
		var radius: float = nail.get_detection_radius()

		if radius > 0 and distance > radius:
			continue

		if distance < nearest_distance:
			nearest = nail
			nearest_distance = distance

	return nearest

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

	# No initial pull force - we rely on BaseCharacter constraint

	# After initial pull: NO FORCE - constraint is handled in BaseCharacter
	return Vector2.ZERO
