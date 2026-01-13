extends BaseConstants



func _ready() -> void:
	settings = {
		"Grappling": {
			"max_boost_force": { "value": 1000.0, "min": 0.0, "max": 2000.0, "step": 50.0 },
			"max_swing_speed": { "value": 800.0, "min": 100.0, "max": 2000.0, "step": 50.0 },
			"tension_strength": { "value": 2000.0, "min": 100.0, "max": 5000.0, "step": 100.0 },
			"swing_pump_force": { "value": 400.0, "min": 0.0, "max": 2000.0, "step": 50.0 },
			"damping": { "value": 0.995, "min": 0.9, "max": 1.0, "step": 0.001 },
			"initial_pull_strength": { "value": 1500.0, "min": 100.0, "max": 5000.0, "step": 100.0 },
			"max_rope_length": { "value": 300.0, "min": 10.0, "max": 1000.0, "step": 10.0 }
		}
	}
