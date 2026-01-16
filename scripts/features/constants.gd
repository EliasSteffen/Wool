extends BaseConstants



func _ready() -> void:
	settings = {
		"Grappling": {
			"swing_pump_force": { "value": 1000.0, "min": 0.0, "max": 2000.0, "step": 50.0, "description": "Kraft beim aktiven Schwingen (Knopf halten)" },
			"max_boost_force": { "value": 1500.0, "min": 0.0, "max": 2000.0, "step": 50.0, "description": "Zusätzlicher Schwung beim Loslassen des Seils" },
			"fixed_rope_length": { "value": 100.0, "min": 10.0, "max": 1000.0, "step": 10.0, "description": "Feste Länge des Greifarm-Seils" }
		}
	}
