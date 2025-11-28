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

# === OVERRIDDEN METHODS ===
func _setup_interaction() -> void:
	interaction_name = "Thread"
	prompt_action = "interact"
	prompt_text = "Cut"

	# Update prompt if label already exists (if _ready ran before this)
	if prompt_label:
		_update_prompt_text()

func _on_interaction_used(character: CharacterBody2D) -> void:
	if is_cuttable:
		cut_thread()

# === PUBLIC METHODS ===
func cut_thread() -> void:
	cut.emit()
	queue_free()
