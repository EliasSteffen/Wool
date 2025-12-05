extends BaseConstants

const DEFAULT_MOVE_SPEED: float = 200.0

func _ready() -> void:
	settings = {
		"Player": {
			"move_speed": { "value": DEFAULT_MOVE_SPEED, "min": 50.0, "max": 1000.0, "step": 10.0 },
			"max_health": { "value": 100, "min": 1, "max": 500, "step": 1 },
			"jump_velocity": { "value": 400.0, "min": 100.0, "max": 1000.0, "step": 10.0 },
			"acceleration": { "value": 1500.0, "min": 100.0, "max": 5000.0, "step": 50.0 },
			"friction": { "value": 1200.0, "min": 100.0, "max": 5000.0, "step": 50.0 },
			"can_control": { "value": true, "type": "bool" },
			"camera_zoom": { "value": 1.0, "min": 0.1, "max": 10.0, "step": 0.1 }
		},
		"Enemy": {
			"attack_damage": { "value": 10, "min": 1, "max": 100, "step": 1 },
			"attack_range": { "value": 50.0, "min": 10.0, "max": 300.0, "step": 10.0 },
			"detection_range": { "value": 200.0, "min": 50.0, "max": 1000.0, "step": 50.0 },
			"patrol_speed": { "value": 100.0, "min": 10.0, "max": 500.0, "step": 10.0 },
			"chase_speed": { "value": 150.0, "min": 10.0, "max": 600.0, "step": 10.0 }
		}
	}
