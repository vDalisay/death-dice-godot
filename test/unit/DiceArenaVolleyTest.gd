extends GdUnitTestSuite
## Tests for the dealer's sweep volley throw in DiceArena.


var _arena: DiceArena


func before_test() -> void:
	_arena = auto_free(DiceArena.new())
	add_child(_arena)
	await get_tree().process_frame


func test_volley_constants_are_sensible() -> void:
	assert_float(DiceArena.VOLLEY_DELAY_START).is_greater(DiceArena.VOLLEY_DELAY_END)
	assert_float(DiceArena.VOLLEY_DELAY_END).is_greater(0.0)
	assert_float(DiceArena.VOLLEY_DELAY_JITTER).is_greater_equal(0.0)
	assert_float(DiceArena.VOLLEY_CONE_HALF_ANGLE).is_greater(0.0)
	assert_float(DiceArena.VOLLEY_CONE_HALF_ANGLE).is_less(PI)
	assert_float(DiceArena.VOLLEY_CONE_JITTER).is_greater_equal(0.0)
	assert_float(DiceArena.VOLLEY_EMITTER_JITTER_X).is_greater(0.0)
	assert_float(DiceArena.VOLLEY_EMITTER_JITTER_Y).is_greater(0.0)
	assert_float(DiceArena.REROLL_VOLLEY_DELAY_START).is_greater(DiceArena.REROLL_VOLLEY_DELAY_END)
	assert_float(DiceArena.REROLL_VOLLEY_DELAY_START).is_greater(DiceArena.VOLLEY_DELAY_START)
	assert_float(DiceArena.REROLL_VOLLEY_DELAY_END).is_greater(DiceArena.VOLLEY_DELAY_END)
	assert_float(DiceArena.REROLL_VOLLEY_DELAY_JITTER).is_greater_equal(0.0)
	assert_float(DiceArena.REROLL_VOLLEY_CONE_HALF_ANGLE).is_less(DiceArena.VOLLEY_CONE_HALF_ANGLE)
	assert_float(DiceArena.REROLL_VOLLEY_CONE_JITTER).is_less(DiceArena.VOLLEY_CONE_JITTER)
	assert_float(DiceArena.REROLL_THROW_IMPULSE_MAX).is_less(DiceArena.THROW_IMPULSE_MAX)
	assert_float(DiceArena.REROLL_THROW_IMPULSE_MIN).is_less(DiceArena.REROLL_THROW_IMPULSE_MAX)


func test_volley_delay_acceleration() -> void:
	## Cumulative delay for die N is less than N * VOLLEY_DELAY_START.
	var total: int = 20
	for idx: int in [5, 10, 15, 19]:
		var cumulative: float = _arena.volley_cumulative_delay(idx, total)
		var linear: float = float(idx) * DiceArena.VOLLEY_DELAY_START
		assert_float(cumulative).is_less(linear)


func test_reroll_delay_profile_is_slower_than_opening_volley() -> void:
	var total: int = 8
	for idx: int in [1, 3, 5, 7]:
		var reroll_delay: float = _arena.reroll_cumulative_delay(idx, total)
		var opening_delay: float = _arena.volley_cumulative_delay(idx, total)
		assert_float(reroll_delay).is_greater(opening_delay)


func test_volley_emitter_is_in_lower_arena() -> void:
	var emitter: Vector2 = _arena._volley_emitter()
	assert_float(emitter.x).is_equal_approx(DiceArena.ARENA_WIDTH / 2.0, 1.0)
	assert_float(emitter.y).is_greater(DiceArena.ARENA_HEIGHT * 0.5)


func test_instant_mode_still_works() -> void:
	_arena.instant_mode = true
	var pool: Array[DiceData] = []
	for _i: int in 8:
		pool.append(DiceData.make_standard_d6())
	_arena.throw_dice(pool)
	assert_int(_arena.get_die_count()).is_equal(8)
	for i: int in 8:
		var die: PhysicsDie = _arena.get_die(i)
		assert_bool(die.freeze).is_true()
		assert_int(die.physics_state).is_equal(PhysicsDie.DiePhysicsState.SETTLED)
		assert_object(die.current_face).is_not_null()


func test_volley_launch_creates_die() -> void:
	## Calling _volley_launch for index 0 should add one die.
	_arena._pending_pool = [DiceData.make_standard_d6(), DiceData.make_standard_d6()]
	assert_int(_arena.get_die_count()).is_equal(0)
	_arena._volley_launch(0)
	assert_int(_arena.get_die_count()).is_equal(1)
	var die: PhysicsDie = _arena.get_die(0)
	assert_object(die).is_not_null()
	assert_int(die.die_index).is_equal(0)
	assert_object(die.current_face).is_not_null()


func test_volley_launch_out_of_bounds_is_safe() -> void:
	_arena._pending_pool = [DiceData.make_standard_d6()]
	_arena._volley_launch(5)
	assert_int(_arena.get_die_count()).is_equal(0)
	_arena._volley_launch(-1)
	assert_int(_arena.get_die_count()).is_equal(0)


func test_volley_cone_direction_spread() -> void:
	## First and last die in a large pool should be aimed at opposite
	## sides of the cone, giving measurable angular separation.
	var pool: Array[DiceData] = []
	for _i: int in 20:
		pool.append(DiceData.make_standard_d6())
	_arena._pending_pool = pool

	# Launch first die and record its position + velocity direction.
	_arena._volley_launch(0)
	var first_die: PhysicsDie = _arena.get_die(0)
	var first_angle: float = first_die.linear_velocity.angle()

	# Launch last die.
	_arena._volley_launch(19)
	# It's the second die added, so index 1 in _dice array.
	var last_die: PhysicsDie = _arena._dice[1]
	var last_angle: float = last_die.linear_velocity.angle()

	# The angular difference should be significant (at least half the cone width).
	var angle_diff: float = absf(angle_difference(first_angle, last_angle))
	assert_float(angle_diff).is_greater(DiceArena.VOLLEY_CONE_HALF_ANGLE * 0.5)


func test_reroll_unaffected_by_volley() -> void:
	## After a volley throw, reroll_dice should still work with the old flow.
	_arena.instant_mode = true
	var pool: Array[DiceData] = []
	for _i: int in 5:
		pool.append(DiceData.make_standard_d6())
	_arena.throw_dice(pool)
	assert_int(_arena.get_die_count()).is_equal(5)

	var old_face: DiceFaceData = _arena.get_die(0).current_face
	_arena.reroll_dice([0], pool)
	# Die 0 should have a new face (it was rerolled).
	assert_object(_arena.get_die(0).current_face).is_not_null()
	# Die count unchanged.
	assert_int(_arena.get_die_count()).is_equal(5)


func test_begin_reroll_launch_sequence_adds_lift_phase_before_throw() -> void:
	_arena.instant_mode = true
	var pool: Array[DiceData] = [DiceData.make_standard_d6()]
	_arena.throw_dice(pool)
	var die: PhysicsDie = _arena.get_die(0)
	var face: DiceFaceData = pool[0].roll()

	_arena._begin_reroll_launch_sequence(die, face, 0, 1)

	assert_int(die.physics_state).is_equal(PhysicsDie.DiePhysicsState.RESOLVING)
	assert_bool(die.freeze).is_true()
	assert_float(die.linear_velocity.length()).is_equal(0.0)


func test_reroll_volley_launch_uses_controlled_speed_range() -> void:
	_arena.instant_mode = true
	var pool: Array[DiceData] = [DiceData.make_standard_d6()]
	_arena.throw_dice(pool)
	var die: PhysicsDie = _arena.get_die(0)
	var face: DiceFaceData = pool[0].roll()

	_arena._reroll_volley_launch(die, face, 0, 3)

	var speed: float = die.linear_velocity.length()
	assert_int(die.physics_state).is_equal(PhysicsDie.DiePhysicsState.FLYING)
	assert_bool(die.freeze).is_false()
	assert_float(speed).is_greater_equal(DiceArena.REROLL_THROW_IMPULSE_MIN)
	assert_float(speed).is_less_equal(DiceArena.REROLL_THROW_IMPULSE_MAX)
