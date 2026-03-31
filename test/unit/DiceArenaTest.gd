extends GdUnitTestSuite
## Unit tests for DiceArena API (spawning, results, queries).


var _arena: DiceArena


func before_test() -> void:
	_arena = auto_free(DiceArena.new())
	add_child(_arena)
	# Let _ready build background and walls
	await get_tree().process_frame


func test_arena_starts_empty() -> void:
	assert_int(_arena.get_die_count()).is_equal(0)


func test_arena_rect_dimensions() -> void:
	var rect: Rect2 = _arena.get_arena_rect()
	# get_arena_rect returns interior (minus wall thickness on each side)
	var expected_w: float = DiceArena.ARENA_WIDTH - DiceArena.WALL_THICKNESS * 2
	var expected_h: float = DiceArena.ARENA_HEIGHT - DiceArena.WALL_THICKNESS * 2
	assert_float(rect.size.x).is_equal(expected_w)
	assert_float(rect.size.y).is_equal(expected_h)


func test_throw_dice_creates_correct_count() -> void:
	var pool: Array[DiceData] = [
		DiceData.make_standard_d6(),
		DiceData.make_standard_d6(),
		DiceData.make_standard_d6(),
	]
	_arena.throw_dice(pool)
	assert_int(_arena.get_die_count()).is_equal(3)


func test_get_die_returns_correct_die() -> void:
	var pool: Array[DiceData] = [DiceData.make_standard_d6()]
	_arena.throw_dice(pool)
	var die: PhysicsDie = _arena.get_die(0)
	assert_object(die).is_not_null()
	assert_int(die.die_index).is_equal(0)


func test_get_die_out_of_bounds_returns_null() -> void:
	assert_object(_arena.get_die(0)).is_null()
	assert_object(_arena.get_die(-1)).is_null()


func test_get_results_returns_faces() -> void:
	var pool: Array[DiceData] = [
		DiceData.make_standard_d6(),
		DiceData.make_standard_d6(),
	]
	_arena.throw_dice(pool)
	var results: Array[DiceFaceData] = _arena.get_results()
	assert_int(results.size()).is_equal(2)
	# Each result should be a DiceFaceData (or null before settling)
	for face: DiceFaceData in results:
		# Faces are set during throw_dice via pool[i].roll()
		assert_object(face).is_not_null()


func test_reset_clears_all_dice() -> void:
	var pool: Array[DiceData] = [DiceData.make_standard_d6()]
	_arena.throw_dice(pool)
	assert_int(_arena.get_die_count()).is_equal(1)
	_arena.reset()
	assert_int(_arena.get_die_count()).is_equal(0)


func test_lock_die_freezes_physics() -> void:
	var pool: Array[DiceData] = [DiceData.make_standard_d6()]
	_arena.throw_dice(pool)
	_arena.lock_die(0)
	var die: PhysicsDie = _arena.get_die(0)
	assert_bool(die.freeze).is_true()
	assert_int(die.physics_state).is_equal(PhysicsDie.DiePhysicsState.KEPT)


func test_constants_are_sensible() -> void:
	assert_float(DiceArena.ARENA_WIDTH).is_greater(0.0)
	assert_float(DiceArena.ARENA_HEIGHT).is_greater(0.0)
	assert_float(DiceArena.THROW_IMPULSE_MAX).is_greater(DiceArena.THROW_IMPULSE_MIN)
	assert_float(DiceArena.WALL_THICKNESS).is_greater(0.0)
	assert_float(DiceArena.BOUNDARY_GLOW_HIT_GAIN).is_greater(0.0)
	assert_float(DiceArena.BOUNDARY_GLOW_DECAY_PER_SEC).is_greater(0.0)
	assert_float(DiceArena.THROW_STAGGER_RANDOM_MAX).is_greater_equal(0.0)
	assert_float(DiceArena.REROLL_LIFT_RANDOM_MAX).is_greater_equal(0.0)
	assert_float(DiceArena.THROW_STAGGER_SWEEP).is_greater(0.0)
	assert_float(DiceArena.THROW_STAGGER_SPAWN_SWEEP_X).is_greater(0.0)
	assert_float(DiceArena.THROW_STAGGER_TARGET_SWEEP_X).is_greater(0.0)
	assert_float(DiceArena.THROW_STAGGER_MAGNITUDE_VARIANCE).is_greater(0.0)
	assert_float(DiceArena.CONTAINMENT_MIN_BOUNCE_SPEED).is_greater(0.0)
	assert_float(DiceArena.CONTAINMENT_INWARD_NUDGE).is_greater(0.0)
	assert_float(DiceArena.SOFT_SEPARATION_RADIUS_MULT).is_greater(1.0)
	assert_float(DiceArena.SOFT_SEPARATION_MAX_SPEED).is_greater(0.0)
	assert_float(DiceArena.SOFT_SEPARATION_PUSH).is_greater(0.0)


func test_cone_volley_constants_are_sensible() -> void:
	assert_float(DiceArena.CONE_HALF_ANGLE_DEG).is_greater(0.0)
	assert_float(DiceArena.CONE_HALF_ANGLE_DEG).is_less(45.0)
	assert_float(DiceArena.CONE_CADENCE_START).is_greater(DiceArena.CONE_CADENCE_END_SMALL)
	assert_float(DiceArena.CONE_CADENCE_END_SMALL).is_greater(DiceArena.CONE_CADENCE_END_LARGE)
	assert_float(DiceArena.CONE_IMPULSE_MAX).is_greater(DiceArena.CONE_IMPULSE_MIN)
	assert_int(DiceArena.CONE_AIRBORNE_SOFT_CAP).is_greater(0)
	assert_float(DiceArena.CONE_AIRBORNE_STRETCH).is_greater(1.0)
	assert_int(DiceArena.CONE_MICRO_BURST_SIZE).is_greater_equal(2)


func test_cone_cadence_accelerates() -> void:
	var first: float = _arena._cone_cadence(0, 20)
	var mid: float = _arena._cone_cadence(10, 20)
	var last: float = _arena._cone_cadence(19, 20)
	assert_float(first).is_greater(mid)
	assert_float(mid).is_greater(last)


func test_cone_emitter_is_lower_center() -> void:
	var emitter: Vector2 = _arena._cone_emitter_position()
	assert_float(emitter.x).is_equal_approx(DiceArena.ARENA_WIDTH * 0.5, 1.0)
	assert_float(emitter.y).is_greater(DiceArena.ARENA_HEIGHT * 0.5)


func test_micro_burst_never_on_first_die() -> void:
	## First die should always be solo regardless of pool size.
	for _i: int in 50:
		assert_bool(_arena._should_micro_burst(0, 30)).is_false()


func test_micro_burst_never_for_small_pools() -> void:
	## Pools <= 8 should never burst.
	for _i: int in 50:
		for idx: int in range(1, 8):
			assert_bool(_arena._should_micro_burst(idx, 8)).is_false()


func test_default_throw_pattern_is_cone_volley() -> void:
	assert_int(_arena.throw_pattern).is_equal(DiceArena.ThrowPattern.CONE_VOLLEY)


func test_cone_volley_creates_correct_die_count() -> void:
	var pool: Array[DiceData] = []
	for _i: int in 12:
		pool.append(DiceData.make_standard_d6())
	_arena.instant_mode = true
	_arena.throw_dice(pool)
	assert_int(_arena.get_die_count()).is_equal(12)


func test_arena_centers_in_viewport() -> void:
	_arena._update_centering()
	var viewport_size: Vector2 = Vector2(_arena.get_viewport().size)
	var expected: Vector2 = (viewport_size - Vector2(DiceArena.ARENA_WIDTH, DiceArena.ARENA_HEIGHT)) * 0.5
	assert_float(_arena.position.x).is_equal(expected.x)
	assert_float(_arena.position.y).is_equal(expected.y)


func test_throw_dice_spread_avoids_overlap() -> void:
	_arena.throw_pattern = DiceArena.ThrowPattern.SPREAD
	var pool: Array[DiceData] = []
	for _i: int in 18:
		pool.append(DiceData.make_standard_d6())
	_arena.throw_dice(pool)
	var min_allowed: float = PhysicsDie.COLLISION_RADIUS * 2.0
	for i: int in _arena.get_die_count():
		var a: PhysicsDie = _arena.get_die(i)
		for j: int in range(i + 1, _arena.get_die_count()):
			var b: PhysicsDie = _arena.get_die(j)
			assert_float(a.position.distance_to(b.position)).is_greater_equal(min_allowed)
