extends Node2D

## Level 1 Script
##
## Handles start icons animation and removal on first input

signal start_icons_animation_started

@onready var start_icons: Node2D = $Starticons

var player: BasePlayer = null
var _has_started: bool = false
var _is_animating: bool = false
var _animation_speed: float = 800.0  # Pixels per second upward

func _ready() -> void:
	if not start_icons:
		push_warning("Level1: Starticons node not found!")
		return
	
	# If this is not the first game start, remove start icons immediately
	if not GameManager.is_first_game_start:
		print("Level1: Not first start - removing start icons immediately")
		_remove_start_icons()
	else:
		# Mark that the game has been started (after first load)
		GameManager.mark_game_started()

func _process(delta: float) -> void:
	# Try to find player if not found yet
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	# Check for first input (jump or screen press)
	if not _has_started and not _is_animating:
		if Input.is_action_just_pressed("jump"):
			_start_animation()
	
	# Animate upward if animation is active
	if _is_animating and start_icons:
		start_icons.position.y -= _animation_speed * delta
		
		# Check if icons are out of camera view
		if _is_out_of_camera_view():
			_remove_start_icons()

func _start_animation() -> void:
	if not start_icons:
		return
	
	_has_started = true
	_is_animating = true
	start_icons_animation_started.emit()
	print("Level1: Starting animation for start icons")

func _is_out_of_camera_view() -> bool:
	if not start_icons:
		return true
	
	# Calculate the actual top and bottom bounds of the icons in global coordinates
	var icons_bounds = _get_icons_bounds()
	var icons_top = icons_bounds["top"]
	var icons_bottom = icons_bounds["bottom"]
	
	# Try to get player camera if available
	if player and player.camera:
		var camera = player.camera
		var viewport_rect = get_viewport().get_visible_rect()
		var half_height = (viewport_rect.size.y / camera.zoom.y) * 0.5
		
		var camera_top = camera.global_position.y - half_height
		
		# Check if icons are completely above camera view (with margin)
		return icons_bottom < camera_top - 200.0  # 200px margin above camera
	
	# Fallback: check if icons are far above viewport
	var viewport_rect = get_viewport().get_visible_rect()
	var viewport_top = viewport_rect.position.y
	return icons_bottom < viewport_top - 200.0  # 200px margin

func _get_icons_bounds() -> Dictionary:
	var result = {"top": INF, "bottom": -INF}
	
	if not start_icons:
		return result
	
	var icons_center_y = start_icons.global_position.y
	
	# Get the bounding box of all children in global coordinates
	for child in start_icons.get_children():
		if child is Node2D:
			var child_global_y = child.global_position.y
			var child_height: float = 0.0
			
			if child is Sprite2D:
				var texture = child.texture
				if texture:
					child_height = texture.get_height() * child.scale.y
			elif child is Label:
				child_height = child.size.y
			
			var child_top = child_global_y - child_height * 0.5
			var child_bottom = child_global_y + child_height * 0.5
			
			result["top"] = min(result["top"], child_top)
			result["bottom"] = max(result["bottom"], child_bottom)
	
	# Fallback if no children found
	if result["top"] == INF or result["bottom"] == -INF:
		result["top"] = icons_center_y
		result["bottom"] = icons_center_y
	
	return result

func _remove_start_icons() -> void:
	if start_icons:
		print("Level1: Removing start icons (out of camera view)")
		start_icons.queue_free()
		start_icons = null
		_is_animating = false
