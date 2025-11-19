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
const ACCELERATION: float = 1500.0
const FRICTION: float = 1200.0
const JUMP_VELOCITY: float = -400.0

# === EXPORTED VARIABLES ===
@export var can_control: bool = true

# === PRIVATE VARIABLES ===
var _direction: float = 0.0
var _debug_key_pressed: Dictionary = {}  # Track key state for debouncing
var _debug_label: Label = null  # Debug UI label for feature status

# === ONREADY VARIABLES ===
@onready var camera: Camera2D = $Camera2D if has_node("Camera2D") else null
@onready var pickaxe: Node2D = $Pickaxe if has_node("Pickaxe") else null
@onready var pickaxe_sprite: Sprite2D = $Pickaxe/Sprite2D if has_node("Pickaxe/Sprite2D") else ($Pickaxe as Sprite2D if has_node("Pickaxe") else null)
@onready var grappling_feature: GrapplingFeature = get_feature_by_type(GrapplingFeature)
@onready var push_feature: PushFeature = get_feature_by_type(PushFeature)
@onready var wings_feature: WingsFeature = get_feature_by_type(WingsFeature)
@onready var double_jump_feature: DoubleJumpFeature = get_feature_by_type(DoubleJumpFeature)
@onready var glide_feature: GlideFeature = get_feature_by_type(GlideFeature)

# === BUILT-IN METHODS ===
func _ready() -> void:
	super._ready()
	# Get features after they're setup
	call_deferred("_get_features")
	# Setup debug UI
	call_deferred("_setup_debug_ui")

func _get_features() -> void:
	grappling_feature = get_feature_by_type(GrapplingFeature)
	push_feature = get_feature_by_type(PushFeature)
	wings_feature = get_feature_by_type(WingsFeature)
	double_jump_feature = get_feature_by_type(DoubleJumpFeature)
	glide_feature = get_feature_by_type(GlideFeature)

	# Setup pickaxe sprite if it's directly a Sprite2D
	if pickaxe is Sprite2D and not pickaxe_sprite:
		pickaxe_sprite = pickaxe

func _process(delta: float) -> void:
	_update_pickaxe_visual()
	_update_debug_ui()

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
			# We use 200.0 as a reference base speed to normalize the multiplier
			var speed_multiplier: float = move_speed / 200.0
			var pump_force: float = _direction * grappling_feature.swing_pump_force * speed_multiplier * delta
			velocity.x += pump_force
		else:
			# Normal ground/air movement
			velocity.x = move_toward(velocity.x, _direction * move_speed, ACCELERATION * delta)

			# Apply push slowdown if pushing
			if push_feature and push_feature.is_pushing():
				velocity.x *= push_feature.get_push_slowdown()
	else:
		# Only apply friction when ON THE GROUND and NOT grappling
		# In air: momentum is preserved, terrain damping handles energy loss
		if not is_grappling and is_on_floor():
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

func _jump() -> void:
	var jump_power: float = JUMP_VELOCITY

	# Apply wings boost if available
	if wings_feature and wings_feature.is_active():
		jump_power *= wings_feature.get_jump_boost()

	velocity.y = jump_power

func _find_nearest_nail() -> Nail:
	var nearest: Nail = null
	var nearest_distance: float = INF

	for interaction in nearby_interactions:
		if interaction is Nail:
			var distance: float = global_position.distance_to(interaction.global_position)
			if distance < nearest_distance:
				nearest = interaction
				nearest_distance = distance

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
		# Normal pickaxe position (in hand)
		pickaxe.visible = true
		pickaxe_sprite.centered = true
		pickaxe_sprite.offset = Vector2.ZERO
		pickaxe.position = Vector2(32, 0)
		pickaxe.rotation = -0.785398  # -45 degrees
		pickaxe.scale = Vector2(1.0, 1.0)

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

	_debug_label.text = text
