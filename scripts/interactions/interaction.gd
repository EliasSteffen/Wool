## Interaction - Abstract Base Class
##
## Base class for all interactive objects (Nail, Box, etc.)
## Interactions are objects that characters can interact with.
##
## Interactions notify the character when they enter/exit range,
## and the character decides whether to activate corresponding features.
class_name Interaction
extends Area2D

# === SIGNALS ===
signal character_in_range(character: CharacterBody2D, interaction: Interaction)
signal character_out_of_range(character: CharacterBody2D, interaction: Interaction)
signal interaction_used(character: CharacterBody2D)

# === EXPORTED VARIABLES ===
@export var interaction_name: String = "UnnamedInteraction"
@export var is_active: bool = true
@export var highlight_on_range: bool = true
@export var highlight_color: Color = Color(1.5, 1.5, 1.5, 1.0)
@export var normal_color: Color = Color(1.0, 1.0, 1.0, 1.0)

# === PRIVATE VARIABLES ===
var _characters_in_range: Array[CharacterBody2D] = []
var _is_being_used: bool = false

# === ONREADY VARIABLES ===
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

# === BUILT-IN METHODS ===
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if sprite:
		sprite.modulate = normal_color

	_setup_interaction()

# === PUBLIC METHODS ===

## Check if a specific character is in range
func is_character_in_range(character: CharacterBody2D) -> bool:
	return character in _characters_in_range

## Get all characters currently in range
func get_characters_in_range() -> Array[CharacterBody2D]:
	return _characters_in_range.duplicate()

## Mark interaction as being used
func set_used(used: bool) -> void:
	_is_being_used = used
	_update_visual()

## Check if interaction is currently being used
func is_being_used() -> bool:
	return _is_being_used

# === VIRTUAL METHODS (Override in child classes) ===

## Override for custom setup logic
func _setup_interaction() -> void:
	pass

## Called when a character enters interaction range
func _on_character_entered(character: CharacterBody2D) -> void:
	pass

## Called when a character exits interaction range
func _on_character_exited(character: CharacterBody2D) -> void:
	pass

## Called when interaction is used by a character
func _on_interaction_used(character: CharacterBody2D) -> void:
	pass

## Get the interaction point (e.g., grapple point for nail)
## Override in child classes for custom interaction points
func get_interaction_point() -> Vector2:
	return global_position

# === PRIVATE METHODS ===
func _update_visual() -> void:
	if not sprite or not highlight_on_range:
		return

	if _characters_in_range.size() > 0 and not _is_being_used:
		sprite.modulate = highlight_color
	else:
		sprite.modulate = normal_color

# === SIGNAL CALLBACKS ===
func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return

	if body is CharacterBody2D:
		_characters_in_range.append(body)
		_update_visual()
		_on_character_entered(body)
		character_in_range.emit(body, self)

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_characters_in_range.erase(body)
		_update_visual()
		_on_character_exited(body)
		character_out_of_range.emit(body, self)
