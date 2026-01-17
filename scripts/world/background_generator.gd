extends Node2D

## Background Generator
##
## Generates infinite background tiles that repeat horizontally
## Background spans from y=0 to y=-1755

@export var background_texture: Texture2D = preload("res://assets/map/background.png")

@onready var parallax_layer: ParallaxLayer = get_node_or_null("../ParallaxBackground/ParallaxLayer")

var _player: BasePlayer = null
var _camera_width: float = 0.0
var _last_generated_x: float = 0.0
var _background_tiles: Array[Sprite2D] = []
var _background_width: float = 0.0  # Width of a single background tile
var _background_height: float = 1755.0  # Height from y=0 to y=-1755

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_camera_width = get_viewport().get_visible_rect().size.x
	else:
		_camera_width = get_viewport().get_visible_rect().size.x

	# Get background texture dimensions and calculate scaled width
	if background_texture:
		var texture_width = background_texture.get_width()
		var texture_height = background_texture.get_height()
		if texture_height > 0:
			var scale = _background_height / texture_height
			_background_width = texture_width * scale
		else:
			_background_width = texture_width

	# Initial background generation
	if parallax_layer:
		_generate_background_in_range(0.0, 2.0 * _camera_width)

func _process(delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
	if not _player or not _player.camera:
		return

	if not parallax_layer:
		parallax_layer = get_node_or_null("../ParallaxBackground/ParallaxLayer")
		if not parallax_layer:
			return

	if _background_width <= 0:
		return

	var camera = _player.camera
	# Get camera position in world coordinates
	var camera_world_x = camera.global_position.x
	var camera_left_border = camera_world_x - (_camera_width / 2.0) / camera.zoom.x
	var camera_right_border = camera_world_x + (_camera_width / 2.0) / camera.zoom.x

	# Generate ahead (to the right)
	# Use world coordinates for generation
	while _last_generated_x < camera_right_border + _camera_width:
		_generate_background_in_range(_last_generated_x, _last_generated_x + _background_width)
		_last_generated_x += _background_width

	# Cleanup tiles left from the camera
	_cleanup(camera_left_border - _background_width)

func _generate_background_in_range(start_x: float, end_x: float) -> void:
	if not background_texture or not parallax_layer:
		return

	# Calculate how many tiles we need in this range
	var num_tiles = ceil((end_x - start_x) / _background_width)

	for i in range(num_tiles):
		var tile_x = start_x + i * _background_width

		# Check if tile already exists (compare position relative to parallax layer)
		var tile_exists = false
		for tile in _background_tiles:
			if is_instance_valid(tile) and abs(tile.position.x - tile_x) < 10.0:
				tile_exists = true
				break

		if not tile_exists:
			_spawn_background_tile(tile_x)

func _spawn_background_tile(x: float) -> void:
	if not background_texture or not parallax_layer:
		return

	var sprite = Sprite2D.new()
	sprite.texture = background_texture
	sprite.z_index = -10

	# Position: x at tile position, y centered at -1755/2 = -877.5
	# So top is at y=0 and bottom is at y=-1755
	# Note: Position is relative to ParallaxLayer
	sprite.position = Vector2(x, -877.5)  # Center Y position

	# Scale to match desired height (1755 pixels from y=0 to y=-1755)
	if background_texture:
		var texture_height = background_texture.get_height()
		if texture_height > 0:
			var scale_y = _background_height / texture_height
			sprite.scale.y = scale_y
			# Keep aspect ratio for x scale
			var texture_width = background_texture.get_width()
			if texture_width > 0:
				sprite.scale.x = scale_y

	parallax_layer.add_child(sprite)
	_background_tiles.append(sprite)

func _cleanup(cleanup_x: float) -> void:
	var tiles_to_remove: Array[Sprite2D] = []

	for tile in _background_tiles:
		if not is_instance_valid(tile):
			tiles_to_remove.append(tile)
			continue

		# Remove tiles that are far to the left of the camera
		# Compare using position relative to parallax layer
		if tile.position.x < cleanup_x:
			tiles_to_remove.append(tile)

	for tile in tiles_to_remove:
		_background_tiles.erase(tile)
		if is_instance_valid(tile):
			tile.queue_free()
