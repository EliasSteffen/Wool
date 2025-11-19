extends BaseConstants

func _ready() -> void:
	settings = {
		"Physics": {
			"gravity": { "value": 980.0, "min": 0.0, "max": 2000.0, "step": 10.0 }
		}
	}
