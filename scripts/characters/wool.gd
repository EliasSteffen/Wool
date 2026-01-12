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
var _is_jumping_active: bool = false # Tracks if a jump was voluntarily initiated
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

func _jump() -> void:
	super._jump()
	_is_jumping_active = true

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
		if _is_jumping_active or jump_just_pressed:
			return PlayerState.JUMP

	# Floating/Falling State
	if not is_on_floor() and current_form != FormState.FISH:
		if current_form != FormState.NORMAL:
			return PlayerState.JUMP
		# For Normal Form: Fall through to check movement (WALK)
		# This prevents JUMP animation flickering when running down slopes

	if current_form == FormState.FISH and not is_zero_approx(velocity.y):
		return PlayerState.WALK

	# Check for horizontal movement (Walking)
	if not is_zero_approx(velocity.x):
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
		if _idle_timer >= CharacterConstants.IDLE_ANIMATION_DELAY:
			if skin and skin.animated_sprite and not skin.animated_sprite.is_playing():
				return true

	# SAFETY CHECK: Ensure Walk/Jump animations don't get stuck
	# If we are walking or jumping, the animation should strictly be playing.
	# This catches cases where an animation finished (non-looping) or was paused errantly.
	if current_anim_state != PlayerState.IDLE:
		if skin and skin.animated_sprite and not skin.animated_sprite.is_playing():
			return true

	return false

func _play_animation_for_state(state: PlayerState) -> void:
	var target_anim = "default"

	if ANIMATION_MAP.has(current_form) and ANIMATION_MAP[current_form].has(state):
		target_anim = ANIMATION_MAP[current_form][state]

	if skin:
		# FALLBACK LOGIC for missing animations
		if skin.animated_sprite and not skin.animated_sprite.sprite_frames.has_animation(target_anim):
			# 1. Try generic "idle" for unset idle animations (fallback)
			if target_anim.ends_with("_idle"):
				var base_name = target_anim.replace("_idle", "")
				if skin.animated_sprite.sprite_frames.has_animation(base_name):
					target_anim = base_name
				elif skin.animated_sprite.sprite_frames.has_animation("idle"):
					target_anim = "idle"
			# 2. Last resort fallback
			elif not skin.animated_sprite.sprite_frames.has_animation(target_anim):
				if current_form == FormState.NORMAL:
					target_anim = "walk" if state == BasePlayer.PlayerState.WALK else "idle"

		# PLAY ANIMATION
		# Only play if the animation actually changed.
		# This allows non-looping animations (like Jump) to finish properly without being restarted.
		if target_anim != _last_played_anim:
			# SPECIAL CASE: Skip windup for Jump (Frame 5 Start)
			if target_anim == "jump" and current_form == FormState.NORMAL:
				skin.play_animation(target_anim)
				if skin.animated_sprite:
					skin.animated_sprite.frame = 5
			else:
				# Standard Play
				skin.play_animation(target_anim)

			_last_played_anim = target_anim
		elif target_anim == "walk" or target_anim.ends_with("idle") or target_anim == "idle":
			# Ensure looping animations are playing (in case they stopped due to frame errors)
			if skin.animated_sprite and not skin.animated_sprite.is_playing():
				skin.animated_sprite.play()

var _current_visual_rotation: float = 0.0
var _last_valid_floor_normal: Vector2 = Vector2.UP

func _update_rotation(delta: float) -> void:
	# Lock rotation during attack to prevent visual desync of the pickaxe
	if _is_attacking:
		return

	# OVERRIDE: Do not call super._update_rotation(delta)
	# We handle rotation manually on the visuals (Skin/Hitbox) ONLY.
	# Rotating the CharacterBody2D (self) causes floor detachment on slopes.

	var is_grappling = grappling_feature and grappling_feature.is_active()
	var is_underwater = current_terrain is UnderWaterTerrain
	var target_rotation = 0.0

	# --- RESTORE FACING DIRECTION LOGIC ---
	# Handle flipping (standard platformer behavior)
	# Prioritize Input direction for responsiveness
	if not is_zero_approx(_direction):
		_update_facing_direction(_direction < 0)
	# Fallback to velocity if moving significantly (e.g. knockback or drift)
	elif abs(velocity.x) > 10.0:
		_update_facing_direction(velocity.x < 0)
	# --------------------------------------

	if is_grappling:
		var current_nail = grappling_feature.get_target_nail()
		if current_nail:
			var rope_vector = current_nail.global_position - global_position
			# Align head with rope (rope angle + 90 deg)
			target_rotation = rope_vector.angle() + PI / 2.0
	elif is_on_floor():
		# Align with floor slope
		var floor_normal = get_floor_normal()
		target_rotation = floor_normal.angle() + PI / 2.0
		_last_valid_floor_normal = floor_normal
	elif is_underwater:
		var close_to_floor = is_on_floor()
		if not close_to_floor and velocity.y >= 0: # Only check if falling/sinking
			close_to_floor = test_move(global_transform, Vector2(0, 16))

		if close_to_floor:
			target_rotation = 0.0
		elif velocity.length() > 10.0:
			var angle = velocity.angle() + PI / 2.0
			angle = wrapf(angle, -PI, PI)

			if skin.scale.x > 0:
				target_rotation = clamp(angle, -PI/6, PI)
			else:
				if angle > PI/2: angle -= 2 * PI
				target_rotation = clamp(angle, -PI, PI/6)
	else:
		# VISUAL FLICKER FIX:
		# Use last known floor normal to maintain rotation during momentary flickers
		target_rotation = _last_valid_floor_normal.angle() + PI / 2.0

		# If we are really in the air for longer, slowly rotate back to 0
		# But for quick flickers, this keeps it stable.
		var target_air_rotation = 0.0
		# Interpolate target towards 0 based on air time (heuristic) would be ideal,
		# but simply reusing last normal prevents the hard snap to 0.

	# Apply rotation with smoothing to the VISUAL ROTATION variable
	if is_underwater and not is_grappling:
		_current_visual_rotation = wrapf(_current_visual_rotation, -PI, PI)
		_current_visual_rotation = lerp(_current_visual_rotation, target_rotation, 5.0 * delta)
	else:
		var rotate_speed = 15.0 if is_on_floor() else 5.0
		_current_visual_rotation = lerp_angle(_current_visual_rotation, target_rotation, rotate_speed * delta)

	# Apply to Skin
	if skin:
		skin.rotation = _current_visual_rotation

		# Fix floating on slopes (Visual Offset)
		# Improved: Rely on visual rotation (which handles flickers) to set offset
		# This prevents the 'snap to 0' when is_on_floor() flickers false momentarily
		var slope_offset = abs(sin(_current_visual_rotation)) * 10.0
		skin.position.y = lerp(skin.position.y, slope_offset, 20.0 * delta)

	# Apply to Hitbox Area (if exists)
	if has_node("HitboxArea"):
		$HitboxArea.rotation = _current_visual_rotation
		if skin:
			# Also sync position offset
			$HitboxArea.position.y = skin.position.y

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

func _process_physics(delta: float) -> void:
	super._process_physics(delta)

	# Only reset jumping logic if we are actually on floor AND falling/standing (not moving up/jumping)
	# This prevents resetting the jump flag immediately in the frame we jump (where is_on_floor is still true)
	if is_on_floor() and velocity.y >= 0:
		_is_jumping_active = false

	# Increase floor snap length to handle steep slopes better at high speeds
	# BUT: Only apply high snap if we didn't just jump. Otherwise we snap back to ground instantly.
	if not _just_jumped:
		floor_snap_length = 64.0

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

		# Define visual grounded state (Use coyote timer to bridge physics flickers on slopes)
		var is_visually_grounded = is_on_floor() or _coyote_timer > 0.0

		# 1. Walking Bob (On Floor)
		if is_visually_grounded and abs(velocity.x) > 10.0:
			# Bobbing up and down
			dynamic_y = sin(time * 15.0) * 3.0
			# Slight rotation sway
			dynamic_r = cos(time * 15.0) * 0.1

		# 2. Air Physics (Jumping/Falling)
		if not is_visually_grounded:
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

		# 3. Apply Visual Rotation (Slope) to Pickaxe
		# Pickaxe is child of Wool (unrotated), so we must manually add the visual rotation
		# to match the skin.
		pickaxe.rotation += _current_visual_rotation

		# Sync Position offset with skin (floating fix)
		if skin:
			pickaxe.position.y += skin.position.y
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
