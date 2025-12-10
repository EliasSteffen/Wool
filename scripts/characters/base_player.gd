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

# Feature Management
var _default_features: Array[Feature] = []
var _picked_up_features: Array[Feature] = []

# Pickaxe initial state
var _initial_pickaxe_position: Vector2
var _initial_pickaxe_rotation: float
var _initial_pickaxe_scale: Vector2
var _initial_pickaxe_centered: bool
var _initial_pickaxe_offset: Vector2
var _is_attacking: bool = false

# === ONREADY VARIABLES ===
@onready var camera: Camera2D = $Camera2D if has_node("Camera2D") else null
@onready var pickaxe: Node2D = $Pickaxe if has_node("Pickaxe") else null
@onready var pickaxe_sprite: Sprite2D = $Pickaxe/Sprite2D if has_node("Pickaxe/Sprite2D") else ($Pickaxe as Sprite2D if has_node("Pickaxe") else null)
@onready var pickaxe_hitbox: Area2D = $Pickaxe/Hitbox if has_node("Pickaxe/Hitbox") else null
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

	# Capture initial pickaxe state
	if pickaxe:
		_initial_pickaxe_position = pickaxe.position
		_initial_pickaxe_rotation = pickaxe.rotation
		_initial_pickaxe_scale = pickaxe.scale

	if pickaxe_sprite:
		_initial_pickaxe_centered = pickaxe_sprite.centered
		_initial_pickaxe_offset = pickaxe_sprite.offset

	if pickaxe_hitbox:
		pickaxe_hitbox.body_entered.connect(_on_pickaxe_hitbox_body_entered)

	# Connect terrain signals for debug UI
	terrain_entered.connect(func(_t): _update_debug_ui())
	terrain_exited.connect(func(_t): _update_debug_ui())

	# Get features after they're setup
	call_deferred("_setup_player_features")
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
	_is_attacking = true

	# Enable hitbox
	if pickaxe_hitbox:
		pickaxe_hitbox.monitoring = true

	# Animate pickaxe
	if pickaxe:
		var tween = create_tween()
		tween.set_parallel(true)

		# Determine forward direction based on current position
		var forward_dir = Vector2.RIGHT
		var rotation_mod = 100

		if pickaxe.position.x < 0:
			forward_dir = Vector2.LEFT
			rotation_mod = -100

		# Capture current state as start/end point
		var start_pos = pickaxe.position
		var start_rot_deg = pickaxe.rotation_degrees

		# Move pickaxe forward to extend range ("full length")
		var target_pos = start_pos + (forward_dir * 40.0)

		# Swing down and move forward
		tween.tween_property(pickaxe, "rotation_degrees", start_rot_deg + rotation_mod, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(pickaxe, "position", target_pos, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)		# Swing back and return to position
		tween.chain().tween_property(pickaxe, "rotation_degrees", start_rot_deg, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(pickaxe, "position", start_pos, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

		await tween.finished

	# Disable hitbox
	if pickaxe_hitbox:
		pickaxe_hitbox.monitoring = false

	_is_attacking = false

func _on_pickaxe_hitbox_body_entered(body: Node2D) -> void:
	if body is BaseEnemy:
		body.die()

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

	# Setup pickaxe sprite if it's directly a Sprite2D
	if pickaxe is Sprite2D and not pickaxe_sprite:
		pickaxe_sprite = pickaxe

	_update_skin_appearance()## Called when a new feature is picked up (e.g. from FeaturePickup)
func pickup_feature(new_feature: Feature) -> void:
	if not new_feature:
		return

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

	# Determine which animation to play based on active features
	# Priority: Wings > Swim > Glide > DoubleJump
	if wings_feature and wings_feature.enabled:
		skin.play_animation("wings")
	elif swim_feature and swim_feature.enabled:
		skin.play_animation("swim")
	elif glide_feature and glide_feature.enabled:
		skin.play_animation("glide")
	elif double_jump_feature and double_jump_feature.enabled:
		skin.play_animation("double-jump")
	else:
		skin.play_animation("default")

func _process(delta: float) -> void:
	_update_rotation(delta) # Update facing first
	_update_pickaxe_visual() # Then update pickaxe based on facing
	_update_interaction_prompt()

# === OVERRIDDEN METHODS ===

func _process_physics(delta: float) -> void:
	if not can_control:
		return

	_handle_input()
	_handle_feature_inputs()
	_handle_grappling_input()
	_handle_push_input()
	_handle_movement(delta)

# === PRIVATE METHODS ===

func _handle_input() -> void:
	_direction = Input.get_axis("move_left", "move_right")
	_vertical_direction = Input.get_axis("move_up", "move_down")
	if _vertical_direction == 0.0:
		_vertical_direction = Input.get_axis("ui_up", "ui_down")

	var is_underwater = current_terrain is UnderWaterTerrain

	# Jump (only if not underwater)
	if not is_underwater and Input.is_action_just_pressed("jump") and is_on_floor():
		_jump()

	# Swim Up with Jump button
	if is_underwater and Input.is_action_pressed("jump"):
		_vertical_direction = -1.0

	# Attack
	if Input.is_key_pressed(KEY_V) and not _is_attacking:
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
	# 1 = DoubleJump
	_toggle_feature(KEY_1, double_jump_feature, "DoubleJump")

	# 2 = Glide
	_toggle_feature(KEY_2, glide_feature, "Glide")

	# 3 = Grappling
	_toggle_feature(KEY_3, grappling_feature, "Grappling")

	# 4 = Wings
	_toggle_feature(KEY_4, wings_feature, "Wings")

	# 5 = Cut
	_toggle_feature(KEY_5, cut_feature, "Cut")

func _handle_feature_inputs() -> void:
	# Let all features handle their own input
	for feature in get_features():
		if feature.enabled:
			feature.handle_input(self)

func _handle_grappling_input() -> void:
	if not grappling_feature or not grappling_feature.enabled:
		return

	if Input.is_action_just_pressed("grapple"):
		var nail: Nail = _find_nearest_nail()
		if nail:
			grappling_feature.set_target(nail.get_grapple_point(), nail)

	if Input.is_action_just_released("grapple"):
		grappling_feature.release()

func _handle_push_input() -> void:
	if not push_feature or not push_feature.enabled:
		return

	# Check if moving towards a box
	var box: Box = _find_nearest_box()
	if box and _direction != 0:
		var direction_to_box: float = sign(box.global_position.x - global_position.x)
		if sign(_direction) == direction_to_box:
			push_feature.start_pushing(box)
		else:
			push_feature.stop_pushing()
	else:
		push_feature.stop_pushing()

func _handle_movement(delta: float) -> void:
	var is_grappling: bool = grappling_feature and grappling_feature.is_active()

	if current_terrain is UnderWaterTerrain:
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
			# Player is not swimming vertically -> Apply sinking/buoyancy
			# Gravity is already applied in BaseCharacter._physics_process()
			# Buoyancy is applied in BaseCharacter via current_terrain.get_movement_factor()
			# We just need to make sure we don't reset velocity.y to 0 here.

			# Apply water resistance (damping) to vertical velocity to prevent infinite acceleration
			# This acts as terminal velocity underwater
			velocity.y = move_toward(velocity.y, 0, underwater_terrain.water_resistance * 100.0 * delta)

		return

	if _direction != 0:
		if is_grappling:
			# Swing pumping: Add force in direction of input to build momentum
			# This simulates leaning forward/backward on a swing

			# Scale pump force by the player's move_speed so that agility upgrades feel consistent
			# We use DEFAULT_MOVE_SPEED as a reference base speed to normalize the multiplier
			var speed_multiplier: float = move_speed / CharacterConstants.DEFAULT_MOVE_SPEED
			var pump_force: float = _direction * grappling_feature.swing_pump_force * speed_multiplier * delta
			velocity.x += pump_force
		else:
			# Normal ground/air movement
			velocity.x = move_toward(velocity.x, _direction * move_speed, acceleration * delta)

			# Apply push slowdown if pushing
			if push_feature and push_feature.is_pushing():
				velocity.x *= push_feature.get_push_slowdown()
	else:
		# Only apply friction when ON THE GROUND and NOT grappling
		# In air: momentum is preserved, terrain damping handles energy loss
		if not is_grappling and is_on_floor():
			velocity.x = move_toward(velocity.x, 0, friction * delta)

func _jump() -> void:
	# Note: jump_velocity is positive in settings, so we negate it for upward movement
	var jump_power: float = -jump_velocity

	# Apply wings boost if available
	if wings_feature and wings_feature.enabled and wings_feature.is_active():
		jump_power *= wings_feature.get_jump_boost()

	velocity.y = jump_power

func _find_nearest_nail() -> Nail:
	var nearest: Nail = null
	var nearest_distance: float = INF

	# Clean up stale interactions first
	var stale_interactions: Array[Interaction] = []

	for interaction in nearby_interactions:
		if interaction is Nail:
			# Double check if we are still overlapping (physics safety check)
			if not interaction.overlaps_body(self):
				stale_interactions.append(interaction)
				continue

			# Triple check: Strict distance check against detection radius
			# This prevents grappling from outside the visual circle if physics is imprecise
			var distance: float = global_position.distance_to(interaction.global_position)
			var radius: float = interaction.get_detection_radius()

			if radius > 0 and distance > radius:
				continue

			if distance < nearest_distance:
				nearest = interaction
				nearest_distance = distance

	# Remove stale interactions
	for interaction in stale_interactions:
		remove_nearby_interaction(interaction)

	return nearest

func _find_nearest_box() -> Box:
	var nearest: Box = null
	var nearest_distance: float = INF

	for interaction in nearby_interactions:
		if interaction is Box:
			var distance: float = global_position.distance_to(interaction.global_position)
			if distance < nearest_distance:
				nearest = interaction
				nearest_distance = distance

	return nearest

## Update pickaxe visual based on grappling state
func _update_pickaxe_visual() -> void:
	if not pickaxe or not pickaxe_sprite:
		return

	var is_grappling: bool = grappling_feature and grappling_feature.is_active()
	var current_nail: Nail = null

	if is_grappling and grappling_feature:
		current_nail = grappling_feature.get_target_nail() as Nail

	if is_grappling and current_nail:
		# Show pickaxe as rope stretching from player to nail
		pickaxe.visible = true

		# c_player und c_nail definieren
		var c_player: Vector2 = global_position
		var c_nail: Vector2 = current_nail.global_position

		# Vektor und Distanz zwischen den Punkten
		var rope_vector: Vector2 = c_nail - c_player
		var rope_distance: float = rope_vector.length()
		var rope_angle: float = rope_vector.angle()

		# Original Sprite-Dimensionen
		var texture_size: Vector2 = pickaxe_sprite.texture.get_size()
		# Diagonale von c zu b im unskaliertem Sprite (von links-unten zu rechts-oben)
		var original_diagonal: float = Vector2(texture_size.x, texture_size.y).length()

		# Skalierung so berechnen, dass Diagonale c->b = rope_distance
		var scale_factor: float = rope_distance / original_diagonal
		pickaxe.scale = Vector2(scale_factor, scale_factor)

		# Pickaxe auf Mittelpunkt zwischen c_player und c_nail positionieren
		var midpoint: Vector2 = c_player + rope_vector * 0.5
		pickaxe.global_position = midpoint

		# Rotation: c zeigt zu c_player, b zeigt zu c_nail
		# Die Diagonale c->b entspricht dem Vektor (texture_width, texture_height) im Sprite
		# Wir müssen also so rotieren, dass dieser Vektor mit rope_vector übereinstimmt
		var diagonal_angle: float = atan2(texture_size.y, texture_size.x)
		pickaxe.global_rotation = rope_angle - diagonal_angle + PI

		# Sprite zentriert zeichnen
		pickaxe_sprite.centered = true
		pickaxe_sprite.offset = Vector2.ZERO
	else:
		if _is_attacking:
			return

		# Restore initial pickaxe state (as set in scene)
		pickaxe.visible = true
		pickaxe_sprite.centered = _initial_pickaxe_centered
		pickaxe_sprite.offset = _initial_pickaxe_offset

		# Handle facing direction
		var facing_left = skin.scale.x < 0

		if facing_left:
			pickaxe.position = Vector2(-_initial_pickaxe_position.x, _initial_pickaxe_position.y)
			pickaxe.scale = Vector2(-_initial_pickaxe_scale.x, _initial_pickaxe_scale.y)
			# Rotation is mirrored by negative scale.x, so we keep the value
			pickaxe.rotation = _initial_pickaxe_rotation
		else:
			pickaxe.position = _initial_pickaxe_position
			pickaxe.scale = _initial_pickaxe_scale
			pickaxe.rotation = _initial_pickaxe_rotation

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
