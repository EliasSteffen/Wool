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
signal attack_started()
signal attack_ended()

# === EXPORTED VARIABLES ===
# Removed exports in favor of Tweakables

# === PUBLIC VARIABLES ===
var attack_damage: int
var attack_range: float
var detection_range: float
var patrol_speed: float
var chase_speed: float
var patrol_distance: float = 300.0
var jump_velocity: float = -400.0

# === PRIVATE VARIABLES ===
var _current_target: Node2D = null
var _is_attacking: bool = false
var _ai_state: AIState = AIState.IDLE
var _patrol_start_position: Vector2
var _patrol_direction: int = 1
var _feature_use_cooldown: float = 0.0

# === ENUMS ===
enum AIState {
	IDLE,
	CHASE,
	ATTACK
}

# === ONREADY VARIABLES ===
@onready var detection_area: Area2D = $DetectionArea if has_node("DetectionArea") else null
@onready var features_node: Node = $Features if has_node("Features") else null

# === BUILT-IN METHODS ===
func _ready() -> void:
	super._ready()
	_setup_enemy_tweakables()

	if detection_area:
		if not detection_area.body_entered.is_connected(_on_detection_body_entered):
			detection_area.body_entered.connect(_on_detection_body_entered)
		if not detection_area.body_exited.is_connected(_on_detection_body_exited):
			detection_area.body_exited.connect(_on_detection_body_exited)

	if hitbox_area:
		if not hitbox_area.body_entered.is_connected(_on_hitbox_body_entered):
			hitbox_area.body_entered.connect(_on_hitbox_body_entered)

	_patrol_start_position = global_position
	_ai_state = AIState.IDLE

func _setup_enemy_tweakables() -> void:
	attack_damage = int(CharacterConstants.get_value("Enemy", "attack_damage"))
	attack_range = CharacterConstants.get_value("Enemy", "attack_range")
	detection_range = CharacterConstants.get_value("Enemy", "detection_range")
	patrol_speed = CharacterConstants.get_value("Enemy", "patrol_speed")
	chase_speed = CharacterConstants.get_value("Enemy", "chase_speed")

	CharacterConstants.value_changed.connect(_on_enemy_tweakable_changed)

func _on_enemy_tweakable_changed(category: String, key: String, value: Variant) -> void:
	if category == "Enemy":
		match key:
			"attack_damage": attack_damage = int(value)
			"attack_range": attack_range = float(value)
			"detection_range": detection_range = float(value)
			"patrol_speed": patrol_speed = float(value)
			"chase_speed": chase_speed = float(value)

# === PUBLIC METHODS ===

func die() -> void:
	# Drop features if any
	if features_node:
		_drop_features()

	# Play death animation if available (TODO)
	queue_free()

func _drop_features() -> void:
	var pickup_scene = preload("res://scenes/interactions/feature_pickup.tscn")

	for child in features_node.get_children():
		if child is Feature:
			print("Dropping feature: ", child.feature_name)
			var pickup = pickup_scene.instantiate()

			# Setup pickup synchronously BEFORE adding to tree
			# This ensures data is copied before the feature/enemy is freed
			pickup.setup(child)

			# Set position (since it will be a sibling, global_position works, or position = position)
			pickup.global_position = global_position

			# Add to the world (parent of the enemy)
			get_parent().call_deferred("add_child", pickup)

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
	if _feature_use_cooldown > 0:
		_feature_use_cooldown -= delta

	match _ai_state:
		AIState.IDLE:
			_ai_idle(delta)
		AIState.CHASE:
			_ai_chase(delta)
		AIState.ATTACK:
			_ai_attack(delta)

func _ai_idle(delta: float) -> void:
	# Simple back-and-forth patrol
	var distance_from_start = global_position.x - _patrol_start_position.x

	# Check boundaries
	if abs(distance_from_start) >= patrol_distance:
		# Turn around if we went too far
		if distance_from_start > 0 and _patrol_direction > 0:
			_patrol_direction = -1
		elif distance_from_start < 0 and _patrol_direction < 0:
			_patrol_direction = 1

	# Check for wall collision
	if is_on_wall():
		_patrol_direction *= -1

	# Randomly jump (1% chance per frame)
	if is_on_floor() and randf() < 0.01:
		jump()

	# Randomly use features (2% chance per frame)
	if _feature_use_cooldown <= 0 and randf() < 0.02:
		_try_use_random_feature()

	# Apply movement
	velocity.x = move_toward(velocity.x, _patrol_direction * patrol_speed, 20.0)

	# Face direction
	if _patrol_direction > 0:
		if skin: skin.scale.x = abs(skin.scale.x)
	else:
		if skin: skin.scale.x = -abs(skin.scale.x)

func _ai_chase(delta: float) -> void:
	if not _current_target:
		_change_state(AIState.IDLE)
		return

	# Move towards target
	var direction_vector = global_position.direction_to(_current_target.global_position)
	velocity.x = move_toward(velocity.x, direction_vector.x * chase_speed, 20.0)

	# Jump logic
	if is_on_floor():
		# Jump if target is significantly higher
		if _current_target.global_position.y < global_position.y - 50:
			jump()
		# Jump if stuck on wall
		elif is_on_wall():
			jump()

	# Use features intelligently
	if _feature_use_cooldown <= 0:
		_try_use_smart_feature()

	# Face direction
	if direction_vector.x > 0:
		if skin: skin.scale.x = abs(skin.scale.x)
	elif direction_vector.x < 0:
		if skin: skin.scale.x = -abs(skin.scale.x)

func _ai_attack(delta: float) -> void:
	# Stop moving when attacking
	velocity.x = 0

	if not _is_attacking:
		_perform_attack()

## Override for custom attack behavior
func _perform_attack() -> void:
	_is_attacking = true
	attack_started.emit()

	# Simple attack: damage target if in range
	if _current_target and _current_target is BaseCharacter:
		_current_target.take_damage(attack_damage)

	# Attack cooldown (simple version)
	await get_tree().create_timer(1.0).timeout
	_is_attacking = false
	attack_ended.emit()

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
		_change_state(AIState.CHASE)
	else:
		target_lost.emit()
		_change_state(AIState.IDLE)

## Change AI state
func _change_state(new_state: AIState) -> void:
	if _ai_state == new_state:
		return

	_ai_state = new_state
	_on_state_changed(new_state)

## Called when AI state changes - override for custom behavior
func _on_state_changed(new_state: AIState) -> void:
	pass

# === PRIVATE METHODS ===

const FRICTION: float = 1200.0

func _update_ai_state() -> void:
	if not _current_target:
		_change_state(AIState.IDLE)
		return

	var distance_to_target: float = global_position.distance_to(_current_target.global_position)

	if distance_to_target <= attack_range:
		_change_state(AIState.ATTACK)
	elif distance_to_target <= detection_range:
		_change_state(AIState.CHASE)
	else:
		set_target(null)

func _try_use_random_feature() -> void:
	if not features_node:
		return

	var active_features: Array[Feature] = []
	for child in features_node.get_children():
		if child is Feature and child.is_active():
			active_features.append(child)

	if active_features.is_empty():
		return

	var feature = active_features.pick_random()
	feature.trigger()
	_feature_use_cooldown = randf_range(1.0, 3.0)

func _try_use_smart_feature() -> void:
	if not features_node or not _current_target:
		return

	for child in features_node.get_children():
		if not (child is Feature and child.is_active()):
			continue

		# Logic for specific features
		if child is DoubleJumpFeature:
			# Use double jump if target is high and we are falling or at peak of jump
			if not is_on_floor() and _current_target.global_position.y < global_position.y:
				if velocity.y > -100: # Falling or slow rise
					child.trigger()
					_feature_use_cooldown = 0.5
					return

		# Add logic for other features here (e.g. Dash, Glide)
		# For now, just random chance for others if needed

# === SIGNAL CALLBACKS ===

func _on_detection_body_entered(body: Node2D) -> void:
	# Detect players
	if body is BasePlayer:
		set_target(body)

func _on_detection_body_exited(body: Node2D) -> void:
	if body == _current_target:
		set_target(null)

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body is BasePlayer:
		body.take_damage(body.max_health)
