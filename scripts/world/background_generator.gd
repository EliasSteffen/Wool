extends Node2D

## Background Generator
##
## Generates infinite background tiles that repeat horizontally
## Background spans from y=0 to y=-1755

@export var background_folder: String = "res://assets/map/fetzen"
@export var pattern_folder: String = "res://assets/map/muster"
@export var pattern_chance: float = 0.9
@export var max_patterns_per_tile: int = 25
@export var parallax_factor_x: float = 0.5

# Preload textures to ensure they are included in exports
const BACKGROUND_TEXTURES: Array[Texture2D] = [
	preload("res://assets/map/fetzen/fetzen-1.jpg")
]
const PATTERN_TEXTURES: Array[Texture2D] = [
	preload("res://assets/map/muster/muster-1.png"),
	preload("res://assets/map/muster/muster-2.png")
]

@onready var parallax_layer: ParallaxLayer = get_node_or_null("../ParallaxBackground/ParallaxLayer")

var _player: BasePlayer = null
var _camera_width: float = 0.0
var _last_generated_x: float = 0.0
var _background_tiles: Array[Sprite2D] = []
var _background_width: float = 0.0  # Width of a single background tile
var _background_height: float = abs(GameManager.PLAYABLE_HEIGHT_TOP - GameManager.PLAYABLE_HEIGHT_BOTTOM)

# Runtime-loaded pattern textures and pattern nodes
var _pattern_textures: Array[Texture2D] = []
var _pattern_nodes: Array[Sprite2D] = []

# Runtime-loaded textures from `background_folder`
var _background_textures: Array[Texture2D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_camera_width = get_viewport().get_visible_rect().size.x
	else:
		_camera_width = get_viewport().get_visible_rect().size.x

	# Use preloaded textures
	_background_textures = BACKGROUND_TEXTURES.duplicate()
	_pattern_textures = PATTERN_TEXTURES.duplicate()

	# Randomize RNG for tile selection and pattern placement
	_rng.randomize()

	if _background_textures.size() == 0:
		# error...
		return

	var max_scaled_width: float = 0.0
	for tex in _background_textures:
		if tex:
			var tw: float = tex.get_width()
			var th: float = tex.get_height()
			var scaled_w: float = (tw * (_background_height / th)) if th > 0 else tw
			if scaled_w > max_scaled_width:
				max_scaled_width = scaled_w
	_background_width = max_scaled_width

	# Initial background generation
	if parallax_layer:
		# Set parallax motion scale
		# x moves slower (parallax), y is fixed (1.0) to match gameplay vertical bounds
		parallax_layer.motion_scale = Vector2(parallax_factor_x, 1.0)
		
		# Initial generation assumes camera is near 0, so WorldX ~ LayerX
		var generation_end: float = 2.0 * _camera_width
		if _background_textures.size() > 0:
			_generate_background_until(generation_end)
		else:
			_generate_background_in_range(0.0, generation_end)

func _process(delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
	if not _player or not _player.camera:
		return

	if not parallax_layer:
		parallax_layer = get_node_or_null("../ParallaxBackground/ParallaxLayer")
		if not parallax_layer:
			return

	if _background_textures.size() == 0 and _background_width <= 0:
		return

	var camera = _player.camera
	
	# Calculate visible bounds in the ParallaxLayer's coordinate space
	# Since motion_scale.x < 1, the layer moves slower than the camera.
	var layer_center_x = camera.global_position.x * parallax_factor_x
	var visible_half_width = (_camera_width / 2.0) / camera.zoom.x
	
	var layer_right_border = layer_center_x + visible_half_width
	var layer_left_border = layer_center_x - visible_half_width

	# Generate ahead (to the right)
	var generation_end: float = layer_right_border + _camera_width
	
	if _background_textures.size() > 0:
		_generate_background_until(generation_end)
	else:
		while _last_generated_x < generation_end:
			_generate_background_in_range(_last_generated_x, _last_generated_x + _background_width)
			_last_generated_x += _background_width

	# Cleanup tiles left from the camera using layer coordinates
	_cleanup(layer_left_border - _background_width)

func _generate_background_in_range(start_x: float, end_x: float) -> void:
	if not parallax_layer or _background_width <= 0:
		return

	# Calculate how many tiles we need in this range (using uniform width)
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

func _generate_background_until(end_x: float) -> void:
	if _background_textures.size() == 0:
		return

	var x: float = max(_last_generated_x, 0.0)
	while x < end_x:
		# Choose a texture from the loaded set and spawn it at x
		var tex: Texture2D = _background_textures[_rng.randi_range(0, _background_textures.size() - 1)]
		if tex == null:
			break
		var tile_w: float = _spawn_background_tile(x, tex)
		if tile_w <= 0.0:
			# avoid infinite loop
			tile_w = 1.0
		x += tile_w

	_last_generated_x = x

func _spawn_background_tile(x: float, texture_in: Texture2D = null) -> float:
	if not parallax_layer:
		return 0.0

	var texture := texture_in if texture_in != null else _choose_random_texture()
	if not texture:
		return 0.0

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.z_index = -10

	# Position: x at tile position, y centered 
	# Top is GameManager.PLAYABLE_HEIGHT_BOTTOM (0), Bottom is GameManager.PLAYABLE_HEIGHT_TOP (-1755)
	# Center Y = (0 + -1755) / 2
	var center_y = (GameManager.PLAYABLE_HEIGHT_BOTTOM + GameManager.PLAYABLE_HEIGHT_TOP) / 2.0
	sprite.position = Vector2(x, center_y)

	var tile_width: float = 0.0
	# Scale background textures to fill the background height
	var texture_height := texture.get_height()
	if texture_height > 0:
		var scale := _background_height / texture_height
		sprite.scale = Vector2(scale, scale)
		var texture_width := texture.get_width()
		if texture_width > 0:
			tile_width = texture_width * scale
		else:
			tile_width = texture_width
	else:
		# Fallback: preserve original size if height information is unavailable
		sprite.scale = Vector2(1, 1)
		tile_width = texture.get_width()

	parallax_layer.add_child(sprite)
	_background_tiles.append(sprite)

	# Possibly spawn decorative pattern(s) on this tile using the tile width
	if tile_width <= 0.0:
		# Fallback to a small width to avoid infinite loops
		tile_width = 1.0
	_maybe_spawn_patterns_in_tile(x, tile_width)

	return tile_width

func _load_background_textures_from_folder() -> void:
	_background_textures.clear()
	var dir := DirAccess.open(background_folder)
	if dir:
		dir.list_dir_begin()
		var file := dir.get_next()
		while file != "":
			if not dir.current_is_dir():
				var ext := file.get_extension().to_lower()
				if ext in ["png", "jpg", "jpeg", "webp"]:
					var path := "%s/%s" % [background_folder, file]
					var tex := ResourceLoader.load(path) as Texture2D
					if tex:
						_background_textures.append(tex)
			file = dir.get_next()
		dir.list_dir_end()

func _choose_random_texture() -> Texture2D:
	return _background_textures[_rng.randi_range(0, _background_textures.size() - 1)]

func _load_pattern_textures_from_folder() -> void:
	_pattern_textures.clear()
	var dir := DirAccess.open(pattern_folder)
	if dir:
		dir.list_dir_begin()
		var file := dir.get_next()
		while file != "":
			if not dir.current_is_dir():
				var ext := file.get_extension().to_lower()
				if ext in ["png", "jpg", "jpeg", "webp"]:
					var path := "%s/%s" % [pattern_folder, file]
					var tex := ResourceLoader.load(path) as Texture2D
					if tex:
						_pattern_textures.append(tex)
			file = dir.get_next()
		dir.list_dir_end()

func _choose_random_pattern_texture() -> Texture2D:
	if _pattern_textures.size() == 0:
		return null
	return _pattern_textures[_rng.randi_range(0, _pattern_textures.size() - 1)]

func _maybe_spawn_patterns_in_tile(tile_x: float, tile_width: float = 0.0) -> void:
	if _pattern_textures.size() == 0:
		return
	if _rng.randf() >= pattern_chance:
		return

	var usable_width: float = tile_width if tile_width > 0.0 else (_background_width if _background_width > 0.0 else 1.0)
	var count: int = _rng.randi_range(1, max_patterns_per_tile)
	for i in range(count):
		var texture: Texture2D = _choose_random_pattern_texture()
		if texture == null:
			continue
		var offset_x: float = _rng.randf_range(0.0, usable_width)
		var px: float = tile_x + offset_x
		# Choose Y between 10% and 90% of background height so patterns stay within visible area
		var py: float = -(_rng.randf_range(0.1, 0.9) * _background_height)
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.z_index = -5
		sprite.position = Vector2(px, py)
		# Keep pattern at original size (no scaling)
		sprite.scale = Vector2(1, 1)
		parallax_layer.add_child(sprite)
		_pattern_nodes.append(sprite)

func _cleanup(cleanup_x: float) -> void:
	var tiles_to_remove: Array[Sprite2D] = []
	var patterns_to_remove: Array[Sprite2D] = []

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

	for p in _pattern_nodes:
		if not is_instance_valid(p) or p.position.x < cleanup_x:
			patterns_to_remove.append(p)

	for p in patterns_to_remove:
		_pattern_nodes.erase(p)
		if is_instance_valid(p):
			p.queue_free()
