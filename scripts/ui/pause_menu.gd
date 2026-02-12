extends BaseMenu

@onready var settings_button: Button = $Control/MenuPanel/VBoxContainer/SettingsButton
@onready var credits_button: Button = $Control/MenuPanel/VBoxContainer/CreditsButton

func _ready() -> void:
	super._ready()
	$Control/MenuPanel/MenuBackground/CloseButton.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

	# Buttons will use the textured theme from assets/ui/pause_theme.tres

	settings_button.text = "Settings"

	register_buttons([settings_button, credits_button], false, false)

	setup_credits_button()

func setup_credits_button() -> void:
	credits_button.pressed.connect(_on_credits_pressed)

	credits_button.text = "Credits"

func _on_credits_pressed() -> void:
	var credits_scene = preload("res://scenes/ui/credits.tscn").instantiate()
	add_child(credits_scene)


func _on_resume_pressed() -> void:
	GameManager.toggle_pause()
