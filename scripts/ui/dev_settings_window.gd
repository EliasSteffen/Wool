extends CanvasLayer

@onready var container: VBoxContainer = $Panel/ScrollContainer/VBoxContainer
@onready var close_button: Button = $Panel/Header/CloseButton

func _ready() -> void:
	close_button.pressed.connect(close)

	# Make panel less transparent (more opaque)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95) # Dark grey, almost opaque
	$Panel.add_theme_stylebox_override("panel", style)

	_build_ui()

	# Configure ScrollContainer for mobile scrolling
	var scroll_container = $Panel/ScrollContainer
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	# Add Safe Area Padding for notches (Landscape)
	$Panel.set_begin(Vector2(200, 0)) # offset_left
	$Panel.set_end(Vector2(-200, 0)) # offset_right

func _build_ui() -> void:
	# Clear existing
	for child in container.get_children():
		child.queue_free()

	# Add Export Button
	var export_btn = Button.new()
	export_btn.text = "Export Settings as JSON"
	export_btn.custom_minimum_size.y = 100 # Larger mobile touch target
	export_btn.add_theme_font_size_override("font_size", 32)
	export_btn.pressed.connect(_on_export_pressed)
	container.add_child(export_btn)

	# Add separator
	container.add_child(HSeparator.new())

	# Build new from all registries
	for registry in Tweakables.registries:
		for category in registry.settings:
			_add_category_header(category)
			for key in registry.settings[category]:
				_add_setting_row(registry, category, key, registry.settings[category][key])

func _add_category_header(text: String) -> void:
	var label = Label.new()
	label.text = "--- " + text + " ---"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_font_size_override("font_size", 36)
	container.add_child(label)

func _add_setting_row(registry: BaseConstants, category: String, key: String, data: Dictionary) -> void:
	# Create a PanelContainer wrapper for each block
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(main_vbox)

	# TOP ROW: Name and Value Input
	var top_hbox = HBoxContainer.new()
	main_vbox.add_child(top_hbox)

	var label = Label.new()
	label.text = key
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	top_hbox.add_child(label)

	var value = data["value"]
	var type = data.get("type", "")

	# DESCRIPTION ROW (if any)
	if data.has("description"):
		var desc_label = Label.new()
		desc_label.text = data["description"]
		desc_label.add_theme_font_size_override("font_size", 18)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		main_vbox.add_child(desc_label)

	# SLIDER / INPUT ROW
	if type == "bool" or typeof(value) == TYPE_BOOL:
		var check = CheckBox.new()
		check.button_pressed = value
		check.custom_minimum_size = Vector2(80, 80)
		check.scale = Vector2(1.5, 1.5)
		check.toggled.connect(func(toggled):
			registry.set_value(category, key, toggled)
		)
		top_hbox.add_child(check)

	elif type == "color" or typeof(value) == TYPE_COLOR:
		var picker = ColorPickerButton.new()
		picker.color = value
		picker.custom_minimum_size = Vector2(120, 60)
		picker.color_changed.connect(func(col):
			registry.set_value(category, key, col)
		)
		top_hbox.add_child(picker)

	elif typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		var spinbox = SpinBox.new()
		spinbox.min_value = data.get("min", 0.0)
		spinbox.max_value = data.get("max", 1000.0)
		spinbox.step = data.get("step", 1.0)
		spinbox.value = value
		spinbox.custom_minimum_size = Vector2(180, 70)
		spinbox.get_line_edit().add_theme_font_size_override("font_size", 26)
		spinbox.get_line_edit().alignment = HORIZONTAL_ALIGNMENT_CENTER
		# top_hbox.add_child(spinbox) # REMOVED from top row

		# Slider with a "Scroll Lane" (spacer) and the numerical Value
		var slider_hbox = HBoxContainer.new()
		slider_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var slider = HSlider.new()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.y = 100 # Large touch area

		var slider_style = StyleBoxFlat.new()
		slider_style.bg_color = Color(0.25, 0.25, 0.25)
		slider_style.expand_margin_top = 12
		slider_style.expand_margin_bottom = 12
		slider_style.corner_radius_top_left = 12
		slider_style.corner_radius_top_right = 12
		slider_style.corner_radius_bottom_left = 12
		slider_style.corner_radius_bottom_right = 12

		var slider_active_style = slider_style.duplicate()
		slider_active_style.bg_color = Color(0.35, 0.55, 0.95) # Modern Blue

		slider.add_theme_stylebox_override("slider", slider_style)
		slider.add_theme_stylebox_override("grabber_area", slider_active_style)
		slider.add_theme_stylebox_override("grabber_area_highlight", slider_active_style)

		slider.min_value = data.get("min", 0.0)
		slider.max_value = data.get("max", 1000.0)
		slider.step = data.get("step", 1.0)
		slider.value = value

		# Sync
		slider.value_changed.connect(func(new_val):
			spinbox.value = new_val
			registry.set_value(category, key, new_val)
		)
		spinbox.value_changed.connect(func(new_val):
			slider.value = new_val
			registry.set_value(category, key, new_val)
		)

		slider_hbox.add_child(slider)

		# The Scroll Lane: 400px spacer for safe swiping
		var scroll_lane = Control.new()
		scroll_lane.custom_minimum_size.x = 400
		slider_hbox.add_child(scroll_lane)

		# Move the numerical value here, after the spacer
		slider_hbox.add_child(spinbox)

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
