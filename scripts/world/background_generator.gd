extends Node2D

## Background Generator
##
## Generates infinite background tiles that repeat horizontally
## Background spans from y=0 to y=-1755

@export var background_folder: String = "res://assets/map/fetzen"
@export var pattern_folder: String = "res://assets/map/muster"
@export var pattern_chance: float = 0.4
@export var max_patterns_per_tile: int = 5
@export var parallax_factor_x: float = 0.5

var base_background_texture = preload("res://assets/map/background.png")

# Preload textures to ensure they are included in exports
const BACKGROUND_TEXTURES: Array[Texture2D] = [
	preload("res://assets/map/fetzen/1.png"),
	preload("res://assets/map/fetzen/2.png")
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

	if not base_background_texture:
		# fallback to something generated if texture missing, but for now just return
		return

	# Calculate scale for background base
	var bg_h = base_background_texture.get_height()
	var bg_w = base_background_texture.get_width()
	var bg_scale = 1.0
	if bg_h > 0:
		bg_scale = _background_height / bg_h
	
	_background_width = bg_w * bg_scale

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
			_spawn_background_chunk(tile_x)

func _generate_background_until(end_x: float) -> void:
	if _background_textures.size() == 0:
		return

	var x: float = max(_last_generated_x, 0.0)
	while x < end_x:
		var chunk_w = _spawn_background_chunk(x)
		if chunk_w <= 0.0:
			chunk_w = 1.0
		x += chunk_w

	_last_generated_x = x

func _spawn_background_chunk(x: float) -> float:
	if not parallax_layer or not base_background_texture:
		return 0.0

	# 1. Spawn Base Background
	var sprite := Sprite2D.new()
	sprite.texture = base_background_texture
	sprite.z_index = -20
	
	var bg_h = base_background_texture.get_height()
	var bg_scale = 1.0
	if bg_h > 0:
		bg_scale = _background_height / bg_h
	
	sprite.scale = Vector2(bg_scale, bg_scale)
	
	# Center Y
	var center_y = (GameManager.PLAYABLE_HEIGHT_BOTTOM + GameManager.PLAYABLE_HEIGHT_TOP) / 2.0
	# X must be adjusted because sprite is centered by default. 
	# We want left edge at 'x', so center is x + width/2
	var chunk_width = base_background_texture.get_width() * bg_scale
	sprite.position = Vector2(x + chunk_width / 2.0, center_y)
	
	parallax_layer.add_child(sprite)
	_background_tiles.append(sprite)
	
	# 2. Spawn Decorations (Fetzen & Muster) using Grid/Cell approach
	# This ensures better distribution and less overlapping
	
	var cell_size = 500.0
	var num_cols = ceil(chunk_width / cell_size)
	# Playable Height is from PLAYABLE_HEIGHT_TOP (negative, -1755) to PLAYABLE_HEIGHT_BOTTOM (0)
	# So height is abs(TOP - BOTTOM) which is _background_height
	var num_rows = ceil(_background_height / cell_size)
	
	# Start Y at TOP (which is the lowest value, e.g. -1755)
	var start_y = GameManager.PLAYABLE_HEIGHT_TOP
	
	for col in range(num_cols):
		for row in range(num_rows):
			if _rng.randf() > pattern_chance:
				continue
				
			var cell_x = x + (col * cell_size)
			var cell_y = start_y + (row * cell_size)
			
			var dec_sprite = Sprite2D.new()
			var use_fetzen = _rng.randf() > 0.5 # 50/50 split
			var tex: Texture2D = null
			
			if use_fetzen and _background_textures.size() > 0:
				tex = _background_textures[_rng.randi() % _background_textures.size()]
				dec_sprite.z_index = -10
			elif _pattern_textures.size() > 0:
				tex = _pattern_textures[_rng.randi() % _pattern_textures.size()]
				dec_sprite.z_index = -5
				
			if tex:
				dec_sprite.texture = tex
				
				# Position randomly WITHIN the cell
				# Add padding so it doesn't clip too weirdly (optional)
				var padding = 20.0
				var offset_x = _rng.randf_range(padding, cell_size - padding)
				var offset_y = _rng.randf_range(padding, cell_size - padding)
				
				# Ensure x doesn't go beyond chunk (though x+chunk_width is fine for background)
				# cell_x is local to world, but aligned with grid
				var final_x = cell_x + offset_x
				var final_y = cell_y + offset_y
				
				# Safety check for Y bounds if needed, but grid should cover it roughly
				
				dec_sprite.position = Vector2(final_x, final_y)
				
				# Decoration Scale - random slightly?
				var s = 1.0
				if use_fetzen:
					s = _rng.randf_range(0.5, 1.5)
				else:
					s = _rng.randf_range(0.8, 1.2)
				
				dec_sprite.scale = Vector2(s, s)
				dec_sprite.rotation = _rng.randf_range(-0.1, 0.1)
				
				parallax_layer.add_child(dec_sprite)
				_pattern_nodes.append(dec_sprite)

	return chunk_width

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
