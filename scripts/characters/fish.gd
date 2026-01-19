class_name Fish
extends BaseEnemy

# Removed export var jump_strength
# Jump strength is now calculated dynamically

@export var horizontal_speed: float = -900.0

var _start_y: float = 0.0
var _start_x: float = 0.0

func _ready() -> void:
	super._ready()
	_start_y = global_position.y
	_start_x = global_position.x
	
	_jump()

func _process_ai(delta: float) -> void:
	# BaseCharacter applies gravity in _process_physics.
	# We just need to check if we fell back to water level.
	
	if velocity.y > 0 and global_position.y >= _start_y:
		# Fish has returned to the water -> Die
		die()

func _jump() -> void:
	# Recalculate or reuse jump velocity
	# Target significantly above the top of the playable area for a high jump
	var target_y = GameManager.PLAYABLE_HEIGHT_TOP - 400.0
	var height_diff = _start_y - target_y
	
	if height_diff > 0:
		var jump_velocity = sqrt(2.0 * gravity * height_diff)
		velocity.y = -jump_velocity
		velocity.x = horizontal_speed # Apply lateral movement
		print("DEBUG: Fish jumping with velocity ", velocity)
	else:
		velocity.y = -1000.0
		velocity.x = horizontal_speed
