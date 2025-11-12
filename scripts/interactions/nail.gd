## Nail - Grappling Interaction
##
## A nail that can be grappled to.
## Activates the grappling feature when in nearby_interactions.
class_name Nail
extends Interaction

# === EXPORTED VARIABLES ===
@export var grapple_point_offset: Vector2 = Vector2.ZERO

# === OVERRIDDEN METHODS ===

func _setup_interaction() -> void:
	interaction_name = "Nail"
	# Nail-specific setup

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
