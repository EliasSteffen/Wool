extends CanvasLayer

@onready var resume_button: Button = $Control/CenterContainer/VBoxContainer/ResumeButton
@onready var dev_settings_button: Button = $Control/CenterContainer/VBoxContainer/DevSettingsButton
@onready var menu_button: Button = $Control/CenterContainer/VBoxContainer/MenuButton
@onready var quit_button: Button = $Control/CenterContainer/VBoxContainer/QuitButton

const DEV_SETTINGS_SCENE = preload("res://scenes/ui/dev_settings_window.tscn")
var _dev_settings_instance: Node = null

func _ready() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	dev_settings_button.pressed.connect(_on_dev_settings_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_resume_pressed() -> void:
	GameManager.toggle_pause()

func _on_dev_settings_pressed() -> void:
	if not _dev_settings_instance:
		_dev_settings_instance = DEV_SETTINGS_SCENE.instantiate()
		get_tree().root.add_child(_dev_settings_instance)

	if _dev_settings_instance.has_method("open"):
		_dev_settings_instance.open()

func _on_menu_pressed() -> void:
	GameManager.return_to_menu()

func _on_quit_pressed() -> void:
	GameManager.quit_game()
