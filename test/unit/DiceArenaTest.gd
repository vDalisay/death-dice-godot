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
	_arena.instant_mode = true
	var pool: Array[DiceData] = [
		DiceData.make_standard_d6(),
		DiceData.make_standard_d6(),
		DiceData.make_standard_d6(),
	]
	_arena.throw_dice(pool)
	assert_int(_arena.get_die_count()).is_equal(3)


func test_get_die_returns_correct_die() -> void:
	_arena.instant_mode = true
	var pool: Array[DiceData] = [DiceData.make_standard_d6()]
	_arena.throw_dice(pool)
	var die: PhysicsDie = _arena.get_die(0)
	assert_object(die).is_not_null()
	assert_int(die.die_index).is_equal(0)


func test_get_die_out_of_bounds_returns_null() -> void:
	assert_object(_arena.get_die(0)).is_null()
	assert_object(_arena.get_die(-1)).is_null()


func test_get_results_returns_faces() -> void:
	_arena.instant_mode = true
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
	_arena.instant_mode = true
	var pool: Array[DiceData] = [DiceData.make_standard_d6()]
	_arena.throw_dice(pool)
	assert_int(_arena.get_die_count()).is_equal(1)
	_arena.reset()
	assert_int(_arena.get_die_count()).is_equal(0)


func test_lock_die_freezes_physics() -> void:
	_arena.instant_mode = true
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
	assert_float(DiceArena.REROLL_EXIT_DURATION).is_greater(0.0)
	assert_float(DiceArena.THROW_STAGGER_SWEEP).is_greater(0.0)
	assert_float(DiceArena.THROW_STAGGER_SPAWN_SWEEP_X).is_greater(0.0)
	assert_float(DiceArena.THROW_STAGGER_TARGET_SWEEP_X).is_greater(0.0)
	assert_float(DiceArena.THROW_STAGGER_MAGNITUDE_VARIANCE).is_greater(0.0)
	assert_float(DiceArena.CONTAINMENT_MIN_BOUNCE_SPEED).is_greater(0.0)
	assert_float(DiceArena.CONTAINMENT_INWARD_NUDGE).is_greater(0.0)
	assert_float(DiceArena.SOFT_SEPARATION_RADIUS_MULT).is_greater(1.0)
	assert_float(DiceArena.SOFT_SEPARATION_MAX_SPEED).is_greater(0.0)
	assert_float(DiceArena.SOFT_SEPARATION_PUSH).is_greater(0.0)


func test_arena_centers_in_viewport() -> void:
	_arena._update_centering()
	var viewport_size: Vector2 = Vector2(_arena.get_viewport().size)
	var fit_scale: float = _arena._calculate_fit_scale(viewport_size)
	var expected: Vector2 = (viewport_size - Vector2(DiceArena.ARENA_WIDTH, DiceArena.ARENA_HEIGHT) * fit_scale) * 0.5
	assert_float(_arena.scale.x).is_equal_approx(fit_scale, 0.0001)
	assert_float(_arena.scale.y).is_equal_approx(fit_scale, 0.0001)
	assert_float(_arena.position.x).is_equal_approx(expected.x, 0.001)
	assert_float(_arena.position.y).is_equal_approx(expected.y, 0.001)
	assert_float(DiceArena.ARENA_WIDTH * _arena.scale.x).is_less_equal(viewport_size.x + 0.1)
	assert_float(DiceArena.ARENA_HEIGHT * _arena.scale.y).is_less_equal(viewport_size.y + 0.1)


func test_arena_scales_down_to_fit_small_viewport() -> void:
	var subviewport: SubViewport = auto_free(SubViewport.new())
	subviewport.size = Vector2i(960, 260)
	add_child(subviewport)
	var small_arena: DiceArena = auto_free(DiceArena.new())
	subviewport.add_child(small_arena)
	await get_tree().process_frame

	small_arena._update_centering()

	assert_float(small_arena.scale.x).is_less(1.0)
	assert_float(small_arena.scale.y).is_less(1.0)
	assert_float(DiceArena.ARENA_WIDTH * small_arena.scale.x).is_less_equal(float(subviewport.size.x) + 0.1)
	assert_float(DiceArena.ARENA_HEIGHT * small_arena.scale.y).is_less_equal(float(subviewport.size.y) + 0.1)


func test_throw_dice_spread_avoids_overlap() -> void:
	_arena.instant_mode = true
	var pool: Array[DiceData] = []
	for _i: int in 18:
		pool.append(DiceData.make_standard_d6())
	_arena.throw_dice(pool)
	var min_allowed: float = PhysicsDie.COLLISION_RADIUS * 1.2
	for i: int in _arena.get_die_count():
		var a: PhysicsDie = _arena.get_die(i)
		for j: int in range(i + 1, _arena.get_die_count()):
			var b: PhysicsDie = _arena.get_die(j)
			assert_float(a.position.distance_to(b.position)).is_greater_equal(min_allowed)


func test_large_pool_spawn_positions_stay_centered_and_in_bounds() -> void:
	var positions: Array[Vector2] = _arena._build_spawn_positions(DiceArena.SpawnOrigin.CENTER_BOTTOM, 30)
	assert_int(positions.size()).is_equal(30)

	var arena_rect: Rect2 = _arena.get_arena_rect()
	var min_x: float = arena_rect.position.x + PhysicsDie.COLLISION_RADIUS
	var max_x: float = arena_rect.end.x - PhysicsDie.COLLISION_RADIUS
	var min_y: float = arena_rect.position.y + PhysicsDie.COLLISION_RADIUS
	var max_y: float = arena_rect.end.y - PhysicsDie.COLLISION_RADIUS
	var average_x: float = 0.0

	for pos: Vector2 in positions:
		average_x += pos.x
		assert_float(pos.x).is_greater_equal(min_x)
		assert_float(pos.x).is_less_equal(max_x)
		assert_float(pos.y).is_greater_equal(min_y)
		assert_float(pos.y).is_less_equal(max_y)

	average_x /= float(positions.size())
	assert_float(average_x).is_equal_approx(DiceArena.ARENA_WIDTH * 0.5, 0.1)


func test_detonate_around_returns_hits_within_radius() -> void:
	var face: DiceFaceData = DiceFaceData.new()
	face.type = DiceFaceData.FaceType.NUMBER
	face.value = 2
	_arena.spawn_settled_die(0, DiceData.make_standard_d6(), face, Vector2(200.0, 200.0))
	_arena.spawn_settled_die(1, DiceData.make_standard_d6(), face, Vector2(240.0, 200.0))
	_arena.spawn_settled_die(2, DiceData.make_standard_d6(), face, Vector2(420.0, 200.0))

	var hit_indices: Array[int] = _arena.detonate_around(0, 70.0)

	assert_bool(hit_indices.has(1)).is_true()
	assert_bool(hit_indices.has(0)).is_false()
	assert_bool(hit_indices.has(2)).is_false()


func test_detonate_around_is_seed_reproducible_for_overlapping_dice() -> void:
	GameManager.restore_run_identity("detonate-seed", true, 1)
	var face: DiceFaceData = DiceFaceData.new()
	face.type = DiceFaceData.FaceType.NUMBER
	face.value = 2
	_arena.spawn_settled_die(0, DiceData.make_standard_d6(), face, Vector2(260.0, 260.0))
	_arena.spawn_settled_die(1, DiceData.make_standard_d6(), face, Vector2(260.0, 260.0))

	_arena.detonate_around(0, 80.0)
	var first_position: Vector2 = _arena.get_die(1).position

	_arena.reset()
	GameManager.restore_run_identity("detonate-seed", true, 1)
	_arena.spawn_settled_die(0, DiceData.make_standard_d6(), face, Vector2(260.0, 260.0))
	_arena.spawn_settled_die(1, DiceData.make_standard_d6(), face, Vector2(260.0, 260.0))

	_arena.detonate_around(0, 80.0)
	var second_position: Vector2 = _arena.get_die(1).position

	assert_float(first_position.x).is_equal_approx(second_position.x, 0.001)
	assert_float(first_position.y).is_equal_approx(second_position.y, 0.001)
