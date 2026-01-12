## ThreadInteraction - A thread that can be cut
##
## Represents a thread or string that blocks the way or holds something.
## Can be cut by the character when in range.
class_name ThreadInteraction
extends Interaction

# === SIGNALS ===
signal cut()

# === EXPORTED VARIABLES ===
@export var is_cuttable: bool = true
@export var cut_texture: Texture2D ## Texture to display when cut

# === ONREADY VARIABLES ===
@onready var obstacle_collision: CollisionShape2D = $StaticBody2D/CollisionShape2D

# === OVERRIDDEN METHODS ===
func _setup_interaction() -> void:
	interaction_name = "Thread"
	# Remove prompt as player cuts automatically on contact/attack
	prompt_action = ""
	prompt_text = ""

func _ready() -> void:
	super._ready()

	# Ensure monitoring is active so key interaction features (like CutFeature)
	# can detect this thread via nearby_interactions.

	# If the Area2D interaction shape is missing (common since we usually just define the StaticBody),
	# we verify and create one matching the obstacle.
	if obstacle_collision and not has_node("CollisionShape2D"):
		# Check if we already have a child that IS a CollisionShape2D but with a different name
		var has_shape = false
		for child in get_children():
			if child is CollisionShape2D:
				has_shape = true
				break

		# If really no shape, create one
		if not has_shape:
			var interaction_shape = CollisionShape2D.new()
			interaction_shape.name = "InteractionShape"
			interaction_shape.shape = obstacle_collision.shape
			# Make the interaction area slightly larger than the collision obstacle
			# to ensure the player is detected even when "standing on" (colliding with) the obstacle.
			interaction_shape.scale = Vector2(1.1, 1.1)
			interaction_shape.debug_color = Color(0.8, 0.2, 0.8, 0.42)
			add_child(interaction_shape)



func _on_interaction_used(character: CharacterBody2D) -> void:
	# Not used for threads anymore
	pass

# === PUBLIC METHODS ===
func cut_thread() -> void:
	if not is_cuttable:
		return

	print("Cutting thread: ", name)
	is_cuttable = false
	is_active = false # Prevent further interaction
	cut.emit()

	# Visual feedback
	if cut_texture:
		sprite.texture = cut_texture
	else:
		# Fallback: make it semi-transparent
		sprite.modulate.a = 0.5

	# Disable physical collision
	if obstacle_collision:
		obstacle_collision.set_deferred("disabled", true)
	else:
		push_warning("ThreadInteraction: No collision shape found to disable!")

	# Hide prompt immediately
	if prompt_label:
		prompt_label.visible = false
