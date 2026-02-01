extends CanvasLayer

@onready var container: VBoxContainer = $Panel/ScrollContainer/VBoxContainer
@onready var close_button: Button = $Panel/Header/CloseButton

func _ready() -> void:
	close_button.pressed.connect(close)

	# Make panel less transparent (more opaque)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25, 0.95) # Modern blue-grey
	style.border_color = Color(0.3, 0.3, 0.4, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	$Panel.add_theme_stylebox_override("panel", style)

	# Apply modern rounded style to the close button (icon-like)
	var UITheme = preload("res://scripts/ui/ui_theme.gd")
	UITheme.apply_modern_button_style(close_button, Vector2(100, 100), true)
	# Make close button background transparent (icon-only)
	var flat_style := StyleBoxFlat.new()
	flat_style.bg_color = Color(0,0,0,0)
	flat_style.corner_radius_top_left = 0
	flat_style.corner_radius_top_right = 0
	flat_style.corner_radius_bottom_left = 0
	flat_style.corner_radius_bottom_right = 0
	close_button.add_theme_stylebox_override("normal", flat_style)
	close_button.add_theme_stylebox_override("hover", flat_style)
	close_button.add_theme_stylebox_override("pressed", flat_style)
	# Use asset icon for close (icon-only)
	close_button.text = ""
	var close_icon: Texture2D = preload("res://assets/ui/close-button.png")
	var close_icon_rect: TextureRect = close_button.get_node_or_null("IconTex") as TextureRect
	if not close_icon_rect:
		close_icon_rect = TextureRect.new()
		close_icon_rect.name = "IconTex"
		close_button.add_child(close_icon_rect)
		close_icon_rect.anchor_left = 0.0
		close_icon_rect.anchor_top = 0.0
		close_icon_rect.anchor_right = 1.0
		close_icon_rect.anchor_bottom = 1.0
		close_icon_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		close_icon_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		close_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	close_icon_rect.texture = close_icon

	# Enhance header visuals (rounded, slight accent)
	var header = $Panel.get_node_or_null("Header")
	if header:
		var header_style = StyleBoxFlat.new()
		header_style.bg_color = Color(0.15, 0.15, 0.2, 0.95) # Slightly lighter blue-grey
		header_style.border_color = Color(0.25, 0.25, 0.35, 1.0)
		header_style.border_width_bottom = 1
		header_style.corner_radius_top_left = 16
		header_style.corner_radius_top_right = 16
		header_style.content_margin_left = 16
		header_style.content_margin_right = 16
		header_style.content_margin_top = 12
		header_style.content_margin_bottom = 12
		header.add_theme_stylebox_override("panel", header_style)
		for child in header.get_children():
			if child is Label:
				child.add_theme_font_size_override("font_size", 40)
				child.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))

	_build_ui()

	# Configure ScrollContainer for mobile scrolling
	var scroll_container = $Panel/ScrollContainer
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	# Add Safe Area Padding for notches (Landscape)
	$Panel.set_begin(Vector2(200, 75)) # offset_left and offset_top
	$Panel.set_end(Vector2(-200, -75)) # offset_right and offset_bottom

func _build_ui() -> void:
	# Clear existing
	for child in container.get_children():
		child.queue_free()

	# 1. Master Volume
	_add_volume_slider("Master Volume", "Master")

	# 2. Music Volume
	_add_volume_slider("Music Volume", "Music")

	# 3. SFX Volume
	_add_volume_slider("SFX Volume", "SFX")

func _add_volume_slider(label_text: String, bus_name: String) -> void:
	# Create a PanelContainer wrapper for each block
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.25, 0.3, 0.9) # Lighter blue-grey for contrast
	style.border_color = Color(0.35, 0.35, 0.45, 1.0)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	panel.add_theme_stylebox_override("panel", style)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	panel.add_child(main_vbox)

	# Label
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	main_vbox.add_child(label)

	# Slider Row
	var slider_hbox = HBoxContainer.new()
	slider_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var slider = HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 100 # Larger touch area

	# Styles
	var slider_style = StyleBoxFlat.new()
	slider_style.bg_color = Color(0.2, 0.2, 0.2)
	slider_style.expand_margin_top = 20
	slider_style.expand_margin_bottom = 20
	slider_style.corner_radius_top_left = 20
	slider_style.corner_radius_top_right = 20
	slider_style.corner_radius_bottom_left = 20
	slider_style.corner_radius_bottom_right = 20

	var slider_active_style = slider_style.duplicate()
	slider_active_style.bg_color = Color(0.4, 0.6, 1.0) # Modern Blue
	slider_active_style.expand_margin_left = 10
	slider_active_style.expand_margin_right = 10

	slider.add_theme_stylebox_override("slider", slider_style)
	slider.add_theme_stylebox_override("grabber_area", slider_active_style)
	slider.add_theme_stylebox_override("grabber_area_highlight", slider_active_style)

	# Audio Logic
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

	slider_hbox.add_child(slider)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.x = 20
	slider_hbox.add_child(spacer)

	main_vbox.add_child(slider_hbox)
	container.add_child(panel)

func open() -> void:
	show()
	get_tree().paused = true

func close() -> void:
	hide()
	# Unpause if we are not in the PAUSED state (i.e. unpause for MENU and PLAYING)
	if GameManager.current_state != GameManager.GameState.PAUSED:
		get_tree().paused = false

func _on_export_pressed() -> void:
	var export_data: Dictionary = {}

	for registry in Tweakables.registries:
		# Merge settings from all registries
		# We assume categories are unique across registries
		for category in registry.settings:
			export_data[category] = registry.settings[category]

	var json_string = JSON.stringify(export_data, "\t")

	if OS.has_feature("web"):
		# Web export: Trigger download via JavaScript
		var buffer = json_string.to_utf8_buffer()
		JavaScriptBridge.download_buffer(buffer, "tweakables_export.json", "application/json")

		# Visual feedback
		var original_text = "Export Settings as JSON"
		var btn = container.get_child(0) as Button
		if btn:
			btn.text = "Downloaded!"
			await get_tree().create_timer(1.0).timeout
			btn.text = original_text
	else:
		# Desktop/Editor: Save to file
		var file_path = "res://tweakables_export.json"
		var file = FileAccess.open(file_path, FileAccess.WRITE)

		if file:
			file.store_string(json_string)
			file.close()

			# Visual feedback
			var original_text = "Export Settings as JSON"
			var btn = container.get_child(0) as Button
			if btn:
				btn.text = "Saved!"
				await get_tree().create_timer(1.0).timeout
				btn.text = original_text
		else:
			push_error("Failed to save settings to " + file_path)
