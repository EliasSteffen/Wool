class_name Wool
extends BasePlayer

# === ONREADY VARIABLES ===
# Pickaxe
@onready var pickaxe: Sprite2D = $Pickaxe
@onready var pickaxe_hitbox: Area2D = $Pickaxe/Hitbox
@onready var pickaxe_pivot: Marker2D = $PickaxePivot

# Physics Shapes
@onready var physics_shape_default: CollisionShape2D = $PhysicsShape
@onready var physics_shape_double_jump: CollisionShape2D = $PhysicsShape_DoubleJump
@onready var physics_shape_glide: CollisionShape2D = $PhysicsShape_Glide
@onready var physics_shape_swim: CollisionShape2D = $PhysicsShape_Swim
@onready var physics_shape_wings: CollisionShape2D = $PhysicsShape_Wings

# Hitbox Shapes
@onready var hitbox_shape_default: CollisionShape2D = $HitboxArea/HitboxShape
@onready var hitbox_shape_double_jump: CollisionShape2D = $HitboxArea/HitboxShape_DoubleJump
@onready var hitbox_shape_glide: CollisionShape2D = $HitboxArea/HitboxShape_Glide
@onready var hitbox_shape_swim: CollisionShape2D = $HitboxArea/HitboxShape_Swim
@onready var hitbox_shape_wings: CollisionShape2D = $HitboxArea/HitboxShape_Wings

# Pickaxe State
var _initial_pickaxe_position: Vector2
var _initial_pickaxe_rotation: float
var _initial_pickaxe_scale: Vector2
var _initial_pickaxe_centered: bool = true
var _initial_pickaxe_offset: Vector2 = Vector2.ZERO
var _is_attacking: bool = false
var _current_shape_animation: String = ""

func _ready() -> void:
	super._ready()

	# Initialize Pickaxe Data
	if pickaxe:
		_initial_pickaxe_position = pickaxe.position
		_initial_pickaxe_rotation = pickaxe.rotation
		_initial_pickaxe_scale = pickaxe.scale
		_initial_pickaxe_centered = pickaxe.centered
		_initial_pickaxe_offset = pickaxe.offset

		# Ensure hitbox is off initially
		if pickaxe_hitbox:
			pickaxe_hitbox.monitoring = false
			pickaxe_hitbox.monitorable = false
			# Check default mask (1) vs Enemy Layer (usually 1 or specific)
			# We ensure it masks enemies relative to project settings later if needed
			if not pickaxe_hitbox.body_entered.is_connected(_on_pickaxe_hit_body):
				pickaxe_hitbox.body_entered.connect(_on_pickaxe_hit_body)

	_update_shapes("default")

func _on_pickaxe_hit_body(body: Node2D) -> void:
	if body is BaseEnemy and body.has_method("take_damage"):
		body.take_damage(100) # Instakill for now purely based on request context? Or typical damage?
		# Apply knockback?
		# print("Hit enemy: ", body.name)

func _update_skin_appearance() -> void:
	super._update_skin_appearance()

	# Use the actual animation being played by the skin to update shapes
	if skin and skin.animated_sprite:
		_update_shapes(skin.animated_sprite.animation)
	else:
		_update_shapes("default")

func _process(delta: float) -> void:
	super._process(delta)
	_update_pickaxe_visual()

func _update_rotation(delta: float) -> void:
	# Lock rotation during attack to prevent visual desync of the pickaxe
	if _is_attacking:
		return
	super._update_rotation(delta)

func _update_shapes(animation_name: String) -> void:
	# OPTIMIZATION: Only update shapes if animation actually changed.
	# Prevents physics engine flicker where shapes are disabled/enabled every frame.
	if _current_shape_animation == animation_name:
		return

	_current_shape_animation = animation_name

	# Disable all shapes first
	_disable_all_shapes()

	# Enable specific shapes based on animation
	match animation_name:
		"wings":
			if physics_shape_wings: physics_shape_wings.set_deferred("disabled", false)
			if hitbox_shape_wings: hitbox_shape_wings.set_deferred("disabled", false)
		"swim":
			if physics_shape_swim: physics_shape_swim.set_deferred("disabled", false)
			if hitbox_shape_swim: hitbox_shape_swim.set_deferred("disabled", false)
		"glide":
			if physics_shape_glide: physics_shape_glide.set_deferred("disabled", false)
			if hitbox_shape_glide: hitbox_shape_glide.set_deferred("disabled", false)
		"double-jump":
			if physics_shape_double_jump: physics_shape_double_jump.set_deferred("disabled", false)
			if hitbox_shape_double_jump: hitbox_shape_double_jump.set_deferred("disabled", false)
		_:
			if physics_shape_default: physics_shape_default.set_deferred("disabled", false)
			if hitbox_shape_default: hitbox_shape_default.set_deferred("disabled", false)

func _disable_all_shapes() -> void:
	if physics_shape_default: physics_shape_default.set_deferred("disabled", true)
	if physics_shape_double_jump: physics_shape_double_jump.set_deferred("disabled", true)
	if physics_shape_glide: physics_shape_glide.set_deferred("disabled", true)
	if physics_shape_swim: physics_shape_swim.set_deferred("disabled", true)
	if physics_shape_wings: physics_shape_wings.set_deferred("disabled", true)

	if hitbox_shape_default: hitbox_shape_default.set_deferred("disabled", true)
	if hitbox_shape_double_jump: hitbox_shape_double_jump.set_deferred("disabled", true)
	if hitbox_shape_glide: hitbox_shape_glide.set_deferred("disabled", true)
	if hitbox_shape_swim: hitbox_shape_swim.set_deferred("disabled", true)
	if hitbox_shape_wings: hitbox_shape_wings.set_deferred("disabled", true)

func attack() -> void:
	if _is_attacking or not pickaxe:
		return

	_is_attacking = true

	# Enable Hitbox
	if pickaxe_hitbox:
		pickaxe_hitbox.monitoring = true
		pickaxe_hitbox.monitorable = true

	# 1. RESET STATE FROM SAVED INITIALS
	# Because we might be attacking immediately after another attack (before _process reset),
	# we must force a clean state here.
	var facing_left = skin.scale.x < 0

	pickaxe.centered = _initial_pickaxe_centered
	pickaxe.offset = _initial_pickaxe_offset
	pickaxe.scale = _initial_pickaxe_scale # Base positive scale

	if facing_left:
		pickaxe.position = Vector2(-_initial_pickaxe_position.x, _initial_pickaxe_position.y)
		pickaxe.scale = Vector2(-_initial_pickaxe_scale.x, _initial_pickaxe_scale.y)
		pickaxe.rotation = -_initial_pickaxe_rotation
	else:
		pickaxe.position = _initial_pickaxe_position
		pickaxe.rotation = _initial_pickaxe_rotation

	# Now capture these "clean" values as our start points
	var initial_pos = pickaxe.position
	var initial_rot = pickaxe.rotation

	# Adjust pivot to handle (25% from bottom)
	# Default center is middle. We want point at y=+h/4 (relative to center) to be origin.
	# So we shift texture UP by h/4.
	var tex_height = pickaxe.texture.get_size().y
	var handle_shift_vec = Vector2(0, -tex_height * 0.25)

	# To prevent visual jump, we need to move the Node in the opposite direction of the offset shift
	# taking rotation and scale into account.
	var visual_correction = pickaxe.transform.basis_xform(handle_shift_vec)

	# Apply Offset
	pickaxe.offset += handle_shift_vec
	# Apply Position Correction (Inverse of offset shift)
	pickaxe.position -= visual_correction

	var compensated_start_pos = pickaxe.position

	# Target Position (Pivot)
	var target_pos = initial_pos # Fallback
	if pickaxe_pivot:
		var pivot_pos = pickaxe_pivot.position
		if facing_left:
			target_pos = Vector2(-pivot_pos.x, pivot_pos.y)
		else:
			target_pos = pivot_pos

	# Animate
	var tween = create_tween()

	# 1. Move to Pivot (Quickly)
	tween.tween_property(pickaxe, "position", target_pos, 0.05).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# 2. Swing
	var target_rot_value = initial_rot
	if facing_left:
		target_rot_value -= (PI * 0.5)
	else:
		target_rot_value += (PI * 0.5)

	# Swing Down
	tween.tween_property(pickaxe, "rotation", target_rot_value, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Swing Back
	tween.tween_property(pickaxe, "rotation", initial_rot, 0.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

	# 3. Return to Initial Position (Compensated)
	tween.tween_property(pickaxe, "position", compensated_start_pos, 0.1).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

	await tween.finished

	_is_attacking = false
	if pickaxe_hitbox:
		pickaxe_hitbox.monitoring = false
		pickaxe_hitbox.monitorable = false

	# Force a visual update immediately to clean up offset hacks
	_update_pickaxe_visual()

func _update_pickaxe_visual() -> void:
	if not pickaxe:
		return

	var is_grappling: bool = grappling_feature and grappling_feature.is_active()
	var current_nail: Nail = null

	if is_grappling and grappling_feature:
		current_nail = grappling_feature.get_target_nail() as Nail

	if is_grappling and current_nail:
		# Show pickaxe as rope stretching from player to nail
		pickaxe.visible = true

		# Use pivot if available, otherwise player position
		var c_player: Vector2 = pickaxe_pivot.global_position if pickaxe_pivot else global_position
		var c_nail: Vector2 = current_nail.global_position

		# Vector and distance
		var rope_vector: Vector2 = c_nail - c_player
		var rope_distance: float = rope_vector.length()
		var rope_angle: float = rope_vector.angle()

		# Original Sprite Dimensions
		var texture_size: Vector2 = pickaxe.texture.get_size()
		# Diagonal from bottom-left to top-right (unscaled)
		var original_diagonal: float = Vector2(texture_size.x, texture_size.y).length()

		# Scale to match distance
		var scale_factor: float = rope_distance / original_diagonal
		pickaxe.scale = Vector2(scale_factor, scale_factor)

		# Position at midpoint
		var midpoint: Vector2 = c_player + rope_vector * 0.5
		pickaxe.global_position = midpoint

		# Rotation
		var diagonal_angle: float = atan2(texture_size.y, texture_size.x)
		pickaxe.global_rotation = rope_angle - diagonal_angle + PI

		# Center sprite
		pickaxe.centered = true
		pickaxe.offset = Vector2.ZERO
	else:
		if _is_attacking:
			return

		# Restore initial state
		pickaxe.visible = true
		pickaxe.centered = _initial_pickaxe_centered
		pickaxe.offset = _initial_pickaxe_offset

		# Facings
		var facing_left = skin.scale.x < 0

		# Define base position/rotation
		var base_pos = _initial_pickaxe_position
		var base_rot = _initial_pickaxe_rotation
		var base_scale = _initial_pickaxe_scale

		# Note: We do NOT force position to pivot here anymore,
		# as pivot is only used during attack animation.

		if facing_left:
			# Mirror X position
			pickaxe.position = Vector2(-base_pos.x, base_pos.y)
			# Mirror Scale X
			pickaxe.scale = Vector2(-base_scale.x, base_scale.y)
			# Invert rotation for symmetry
			pickaxe.rotation = -base_rot
		else:
			pickaxe.position = base_pos
			pickaxe.scale = base_scale
			pickaxe.rotation = base_rot
