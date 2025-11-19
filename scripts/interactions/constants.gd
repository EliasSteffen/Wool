extends BaseConstants

func _ready() -> void:
	settings = {
		"Box": {
			"weight": { "value": 50.0, "min": 1.0, "max": 500.0, "step": 1.0 },
			"friction": { "value": 1.0, "min": 0.0, "max": 5.0, "step": 0.1 }
		},
		"Visuals": {
			"highlight_color": { "value": Color(1, 1, 0, 1), "type": "color" },
			"interaction_range_color": { "value": Color(0, 1, 0, 0.2), "type": "color" }
		}
	}
