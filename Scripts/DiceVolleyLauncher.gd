class_name DiceVolleyLauncher
extends Node
## Orchestrates dealer's sweeping volley throws and reroll launches.
## Child of DiceArena — holds a reference to the arena for die management.

const PhysicsDieScene: PackedScene = preload("res://Scenes/PhysicsDie.tscn")

var _arena: DiceArena
var reroll_burst_rotation: float = 0.0


func setup(arena: DiceArena) -> void:
	_arena = arena


# ---------------------------------------------------------------------------
# Opening volley — launch dice one at a time from emitter
# ---------------------------------------------------------------------------

func start_volley() -> void:
	_arena._settle_check_active = true
	var total: int = _arena._pending_pool.size()
	var cumulative_delay: float = 0.0
	for i: int in total:
		if i == 0:
			volley_launch(0)
		else:
			var progress: float = float(i) / float(maxi(total - 1, 1))
			var base_delay: float = lerpf(DiceArena.VOLLEY_DELAY_START, DiceArena.VOLLEY_DELAY_END, progress)
			cumulative_delay += base_delay + randf_range(0.0, DiceArena.VOLLEY_DELAY_JITTER)
			var captured_index: int = i
			get_tree().create_timer(cumulative_delay).timeout.connect(
				volley_launch.bind(captured_index)
			)


## Instantiate and launch a single die as part of the volley.
func volley_launch(index: int) -> void:
	if index < 0 or index >= _arena._pending_pool.size():
		return
	var data: DiceData = _arena._pending_pool[index]
	var die: PhysicsDie = PhysicsDieScene.instantiate() as PhysicsDie
	_arena.add_child(die)
	die.setup(index, data)
	_arena._apply_popup_bounds_to_die(die)
	_arena._dice.append(die)
	die.toggled_keep.connect(_arena._on_die_toggled)
	die.shift_toggled_keep.connect(_arena._on_die_shift_toggled)
	die.collision_rerolled.connect(_arena._on_die_collision_rerolled)

	# Position at emitter with jitter.
	var emitter: Vector2 = volley_emitter()
	die.position = emitter + Vector2(
		randf_range(-DiceArena.VOLLEY_EMITTER_JITTER_X, DiceArena.VOLLEY_EMITTER_JITTER_X),
		randf_range(-DiceArena.VOLLEY_EMITTER_JITTER_Y, DiceArena.VOLLEY_EMITTER_JITTER_Y))

	# Roll and set face.
	var face: DiceFaceData = data.roll()
	die.current_face = face
	die.tumble(face)
	die.play_launch_burst()

	var total: int = _arena._pending_pool.size()
	var target: Vector2 = burst_target_position(index, total, false)
	var direction: Vector2 = (target - emitter).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT.rotated(randf() * TAU)
	var travel_ratio: float = clampf(emitter.distance_to(target) / DiceArena.BURST_TARGET_RADIUS_X, DiceArena.BURST_TARGET_MIN_RING, 1.0)
	var magnitude: float = randf_range(DiceArena.THROW_IMPULSE_MIN, DiceArena.THROW_IMPULSE_MAX) * lerpf(0.92, 1.14, travel_ratio)
	die.linear_velocity = direction * magnitude
	die.angular_velocity = randf_range(DiceArena.THROW_ANGULAR_MIN, DiceArena.THROW_ANGULAR_MAX)
	SFXManager.play_roll()


## Emitter position for the volley: lower center of the arena.
func volley_emitter() -> Vector2:
	return Vector2(DiceArena.ARENA_WIDTH * 0.5, DiceArena.ARENA_HEIGHT * DiceArena.VOLLEY_EMITTER_HEIGHT_RATIO)


# ---------------------------------------------------------------------------
# Reroll launch sequence
# ---------------------------------------------------------------------------

func execute_reroll(indices: Array[int], pool: Array[DiceData]) -> void:
	var valid_indices: Array[int] = []
	for i: int in indices:
		if i >= 0 and i < _arena._dice.size():
			valid_indices.append(i)

	if valid_indices.is_empty():
		return

	var total: int = valid_indices.size()
	reroll_burst_rotation = randf() * TAU

	for slot: int in total:
		var i: int = valid_indices[slot]
		var die: PhysicsDie = _arena._dice[i]
		die.is_stopped = false
		die.is_kept = false
		die._bump_count = 0
		die._wall_bounce_count = 0

		# Roll new face.
		var face: DiceFaceData = pool[i].roll()
		die.current_face = face
		die._apply_visual()

		if _arena.instant_mode:
			die.collision_layer = 1
			die.collision_mask = 1
			die.scale = Vector2.ONE
			die.modulate = Color.WHITE
			die.show_face(face)
			die.freeze = true
			die.physics_state = PhysicsDie.DiePhysicsState.SETTLED
		else:
			# Schedule sweep launch for this die.
			var captured_slot: int = slot
			var captured_die: PhysicsDie = die
			var captured_face: DiceFaceData = face
			var captured_total: int = total
			if slot == 0:
				begin_reroll_launch_sequence(captured_die, captured_face, captured_slot, captured_total)
			else:
				var cumulative: float = reroll_cumulative_delay(slot, total) + randf_range(0.0, DiceArena.REROLL_VOLLEY_DELAY_JITTER)
				get_tree().create_timer(cumulative).timeout.connect(
					begin_reroll_launch_sequence.bind(captured_die, captured_face, captured_slot, captured_total)
				)

	if _arena.instant_mode:
		_arena.all_dice_settled.emit()
	else:
		_arena._settle_check_active = true


func begin_reroll_launch_sequence(die: PhysicsDie, face: DiceFaceData, slot: int, total: int) -> void:
	if not is_instance_valid(die):
		return
	# Restore visibility — die was invisible from exit animation.
	die.collision_layer = 1
	die.collision_mask = 1
	die.scale = Vector2.ONE
	die.modulate = Color.WHITE
	die.physics_state = PhysicsDie.DiePhysicsState.RESOLVING
	die.freeze = true
	die.linear_velocity = Vector2.ZERO
	die.angular_velocity = 0.0
	reroll_volley_launch(die, face, slot, total)


## Launch a single rerolled die using the sweep volley pattern.
func reroll_volley_launch(die: PhysicsDie, face: DiceFaceData, slot: int, total: int) -> void:
	if not is_instance_valid(die):
		return

	var emitter: Vector2 = reroll_emitter_position(slot, total)
	die.position = emitter

	die.physics_state = PhysicsDie.DiePhysicsState.FLYING
	die.freeze = false
	die._settle_timer = 0.0
	die.tumble(face)
	die.play_launch_burst()

	var target: Vector2 = reroll_target_position(slot, total)
	var direction: Vector2 = (target - emitter).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT.rotated(randf() * TAU)
	var travel_ratio: float = clampf(emitter.distance_to(target) / DiceArena.REROLL_BURST_TARGET_RADIUS_X, DiceArena.BURST_TARGET_MIN_RING, 1.0)
	var magnitude: float = randf_range(DiceArena.REROLL_THROW_IMPULSE_MIN, DiceArena.REROLL_THROW_IMPULSE_MAX) * lerpf(0.92, 1.08, travel_ratio)
	magnitude = clampf(magnitude, DiceArena.REROLL_THROW_IMPULSE_MIN, DiceArena.REROLL_THROW_IMPULSE_MAX)
	die.linear_velocity = direction * magnitude
	die.angular_velocity = randf_range(DiceArena.THROW_ANGULAR_MIN * 0.8, DiceArena.THROW_ANGULAR_MAX * 0.8)
	SFXManager.play_roll()


# ---------------------------------------------------------------------------
# Target / emitter position math
# ---------------------------------------------------------------------------

func burst_target_position(index: int, total: int, is_reroll: bool) -> Vector2:
	var safe_total: int = maxi(total, 1)
	var burst_center: Vector2 = Vector2(DiceArena.ARENA_WIDTH * 0.5, DiceArena.ARENA_HEIGHT * DiceArena.REROLL_VOLLEY_TARGET_HEIGHT_RATIO)
	var radius_x: float = DiceArena.REROLL_BURST_TARGET_RADIUS_X if is_reroll else DiceArena.BURST_TARGET_RADIUS_X
	var radius_y: float = DiceArena.REROLL_BURST_TARGET_RADIUS_Y if is_reroll else DiceArena.BURST_TARGET_RADIUS_Y
	var jitter_x: float = DiceArena.REROLL_BURST_TARGET_JITTER_X if is_reroll else DiceArena.BURST_TARGET_JITTER_X
	var jitter_y: float = DiceArena.REROLL_BURST_TARGET_JITTER_Y if is_reroll else DiceArena.BURST_TARGET_JITTER_Y
	var ring_ratio: float = 1.0
	var angle: float = 0.0
	if not is_reroll and total >= DiceArena.LARGE_POOL_BURST_THRESHOLD:
		var sector_size: float = TAU / float(safe_total)
		ring_ratio = randf_range(DiceArena.LARGE_POOL_BURST_MIN_RING, 1.0)
		angle = float(index) * sector_size + randf_range(-sector_size * DiceArena.LARGE_POOL_BURST_ANGLE_JITTER, sector_size * DiceArena.LARGE_POOL_BURST_ANGLE_JITTER)
		jitter_x *= DiceArena.LARGE_POOL_BURST_JITTER_SCALE
		jitter_y *= DiceArena.LARGE_POOL_BURST_JITTER_SCALE
	else:
		var spiral_progress: float = sqrt((float(index) + 0.5) / float(safe_total))
		ring_ratio = lerpf(DiceArena.BURST_TARGET_MIN_RING, 1.0, spiral_progress)
		angle = DiceArena.GOLDEN_ANGLE * float(index) + randf_range(-DiceArena.VOLLEY_CONE_JITTER, DiceArena.VOLLEY_CONE_JITTER)
	var offset := Vector2(cos(angle) * radius_x * ring_ratio, sin(angle) * radius_y * ring_ratio)
	offset.x += randf_range(-jitter_x, jitter_x)
	offset.y += randf_range(-jitter_y, jitter_y)
	var min_x: float = DiceArena.WALL_THICKNESS + PhysicsDie.COLLISION_RADIUS + DiceArena.SPAWN_EDGE_PADDING
	var max_x: float = DiceArena.ARENA_WIDTH - DiceArena.WALL_THICKNESS - PhysicsDie.COLLISION_RADIUS - DiceArena.SPAWN_EDGE_PADDING
	var min_y: float = DiceArena.WALL_THICKNESS + PhysicsDie.COLLISION_RADIUS + DiceArena.SPAWN_EDGE_PADDING
	var max_y: float = DiceArena.ARENA_HEIGHT - DiceArena.WALL_THICKNESS - PhysicsDie.COLLISION_RADIUS - DiceArena.SPAWN_EDGE_PADDING
	return Vector2(
		clampf(burst_center.x + offset.x, min_x, max_x),
		clampf(burst_center.y + offset.y, min_y, max_y)
	)


func reroll_emitter_position(slot: int, _total: int) -> Vector2:
	var base: Vector2 = volley_emitter()
	return base + Vector2(
		slot * DiceArena.REROLL_VOLLEY_EMITTER_SWEEP_X + randf_range(-DiceArena.REROLL_VOLLEY_EMITTER_JITTER_X, DiceArena.REROLL_VOLLEY_EMITTER_JITTER_X),
		randf_range(-DiceArena.REROLL_VOLLEY_EMITTER_JITTER_Y, DiceArena.REROLL_VOLLEY_EMITTER_JITTER_Y)
	)


func reroll_target_position(slot: int, total: int) -> Vector2:
	var safe_total: int = maxi(total, 1)
	var sector_size: float = TAU / float(safe_total)
	var ring_ratio: float = randf_range(0.45, 1.0)
	var angle: float = reroll_burst_rotation + float(slot) * sector_size + randf_range(-sector_size * 0.38, sector_size * 0.38)
	var burst_center: Vector2 = Vector2(DiceArena.ARENA_WIDTH * 0.5, DiceArena.ARENA_HEIGHT * DiceArena.REROLL_VOLLEY_TARGET_HEIGHT_RATIO)
	var offset := Vector2(
		cos(angle) * DiceArena.REROLL_BURST_TARGET_RADIUS_X * ring_ratio,
		sin(angle) * DiceArena.REROLL_BURST_TARGET_RADIUS_Y * ring_ratio
	)
	offset.x += randf_range(-DiceArena.REROLL_BURST_TARGET_JITTER_X, DiceArena.REROLL_BURST_TARGET_JITTER_X)
	offset.y += randf_range(-DiceArena.REROLL_BURST_TARGET_JITTER_Y, DiceArena.REROLL_BURST_TARGET_JITTER_Y)
	var min_x: float = DiceArena.WALL_THICKNESS + PhysicsDie.COLLISION_RADIUS + DiceArena.SPAWN_EDGE_PADDING
	var max_x: float = DiceArena.ARENA_WIDTH - DiceArena.WALL_THICKNESS - PhysicsDie.COLLISION_RADIUS - DiceArena.SPAWN_EDGE_PADDING
	var min_y: float = DiceArena.WALL_THICKNESS + PhysicsDie.COLLISION_RADIUS + DiceArena.SPAWN_EDGE_PADDING
	var max_y: float = DiceArena.ARENA_HEIGHT - DiceArena.WALL_THICKNESS - PhysicsDie.COLLISION_RADIUS - DiceArena.SPAWN_EDGE_PADDING
	return Vector2(
		clampf(burst_center.x + offset.x, min_x, max_x),
		clampf(burst_center.y + offset.y, min_y, max_y)
	)


func animate_reroll_exit(die: PhysicsDie) -> void:
	var start_position: Vector2 = die.position
	die.collision_layer = 0
	die.collision_mask = 0
	die.freeze = true
	die.physics_state = PhysicsDie.DiePhysicsState.RESOLVING
	die.linear_velocity = Vector2.ZERO
	die.angular_velocity = 0.0
	var tween: Tween = _arena.create_tween().set_parallel(true)
	tween.tween_property(die, "position", start_position + Vector2(0.0, -DiceArena.REROLL_EXIT_LIFT_Y), DiceArena.REROLL_EXIT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(die, "scale", Vector2(0.18, 0.18), DiceArena.REROLL_EXIT_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(die, "modulate:a", 0.0, DiceArena.REROLL_EXIT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# ---------------------------------------------------------------------------
# Delay math (public — used by tests and _execute_reroll)
# ---------------------------------------------------------------------------

## Compute cumulative volley delay for a given die index.
func volley_cumulative_delay(index: int, total: int) -> float:
	var cumulative: float = 0.0
	for i: int in range(1, index + 1):
		var progress: float = float(i) / float(maxi(total - 1, 1))
		cumulative += lerpf(DiceArena.VOLLEY_DELAY_START, DiceArena.VOLLEY_DELAY_END, progress)
	return cumulative


func reroll_cumulative_delay(index: int, total: int) -> float:
	var cumulative: float = 0.0
	for i: int in range(1, index + 1):
		var progress: float = float(i) / float(maxi(total - 1, 1))
		cumulative += lerpf(DiceArena.REROLL_VOLLEY_DELAY_START, DiceArena.REROLL_VOLLEY_DELAY_END, progress)
	return cumulative


# ---------------------------------------------------------------------------
# Spawn position calculations
# ---------------------------------------------------------------------------

func build_spawn_positions(origin: DiceArena.SpawnOrigin, count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if count <= 0:
		return positions

	var radius: float = PhysicsDie.COLLISION_RADIUS
	var min_x: float = DiceArena.WALL_THICKNESS + radius + DiceArena.SPAWN_EDGE_PADDING
	var max_x: float = DiceArena.ARENA_WIDTH - DiceArena.WALL_THICKNESS - radius - DiceArena.SPAWN_EDGE_PADDING
	var min_y: float = DiceArena.WALL_THICKNESS + radius + DiceArena.SPAWN_EDGE_PADDING
	var max_y: float = DiceArena.ARENA_HEIGHT - DiceArena.WALL_THICKNESS - radius - DiceArena.SPAWN_EDGE_PADDING
	var usable_width: float = maxf(0.0, max_x - min_x)
	var spacing: float = maxf(radius * DiceArena.SPAWN_SPACING_MULT, 1.0)
	var max_per_row: int = maxi(1, int(floor(usable_width / spacing)) + 1)
	var row_count: int = maxi(1, int(ceil(float(count) / float(max_per_row))))
	var row_spacing: float = radius * DiceArena.SPAWN_ROW_SPACING_MULT
	var max_row_size: int = mini(count, max_per_row)
	var anchor: Vector2 = _spawn_layout_anchor(
		origin,
		count,
		row_count,
		max_row_size,
		spacing,
		row_spacing,
		min_x,
		max_x,
		min_y,
		max_y
	)

	var remaining: int = count
	for row_index: int in row_count:
		var rows_left: int = row_count - row_index
		var in_row: int = int(ceil(float(remaining) / float(rows_left)))
		remaining -= in_row
		var total_span: float = float(maxi(0, in_row - 1)) * spacing
		var start_x: float = clampf(anchor.x - total_span * 0.5, min_x, max_x - total_span)
		var row_y: float = clampf(anchor.y - row_index * row_spacing, min_y, max_y)
		for col: int in in_row:
			var x: float = clampf(start_x + float(col) * spacing, min_x, max_x)
			var y: float = clampf(row_y, min_y, max_y)
			positions.append(Vector2(x, y))

	return positions


func spawn_position_for_origin(origin: DiceArena.SpawnOrigin) -> Vector2:
	var margin: float = DiceArena.SPAWN_MARGIN
	var cx: float = DiceArena.ARENA_WIDTH / 2.0
	var cy: float = DiceArena.ARENA_HEIGHT / 2.0
	match origin:
		DiceArena.SpawnOrigin.CENTER_BOTTOM:
			return Vector2(cx, DiceArena.ARENA_HEIGHT - margin - DiceArena.BOTTOM_SPAWN_LIFT)
		DiceArena.SpawnOrigin.CENTER_TOP:
			return Vector2(cx, margin)
		DiceArena.SpawnOrigin.TOP_LEFT:
			return Vector2(margin, margin)
		DiceArena.SpawnOrigin.TOP_RIGHT:
			return Vector2(DiceArena.ARENA_WIDTH - margin, margin)
		DiceArena.SpawnOrigin.BOTTOM_LEFT:
			return Vector2(margin, DiceArena.ARENA_HEIGHT - margin - DiceArena.BOTTOM_SPAWN_LIFT)
		DiceArena.SpawnOrigin.BOTTOM_RIGHT:
			return Vector2(DiceArena.ARENA_WIDTH - margin, DiceArena.ARENA_HEIGHT - margin - DiceArena.BOTTOM_SPAWN_LIFT)
		DiceArena.SpawnOrigin.LEFT:
			return Vector2(margin, cy)
		DiceArena.SpawnOrigin.RIGHT:
			return Vector2(DiceArena.ARENA_WIDTH - margin, cy)
		DiceArena.SpawnOrigin.TOP:
			return Vector2(cx, margin)
	return Vector2(cx, DiceArena.ARENA_HEIGHT - margin - DiceArena.BOTTOM_SPAWN_LIFT)


func _spawn_layout_anchor(
	origin: DiceArena.SpawnOrigin,
	count: int,
	row_count: int,
	max_row_size: int,
	spacing: float,
	row_spacing: float,
	min_x: float,
	max_x: float,
	min_y: float,
	max_y: float
) -> Vector2:
	var anchor: Vector2 = spawn_position_for_origin(origin)
	var centered_x: float = (min_x + max_x) * 0.5
	var max_row_span: float = float(maxi(0, max_row_size - 1)) * spacing
	var left_bound: float = min_x + max_row_span * 0.5
	var right_bound: float = max_x - max_row_span * 0.5
	var jitter_scale: float = clampf(
		1.0 - float(maxi(count - 1, 0)) / float(maxi(DiceArena.LARGE_POOL_CENTERING_THRESHOLD - 1, 1)),
		0.0,
		1.0
	)
	if count >= DiceArena.LARGE_POOL_CENTERING_THRESHOLD:
		anchor.x = centered_x
	else:
		anchor.x = clampf(anchor.x + randf_range(-DiceArena.SPAWN_LAYOUT_JITTER_X, DiceArena.SPAWN_LAYOUT_JITTER_X) * jitter_scale, left_bound, right_bound)
	var top_row_y: float = min_y + float(maxi(row_count - 1, 0)) * row_spacing
	anchor.y = clampf(anchor.y + randf_range(-DiceArena.SPAWN_LAYOUT_JITTER_Y, DiceArena.SPAWN_LAYOUT_JITTER_Y) * jitter_scale, top_row_y, max_y)
	return anchor


func throw_target_for_origin(origin: DiceArena.SpawnOrigin) -> Vector2:
	var cx: float = DiceArena.ARENA_WIDTH / 2.0
	var cy: float = DiceArena.ARENA_HEIGHT / 2.0
	var jitter_x: float = randf_range(-100.0, 100.0)
	var jitter_y: float = randf_range(-60.0, 60.0)
	match origin:
		DiceArena.SpawnOrigin.CENTER_BOTTOM:
			return Vector2(cx + jitter_x, cy * 0.4 + jitter_y)
		DiceArena.SpawnOrigin.CENTER_TOP:
			return Vector2(cx + jitter_x, cy * 1.6 + jitter_y)
		DiceArena.SpawnOrigin.TOP_LEFT:
			return Vector2(cx * 1.4 + jitter_x, cy * 1.4 + jitter_y)
		DiceArena.SpawnOrigin.TOP_RIGHT:
			return Vector2(cx * 0.6 + jitter_x, cy * 1.4 + jitter_y)
		DiceArena.SpawnOrigin.BOTTOM_LEFT:
			return Vector2(cx * 1.4 + jitter_x, cy * 0.6 + jitter_y)
		DiceArena.SpawnOrigin.BOTTOM_RIGHT:
			return Vector2(cx * 0.6 + jitter_x, cy * 0.6 + jitter_y)
		DiceArena.SpawnOrigin.LEFT:
			return Vector2(cx * 1.4 + jitter_x, cy + jitter_y)
		DiceArena.SpawnOrigin.RIGHT:
			return Vector2(cx * 0.6 + jitter_x, cy + jitter_y)
		DiceArena.SpawnOrigin.TOP:
			return Vector2(cx + jitter_x, cy * 1.4 + jitter_y)
	return Vector2(cx + jitter_x, cy * 0.4 + jitter_y)


# ---------------------------------------------------------------------------
# Launch helpers
# ---------------------------------------------------------------------------

func launch_die(
	die: PhysicsDie,
	origin: DiceArena.SpawnOrigin = DiceArena.SpawnOrigin.CENTER_BOTTOM,
	launch_index: int = 0,
	launch_total: int = 1
) -> void:
	var stagger: float = stagger_unit(launch_index, launch_total)
	die.position += Vector2(stagger * DiceArena.THROW_STAGGER_SPAWN_SWEEP_X, 0.0)
	die.tumble(die.current_face)
	die.play_launch_burst()
	var target: Vector2 = throw_target_for_origin(origin)
	target.x += stagger * DiceArena.THROW_STAGGER_TARGET_SWEEP_X
	var direction: Vector2 = (target - die.position).normalized()
	var spread: float = randf_range(-0.4, 0.4)
	direction = direction.rotated(spread)
	var magnitude_bias: float = clampf(
		1.0 + stagger * DiceArena.THROW_STAGGER_MAGNITUDE_VARIANCE + randf_range(-0.05, 0.05),
		0.82,
		1.25
	)
	var magnitude: float = randf_range(DiceArena.THROW_IMPULSE_MIN, DiceArena.THROW_IMPULSE_MAX) * magnitude_bias
	die.apply_central_impulse(direction * magnitude)
	die.angular_velocity = randf_range(DiceArena.THROW_ANGULAR_MIN, DiceArena.THROW_ANGULAR_MAX)
	SFXManager.play_roll()


func stagger_unit(launch_index: int, launch_total: int) -> float:
	if launch_total <= 1:
		return 0.0
	var normalized: float = (float(launch_index) / float(maxi(launch_total - 1, 1))) * 2.0 - 1.0
	var wave: float = sin(float(launch_index) * 1.2) * 0.35
	return clampf(normalized * DiceArena.THROW_STAGGER_SWEEP + wave, -1.0, 1.0)
