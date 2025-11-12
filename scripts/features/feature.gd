## Feature - Abstract Base Class
##
## Base class for all character features (wings, grappling, push, etc.)
## Features are components that modify character physics/behavior.
##
## Features inherit from PhysicsChanger and are managed by the Character.
## They can be activated/deactivated based on game state (e.g., nearby interactions).
class_name Feature
extends PhysicsChanger

# === SIGNALS ===
signal feature_activated()
signal feature_deactivated()

# === EXPORTED VARIABLES ===
@export var feature_name: String = "UnnamedFeature"
@export var enabled: bool = true

# === PRIVATE VARIABLES ===
var _active: bool = false

# === PUBLIC METHODS ===

## Activate this feature (called by Character)
func activate() -> void:
	if not enabled:
		return

	_active = true
	_on_activated()
	feature_activated.emit()

## Deactivate this feature (called by Character)
func deactivate() -> void:
	_active = false
	_on_deactivated()
	feature_deactivated.emit()

## Check if this feature is currently active
func is_active() -> bool:
	return _active and enabled

# === VIRTUAL METHODS (Override in child classes) ===

## Called when feature is activated - override for custom behavior
func _on_activated() -> void:
	pass

## Called when feature is deactivated - override for custom behavior
func _on_deactivated() -> void:
	pass

## Get movement factor - MUST be overridden
## @param delta: The physics delta time
## @param character_position: The current position of the character
## @return Vector2: The movement factor to apply
func get_movement_factor(delta: float, character_position: Vector2) -> Vector2:
	if not is_active():
		return Vector2.ZERO

	return _calculate_movement_factor(delta, character_position)

## Override this in child classes to implement feature-specific physics
func _calculate_movement_factor(delta: float, character_position: Vector2) -> Vector2:
	push_error("Feature._calculate_movement_factor() must be overridden in: " + feature_name)
	return Vector2.ZERO
