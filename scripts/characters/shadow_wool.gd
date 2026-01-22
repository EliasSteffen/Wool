extends Wool

var _sim_jump_pressed: bool = false
var _sim_jump_held: bool = false

func _ready() -> void:
	# Do NOT call super._ready() immediately if we want to modify things before?
	# Actually super._ready() does setup. We want that.
	super._ready()
	
	# Remove from 'player' group to avoid interference
	if is_in_group("player"):
		remove_from_group("player")
	
	# Disable Camera
	if camera:
		camera.enabled = false
		camera.queue_free()
		
	# Collision Layer Adjustment
	# We want to collide with World (Layer 1) and Nails (Interaction?)
	# But NOT Enemies (Layer ?)
	# Standard: 1=World, 2=Character, 3=Enemy
	# We keep Layer 2 so Nails can detect us.
	# We Mask Layer 1 so we stand on ground.
	collision_mask = 1
	
	# Initial State
	velocity = Vector2.ZERO
	_game_started = true # Force game start mode so it runs physics logic
	
	# Disable sound effects to avoid spam?
	# Or keep them for realism? "physics should be also the same" implies sound too?
	# Keep sounds.

func _unhandled_input(event: InputEvent) -> void:
	pass # Ignore real input

func _get_jump_just_pressed() -> bool:
	var res = _sim_jump_pressed
	_sim_jump_pressed = false
	return res

func _get_jump_held() -> bool:
	return _sim_jump_held

# === CONTROLS ===
func sim_press_jump() -> void:
	_sim_jump_pressed = true
	_sim_jump_held = true

func sim_release_jump() -> void:
	_sim_jump_held = false

func die() -> void:
	# Prevent Game Over
	# Just vanish or reset?
	# Tutorial controller handles reset loop.
	pass
