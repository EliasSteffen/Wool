extends Control

@onready var hand: TextureRect = $Hand
@onready var circle: TextureRect = $Circle

func _ready() -> void:
	# Start the animation loop
	_play_animation()

func _play_animation() -> void:
	if not hand or not circle:
		return
		
	# Reset state
	# Bigger Scale Start (Now using 512px texture, so 0.5 scale = 256px visual size = 4x original 64px)
	# Hand Pivot is set to Top-Center (256, 0) in Scene
	hand.scale = Vector2.ONE * 0.5
	hand.modulate.a = 0.0
	
	# Start slightly down-right. Since pivot is at top-center, (0,0) centers the finger tip.
	# We want it to move TO (0,0). Start at offset.
	hand.position = Vector2(60, 60) 
	
	circle.scale = Vector2.ONE * 0.25 # Start 50% smaller (0.25 of 512 = 128px)
	circle.modulate.a = 0.0
	
	var tween = create_tween().set_loops()
	
	# 1. Hand fades in and moves to target (Appears)
	tween.tween_property(hand, "modulate:a", 1.0, 0.3)
	# Move to (-181, -53) -> This aligns the Pivot (Fingertip at 181,53) with Parent Center (0,0)
	# Target = Center - Pivot
	tween.parallel().tween_property(hand, "position", Vector2(-181, -53), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 2. Hand presses down (Scale down slightly to simulate press pressure?)
	# 0.5 * 0.9 = 0.45
	tween.tween_property(hand, "scale", Vector2(0.45, 0.45), 0.1).set_delay(0.2)
	
	# 3. Circle expands and fades out (Touch ripple)
	# Instant appear
	tween.parallel().tween_property(circle, "modulate:a", 1.0, 0.0).set_delay(0.2) 
	# Scale UP (Ripple) - From 0.25 to 0.5 (128px to 256px)
	tween.parallel().tween_property(circle, "scale", Vector2(0.5, 0.5), 0.4).set_delay(0.2)
	tween.parallel().tween_property(circle, "modulate:a", 0.0, 0.4).set_delay(0.2)
	
	# 4. Hand releases and fades out
	tween.tween_property(hand, "scale", Vector2(0.5, 0.5), 0.1) # Return to "normal" big size
	tween.tween_property(hand, "modulate:a", 0.0, 0.3).set_delay(0.3)
	
	# Wait a bit before repeating
	tween.tween_interval(0.5)
