class_name GameOverScreen
extends Control

var _can_interact: bool = false

func _ready() -> void:
	# Connect close button from MenuBackground
	$MenuBackground/CloseButton.pressed.connect(_on_close_button_pressed)
	get_tree().root.size_changed.connect(_update_layout)
	call_deferred("_update_layout")

	name_prompt.visible = false
	rank_label.visible = false
	publish_button.pressed.connect(_on_publish_pressed)
	name_edit.text_submitted.connect(_on_name_edit_submitted)

	# Start invisible
	modulate.a = 0.0

	var duration = 0.5 if Engine.time_scale != 1.0 else 1.0

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func(): _can_interact = true)

	_setup_score_display(duration)

@onready var score_display: Control = $MarginContainer/VBoxContainer/ScoreDisplay
@onready var menu_background: Control = $MenuBackground
@onready var content_margin: MarginContainer = $MarginContainer
# New References
@onready var highscore_container: Control = $MarginContainer/VBoxContainer/ScoreDisplay/HighscoreContainer
@onready var bar_mask: Control = $MarginContainer/VBoxContainer/ScoreDisplay/HighscoreContainer/BarMask
@onready var platform_container: Control = $MarginContainer/VBoxContainer/ScoreDisplay/HighscoreContainer/PlatformContainer
@onready var platform_sprite: Sprite2D = $MarginContainer/VBoxContainer/ScoreDisplay/HighscoreContainer/PlatformContainer/PlatformSprite
# Wool Marker is now a sibling of Platform Container
@onready var wool_marker: Control = $MarginContainer/VBoxContainer/ScoreDisplay/HighscoreContainer/WoolMarker
@onready var wool_instance: Node = $MarginContainer/VBoxContainer/ScoreDisplay/HighscoreContainer/WoolMarker/Wool
@onready var score_label: Label = $MarginContainer/VBoxContainer/ScoreDisplay/HighscoreContainer/WoolMarker/ScoreLabel


@onready var end_label: Label = $MarginContainer/VBoxContainer/ScoreDisplay/EndLabel
@onready var new_highscore_label: Label = $MarginContainer/VBoxContainer/NewHighscoreLabel
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var instruction_label: Label = $MarginContainer/VBoxContainer/InstructionLabel

# Name prompt
@onready var name_prompt: VBoxContainer = $MarginContainer/VBoxContainer/NamePrompt
@onready var prompt_label: Label = $MarginContainer/VBoxContainer/NamePrompt/PromptLabel
@onready var name_edit: LineEdit = $MarginContainer/VBoxContainer/NamePrompt/NameRow/NameEdit
@onready var publish_button: Button = $MarginContainer/VBoxContainer/NamePrompt/NameRow/PublishButton
@onready var rank_label: Label = $MarginContainer/VBoxContainer/RankLabel

var _move_tween: Tween = null
var internal_wool_sprite: AnimatedSprite2D = null

## While the name prompt is up, _input() must not treat taps as "restart" -
## otherwise the LineEdit can never be focused or typed into.
var _name_prompt_active: bool = false
## The name the field was pre-filled with, so an emptied field still has
## something to publish under.
var _suggested_name: String = ""

## Shown once the prompt is gone - or when it never appeared.
const RESTART_HINT: String = "Drücke auf den Bildschirm,\num das Level neu zu starten"
## Shown underneath the open prompt. Leaving is a valid answer, and the player
## has to be able to tell that it is not the answer that publishes.
const LOCAL_ONLY_HINT: String = "Ohne \"Eintragen\" bleibt dein Score\nnur auf diesem Gerät"

func _update_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var base_size: float = minf(viewport_size.x, viewport_size.y)
	var outer_margin_x: float = clampf(viewport_size.x * 0.08, 12.0, 150.0)
	var outer_margin_y: float = clampf(viewport_size.y * 0.08, 12.0, 150.0)
	var inner_margin_x: float = clampf(viewport_size.x * 0.06, 16.0, 90.0)
	var inner_margin_y: float = clampf(viewport_size.y * 0.06, 16.0, 90.0)

	menu_background.offset_left = outer_margin_x
	menu_background.offset_top = outer_margin_y
	menu_background.offset_right = -outer_margin_x
	menu_background.offset_bottom = -outer_margin_y

	# Keep text/content bound to the same panel rect as MenuBackground.
	content_margin.offset_left = outer_margin_x
	content_margin.offset_top = outer_margin_y
	content_margin.offset_right = -outer_margin_x
	content_margin.offset_bottom = -outer_margin_y

	content_margin.add_theme_constant_override("margin_left", int(inner_margin_x))
	content_margin.add_theme_constant_override("margin_top", int(inner_margin_y))
	content_margin.add_theme_constant_override("margin_right", int(inner_margin_x))
	content_margin.add_theme_constant_override("margin_bottom", int(inner_margin_y))

	title_label.add_theme_font_size_override("font_size", int(clampf(base_size * 0.1, 44.0, 150.0)))
	new_highscore_label.add_theme_font_size_override("font_size", int(clampf(base_size * 0.05, 24.0, 60.0)))
	end_label.add_theme_font_size_override("font_size", int(clampf(base_size * 0.035, 22.0, 40.0)))
	instruction_label.add_theme_font_size_override("font_size", int(clampf(base_size * 0.035, 22.0, 40.0)))
	score_label.add_theme_font_size_override("font_size", int(clampf(base_size * 0.03, 18.0, 32.0)))
	score_display.custom_minimum_size.y = clampf(viewport_size.y * 0.18, 120.0, 200.0)

	rank_label.add_theme_font_size_override("font_size", int(clampf(base_size * 0.042, 26.0, 52.0)))

	_update_name_prompt_layout(viewport_size, base_size)

func _update_name_prompt_layout(viewport_size: Vector2, base_size: float) -> void:
	if not is_instance_valid(name_prompt):
		return

	var field_font_size: int = int(clampf(base_size * 0.038, 24.0, 48.0))
	var button_font_size: int = int(clampf(base_size * 0.035, 22.0, 44.0))

	prompt_label.add_theme_font_size_override("font_size", int(clampf(base_size * 0.032, 20.0, 40.0)))

	name_edit.add_theme_font_size_override("font_size", field_font_size)
	# Width only. The styled box supplies its own vertical padding, so forcing a
	# height here would crop the text.
	#
	# Narrower than it looks like it should be: "Eintragen" plus the button's own
	# 40px-a-side content margin is a wide neighbour, and the row has no way to
	# shrink either of them on a narrow phone.
	name_edit.custom_minimum_size = Vector2(clampf(viewport_size.x * 0.26, 220.0, 480.0), 0.0)

	# Deliberately no custom_minimum_size on the themed button: the button
	# StyleBoxTexture already reserves 40px left/right and 20px top/bottom of
	# content margin, so it sizes itself around the label. Clamping it smaller
	# is what overflowed the text.
	if is_instance_valid(publish_button):
		publish_button.add_theme_font_size_override("font_size", button_font_size)

func _setup_score_display(fade_duration: float) -> void:
	if not score_display: return

	var current_score = GameManager.max_run_distance
	var current_time_ms = GameManager.max_run_time_ms

	# Save highscore (silently) if we beat it - update_highscore applies the
	# distance-then-time rule itself.
	GameManager.update_highscore(current_score, current_time_ms, true)

	# Bank the run. This only reaches the global board once the player has opted
	# in - before that it goes no further than player.cfg, and the prompt below
	# is the only thing that can publish it.
	LeaderboardManager.submit_run(current_score, current_time_ms)

	# Deliberately not awaited: the placement resolves in parallel with the
	# score animation so it is on screen immediately, rather than after it.
	_refresh_rank_display()

	var highscore = GameManager.highscore

	score_label.text = str(current_score) + "m"
	end_label.text = str(highscore) + "m"

	if GameManager.new_highscore_reached_this_run:
		if new_highscore_label: new_highscore_label.visible = true
		if score_label: score_label.visible = false

	# Setup Wool Instance
	if wool_instance:
		wool_instance.set_physics_process(false)
		wool_instance.set_process(false)
		if "can_control" in wool_instance: wool_instance.can_control = false
		if wool_instance.is_in_group("player"): wool_instance.remove_from_group("player")
		if wool_instance is CollisionObject2D:
			wool_instance.collision_layer = 0
			wool_instance.collision_mask = 0
		var cam = wool_instance.get_node_or_null("Camera2D")
		if cam: cam.queue_free()

		var skin = wool_instance.get_node_or_null("Skin")
		if skin: internal_wool_sprite = skin.get_node_or_null("AnimatedSprite2D")
		if internal_wool_sprite: internal_wool_sprite.play("idle")

	# Calculate ratio
	var ratio = 0.0
	if highscore > 0:
		ratio = float(current_score) / float(highscore)
	ratio = clampf(ratio, 0.0, 1.0)

	# Initial State
	bar_mask.size.x = 0
	platform_container.position.x = 0
	platform_sprite.rotation = 0
	platform_sprite.scale = Vector2(1, 1)
	wool_marker.position.x = 0 # Start at 0
	wool_marker.visible = false

	# Wait for layout
	var retries = 0
	while highscore_container.size.x <= 0 and retries < 10:
		await get_tree().process_frame
		retries += 1

	var total_width = highscore_container.size.x
	# Max width of the bar inside the mask should match container width
	if bar_mask.has_node("HighscoreBar"):
		var bar = bar_mask.get_node("HighscoreBar")
		bar.size.x = total_width # Stretch texture to full width

	# Platform moves ALL the way
	var platform_target_x = total_width

	# Wool stops at score
	var wool_target_x = total_width * ratio

	# Start Highscore Animation
	if GameManager.new_highscore_reached_this_run and new_highscore_label:
		new_highscore_label.pivot_offset = new_highscore_label.size / 2.0
		var pulse_tween = create_tween().set_loops()
		pulse_tween.tween_property(new_highscore_label, "scale", Vector2(1.1, 1.1), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse_tween.tween_property(new_highscore_label, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Main Animation Sequence
	_move_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_move_tween.finished.connect(func():
		_move_tween = null
		_can_interact = true
		_maybe_show_name_prompt()
		_maybe_request_review()
	)
	_move_tween.tween_interval(fade_duration * 0.5)

	# 1. Platform moves FAST to the end
	var platform_duration = 1.2 # Fast
	_move_tween.tween_method(_animate_platform.bind(total_width), 0.0, 1.0, platform_duration).set_ease(Tween.EASE_OUT)

	# 2. Wool Waits
	_move_tween.tween_interval(0.2)

	var wool_limit = total_width * ratio

	# 3. Make wool visible and walk to score
	_move_tween.tween_callback(func():
		wool_marker.visible = true
		if internal_wool_sprite: internal_wool_sprite.play("walk")
	)

	# Duration proportional to distance
	var walk_duration = 2.0 * ratio
	if walk_duration < 1.0: walk_duration = 1.0

	_move_tween.tween_method(_animate_wool.bind(wool_limit, current_score), 0.0, 1.0, walk_duration).set_ease(Tween.EASE_OUT)

	# End
	_move_tween.tween_callback(func():
		if internal_wool_sprite: internal_wool_sprite.play("idle")
	)

func _animate_platform(t: float, total_width: float) -> void:
	# T goes 0->1
	var platform_x = total_width * t
	platform_container.position.x = platform_x
	bar_mask.size.x = platform_x

	# Rotate Platform
	var diameter = 100.0
	if platform_sprite and platform_sprite.texture:
		diameter = platform_sprite.texture.get_width() * platform_sprite.scale.x
	var rotations = platform_x / (PI * diameter)
	platform_sprite.rotation = rotations * TAU

	# Platform shrinks from 1.0 to 0.25
	var shrink_scale = lerp(1.0, 0.25, t)
	platform_sprite.scale = Vector2(shrink_scale, shrink_scale)

	# Disappear at very end
	if t >= 0.99:
		platform_sprite.visible = false
	else:
		platform_sprite.visible = true

func _animate_wool(t: float, max_x: float, max_score: int) -> void:
	# T goes 0->1
	var current_x = max_x * t
	wool_marker.position.x = current_x

	# Score
	var disp_score = int(float(max_score) * t)
	if score_label: score_label.text = str(disp_score) + "m"


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return

	# The name prompt owns input while it is open - without this, the LineEdit
	# below would be unusable because every tap would restart the game.
	if _name_prompt_active:
		return

	# Same reasoning for the review popup: it draws above this screen, but
	# _input() still runs here first, so its buttons would double as "restart".
	if ReviewManager.is_prompt_open():
		return

	# Covers the brief window after dismissing the prompt, so the same tap does
	# not fall through and restart.
	if GameManager.is_input_ignored():
		return

	# Tap-anywhere-to-restart must not fire when the tap was aimed at one of the
	# explicit buttons - they handle themselves.
	if _is_event_over_controls(event):
		return

	# is_any_press() counts one physical press once, so a tap cannot both skip
	# the animation here and fall through to restart on its emulated twin.
	if PointerInput.is_any_press(event):
		if _move_tween and _move_tween.is_valid():
			_move_tween.kill()
			_move_tween = null
			_skip_to_end()
			return

		if _can_interact:
			_restart_game()

func _is_event_over_controls(event: InputEvent) -> bool:
	# Keys and gamepad buttons carry no position, so they are never "over" anything.
	if not (event is InputEventMouseButton or event is InputEventScreenTouch):
		return false

	var position: Vector2 = PointerInput.press_position(event)

	# Taps inside the name prompt belong to the field and its publish button, not
	# to tap-anywhere-to-restart.
	return is_instance_valid(name_prompt) and name_prompt.visible \
		and name_prompt.get_global_rect().has_point(position)

func _skip_to_end() -> void:
	var current_score = GameManager.max_run_distance
	var highscore = max(GameManager.highscore, current_score)
	var ratio = 0.0
	if highscore > 0: ratio = float(current_score) / float(highscore)
	ratio = clampf(ratio, 0.0, 1.0)

	var total_width = highscore_container.size.x
	var wool_limit = total_width * ratio

	# End state
	_animate_platform(1.0, total_width)
	wool_marker.visible = true
	_animate_wool(1.0, wool_limit, current_score)

	if internal_wool_sprite: internal_wool_sprite.play("idle")

	_can_interact = true
	_maybe_show_name_prompt()
	_maybe_request_review()

## Ask before the player's first entry ever goes up, and keep asking after every
## run until they answer with "Eintragen". Nothing here accepts on their behalf:
## leaving the screen any other way keeps the run on the device.
##
## Once they are on the board the ask stops - later runs publish by themselves -
## until they delete the entry, which puts them back at this first-time state.
func _maybe_show_name_prompt() -> void:
	if _name_prompt_active or not is_instance_valid(name_prompt):
		return
	if GameManager.max_run_distance <= 0:
		return
	if not LeaderboardManager.needs_publish_consent():
		return

	_name_prompt_active = true
	name_prompt.visible = true
	instruction_label.text = LOCAL_ONLY_HINT
	_update_layout()

	_fill_suggested_name()

## Pre-fills the field so the player only has to press once. A name they typed
## on an earlier game over wins over a fresh suggestion - it was kept locally
## precisely so they would not have to type it again.
func _fill_suggested_name() -> void:
	_suggested_name = LeaderboardManager.player_name
	if _suggested_name.is_empty():
		_suggested_name = LeaderboardManager.generate_name()
	name_edit.text = _suggested_name
	name_edit.placeholder_text = "Dein Name"
	name_edit.editable = true
	publish_button.disabled = false

## Show where this run landed globally, but only for a new personal best -
## otherwise the standing has not moved and the line is noise.
##
## Skipped while consent is still outstanding, because nothing has been
## submitted at that point. Pressing "Eintragen" calls this again, which is when
## a first-time player gets their placing.
func _refresh_rank_display() -> void:
	if not is_instance_valid(rank_label):
		return
	if not GameManager.new_highscore_reached_this_run:
		return
	if not LeaderboardManager.is_available or LeaderboardManager.needs_publish_consent():
		return

	rank_label.visible = true
	rank_label.text = "Platz wird geladen …"
	_update_layout()

	var rank: int = await LeaderboardManager.refresh_player_rank()

	if not is_instance_valid(rank_label):
		return
	if rank > 0:
		rank_label.text = "Platz %d" % rank
	else:
		rank_label.visible = false

func _close_name_prompt() -> void:
	_name_prompt_active = false
	name_prompt.visible = false
	instruction_label.text = RESTART_HINT
	_can_interact = true
	# The review ask queues behind the name prompt, never on top of it.
	_maybe_request_review()

## Offers the rating popup, but only after a beat. ReviewManager owns every
## "should we?" decision - the delay is this screen's concern: two of the three
## paths here are reached by a tap, and a dialog appearing under a finger already
## on its way down would both misfire and read as an interruption.
func _maybe_request_review() -> void:
	if _name_prompt_active or not ReviewManager.is_eligible():
		return

	# ignore_time_scale: this screen runs at Engine.time_scale = 0.5, which would
	# otherwise stretch the beat to two real seconds.
	await get_tree().create_timer(1.0, true, false, true).timeout

	# The screen may have been torn down, or the name prompt reopened, while we
	# waited - re-check rather than trusting the decision made a second ago.
	if not is_inside_tree() or _name_prompt_active:
		return

	ReviewManager.maybe_prompt()

## Enter in the name field means the same as pressing the button next to it.
func _on_name_edit_submitted(_text: String) -> void:
	_on_publish_pressed()

## The one path that puts a score on the global board for the first time.
func _on_publish_pressed() -> void:
	AudioManager.play_sound(AudioManager.GAME.CLICK)

	# No uniqueness check: names may repeat, and this must work with no signal.
	LeaderboardManager.publish_run(
		_chosen_name(), GameManager.max_run_distance, GameManager.max_run_time_ms
	)
	_close_name_prompt()

	# Now that a run is on its way up, the standing is worth showing.
	_refresh_rank_display()

## Keeps a typed name for the next game over without publishing anything -
## storing a name is purely local until consent is given. The player edited the
## field, so discarding it and suggesting a fresh random name after every death
## would be its own small annoyance.
func _remember_name_locally() -> void:
	LeaderboardManager.set_player_name(_chosen_name())

## What the player would go on the board as: whatever is in the field, falling
## back to the name it was pre-filled with if they cleared it.
func _chosen_name() -> String:
	var entered: String = LeaderboardEntry.sanitize_name(name_edit.text)
	if entered.is_empty():
		return _suggested_name
	return entered


func _restart_game() -> void:
	# Leaving is not consent. The run was already banked locally when this screen
	# opened; all that is left is to keep the name they typed for next time.
	if _name_prompt_active:
		_remember_name_locally()

	_can_interact = false
	Engine.time_scale = 1.0
	if get_parent() is CanvasLayer: get_parent().queue_free()
	else: queue_free()
	GameManager.start_game()

func _on_close_button_pressed() -> void:
	_restart_game()
