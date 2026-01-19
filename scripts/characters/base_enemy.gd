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

# === EXPORTED VARIABLES ===
# Removed exports in favor of Tweakables

# === PUBLIC VARIABLES ===
var jump_velocity: float = -400.0

# === PRIVATE VARIABLES ===
var _current_target: Node2D = null


# === ENUMS ===

# === ONREADY VARIABLES ===

# === BUILT-IN METHODS ===
func _ready() -> void:
	super._ready()


	if hitbox_area:
		if not hitbox_area.body_entered.is_connected(_on_hitbox_body_entered):
			hitbox_area.body_entered.connect(_on_hitbox_body_entered)

	pass


# === PUBLIC METHODS ===

func die() -> void:
	# Drop features if any

	# Play death animation if available (TODO)
	queue_free()


# === OVERRIDDEN METHODS ===

func _process_physics(delta: float) -> void:
	_process_ai(delta)

	# Check for collision with player to kill
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is BasePlayer:
			collider.take_damage(collider.max_health)

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

# === PRIVATE METHODS ===

const FRICTION: float = 1200.0



# === SIGNAL CALLBACKS ===


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body is BasePlayer:
		body.take_damage(body.max_health)
