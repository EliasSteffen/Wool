extends CanvasLayer

@onready var container: VBoxContainer = $Panel/ScrollContainer/VBoxContainer
@onready var close_button: Button = $Panel/CloseButton

func _ready() -> void:
	close_button.pressed.connect(close)

	# Configure ScrollContainer for mobile scrolling
	var scroll_container = $Panel/ScrollContainer
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	# Find and setup sliders if they exist in the scene
	var master_slider = container.get_node_or_null("MasterVolume/HBoxContainer/HSlider")
	if master_slider: _setup_slider(master_slider, "Master")

	var music_slider = container.get_node_or_null("MusicVolume/HBoxContainer/HSlider")
	if music_slider: _setup_slider(music_slider, "Music")

	var sfx_slider = container.get_node_or_null("SFXVolume/HBoxContainer/HSlider")
	if sfx_slider: _setup_slider(sfx_slider, "SFX")

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
