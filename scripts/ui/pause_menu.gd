extends CanvasLayer

@onready var resume_button: Button = $Control/CenterContainer/VBoxContainer/ResumeButton
@onready var menu_button: Button = $Control/CenterContainer/VBoxContainer/MenuButton
@onready var quit_button: Button = $Control/CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_resume_pressed() -> void:
	GameManager.toggle_pause()

func _on_menu_pressed() -> void:
	GameManager.return_to_menu()

func _on_quit_pressed() -> void:
	GameManager.quit_game()
