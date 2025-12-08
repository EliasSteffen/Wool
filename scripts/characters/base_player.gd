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

# === PUBLIC VARIABLES ===
var acceleration: float
var friction: float
var jump_velocity: float
var camera_zoom: float

# === PRIVATE VARIABLES ===
var _direction: float = 0.0
var _debug_key_pressed: Dictionary = {}  # Track key state for debouncing
var _debug_label: Label = null  # Debug UI label for feature status
var _interaction_prompt_label: Label = null
var _all_interactions: Array[Interaction] = []
const INTERACTION_PROMPT_DISTANCE: float = 500.0

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
@onready var grappling_feature: GrapplingFeature = get_feature_by_type(GrapplingFeature)
@onready var push_feature: PushFeature = get_feature_by_type(PushFeature)
@onready var wings_feature: WingsFeature = get_feature_by_type(WingsFeature)
@onready var double_jump_feature: DoubleJumpFeature = get_feature_by_type(DoubleJumpFeature)
@onready var glide_feature: GlideFeature = get_feature_by_type(GlideFeature)
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

	# Get features after they're setup
	call_deferred("_get_features")
	# Setup debug UI
	call_deferred("_setup_debug_ui")
	call_deferred("_setup_interaction_prompt_label")
	call_deferred("_collect_all_interactions")

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
		if pickaxe.position.x < 0:
			forward_dir = Vector2.LEFT

		# Move pickaxe forward to extend range ("full length")
		var target_pos = _initial_pickaxe_position + (forward_dir * 40.0)

		# Swing down and move forward
		tween.tween_property(pickaxe, "rotation_degrees", _initial_pickaxe_rotation + 100, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(pickaxe, "position", target_pos, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		# Swing back and return to position
		tween.chain().tween_property(pickaxe, "rotation_degrees", _initial_pickaxe_rotation, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(pickaxe, "position", _initial_pickaxe_position, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

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

func _get_features() -> void:
	grappling_feature = get_feature_by_type(GrapplingFeature)
	push_feature = get_feature_by_type(PushFeature)
	wings_feature = get_feature_by_type(WingsFeature)
	double_jump_feature = get_feature_by_type(DoubleJumpFeature)
	glide_feature = get_feature_by_type(GlideFeature)

	# Ensure CutFeature exists
	cut_feature = get_feature_by_type(CutFeature)
	if not cut_feature:
		print("BasePlayer: CutFeature not found, creating it...")
		cut_feature = CutFeature.new()
		cut_feature.name = "CutFeature"
		if features_container:
			features_container.add_child(cut_feature)
		else:
			add_child(cut_feature)

	# Setup pickaxe sprite if it's directly a Sprite2D
	if pickaxe is Sprite2D and not pickaxe_sprite:
		pickaxe_sprite = pickaxe

func _process(delta: float) -> void:
	_update_pickaxe_visual()
	_update_debug_ui()
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

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		_jump()

	# Attack
	if Input.is_key_pressed(KEY_V) and not _is_attacking:
		attack()

	# Debug: Toggle features with number keys
	_handle_debug_feature_toggle()

func _handle_debug_feature_toggle() -> void:
	# Helper function to toggle a feature with debouncing
	var toggle_feature = func(key: int, feature_ref: Feature, feature_name: String) -> void:
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
					_update_debug_ui()
				else:
					print("%s: NOT FOUND (add to Features container)" % feature_name)
		else:
			_debug_key_pressed[key] = false

	# 1 = DoubleJump
	toggle_feature.call(KEY_1, double_jump_feature, "DoubleJump")

	# 2 = Glide
	toggle_feature.call(KEY_2, glide_feature, "Glide")

	# 3 = Grappling
	toggle_feature.call(KEY_3, grappling_feature, "Grappling")

	# 4 = Wings
	toggle_feature.call(KEY_4, wings_feature, "Wings")

	# 5 = Cut
	toggle_feature.call(KEY_5, cut_feature, "Cut")

func _handle_feature_inputs() -> void:
	# Let all features handle their own input
	for feature in get_features():
		if feature.enabled:
			feature.handle_input(self)

func _handle_grappling_input() -> void:
	if not grappling_feature:
		return

	if Input.is_action_just_pressed("grapple"):
		var nail: Nail = _find_nearest_nail()
		if nail:
			grappling_feature.set_target(nail.get_grapple_point(), nail)

	if Input.is_action_just_released("grapple"):
		grappling_feature.release()

func _handle_push_input() -> void:
	if not push_feature:
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
	if wings_feature and wings_feature.is_active():
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
		pickaxe.rotation = rope_angle - diagonal_angle + PI / 2.0

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
		pickaxe.position = _initial_pickaxe_position
		pickaxe.rotation = _initial_pickaxe_rotation
		pickaxe.scale = _initial_pickaxe_scale

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

func _collect_all_interactions() -> void:
	var nodes = get_tree().get_nodes_in_group("interactions")
	for node in nodes:
		if node is Interaction:
			_all_interactions.append(node)

func _update_interaction_prompt() -> void:
	if _all_interactions.is_empty():
		return

	var closest_interaction: Interaction = null
	var closest_dist: float = INTERACTION_PROMPT_DISTANCE

	for interaction in _all_interactions:
		if not is_instance_valid(interaction) or not interaction.is_active:
			continue

		var dist = global_position.distance_to(interaction.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_interaction = interaction

	if closest_interaction:
		_show_interaction_prompt(closest_interaction)
	else:
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
	# Create a CanvasLayer for UI (so it's always on top)
	var canvas_layer: CanvasLayer = CanvasLayer.new()
	canvas_layer.name = "DebugUI"
	canvas_layer.layer = 100  # Make sure it's on top
	add_child(canvas_layer)

	# Create label
	_debug_label = Label.new()
	_debug_label.position = Vector2(10, 10)
	_debug_label.z_index = 1000
	_debug_label.add_theme_font_size_override("font_size", 20)
	_debug_label.add_theme_color_override("font_color", Color.WHITE)
	_debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_debug_label.add_theme_constant_override("outline_size", 2)
	canvas_layer.add_child(_debug_label)

## Update debug UI text
func _update_debug_ui() -> void:
	if not _debug_label:
		return

	var text: String = "=== FEATURES ===\n"

	# Add feature status directly (no lambda - they don't capture outer variables properly)
	# 1. DoubleJump
	if double_jump_feature:
		var status: String = "OFF"
		if double_jump_feature.enabled:
			status = "ON"
		text += "[1] %s: %s\n" % [double_jump_feature.feature_name, status]
	else:
		text += "[1] NOT FOUND\n"

	# 2. Glide
	if glide_feature:
		var status: String = "OFF"
		if glide_feature.enabled:
			status = "ON"
		text += "[2] %s: %s\n" % [glide_feature.feature_name, status]
	else:
		text += "[2] NOT FOUND\n"

	# 3. Grappling
	if grappling_feature:
		var status: String = "OFF"
		if grappling_feature.enabled:
			status = "ON"

		text += "[3] %s: %s\n" % [grappling_feature.feature_name, status]
	else:
		text += "[3] NOT FOUND\n"

	# 4. Wings
	if wings_feature:
		var status: String = "OFF"
		if wings_feature.enabled:
			status = "ON"
		text += "[4] %s: %s\n" % [wings_feature.feature_name, status]
	else:
		text += "[4] NOT FOUND\n"

	# 5. Cut
	if cut_feature:
		var status: String = "OFF"
		if cut_feature.enabled:
			status = "ON"
		text += "[5] %s: %s (Action: F)\n" % [cut_feature.feature_name, status]
	else:
		text += "[5] Cut: NOT FOUND\n"

	# Terrain
	text += "\n=== TERRAIN ===\n"
	text += "%s: ON" % current_terrain.terrain_name

	_debug_label.text = text
