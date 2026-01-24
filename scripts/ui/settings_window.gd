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

	# Add Export Button
	var export_btn = Button.new()
	export_btn.text = "Export Settings as JSON"
	export_btn.custom_minimum_size.y = 120 # Larger mobile touch target
	export_btn.add_theme_font_size_override("font_size", 48)
	export_btn.pressed.connect(_on_export_pressed)
	# Apply modern rounded style
	var UITheme = preload("res://scripts/ui/ui_theme.gd")
	UITheme.apply_modern_button_style(export_btn, Vector2(0, 100), false)
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
	label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0)) # Modern blue
	label.add_theme_font_size_override("font_size", 48)
	container.add_child(label)

func _add_setting_row(registry: BaseConstants, category: String, key: String, data: Dictionary) -> void:
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

	# TOP ROW: Name and Value Input
	var top_hbox = HBoxContainer.new()
	main_vbox.add_child(top_hbox)

	var label = Label.new()
	label.text = key
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	top_hbox.add_child(label)

	var value = data["value"]
	var type = data.get("type", "")

	# DESCRIPTION ROW (if any)
	if data.has("description"):
		var desc_label = Label.new()
		desc_label.text = data["description"]
		desc_label.add_theme_font_size_override("font_size", 24)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		main_vbox.add_child(desc_label)

	# SLIDER / INPUT ROW
	if type == "bool" or typeof(value) == TYPE_BOOL:
		var check = CheckBox.new()
		check.button_pressed = value
		check.custom_minimum_size = Vector2(100, 100)
		check.scale = Vector2(2.0, 2.0)
		check.toggled.connect(func(toggled):
			registry.set_value(category, key, toggled)
		)
		top_hbox.add_child(check)

	elif type == "color" or typeof(value) == TYPE_COLOR:
		var picker = ColorPickerButton.new()
		picker.color = value
		picker.custom_minimum_size = Vector2(150, 80)
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
		spinbox.custom_minimum_size = Vector2(220, 90)
		spinbox.get_line_edit().add_theme_font_size_override("font_size", 32)
		spinbox.get_line_edit().alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Hide the up/down buttons
		var empty_style = StyleBoxEmpty.new()
		spinbox.add_theme_stylebox_override("up", empty_style)
		spinbox.add_theme_stylebox_override("down", empty_style)
		# top_hbox.add_child(spinbox) # REMOVED from top row

		# Slider with a "Scroll Lane" (spacer) and the numerical Value
		var slider_hbox = HBoxContainer.new()
		slider_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var slider = HSlider.new()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.y = 150 # Larger touch area

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

		slider.min_value = data.get("min", 0.0)
		slider.max_value = data.get("max", 1000.0)
		slider.step = data.get("step", 1.0)
		slider.value = value

		# Sync
		slider.value_changed.connect(func(new_val):
			registry.set_value(category, key, new_val)
		)

		slider_hbox.add_child(slider)

		# The Scroll Lane: 400px spacer for safe swiping
		var scroll_lane = Control.new()
		scroll_lane.custom_minimum_size.x = 400
		slider_hbox.add_child(scroll_lane)

		# Move the numerical value here, after the spacer
		# slider_hbox.add_child(spinbox)  # Removed as per user request

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
