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

# === PRIVATE VARIABLES ===
var _current_target: Node2D = null
var _is_attacking: bool = false
var _ai_state: AIState = AIState.IDLE

# === ENUMS ===
enum AIState {
	IDLE,
	PATROL,
	CHASE,
	ATTACK
}

# === ONREADY VARIABLES ===
@onready var detection_area: Area2D = $DetectionArea if has_node("DetectionArea") else null

# === BUILT-IN METHODS ===
func _ready() -> void:
	super._ready()
	_setup_enemy_tweakables()

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

	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)

# === OVERRIDDEN METHODS ===

func _process_physics(delta: float) -> void:
	_process_ai(delta)

# === VIRTUAL METHODS (Override in specific enemy types) ===

## Override for custom AI behavior
func _process_ai(delta: float) -> void:
	match _ai_state:
		AIState.IDLE:
			_ai_idle(delta)
		AIState.PATROL:
			_ai_patrol(delta)
		AIState.CHASE:
			_ai_chase(delta)
		AIState.ATTACK:
			_ai_attack(delta)

func _ai_idle(delta: float) -> void:
	# Default: do nothing
	velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

func _ai_patrol(delta: float) -> void:
	# Default: simple back-and-forth patrol
	# Override in child classes for custom patrol
	pass

func _ai_chase(delta: float) -> void:
	if not _current_target:
		_change_state(AIState.IDLE)
		return

	# Move towards target
	var direction: float = sign(_current_target.global_position.x - global_position.x)
	velocity.x = direction * chase_speed

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

# === SIGNAL CALLBACKS ===

func _on_detection_body_entered(body: Node2D) -> void:
	# Detect players
	if body is BasePlayer:
		set_target(body)

func _on_detection_body_exited(body: Node2D) -> void:
	if body == _current_target:
		set_target(null)
