## BaseEnemy - Base class for all enemy characters
##
## Inherits from BaseCharacter and adds enemy-specific functionality:
## - AI behavior
## - Attack logic
## - Targeting system
##
## Specific enemy types (Bunny, Slime, etc.) inherit from this.
class_name BaseEnemy
extends BaseCharacter

# === SIGNALS ===
signal target_acquired(target: Node2D)
signal target_lost()
signal despawn_requested(node: Node)

# === EXPORTED VARIABLES ===
# Removed exports in favor of Tweakables

# === PUBLIC VARIABLES ===
var jump_velocity: float = -400.0

# === PRIVATE VARIABLES ===
var _current_target: Node2D = null

# Audio
@export var start_volume_percent: float = 10.0 ## Volume (0-100%) when enemy spawns off-screen
@export var audio_stream: AudioStream

var _sfx_player: AudioStreamPlayer2D
var _spawn_position: Vector2



# === ENUMS ===

# === ONREADY VARIABLES ===

# === BUILT-IN METHODS ===
func _ready() -> void:
	_spawn_position = global_position
	_setup_audio()
	# Ensure enemies render above Nails (Z=0 and Z=2)
	z_index = 10
	super._ready()


	if hitbox_area:
		if not hitbox_area.body_entered.is_connected(_on_hitbox_body_entered):
			hitbox_area.body_entered.connect(_on_hitbox_body_entered)

	GameManager.state_changed.connect(_on_game_state_changed)

func _on_game_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.GAME_OVER:
		_stop_audio()

func _stop_audio() -> void:
	if _sfx_player:
		_sfx_player.stop()


# === PUBLIC METHODS ===

func reset() -> void:
	velocity = Vector2.ZERO
	rotation = 0
	process_mode = Node.PROCESS_MODE_INHERIT

func show_spawn_warning() -> void:
	# Add warning icon
	var warning_scene = preload("res://scenes/ui/warn_player.tscn")
	var warning_instance = warning_scene.instantiate()
	warning_instance.position = Vector2(0, 0) # Scene has its own offset or we adjust here?
	# The scene has the exclamation mark at -283, -333. That's huge offset.
	# User wants "Links oben vom gegner".
	# If I add it at (0,0), the sprite will be at (-283, -333).
	# This might be too far. But let's respect the scene layout first or reset it?
	# "verwende die warnplayer szene" - imply using it as is.
	add_child(warning_instance)

func die() -> void:
	# Drop features if any

	# Play death animation if available (TODO)
	queue_free()

func _process(delta: float) -> void:
	# Cleanup if too far behind player
	# We use a large buffer to ensure we don't despot eagles that are swooping
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		# If we are more than 3000px behind the player, we are definitely off screen and safe to remove
		if global_position.x < player.global_position.x - 3000.0:
			queue_free()

	_update_audio_volume()



# === OVERRIDDEN METHODS ===

func _process_physics(delta: float) -> void:
	_process_ai(delta)

	# Check for collisions
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		# Check for player to kill
		if collider is BasePlayer:
			collider.take_damage(collider.max_health)

		# Check for Left Border to die
		if collider.name == "Left Border":
			die()

# === VIRTUAL METHODS (Override in specific enemy types) ===

## Override for custom AI behavior
func _process_ai(delta: float) -> void:
	pass


## Override for custom attack behavior

# === PUBLIC METHODS ===

## Perform a jump
func jump() -> void:
	if is_on_floor():
		velocity.y = jump_velocity

## Set current target
func set_target(target: Node2D) -> void:
	if _current_target == target:
		return

	_current_target = target
	if target:
		target_acquired.emit(target)
	else:
		target_lost.emit()

func _setup_audio() -> void:
	if not audio_stream:
		return

	_sfx_player = AudioStreamPlayer2D.new()
	_sfx_player.stream = audio_stream
	_sfx_player.bus = "SFX"

	# We handle volume manually relative to camera proximity
	# Disable standard attenuation to avoid double effects or set max distance very high
	_sfx_player.max_distance = 10000.0
	_sfx_player.attenuation = 1e-5 # Effectively 0 attenuation over distance

	add_child(_sfx_player)
	_sfx_player.play()
	_update_audio_volume() # Set initial

func _update_audio_volume() -> void:
	if not _sfx_player: return

	var viewport = get_viewport()
	if not viewport: return

	var camera = viewport.get_camera_2d()
	if not camera: return

	# Determine if visible on screen
	var canvas_transform = get_canvas_transform()
	var screen_pos = canvas_transform * global_position
	var screen_rect = viewport.get_visible_rect()

	# Expand rect slightly? No, user said "when visible".
	# Actually "visible" can mean "on screen".

	var is_visible = screen_rect.has_point(screen_pos)

	var target_vol_linear: float = 0.0

	if is_visible:
		target_vol_linear = 1.0 # 100%
	else:
		# Calculate distance to screen edge
		# Simplified: Distance to camera center vs screen size?
		# Or generic distance from Camera Center

		# Let's use distance to camera center for smoothness
		var camera_center = camera.get_screen_center_position()
		var dist = global_position.distance_to(camera_center)

		# Approximate screen radius (diagonal / 2)
		var screen_radius = screen_rect.size.length() / 2.0

		# If dist <= screen_radius, we are essentially "visible" or close.
		# If dist > screen_radius, we ramp down.

		# User requirement: "spawns at start_volume ... increases to 100% when visible"
		# Logic:
		# Map distance [SpawnDist -> VisibleDist] to [StartVol -> 1.0]

		# Spawn distance is roughly where it spawned? Or current distance?
		# Let's use a dynamic range.
		# If it's 1000px away, volume is low.
		# If it's at screen edge, volume is high.

		# Let's assume a "Fade Band".
		# 0 distance outside screen = 100%
		# 1000 distance outside screen = start_volume

		# Calculate distance to nearest point on screen rect? expensive.
		# Use x-distance as primary factor since game is side scroller?

		var x_dist = abs(global_position.x - camera_center.x) - (screen_rect.size.x / 2.0)
		var y_dist = abs(global_position.y - camera_center.y) - (screen_rect.size.y / 2.0)

		# taking max of 0 and dist
		var dist_outside = max(0, max(x_dist, y_dist))

		if dist_outside <= 0:
			target_vol_linear = 1.0
		else:
			# Ramp over e.g. 800 pixels
			var ramp_distance = 800.0
			var t = clamp(1.0 - (dist_outside / ramp_distance), 0.0, 1.0)

			var start_linear = start_volume_percent / 100.0
			target_vol_linear = lerp(start_linear, 1.0, t)

	_sfx_player.volume_db = linear_to_db(target_vol_linear)


# === PRIVATE METHODS ===

const FRICTION: float = 1200.0



# === SIGNAL CALLBACKS ===


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body is BasePlayer:
		body.take_damage(body.max_health)
