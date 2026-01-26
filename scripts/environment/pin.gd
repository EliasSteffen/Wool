class_name Pin
extends Sprite2D

func _ready() -> void:
	# Ensure proper layering
	# Platform is Z=0. We want Shadow on Platform (Z=1) and Pin on Shadow (Z=2).
	z_index = 2

	var shadow = Sprite2D.new()
	shadow.texture = texture
	shadow.scale = Vector2(1.0, 1.0) # Relative to parent
	shadow.rotation = 0.0 # Relative

	# Offset logic
	# Background pins used scale 3.0 and offset 15.
	# These pins are scale ~0.6 to 0.9.
	# 15 / 3.0 = 5 offset per scale unit?
	# Let's try a fixed local offset of (10, 10) / scale?
	# Or simpler: Fixed visual offset (5, 5).
	# Since shadow is child, position (10, 10) will be scaled by parent scale.
	# If parent scale is 0.6, (10, 10) becomes (6, 6) global. Close enough.
	shadow.position = Vector2(10, 10)

	shadow.modulate = Color(0, 0, 0, 0.5)
	shadow.z_index = -1 # Relative to Pin (Z=2) -> Z=1.

	add_child(shadow)
