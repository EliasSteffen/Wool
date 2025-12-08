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

func setup(feature: Feature) -> void:
	feature_script = feature.get_script()
	feature_name = feature.feature_name
	icon_texture = feature.drop_icon

	if sprite and icon_texture:
		sprite.texture = icon_texture

func _on_body_entered(body: Node2D) -> void:
	if body is BasePlayer:
		_give_feature(body)

func _give_feature(player: BasePlayer) -> void:
	if not feature_script:
		push_error("FeaturePickup: No feature script assigned!")
		queue_free()
		return

	# Check if player already has this feature type
	var existing_feature = player.get_feature_by_name(feature_name)

	if existing_feature:
		# If player has it but it's disabled, enable it
		if not existing_feature.enabled:
			existing_feature.enabled = true
			existing_feature.activate() # Activate it immediately!
			print("FeaturePickup: Enabled existing feature '%s'" % feature_name)
			# Optional: Show pickup effect
	else:
		# Create new instance of the feature
		var new_feature = feature_script.new()
		new_feature.name = feature_name
		new_feature.enabled = true

		# Add to player's Features node
		if player.features_container:
			player.features_container.add_child(new_feature)
			# Note: Feature automatically registers itself in _ready()
			new_feature.activate() # Activate it immediately!
			print("FeaturePickup: Added new feature '%s'" % feature_name)
		else:
			player.add_child(new_feature)
			new_feature.activate() # Activate it immediately!
			print("FeaturePickup: Added new feature '%s' (no container)" % feature_name)

	queue_free()
