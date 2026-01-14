extends Node2D

@export var follow_x: bool = true
@export var follow_y: bool = false
@export var only_forward: bool = false
@export var offset: Vector2 = Vector2.ZERO

var _player: Node2D = null

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")

func _physics_process(_delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
		return
	
	if follow_x:
		var target_x = _player.global_position.x + offset.x
		if only_forward:
			global_position.x = max(global_position.x, target_x)
		else:
			global_position.x = target_x
			
	if follow_y:
		var target_y = _player.global_position.y + offset.y
		if only_forward:
			global_position.y = max(global_position.y, target_y)
		else:
			global_position.y = target_y
