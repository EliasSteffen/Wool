extends CanvasLayer

@onready var pause_button: Button = $PauseButton
@onready var current_distance_label: Label = $CurrentDistance
@onready var rusty_nail_timer: Control = $RustyNailTimer
@onready var rusty_nail_timer_bg: Panel = $RustyNailTimer/Background
@onready var rusty_nail_timer_fill: Panel = $RustyNailTimer/Fill
@onready var off_screen_indicator: TextureRect = $OffScreenIndicator

var player: BasePlayer = null


func _ready() -> void:
	GameManager.rusty_nail_timer_started.connect(_on_rusty_nail_timer_started)
	GameManager.rusty_nail_timer_updated.connect(_on_rusty_nail_timer_updated)
	GameManager.rusty_nail_timer_stopped.connect(_on_rusty_nail_timer_stopped)
	GameManager.state_changed.connect(_on_game_state_changed)

	rusty_nail_timer.visible = false
	# Ensure initial fill matches (full)
	rusty_nail_timer_fill.offset_left = rusty_nail_timer.offset_left
	rusty_nail_timer_fill.offset_right = rusty_nail_timer.offset_right
	# Make button background transparent (icon only)
	var flat_style := StyleBoxFlat.new()
	flat_style.bg_color = Color(0,0,0,0)
	flat_style.corner_radius_top_left = 0
	flat_style.corner_radius_top_right = 0
	flat_style.corner_radius_bottom_left = 0
	flat_style.corner_radius_bottom_right = 0
	pause_button.add_theme_stylebox_override("normal", flat_style)
	pause_button.add_theme_stylebox_override("hover", flat_style)
	pause_button.add_theme_stylebox_override("pressed", flat_style)

	# Configure RustyNailTimer rounded visuals
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.5)
	bg_style.set_corner_radius_all(20) # Half of 40px height
	rusty_nail_timer_bg.add_theme_stylebox_override("panel", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(1, 1, 1, 0.95)
	fill_style.set_corner_radius_all(20)
	rusty_nail_timer_fill.add_theme_stylebox_override("panel", fill_style)

	# Clear default text and use a centered TextureRect so the icon fills the button
	pause_button.text = ""
	var pause_icon: Texture2D = preload("res://assets/ui/pause-button.png")
	var icon_rect: TextureRect = pause_button.get_node_or_null("IconTex") as TextureRect
	if not icon_rect:
		icon_rect = TextureRect.new()
		icon_rect.name = "IconTex"
		pause_button.add_child(icon_rect)
		icon_rect.anchor_left = 0.0
		icon_rect.anchor_top = 0.0
		icon_rect.anchor_right = 1.0
		icon_rect.anchor_bottom = 1.0
		icon_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	icon_rect.texture = pause_icon
	# Ensure icon is visible; sizing and anchors keep it centered
	icon_rect.modulate = Color(1, 1, 1)

	# Make labels background transparent
	if current_distance_label:
		var transparent_style = StyleBoxEmpty.new()
		current_distance_label.add_theme_stylebox_override("normal", transparent_style)


	# Ensure the pause button triggers on touch (connect pressed signal)
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)
func _on_pause_pressed() -> void:
	# Prevent a simultaneous jump by ignoring input for a short moment
	GameManager.ignore_input_for(0.15)
	GameManager.toggle_pause()


func _input(event: InputEvent) -> void:
	# Explicitly handle touch for the pause button to support multi-touch
	# (e.g. holding grapple (finger 1) and hitting pause (finger 2))
	if event is InputEventScreenTouch and event.pressed:
		if pause_button and pause_button.is_visible_in_tree():
			if pause_button.get_global_rect().has_point(event.position):
				_on_pause_pressed()
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")

	if player:
		_update_off_screen_indicator()

	if current_distance_label:
		var distance_meters: int = GameManager.max_run_distance
		current_distance_label.text = str(distance_meters) + "m"


func _on_rusty_nail_timer_started(duration: float) -> void:
	rusty_nail_timer.visible = true
	# Max fill (no progress elapsed)
	rusty_nail_timer_fill.offset_left = rusty_nail_timer.offset_left
	rusty_nail_timer_fill.offset_right = rusty_nail_timer.offset_right

func _on_rusty_nail_timer_updated(progress: float) -> void:
	if not rusty_nail_timer.visible:
		rusty_nail_timer.visible = true

	# progress is 0..1 where 1 = timer finished
	var total_width := rusty_nail_timer.offset_right - rusty_nail_timer.offset_left
	var fill_width := total_width * (1.0 - progress)
	var half := fill_width * 0.5
	rusty_nail_timer_fill.offset_left = -half
	rusty_nail_timer_fill.offset_right = half

	# Update color: White -> Red as it progresses
	var sb = rusty_nail_timer_fill.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		sb.bg_color = Color.WHITE.lerp(Color(1, 0, 0, 1), progress)

func _on_rusty_nail_timer_stopped() -> void:
	rusty_nail_timer.visible = false

func _on_game_state_changed(state: int) -> void:
	# GameManager handles distance reset internally when player resets
	pass

func _update_off_screen_indicator() -> void:
	if not off_screen_indicator:
		return

	# Get player screen position
	var screen_pos = player.get_global_transform_with_canvas().origin
	var viewport_rect = get_viewport().get_visible_rect()

	# Margin to keep the arrow fully on screen (approx half icon size)
	# Margin to keep the arrow fully on screen
	var margin = 50.0

	# Only show if player is ABOVE the screen (y < 0)
	if screen_pos.y >= 0:
		# Player is visible OR below screen
		off_screen_indicator.visible = false
	else:
		# Player is off-screen (ABOVE)
		off_screen_indicator.visible = true

		# Clamp X position to screen edges with margin, FIX Y to top margin
		var clamped_x = clamp(screen_pos.x, viewport_rect.position.x + margin, viewport_rect.end.x - margin)
		var clamped_y = viewport_rect.position.y + margin

		off_screen_indicator.position = Vector2(clamped_x, clamped_y) - off_screen_indicator.pivot_offset

		# Rotate to point at player
		# Adjusted to + PI / 2.0 based on request "rotated by 180" relative to last fix (-PI/2).
		var to_player = screen_pos - Vector2(clamped_x, clamped_y)
		off_screen_indicator.rotation = to_player.angle() - PI / 2.0 + PI
