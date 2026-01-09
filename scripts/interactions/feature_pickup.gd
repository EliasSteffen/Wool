class_name FeaturePickup
extends Area2D

## FeaturePickup - Item that gives a feature to the player
##
## Spawns when an enemy dies.
## When the player touches it, the feature is added to the player.

var feature_script: Script
var feature_name: String
var icon_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _picked_up: bool = false

func _ready() -> void:
	# print("FeaturePickup: Ready! Global Pos: ", global_position, " Monitoring: ", monitoring, " Monitorable: ", monitorable)
	# Setup visual
	if icon_texture:
		sprite.texture = icon_texture

	# Ensure mask is correct (Layer 1 and 2 and 3 just to be safe)
	collision_mask = 1 | 2 | 4 | 8 # Scan masks 1, 2, 3, 4 (binary 1, 10, 100, 1000)

	# Setup collision
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


	# Simple floating animation
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -10.0, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", 0.0, 1.0).set_trans(Tween.TRANS_SINE)

	_update_sprite_size()

func setup(feature: Feature) -> void:
	feature_script = feature.get_script()
	feature_name = feature.feature_name
	icon_texture = feature.drop_icon

	if sprite and icon_texture:
		sprite.texture = icon_texture
		_update_sprite_size()

func _update_sprite_size() -> void:
	if not sprite or not sprite.texture or not collision_shape or not collision_shape.shape:
		return

	var shape = collision_shape.shape
	var target_size = Vector2.ZERO

	if shape is RectangleShape2D:
		target_size = shape.size
	elif shape is CircleShape2D:
		target_size = Vector2(shape.radius * 2, shape.radius * 2)
	elif shape is CapsuleShape2D:
		target_size = Vector2(shape.radius * 2, shape.height)

	if target_size != Vector2.ZERO:
		var tex_size = sprite.texture.get_size()
		# Scale to fit INSIDE the hitbox (Contain)
		# Use MIN to ensure the sprite stays within the collision bounds
		# This guarantees that if you touch the visual sprite, you are definitely inside the hitbox.
		var scale_factor = min(target_size.x / tex_size.x, target_size.y / tex_size.y)
		sprite.scale = Vector2(scale_factor, scale_factor)

# func _draw() -> void:
	# DEBUG VISUALIZATION
	# if collision_shape and collision_shape.shape:
		# var shape = collision_shape.shape
		# if shape is CircleShape2D:
			# draw_circle(collision_shape.position, shape.radius, Color(1, 0, 0, 0.4))
		# elif shape is RectangleShape2D:
			# draw_rect(Rect2(collision_shape.position - shape.size/2, shape.size), Color(1, 0, 0, 0.4))


func _physics_process(delta: float) -> void:
	if _picked_up: return

	# Fallback: Active monitoring if Area2D signals fail
	# We check every frame because the player can be fast
	var bodies = get_overlapping_bodies()
	for b in bodies:
		if b is BasePlayer or b.is_in_group("player"):
			_on_body_entered(b)

	# DEBUG: Check distance to player manually
	# var players = get_tree().get_nodes_in_group("player")
	# if players.size() > 0:
	# 	var p = players[0] as Node2D
	# 	var dist = global_position.distance_to(p.global_position)
	# 	if dist < 80.0: # 80 pixels is slightly larger than radius 50 + player radius
	# 		# print("FeaturePickup: Close to player (%.2f), forcing check..." % dist)
	# 		_on_body_entered(p)

func _on_body_entered(body: Node2D) -> void:
	if _picked_up: return

	# Only log if it's the player, to avoid spamming "Body entered - StaticBody2D"
	if body is BasePlayer or body.is_in_group("player"):
		# print("FeaturePickup: Body entered - ", body.name)
		_give_feature(body)
	elif body.has_method("pickup_feature"):
		_give_feature(body)

func _give_feature(player: Node) -> void:
	if _picked_up: return
	_picked_up = true

	if not feature_script:
		push_error("FeaturePickup: No feature script assigned!")
		queue_free()
		return

	# Create new instance of the feature
	var new_feature = feature_script.new()
	# print("FeaturePickup: Created new feature instance: ", new_feature)
	new_feature.name = feature_name

	# Pass to player
	# print("FeaturePickup: Giving feature to player...")
	player.pickup_feature(new_feature)

	print("FeaturePickup: Picked up feature '%s'" % feature_name)

	queue_free()
