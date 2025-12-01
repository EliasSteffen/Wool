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
	# Activate by default so it can listen for input
	activate()

# === OVERRIDDEN METHODS ===
## Override is_active to always return enabled for this passive feature
func is_active() -> bool:
	return enabled

func handle_input(character: BaseCharacter) -> void:
	if not is_active():
		return

	if Input.is_action_just_pressed(cut_input_action):
		print("CutFeature: Input detected!")
		_try_cut(character)

# === PRIVATE METHODS ===
func _try_cut(character: BaseCharacter) -> void:
	print("CutFeature: Trying to cut...")
	# Check for nearby ThreadInteractions
	# We search for the closest thread within the interaction range (500px)
	# to match the prompt label visibility.

	var closest_thread: ThreadInteraction = null
	var closest_dist: float = 500.0 # Match prompt distance

	# Check all interactions in the group "interactions"
	# This is safer than relying on nearby_interactions which depends on Area2D size
	var interactions = character.get_tree().get_nodes_in_group("interactions")

	for node in interactions:
		if node is ThreadInteraction and node.is_active and node.is_cuttable:
			var dist = character.global_position.distance_to(node.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_thread = node

	if closest_thread:
		closest_thread.cut_thread()
		# Optional: Play cut animation/sound on character
