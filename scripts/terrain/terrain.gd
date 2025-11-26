## Terrain - Abstract Base Class
##
## Base class for all terrain types (underwater, ice, mud, etc.)
## Terrains modify character physics based on environmental conditions.
##
## Terrains inherit from PhysicsChanger and affect characters within their area.
## Example: Underwater terrain slows down movement, ice terrain reduces friction.
class_name Terrain
extends PhysicsChanger

# === SIGNALS ===
signal character_entered(character: CharacterBody2D)
signal character_exited(character: CharacterBody2D)

# === EXPORTED VARIABLES ===
@export var terrain_name: String = "UnnamedTerrain"
@export var affects_movement: bool = true

# === PRIVATE VARIABLES ===
var _characters_in_terrain: Array[CharacterBody2D] = []

# === PUBLIC VARIABLES ===
var detection_area: Area2D

# === BUILT-IN METHODS ===
func _ready() -> void:
	detection_area = _find_detection_area()

	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)
	else:
		push_warning("Terrain '%s' has no DetectionArea child node!" % terrain_name)

func _find_detection_area() -> Area2D:
	if has_node("DetectionArea"):
		return $DetectionArea

	for child in get_children():
		if child is Area2D:
			return child

	return null

# === PUBLIC METHODS ===

## Check if a specific character is in this terrain
func is_character_in_terrain(character: CharacterBody2D) -> bool:
	return character in _characters_in_terrain

## Get all characters currently in this terrain
func get_characters_in_terrain() -> Array[CharacterBody2D]:
	return _characters_in_terrain.duplicate()

# === VIRTUAL METHODS (Override in child classes) ===

## Get movement factor - MUST be overridden
## @param delta: The physics delta time
## @param character_position: The current position of the character
## @return Vector2: The movement factor to apply (can be negative to slow down)
func get_movement_factor(delta: float, character_position: Vector2) -> Vector2:
	if not affects_movement:
		return Vector2.ZERO

	return _calculate_terrain_effect(delta, character_position)

## Override this in child classes to implement terrain-specific physics
func _calculate_terrain_effect(_delta: float, _character_position: Vector2) -> Vector2:
	push_error("Terrain._calculate_terrain_effect() must be overridden in: " + terrain_name)
	return Vector2.ZERO

## Get damping factor for energy loss (override in child classes)
## @return float: Damping multiplier (0.99 = 1% loss per second, 1.0 = no damping)
func get_damping_factor() -> float:
	return 1.0  # No damping by default

## Apply terrain-specific damping to a character (override in child classes)
## @param character: The character to apply damping to
## @param delta: The physics delta time
func apply_damping(character: CharacterBody2D, delta: float) -> void:
	var damping_factor: float = get_damping_factor()
	if damping_factor < 1.0:
		# Apply damping: velocity = velocity * damping^(delta * 60)
		# This creates exponential decay (realistic energy loss)
		var damping_per_frame: float = pow(damping_factor, delta * 60.0)
		character.velocity *= damping_per_frame

## Called when a character enters this terrain
func _on_character_entered(character: CharacterBody2D) -> void:
	pass

## Called when a character exits this terrain
func _on_character_exited(character: CharacterBody2D) -> void:
	pass

# === SIGNAL CALLBACKS ===
func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_characters_in_terrain.append(body)
		_on_character_entered(body)
		character_entered.emit(body)

		if body.has_method("enter_terrain"):
			body.enter_terrain(self)

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_characters_in_terrain.erase(body)
		_on_character_exited(body)
		character_exited.emit(body)

		if body.has_method("exit_terrain"):
			body.exit_terrain(self)
