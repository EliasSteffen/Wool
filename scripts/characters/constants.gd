extends BaseConstants

const DEFAULT_MOVE_SPEED: float = 400.0
const IDLE_ANIMATION_DELAY: float = 2.0

func _ready() -> void:
	settings = {
		"Player": {
			"move_speed": { "value": DEFAULT_MOVE_SPEED, "min": 50.0, "max": 1000.0, "step": 10.0, "description": "Basis-Laufgeschwindigkeit am Boden" },
			"jump_velocity": { "value": 1000.0, "min": 100.0, "max": 5000.0, "step": 10.0, "description": "Stärke des Sprungs" },
			"fall_gravity_multiplier": { "value": 1.5, "min": 1.0, "max": 5.0, "step": 0.1, "description": "Multiplikator für die Schwerkraft beim Fallen (schnelleres Fallen)" },
			"acceleration": { "value": 5000.0, "min": 1000.0, "max": 10000.0, "step": 50.0, "description": "Wie schnell Wool auf Höchstgeschwindigkeit kommt" },
			"friction": { "value": 2500.0, "min": 100.0, "max": 5000.0, "step": 50.0, "description": "Bremskraft am Boden" },
			"camera_zoom": { "value": 1.0, "min": 0.1, "max": 10.0, "step": 0.1, "description": "Zoom-Faktor der Kamera (kleiner ist näher)" }
		},
		"Enemy": {
		}
	}
