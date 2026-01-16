extends BaseConstants



func _ready() -> void:
	settings = {
		"Grappling": {
			"swing_pump_force": { "value": 1000.0, "min": 0.0, "max": 2000.0, "step": 50.0 },
			"max_boost_force": { "value": 1500.0, "min": 0.0, "max": 2000.0, "step": 50.0 },
			"fixed_rope_length": { "value": 100.0, "min": 10.0, "max": 1000.0, "step": 10.0 }
		}
	}
