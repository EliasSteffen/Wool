extends BaseConstants

const DEFAULT_BOX_WEIGHT: float = 50.0
const DEFAULT_BOX_FRICTION: float = 1.0
const DEFAULT_HIGHLIGHT_COLOR: Color = Color(1.5, 1.5, 1.5, 1.0)
const DEFAULT_NORMAL_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)

func _ready() -> void:
	settings = {
		"Box": {
			"weight": { "value": DEFAULT_BOX_WEIGHT, "min": 1.0, "max": 500.0, "step": 1.0 },
			"friction": { "value": DEFAULT_BOX_FRICTION, "min": 0.0, "max": 5.0, "step": 0.1 }
		},
		"Visuals": {
			"highlight_color": { "value": DEFAULT_HIGHLIGHT_COLOR, "type": "color" },
			"normal_color": { "value": DEFAULT_NORMAL_COLOR, "type": "color" }
		}
	}
