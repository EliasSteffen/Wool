class_name Eagle
extends BaseEnemy

var _glide_feature: GlideFeature
var _flight_time: float = 0.0

func _ready() -> void:
	super._ready()
	# Find glide feature
	_glide_feature = get_feature_by_type(GlideFeature)

	# Override jump velocity for eagle if needed (e.g. higher jumps)
	# jump_velocity = -600.0

	# Randomize flight phase so multiple eagles don't bob in sync
	_flight_time = randf() * 100.0

func _process_ai(delta: float) -> void:
	super._process_ai(delta)
	_flight_time += delta

	# AI Logic for Gliding
	if _glide_feature:
		var should_glide: bool = false
		var is_gliding_now = _glide_feature.is_gliding()

# 1. Determine Desired Vertical Behavior
		var in_upwind = get_active_terrain_of_type(UpwindTerrain) != null
		var want_to_go_up = false

		# If chasing, height depends on target
		if _ai_state == AIState.CHASE and _current_target:
			var target_y = _current_target.global_position.y
			# Aim slightly above player to swoop or attack head
			var desired_y = target_y - 50.0

			if global_position.y > desired_y:
				want_to_go_up = true
			else:
				want_to_go_up = false

		# If idle/patrolling and in Upwind, use "Bobbing" logic relative to ceiling
		elif in_upwind:
			# Raycast upwards to detect ceiling and maintain distance
			var space_state = get_world_2d().direct_space_state

			# Check 400px above
			var query = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2.UP * 400, collision_mask)
			var result = space_state.intersect_ray(query)

			var ceiling_dist = 9999.0
			if result:
				ceiling_dist = global_position.distance_to(result.position)

			# Dynamic Target Distance from Ceiling
			var target_dist = 150.0 + (sin(_flight_time * 2.0) * 50.0) + 50.0
			var tolerance = 10.0

			if is_gliding_now:
				if ceiling_dist < (target_dist - tolerance):
					want_to_go_up = false
				else:
					want_to_go_up = true
			else:
				if ceiling_dist > (target_dist + tolerance):
					want_to_go_up = true
				else:
					want_to_go_up = false

		# Fallback for normal air (maintain height as best as possible if falling)
		else:
			if velocity.y > 0 and not is_on_floor():
				want_to_go_up = true

		# 2. Execute Gliding based on "Want to go Up"
		if in_upwind:
			# In upwind: Glide = Up, No Glide = Down
			should_glide = want_to_go_up

			# Ceiling Safety Override for Upwind
			if is_on_ceiling() and should_glide:
				should_glide = false

		else:
			# In normal air: Glide = Slow Fall (Closest to Up), No Glide = Fast Fall
			# We can't actually go up without jumping, but we can delay falling
			if want_to_go_up:
				should_glide = true # Try to stay up
			else:
				should_glide = false # Drop down

		if should_glide:
			_glide_feature.start_gliding()
		else:
			_glide_feature.stop_gliding()

func _execute_chase_movement(delta: float, direction: Vector2) -> void:
	# Eagle movement logic

	# 1. Horizontal Movement
	# Fly/Glide towards target horizontally
	velocity.x = move_toward(velocity.x, direction.x * chase_speed, 20.0)

	# 2. Vertical / Takeoff Logic
	# If we are on the ground and chasing, we should immediately take off to start flying/gliding
	if is_on_floor():
		jump()
