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
	# Setup visual
	if icon_texture:
		sprite.texture = icon_texture

	# Setup collision
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

func _on_body_entered(body: Node2D) -> void:
	if body is BasePlayer:
		_give_feature(body)

func _give_feature(player: BasePlayer) -> void:
	if not feature_script:
		push_error("FeaturePickup: No feature script assigned!")
		queue_free()
		return

	# Create new instance of the feature
	var new_feature = feature_script.new()
	new_feature.name = feature_name

	# Pass to player
	player.pickup_feature(new_feature)

	print("FeaturePickup: Picked up feature '%s'" % feature_name)

	queue_free()
