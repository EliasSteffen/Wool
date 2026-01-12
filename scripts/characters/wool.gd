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
var _idle_timer: float = 0.0
var _last_played_anim: String = ""

enum FormState { NORMAL, BUNNY, FISH, EAGLE }
var current_form: FormState = FormState.NORMAL

const ANIMATION_MAP = {
	FormState.NORMAL: {
		BasePlayer.PlayerState.IDLE: "idle",
		BasePlayer.PlayerState.WALK: "walk",
		BasePlayer.PlayerState.GRAPPLE: "grapple",
		BasePlayer.PlayerState.JUMP: "jump",
	},
	FormState.BUNNY: {
		BasePlayer.PlayerState.IDLE: "double-jump_idle",
		BasePlayer.PlayerState.WALK: "double-jump"
	},
	FormState.FISH: {
		BasePlayer.PlayerState.IDLE: "swim_idle",
		BasePlayer.PlayerState.WALK: "swim"
	},
	FormState.EAGLE: {
		BasePlayer.PlayerState.IDLE: "glide_idle",
		BasePlayer.PlayerState.WALK: "glide"
	}
}

func _ready() -> void:
	super._ready()

	# Fix Jump Interaction
	if skin and skin.animated_sprite and skin.animated_sprite.sprite_frames:
		if skin.animated_sprite.sprite_frames.has_animation("jump"):
			skin.animated_sprite.sprite_frames.set_animation_loop("jump", false)

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

	if current_anim_state == PlayerState.IDLE:
		_idle_timer += delta
	else:
		_idle_timer = 0.0

	_update_pickaxe_visual()

# === OVERRIDDEN METHODS FOR BASE PLAYER ===

func checkpoint_reached() -> void:
	super.checkpoint_reached()

	# Reset picked up features
	for feature in _picked_up_features:
		feature.enabled = false
		feature.deactivate()

	_picked_up_features.clear()

	current_form = FormState.NORMAL

	# Update appearances
	_update_feature_references()
	_update_form_state()
	_update_skin_appearance()
	_update_debug_ui()

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
		print("Wool: Form Update -> ", FormState.keys()[current_form])

func _calculate_player_state() -> PlayerState:
	if grappling_feature and grappling_feature.is_active():
		return PlayerState.GRAPPLE

	# Immediate Jump Response on Input or Flag
	var jump_just_pressed = Input.is_action_just_pressed("jump")

	if current_form == FormState.NORMAL:
		# Trigger JUMP if button pressed, flag set, or clearly in air
		if jump_just_pressed or _just_jumped:
			return PlayerState.JUMP

	# Floating/Falling State
	if not is_on_floor() and current_form != FormState.FISH:
		return PlayerState.JUMP

	if not is_zero_approx(velocity.x):
		return PlayerState.WALK

	# Special case: Swimming vertically counts as walking/swimming for Fish form
	if current_form == FormState.FISH and not is_zero_approx(velocity.y):
		return PlayerState.WALK

	return PlayerState.IDLE

var _last_rendered_form: FormState = FormState.NORMAL

func _should_force_animation_update() -> bool:
	# Only force update if Form changed, to avoid per-frame logic interfering with running animations
	if current_form != _last_rendered_form:
		_last_rendered_form = current_form
		return true

	# FORCE UPDATE FOR IDLE DELAY
	if current_anim_state == PlayerState.IDLE:
		# If timer just crossed threshold, force update to start playing animation
		if _idle_timer >= CharacterConstants.IDLE_ANIMATION_DELAY and skin and skin.animated_sprite and not skin.animated_sprite.is_playing():
			return true

	return false

func _play_animation_for_state(state: PlayerState) -> void:
	var target_anim = "default"

	if ANIMATION_MAP.has(current_form) and ANIMATION_MAP[current_form].has(state):
		target_anim = ANIMATION_MAP[current_form][state]

	# IDLE DELAY: If waiting, use "stand" frame or pause animation
	if state == BasePlayer.PlayerState.IDLE and _idle_timer < CharacterConstants.IDLE_ANIMATION_DELAY:
		if skin and skin.animated_sprite:
			# Play the animation but pause on first frame (assuming frame 0 is the "stand" pose)
			skin.play_animation(target_anim)
			skin.animated_sprite.set_frame_and_progress(0, 0.0)
			skin.animated_sprite.pause()
			_last_played_anim = target_anim
			return

	if skin and skin.animated_sprite:
		# If we were paused (from idle delay), resume
		if skin.animated_sprite.is_playing() == false and state != BasePlayer.PlayerState.IDLE: # Only resume if moving, or if idle timer passed (implicit by not entering above if)
			skin.animated_sprite.play()
		elif state == BasePlayer.PlayerState.IDLE and _idle_timer >= CharacterConstants.IDLE_ANIMATION_DELAY and not skin.animated_sprite.is_playing():
			skin.animated_sprite.play()

		if not skin.animated_sprite.sprite_frames.has_animation(target_anim):
			# 1. Try generic "idle" for unset idle animations (fallback)
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
					target_anim = "walk" if state == BasePlayer.PlayerState.WALK else "idle"

	# Optimized Play with Windup Skip
	if target_anim != _last_played_anim:
		skin.play_animation(target_anim)

		# SPECIAL CASE: Skip windup frames for normal jump to match instant physics
		if target_anim == "jump" and current_form == FormState.NORMAL:
			if skin and skin.animated_sprite:
				skin.animated_sprite.frame = 5

		_last_played_anim = target_anim
	else:
		# Continue playing (or ensure correct loop state if needed)
		# Do NOT restart JUMP animation if it finished (it should be one-shot)
		if state != BasePlayer.PlayerState.JUMP and skin and skin.animated_sprite and not skin.animated_sprite.is_playing() and state != BasePlayer.PlayerState.IDLE:
			skin.play_animation(target_anim) # Resilience against accidental stops


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

	# Enable specific shapes based on animation (handle both moving and idle variants)
	var base_anim = animation_name.replace("_idle", "")

	match base_anim:
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

		# Stretch along X axis to fit length, preserve Y (thickness)
		# Assuming the needle sprite is roughly horizontal.
		var scale_x: float = rope_distance / texture_size.x
		# Use absolute scale X but keep Y 1.0
		pickaxe.scale = Vector2(scale_x, 1.0)

		# Position at midpoint
		var midpoint: Vector2 = c_player + rope_vector * 0.5
		pickaxe.global_position = midpoint

		# Align to rope direction.
		# Adjusted rotation based on user feedback (-90 deg from previous state)
		pickaxe.global_rotation = rope_angle + PI / 2.0

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

		# --- DYNAMIC MOVEMENT (Backpack Style) ---
		var time = Time.get_ticks_msec() / 1000.0
		var dynamic_y = 0.0
		var dynamic_r = 0.0

		# 1. Walking Bob (On Floor)
		if is_on_floor() and abs(velocity.x) > 10.0:
			# Bobbing up and down
			dynamic_y = sin(time * 15.0) * 3.0
			# Slight rotation sway
			dynamic_r = cos(time * 15.0) * 0.1

		# 2. Air Physics (Jumping/Falling)
		if not is_on_floor():
			# Tilt based on vertical velocity (lag behind movement)
			# dragging behind -> rotates opposite to velocity direction visually
			dynamic_r = clamp(velocity.y * 0.001, -0.3, 0.3)

		# Apply dynamics
		pickaxe.position.y += dynamic_y

		# Apply rotation correctly based on facing
		if facing_left:
			pickaxe.rotation -= dynamic_r
		else:
			pickaxe.rotation += dynamic_r
		# ----------------------------------------

## Override to handle Wool-specific shape mirroring
func _update_facing_direction(is_facing_left: bool) -> void:
	# Call base to update skin and hitbox scale
	super._update_facing_direction(is_facing_left)

	# Manually update PhysicsShapes positions
	_update_physics_shapes_facing(is_facing_left)

	# Force pickaxe visual update immediately
	_update_pickaxe_visual()

## Helper to flip PhysicsShapes positions
func _update_physics_shapes_facing(is_facing_left: bool) -> void:
	# Default shape (usually centered, but strictness is good)
	if physics_shape_default: _flip_shape_pos(physics_shape_default, is_facing_left)

	# Feature shapes (often offset)
	if physics_shape_double_jump: _flip_shape_pos(physics_shape_double_jump, is_facing_left)
	if physics_shape_glide: _flip_shape_pos(physics_shape_glide, is_facing_left)
	if physics_shape_swim: _flip_shape_pos(physics_shape_swim, is_facing_left)
	if physics_shape_wings: _flip_shape_pos(physics_shape_wings, is_facing_left)

## Helper to flip a single shape's position based on direction
## Assumes positive X in editor is "Right"
func _flip_shape_pos(shape: Node2D, is_facing_left: bool) -> void:
	if not shape: return

	# We use ABS to always restore 'Right' side magnitude, then negate for 'Left'
	var current_x = shape.position.x

	# Heuristic: If we don't store initial positions, we might get drift if we just flip sign.
	# But if we assume the shape is currently correct for *some* direction, we can't be sure which.
	# HACK: We assume the shape's ABSOLUTE x position is correct for one side.
	# Since shapes are usually saved in "Right" facing state in editor (positive X or whatever offset).

	# Better approach: We should have stored initial positions in _ready.
	# But since I didn't want to add 10 variables, let's use the dictionary approach NOW.
	if not _initial_shape_positions.has(shape):
		_initial_shape_positions[shape] = shape.position

	var initial_pos = _initial_shape_positions[shape]

	if is_facing_left:
		# Mirror X relative to parent (Root/0)
		shape.position.x = -initial_pos.x
	else:
		shape.position.x = initial_pos.x

var _initial_shape_positions: Dictionary = {}
