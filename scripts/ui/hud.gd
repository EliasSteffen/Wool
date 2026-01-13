extends CanvasLayer

@onready var pause_button: Button = $PauseButton

func _ready() -> void:
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)

func _on_pause_pressed() -> void:
	GameManager.toggle_pause()
