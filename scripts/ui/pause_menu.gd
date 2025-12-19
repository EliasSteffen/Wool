extends BaseMenu

@onready var resume_button: Button = $Control/CenterContainer/VBoxContainer/ResumeButton
@onready var dev_settings_button: Button = $Control/CenterContainer/VBoxContainer/DevSettingsButton
@onready var menu_button: Button = $Control/CenterContainer/VBoxContainer/MenuButton
@onready var quit_button: Button = $Control/CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	super._ready()
	resume_button.pressed.connect(_on_resume_pressed)
	dev_settings_button.pressed.connect(_on_dev_settings_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	register_buttons([resume_button, dev_settings_button, menu_button, quit_button])

func _on_resume_pressed() -> void:
	GameManager.toggle_pause()

func _on_menu_pressed() -> void:
	GameManager.return_to_menu()

func _on_quit_pressed() -> void:
	GameManager.quit_game()
