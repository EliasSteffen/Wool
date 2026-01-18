## Nail - Grappling Interaction
##
## A nail that can be grappled to.
## Activates the grappling feature when in nearby_interactions.
class_name Nail
extends Interaction

# === EXPORTED VARIABLES ===
@export var grapple_point_offset: Vector2 = Vector2.ZERO
@export var is_rusty: bool = false

# === OVERRIDDEN METHODS ===

func _setup_interaction() -> void:
	interaction_name = "Nail"

	# Set colors based on type
	if is_rusty:
		normal_color = InteractionConstants.get_value("Visuals", "rusty_nail_color", InteractionConstants.DEFAULT_RUSTY_NAIL_COLOR)
	else:
		normal_color = InteractionConstants.get_value("Visuals", "nail_color", InteractionConstants.DEFAULT_NORMAL_COLOR)

	highlight_color = InteractionConstants.get_value("Visuals", "highlight_nail_color", InteractionConstants.DEFAULT_HIGHLIGHT_COLOR)

	# Nail-specific setup

	_update_visual()

## Setup tweakables
func _setup_tweakables() -> void:
	# Colors are set in _setup_interaction, no need to set again
	if not InteractionConstants.value_changed.is_connected(_on_tweakable_changed):
		InteractionConstants.value_changed.connect(_on_tweakable_changed)

	_update_visual()

func _on_tweakable_changed(category: String, key: String, value: Variant) -> void:
	if category == "Visuals":
		match key:
			"highlight_nail_color":
				highlight_color = value
				_update_visual()
			"nail_color":
				if not is_rusty:
					normal_color = value
					_update_visual()
			"rusty_nail_color":
				if is_rusty:
					normal_color = value
					_update_visual()

func _on_character_entered(character: CharacterBody2D) -> void:
	# Notify character that this nail is available for grappling
	pass

func _on_character_exited(character: CharacterBody2D) -> void:
	# Character left range
	pass

## Get the exact point to grapple to
func get_interaction_point() -> Vector2:
	return global_position + grapple_point_offset

## Get grapple point (alias for clarity)
func get_grapple_point() -> Vector2:
	return get_interaction_point()

## Get the effective detection radius
func get_detection_radius() -> float:
	# Try to find the collision shape by name first
	var collision_shape = get_node_or_null("CollisionShape2D")

	# If not found or not a circle, search children
	if not collision_shape or not (collision_shape.shape is CircleShape2D):
		for child in get_children():
			if child is CollisionShape2D and child.shape is CircleShape2D:
				collision_shape = child
				break

	if collision_shape and collision_shape.shape is CircleShape2D:
		# Use the global scale of the collision shape itself to account for all parent scaling AND its own scaling
		var shape_scale = collision_shape.global_scale
		var max_scale = max(abs(shape_scale.x), abs(shape_scale.y))
		return collision_shape.shape.radius * max_scale

	push_warning("Nail: Could not calculate detection radius. Using default 100.0")
	return 100.0
