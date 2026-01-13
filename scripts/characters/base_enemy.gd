class_name BaseEnemy
extends BaseCharacter

## Base class for all enemies
## Inherits from BaseCharacter for common physics/feature support

func take_damage(amount: int) -> void:
	# Default implementation - override in specific enemies
	die()

func die() -> void:
	queue_free()
