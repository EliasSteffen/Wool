class_name Checkpoint
extends Area2D

# === SIGNALS ===
signal checkpoint_activated(checkpoint_pos: Vector2)

# === PRIVATE VARIABLES ===
var _is_active: bool = false
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# === BUILT-IN METHODS ===
func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	# Ensure monitoring
	monitoring = true
	monitorable = true

	# Make sure we collide with player (Layer 2 usually) + Default (Layer 1)
	collision_mask = 1 | 2

func _on_body_entered(body: Node2D) -> void:
	if body is BasePlayer:
		if body.has_method("checkpoint_reached"):
			body.checkpoint_reached()
			_activate(body)

func _activate(_player: BasePlayer) -> void:
	if _is_active:
		return

	_is_active = true
	print("Checkpoint activated at ", global_position)

	# Visual feedback could go here
