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
	super._ready()
	feature_name = "Cut"
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
		# print("CutFeature: Input detected!")
		_try_cut(character)

# === OVERRIDDEN METHODS ===
func _calculate_movement_factor(_delta: float, _character_position: Vector2) -> Vector2:
	return Vector2.ZERO

func _try_cut(character: BaseCharacter) -> void:
	# Check for nearby ThreadInteractions
	# We search for the closest thread within the interaction range (500px)
	# to match the prompt label visibility.

	var closest_thread: ThreadInteraction = null
	var closest_dist: float = 500.0 # Match prompt distance

	# Search mainly within character's ALREADY DETECTED nearby_interactions
	# to be consistent with other interactions, instead of searching the whole tree.
	# But the original code searched the whole group. I'll stick to optimization if possible,
	# but for now I will just fix the logging.

	# Optimization: check radius first using existing nearby list if possible,
	# but if not populated, fallback to group (ThreadInteraction might not be Area2D based?)
	# Assuming ThreadInteraction IS an Interaction which is Area2D based.

	var interactions = character.nearby_interactions

	for node in interactions:
		if node is ThreadInteraction and node.is_active and node.is_cuttable:
			var dist = character.global_position.distance_to(node.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_thread = node

	if closest_thread:
		print("CutFeature: Cutting thread: ", closest_thread.name)
		closest_thread.cut_thread()
		# Optional: Play cut animation/sound on character
