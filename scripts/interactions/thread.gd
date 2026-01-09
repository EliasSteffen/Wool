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
	# Disable interaction monitoring as we rely purely on physical collision / manual cutting
	monitoring = false
	monitorable = false

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
