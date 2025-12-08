extends BaseConstants

const DEFAULT_AIR_RESISTANCE: float = 0.98
const DEFAULT_APPLIES_TO_GRAPPLING: bool = true
const DEFAULT_WATER_SLOWDOWN_FACTOR: float = 0.5
const DEFAULT_WATER_BUOYANCY_FORCE: float = -100.0
const DEFAULT_WATER_RESISTANCE: float = 0.5
const DEFAULT_UPWIND_FORCE: float = -2000.0

func _ready() -> void:
	settings = {
		"Air": {
			"air_resistance": { "value": DEFAULT_AIR_RESISTANCE, "min": 0.9, "max": 1.0, "step": 0.001 },
			"applies_to_grappling": { "value": DEFAULT_APPLIES_TO_GRAPPLING, "type": "bool" }
		},
		"Water": {
			"slowdown_factor": { "value": DEFAULT_WATER_SLOWDOWN_FACTOR, "min": 0.1, "max": 1.0, "step": 0.05 },
			"buoyancy_force": { "value": DEFAULT_WATER_BUOYANCY_FORCE, "min": -100.0, "max": 0.0, "step": 10.0 },
			"water_resistance": { "value": DEFAULT_WATER_RESISTANCE, "min": 0.1, "max": 1.0, "step": 0.001 }
		},
		"Upwind": {
			"upwind_force": { "value": DEFAULT_UPWIND_FORCE, "min": -5000.0, "max": -100.0, "step": 100.0 }
		}
	}
