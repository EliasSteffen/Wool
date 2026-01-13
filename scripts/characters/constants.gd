extends BaseConstants

const DEFAULT_MOVE_SPEED: float = 400.0
const IDLE_ANIMATION_DELAY: float = 2.0

func _ready() -> void:
	settings = {
		"Player": {
			"move_speed": { "value": DEFAULT_MOVE_SPEED, "min": 50.0, "max": 1000.0, "step": 10.0 },
			"max_health": { "value": 100, "min": 1, "max": 500, "step": 1 },
			"jump_velocity": { "value": 600.0, "min": 100.0, "max": 5000.0, "step": 10.0 },
			"acceleration": { "value": 5000.0, "min": 1000.0, "max": 10000.0, "step": 50.0 },
			"friction": { "value": 2500.0, "min": 100.0, "max": 5000.0, "step": 50.0 },
			"can_control": { "value": true, "type": "bool" },
			"camera_zoom": { "value": 1.0, "min": 0.1, "max": 10.0, "step": 0.1 }
		}
	}
