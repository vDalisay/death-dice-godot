class_name DiceArena
extends Node2D
## Physics arena for dice throwing. Contains walls, spawns PhysicsDie
## instances, monitors settling, and provides the results API.
## Lives inside a SubViewport to isolate physics from the UI layer.

const _UITheme := preload("res://Scripts/UITheme.gd")
const PhysicsDieScene: PackedScene = preload("res://Scenes/PhysicsDie.tscn")

signal all_dice_settled()
signal die_clicked(die_index: int, is_kept: bool)
signal die_shift_clicked(die_index: int, is_kept: bool)
signal die_collision_rerolled(die_index: int, new_face: DiceFaceData)

# ---------------------------------------------------------------------------
# Arena dimensions (logical pixels inside the SubViewport)
# ---------------------------------------------------------------------------

const ARENA_WIDTH: float = 1840.0
const ARENA_HEIGHT: float = 520.0
const WALL_THICKNESS: float = 20.0
const ARENA_CORNER_RADIUS: int = 12
const ARENA_BG_COLOR: Color = Color("#1a1a2e")
const ARENA_BORDER_COLOR: Color = Color("#333355")
const ARENA_BORDER_WIDTH: int = 2

# Throw parameters
const THROW_IMPULSE_MIN: float = 1400.0
const THROW_IMPULSE_MAX: float = 2400.0
const THROW_ANGULAR_MIN: float = -8.0
const THROW_ANGULAR_MAX: float = 8.0
const THROW_STAGGER_DELAY: float = 0.03
const SPAWN_MARGIN: float = 80.0
const BOTTOM_SPAWN_LIFT: float = 92.0
const CONTAINMENT_BOUNCE_DAMP: float = 0.45
const WALL_BOUNCE_DAMPEN_FACTOR: float = 0.6
const REROLL_LIFT_DELAY: float = 0.06
const REROLL_LIFT_RANDOM_MAX: float = 0.03
const THROW_STAGGER_RANDOM_MAX: float = 0.02
const THROW_STAGGER_SWEEP: float = 0.85
const THROW_STAGGER_SPAWN_SWEEP_X: float = 52.0
const THROW_STAGGER_TARGET_SWEEP_X: float = 116.0
const THROW_STAGGER_MAGNITUDE_VARIANCE: float = 0.12
const SPAWN_SPACING_MULT: float = 2.2
const SPAWN_ROW_SPACING_MULT: float = 2.1
const SPAWN_EDGE_PADDING: float = 8.0
const BOUNDARY_GLOW_HIT_GAIN: float = 0.22
const BOUNDARY_GLOW_DECAY_PER_SEC: float = 2.1
const CONTAINMENT_MIN_BOUNCE_SPEED: float = 90.0
const CONTAINMENT_INWARD_NUDGE: float = 54.0
const SOFT_SEPARATION_RADIUS_MULT: float = 1.82
const SOFT_SEPARATION_MAX_SPEED: float = 150.0
const SOFT_SEPARATION_PUSH: float = 38.0

# Dealer's sweep volley parameters
const VOLLEY_DELAY_START: float = 0.055
const VOLLEY_DELAY_END: float = 0.012
const VOLLEY_DELAY_JITTER: float = 0.008
const VOLLEY_CONE_HALF_ANGLE: float = 0.55
const VOLLEY_CONE_JITTER: float = 0.15
const VOLLEY_EMITTER_JITTER_X: float = 15.0
const VOLLEY_EMITTER_JITTER_Y: float = 8.0

## Spawn origin presets for dice throwing.
## Items can override per-die spawn origins in the future.
enum SpawnOrigin { CENTER_BOTTOM, TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT, LEFT, RIGHT, TOP, CENTER_TOP }

## Default spawn origin for all dice.
var default_spawn_origin: SpawnOrigin = SpawnOrigin.CENTER_BOTTOM

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _dice: Array[PhysicsDie] = []
var _pending_pool: Array[DiceData] = []
var _settle_check_active: bool = false
var _bg_panel: Panel = null
var _bg_style: StyleBoxFlat = null
var _boundary_glow_energy: float = 0.0
## When true, dice settle instantly (no physics). Set by tests.
var instant_mode: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_background()
	_build_walls()
	_update_centering()
	var viewport: Viewport = get_viewport()
	if viewport and not viewport.size_changed.is_connected(_update_centering):
		viewport.size_changed.connect(_update_centering)


func _physics_process(_delta: float) -> void:
	if _boundary_glow_energy > 0.0:
		_boundary_glow_energy = maxf(0.0, _boundary_glow_energy - BOUNDARY_GLOW_DECAY_PER_SEC * _delta)
	_apply_boundary_glow()
	_enforce_arena_containment()
	_apply_soft_separation()
	if not _settle_check_active:
		return
	# Check if all dice have settled
	for die: PhysicsDie in _dice:
		if die.physics_state == PhysicsDie.DiePhysicsState.FLYING:
			return
	# All settled
	_settle_check_active = false
	all_dice_settled.emit()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func throw_dice(pool: Array[DiceData]) -> void:
	_clear_dice()
	if instant_mode:
		# Instant mode: spawn all dice at once in grid and settle (used by tests).
		var spawn_positions: Array[Vector2] = _build_spawn_positions(default_spawn_origin, pool.size())
		for i: int in pool.size():
			var die: PhysicsDie = PhysicsDieScene.instantiate() as PhysicsDie
			add_child(die)
			die.setup(i, pool[i])
			_dice.append(die)
			die.toggled_keep.connect(_on_die_toggled)
			die.shift_toggled_keep.connect(_on_die_shift_toggled)
			die.collision_rerolled.connect(_on_die_collision_rerolled)
			die.position = spawn_positions[i]
			var face: DiceFaceData = pool[i].roll()
			die.current_face = face
			die.show_face(face)
			die.freeze = true
			die.physics_state = PhysicsDie.DiePhysicsState.SETTLED
		all_dice_settled.emit()
	else:
		# Dealer's sweep: store pool and launch dice one at a time.
		_pending_pool = pool.duplicate()
		_start_volley()


func reroll_dice(indices: Array[int], pool: Array[DiceData]) -> void:
	# Filter valid indices.
	var valid_indices: Array[int] = []
	for i: int in indices:
		if i >= 0 and i < _dice.size():
			valid_indices.append(i)

	if valid_indices.is_empty():
		return

	var total: int = valid_indices.size()

	for slot: int in total:
		var i: int = valid_indices[slot]
		var die: PhysicsDie = _dice[i]
		die.is_stopped = false
		die._bump_count = 0
		die._wall_bounce_count = 0

		# Roll new face.
		var face: DiceFaceData = pool[i].roll()
		die.current_face = face

		if instant_mode:
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
				_reroll_volley_launch(captured_die, captured_face, captured_slot, captured_total)
			else:
				var cumulative: float = volley_cumulative_delay(slot, total) + randf_range(0.0, VOLLEY_DELAY_JITTER)
				get_tree().create_timer(cumulative).timeout.connect(
					func() -> void: _reroll_volley_launch(captured_die, captured_face, captured_slot, captured_total)
				)

	if instant_mode:
		all_dice_settled.emit()
	else:
		_settle_check_active = true


func lock_die(index: int) -> void:
	if index >= 0 and index < _dice.size():
		_dice[index].is_keep_locked = true
		_dice[index].set_physics_state(PhysicsDie.DiePhysicsState.KEPT)


func get_results() -> Array[DiceFaceData]:
	var results: Array[DiceFaceData] = []
	for die: PhysicsDie in _dice:
		results.append(die.current_face)
	return results


func get_die_position(index: int) -> Vector2:
	if index >= 0 and index < _dice.size():
		return _dice[index].global_position
	return Vector2.ZERO


func get_dice_in_radius(center: Vector2, radius: float) -> Array[int]:
	var result: Array[int] = []
	var radius_sq: float = radius * radius
	for die: PhysicsDie in _dice:
		if die.global_position.distance_squared_to(center) <= radius_sq:
			result.append(die.die_index)
	return result


func get_dice_in_rect(rect: Rect2) -> Array[int]:
	var result: Array[int] = []
	for die: PhysicsDie in _dice:
		if rect.has_point(die.global_position):
			result.append(die.die_index)
	return result


func get_die(index: int) -> PhysicsDie:
	if index >= 0 and index < _dice.size():
		return _dice[index]
	return null


func get_die_count() -> int:
	return _dice.size()


func reset() -> void:
	_clear_dice()
	_settle_check_active = false
	_boundary_glow_energy = 0.0
	_apply_boundary_glow()


## Immediately settle all dice (skip physics). Used by tests.
func force_settle_all() -> void:
	for die: PhysicsDie in _dice:
		die.linear_velocity = Vector2.ZERO
		die.angular_velocity = 0.0
		die.freeze = true
		die.physics_state = PhysicsDie.DiePhysicsState.SETTLED
	_settle_check_active = false
	all_dice_settled.emit()


func get_arena_rect() -> Rect2:
	return Rect2(WALL_THICKNESS, WALL_THICKNESS,
		ARENA_WIDTH - WALL_THICKNESS * 2, ARENA_HEIGHT - WALL_THICKNESS * 2)


# ---------------------------------------------------------------------------
# Throw helpers
# ---------------------------------------------------------------------------

## Start the dealer's sweep volley — launch dice one at a time from emitter.
func _start_volley() -> void:
	_settle_check_active = true
	var total: int = _pending_pool.size()
	var cumulative_delay: float = 0.0
	for i: int in total:
		if i == 0:
			_volley_launch(0)
		else:
			var progress: float = float(i) / float(maxi(total - 1, 1))
			var base_delay: float = lerpf(VOLLEY_DELAY_START, VOLLEY_DELAY_END, progress)
			cumulative_delay += base_delay + randf_range(0.0, VOLLEY_DELAY_JITTER)
			var captured_index: int = i
			get_tree().create_timer(cumulative_delay).timeout.connect(
				func() -> void: _volley_launch(captured_index)
			)


## Instantiate and launch a single die as part of the volley.
func _volley_launch(index: int) -> void:
	if index < 0 or index >= _pending_pool.size():
		return
	var data: DiceData = _pending_pool[index]
	var die: PhysicsDie = PhysicsDieScene.instantiate() as PhysicsDie
	add_child(die)
	die.setup(index, data)
	_dice.append(die)
	die.toggled_keep.connect(_on_die_toggled)
	die.shift_toggled_keep.connect(_on_die_shift_toggled)
	die.collision_rerolled.connect(_on_die_collision_rerolled)

	# Position at emitter with jitter.
	var emitter: Vector2 = _volley_emitter()
	die.position = emitter + Vector2(
		randf_range(-VOLLEY_EMITTER_JITTER_X, VOLLEY_EMITTER_JITTER_X),
		randf_range(-VOLLEY_EMITTER_JITTER_Y, VOLLEY_EMITTER_JITTER_Y))

	# Roll and set face.
	var face: DiceFaceData = data.roll()
	die.current_face = face
	die.tumble(face)
	die.play_launch_burst()

	# Cone direction: sweep left-to-right across the volley.
	var total: int = _pending_pool.size()
	var target: Vector2 = Vector2(ARENA_WIDTH / 2.0, ARENA_HEIGHT * 0.4)
	var base_dir: Vector2 = (target - emitter).normalized()
	var base_angle: float = base_dir.angle()
	var sweep_t: float = lerpf(-1.0, 1.0, float(index) / float(maxi(total - 1, 1)))
	var cone_angle: float = base_angle + VOLLEY_CONE_HALF_ANGLE * sweep_t + randf_range(-VOLLEY_CONE_JITTER, VOLLEY_CONE_JITTER)
	var direction: Vector2 = Vector2.from_angle(cone_angle)

	var magnitude: float = randf_range(THROW_IMPULSE_MIN, THROW_IMPULSE_MAX)
	die.linear_velocity = direction * magnitude
	die.angular_velocity = randf_range(THROW_ANGULAR_MIN, THROW_ANGULAR_MAX)
	SFXManager.play_roll()


## Emitter position for the volley: lower center of the arena.
func _volley_emitter() -> Vector2:
	return Vector2(ARENA_WIDTH / 2.0, ARENA_HEIGHT - SPAWN_MARGIN - BOTTOM_SPAWN_LIFT)


## Launch a single rerolled die using the sweep volley pattern.
func _reroll_volley_launch(die: PhysicsDie, face: DiceFaceData, slot: int, total: int) -> void:
	if not is_instance_valid(die):
		return

	# Move die to emitter with jitter.
	var emitter: Vector2 = _volley_emitter()
	die.position = emitter + Vector2(
		randf_range(-VOLLEY_EMITTER_JITTER_X, VOLLEY_EMITTER_JITTER_X),
		randf_range(-VOLLEY_EMITTER_JITTER_Y, VOLLEY_EMITTER_JITTER_Y))

	die.physics_state = PhysicsDie.DiePhysicsState.FLYING
	die.freeze = false
	die._settle_timer = 0.0
	die.tumble(face)
	die.play_launch_burst()

	# Cone direction with sweep bias.
	var target: Vector2 = Vector2(ARENA_WIDTH / 2.0, ARENA_HEIGHT * 0.4)
	var base_dir: Vector2 = (target - emitter).normalized()
	var base_angle: float = base_dir.angle()
	var sweep_t: float = lerpf(-1.0, 1.0, float(slot) / float(maxi(total - 1, 1)))
	var cone_angle: float = base_angle + VOLLEY_CONE_HALF_ANGLE * sweep_t + randf_range(-VOLLEY_CONE_JITTER, VOLLEY_CONE_JITTER)
	var direction: Vector2 = Vector2.from_angle(cone_angle)

	var magnitude: float = randf_range(THROW_IMPULSE_MIN * 0.7, THROW_IMPULSE_MAX * 0.9)
	die.linear_velocity = direction * magnitude
	die.angular_velocity = randf_range(THROW_ANGULAR_MIN, THROW_ANGULAR_MAX)
	SFXManager.play_roll()


## Compute cumulative volley delay for a given die index (used by tests).
func volley_cumulative_delay(index: int, total: int) -> float:
	var cumulative: float = 0.0
	for i: int in range(1, index + 1):
		var progress: float = float(i) / float(maxi(total - 1, 1))
		cumulative += lerpf(VOLLEY_DELAY_START, VOLLEY_DELAY_END, progress)
	return cumulative


func _launch_die(
	die: PhysicsDie,
	origin: SpawnOrigin = SpawnOrigin.CENTER_BOTTOM,
	launch_index: int = 0,
	launch_total: int = 1
) -> void:
	var stagger_unit: float = _stagger_unit(launch_index, launch_total)
	die.position += Vector2(stagger_unit * THROW_STAGGER_SPAWN_SWEEP_X, 0.0)
	die.tumble(die.current_face)
	die.play_launch_burst()
	# Impulse away from spawn origin toward arena interior
	var target: Vector2 = _throw_target_for_origin(origin)
	target.x += stagger_unit * THROW_STAGGER_TARGET_SWEEP_X
	var direction: Vector2 = (target - die.position).normalized()
	# Add some random spread
	var spread: float = randf_range(-0.4, 0.4)
	direction = direction.rotated(spread)
	var magnitude_bias: float = clampf(
		1.0 + stagger_unit * THROW_STAGGER_MAGNITUDE_VARIANCE + randf_range(-0.05, 0.05),
		0.82,
		1.25
	)
	var magnitude: float = randf_range(THROW_IMPULSE_MIN, THROW_IMPULSE_MAX) * magnitude_bias
	die.apply_central_impulse(direction * magnitude)
	die.angular_velocity = randf_range(THROW_ANGULAR_MIN, THROW_ANGULAR_MAX)
	SFXManager.play_roll()


func _stagger_unit(launch_index: int, launch_total: int) -> float:
	if launch_total <= 1:
		return 0.0
	var normalized: float = (float(launch_index) / float(maxi(launch_total - 1, 1))) * 2.0 - 1.0
	var wave: float = sin(float(launch_index) * 1.2) * 0.35
	return clampf(normalized * THROW_STAGGER_SWEEP + wave, -1.0, 1.0)


## Returns a spawn position for the given origin with slight random jitter.
func _spawn_position_for_origin(origin: SpawnOrigin) -> Vector2:
	var margin: float = SPAWN_MARGIN
	var cx: float = ARENA_WIDTH / 2.0
	var cy: float = ARENA_HEIGHT / 2.0
	var jitter_x: float = randf_range(-40.0, 40.0)
	var jitter_y: float = randf_range(-20.0, 20.0)
	match origin:
		SpawnOrigin.CENTER_BOTTOM:
			return Vector2(cx + jitter_x, ARENA_HEIGHT - margin - BOTTOM_SPAWN_LIFT + jitter_y)
		SpawnOrigin.CENTER_TOP:
			return Vector2(cx + jitter_x, margin + jitter_y)
		SpawnOrigin.TOP_LEFT:
			return Vector2(margin + jitter_x, margin + jitter_y)
		SpawnOrigin.TOP_RIGHT:
			return Vector2(ARENA_WIDTH - margin + jitter_x, margin + jitter_y)
		SpawnOrigin.BOTTOM_LEFT:
			return Vector2(margin + jitter_x, ARENA_HEIGHT - margin - BOTTOM_SPAWN_LIFT + jitter_y)
		SpawnOrigin.BOTTOM_RIGHT:
			return Vector2(ARENA_WIDTH - margin + jitter_x, ARENA_HEIGHT - margin - BOTTOM_SPAWN_LIFT + jitter_y)
		SpawnOrigin.LEFT:
			return Vector2(margin + jitter_x, cy + jitter_y)
		SpawnOrigin.RIGHT:
			return Vector2(ARENA_WIDTH - margin + jitter_x, cy + jitter_y)
		SpawnOrigin.TOP:
			return Vector2(cx + jitter_x, margin + jitter_y)
	return Vector2(cx + jitter_x, ARENA_HEIGHT - margin - BOTTOM_SPAWN_LIFT + jitter_y)


func _build_spawn_positions(origin: SpawnOrigin, count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if count <= 0:
		return positions

	var anchor: Vector2 = _spawn_position_for_origin(origin)
	var radius: float = PhysicsDie.COLLISION_RADIUS
	var min_x: float = WALL_THICKNESS + radius + SPAWN_EDGE_PADDING
	var max_x: float = ARENA_WIDTH - WALL_THICKNESS - radius - SPAWN_EDGE_PADDING
	var usable_width: float = maxf(0.0, max_x - min_x)
	var spacing: float = maxf(radius * SPAWN_SPACING_MULT, 1.0)
	var max_per_row: int = maxi(1, int(floor(usable_width / spacing)) + 1)
	var row_count: int = maxi(1, int(ceil(float(count) / float(max_per_row))))
	var row_spacing: float = radius * SPAWN_ROW_SPACING_MULT

	var remaining: int = count
	for row_index: int in row_count:
		var rows_left: int = row_count - row_index
		var in_row: int = int(ceil(float(remaining) / float(rows_left)))
		remaining -= in_row
		var total_span: float = float(maxi(0, in_row - 1)) * spacing
		var start_x: float = anchor.x - total_span * 0.5
		var row_y: float = anchor.y - row_index * row_spacing
		for col: int in in_row:
			var x: float = clampf(start_x + float(col) * spacing, min_x, max_x)
			var y: float = clampf(row_y, WALL_THICKNESS + radius + SPAWN_EDGE_PADDING, ARENA_HEIGHT - WALL_THICKNESS - radius - SPAWN_EDGE_PADDING)
			positions.append(Vector2(x, y))

	return positions


func _update_centering() -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var viewport_size: Vector2 = Vector2(viewport.size)
	position = (viewport_size - Vector2(ARENA_WIDTH, ARENA_HEIGHT)) * 0.5


## Returns a target point for the throw impulse based on spawn origin.
func _throw_target_for_origin(origin: SpawnOrigin) -> Vector2:
	var cx: float = ARENA_WIDTH / 2.0
	var cy: float = ARENA_HEIGHT / 2.0
	var jitter_x: float = randf_range(-100.0, 100.0)
	var jitter_y: float = randf_range(-60.0, 60.0)
	match origin:
		SpawnOrigin.CENTER_BOTTOM:
			return Vector2(cx + jitter_x, cy * 0.4 + jitter_y)
		SpawnOrigin.CENTER_TOP:
			return Vector2(cx + jitter_x, cy * 1.6 + jitter_y)
		SpawnOrigin.TOP_LEFT:
			return Vector2(cx * 1.4 + jitter_x, cy * 1.4 + jitter_y)
		SpawnOrigin.TOP_RIGHT:
			return Vector2(cx * 0.6 + jitter_x, cy * 1.4 + jitter_y)
		SpawnOrigin.BOTTOM_LEFT:
			return Vector2(cx * 1.4 + jitter_x, cy * 0.6 + jitter_y)
		SpawnOrigin.BOTTOM_RIGHT:
			return Vector2(cx * 0.6 + jitter_x, cy * 0.6 + jitter_y)
		SpawnOrigin.LEFT:
			return Vector2(cx * 1.4 + jitter_x, cy + jitter_y)
		SpawnOrigin.RIGHT:
			return Vector2(cx * 0.6 + jitter_x, cy + jitter_y)
		SpawnOrigin.TOP:
			return Vector2(cx + jitter_x, cy * 1.4 + jitter_y)
	return Vector2(cx + jitter_x, cy * 0.4 + jitter_y)


# ---------------------------------------------------------------------------
# Arena construction
# ---------------------------------------------------------------------------

func _build_background() -> void:
	_bg_panel = Panel.new()
	_bg_panel.size = Vector2(ARENA_WIDTH, ARENA_HEIGHT)
	_bg_panel.position = Vector2.ZERO
	_bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_style = StyleBoxFlat.new()
	_bg_style.bg_color = ARENA_BG_COLOR
	_bg_style.border_color = ARENA_BORDER_COLOR
	_bg_style.set_border_width_all(ARENA_BORDER_WIDTH)
	_bg_style.set_corner_radius_all(ARENA_CORNER_RADIUS)
	_bg_panel.add_theme_stylebox_override("panel", _bg_style)
	add_child(_bg_panel)
	move_child(_bg_panel, 0)


func _build_walls() -> void:
	# Four walls as StaticBody2D with RectangleShape2D
	_add_wall(  # Top
		Vector2(ARENA_WIDTH / 2.0, -WALL_THICKNESS / 2.0),
		Vector2(ARENA_WIDTH, WALL_THICKNESS))
	_add_wall(  # Bottom
		Vector2(ARENA_WIDTH / 2.0, ARENA_HEIGHT + WALL_THICKNESS / 2.0),
		Vector2(ARENA_WIDTH, WALL_THICKNESS))
	_add_wall(  # Left
		Vector2(-WALL_THICKNESS / 2.0, ARENA_HEIGHT / 2.0),
		Vector2(WALL_THICKNESS, ARENA_HEIGHT))
	_add_wall(  # Right
		Vector2(ARENA_WIDTH + WALL_THICKNESS / 2.0, ARENA_HEIGHT / 2.0),
		Vector2(WALL_THICKNESS, ARENA_HEIGHT))


func _add_wall(pos: Vector2, extents: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = pos
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = extents
	col.shape = rect
	wall.add_child(col)
	add_child(wall)


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_die_toggled(die_index: int, is_kept: bool) -> void:
	die_clicked.emit(die_index, is_kept)


func _on_die_shift_toggled(die_index: int, is_kept: bool) -> void:
	die_shift_clicked.emit(die_index, is_kept)


func _on_die_collision_rerolled(die_index: int, new_face: DiceFaceData) -> void:
	die_collision_rerolled.emit(die_index, new_face)


# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

func _clear_dice() -> void:
	for die: PhysicsDie in _dice:
		if is_instance_valid(die):
			die.queue_free()
	_dice.clear()


func _enforce_arena_containment() -> void:
	if instant_mode or _dice.is_empty():
		return
	var rect: Rect2 = get_arena_rect()
	var min_x: float = rect.position.x + PhysicsDie.COLLISION_RADIUS
	var max_x: float = rect.end.x - PhysicsDie.COLLISION_RADIUS
	var min_y: float = rect.position.y + PhysicsDie.COLLISION_RADIUS
	var max_y: float = rect.end.y - PhysicsDie.COLLISION_RADIUS
	var hit_count: int = 0
	for die: PhysicsDie in _dice:
		if die == null or die.freeze:
			continue
		var p: Vector2 = die.position
		var corrected: bool = false
		var wall_dampen: float = pow(WALL_BOUNCE_DAMPEN_FACTOR, mini(die._wall_bounce_count, 10))
		var effective_min_speed: float = CONTAINMENT_MIN_BOUNCE_SPEED * wall_dampen
		var effective_damp: float = CONTAINMENT_BOUNCE_DAMP * wall_dampen
		if p.x < min_x:
			p.x = min_x
			die.linear_velocity.x = maxf(absf(die.linear_velocity.x) * effective_damp, effective_min_speed)
			corrected = true
		elif p.x > max_x:
			p.x = max_x
			die.linear_velocity.x = -maxf(absf(die.linear_velocity.x) * effective_damp, effective_min_speed)
			corrected = true
		if p.y < min_y:
			p.y = min_y
			die.linear_velocity.y = maxf(absf(die.linear_velocity.y) * effective_damp, effective_min_speed)
			corrected = true
		elif p.y > max_y:
			p.y = max_y
			die.linear_velocity.y = -maxf(absf(die.linear_velocity.y) * effective_damp, effective_min_speed)
			corrected = true
		if corrected:
			die._wall_bounce_count += 1
			die.position = p
			var inward: Vector2 = (Vector2(ARENA_WIDTH * 0.5, ARENA_HEIGHT * 0.5) - p).normalized()
			if inward != Vector2.ZERO:
				die.apply_central_impulse(inward * CONTAINMENT_INWARD_NUDGE)
			hit_count += 1
	if hit_count > 0:
		_accumulate_boundary_glow(hit_count)


func _apply_soft_separation() -> void:
	if instant_mode or _dice.size() < 2:
		return
	var min_distance: float = PhysicsDie.COLLISION_RADIUS * SOFT_SEPARATION_RADIUS_MULT
	var min_distance_sq: float = min_distance * min_distance
	for i: int in _dice.size():
		var a: PhysicsDie = _dice[i]
		if a == null or a.freeze:
			continue
		if a.linear_velocity.length() > SOFT_SEPARATION_MAX_SPEED:
			continue
		for j: int in range(i + 1, _dice.size()):
			var b: PhysicsDie = _dice[j]
			if b == null or b.freeze:
				continue
			if b.linear_velocity.length() > SOFT_SEPARATION_MAX_SPEED:
				continue
			var delta_pos: Vector2 = a.position - b.position
			var dist_sq: float = delta_pos.length_squared()
			if dist_sq <= 0.0001 or dist_sq >= min_distance_sq:
				continue
			var dist: float = sqrt(dist_sq)
			var normal: Vector2 = delta_pos / dist
			var overlap_ratio: float = clampf((min_distance - dist) / min_distance, 0.0, 1.0)
			var push: float = overlap_ratio * SOFT_SEPARATION_PUSH
			a.apply_central_impulse(normal * push)
			b.apply_central_impulse(-normal * push)


func _accumulate_boundary_glow(hit_count: int) -> void:
	var gain: float = float(hit_count) * BOUNDARY_GLOW_HIT_GAIN
	_boundary_glow_energy = clampf(_boundary_glow_energy + gain, 0.0, 1.0)
	_apply_boundary_glow()


func _apply_boundary_glow() -> void:
	if _bg_style == null:
		return
	var t: float = clampf(_boundary_glow_energy, 0.0, 1.0)
	_bg_style.border_color = ARENA_BORDER_COLOR.lerp(_UITheme.DANGER_RED, t)
