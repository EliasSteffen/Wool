extends BaseConstants

const DEFAULT_MOVE_SPEED: float = 400.0
const IDLE_ANIMATION_DELAY: float = 2.0

func _ready() -> void:
	settings = {
		"Player": {
			"move_speed": { "value": DEFAULT_MOVE_SPEED, "min": 50.0, "max": 1000.0, "step": 10.0 },
			"jump_velocity": { "value": 600.0, "min": 100.0, "max": 5000.0, "step": 10.0 },
			"acceleration": { "value": 5000.0, "min": 1000.0, "max": 10000.0, "step": 50.0 },
			"friction": { "value": 2500.0, "min": 100.0, "max": 5000.0, "step": 50.0 },
			"camera_zoom": { "value": 1.0, "min": 0.1, "max": 10.0, "step": 0.1 }
		}
	}
