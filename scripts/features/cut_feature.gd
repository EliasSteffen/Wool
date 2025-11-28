## CutFeature - Allows cutting threads
##
## This feature allows the character to cut ThreadInteractions.
## Triggered by the 'interact' action (default: F).
class_name CutFeature
extends Feature

# === EXPORTED VARIABLES ===
@export var cut_input_action: String = "interact"

# === BUILT-IN METHODS ===
func _ready() -> void:
	feature_name = "Cut"
	enabled = true

# === OVERRIDDEN METHODS ===
func handle_input(character: BaseCharacter) -> void:
	if not is_active():
		return

	if Input.is_action_just_pressed(cut_input_action):
		_try_cut(character)

# === PRIVATE METHODS ===
func _try_cut(character: BaseCharacter) -> void:
	# Check for nearby ThreadInteractions
	for interaction in character.nearby_interactions:
		if interaction is ThreadInteraction:
			interaction.cut_thread()
			# Optional: Play cut animation/sound on character
			return # Cut one at a time
