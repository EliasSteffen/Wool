class_name BaseNail
extends Interaction

## Base Class for all Nails (Normal, Rusty, etc.)
## Defines standardized structure:
## - GrapplePoint (Marker2D)
## - Back Sprite (z_index = -1)
## - Front Sprite (z_index = 1)
## - Detection Radius

@export var grapple_point_offset: Vector2 = Vector2.ZERO

# Standardized Child Node Names
const NODE_BACK_SPRITE = "BackSprite"
const NODE_FRONT_SPRITE = "FrontSprite"
const NODE_GRAPPLE_POINT = "GrapplePoint"
const NODE_SHADOW_SPRITE = "ShadowSprite"

func _ready() -> void:
	super._ready()
	_enforce_z_ordering()
	add_to_group("nails")

func _setup_interaction() -> void:
	interaction_name = "BaseNail"
	# Default visual update
	_update_visual()

func _enforce_z_ordering() -> void:
	# Ensure standard layering for player interaction
	var back = get_node_or_null(NODE_BACK_SPRITE)
	if back:
		back.z_index = 0 # Base Layer

	var front = get_node_or_null(NODE_FRONT_SPRITE)
	if front:
		front.z_index = 2 # Top Layer

	var shadow = get_node_or_null(NODE_SHADOW_SPRITE)
	if shadow:
		shadow.z_index = -1 # Background Shadow Layer

	# Wool's pickaxe uses Z-Index 1 to sit between them.

func get_grapple_point() -> Vector2:
	return global_position + grapple_point_offset

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

	# Fallback
	return 100.0

# Virtual method for visual updates
func _update_visual() -> void:
	pass

func get_boost_multiplier() -> float:
	return 1.0
