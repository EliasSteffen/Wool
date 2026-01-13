extends BaseMenu

@onready var resume_button: Button = $Control/CenterContainer/VBoxContainer/ResumeButton
@onready var dev_settings_button: Button = $Control/CenterContainer/VBoxContainer/DevSettingsButton

func _ready() -> void:
	super._ready()
	resume_button.pressed.connect(_on_resume_pressed)
	dev_settings_button.pressed.connect(_on_dev_settings_pressed)

	register_buttons([resume_button, dev_settings_button])

func _on_resume_pressed() -> void:
	GameManager.toggle_pause()
