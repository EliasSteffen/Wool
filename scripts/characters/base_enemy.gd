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
			
	GameManager.state_changed.connect(_on_game_state_changed)

func _on_game_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.GAME_OVER:
		_stop_audio()

func _stop_audio() -> void:
	# Override in specific enemies if they have audio
	pass

	pass


# === PUBLIC METHODS ===

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

# === PRIVATE METHODS ===

const FRICTION: float = 1200.0



# === SIGNAL CALLBACKS ===


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body is BasePlayer:
		body.take_damage(body.max_health)
