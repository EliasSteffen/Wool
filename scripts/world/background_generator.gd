extends Node2D

## Background Generator
##
## Generates infinite background tiles that repeat horizontally
## Background spans from y=0 to y=-1755

@export var background_folder: String = "res://assets/map/fetzen"
@export var pattern_folder: String = "res://assets/map/muster"
@export var pattern_chance: float = 0.25
@export var max_patterns_per_tile: int = 5
@export var parallax_factor_x: float = 0.5
@export var decoration_parallax_factor_x: float = 0.7 # Slightly faster than background

var base_background_texture = preload("res://assets/map/background.png")

# Preload textures to ensure they are included in exports
const BACKGROUND_TEXTURES: Array[Texture2D] = [
	preload("res://assets/map/background.png"),
	preload("res://assets/map/fetzen/1.png"),
	preload("res://assets/map/fetzen/2.png")
]
const PATTERN_TEXTURES: Array[Texture2D] = [

]

@onready var parallax_layer: ParallaxLayer = get_node_or_null("../ParallaxBackground/ParallaxLayer")
var decoration_layer: ParallaxLayer = null

var _player: BasePlayer = null
var _camera_width: float = 0.0

var _last_bg_x: float = 0.0
var _last_deco_x: float = 0.0

var _background_tiles: Array[Sprite2D] = [] # Base background tiles
# We track decoration nodes separately if needed, or just keep them in a list for cleanup
var _decoration_nodes: Array[Sprite2D] = []

var _background_width: float = 0.0  # Width of a single background tile
var _background_height: float = abs(GameManager.PLAYABLE_HEIGHT_TOP - GameManager.PLAYABLE_HEIGHT_BOTTOM)

# Runtime-loaded pattern textures and pattern nodes
var _pattern_textures: Array[Texture2D] = []

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
	# remove background.png from random textures if added there by mistake
	
	_pattern_textures = PATTERN_TEXTURES.duplicate()

	# Randomize RNG for tile selection and pattern placement
	_rng.randomize()

	if not base_background_texture:
		return

	# Calculate scale for background base
	var bg_h = base_background_texture.get_height()
	var bg_w = base_background_texture.get_width()
	var bg_scale = 1.0
	if bg_h > 0:
		bg_scale = _background_height / bg_h
	
	_background_width = bg_w * bg_scale

	# Setup Parallax Layers
	if parallax_layer:
		# Base Layer configuration
		parallax_layer.motion_scale = Vector2(parallax_factor_x, 1.0)
		
		# Create Decoration Layer
		decoration_layer = ParallaxLayer.new()
		decoration_layer.name = "DecorationLayer"
		decoration_layer.motion_scale = Vector2(decoration_parallax_factor_x, 1.0)
		parallax_layer.get_parent().add_child(decoration_layer)
		# Ensure it's rendered in correct order.
		# Base bg is z -20, decorations -10/-5.
		
		# Initial generation
		var bg_gen_end: float = 2.0 * _camera_width
		_generate_bg_until(bg_gen_end)
		
		# Decor generation (needs its own coordination system)
		_generate_deco_until(bg_gen_end)

func _process(delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
	if not _player or not _player.camera:
		return

	if not parallax_layer or not decoration_layer:
		# Re-acquire logic if lost? Usually not needed if setup in _ready
		return

	if _background_width <= 0:
		return

	var camera = _player.camera
	var visible_half_width = (_camera_width / 2.0) / camera.zoom.x
	
	# --- Base Background Generation ---
	var bg_layer_center_x = camera.global_position.x * parallax_factor_x
	var bg_layer_right = bg_layer_center_x + visible_half_width
	var bg_gen_end = bg_layer_right + _camera_width
	
	_generate_bg_until(bg_gen_end)
	_cleanup_bg(bg_layer_center_x - visible_half_width - _background_width)

	# --- Decoration Generation ---
	var deco_layer_center_x = camera.global_position.x * decoration_parallax_factor_x
	var deco_layer_right = deco_layer_center_x + visible_half_width
	var deco_gen_end = deco_layer_right + _camera_width
	
	_generate_deco_until(deco_gen_end)
	_cleanup_deco(deco_layer_center_x - visible_half_width - 500.0) # 500 buffer

func _generate_bg_until(end_x: float) -> void:
	var x: float = max(_last_bg_x, 0.0)
	while x < end_x:
		var chunk_w = _spawn_base_chunk(x)
		if chunk_w <= 0.0:
			chunk_w = 1.0
		x += chunk_w
	_last_bg_x = x

func _generate_deco_until(end_x: float) -> void:
	var x: float = max(_last_deco_x, 0.0)
	# Decorations are spawned in 250 width chunks (grid columns)
	# We can just increment by cell_size
	var cell_size = 250.0
	
	while x < end_x:
		_spawn_deco_chunk(x, cell_size)
		x += cell_size
	_last_deco_x = x

func _spawn_base_chunk(x: float) -> float:
	if not parallax_layer or not base_background_texture:
		return 0.0

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
	var chunk_width = base_background_texture.get_width() * bg_scale
	sprite.position = Vector2(x + chunk_width / 2.0, center_y)
	
	parallax_layer.add_child(sprite)
	_background_tiles.append(sprite)
	
	return chunk_width

func _spawn_deco_chunk(x: float, width: float) -> void:
	if not decoration_layer:
		return
		
	var cell_size = 250.0
	# We assume 'width' is effectively one column width, but let's stick to the grid logic
	# Playable Height logic
	var num_rows = ceil(_background_height / cell_size)
	var start_y = GameManager.PLAYABLE_HEIGHT_TOP
	
	for row in range(num_rows):
		if _rng.randf() > pattern_chance:
			continue
			
		var cell_y = start_y + (row * cell_size)
		
		var dec_sprite = Sprite2D.new()
		var use_fetzen = _rng.randf() > 0.5
		var tex: Texture2D = null
		
		if use_fetzen and _background_textures.size() > 0:
			# Filter out the base background if it's in the list
			var attempts = 0
			while attempts < 10:
				tex = _background_textures[_rng.randi() % _background_textures.size()]
				if tex != base_background_texture:
					break
				attempts += 1
			dec_sprite.z_index = -10
		elif _pattern_textures.size() > 0:
			tex = _pattern_textures[_rng.randi() % _pattern_textures.size()]
			dec_sprite.z_index = -5
			
		if tex:
			dec_sprite.texture = tex
			
			var padding = 20.0
			var offset_x = _rng.randf_range(padding, cell_size - padding)
			var offset_y = _rng.randf_range(padding, cell_size - padding)
			
			var final_x = x + offset_x
			var final_y = cell_y + offset_y
			
			dec_sprite.position = Vector2(final_x, final_y)
			
			var s = 1.0
			if use_fetzen:
				s = _rng.randf_range(0.2, 0.6)
			else:
				s = _rng.randf_range(0.4, 0.8)
			
			dec_sprite.scale = Vector2(s, s)
			dec_sprite.rotation = _rng.randf_range(-0.1, 0.1)
			
			decoration_layer.add_child(dec_sprite)
			_decoration_nodes.append(dec_sprite)

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

func _cleanup_bg(cleanup_x: float) -> void:
	var tiles_to_remove: Array[Sprite2D] = []
	for tile in _background_tiles:
		if not is_instance_valid(tile):
			tiles_to_remove.append(tile)
			continue
		if tile.position.x < cleanup_x:
			tiles_to_remove.append(tile)
			
	for tile in tiles_to_remove:
		_background_tiles.erase(tile)
		if is_instance_valid(tile):
			tile.queue_free()

func _cleanup_deco(cleanup_x: float) -> void:
	var nodes_to_remove: Array[Sprite2D] = []
	for node in _decoration_nodes:
		if not is_instance_valid(node):
			nodes_to_remove.append(node)
			continue
		if node.position.x < cleanup_x:
			nodes_to_remove.append(node)
			
	for node in nodes_to_remove:
		_decoration_nodes.erase(node)
		if is_instance_valid(node):
			node.queue_free()
