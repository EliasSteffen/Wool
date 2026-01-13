class_name KillZone
extends Area2D

## KillZone - Resets the game when player enters
##
## Can be used for bottomless pits, spikes, etc.
## When the player enters this zone, they are returned to the main menu.

func _ready() -> void:
	# Ensure we are monitoring
	monitoring = true
	monitorable = false

	# Make sure we detect the player (Layer 1 is usually default, but let's be safe)
	# If you have a specific Player layer, set collision_mask in the Inspector or here.
	# For now, we rely on the Inspector/Scene settings, but we'll print debug info.
	# print("KillZone ready. Monitoring: ", monitoring, " Mask: ", collision_mask)

	# FORCE ENABLE LAYER 1 (Value 1) just in case it was turned off
	set_collision_mask_value(1, true)
	# Also enable Layer 2 just in case
	set_collision_mask_value(2, true)

	# print("KillZone updated Mask: ", collision_mask)

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		body.die()

func _reset_game() -> void:
	GameManager.return_to_menu()
