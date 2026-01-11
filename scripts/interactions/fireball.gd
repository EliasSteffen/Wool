class_name Fireball
extends Area2D

# Config - could be set by spawner or tweakables
var speed: float = 300.0
var direction: Vector2 = Vector2.UP
var lifetime: float = 5.0

func _ready() -> void:
	# Clean up after lifetime to prevent infinite existing objects
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

	# Connect collision if not already done in editor
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# Ignore self/shooter (if shooter was passed, but we don't have it here simply)
	if body is Plant:
		return

	if body is BasePlayer:
		if body.has_method("die"):
			body.die()
		queue_free()
	elif body is TileMap or body is StaticBody2D:
		# Destroy on wall hit
		queue_free()
