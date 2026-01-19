extends CanvasLayer

@onready var pause_button: Button = $PauseButton
@onready var current_distance_label: Label = $CurrentDistance
@onready var highscore_label: Label = $Label
@onready var rusty_nail_timer: Control = $RustyNailTimer
@onready var rusty_nail_timer_bg: ColorRect = $RustyNailTimer/Background
@onready var rusty_nail_timer_fill: ColorRect = $RustyNailTimer/Fill

var player: BasePlayer = null

# Track starting X so distance reads 0m at game start
var _start_x: float = 0.0
var _start_initialized: bool = false

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

	# Clear default text and use a centered TextureRect so the icon fills the button
	pause_button.text = ""
	var pause_icon: Texture2D = preload("res://assets/ui/pause.svg")
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

	if highscore_label:
		var transparent_style = StyleBoxEmpty.new()
		highscore_label.add_theme_stylebox_override("normal", transparent_style)

	# Ensure the pause button triggers on touch (connect pressed signal)
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)
func _on_pause_pressed() -> void:
	# Prevent a simultaneous jump by ignoring input for a short moment
	GameManager.ignore_input_for(0.15)
	GameManager.toggle_pause()

func _process(delta: float) -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")
		if player:
			# Initialize highscore display
			highscore_label.text = "Highscore: " + str(GameManager.highscore) + "m"

	# Initialize start X on first detection or when reset by game state
	if player:
		if not _start_initialized:
			_start_x = player.global_position.x
			_start_initialized = true

		if current_distance_label:
			var distance_meters: int = int(max(player.global_position.x - _start_x, 0.0) / 10.0)
			current_distance_label.text = str(distance_meters) + "m"

			# Update highscore if beaten
			GameManager.update_highscore(distance_meters)
			highscore_label.text = "Highscore: " + str(GameManager.highscore) + "m"

func _on_rusty_nail_timer_started(duration: float) -> void:
	rusty_nail_timer.visible = true
	# Max fill (no progress elapsed)
	rusty_nail_timer_fill.offset_left = rusty_nail_timer.offset_left
	rusty_nail_timer_fill.offset_right = rusty_nail_timer.offset_right

func _on_rusty_nail_timer_updated(progress: float) -> void:
	# progress is 0..1 where 1 = timer finished
	var total_width := rusty_nail_timer.offset_right - rusty_nail_timer.offset_left
	var fill_width := total_width * (1.0 - progress)
	var half := fill_width * 0.5
	rusty_nail_timer_fill.offset_left = -half
	rusty_nail_timer_fill.offset_right = half

func _on_rusty_nail_timer_stopped() -> void:
	rusty_nail_timer.visible = false

func _on_game_state_changed(state: int) -> void:
	# When the game starts playing, reset start position so the displayed distance begins at 0m
	if state == GameManager.GameState.PLAYING:
		_start_initialized = false
		if player:
			_start_x = player.global_position.x
			_start_initialized = true
