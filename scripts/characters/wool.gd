class_name Wool
extends BasePlayer

# === ONREADY VARIABLES ===
# Pickaxe
@onready var pickaxe: Sprite2D = $Pickaxe
@onready var pickaxe_hitbox: Area2D = $Pickaxe/Hitbox
@onready var pickaxe_pivot: Marker2D = $PickaxePivot

# Physics Shapes
@onready var physics_shape_default: CollisionShape2D = $PhysicsShape

# Hitbox Shapes
@onready var hitbox_shape_default: CollisionShape2D = $HitboxArea/HitboxShape

# Pickaxe State
var _initial_pickaxe_position: Vector2
var _initial_pickaxe_rotation: float
var _initial_pickaxe_scale: Vector2
var _initial_pickaxe_centered: bool = true
var _initial_pickaxe_offset: Vector2 = Vector2.ZERO
var _is_attacking: bool = false
var _is_jumping_active: bool = false # Tracks if a jump was voluntarily initiated
var _game_started: bool = false # Tracks if the game has started
var _current_shape_animation: String = ""
var _idle_timer: float = 0.0
var _last_played_anim: String = ""

# Pickaxe Grapple Configuration
# Assign a Marker2D node here (e.g. child of Pickaxe) to visually define the grapple connection point.
@export var grapple_marker: Marker2D

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

func _on_pickaxe_hit_body(body: Node2D) -> void:
	if body is BaseEnemy and body.has_method("take_damage"):
		body.take_damage(100) # Instakill for now purely based on request context? Or typical damage?
		# Apply knockback?
		# print("Hit enemy: ", body.name)

func _process(delta: float) -> void:
	super._process(delta)

	if current_anim_state == PlayerState.IDLE:
		_idle_timer += delta
	else:
		_idle_timer = 0.0

	# Keep pickaxe visual updated if grappling (rope effect)
	if grappling_feature and grappling_feature.is_active():
		_update_pickaxe_visual()
	else:
		# Also update visual when NOT grappling to handle the "restore state" logic continuously
		# This prevents the pickaxe from getting stuck in a weird state if grapple ends abruptly
		_update_pickaxe_visual()

# === OVERRIDDEN METHODS FOR BASE PLAYER ===

func get_grapple_offset() -> Vector2:
	# Use the visual marker if assigned
	if grapple_marker:
		return grapple_marker.global_position - global_position

	# Fallback: Calculate from pickaxe center if it exists
	if pickaxe:
		# Default to pickaxe center/origin
		return pickaxe.global_position - global_position

	return Vector2.ZERO

func _jump() -> void:
	super._jump()
	_is_jumping_active = true

func _calculate_player_state() -> PlayerState:
	if grappling_feature and grappling_feature.is_active():
		return PlayerState.GRAPPLE

	# Immediate Jump Response on Input or Flag
	var jump_just_pressed = Input.is_action_just_pressed("jump")

	if _is_jumping_active or jump_just_pressed:
		return PlayerState.JUMP

	# Floating/Falling State
	if not is_on_floor():
		return PlayerState.JUMP

	# Check for horizontal movement (Walking)
	if not is_zero_approx(velocity.x):
		return PlayerState.WALK

	return PlayerState.IDLE

func _should_force_animation_update() -> bool:
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
	var target_anim = "idle"

	match state:
		PlayerState.IDLE: target_anim = "idle"
		PlayerState.WALK: target_anim = "walk"
		PlayerState.GRAPPLE: target_anim = "grapple"
		PlayerState.JUMP: target_anim = "jump"

	if skin:
		# PLAY ANIMATION
		# Only play if the animation actually changed.
		# This allows non-looping animations (like Jump) to finish properly without being restarted.
		if target_anim != _last_played_anim:
			# SPECIAL CASE: Skip windup for Jump (Frame 5 Start)
			if target_anim == "jump":
				skin.play_animation(target_anim)
				if skin.animated_sprite:
					skin.animated_sprite.frame = 5
			else:
				# Standard Play
				skin.play_animation(target_anim)

			_last_played_anim = target_anim
		elif target_anim == "walk" or target_anim == "idle":
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

			# "Schwung holen" Animation Logic
			# 1. Detect Impulse
			if Input.is_action_just_pressed("move_left"):
				# Move Left -> Kick CCW (Feet Right) for momentum "Wind Up"
				_grapple_kick = deg_to_rad(-80.0)
			elif Input.is_action_just_pressed("move_right"):
				# Move Right -> Kick CW (Feet Left) for momentum "Wind Up"
				_grapple_kick = deg_to_rad(80.0)

			# 2. Decay Impulse (Slower decay for better visibility)
			_grapple_kick = move_toward(_grapple_kick, 0.0, delta * 3.0)

			# 3. Sustained Lean (Hold direction to swing)
			var target_lean = 0.0
			if _direction < 0: # Left
				target_lean = deg_to_rad(40.0) # Lean into the swing (CW)
			elif _direction > 0: # Right
				target_lean = deg_to_rad(-40.0) # Lean into the swing (CCW)

			# Align head with rope (rope angle + 90 deg) + Kick + Lean
			target_rotation = rope_vector.angle() + PI / 2.0 + _grapple_kick + target_lean
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

		# --- VISUAL SCALING LOGIC ---
		# User Request: Stretch along X axis (Width) to reach the nail

		# 1. Position: Pivot (Spielerhand)
		pickaxe.global_position = c_player

		# 2. Richtung: Vektor von Pivot zu Nail (bereits oben definiert)
		# rope_vector, rope_distance, rope_angle sind schon vorhanden!

		# 3. Rotation: Sprite-Y (-Y Axis) should point to Nail
		# Standard Sprite points UP (-Y). So we align -Y with rope_vector.
		# rope_angle is angle of X axis. To make -Y align with X, we rotate +90 deg.
		pickaxe.global_rotation = rope_angle + PI / 2.0

		# 4. Offset: Ursprung an unteren Rand (EdgeBottom)
		var height: float = texture_size.y
		if height < 1.0: height = 1.0
		# We want the Bottom of the sprite (max Y) to be at (0,0).
		pickaxe.offset = Vector2(0, -height * 0.5)
		pickaxe.centered = true

		# 5. Skalierung: Y so, dass EdgeTop = Nail
		# IMPORTANT: We must calculate distance in PARENT LOCAL SPACE to account for Parent Scaling (e.g. 0.1)
		# to_local converts Global -> Parent Local (since script is on Parent)
		var local_start = to_local(c_player)
		var local_end = to_local(c_nail)
		var dist_in_parent = local_start.distance_to(local_end)

		# Scale Y to match distance in local space
		pickaxe.scale = Vector2(1.0, dist_in_parent / height)



		# Ensure visibility
		pickaxe.visible = true
		pickaxe.z_index = 10
	else:
		if _is_attacking:
			return

		# Restore initial state
		if pickaxe:
			pickaxe.visible = true
			pickaxe.centered = _initial_pickaxe_centered
			pickaxe.offset = _initial_pickaxe_offset
			pickaxe.scale = _initial_pickaxe_scale
			pickaxe.z_index = 0

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
# Use BasePlayer logic primarily, but force pickaxe update
func _update_facing_direction(is_facing_left: bool) -> void:
	# Call base to update skin and hitbox scale
	super._update_facing_direction(is_facing_left)

	# Force pickaxe visual update immediately
	# But wrap in check to ensure pickaxe is valid, as this might be called during setup
	if pickaxe:
		_update_pickaxe_visual()



# === MOBILE / ONE-BUTTON GAMEPLAY LOGIC ===
# Overrides BasePlayer input handling for the requested mobile loop.

func _handle_input() -> void:
	# 1. Unified Input Action: "jump" (Space / Touch / Click)
	# We treat any main action as the single input.
	var input_pressed: bool = Input.is_action_pressed("jump")
	var input_just_pressed: bool = Input.is_action_just_pressed("jump")

	if not _game_started:
		_direction = 0.0
		if input_just_pressed:
			_game_started = true
			_jump()
			_direction = 1.0
			velocity.x = move_speed # Instant burst to right
		return

	# 2. Ground Logic: Auto-run & Tap to Jump
	if is_on_floor():
		_direction = 1.0 # Always run right on ground
		if input_just_pressed:
			_jump()

	# 3. Air Logic: Hold to Grapple / Release to Fly
	else:
		# Preserve momentum direction in air (handle back-swings)
		if abs(velocity.x) > 10.0:
			_direction = sign(velocity.x)
		else:
			_direction = 1.0

		var is_grappling: bool = grappling_feature and grappling_feature.is_active()

		# Allow grapple activation only if we are NOT in the initial jump frame
		# (Though typically distinct taps are handled, a hold is needed)
		if input_pressed:
			# HOLDING
			if not is_grappling:
				var best_nail: Interaction = _find_best_grapple_target()
				if best_nail:
					grappling_feature.set_target(best_nail.get_grapple_point(), best_nail)
		else:
			# RELEASED
			if is_grappling:
				grappling_feature.release()

	# 4. Vertical Input (Swim/Climb) - currently zeroed for one-button simplicity
	_vertical_direction = 0.0

func _find_best_grapple_target() -> Interaction:
	var best_target: Interaction = null
	var min_dist: float = 9999999.0 # Squared distance

	# Use built-in nearby_interactions from BaseCharacter
	for interaction in nearby_interactions:
		if interaction is Nail and not interaction.is_being_used():
			var dist_sq = global_position.distance_squared_to(interaction.global_position)
			if dist_sq < min_dist:
				min_dist = dist_sq
				best_target = interaction

	return best_target

func _handle_grapple_swing_pump(delta: float) -> void:
	# "Character should automatically swing left and right"
	# We override the pump logic to be automatic based on momentum orientation.

	# If we have speed, pump in that direction to maintain momentum
	if abs(velocity.x) > 10.0:
		_direction = sign(velocity.x)
	else:
		# If stalled or starting, nudge forward (Right) or based on position relative to nail?
		# Nudge Right by default for progress
		_direction = 1.0

	# Store the auto-direction so super() can use it
	super._handle_grapple_swing_pump(delta)
