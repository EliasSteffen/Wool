extends BaseConstants


const DEFAULT_HIGHLIGHT_COLOR: Color = Color(1.5, 1.5, 1.5, 1.0)
const DEFAULT_NORMAL_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)

func _ready() -> void:
	settings = {
		"Visuals": {
			"highlight_color": { "value": DEFAULT_HIGHLIGHT_COLOR, "type": "color" },
			"normal_color": { "value": DEFAULT_NORMAL_COLOR, "type": "color" }
		}
	}
