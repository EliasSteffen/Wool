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

enum PlayerState { IDLE, WALK }
enum FormState { NORMAL, BUNNY, FISH, EAGLE }

var current_anim_state: PlayerState = PlayerState.IDLE
var current_form: FormState = FormState.NORMAL

const ANIMATION_MAP = {
	FormState.NORMAL: {
		PlayerState.IDLE: "walk_idle",
		PlayerState.WALK: "walk"
	},
	FormState.BUNNY: {
		PlayerState.IDLE: "double-jump_idle",
		PlayerState.WALK: "double-jump"
	},
	FormState.FISH: {
		PlayerState.IDLE: "swim_idle",
		PlayerState.WALK: "swim"
	},
	FormState.EAGLE: {
		PlayerState.IDLE: "glide_idle",
		PlayerState.WALK: "glide"
	}
}

# === CONSTANTS ===
# Removed constants in favor of Tweakables

# === EXPORTED VARIABLES ===
@export var can_control: bool = true
@export var max_picked_up_features: int = 1

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

# Feature Management
var _default_features: Array[Feature] = []
var _picked_up_features: Array[Feature] = []

# Pickaxe initial state - REMOVED (Specific to Wool)
# var _initial_pickaxe_position: Vector2
# ...

# === ONREADY VARIABLES ===
@onready var camera: Camera2D = $Camera2D if has_node("Camera2D") else null
@onready var pickupable_features_node: Node = $PickupableFeatures if has_node("PickupableFeatures") else null

@onready var grappling_feature: GrapplingFeature = get_feature_by_type(GrapplingFeature)
@onready var push_feature: PushFeature = get_feature_by_type(PushFeature)
@onready var wings_feature: WingsFeature = get_feature_by_type(WingsFeature)
@onready var double_jump_feature: DoubleJumpFeature = get_feature_by_type(DoubleJumpFeature)
@onready var glide_feature: GlideFeature = get_feature_by_type(GlideFeature)
@onready var swim_feature: SwimFeature = get_feature_by_type(SwimFeature)
var cut_feature: CutFeature

# === BUILT-IN METHODS ===
func _ready() -> void:
	super._ready()

	add_to_group("player")

	# Set floor snap length to ensure we stick to slopes
	floor_snap_length = 32.0

	# Ensure essential nodes exist
	assert(skin != null, "BasePlayer: Skin node is missing!")

	# Connect terrain signals for debug UI
	terrain_entered.connect(func(_t): _update_debug_ui())
	terrain_exited.connect(func(_t): _update_debug_ui())

	# Get features after they're setup
	call_deferred("_setup_player_features")
	call_deferred("_update_form_state")

	# Setup debug UI
	call_deferred("_setup_debug_ui")
	call_deferred("_setup_interaction_prompt_label")

func die() -> void:
	# Disable control
	can_control = false
	velocity = Vector2.ZERO

	# Play death animation if available (TODO)

	# Reload scene after a short delay
	await get_tree().create_timer(1.0).timeout
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
	push_feature = get_feature_by_type(PushFeature)
	wings_feature = get_feature_by_type(WingsFeature)
	double_jump_feature = get_feature_by_type(DoubleJumpFeature)
	glide_feature = get_feature_by_type(GlideFeature)
	swim_feature = get_feature_by_type(SwimFeature)
	cut_feature = get_feature_by_type(CutFeature)

	# Clear lists
	_default_features.clear()
	_picked_up_features.clear()

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

	# 2. Pickupable Features
	# Features in "PickupableFeatures" are considered picked up
	if pickupable_features_node:
		for child in pickupable_features_node.get_children():
			if child is Feature:
				# Ensure feature is registered with BaseCharacter
				if child not in get_features():
					add_feature(child)

				# Only track enabled features as "picked up" active features
				# Disabled features in this node might be placeholders or inactive
				if child.enabled:
					_picked_up_features.append(child)
					if not child.enabled_changed.is_connected(_on_feature_enabled_changed):
						child.enabled_changed.connect(_on_feature_enabled_changed)

	_update_skin_appearance()## Called when a new feature is picked up (e.g. from FeaturePickup)
func pickup_feature(new_feature: Feature) -> void:
	if not new_feature:
		return

	print("Player: Attempting to pickup feature type: ", new_feature.get_script().resource_path)

	var feature_to_activate: Feature = null

	# Check if we have this feature in our "pickupable" list
	if pickupable_features_node:
		for child in pickupable_features_node.get_children():
			if child.get_script() == new_feature.get_script():
				feature_to_activate = child
				break

	# The new_feature instance is just a carrier of information (type), we don't need it anymore
	new_feature.queue_free()

	if not feature_to_activate:
		print("Player does not have pickupable feature of type: %s" % new_feature.get_script().resource_path)
		return

	# Manage picked up features limit
	if _picked_up_features.size() >= max_picked_up_features:
		var old_feature = _picked_up_features.pop_front()
		if old_feature:
			old_feature.enabled = false

	_picked_up_features.append(feature_to_activate)
	feature_to_activate.enabled = true
	feature_to_activate.activate() # Explicitly activate the feature
	_update_form_state()

	# Ensure it is in the main features list for processing
	if feature_to_activate not in get_features():
		print("Adding picked up feature to main list: %s" % feature_to_activate.feature_name)
		add_feature(feature_to_activate)

	# Connect signal if not already connected
	if not feature_to_activate.enabled_changed.is_connected(_on_feature_enabled_changed):
		feature_to_activate.enabled_changed.connect(_on_feature_enabled_changed)	# Update references if needed
	_update_feature_references()
	_update_skin_appearance()
	_update_debug_ui()

func _deactivate_picked_up_feature(feature: Feature) -> void:
	if not feature:
		return
	feature.enabled = false
	feature.deactivate() # Explicitly deactivate

func _drop_feature(feature: Feature) -> void:
	# Legacy wrapper
	_deactivate_picked_up_feature(feature)

func _update_feature_references() -> void:
	# Refresh references to specific features
	grappling_feature = get_feature_by_type(GrapplingFeature)
	push_feature = get_feature_by_type(PushFeature)
	wings_feature = get_feature_by_type(WingsFeature)
	double_jump_feature = get_feature_by_type(DoubleJumpFeature)
	glide_feature = get_feature_by_type(GlideFeature)
	swim_feature = get_feature_by_type(SwimFeature)
	cut_feature = get_feature_by_type(CutFeature)

func _on_feature_enabled_changed(_enabled: bool) -> void:
	_update_skin_appearance()
	_update_debug_ui()

func _update_skin_appearance() -> void:
	if not skin:
		return

	var is_moving_x = not is_zero_approx(velocity.x)
	var is_moving_y = not is_zero_approx(velocity.y)
	# var is_grappling = grappling_feature and grappling_feature.is_active() # Grapple has no special animation state

	# Determine State
	var new_state = PlayerState.IDLE

	if is_moving_x:
		new_state = PlayerState.WALK
	elif current_form == FormState.FISH and is_moving_y:
		# Special case: Swimming vertically counts as walking/swimming
		new_state = PlayerState.WALK
	else:
		new_state = PlayerState.IDLE

	# Apply Animation only if state or form changed
	# (We check logic every frame, optimization could be added but this is safe)
	if current_anim_state != new_state or true: # or true to force re-check of form/anim combination
		current_anim_state = new_state
		_play_animation_for_state(new_state)


func _update_form_state() -> void:
	# Determine form based on active/enabled pickupable features
	# Priority: SWIM > GLIDE > DOUBLE_JUMP > NORMAL

	var old_form = current_form

	if swim_feature and swim_feature.enabled:
		current_form = FormState.FISH
	elif glide_feature and glide_feature.enabled:
		current_form = FormState.EAGLE
	elif double_jump_feature and double_jump_feature.enabled:
		current_form = FormState.BUNNY
	else:
		current_form = FormState.NORMAL

	if old_form != current_form:
		print("BasePlayer: Form Update -> ", FormState.keys()[current_form])

func _play_animation_for_state(state: PlayerState) -> void:
	var target_anim = "default"

	if ANIMATION_MAP.has(current_form) and ANIMATION_MAP[current_form].has(state):
		target_anim = ANIMATION_MAP[current_form][state]

	# Fallback Logic for missing "walk_idle", "double-jump_idle" etc.
	if skin and skin.animated_sprite:
		if not skin.animated_sprite.sprite_frames.has_animation(target_anim):
			# 1. Try generic "idle" for unset idle animations
			if target_anim.ends_with("_idle"):
				var base_name = target_anim.replace("_idle", "")
				# Try "double-jump" instead of "double-jump_idle"
				if skin.animated_sprite.sprite_frames.has_animation(base_name):
					target_anim = base_name
				# Or try generic "idle"
				elif skin.animated_sprite.sprite_frames.has_animation("idle"):
					target_anim = "idle"

			# 2. Last resort fallback
			elif not skin.animated_sprite.sprite_frames.has_animation(target_anim):
				if current_form == FormState.NORMAL:
					target_anim = "walk" if state == PlayerState.WALK else "idle"

	skin.play_animation(target_anim)

func _process(delta: float) -> void:
	_update_skin_appearance() # Check for changes every frame
	_update_rotation(delta) # Update facing first
	_update_interaction_prompt()

# === OVERRIDDEN METHODS ===

func _process_physics(delta: float) -> void:
	# Reset state
	_just_jumped = false
	floor_snap_length = 32.0

	if not can_control:
		return

	_handle_input()
	_handle_feature_inputs()
	# Specific feature inputs are now handled via _handle_feature_inputs calling feature.handle_input()
	_handle_movement(delta)

# === PRIVATE METHODS ===

func _handle_input() -> void:
	_direction = Input.get_axis("move_left", "move_right")
	# Use ui_up/down as default vertical controls since move_up/down are not defined
	_vertical_direction = Input.get_axis("ui_up", "ui_down")

	var is_underwater := current_terrain is UnderWaterTerrain

	# Jump (only if not underwater)
	if not is_underwater and Input.is_action_just_pressed("jump") and is_on_floor():
		_jump()

	# Swim Up with Jump button
	if is_underwater and Input.is_action_pressed("jump"):
		_vertical_direction = -1.0

	# Attack
	# "attack" action is mapped to input (e.g. mouse click or key)
	if Input.is_key_pressed(KEY_V):
		attack()

	# Debug: Toggle features with number keys
	_handle_debug_feature_toggle()

func _toggle_feature(key: int, feature_ref: Feature, feature_name: String) -> void:
	if Input.is_physical_key_pressed(key):
		if not _debug_key_pressed.get(key, false):
			_debug_key_pressed[key] = true
			if feature_ref:
				feature_ref.enabled = not feature_ref.enabled
				# Reactivate wings if re-enabled
				if feature_ref is WingsFeature:
					if feature_ref.enabled:
						feature_ref.activate()
					else:
						feature_ref.deactivate()
				print("%s: %s" % [feature_name, "ON" if feature_ref.enabled else "OFF"])
			else:
				print("%s: NOT FOUND (add to Features container)" % feature_name)
	else:
		_debug_key_pressed[key] = false

func _handle_debug_feature_toggle() -> void:
	_toggle_feature(KEY_1, double_jump_feature, "DoubleJump")
	_toggle_feature(KEY_2, glide_feature, "Glide")
	_toggle_feature(KEY_3, grappling_feature, "Grappling")
	_toggle_feature(KEY_4, wings_feature, "Wings")
	_toggle_feature(KEY_5, cut_feature, "Cut")

func _handle_feature_inputs() -> void:
	# Let all features handle their own input
	for feature in get_features():
		if feature.enabled:
			feature.handle_input(self)

func _handle_movement(delta: float) -> void:
	if current_terrain is UnderWaterTerrain:
		_handle_underwater_movement(delta)
		return

	if _direction != 0:
		if grappling_feature and grappling_feature.is_active():
			_handle_grapple_swing_pump(delta)
		else:
			_handle_ground_air_movement(delta)
	else:
		# Friction / Stopping
		var is_grappling: bool = grappling_feature and grappling_feature.is_active()
		if not is_grappling and is_on_floor():
			velocity.x = move_toward(velocity.x, 0, friction * delta)

func _handle_underwater_movement(delta: float) -> void:
	var underwater_terrain := current_terrain as UnderWaterTerrain
	var speed: float = move_speed * underwater_terrain.slowdown_factor

	# Apply swim boost if available
	if swim_feature and swim_feature.is_active():
		speed *= swim_feature.get_swim_speed_multiplier()

	# Horizontal movement (always controlled)
	var target_velocity_x: float = _direction * speed
	velocity.x = move_toward(velocity.x, target_velocity_x, acceleration * delta)

	# Vertical movement
	if _vertical_direction != 0:
		# Player is actively swimming up/down
		var target_velocity_y: float = _vertical_direction * speed
		velocity.y = move_toward(velocity.y, target_velocity_y, acceleration * delta)
	else:
		# Apply water resistance (damping) to vertical velocity to prevent infinite acceleration
		velocity.y = move_toward(velocity.y, 0, underwater_terrain.water_resistance * 100.0 * delta)

func _handle_grapple_swing_pump(delta: float) -> void:
	# Swing pumping: Add force in direction of input to build momentum
	var speed_multiplier: float = move_speed / CharacterConstants.DEFAULT_MOVE_SPEED
	var pump_force: float = _direction * grappling_feature.swing_pump_force * speed_multiplier * delta
	velocity.x += pump_force

func _handle_ground_air_movement(delta: float) -> void:
	# Normal ground/air movement
	velocity.x = move_toward(velocity.x, _direction * move_speed, acceleration * delta)

	# Adjust velocity to slope if on floor
	if is_on_floor() and not _just_jumped:
		_apply_slope_velocity_adjustment()

	# Apply push slowdown if pushing
	if push_feature and push_feature.is_pushing():
		velocity.x *= push_feature.get_push_slowdown()

func _apply_slope_velocity_adjustment() -> void:
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
	var jump_power: float = -jump_velocity

	# Apply wings boost if available
	if wings_feature and wings_feature.enabled and wings_feature.is_active():
		jump_power *= wings_feature.get_jump_boost()

	velocity.y = jump_power

	# Disable floor snapping for this frame to allow takeoff
	floor_snap_length = 0.0
	_just_jumped = true

func _update_rotation(delta: float) -> void:
	if not skin:
		return

	# Handle flipping (standard platformer behavior)
	# Prioritize Input direction for responsiveness
	if not is_zero_approx(_direction):
		if _direction > 0:
			skin.scale.x = abs(skin.scale.x)
		else:
			skin.scale.x = -abs(skin.scale.x)
	# Fallback to velocity if moving significantly (e.g. knockback or drift)
	elif abs(velocity.x) > 10.0:
		if velocity.x > 0:
			skin.scale.x = abs(skin.scale.x)
		else:
			skin.scale.x = -abs(skin.scale.x)

	# Check states
	var is_grappling = grappling_feature and grappling_feature.is_active()
	var is_underwater = current_terrain is UnderWaterTerrain
	var target_rotation = 0.0

	if is_grappling:
		var current_nail = grappling_feature.get_target_nail()
		if current_nail:
			var rope_vector = current_nail.global_position - global_position
			# Align head with rope (rope angle + 90 deg)
			target_rotation = rope_vector.angle() + PI / 2.0
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
	else:
		rotation = lerp_angle(rotation, target_rotation, 5.0 * delta)

	# Reset skin rotation to 0 so it aligns with the player
	skin.rotation = 0.0

	# Collision shape rotates automatically with the player node

func _setup_interaction_prompt_label() -> void:
	_interaction_prompt_label = Label.new()
	_interaction_prompt_label.visible = false
	_interaction_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_interaction_prompt_label.position = Vector2(-100, -100) # Above player
	_interaction_prompt_label.size = Vector2(200, 30)
	_interaction_prompt_label.z_index = 100
	_interaction_prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_interaction_prompt_label.add_theme_constant_override("outline_size", 4)
	add_child(_interaction_prompt_label)

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

	if closest_interaction != _current_prompt_interaction:
		_current_prompt_interaction = closest_interaction
		if closest_interaction:
			_show_interaction_prompt(closest_interaction)
		elif _interaction_prompt_label:
			_interaction_prompt_label.visible = false

func _show_interaction_prompt(interaction: Interaction) -> void:
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

## Setup debug UI to show active features
func _setup_debug_ui() -> void:
	_debug_ui = PlayerDebugUI.new()
	add_child(_debug_ui)
	_debug_ui.setup(self)

## Update debug UI text
func _update_debug_ui() -> void:
	if _debug_ui:
		_debug_ui.update_ui()
