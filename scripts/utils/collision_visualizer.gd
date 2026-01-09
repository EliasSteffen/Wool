@tool
class_name CollisionVisualizer
extends Node2D

## Farbe für die sichtbaren Shapes
@export var debug_color: Color = Color(0.8, 0.8, 0.8, 0.5):
	set(value):
		debug_color = value
		if is_inside_tree():
			_update_visuals()

func _ready() -> void:
	# Warten bis Scene Tree fertig ist, um auf Parents/Siblings zuzugreifen
	if not Engine.is_editor_hint():
		await get_tree().process_frame
	_update_visuals()

func _enter_tree() -> void:
	_update_visuals()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_update_visuals()

func _update_visuals() -> void:
	# Alte Visualisierungen entfernen
	for child in get_children():
		if child is Polygon2D:
			child.queue_free()

	# Ziele finden: Erst eigene Kinder prüfen
	var targets: Array[Node] = []
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			targets.append(child)

	# Falls keine Kinder da, schaue beim Elternknoten (Geschwister)
	if targets.is_empty() and get_parent():
		for child in get_parent().get_children():
			if child == self: continue
			if child is CollisionShape2D or child is CollisionPolygon2D:
				targets.append(child)

	# Visuals erstellen
	for node in targets:
		if node is CollisionShape2D:
			_create_visual(node)
		elif node is CollisionPolygon2D:
			_create_polygon_visual(node)

func _create_visual(shape_node: CollisionShape2D) -> void:
	if not shape_node.shape:
		return

	var polygon := Polygon2D.new()
	polygon.color = debug_color

	# Rechtecke unterstützen
	if shape_node.shape is RectangleShape2D:
		var rect: RectangleShape2D = shape_node.shape
		var size := rect.size
		polygon.polygon = PackedVector2Array([
			Vector2(-size.x/2, -size.y/2),
			Vector2(size.x/2, -size.y/2),
			Vector2(size.x/2, size.y/2),
			Vector2(-size.x/2, size.y/2)
		])
	# Kreise unterstützen
	elif shape_node.shape is CircleShape2D:
		var circle: CircleShape2D = shape_node.shape
		var radius := circle.radius
		var points := PackedVector2Array()
		var steps := 32
		for i in range(steps):
			var angle = i * TAU / steps
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		polygon.polygon = points
	# Kapseln unterstützen
	elif shape_node.shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape_node.shape
		var r := capsule.radius
		var h := capsule.height
		# Kapsel als Rechteck annähern
		polygon.polygon = PackedVector2Array([
			Vector2(-r, -h/2), Vector2(r, -h/2),
			Vector2(r, h/2), Vector2(-r, h/2)
		])

	# Transformation korrekt berechnen (Relativ zu diesem Visualizer)
	polygon.transform = global_transform.affine_inverse() * shape_node.global_transform
	add_child(polygon)

func _create_polygon_visual(poly_node: CollisionPolygon2D) -> void:
	var polygon := Polygon2D.new()
	polygon.color = debug_color
	polygon.polygon = poly_node.polygon
	polygon.transform = global_transform.affine_inverse() * poly_node.global_transform
	add_child(polygon)
