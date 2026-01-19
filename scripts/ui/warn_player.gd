class_name WarnPlayer
extends Node2D

@onready var exclamation_mark: Sprite2D = $ExclamationMark

func _ready() -> void:
	if exclamation_mark:
		_start_pulsing()
	
	# Auto-destroy after 2 seconds
	await get_tree().create_timer(2.0).timeout
	queue_free()

func _start_pulsing() -> void:
	var tween = create_tween().set_loops()
	# Scale up
	tween.tween_property(exclamation_mark, "scale", exclamation_mark.scale * 1.75, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Scale down (below original size)
	tween.tween_property(exclamation_mark, "scale", exclamation_mark.scale * 0.5, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
