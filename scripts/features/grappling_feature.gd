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

## Max Rope Length
## Limits how long the "rope" (pickaxe reach) can extend.
## If distance to target > max_rope_length, the grapple will connect
## but constrain the player to this length immediately (pulling them in).
@export var max_rope_length: float = 300.0

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
var _input_buffer_timer: float = 0.0
const GRAPPLE_TOLERANCE: float = 20.0 # Extra pixels to allow grappling (compensates for character width)

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
		"initial_pull_strength": "initial_pull_strength",
		"max_rope_length": "max_rope_length"
	}, "", ["max_rope_length"])

func _process(delta: float) -> void:
	# Input Buffering: Retry grapple if button was pressed recently
	if _input_buffer_timer > 0.0:
		_input_buffer_timer -= delta
		if _input_buffer_timer > 0.0 and not is_active():
			var character = get_character()
			if character:
				_try_start_grapple(character)

# === PUBLIC METHODS ===

## Set the grapple target position (called by character)
func set_target(target_position: Vector2, nail: Interaction = null) -> void:
	_input_buffer_timer = 0.0 # Reset buffer on success
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

		# Adapt rope length to current distance if we are further out (due to scale/tolerance)
		# This prevents snapping the character into the circle if they grapple from the edge
		if character:
			var current_dist: float = character.global_position.distance_to(target_position)
			if current_dist > rope_length:
				rope_length = current_dist

		# === LIMIT MAX ROPE LENGTH ===
		# Override everything if it exceeds the hard limit.
		# This ensures that even if we are far away, the physics target radius is capped.
		if rope_length > max_rope_length:
			rope_length = max_rope_length

			# FORCE IMMEDIATE CONSTRAINT:
			# If we are clamping, the character is likely far away.
			# We must ensure the Character is aware that the legal rope is shorter.
			_has_reached_rope_length = true

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
	if Input.is_action_just_pressed("interact"):
		# Try immediately
		_try_start_grapple(character)

		# If not successful immediately, start buffer timer
		if not is_active():
			_input_buffer_timer = 0.15 # 150ms buffer

	if Input.is_action_just_released("interact"):
		release()

func _try_start_grapple(character: BaseCharacter) -> void:
	var nail: Nail = _find_nearest_nail(character)
	if nail:
		print("DEBUG: [Grapple] Success! Target: ", nail.name)
		set_target(nail.get_grapple_point(), nail)

func _find_nearest_nail(character: BaseCharacter) -> Nail:
	var nearest: Nail = null
	var nearest_distance: float = INF

	for interaction in character.nearby_interactions:
		var nail := interaction as Nail
		if not nail:
			continue

		# Strict distance check against detection radius with TOLERANCE
		var distance: float = character.global_position.distance_to(nail.global_position)
		var radius: float = nail.get_detection_radius()

		# Scale tolerance by character scale to support larger characters
		# This prevents rejection when a large character is touching the zone edge but their center is far out
		var scaled_tolerance: float = GRAPPLE_TOLERANCE * max(character.scale.x, character.scale.y)

		# Allow if distance is within radius + tolerance
		# This handles cases where character shape overlaps nail shape but centers are far
		if radius > 0 and distance > (radius + scaled_tolerance):
			# print("DEBUG: [Grapple] Rejected %s (Dist: %.1f > Rad+Tol: %.1f)" % [nail.name, distance, radius + GRAPPLE_TOLERANCE])
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
