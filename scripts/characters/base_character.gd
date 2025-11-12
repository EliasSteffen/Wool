## BaseCharacter - Abstract Base Class for all Characters
##
## Implements the core character logic according to architecture.excalidraw:
## - Manages list of features
## - Manages current_terrain
## - Manages nearby_interactions
## - Manages skin
## - Iterates over all features to calculate final movement
##
## Both Player and Enemy inherit from this class.
class_name BaseCharacter
extends CharacterBody2D

# === SIGNALS ===
signal feature_added(feature: Feature)
signal feature_removed(feature: Feature)
signal interaction_detected(interaction: Interaction)
signal interaction_lost(interaction: Interaction)
signal terrain_entered(terrain: Terrain)
signal terrain_exited(terrain: Terrain)

# === CONSTANTS ===
const GRAVITY: float = 980.0

# === EXPORTED VARIABLES ===
@export var max_health: int = 100
@export var move_speed: float = 200.0

# === PUBLIC VARIABLES ===
var current_health: int = 100
var nearby_interactions: Array[Interaction] = []
var current_terrain: Terrain = null

# === PRIVATE VARIABLES ===
var _features: Array[Feature] = []
var _physics_changers: Array[PhysicsChanger] = []
var _default_air_terrain: AirTerrain = null  # Default terrain for air resistance

# === ONREADY VARIABLES ===
@onready var skin: BodySkin = $Skin if has_node("Skin") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var features_container: Node = $Features if has_node("Features") else null

# === BUILT-IN METHODS ===
func _ready() -> void:
	current_health = max_health
	_setup_default_air_terrain()
	_setup_features()
	_connect_to_interactions()
	_setup_character()

func _physics_process(delta: float) -> void:
	# Apply gravity if not on floor
	if not is_on_floor():
		velocity.y += _calculate_gravity(delta)

	# Calculate movement from all features and physics changers
	var movement_factor: Vector2 = _calculate_all_movement_factors(delta)
	velocity += movement_factor

	# Apply terrain damping (energy loss)
	_apply_terrain_damping(delta)

	# Custom physics processing (override in child classes)
	_process_physics(delta)

	# Apply movement
	move_and_slide()

	# Apply rope constraint AFTER movement (if grappling)
	_apply_grapple_constraint()

# === PUBLIC METHODS ===

## Add a feature to this character
func add_feature(feature: Feature) -> void:
	if feature in _features:
		push_warning("Feature '%s' already added to character!" % feature.feature_name)
		return

	_features.append(feature)
	_physics_changers.append(feature)
	feature_added.emit(feature)

## Remove a feature from this character
func remove_feature(feature: Feature) -> void:
	_features.erase(feature)
	_physics_changers.erase(feature)
	feature_removed.emit(feature)

## Get all features
func get_features() -> Array[Feature]:
	return _features.duplicate()

## Get a specific feature by name
func get_feature_by_name(feature_name: String) -> Feature:
	for feature in _features:
		if feature.feature_name == feature_name:
			return feature
	return null

## Get a specific feature by type
func get_feature_by_type(feature_type: Variant) -> Feature:
	for feature in _features:
		if is_instance_of(feature, feature_type):
			return feature
	return null

## Add an interaction to nearby list
func add_nearby_interaction(interaction: Interaction) -> void:
	if interaction not in nearby_interactions:
		nearby_interactions.append(interaction)
		_on_interaction_detected(interaction)
		interaction_detected.emit(interaction)

## Remove an interaction from nearby list
func remove_nearby_interaction(interaction: Interaction) -> void:
	nearby_interactions.erase(interaction)
	_on_interaction_lost(interaction)
	interaction_lost.emit(interaction)

## Set current terrain
func set_current_terrain(terrain: Terrain) -> void:
	if current_terrain == terrain:
		return

	var old_terrain: Terrain = current_terrain
	current_terrain = terrain

	if old_terrain:
		terrain_exited.emit(old_terrain)

	if terrain:
		terrain_entered.emit(terrain)

## Take damage
func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	if current_health == 0:
		_on_death()

## Heal
func heal(amount: int) -> void:
	current_health = min(max_health, current_health + amount)

# === VIRTUAL METHODS (Override in child classes) ===

## Custom setup logic - override in child classes
func _setup_character() -> void:
	pass

## Custom physics processing - override in child classes
func _process_physics(delta: float) -> void:
	pass

## Called when an interaction is detected
func _on_interaction_detected(interaction: Interaction) -> void:
	pass

## Called when an interaction is lost
func _on_interaction_lost(interaction: Interaction) -> void:
	pass

## Called when character dies
func _on_death() -> void:
	queue_free()

# === PRIVATE METHODS ===

## Setup default air terrain for energy loss
func _setup_default_air_terrain() -> void:
	_default_air_terrain = AirTerrain.new()
	_default_air_terrain.air_resistance = 0.99  # 1% loss per second
	add_child(_default_air_terrain)
	current_terrain = _default_air_terrain

## Setup all features in the Features container
func _setup_features() -> void:
	if not features_container:
		return

	for child in features_container.get_children():
		if child is Feature:
			add_feature(child)

## Connect to all interactions in the scene
func _connect_to_interactions() -> void:
	# Find all Interaction nodes in the current scene
	var interactions: Array[Node] = get_tree().get_nodes_in_group("interactions")

	# If no group, try finding all Area2D that are Interactions
	if interactions.is_empty():
		_find_interactions_recursive(get_tree().root)
	else:
		for interaction in interactions:
			if interaction is Interaction:
				_connect_interaction(interaction)

func _find_interactions_recursive(node: Node) -> void:
	if node is Interaction and node != self:
		_connect_interaction(node)

	for child in node.get_children():
		_find_interactions_recursive(child)

func _connect_interaction(interaction: Interaction) -> void:
	if not interaction.character_in_range.is_connected(_on_interaction_entered):
		interaction.character_in_range.connect(_on_interaction_entered)
	if not interaction.character_out_of_range.is_connected(_on_interaction_exited):
		interaction.character_out_of_range.connect(_on_interaction_exited)

## Signal callback when interaction is entered
func _on_interaction_entered(character: CharacterBody2D, interaction: Interaction) -> void:
	if character == self:
		add_nearby_interaction(interaction)

## Signal callback when interaction is exited
func _on_interaction_exited(character: CharacterBody2D, interaction: Interaction) -> void:
	if character == self:
		remove_nearby_interaction(interaction)

## Calculate gravity with feature modifications
func _calculate_gravity(delta: float) -> float:
	var gravity: float = GRAVITY

	# Check for features that modify gravity (e.g., wings)
	for feature in _features:
		if feature is WingsFeature and feature.is_active():
			gravity *= feature.get_fall_speed_multiplier()

	return gravity * delta

## Calculate combined movement factor from all PhysicsChangers
## This is the core of the architecture!
func _calculate_all_movement_factors(delta: float) -> Vector2:
	var total_factor: Vector2 = Vector2.ZERO

	# Iterate over all features
	for feature in _features:
		if feature.is_active():
			total_factor += feature.get_movement_factor(delta, global_position)

	# Add terrain effect if in terrain
	if current_terrain:
		total_factor += current_terrain.get_movement_factor(delta, global_position)

	return total_factor

## Apply terrain damping (energy loss over time)
func _apply_terrain_damping(delta: float) -> void:
	# Default air resistance if no terrain
	var damping_factor: float = 0.99  # 1% energy loss per second in air

	# Use terrain's damping if available
	if current_terrain and current_terrain.has_method("get_damping_factor"):
		damping_factor = current_terrain.get_damping_factor()

	# Apply damping: velocity = velocity * damping^delta
	# This creates exponential decay (realistic energy loss)
	var damping_per_frame: float = pow(damping_factor, delta * 60.0)  # Convert to per-frame
	velocity *= damping_per_frame

## Apply rope constraint when grappling (prevents going beyond rope length)
func _apply_grapple_constraint() -> void:
	# Find active grappling feature
	var grappling: GrapplingFeature = null
	for feature in _features:
		if feature is GrapplingFeature and feature.is_active():
			grappling = feature
			break

	if not grappling:
		return

	var grapple_point: Vector2 = grappling.get_target()
	if grapple_point == Vector2.ZERO:
		return

	# Only apply constraint after initial pull
	if not grappling._has_reached_rope_length:
		return

	# Check if beyond rope length
	var to_grapple: Vector2 = grapple_point - global_position
	var distance: float = to_grapple.length()

	if distance > grappling.rope_length:
		# Constrain position to rope_length
		var direction: Vector2 = to_grapple.normalized()
		global_position = grapple_point - direction * grappling.rope_length

		# Project velocity to be tangent to rope (remove radial component)
		var velocity_radial: float = velocity.dot(direction)
		if velocity_radial < 0:  # Only remove outward velocity
			velocity -= direction * velocity_radial
