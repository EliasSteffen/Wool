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

func _ready() -> void:
	print("FeaturePickup: Ready! Global Pos: ", global_position, " Monitoring: ", monitoring, " Monitorable: ", monitorable)
	# Setup visual
	if icon_texture:
		sprite.texture = icon_texture

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
		# Scale to fit the hitbox (uniform scaling based on the larger dimension to fill it)
		var scale_factor = max(target_size.x / tex_size.x, target_size.y / tex_size.y)
		sprite.scale = Vector2(scale_factor, scale_factor)

func _physics_process(delta: float) -> void:
    # Fallback: Active monitoring if Area2D signals fail
	if Engine.get_physics_frames() % 5 == 0:
		# Method 1: Check overlapping bodies (Standard)
		var bodies = get_overlapping_bodies()
		for b in bodies:
			_on_body_entered(b)

		# Method 2: Point Query (Aggressive Fallback)
		# Checks if the center of the pickup is inside any body
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = global_position
		query.collision_mask = collision_mask
		query.collide_with_bodies = true
		query.collide_with_areas = false

		var results = space_state.intersect_point(query)
		for res in results:
			if res.collider and is_instance_valid(res.collider):
				_on_body_entered(res.collider)
func _on_body_entered(body: Node2D) -> void:
	print("FeaturePickup: Body entered - ", body.name)

	if body is BasePlayer:
		_give_feature(body)
	# Check via group or duck typing as fallback if class check fails
	elif body.is_in_group("player") or body.has_method("pickup_feature"):
		_give_feature(body)

func _give_feature(player: Node) -> void:
	if not feature_script:
		push_error("FeaturePickup: No feature script assigned!")
		queue_free()
		return

	# Create new instance of the feature
	var new_feature = feature_script.new()
	print("FeaturePickup: Created new feature instance: ", new_feature)
	new_feature.name = feature_name

	# Pass to player
	print("FeaturePickup: Giving feature to player...")
	player.pickup_feature(new_feature)

	print("FeaturePickup: Picked up feature '%s'" % feature_name)

	queue_free()
