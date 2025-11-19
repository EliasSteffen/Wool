extends BaseConstants

func _ready() -> void:
	settings = {
		"Air": {
			"air_resistance": { "value": 0.98, "min": 0.9, "max": 1.0, "step": 0.001 },
			"applies_to_grappling": { "value": true, "type": "bool" }
		},
		"Water": {
			"slowdown_factor": { "value": 0.5, "min": 0.1, "max": 1.0, "step": 0.05 },
			"buoyancy_force": { "value": -100.0, "min": -500.0, "max": 0.0, "step": 10.0 },
			"water_resistance": { "value": 0.95, "min": 0.8, "max": 1.0, "step": 0.001 }
		}
	}
