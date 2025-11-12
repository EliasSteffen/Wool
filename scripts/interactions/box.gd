## Box - Pushable Interaction
##
## A box that can be pushed by characters.
## Activates the push feature when in nearby_interactions.
class_name Box
extends Interaction

# === EXPORTED VARIABLES ===
@export var weight: float = 1.0  # Affects how hard it is to push
@export var can_be_pushed: bool = true

# === PRIVATE VARIABLES ===
var _being_pushed_by: CharacterBody2D = null

# === OVERRIDDEN METHODS ===

func _setup_interaction() -> void:
	interaction_name = "Box"
	# Box-specific setup

func _on_character_entered(character: CharacterBody2D) -> void:
	# Character is near box and can potentially push it
	pass

func _on_character_exited(character: CharacterBody2D) -> void:
	# Stop being pushed if character leaves
	if _being_pushed_by == character:
		stop_being_pushed()

func _on_interaction_used(character: CharacterBody2D) -> void:
	# Box is being pushed
	_being_pushed_by = character

# === PUBLIC METHODS ===

## Start being pushed by a character
func start_being_pushed(character: CharacterBody2D) -> void:
	if not can_be_pushed:
		return

	_being_pushed_by = character
	set_used(true)

## Stop being pushed
func stop_being_pushed() -> void:
	_being_pushed_by = null
	set_used(false)

## Get the character currently pushing this box
func get_pusher() -> CharacterBody2D:
	return _being_pushed_by

## Check if box is currently being pushed
func is_being_pushed() -> bool:
	return _being_pushed_by != null
