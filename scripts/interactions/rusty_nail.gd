## RustyNail - Special Nail that falls after prolonged swinging
##
## Extends Nail with falling behavior after 5 seconds of swinging.
class_name RustyNail
extends Nail

# === EXPORTED VARIABLES ===
@export var fall_speed: float = 200.0
@export var swing_fall_threshold: float

# === PRIVATE VARIABLES ===
var _swing_timer: float = 0.0
var _is_falling: bool = false

# === CONSTANTS ===
const RUSTY_BASE_THRESHOLD: float = 5.0
const RUSTY_THRESHOLD_DECREASE_INTERVAL: float = 256.0
# Negative percent shortens the threshold per step (e.g. -0.05 = 5% shorter each step)
const RUSTY_THRESHOLD_DECREASE_PERCENT: float = -0.05

# === OVERRIDDEN METHODS ===

func _setup_interaction() -> void:
	super._setup_interaction()
	# Override for rusty nails
	normal_color = InteractionConstants.get_value("Visuals", "rusty_nail_color", InteractionConstants.DEFAULT_RUSTY_NAIL_COLOR)
	highlight_color = InteractionConstants.get_value("Visuals", "highlight_nail_color", InteractionConstants.DEFAULT_HIGHLIGHT_COLOR)

	# Compute threshold now and again deferred after spawn positions the nail
	_compute_swing_threshold()
	call_deferred("_compute_swing_threshold")

	_update_visual()

func _compute_swing_threshold() -> void:
	var steps: int = ScaleUtils.steps_from_position(global_position.x, RUSTY_THRESHOLD_DECREASE_INTERVAL)
	var raw_threshold: float = ScaleUtils.scaled_value(RUSTY_BASE_THRESHOLD, RUSTY_THRESHOLD_DECREASE_PERCENT, steps)
	swing_fall_threshold = max(raw_threshold, 2.0)

func _physics_process(delta: float) -> void:
	if _is_being_used and not _is_falling:
		var prev_timer = _swing_timer
		_swing_timer += delta
		if prev_timer == 0.0:
			GameManager.rusty_nail_timer_started.emit(swing_fall_threshold)
		if _swing_timer >= swing_fall_threshold:
			_is_falling = true
			set_used(false)  # Stop grappling when the nail starts falling
			GameManager.rusty_nail_timer_stopped.emit()
			# Haptic feedback when nail falls (Mobile only)
			Input.vibrate_handheld(200)
			# Optional: Play sound or effect here
		else:
			GameManager.rusty_nail_timer_updated.emit(_swing_timer / swing_fall_threshold)
	elif not _is_being_used:
		if _swing_timer > 0.0:
			_swing_timer = 0.0  # Reset timer if not being used
			GameManager.rusty_nail_timer_stopped.emit()

	if _is_falling:
		global_position.y += fall_speed * delta
## Reset the nail (called when reused or reset)
func reset() -> void:
	_swing_timer = 0.0
	_is_falling = false
	# Reset position if needed
