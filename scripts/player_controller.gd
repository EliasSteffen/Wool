class_name PlayerController
extends CharacterBody2D

# === CONSTANTS ===
const SPEED: float = 300.0
const JUMP_VELOCITY: float = -400.0
const ACCELERATION: float = 1500.0
const FRICTION: float = 1200.0
const GRAPPLE_SPEED: float = 800.0
const SWING_DAMPING: float = 0.98
const ROPE_LENGTH: float = 128.0  # 2x pickaxe length (64x2)

# === PRIVATE VARIABLES ===
var _direction: float = 0.0
var _is_grappling: bool = false
var _grapple_point: Vector2 = Vector2.ZERO
var _current_nail: Node2D = null

# === BUILT-IN METHODS ===
func _ready() -> void:
	_connect_to_nails()

func _physics_process(delta: float) -> void:
	# Always handle input (especially to detect release)
	_handle_input()

	if _is_grappling:
		_handle_grappling(delta)
	else:
		_handle_gravity(delta)
		_handle_movement(delta)

	move_and_slide()
	queue_redraw()  # For drawing rope

func _draw() -> void:
	if _is_grappling and _current_nail:
		# Draw rope from player to nail
		var rope_start: Vector2 = Vector2.ZERO  # Local position (player center)
		var rope_end: Vector2 = _grapple_point - global_position  # Nail position relative to player
		draw_line(rope_start, rope_end, Color.BROWN, 2.0)# === PRIVATE METHODS ===
func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

func _handle_input() -> void:
	# Check for grapple release first
	if _is_grappling and Input.is_action_just_released("ui_accept"):
		print(">>> Leertaste losgelassen - Stoppe Grappling")
		_stop_grappling()
		return

	# Start grappling
	if Input.is_action_pressed("ui_accept") and _current_nail != null and not _is_grappling:
		print(">>> Leertaste gedrückt - Starte Grappling")
		if _current_nail:
			print("Current nail: ", _current_nail.name)
		_start_grappling()
		return

	# Jump (only when not grappling)
	if not _is_grappling and Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Horizontal movement
	if not _is_grappling:
		_direction = Input.get_axis("ui_left", "ui_right")

func _handle_movement(delta: float) -> void:
	if _direction != 0.0:
		# Accelerate
		velocity.x = move_toward(velocity.x, _direction * SPEED, ACCELERATION * delta)
	else:
		# Apply friction ONLY when on ground (not in air)
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

func _connect_to_nails() -> void:
	# Connect to all nails in the scene
	await get_tree().process_frame
	var nails: Array = get_tree().get_nodes_in_group("grappling_nails")
	for nail in nails:
		if nail.has_signal("player_in_range"):
			nail.player_in_range.connect(_on_nail_in_range)
			nail.player_out_of_range.connect(_on_nail_out_of_range)

func _start_grappling() -> void:
	if _current_nail == null:
		print("ERROR: Cannot start grappling - no nail!")
		return

	_is_grappling = true
	_grapple_point = _current_nail.global_position
	print("=== STARTED GRAPPLING ===")
	print("Nail position: ", _grapple_point)
	print("Player position: ", global_position)
	print("Distance: ", (_grapple_point - global_position).length())

	if _current_nail.has_method("set_connected"):
		_current_nail.set_connected(true)

func _stop_grappling() -> void:
	print("=== STOPPED GRAPPLING ===")
	print("Velocity beim Loslassen: ", velocity)
	_is_grappling = false
	# DON'T reset velocity - keep momentum!
	# velocity wird NICHT zurückgesetzt, damit Schwung erhalten bleibt
	if _current_nail and _current_nail.has_method("set_connected"):
		_current_nail.set_connected(false)

func _handle_grappling(delta: float) -> void:
	# Update grapple point to nail's current position (in case nail moves)
	if _current_nail:
		_grapple_point = _current_nail.global_position

	# Calculate rope vector from player center to nail center
	var to_nail: Vector2 = _grapple_point - global_position
	var distance: float = to_nail.length()
	var rope_direction: Vector2 = to_nail.normalized()

	# Debug every 30 frames (about 0.5 seconds)
	if Engine.get_process_frames() % 30 == 0:
		print("--- GRAPPLING DEBUG ---")
		print("Grapple center: ", _grapple_point)
		print("Player position: ", global_position)
		print("Distance: ", distance, " / Rope length: ", ROPE_LENGTH)
		print("Is pulling: ", distance > ROPE_LENGTH)

	# Apply gravity
	velocity += get_gravity() * delta

	# Allow horizontal movement while swinging
	_direction = Input.get_axis("ui_left", "ui_right")
	if _direction != 0.0:
		velocity.x += _direction * ACCELERATION * delta * 0.3

	# Rope constraint physics
	if distance > ROPE_LENGTH:
		# Pull towards nail only to maintain rope length (not to center)
		var velocity_along_rope: float = velocity.dot(rope_direction)

		# Remove velocity component pulling away from nail
		if velocity_along_rope < 0:
			velocity -= rope_direction * velocity_along_rope

		# Gently pull back to rope length (spring-like)
		var excess_distance: float = distance - ROPE_LENGTH
		var pull_strength: float = excess_distance * 15.0  # Spring constant
		velocity += rope_direction * pull_strength * delta

	# Apply swing damping (loses energy over time)
	velocity.x *= SWING_DAMPING

# === SIGNAL CALLBACKS ===
func _on_nail_in_range(nail: Node2D) -> void:
	_current_nail = nail

func _on_nail_out_of_range() -> void:
	if not _is_grappling:
		_current_nail = null
