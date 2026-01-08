class_name Eagle
extends BaseEnemy

var _glide_feature: GlideFeature

func _ready() -> void:
	super._ready()
	# Find glide feature
	_glide_feature = get_feature_by_type(GlideFeature)

	# Override jump velocity for eagle if needed (e.g. higher jumps)
	# jump_velocity = -600.0

func _process_ai(delta: float) -> void:
	super._process_ai(delta)

	# AI Logic for Gliding
	if _glide_feature:
		var should_glide: bool = false

		# 1. Always glide if in Upwind to gain height
		if get_active_terrain_of_type(UpwindTerrain) != null:
			# Raycast upwards to detect ceiling and maintain distance
			var space_state = get_world_2d().direct_space_state
			# Check 200px above. Use own collision mask to detect what blocks us.
			var query = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2.UP * 250, collision_mask)
			var result = space_state.intersect_ray(query)

			if result:
				# Ceiling detected
				var dist = global_position.distance_to(result.position)
				if dist < 150.0:
					# Too close to ceiling, stop gliding to drop
					should_glide = false
				else:
					# Safe distance, glide up
					should_glide = true
			else:
				# No ceiling nearby, check bounds
				if is_on_ceiling():
					should_glide = false
				else:
					should_glide = true

		# 2. Also glide if falling and we want to stay airborne (basic eagle behavior)
		elif velocity.y > 0 and not is_on_floor():
			should_glide = true

		if should_glide:
			_glide_feature.start_gliding()
		else:
			_glide_feature.stop_gliding()

