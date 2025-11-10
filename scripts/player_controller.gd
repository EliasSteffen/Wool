class_name PlayerController
extends CharacterBody2D

# === CONSTANTS ===
const SPEED: float = 300.0
const JUMP_VELOCITY: float = -400.0
const ACCELERATION: float = 1500.0
const FRICTION: float = 1200.0

# === PRIVATE VARIABLES ===
var _direction: float = 0.0

# === BUILT-IN METHODS ===
func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	_handle_gravity(delta)
	_handle_input()
	_handle_movement(delta)
	move_and_slide()

# === PRIVATE METHODS ===
func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

func _handle_input() -> void:
	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Horizontal movement
	_direction = Input.get_axis("ui_left", "ui_right")

func _handle_movement(delta: float) -> void:
	if _direction != 0.0:
		# Accelerate
		velocity.x = move_toward(velocity.x, _direction * SPEED, ACCELERATION * delta)
	else:
		# Apply friction
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
