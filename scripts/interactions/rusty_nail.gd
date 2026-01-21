class_name RustyNail
extends BaseNail

# Rusty Nail Logic
@export var fall_delay: float = 3.0

var _is_triggered: bool = false
var _is_falling: bool = false
var _fall_timer: Timer
var _shake_tween: Tween

func _ready() -> void:
	super._ready()
	_setup_timer()

func _setup_interaction() -> void:
	interaction_name = "RustyNail"
	# Rusty colors (usually fixed texture, but can tint)
	normal_color = InteractionConstants.get_value("Visuals", "rusty_nail_color", InteractionConstants.DEFAULT_RUSTY_NAIL_COLOR)
	highlight_color = InteractionConstants.get_value("Visuals", "highlight_nail_color", InteractionConstants.DEFAULT_HIGHLIGHT_COLOR)
	_update_visual()

func _setup_timer() -> void:
	_fall_timer = Timer.new()
	_fall_timer.one_shot = true
	_fall_timer.wait_time = fall_delay
	_fall_timer.timeout.connect(_on_fall_timeout)
	add_child(_fall_timer)

# Triggered when player grapples
func trigger() -> void:
	if _is_triggered: return
	_is_triggered = true
	
	# Start Shake Effect
	_start_shake()
	
	# Emit signal using GameManager
	GameManager.rusty_nail_timer_started.emit(fall_delay)
	
	_fall_timer.start()

var _was_used: bool = false

func _process(delta: float) -> void:
	if _is_triggered and not _is_falling:
		var used = is_being_used()
		
		if used:
			var time_left = _fall_timer.time_left
			var progress = 1.0 - (time_left / fall_delay)
			GameManager.rusty_nail_timer_updated.emit(progress)
		elif _was_used and not used:
			# Just released - hide the timer
			GameManager.rusty_nail_timer_stopped.emit()
			
		_was_used = used

func _start_shake() -> void:
	if _shake_tween: _shake_tween.kill()
	_shake_tween = create_tween()
	# Random shake offset
	_shake_tween.set_loops() # Infinite loops, killed on timeout
	_shake_tween.tween_property(self, "position", position + Vector2(5,0), 0.05)
	_shake_tween.tween_property(self, "position", position - Vector2(5,0), 0.05)
	_shake_tween.tween_property(self, "position", position, 0.05)
	
func _on_fall_timeout() -> void:
	# Break/Fall logic
	# For now just disable and fall
	is_active = false
	_is_falling = true
	
	# Physics fall using a simple translation or by enabling physics body?
	# Let's just animate it falling down
	if _shake_tween: _shake_tween.kill()
	
	var fall_tween = create_tween()
	fall_tween.tween_property(self, "position:y", position.y + 1000, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.tween_callback(queue_free)
	
	GameManager.rusty_nail_timer_stopped.emit()

	# Break any active grapple (Player logic handles distance check, but we force release?)
	# The player checks if target is valid usually.

func _update_visual() -> void:
	var color = highlight_color if is_active else normal_color
	# Only tint if desired, usually rusty nail has specific texture
	# But highlighting is important
	
	var back = get_node_or_null(NODE_BACK_SPRITE) # e.g. "back" node name mapped to constant?
	# RustyNail scene has "back" and "front" nodes (lowercase)
	# We should rename them in the scene to match BaseNail "BackSprite", "FrontSprite"
	# OR handle both names here.
	
	# Let's strictly rename scene nodes.
	if back: back.modulate = color
	var front = get_node_or_null(NODE_FRONT_SPRITE)
	if front: front.modulate = color
	
	# Legacy Fallback
	var legacy_back = get_node_or_null("back")
	if legacy_back: legacy_back.modulate = color
	var legacy_front = get_node_or_null("front")
	if legacy_front: legacy_front.modulate = color
