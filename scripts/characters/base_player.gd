## BasePlayer - Base class for all player characters
##
## Inherits from BaseCharacter and adds player-specific functionality:
## - Input handling
## - Camera management
## - Player-specific controls
##
## Specific player types (Wool, etc.) inherit from this.
class_name BasePlayer
extends BaseCharacter

enum PlayerState { IDLE, WALK, GRAPPLE, JUMP }

var current_anim_state: PlayerState = PlayerState.IDLE

# === CONSTANTS ===
# Removed constants in favor of Tweakables

# === EXPORTED VARIABLES ===
@export var can_control: bool = true

# === PUBLIC VARIABLES ===
var acceleration: float
var friction: float
var jump_velocity: float
var camera_zoom: float

# === PRIVATE VARIABLES ===
var _direction: float = 0.0
var _vertical_direction: float = 0.0
var _debug_key_pressed: Dictionary = {}  # Track key state for debouncing
var _debug_ui: PlayerDebugUI = null
var _interaction_prompt_label: Label = null
var _current_prompt_interaction: Interaction = null
const INTERACTION_PROMPT_DISTANCE: float = 500.0
var _just_jumped: bool = false
var _coyote_timer: float = 0.0 # Buffer to allow jumping shortly after leaving ground
var _grapple_kick: float = 0.0 # Rotation impulse for grappling "Schwung holen"

# Feature Management
var _default_features: Array[Feature] = []
var _picked_up_features: Array[Feature] = []
var _last_camera_x: float = -INF
# Pickaxe initial state - REMOVED (Specific to Wool)
# var _initial_pickaxe_position: Vector2
# ...

# === ONREADY VARIABLES ===
@onready var camera: Camera2D = $Camera2D if has_node("Camera2D") else null
@onready var grappling_feature: GrapplingFeature = get_feature_by_type(GrapplingFeature)

# === BUILT-IN METHODS ===
func _ready() -> void:
	super._ready()

	add_to_group("player")

	# Set floor snap length to ensure we stick to slopes
	floor_snap_length = 32.0

	# Ensure essential nodes exist
	assert(skin != null, "BasePlayer: Skin node is missing!")

	if camera:
		camera.top_level = true
		_last_camera_x = camera.global_position.x

	# Connect terrain signals for debug UI
	terrain_entered.connect(func(_t): _update_debug_ui())
	terrain_exited.connect(func(_t): _update_debug_ui())

	# Get features after they're setup
	call_deferred("_setup_player_features")
	call_deferred("_update_form_state")

	# Setup debug UI
	# call_deferred("_setup_debug_ui")
	call_deferred("_setup_interaction_prompt_label")

func die() -> void:
	# Disable control
	can_control = false
	velocity = Vector2.ZERO

	# Slow motion effect
	Engine.time_scale = 0.5

	# Show Game Over Screen immediately as overlay
	var game_over_scene = load("res://scenes/ui/game_over.tscn")
	if game_over_scene:
		# Create a temporary CanvasLayer to ensure UI is drawn on top of the paused game
		var canvas_layer = CanvasLayer.new()
		canvas_layer.layer = 100 # High layer priority
		get_tree().root.add_child(canvas_layer)

		var game_over_instance = game_over_scene.instantiate()
		canvas_layer.add_child(game_over_instance)
	else:
		# Fallback if scene missing
		get_tree().reload_current_scene()

func attack() -> void:
	# Virtual method - override in child classes (e.g. Wool)
	pass

func _setup_tweakables() -> void:
	super._setup_tweakables()

	# Initial load
	acceleration = CharacterConstants.get_value("Player", "acceleration")
	friction = CharacterConstants.get_value("Player", "friction")
	jump_velocity = CharacterConstants.get_value("Player", "jump_velocity")
	camera_zoom = CharacterConstants.get_value("Player", "camera_zoom")

	if camera:
		camera.zoom = Vector2(camera_zoom, camera_zoom)

	# Listen for changes (super class already connected, but we need to handle our specific keys)
	# Note: We can't easily hook into the super connection if it doesn't expose a virtual method.
	# But BaseCharacter connects to _on_tweakable_changed. We should override it.

func _on_tweakable_changed(category: String, key: String, value: Variant) -> void:
	super._on_tweakable_changed(category, key, value)

	if category == "Player":
		match key:
			"acceleration": acceleration = float(value)
			"friction": friction = float(value)
			"jump_velocity": jump_velocity = float(value)
			"camera_zoom":
				camera_zoom = float(value)
				if camera:
					camera.zoom = Vector2(camera_zoom, camera_zoom)

func _setup_player_features() -> void:
	# Identify default features (those already enabled in the scene)
	# and picked up features (initially none, unless we save/load state)


	# First, get references to known feature types for easy access
	grappling_feature = get_feature_by_type(GrapplingFeature)

	# Clear lists
	_default_features.clear()

	# 1. Base Features (Always Active)
	# Features in the main "Features" node are considered default/base features
	if features_container:
		for child in features_container.get_children():
			if child is Feature:
				_default_features.append(child)
				# Force enable base features as they should be active from start
				if not child.enabled:
					child.enabled = true

				if not child.enabled_changed.is_connected(_on_feature_enabled_changed):
					child.enabled_changed.connect(_on_feature_enabled_changed)

	_update_skin_appearance()

## Called when a checkpoint is reached.
## Should be overridden by subclasses to reset specific state.
func checkpoint_reached() -> void:
	pass

## Called when a new feature is picked up (e.g. from FeaturePickup)
func pickup_feature(new_feature: Feature) -> void:
	# Deprecated: Feature picking up is simplified.
	# Features should be pre-added to the player scena or enabled via other means.
	if new_feature:
		new_feature.queue_free()

func _update_form_state() -> void:
	# Override in child classes (e.g. Wool)
	pass

func _play_animation_for_state(state: PlayerState) -> void:
	# Base implementation - simple idle/walk
	var target_anim = "idle"
	if state == PlayerState.WALK:
		target_anim = "walk"
	elif state == PlayerState.JUMP:
		target_anim = "jump"

	if skin:
		skin.play_animation(target_anim)

func _update_skin_appearance() -> void:
	# Virtual method to be overridden by subclasses
	pass

func _on_feature_enabled_changed(enabled: bool) -> void:
	_update_skin_appearance()
	_update_debug_ui()

# Virtual Methods for Override
func _calculate_player_state() -> PlayerState:
	if not is_on_floor():
		return PlayerState.JUMP
	if not is_zero_approx(velocity.x):
		return PlayerState.WALK
	return PlayerState.IDLE

func _should_force_animation_update() -> bool:
	return false

func _process(delta: float) -> void:
	_update_skin_appearance() # Check for changes every frame
	_update_rotation(delta) # Update facing first
	_update_interaction_prompt()
	_update_camera_and_bounds()

	# --- ANIMATION STATE MACHINE ---
	var new_state = _calculate_player_state()
	if new_state != current_anim_state or _should_force_animation_update():
		current_anim_state = new_state
		_play_animation_for_state(current_anim_state)
	# -------------------------------

# === OVERRIDDEN METHODS ===

func _process_physics(delta: float) -> void:
	# Update timers
	if is_on_floor():
		_coyote_timer = 0.15 # 150ms forgiveness
	else:
		_coyote_timer = max(0.0, _coyote_timer - delta)

	# Reset state
	_just_jumped = false
	floor_snap_length = 32.0

	if not can_control:
		return

	_handle_input()
	_handle_feature_inputs()
	# Specific feature inputs are now handled via _handle_feature_inputs calling feature.handle_input()
	_handle_movement(delta)


func _update_camera_and_bounds() -> void:
	if not camera or not can_control:
		return

	# 1. Update Camera Position (Only move RIGHT)
	# Target is player's current X position
	var target_x = global_position.x

	# Monotonic check: Only update if target is further right than last position
	if target_x > _last_camera_x:
		camera.global_position.x = target_x
		_last_camera_x = target_x
	else:
		# Lock camera to the furthest right point reached
		camera.global_position.x = _last_camera_x

	# Also sync Y (camera usually follows Y normally, unless requested otherwise)
	camera.global_position.y = global_position.y

	# 2. Check Left Edge Death
	# Get the viewport width to calculate the left edge
	var viewport_rect = get_viewport_rect()
	var half_width = (viewport_rect.size.x / camera.zoom.x) * 0.5
	var left_edge = camera.global_position.x - half_width

	# If player's X (plus some padding/margin if needed) is less than left_edge
	if global_position.x < left_edge:
		die()

# === PRIVATE METHODS ===

func _handle_input() -> void:
	# _direction = Input.get_axis("move_left", "move_right")
	_direction = 0.0
	# Use ui_up/down as default vertical controls since move_up/down are not defined
	# _vertical_direction = Input.get_axis("ui_up", "ui_down")
	_vertical_direction = 0.0

	var is_underwater := false
	if get_active_terrain_of_type(UnderWaterTerrain) != null:
		is_underwater = true

	# Jump (only if not underwater) -> Uses coyote time or floor check
	if not is_underwater and Input.is_action_just_pressed("jump"):

		if is_on_floor() or _coyote_timer > 0.0:
			_jump()
		else:
			pass





	# Attack
	# "attack" action is mapped to input (e.g. mouse click or key)
	# if Input.is_action_just_pressed("attack"):
	# 	attack()

	# Debug: Toggle features with number keys
	_handle_debug_feature_toggle()

func _toggle_feature(key: int, feature_ref: Feature, feature_name: String) -> void:
	if Input.is_physical_key_pressed(key):
		if not _debug_key_pressed.get(key, false):
			_debug_key_pressed[key] = true
			if feature_ref:
				feature_ref.enabled = not feature_ref.enabled
			else:
				pass
	else:
		_debug_key_pressed[key] = false

func _handle_debug_feature_toggle() -> void:
	_toggle_feature(KEY_3, grappling_feature, "Grappling")

func _handle_feature_inputs() -> void:
	# Let all features handle their own input
	for feature in get_features():
		if feature.enabled:
			feature.handle_input(self)

func _handle_movement(delta: float) -> void:
	# Explicitly check for Water terrain, regardless of what 'current_terrain' thinks (handling overlaps)
	var water_terrain = get_active_terrain_of_type(UnderWaterTerrain)

	if water_terrain:
		# Disable floor snapping when swimming to allow free vertical movement
		floor_snap_length = 0.0
		# We need to temporarily force current_terrain to be the water terrain
		# so the logic inside _handle_underwater_movement uses the correct params (buoyancy etc)
		# NOTE: This does NOT change the global 'current_terrain' variable, just for this scope if we passed it.
		# But _handle_underwater_movement uses 'current_terrain' property directly.
		# Instead, let's pass the terrain instance to the function.
		_handle_underwater_movement(delta, water_terrain)
		return

	if _direction != 0:
		if grappling_feature and grappling_feature.is_active():
			_handle_grapple_swing_pump(delta)
		else:
			_handle_ground_air_movement(delta)
	else:
		# Friction / Stopping
		var is_grappling: bool = grappling_feature and grappling_feature.is_active()
		if not is_grappling and is_on_floor() and not _just_jumped:
			# Apply friction along the slope
			var floor_normal = get_floor_normal()
			var tangent = Vector2(-floor_normal.y, floor_normal.x)
			if tangent.x < 0: tangent = -tangent

			var current_speed = velocity.dot(tangent)
			var new_speed = move_toward(current_speed, 0, friction * delta)
			velocity = tangent * new_speed

			# Apply downward force to keep on floor (same as moving state)
			velocity.y += 2.0
		elif not is_grappling:
			# Air friction
			velocity.x = move_toward(velocity.x, 0, friction * delta)

func _handle_underwater_movement(delta: float, underwater_terrain: UnderWaterTerrain = null) -> void:
	# Fallback if called without argument (for backward compat or if used elsewhere)
	if not underwater_terrain and current_terrain is UnderWaterTerrain:
		underwater_terrain = current_terrain as UnderWaterTerrain

	if not underwater_terrain:
		push_error("BasePlayer: _handle_underwater_movement called without valid UnderWaterTerrain context")
		return

	var speed: float = move_speed * underwater_terrain.slowdown_factor



	# Horizontal movement (always controlled)
	var target_velocity_x: float = _direction * speed
	velocity.x = move_toward(velocity.x, target_velocity_x, acceleration * delta)

	# Vertical movement
	if _vertical_direction != 0:
		# Player is actively swimming up/down
		var target_velocity_y: float = _vertical_direction * speed
		velocity.y = move_toward(velocity.y, target_velocity_y, acceleration * delta)
	else:
		# Native terrain damping (handled in BaseCharacter) will limit velocity.
		# We don't need additional manual damping here, otherwise we fight buoyancy.
		pass

func _handle_grapple_swing_pump(delta: float) -> void:
	# Swing pumping: Add force in direction of movement (tangential) to build momentum
	var speed_multiplier: float = move_speed / CharacterConstants.DEFAULT_MOVE_SPEED
	var force_magnitude: float = grappling_feature.swing_pump_force * speed_multiplier * delta

	# Only pump if we have movement and input matches general direction
	# Or if we're just starting and want to push in the input direction
	if velocity.length() > 10.0:
		var move_dir = velocity.normalized()
		# Only apply if input direction matches the horizontal component of movement
		if sign(_direction) == sign(move_dir.x) or _direction == 0:
			velocity += move_dir * force_magnitude * (1.0 if _direction != 0 else 0.0)
	else:
		# Initial push if nearly stationary
		velocity.x += _direction * force_magnitude

func _handle_ground_air_movement(delta: float) -> void:
	if is_on_floor() and not _just_jumped:
		# Move exactly along the slope (tangent)
		var floor_normal = get_floor_normal()
		var tangent = Vector2(-floor_normal.y, floor_normal.x)

		# Ensure tangent points generally right
		if tangent.x < 0:
			tangent = -tangent

		# Calculate new speed along the tangent
		# (Current velocity projected onto tangent)
		var current_speed = velocity.dot(tangent)
		var target_speed = _direction * move_speed

		# Momentum Preservation: Only accelerate/decelerate towards target if we are not already
		# moving faster than the target in that direction.
		if _direction != 0 and sign(current_speed) == sign(target_speed) and abs(current_speed) > abs(target_speed):
			# Already over-speed in the right direction, don't use move_toward (which would brake us)
			# Energy will be lost naturally via terrain damping
			pass
		else:
			current_speed = move_toward(current_speed, target_speed, acceleration * delta)

		velocity = tangent * current_speed

		# Apply a tiny downward force to ensure 'is_on_floor()' remains true and snapping works reliably
		# This prevents "floating" when moving down slopes rapidly

		velocity.y += 2.0
	else:
		# Global movement in air
		var target_x = _direction * move_speed

		# Momentum Preservation in air
		if _direction != 0 and sign(velocity.x) == sign(target_x) and abs(velocity.x) > abs(target_x):
			# Over-speed in air, let damping handle it
			pass
		else:
			velocity.x = move_toward(velocity.x, target_x, acceleration * delta)

		# Allow jumping immediately even if floor_snap_length was set to 0 previously
		if _just_jumped:
			floor_snap_length = 0.0

func _apply_slope_velocity_adjustment() -> void:
	# Deprecated/Unused for movement driving, but kept if needed for other adjustments
	var floor_normal := get_floor_normal()
	if floor_normal == Vector2.UP:
		return

	# Calculate tangent (slope direction)
	var tangent = Vector2(-floor_normal.y, floor_normal.x)

	# Ensure tangent points generally right (positive X)
	if tangent.x < 0:
		tangent = -tangent

	if abs(tangent.x) > 0.001:
		velocity.y = tangent.y * (velocity.x / tangent.x)

func _jump() -> void:
	# Note: jump_velocity is positive in settings, so we negate it for upward movement
	var effective_jump_velocity = jump_velocity
	if effective_jump_velocity <= 0.0:
		effective_jump_velocity = 400.0 # Safe fallback

	var jump_power: float = -effective_jump_velocity



	# Apply directly, ignoring previous frame overwrites
	velocity.y = jump_power

	# Disable floor snapping for this frame to allow takeoff
	floor_snap_length = 0.0
	# Nudge up slightly to break floor contact immediately
	position.y -= 2.0  # Increased nudge to ensure we clear the ground collision

	_just_jumped = true
	_coyote_timer = 0.0 # Consume coyote time

func _update_rotation(delta: float) -> void:
	if not skin:
		return

	# FIND Active Grappling Feature
	var active_grappling_feature: GrapplingFeature = null
	for feature in _features:
		if feature is GrapplingFeature and feature.is_active():
			active_grappling_feature = feature
			break

	# DEBUG: Diagnose why rotation is skipped
	# if Input.is_action_pressed("interact") and active_grappling_feature == null:


	# Handle flipping (standard platformer behavior)
	# Prioritize Input direction for responsiveness
	# Exception: Don't flip while grappling if we are holding momentum,
	# but actually we probably DO want to flip to face "forward" in the swing.
	if not is_zero_approx(_direction):
		_update_facing_direction(_direction < 0)
	# Fallback to velocity if moving significantly (e.g. knockback or drift)
	elif abs(velocity.x) > 10.0:
		_update_facing_direction(velocity.x < 0)

	# Check states
	var is_grappling = active_grappling_feature != null

	var is_underwater = current_terrain is UnderWaterTerrain
	var target_rotation = 0.0

	if is_grappling:
		var current_nail = active_grappling_feature.get_target_nail()
		if current_nail:
			var rope_vector = current_nail.global_position - global_position

			# "Schwung holen" Animation Logic
			# 1. Detect Impulse
			if Input.is_action_just_pressed("move_left"):
				_grapple_kick = deg_to_rad(-60.0) # Kick CCW (Left-Up)
			elif Input.is_action_just_pressed("move_right"):
				_grapple_kick = deg_to_rad(60.0)  # Kick CW (Right-Up)

			# 2. Decay Impulse
			_grapple_kick = move_toward(_grapple_kick, 0.0, delta * 4.0)

			# 3. Sustained Lean (Hold direction to swing)
			var target_lean = 0.0
			if _direction < 0: # Left
				target_lean = deg_to_rad(45.0)
			elif _direction > 0: # Right
				target_lean = deg_to_rad(-45.0)

			# If facing Left, negate lean angles to match sprite flipping?
			# Sprite flip handles local X scale -1.
			# Mathematical rotation 0 is RIGHT. PI is LEFT.
			# If flipped (scale.x < 0), then rotation usually points "forward" relative to flip.
			# Godot rotation is Global. Flipping scale.x flips the local X axis.
			# If we rotate 45 deg CW:
			#  - Facing Right: Beak points down-right.
			#  - Facing Left (Flipped): Beak points down-left?
			# Let's keep calculation simple first.

			# Align head with rope (rope angle + 90 deg) + Kick + Lean
			target_rotation = rope_vector.angle() + PI / 2.0 + _grapple_kick + target_lean

			# Print state
			# Rotation debug suppressed
	elif is_on_floor():
		# Align with floor slope
		target_rotation = get_floor_normal().angle() + PI / 2.0
	elif is_underwater:
		# Check for floor or proximity to floor to force upright standing
		# We use test_move to see if ground is immediately below us (e.g. within 16 pixels)
		# This prevents jitter when rotating upright lifts the collision shape slightly off the ground
		var close_to_floor = is_on_floor()
		if not close_to_floor and velocity.y >= 0: # Only check if falling/sinking
			close_to_floor = test_move(global_transform, Vector2(0, 16))

		if close_to_floor:
			target_rotation = 0.0
		# Otherwise calculate rotation based on velocity
		# We want the character to lean into the movement (Superman style)
		# Sprite Up is (0, -1). Velocity Angle 0 is Right.
		# So we need to add 90 degrees (PI/2) to align Up with Velocity.
		elif velocity.length() > 10.0:
			var angle = velocity.angle() + PI / 2.0
			angle = wrapf(angle, -PI, PI)

			if skin.scale.x > 0:
				# Facing Right
				# Allow rotation from slightly back (-30deg) to full down (180deg)
				target_rotation = clamp(angle, -PI/6, PI)
			else:
				# Facing Left
				# We expect angles in [-PI, 0].
				# If angle is PI (straight down), wrapf might return PI.
				# We want to treat positive PI as negative PI for clamping purposes.
				if angle > PI/2:
					angle -= 2 * PI

				# Allow rotation from full down (-180deg) to slightly back (30deg)
				target_rotation = clamp(angle, -PI, PI/6)

	# Apply rotation with smoothing to the WHOLE PLAYER (including pickaxe)
	# Lower value = smoother/slower rotation
	if is_underwater and not is_grappling:
		# Use lerp (linear) instead of lerp_angle (shortest path) for swimming
		# This prevents the rotation from crossing the bottom (PI/-PI boundary)
		# and forces the "long way" via the top (0) when switching sides.
		rotation = wrapf(rotation, -PI, PI) # Normalize first
		rotation = lerp(rotation, target_rotation, 5.0 * delta)
	elif is_grappling:
		# Very fast rotation for responsive swinging actions
		rotation = lerp_angle(rotation, target_rotation, 20.0 * delta)
	else:
		# Faster rotation on floor to prevent floating visuals during slope changes
		var rotate_speed = 15.0 if is_on_floor() else 5.0
		rotation = lerp_angle(rotation, target_rotation, rotate_speed * delta)

	# Fix floating on slopes:
	# When rotating around the center, the feet (bottom of sprite) lift up relative to the contact point.
	# We lower the skin slightly based on the rotation angle to compensate.
	# A heuristic of ~10px offset at 90 degrees works well for typical sprites.
	var slope_offset = abs(sin(rotation)) * 10.0
	if is_on_floor():
		skin.position.y = slope_offset
	else:
		skin.position.y = lerp(skin.position.y, 0.0, 10.0 * delta)

## Update visual facing direction
## Can be overridden by child classes to handle specialized shapes
func _update_facing_direction(is_facing_left: bool) -> void:
	if skin:
		if is_facing_left:
			skin.scale.x = -abs(skin.scale.x)
			if has_node("HitboxArea"): $HitboxArea.scale.x = -abs($HitboxArea.scale.x)
		else:
			skin.scale.x = abs(skin.scale.x)
			if has_node("HitboxArea"): $HitboxArea.scale.x = abs($HitboxArea.scale.x)

func _update_interaction_prompt() -> void:
	var closest_interaction: Interaction = null

	if not nearby_interactions.is_empty():
		var closest_dist: float = INF

		for interaction in nearby_interactions:
			if not is_instance_valid(interaction) or not interaction.is_active:
				continue

			var dist: float = global_position.distance_to(interaction.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_interaction = interaction

	if nearby_interactions.size() > 0:
		pass


	if closest_interaction != _current_prompt_interaction:
		_current_prompt_interaction = closest_interaction
		if closest_interaction:
			_show_interaction_prompt(closest_interaction)
		elif _interaction_prompt_label:
			_interaction_prompt_label.visible = false

func _show_interaction_prompt(interaction: Interaction) -> void:
	if not is_instance_valid(_interaction_prompt_label):
		return

	var action = interaction.prompt_action
	var text = interaction.prompt_text

	if action == "" and text == "":
		_interaction_prompt_label.visible = false
		return

	var key_text = ""
	if action != "":
		var events = InputMap.action_get_events(action)
		if events.size() > 0:
			key_text = events[0].as_text().split(" ")[0]

	var prompt = ""
	if key_text != "":
		prompt = "Drücke %s, um %s zu tun" % [key_text, text]
	else:
		prompt = text

	_interaction_prompt_label.text = prompt
	_interaction_prompt_label.visible = true

## Setup interaction prompt label
func _setup_interaction_prompt_label() -> void:
	if has_node("InteractionPromptLabel"):
		_interaction_prompt_label = $InteractionPromptLabel
	else:
		_interaction_prompt_label = Label.new()
		_interaction_prompt_label.name = "InteractionPromptLabel"
		add_child(_interaction_prompt_label)

		# Configure label style
		_interaction_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_interaction_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_interaction_prompt_label.position = Vector2(-100, -150) # Above head (approx)
		_interaction_prompt_label.size = Vector2(200, 30)
		_interaction_prompt_label.visible = false

		# Optional: Load a custom font or style if available
		# var font = load("res://assets/fonts/my_font.ttf")
		# if font: _interaction_prompt_label.add_theme_font_override("font", font)

## Setup debug UI to show active features
func _setup_debug_ui() -> void:
	_debug_ui = PlayerDebugUI.new()
	add_child(_debug_ui)
	_debug_ui.setup(self)

## Update debug UI text
func _update_debug_ui() -> void:
	if _debug_ui:
		_debug_ui.update_ui()
