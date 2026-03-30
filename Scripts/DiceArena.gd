class_name DiceArena
extends Node2D
## Physics arena for dice throwing. Contains walls, spawns PhysicsDie
## instances, monitors settling, and provides the results API.
## Lives inside a SubViewport to isolate physics from the UI layer.

const _UITheme := preload("res://Scripts/UITheme.gd")
const PhysicsDieScene: PackedScene = preload("res://Scenes/PhysicsDie.tscn")

signal all_dice_settled()
signal die_clicked(die_index: int, is_kept: bool)
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
const THROW_IMPULSE_MIN: float = 1000.0
const THROW_IMPULSE_MAX: float = 1800.0
const THROW_ANGULAR_MIN: float = -8.0
const THROW_ANGULAR_MAX: float = 8.0
const THROW_STAGGER_DELAY: float = 0.03
const SPAWN_MARGIN: float = 80.0

## Spawn origin presets for dice throwing.
## Items can override per-die spawn origins in the future.
enum SpawnOrigin { CENTER_BOTTOM, TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT, LEFT, RIGHT, TOP, CENTER_TOP }

## Default spawn origin for all dice.
var default_spawn_origin: SpawnOrigin = SpawnOrigin.CENTER_BOTTOM

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _dice: Array[PhysicsDie] = []
var _settle_check_active: bool = false
var _bg_panel: Panel = null
## When true, dice settle instantly (no physics). Set by tests.
var instant_mode: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_background()
	_build_walls()


func _physics_process(_delta: float) -> void:
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
	for i: int in pool.size():
		var die: PhysicsDie = PhysicsDieScene.instantiate() as PhysicsDie
		add_child(die)
		die.setup(i, pool[i])
		_dice.append(die)

		# Connect signals
		die.toggled_keep.connect(_on_die_toggled)
		die.collision_rerolled.connect(_on_die_collision_rerolled)

		# Spawn at the default origin (items can override per-die in the future)
		var spawn_pos: Vector2 = _spawn_position_for_origin(default_spawn_origin)
		die.global_position = spawn_pos

		# Roll the die face
		var face: DiceFaceData = pool[i].roll()
		die.current_face = face

	# Stagger the throws
	_stagger_throw()


func reroll_dice(indices: Array[int], pool: Array[DiceData]) -> void:
	for i: int in indices:
		if i < 0 or i >= _dice.size():
			continue
		var die: PhysicsDie = _dice[i]
		die.is_stopped = false

		# Roll new face
		var face: DiceFaceData = pool[i].roll()
		die.current_face = face

		if instant_mode:
			die.show_face(face)
			die.freeze = true
			die.physics_state = PhysicsDie.DiePhysicsState.SETTLED
		else:
			# Move to spawn origin and re-throw
			var origin: SpawnOrigin = default_spawn_origin
			die.global_position = _spawn_position_for_origin(origin)
			die.physics_state = PhysicsDie.DiePhysicsState.FLYING
			die.freeze = false
			die._settle_timer = 0.0
			die.tumble(face)
			var target: Vector2 = _throw_target_for_origin(origin)
			var direction: Vector2 = (target - die.global_position).normalized()
			var spread: float = randf_range(-0.4, 0.4)
			direction = direction.rotated(spread)
			var magnitude: float = randf_range(THROW_IMPULSE_MIN * 0.7, THROW_IMPULSE_MAX * 0.9)
			die.apply_central_impulse(direction * magnitude)
			die.angular_velocity = randf_range(THROW_ANGULAR_MIN, THROW_ANGULAR_MAX)

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

func _stagger_throw() -> void:
	if instant_mode:
		# Skip physics entirely — place dice in grid and settle immediately.
		for i: int in _dice.size():
			var die: PhysicsDie = _dice[i]
			die.show_face(die.current_face)
			die.freeze = true
			die.physics_state = PhysicsDie.DiePhysicsState.SETTLED
		all_dice_settled.emit()
		return

	_settle_check_active = true
	for i: int in _dice.size():
		var die: PhysicsDie = _dice[i]
		# Stagger: use a timer callback
		if i == 0:
			_launch_die(die, default_spawn_origin)
		else:
			var timer: SceneTreeTimer = get_tree().create_timer(THROW_STAGGER_DELAY * i)
			timer.timeout.connect(_launch_die.bind(die, default_spawn_origin))


func _launch_die(die: PhysicsDie, origin: SpawnOrigin = SpawnOrigin.CENTER_BOTTOM) -> void:
	die.tumble(die.current_face)
	# Impulse away from spawn origin toward arena interior
	var target: Vector2 = _throw_target_for_origin(origin)
	var direction: Vector2 = (target - die.global_position).normalized()
	# Add some random spread
	var spread: float = randf_range(-0.4, 0.4)
	direction = direction.rotated(spread)
	var magnitude: float = randf_range(THROW_IMPULSE_MIN, THROW_IMPULSE_MAX)
	die.apply_central_impulse(direction * magnitude)
	die.angular_velocity = randf_range(THROW_ANGULAR_MIN, THROW_ANGULAR_MAX)
	SFXManager.play_roll()


## Returns a spawn position for the given origin with slight random jitter.
func _spawn_position_for_origin(origin: SpawnOrigin) -> Vector2:
	var margin: float = SPAWN_MARGIN
	var cx: float = ARENA_WIDTH / 2.0
	var cy: float = ARENA_HEIGHT / 2.0
	var jitter_x: float = randf_range(-40.0, 40.0)
	var jitter_y: float = randf_range(-20.0, 20.0)
	match origin:
		SpawnOrigin.CENTER_BOTTOM:
			return Vector2(cx + jitter_x, ARENA_HEIGHT - margin + jitter_y)
		SpawnOrigin.CENTER_TOP:
			return Vector2(cx + jitter_x, margin + jitter_y)
		SpawnOrigin.TOP_LEFT:
			return Vector2(margin + jitter_x, margin + jitter_y)
		SpawnOrigin.TOP_RIGHT:
			return Vector2(ARENA_WIDTH - margin + jitter_x, margin + jitter_y)
		SpawnOrigin.BOTTOM_LEFT:
			return Vector2(margin + jitter_x, ARENA_HEIGHT - margin + jitter_y)
		SpawnOrigin.BOTTOM_RIGHT:
			return Vector2(ARENA_WIDTH - margin + jitter_x, ARENA_HEIGHT - margin + jitter_y)
		SpawnOrigin.LEFT:
			return Vector2(margin + jitter_x, cy + jitter_y)
		SpawnOrigin.RIGHT:
			return Vector2(ARENA_WIDTH - margin + jitter_x, cy + jitter_y)
		SpawnOrigin.TOP:
			return Vector2(cx + jitter_x, margin + jitter_y)
	return Vector2(cx + jitter_x, ARENA_HEIGHT - margin + jitter_y)


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
	var sb := StyleBoxFlat.new()
	sb.bg_color = ARENA_BG_COLOR
	sb.border_color = ARENA_BORDER_COLOR
	sb.set_border_width_all(ARENA_BORDER_WIDTH)
	sb.set_corner_radius_all(ARENA_CORNER_RADIUS)
	_bg_panel.add_theme_stylebox_override("panel", sb)
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
