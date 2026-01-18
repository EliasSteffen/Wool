extends CanvasLayer

@onready var pause_button: Button = $PauseButton

func _ready() -> void:
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)
		# Style pause button as circular icon
		var UITheme = preload("res://scripts/ui/ui_theme.gd")
		UITheme.apply_modern_button_style(pause_button, Vector2(64, 64), true)

func _on_pause_pressed() -> void:
	GameManager.toggle_pause()
