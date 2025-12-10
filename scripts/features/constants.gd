extends BaseConstants

const WINGS_JUMP_BOOST_MULTIPLIER: float = 1.5
const WINGS_FALL_SPEED_MULTIPLIER: float = 0.6
const WINGS_GLIDE_THRESHOLD: float = 50.0

func _ready() -> void:
	settings = {
		"Grappling": {
			"max_boost_force": { "value": 1000.0, "min": 0.0, "max": 2000.0, "step": 50.0 },
			"max_swing_speed": { "value": 800.0, "min": 100.0, "max": 2000.0, "step": 50.0 },
			"tension_strength": { "value": 2000.0, "min": 100.0, "max": 5000.0, "step": 100.0 },
			"swing_pump_force": { "value": 400.0, "min": 0.0, "max": 2000.0, "step": 50.0 },
			"damping": { "value": 0.995, "min": 0.9, "max": 1.0, "step": 0.001 },
			"initial_pull_strength": { "value": 1500.0, "min": 100.0, "max": 5000.0, "step": 100.0 }
		},
		"Glide": {
			"glide_fall_multiplier": { "value": 0.3, "min": 0.05, "max": 1.0, "step": 0.05 }
		},
		"DoubleJump": {
			"max_air_jumps": { "value": 1, "min": 0, "max": 5, "step": 1 },
			"air_jump_power_multiplier": { "value": 0.9, "min": 0.1, "max": 2.0, "step": 0.1 }
		},
		"Push": {
			"push_slowdown_factor": { "value": 0.5, "min": 0.1, "max": 1.0, "step": 0.1 },
			"push_force_multiplier": { "value": 1.0, "min": 0.1, "max": 5.0, "step": 0.1 }
		},
		"Wings": {
			"jump_boost_multiplier": { "value": WINGS_JUMP_BOOST_MULTIPLIER, "min": 1.0, "max": 3.0, "step": 0.1 },
			"fall_speed_multiplier": { "value": WINGS_FALL_SPEED_MULTIPLIER, "min": 0.1, "max": 1.0, "step": 0.05 },
			"glide_threshold": { "value": WINGS_GLIDE_THRESHOLD, "min": 0.0, "max": 200.0, "step": 10.0 }
		},
		"Swim": {
			"swim_speed_multiplier": { "value": 1.5, "min": 1.0, "max": 3.0, "step": 0.1 }
		}
	}
