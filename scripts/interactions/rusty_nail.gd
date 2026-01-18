## RustyNail - Special Nail that falls after prolonged swinging
##
## Extends Nail with falling behavior after 5 seconds of swinging.
class_name RustyNail
extends Nail

# === EXPORTED VARIABLES ===
@export var fall_speed: float = 200.0
@export var swing_fall_threshold: float = 5.0

# === PRIVATE VARIABLES ===
var _swing_timer: float = 0.0
var _is_falling: bool = false

# === OVERRIDDEN METHODS ===

func _setup_interaction() -> void:
	super._setup_interaction()
	# Override for rusty nails
	normal_color = InteractionConstants.get_value("Visuals", "rusty_nail_color", InteractionConstants.DEFAULT_RUSTY_NAIL_COLOR)
	highlight_color = InteractionConstants.get_value("Visuals", "highlight_nail_color", InteractionConstants.DEFAULT_HIGHLIGHT_COLOR)

	# Scale swing_fall_threshold based on distance, like nail distances
	var base_threshold: float = 3.0
	var threshold_decrease_interval: float = 512.0
	var threshold_decrease_percent: float = 0.25
	var steps: int = int(max(0.0, floor(global_position.x / threshold_decrease_interval)))
	swing_fall_threshold = base_threshold * pow(1.0 - threshold_decrease_percent, steps)
	swing_fall_threshold = max(swing_fall_threshold, 1.0)  # Minimum 1 second

	_update_visual()

func _physics_process(delta: float) -> void:
	if _is_being_used and not _is_falling:
		_swing_timer += delta
		if _swing_timer >= swing_fall_threshold:
			_is_falling = true
			set_used(false)  # Stop grappling when the nail starts falling
			# Optional: Play sound or effect here
	elif not _is_being_used:
		_swing_timer = 0.0  # Reset timer if not being used

	if _is_falling:
		global_position.y += fall_speed * delta
## Reset the nail (called when reused or reset)
func reset() -> void:
	_swing_timer = 0.0
	_is_falling = false
	# Reset position if needed
