class_name DiceArena
extends Node2D
## Physics arena for dice throwing. Contains walls, spawns PhysicsDie
## instances, monitors settling, and provides the results API.
## Lives inside a SubViewport to isolate physics from the UI layer.

const _UITheme := preload("res://Scripts/UITheme.gd")
const PhysicsDieScene: PackedScene = preload("res://Scenes/PhysicsDie.tscn")
const DeerSkullDecorScript: GDScript = preload("res://Scripts/DeerSkullDecor.gd")

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
const REROLL_EXIT_DURATION: float = 0.12
const THROW_STAGGER_RANDOM_MAX: float = 0.02
const THROW_STAGGER_SWEEP: float = 0.85
const THROW_STAGGER_SPAWN_SWEEP_X: float = 52.0
const THROW_STAGGER_TARGET_SWEEP_X: float = 116.0
const THROW_STAGGER_MAGNITUDE_VARIANCE: float = 0.12
const SPAWN_SPACING_MULT: float = 2.2
const SPAWN_ROW_SPACING_MULT: float = 2.1
const SPAWN_EDGE_PADDING: float = 8.0
const SPAWN_LAYOUT_JITTER_X: float = 22.0
const SPAWN_LAYOUT_JITTER_Y: float = 12.0
const LARGE_POOL_CENTERING_THRESHOLD: int = 10
const BOUNDARY_GLOW_HIT_GAIN: float = 0.22
const BOUNDARY_GLOW_DECAY_PER_SEC: float = 2.1
const CONTAINMENT_MIN_BOUNCE_SPEED: float = 90.0
const CONTAINMENT_INWARD_NUDGE: float = 54.0
const SOFT_SEPARATION_RADIUS_MULT: float = 1.82
const SOFT_SEPARATION_MAX_SPEED: float = 150.0
const SOFT_SEPARATION_PUSH: float = 38.0
const GRAVITY_WELL_RADIUS: float = 90.0   ## matches TurnScoreService.MULTIPLY_RADIUS
const GRAVITY_WELL_FORCE: float = 30.0    ## constant inward force per physics step (N)
const PREVIEW_BOUNDS_PADDING: float = 10.0
const MIN_ARENA_FIT_SCALE: float = 0.45

# Dice bag (kept-dice staging area)
const BAG_PANEL_W: float = 176.0
const BAG_PANEL_H: float = 150.0
const BAG_PANEL_PADDING: float = 8.0
const BAG_DIE_SCALE: float = 0.52
const BAG_MOVE_DURATION: float = 0.28
const BAG_STACK_MAX_RADIUS: float = 22.0

# Dealer's sweep volley parameters
const VOLLEY_DELAY_START: float = 0.055
const VOLLEY_DELAY_END: float = 0.012
const VOLLEY_DELAY_JITTER: float = 0.008
const VOLLEY_CONE_HALF_ANGLE: float = 1.45
const VOLLEY_CONE_JITTER: float = 0.15
const VOLLEY_EMITTER_JITTER_X: float = 10.0
const VOLLEY_EMITTER_JITTER_Y: float = 10.0
const REROLL_VOLLEY_DELAY_START: float = 0.085
const REROLL_VOLLEY_DELAY_END: float = 0.028
const REROLL_VOLLEY_DELAY_JITTER: float = 0.004
const REROLL_VOLLEY_CONE_HALF_ANGLE: float = 0.9
const REROLL_VOLLEY_CONE_JITTER: float = 0.06
const REROLL_VOLLEY_EMITTER_SWEEP_X: float = 0.0
const REROLL_VOLLEY_EMITTER_JITTER_X: float = 8.0
const REROLL_VOLLEY_EMITTER_JITTER_Y: float = 8.0
const REROLL_VOLLEY_TARGET_SWEEP_X: float = 0.0
const REROLL_VOLLEY_TARGET_HEIGHT_RATIO: float = 0.54
const REROLL_THROW_IMPULSE_MIN: float = 1080.0
const REROLL_THROW_IMPULSE_MAX: float = 1580.0
const VOLLEY_EMITTER_HEIGHT_RATIO: float = 0.54
const BURST_TARGET_MIN_RING: float = 0.28
const BURST_TARGET_RADIUS_X: float = 560.0
const BURST_TARGET_RADIUS_Y: float = 185.0
const BURST_TARGET_JITTER_X: float = 34.0
const BURST_TARGET_JITTER_Y: float = 22.0
const LARGE_POOL_BURST_THRESHOLD: int = 12
const LARGE_POOL_BURST_MIN_RING: float = 0.52
const LARGE_POOL_BURST_ANGLE_JITTER: float = 0.14
const LARGE_POOL_BURST_JITTER_SCALE: float = 0.65
const REROLL_BURST_TARGET_RADIUS_X: float = 470.0
const REROLL_BURST_TARGET_RADIUS_Y: float = 150.0
const REROLL_BURST_TARGET_JITTER_X: float = 24.0
const REROLL_BURST_TARGET_JITTER_Y: float = 16.0
const GOLDEN_ANGLE: float = 2.39996323
const REROLL_EXIT_LIFT_Y: float = 18.0

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
var _bag_panel: Panel = null
var _bag_count_label: Label = null
var _bag_kept_label: Label = null
var _bag_dice_count: int = 0
## When true, dice settle instantly (no physics). Set by tests.
var instant_mode: bool = false

# Extracted components
var _physics_ctrl: ArenaPhysicsController = ArenaPhysicsController.new()
var _volley_launcher: DiceVolleyLauncher = null

## Legacy property — forwards to _physics_ctrl.boundary_glow_energy
var _boundary_glow_energy: float:
	get: return _physics_ctrl.boundary_glow_energy
	set(v): _physics_ctrl.boundary_glow_energy = v

## Legacy property — forwards to _volley_launcher.reroll_burst_rotation
var _reroll_burst_rotation: float:
	get: return _volley_launcher.reroll_burst_rotation if _volley_launcher else 0.0
	set(v):
		if _volley_launcher:
			_volley_launcher.reroll_burst_rotation = v

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_volley_launcher = DiceVolleyLauncher.new()
	_volley_launcher.setup(self)
	add_child(_volley_launcher)
	_build_background()
	_build_walls()
	_build_deer_skulls()
	_build_dice_bag()
	_update_centering()
	_refresh_popup_bounds_for_dice()
	var viewport: Viewport = get_viewport()
	if viewport and not viewport.size_changed.is_connected(_update_centering):
		viewport.size_changed.connect(_update_centering)


func _physics_process(_delta: float) -> void:
	var has_gravity: bool = GameManager != null and GameManager.has_modifier(RunModifier.ModifierType.GRAVITY_WELL)
	_physics_ctrl.process_physics(_dice, get_arena_rect(), _delta, has_gravity, instant_mode, _bg_style)
	if not _settle_check_active:
		return
	# Check if all dice have settled
	for die: PhysicsDie in _dice:
		if die.physics_state != PhysicsDie.DiePhysicsState.SETTLED and die.physics_state != PhysicsDie.DiePhysicsState.KEPT:
			return
	# All settled
	_settle_check_active = false
	all_dice_settled.emit()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func throw_dice(pool: Array) -> void:
	var typed_pool: Array[DiceData] = _coerce_dice_pool(pool)
	_clear_dice()
	if instant_mode:
		# Instant mode: spawn all dice at once in grid and settle (used by tests).
		var spawn_positions: Array[Vector2] = _volley_launcher.build_spawn_positions(default_spawn_origin, typed_pool.size())
		for i: int in typed_pool.size():
			var die: PhysicsDie = PhysicsDieScene.instantiate() as PhysicsDie
			add_child(die)
			die.setup(i, typed_pool[i])
			_apply_popup_bounds_to_die(die)
			_dice.append(die)
			die.toggled_keep.connect(_on_die_toggled)
			die.shift_toggled_keep.connect(_on_die_shift_toggled)
			die.collision_rerolled.connect(_on_die_collision_rerolled)
			die.position = spawn_positions[i]
			var face: DiceFaceData = typed_pool[i].roll()
			die.current_face = face
			die.show_face(face)
			die.freeze = true
			die.physics_state = PhysicsDie.DiePhysicsState.SETTLED
		all_dice_settled.emit()
	else:
		# Dealer's sweep: store pool and launch dice one at a time.
		_pending_pool = typed_pool
		_volley_launcher.start_volley()


func reroll_dice(indices: Array[int], pool: Array) -> void:
	var typed_pool: Array[DiceData] = _coerce_dice_pool(pool)
	if instant_mode:
		_volley_launcher.execute_reroll(indices, typed_pool)
		return
	# Move all kept (non-rerolled) dice to the dice bag.
	var reroll_set: Dictionary = {}
	for idx: int in indices:
		reroll_set[idx] = true
	_reset_bag()
	var launch_prep_delay: float = 0.0
	for i: int in _dice.size():
		if not is_instance_valid(_dice[i]):
			continue
		if reroll_set.has(i):
			_volley_launcher.animate_reroll_exit(_dice[i])
			launch_prep_delay = maxf(launch_prep_delay, REROLL_EXIT_DURATION)
		else:
			_move_die_to_bag(_dice[i])
			launch_prep_delay = maxf(launch_prep_delay, BAG_MOVE_DURATION)

	if instant_mode or launch_prep_delay <= 0.0:
		_volley_launcher.execute_reroll(indices, typed_pool)
	else:
		# Wait for the exit and bag animations to finish, then reroll.
		var captured_indices: Array[int] = []
		for index: int in indices:
			captured_indices.append(index)
		var captured_pool: Array[DiceData] = []
		for die_data: DiceData in typed_pool:
			captured_pool.append(die_data)
		get_tree().create_timer(launch_prep_delay).timeout.connect(
			_volley_launcher.execute_reroll.bind(captured_indices, captured_pool)
		)


func _coerce_dice_pool(pool: Array) -> Array[DiceData]:
	var typed_pool: Array[DiceData] = []
	for entry: Variant in pool:
		if entry is DiceData:
			typed_pool.append(entry as DiceData)
	return typed_pool


func _execute_reroll(indices: Array[int], pool: Array[DiceData]) -> void:
	_volley_launcher.execute_reroll(indices, pool)


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


func _rng_randf(stream_name: String) -> float:
	if GameManager != null and GameManager.has_method("rng_randf"):
		return GameManager.rng_randf(stream_name)
	return randf()


func get_dice_in_radius(center: Vector2, radius: float, exclude_indices: Array[int] = []) -> Array[int]:
	var result: Array[int] = []
	var radius_sq: float = radius * radius
	for die: PhysicsDie in _dice:
		if die == null or exclude_indices.has(die.die_index):
			continue
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


func detonate_around(
	center_index: int,
	radius: float,
	exclude_indices: Array[int] = [],
	immune_indices: Array[int] = [],
	dampened_indices: Array[int] = []
) -> Array[int]:
	var source_die: PhysicsDie = get_die(center_index)
	if source_die == null:
		return []
	var effective_excludes: Array[int] = []
	for index: int in exclude_indices:
		effective_excludes.append(index)
	if not effective_excludes.has(center_index):
		effective_excludes.append(center_index)
	var nearby_indices: Array[int] = get_dice_in_radius(source_die.global_position, radius, effective_excludes)
	var hit_indices: Array[int] = []
	for hit_index: int in nearby_indices:
		if immune_indices.has(hit_index):
			continue
		var hit_die: PhysicsDie = get_die(hit_index)
		if hit_die == null:
			continue
		hit_indices.append(hit_index)
		var direction: Vector2 = (hit_die.global_position - source_die.global_position).normalized()
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT.rotated(_rng_randf("roll") * TAU)
		var distance_ratio: float = clampf(hit_die.global_position.distance_to(source_die.global_position) / maxf(radius, 1.0), 0.0, 1.0)
		var falloff: float = lerpf(1.0, 0.35, distance_ratio)
		var impulse_scale: float = 0.35 if dampened_indices.has(hit_index) else 1.0
		var impulse_magnitude: float = PhysicsDie.DETONATE_IMPULSE * falloff * impulse_scale
		hit_die.set_physics_state(PhysicsDie.DiePhysicsState.FLYING)
		hit_die._settle_timer = 0.0
		hit_die.linear_velocity = direction * (impulse_magnitude * 0.72)
		hit_die.apply_central_impulse(direction * impulse_magnitude)
		hit_die.angular_velocity += randf_range(-4.0, 4.0)
		hit_die.play_displacement_hit(direction)
	_settle_check_active = true
	source_die.play_detonation(radius)
	return hit_indices


func spawn_settled_die(index: int, data: DiceData, face: DiceFaceData, position: Vector2, kept_locked: bool = true) -> void:
	var die: PhysicsDie = PhysicsDieScene.instantiate() as PhysicsDie
	add_child(die)
	die.setup(index, data)
	_apply_popup_bounds_to_die(die)
	if index >= _dice.size():
		_dice.resize(index + 1)
	_dice[index] = die
	die.toggled_keep.connect(_on_die_toggled)
	die.shift_toggled_keep.connect(_on_die_shift_toggled)
	die.collision_rerolled.connect(_on_die_collision_rerolled)
	die.position = _clamp_to_arena(position)
	die.current_face = face
	die.show_face(face)
	die.is_kept = kept_locked
	die.is_keep_locked = kept_locked
	die.freeze = true
	die.physics_state = PhysicsDie.DiePhysicsState.SETTLED
	die.pop()


func spawn_cluster_children(parent_index: int, child_count: int, child_dice: Array[DiceData]) -> Array[int]:
	var spawned_indices: Array[int] = []
	if child_count <= 0 or child_dice.is_empty():
		return spawned_indices
	var parent_die: PhysicsDie = get_die(parent_index)
	if parent_die == null:
		return spawned_indices
	var spawn_total: int = mini(child_count, child_dice.size())
	for slot: int in spawn_total:
		var data: DiceData = child_dice[slot]
		if data == null:
			continue
		var child_index: int = _dice.size()
		var angle: float = (TAU * float(slot) / float(maxi(spawn_total, 1))) + randf_range(-0.25, 0.25)
		var radius: float = randf_range(26.0, 44.0)
		var child_position: Vector2 = _clamp_to_arena(parent_die.position + Vector2(cos(angle), sin(angle)) * radius)
		var die: PhysicsDie = PhysicsDieScene.instantiate() as PhysicsDie
		die.die_scale = 0.55
		add_child(die)
		die.setup(child_index, data)
		_apply_popup_bounds_to_die(die)
		if child_index >= _dice.size():
			_dice.resize(child_index + 1)
		_dice[child_index] = die
		die.toggled_keep.connect(_on_die_toggled)
		die.shift_toggled_keep.connect(_on_die_shift_toggled)
		die.collision_rerolled.connect(_on_die_collision_rerolled)
		die.position = child_position
		var child_face: DiceFaceData = data.roll()
		die.current_face = child_face
		die.tumble(child_face)
		die.play_launch_burst()
		die.set_physics_state(PhysicsDie.DiePhysicsState.FLYING)
		die._settle_timer = 0.0
		die.linear_velocity = Vector2(cos(angle), sin(angle)) * randf_range(600.0, 900.0)
		die.angular_velocity = randf_range(THROW_ANGULAR_MIN * 0.6, THROW_ANGULAR_MAX * 0.6)
		spawned_indices.append(child_index)
	_settle_check_active = true
	return spawned_indices


func get_die_count() -> int:
	return _dice.size()


func _clamp_to_arena(position: Vector2) -> Vector2:
	var rect: Rect2 = get_arena_rect()
	return Vector2(
		clampf(position.x, rect.position.x + PhysicsDie.COLLISION_RADIUS, rect.end.x - PhysicsDie.COLLISION_RADIUS),
		clampf(position.y, rect.position.y + PhysicsDie.COLLISION_RADIUS, rect.end.y - PhysicsDie.COLLISION_RADIUS)
	)


func reset() -> void:
	_clear_dice()
	_settle_check_active = false
	_physics_ctrl.reset()
	_physics_ctrl.process_physics([], get_arena_rect(), 0.0, false, instant_mode, _bg_style)


func restore_dice_state(
	pool: Array[DiceData],
	results: Array[DiceFaceData],
	stopped: Array[bool],
	kept: Array[bool],
	keep_locked: Array[bool]
) -> void:
	_clear_dice()
	_settle_check_active = false
	if pool.is_empty():
		return
	var spawn_positions: Array[Vector2] = _volley_launcher.build_spawn_positions(default_spawn_origin, pool.size())
	for i: int in pool.size():
		var die: PhysicsDie = PhysicsDieScene.instantiate() as PhysicsDie
		add_child(die)
		die.setup(i, pool[i])
		_apply_popup_bounds_to_die(die)
		_dice.append(die)
		die.toggled_keep.connect(_on_die_toggled)
		die.shift_toggled_keep.connect(_on_die_shift_toggled)
		die.collision_rerolled.connect(_on_die_collision_rerolled)
		die.position = spawn_positions[i]
		var face: DiceFaceData = null
		if i < results.size() and results[i] != null:
			face = results[i]
		elif not pool[i].faces.is_empty():
			face = pool[i].faces[0]
		else:
			face = DiceFaceData.new()
			face.type = DiceFaceData.FaceType.BLANK
			face.value = 0
		die.current_face = face
		die.show_face(face)
		die.is_stopped = i < stopped.size() and stopped[i]
		die.is_kept = i < kept.size() and kept[i]
		die.is_keep_locked = i < keep_locked.size() and keep_locked[i]
		die.freeze = true
		die.physics_state = PhysicsDie.DiePhysicsState.SETTLED
		die._apply_visual()


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
# Delegation stubs — forward to DiceVolleyLauncher for backward compat
# ---------------------------------------------------------------------------

func _start_volley() -> void:
	_volley_launcher.start_volley()


func _volley_launch(index: int) -> void:
	_volley_launcher.volley_launch(index)


func _volley_emitter() -> Vector2:
	return _volley_launcher.volley_emitter()


func _begin_reroll_launch_sequence(die: PhysicsDie, face: DiceFaceData, slot: int, total: int) -> void:
	_volley_launcher.begin_reroll_launch_sequence(die, face, slot, total)


func _reroll_volley_launch(die: PhysicsDie, face: DiceFaceData, slot: int, total: int) -> void:
	_volley_launcher.reroll_volley_launch(die, face, slot, total)


func _burst_target_position(index: int, total: int, is_reroll: bool) -> Vector2:
	return _volley_launcher.burst_target_position(index, total, is_reroll)


func _animate_reroll_exit(die: PhysicsDie) -> void:
	_volley_launcher.animate_reroll_exit(die)


func volley_cumulative_delay(index: int, total: int) -> float:
	return _volley_launcher.volley_cumulative_delay(index, total)


func reroll_cumulative_delay(index: int, total: int) -> float:
	return _volley_launcher.reroll_cumulative_delay(index, total)


func _build_spawn_positions(origin: SpawnOrigin, count: int) -> Array[Vector2]:
	return _volley_launcher.build_spawn_positions(origin, count)


func _update_centering() -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var viewport_size: Vector2 = Vector2(viewport.size)
	var fit_scale: float = _calculate_fit_scale(viewport_size)
	scale = Vector2.ONE * fit_scale
	position = (viewport_size - Vector2(ARENA_WIDTH, ARENA_HEIGHT) * fit_scale) * 0.5
	_refresh_popup_bounds_for_dice()


func _calculate_fit_scale(viewport_size: Vector2) -> float:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	var fit_x: float = viewport_size.x / ARENA_WIDTH
	var fit_y: float = viewport_size.y / ARENA_HEIGHT
	return clampf(minf(fit_x, fit_y), MIN_ARENA_FIT_SCALE, 1.0)


func _get_popup_bounds_global() -> Rect2:
	var local_rect: Rect2 = get_arena_rect().grow(-PREVIEW_BOUNDS_PADDING)
	var top_left: Vector2 = to_global(local_rect.position)
	var bottom_right: Vector2 = to_global(local_rect.end)
	return Rect2(top_left, bottom_right - top_left)


func _apply_popup_bounds_to_die(die: PhysicsDie) -> void:
	if die == null or not is_instance_valid(die):
		return
	die.set_popup_bounds(_get_popup_bounds_global())


func _refresh_popup_bounds_for_dice() -> void:
	var popup_bounds: Rect2 = _get_popup_bounds_global()
	for die: PhysicsDie in _dice:
		if die == null or not is_instance_valid(die):
			continue
		die.set_popup_bounds(popup_bounds)


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


func _build_deer_skulls() -> void:
	var positions: Array[Vector2] = [
		Vector2(WALL_THICKNESS + 60.0, ARENA_HEIGHT * 0.5),
		Vector2(ARENA_WIDTH - WALL_THICKNESS - 60.0, ARENA_HEIGHT * 0.5),
		Vector2(ARENA_WIDTH * 0.5, WALL_THICKNESS + 50.0),
		Vector2(ARENA_WIDTH * 0.35, ARENA_HEIGHT - WALL_THICKNESS - 40.0),
		Vector2(ARENA_WIDTH * 0.65, ARENA_HEIGHT - WALL_THICKNESS - 40.0),
	]
	for i: int in positions.size():
		var skull: Node2D = DeerSkullDecorScript.new()
		skull.position = positions[i]
		skull.flip_h = (i % 2 == 1)
		add_child(skull)


func _build_dice_bag() -> void:
	var px: float = ARENA_WIDTH - WALL_THICKNESS - BAG_PANEL_W - BAG_PANEL_PADDING
	var py: float = ARENA_HEIGHT - WALL_THICKNESS - BAG_PANEL_H - BAG_PANEL_PADDING

	# "KEPT" label above the panel.
	_bag_kept_label = Label.new()
	_bag_kept_label.position = Vector2(px, py - 24.0)
	_bag_kept_label.size = Vector2(BAG_PANEL_W, 20.0)
	_bag_kept_label.text = "KEPT"
	_bag_kept_label.add_theme_font_override("font", _UITheme.font_mono())
	_bag_kept_label.add_theme_font_size_override("font_size", 13)
	_bag_kept_label.add_theme_color_override("font_color", Color("#8888aa"))
	_bag_kept_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bag_kept_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bag_kept_label)

	# Bag panel.
	_bag_panel = Panel.new()
	_bag_panel.position = Vector2(px, py)
	_bag_panel.size = Vector2(BAG_PANEL_W, BAG_PANEL_H)
	_bag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.15, 0.88)
	style.border_color = Color("#333355")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	_bag_panel.add_theme_stylebox_override("panel", style)
	add_child(_bag_panel)

	# Count label inside the panel.
	_bag_count_label = Label.new()
	_bag_count_label.position = Vector2.ZERO
	_bag_count_label.size = Vector2(BAG_PANEL_W, BAG_PANEL_H)
	_bag_count_label.text = "0"
	_bag_count_label.add_theme_font_override("font", _UITheme.font_stats())
	_bag_count_label.add_theme_font_size_override("font_size", 42)
	_bag_count_label.add_theme_color_override("font_color", Color("#00E676"))
	_bag_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bag_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bag_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bag_panel.add_child(_bag_count_label)


func _bag_center() -> Vector2:
	var px: float = ARENA_WIDTH - WALL_THICKNESS - BAG_PANEL_W - BAG_PANEL_PADDING
	var py: float = ARENA_HEIGHT - WALL_THICKNESS - BAG_PANEL_H - BAG_PANEL_PADDING
	return Vector2(px + BAG_PANEL_W * 0.5, py + BAG_PANEL_H * 0.5)


func _bag_slot_position(slot: int) -> Vector2:
	if slot == 0:
		return _bag_center()
	var angle: float = float(slot) * 2.39996
	var radius: float = minf(float(slot) * 4.0, BAG_STACK_MAX_RADIUS)
	return _bag_center() + Vector2(cos(angle), sin(angle)) * radius


func _move_die_to_bag(die: PhysicsDie) -> void:
	die.collision_layer = 0
	die.collision_mask = 0
	die.freeze = true
	die.linear_velocity = Vector2.ZERO
	die.angular_velocity = 0.0
	die.physics_state = PhysicsDie.DiePhysicsState.KEPT
	var target: Vector2 = _bag_slot_position(_bag_dice_count)
	_bag_dice_count += 1
	if _bag_count_label:
		_bag_count_label.text = str(_bag_dice_count)
	if instant_mode:
		die.position = target
		die.scale = Vector2(BAG_DIE_SCALE, BAG_DIE_SCALE)
	else:
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(die, "position", target, BAG_MOVE_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(die, "scale", Vector2(BAG_DIE_SCALE, BAG_DIE_SCALE), BAG_MOVE_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)


func _stash_die_in_bag(die: PhysicsDie, slot: int) -> void:
	die.collision_layer = 0
	die.collision_mask = 0
	die.freeze = true
	die.physics_state = PhysicsDie.DiePhysicsState.KEPT
	die.linear_velocity = Vector2.ZERO
	die.angular_velocity = 0.0
	die.position = _bag_slot_position(slot)
	die.scale = Vector2(BAG_DIE_SCALE, BAG_DIE_SCALE)


func _set_bag_count(count: int) -> void:
	_bag_dice_count = maxi(count, 0)
	if _bag_count_label:
		_bag_count_label.text = str(_bag_dice_count)


func _reset_bag() -> void:
	_set_bag_count(0)


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
	_reset_bag()
