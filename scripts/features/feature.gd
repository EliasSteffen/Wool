## Feature - Abstract Base Class
##
## Base class for all character features (wings, grappling, push, etc.)
## Features are components that modify character physics/behavior.
##
## Features inherit from PhysicsChanger and are managed by the Character.
## They can be activated/deactivated based on game state (e.g., nearby interactions).
##
## Auto-Registration: Features automatically register themselves with their parent BaseCharacter in _ready()
class_name Feature
extends PhysicsChanger

# === SIGNALS ===
signal feature_activated()
signal feature_deactivated()
signal enabled_changed(enabled: bool)

# === EXPORTED VARIABLES ===
@export var feature_name: String = "UnnamedFeature"
@export var enabled: bool = true:
	set(value):
		if enabled != value:
			enabled = value
			enabled_changed.emit(enabled)
@export var auto_register: bool = true  # Automatically register with parent character
@export var drop_icon: Texture2D = null # Icon to display when dropped as item

# === PRIVATE VARIABLES ===
var _active: bool = false
var _character: Node = null  # Reference to owning character (typed as Node to avoid cyclic dependency)

# === BUILT-IN METHODS ===
func _ready() -> void:
	if auto_register:
		_register_with_character()

# === PUBLIC METHODS ===

## Get the character that owns this feature
func get_character() -> Node:
	return _character

## Activate this feature (called by Character)
func activate() -> void:
	if not enabled:
		print("Feature %s: Cannot activate because disabled" % feature_name)
		return

	_active = true
	print("Feature %s: Activated" % feature_name)
	_on_activated()
	feature_activated.emit()

## Trigger the feature's primary action (used by AI or manual calls)
## Override this in specific features (e.g. DoubleJump)
func trigger() -> void:
	pass

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

## Handle input for this feature - override for input-based features
## @param character: Reference to the character that owns this feature
## This is called during the character's physics processing
func handle_input(character: BaseCharacter) -> void:
	pass  # Override in child classes that need input

## Get gravity multiplier - override to modify fall speed
## @return float: Multiplier for gravity (1.0 = no change, 0.5 = half speed, etc.)
func get_gravity_multiplier() -> float:
	return 1.0  # No modification by default

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

# === PRIVATE METHODS ===

## Automatically find and register with parent BaseCharacter
func _register_with_character() -> void:
	# Walk up the tree to find a BaseCharacter parent
	var node: Node = get_parent()
	while node:
		if node is BaseCharacter:
			_character = node
			_character.add_feature(self)
			return
		node = node.get_parent()

	# If no BaseCharacter found, warn user
	push_warning("Feature '%s' could not find a BaseCharacter parent! Ensure it's a child (or descendant) of a BaseCharacter." % feature_name)
