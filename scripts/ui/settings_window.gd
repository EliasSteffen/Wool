extends CanvasLayer

@onready var container: VBoxContainer = $Panel/ScrollContainer/VBoxContainer

func _ready() -> void:
	$Panel/MenuBackground/CloseButton.pressed.connect(close)

	# Configure ScrollContainer for mobile scrolling
	var scroll_container = $Panel/ScrollContainer
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	# Find and setup sliders if they exist in the scene
	var master_slider = container.get_node_or_null("MasterVolume/VBoxContainer/HBoxContainer/HSlider")
	if master_slider: _setup_slider(master_slider, "Master")

	var music_slider = container.get_node_or_null("MusicVolume/VBoxContainer/HBoxContainer/HSlider")
	if music_slider: _setup_slider(music_slider, "Music")

	var sfx_slider = container.get_node_or_null("SFXVolume/VBoxContainer/HBoxContainer/HSlider")
	if sfx_slider: _setup_slider(sfx_slider, "SFX")

	var reset_btn = container.get_node_or_null("ResetHighscoreButton")
	if reset_btn:
		reset_btn.pressed.connect(_on_reset_highscore_pressed)

func _on_reset_highscore_pressed() -> void:
	AudioManager.play_sound(AudioManager.GAME.CLICK)
	GameManager.reset_highscore()
	# Optional: feedback? For now just reset.

func _setup_slider(slider: HSlider, bus_name: String) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01

	# Initialize value from current db
	if bus_idx != -1:
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))

	slider.value_changed.connect(func(val):
		var b_idx = AudioServer.get_bus_index(bus_name)
		if b_idx != -1:
			AudioServer.set_bus_volume_db(b_idx, linear_to_db(val))
	)

func open() -> void:
	show()
	get_tree().paused = true

func close() -> void:
	hide()
	# Unpause if we are not in the PAUSED state (i.e. unpause for MENU and PLAYING)
	if GameManager.current_state != GameManager.GameState.PAUSED:
		get_tree().paused = false
