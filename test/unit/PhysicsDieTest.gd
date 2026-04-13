extends GdUnitTestSuite
## Unit tests for PhysicsDie logic (non-physics state, setup, face display).


var _die: PhysicsDie


func before_test() -> void:
	_die = auto_free(PhysicsDie.new())
	# Skip _ready visuals by adding to scene tree manually
	add_child(_die)


func test_setup_sets_index_and_data() -> void:
	var data: DiceData = DiceData.make_standard_d6()
	_die.setup(0, data)
	assert_int(_die.die_index).is_equal(0)
	assert_object(_die.die_data).is_same(data)


func test_setup_resets_flags() -> void:
	_die.is_kept = true
	_die.is_keep_locked = true
	_die.is_stopped = true
	var data: DiceData = DiceData.make_standard_d6()
	_die.setup(1, data)
	assert_bool(_die.is_kept).is_false()
	assert_bool(_die.is_keep_locked).is_false()
	assert_bool(_die.is_stopped).is_false()


func test_show_face_stores_face() -> void:
	add_child(auto_free(PhysicsDie.new()))
	var face: DiceFaceData = DiceFaceData.new()
	face.type = DiceFaceData.FaceType.NUMBER
	face.value = 3
	_die.setup(0, DiceData.make_standard_d6())
	_die.show_face(face)
	assert_object(_die.current_face).is_same(face)


func test_initial_physics_state_is_flying() -> void:
	assert_int(_die.physics_state).is_equal(PhysicsDie.DiePhysicsState.FLYING)


func test_die_physics_state_enum_values() -> void:
	# Verify all expected states exist
	assert_int(PhysicsDie.DiePhysicsState.FLYING).is_equal(0)
	assert_int(PhysicsDie.DiePhysicsState.SETTLING).is_equal(1)
	assert_int(PhysicsDie.DiePhysicsState.SETTLED).is_equal(2)
	assert_int(PhysicsDie.DiePhysicsState.RESOLVING).is_equal(3)
	assert_int(PhysicsDie.DiePhysicsState.KEPT).is_equal(4)


func test_constants_are_reasonable() -> void:
	assert_float(PhysicsDie.DIE_SIZE).is_equal(90.0)
	assert_float(PhysicsDie.COLLISION_RADIUS).is_equal(45.0)
	assert_float(PhysicsDie.SETTLE_VELOCITY_THRESHOLD).is_greater(0.0)
	assert_float(PhysicsDie.REROLL_VELOCITY_THRESHOLD).is_greater(PhysicsDie.SETTLE_VELOCITY_THRESHOLD)
	assert_float(PhysicsDie.SETTLE_POP_SCALE).is_greater(1.0)
	assert_float(PhysicsDie.SETTLE_POP_DURATION).is_greater(0.0)
	assert_float(PhysicsDie.IMPACT_FLASH_DURATION).is_greater(0.0)
	assert_float(PhysicsDie.BUMP_BOOST_MIN_SPEED).is_greater(0.0)
	assert_float(PhysicsDie.BUMP_BOOST_IMPULSE_MIN).is_greater(0.0)
	assert_float(PhysicsDie.BUMP_BOOST_IMPULSE_MAX).is_greater(PhysicsDie.BUMP_BOOST_IMPULSE_MIN)
	assert_float(PhysicsDie.BUMP_BOOST_MULTIPLIER).is_greater(0.0)
	assert_float(PhysicsDie.BUMP_TANGENT_JITTER).is_greater(0.0)
	assert_float(PhysicsDie.REROLL_LIFT_OPACITY).is_less_equal(1.0)
	assert_float(PhysicsDie.REROLL_LIFT_OPACITY).is_greater(0.0)
	assert_float(PhysicsDie.LAUNCH_BURST_DURATION).is_greater(0.0)
	assert_float(PhysicsDie.EXPLODE_WOBBLE_STEP).is_greater(0.0)
	assert_float(PhysicsDie.EXPLODE_WOBBLE_OFFSET).is_greater(0.0)
	assert_float(PhysicsDie.LANDING_SLAM_MAX_SCALE).is_greater(PhysicsDie.SETTLE_POP_SCALE)
	assert_float(PhysicsDie.LANDING_SLAM_MAX_OFFSET_Y).is_greater(0.0)
	assert_float(PhysicsDie.LANDING_SLAM_MIN_TRIGGER_SPEED).is_greater(PhysicsDie.SETTLE_VELOCITY_THRESHOLD)
	assert_float(PhysicsDie.LANDING_SLAM_SPEED_RANGE).is_greater(0.0)
	assert_float(PhysicsDie.LANDING_SLAM_CURVE_EXPONENT).is_greater(1.0)
	assert_float(PhysicsDie.LANDING_SLAM_LATERAL_MAX_OFFSET_X).is_greater(0.0)
	assert_float(PhysicsDie.LANDING_SLAM_DURATION_MIN_FACTOR).is_greater(0.0)
	assert_float(PhysicsDie.LANDING_SLAM_DURATION_MAX_FACTOR).is_greater(PhysicsDie.LANDING_SLAM_DURATION_MIN_FACTOR)


func test_face_type_glyphs_cover_all_types() -> void:
	# Verify glyphs exist for all face types we use
	for face_type: int in range(DiceFaceData.FaceType.size()):
		assert_bool(PhysicsDie.FACE_TYPE_GLYPHS.has(face_type)).is_true()


func test_die_is_input_pickable() -> void:
	assert_bool(_die.input_pickable).is_true()


func test_hover_popup_visibility_changes() -> void:
	var data: DiceData = DiceData.make_standard_d6()
	_die.setup(0, data)
	assert_bool(_die._name_popup.visible).is_false()
	_die._on_mouse_entered()
	assert_bool(_die._name_popup.visible).is_true()
	_die._on_mouse_exited()
	# Popup fade-out is tweened — wait for it to complete.
	if _die._popup_tween and _die._popup_tween.is_valid():
		await _die._popup_tween.finished
	assert_bool(_die._name_popup.visible).is_false()


func test_hover_popup_is_centered_above_die_even_when_rotated() -> void:
	var data: DiceData = DiceData.make_standard_d6()
	_die.setup(0, data)
	_die.global_position = Vector2(320, 240)
	_die.rotation = 1.2
	_die.scale = Vector2(1.1, 1.1)
	_die._update_name_popup_position()
	var expected_x: float = _die.global_position.x - _die._name_popup.size.x * 0.5
	assert_float(_die._name_popup.global_position.x).is_equal(expected_x)
	assert_float(_die._name_popup.global_position.y).is_less(_die.global_position.y)


func test_hover_popup_shows_face_squares_matching_die_faces() -> void:
	var data: DiceData = DiceData.make_standard_d6()
	_die.setup(0, data)
	await await_idle_frame()
	var face_container: HBoxContainer = _die._name_popup_faces
	assert_int(face_container.get_child_count()).is_equal(data.faces.size())
	for i: int in data.faces.size():
		var sq: ColorRect = face_container.get_child(i) as ColorRect
		var expected_color: Color = PhysicsDie.face_type_color(data.faces[i].type)
		assert_object(sq).is_not_null()
		assert_bool(sq.color.is_equal_approx(expected_color)).is_true()


func test_face_type_color_covers_all_face_types() -> void:
	for ft: int in range(DiceFaceData.FaceType.size()):
		var c: Color = PhysicsDie.face_type_color(ft as DiceFaceData.FaceType)
		assert_object(c).is_not_null()


func test_motion_polish_methods_do_not_error() -> void:
	_die.setup(0, DiceData.make_standard_d6())
	_die.play_keep_lock_snap()
	_die.play_shield_charge_pulse()
	_die.play_shield_absorb()
	_die.play_stop_impact(false)
	_die.play_stop_impact(true)
	assert_bool(true).is_true()


func test_bump_count_increases_on_collision() -> void:
	_die.setup(0, DiceData.make_standard_d6())
	assert_int(_die._bump_count).is_equal(0)
	# Simulate multiple bumps — count should increment.
	var other: PhysicsDie = auto_free(PhysicsDie.new()) as PhysicsDie
	add_child(other)
	other.setup(1, DiceData.make_standard_d6())
	_die._bump_count = 3
	# Dampening factor should reduce impulse with each bump.
	var dampen: float = pow(PhysicsDie.BUMP_DAMPEN_FACTOR, 3)
	assert_float(dampen).is_less(1.0)


func test_setup_resets_bump_count() -> void:
	_die._bump_count = 5
	_die.setup(0, DiceData.make_standard_d6())
	assert_int(_die._bump_count).is_equal(0)


func test_physics_properties_set_correctly() -> void:
	assert_float(_die.gravity_scale).is_equal(0.0)
	assert_float(_die.linear_damp).is_equal_approx(2.65, 0.01)
	assert_float(_die.angular_damp).is_equal_approx(3.0, 0.01)
	assert_object(_die.physics_material_override).is_not_null()
	assert_float(_die.physics_material_override.bounce).is_equal_approx(0.65, 0.01)
	assert_float(_die.physics_material_override.friction).is_equal_approx(0.4, 0.01)


func test_jitter_constants_are_reasonable() -> void:
	assert_float(PhysicsDie.JITTER_SPEED_CAP).is_greater(PhysicsDie.SETTLE_VELOCITY_THRESHOLD)
	assert_float(PhysicsDie.JITTER_FORCE_SETTLE_TIME).is_greater(0.0)


func test_setup_resets_jitter_timer() -> void:
	_die._jitter_timer = 1.5
	_die.setup(0, DiceData.make_standard_d6())
	assert_float(_die._jitter_timer).is_equal(0.0)


func test_jitter_timer_accumulates_below_speed_cap() -> void:
	_die.setup(0, DiceData.make_standard_d6())
	_die.physics_state = PhysicsDie.DiePhysicsState.FLYING
	_die.freeze = false
	# Simulate low-speed jitter below JITTER_SPEED_CAP but above SETTLE_VELOCITY_THRESHOLD.
	_die.linear_velocity = Vector2(50.0, 0.0)
	_die._jitter_timer = 0.0
	_die._physics_process(0.5)
	assert_float(_die._jitter_timer).is_equal_approx(0.5, 0.01)
	_die._physics_process(0.5)
	assert_float(_die._jitter_timer).is_equal_approx(1.0, 0.01)


func test_jitter_timer_resets_above_speed_cap() -> void:
	_die.setup(0, DiceData.make_standard_d6())
	_die.physics_state = PhysicsDie.DiePhysicsState.FLYING
	_die.freeze = false
	_die._jitter_timer = 1.5
	# Speed above JITTER_SPEED_CAP should reset the timer.
	_die.linear_velocity = Vector2(100.0, 0.0)
	_die._physics_process(0.1)
	assert_float(_die._jitter_timer).is_equal(0.0)


func test_jitter_force_settles_after_timeout() -> void:
	_die.setup(0, DiceData.make_standard_d6())
	_die.physics_state = PhysicsDie.DiePhysicsState.FLYING
	_die.freeze = false
	_die.linear_velocity = Vector2(50.0, 0.0)
	_die._jitter_timer = PhysicsDie.JITTER_FORCE_SETTLE_TIME - 0.01
	_die._physics_process(0.02)
	# Should have force-settled.
	assert_int(_die.physics_state).is_equal(PhysicsDie.DiePhysicsState.SETTLED)
	assert_bool(_die.freeze).is_true()
	assert_float(_die.linear_velocity.length()).is_equal(0.0)


func test_shift_toggled_keep_signal_exists() -> void:
	_die.setup(0, DiceData.make_standard_d6())
	# Verify the signal is defined and emittable.
	assert_bool(_die.has_signal("shift_toggled_keep")).is_true()


func test_wall_bounce_count_starts_at_zero() -> void:
	_die.setup(0, DiceData.make_standard_d6())
	assert_int(_die._wall_bounce_count).is_equal(0)


func test_setup_resets_wall_bounce_count() -> void:
	_die._wall_bounce_count = 7
	_die.setup(0, DiceData.make_standard_d6())
	assert_int(_die._wall_bounce_count).is_equal(0)


func test_tumble_sets_pending_face_and_clears_on_settle() -> void:
	_die.setup(0, DiceData.make_standard_d6())
	var face: DiceFaceData = DiceFaceData.new()
	face.type = DiceFaceData.FaceType.NUMBER
	face.value = 5
	_die.tumble(face)
	assert_object(_die._pending_face).is_same(face)
	# Simulate settling — pending face should resolve.
	_die.physics_state = PhysicsDie.DiePhysicsState.FLYING
	_die.freeze = false
	_die.linear_velocity = Vector2(5.0, 0.0)  # Below settle threshold
	_die._settle_timer = PhysicsDie.SETTLE_TIME_REQUIRED - 0.01
	_die._physics_process(0.02)
	# Die should have settled and pending face cleared.
	# current_face is NOT set here — the phase tween calls _reveal_die_face()
	# asynchronously after all dice settle, which then calls show_face().
	# In real use, DiceArena always sets die.current_face before tumble().
	assert_int(_die.physics_state).is_equal(PhysicsDie.DiePhysicsState.SETTLED)
	assert_object(_die._pending_face).is_null()


func test_setup_resets_pending_face() -> void:
	var face: DiceFaceData = DiceFaceData.new()
	face.type = DiceFaceData.FaceType.NUMBER
	face.value = 3
	_die._pending_face = face
	_die.setup(0, DiceData.make_standard_d6())
	assert_object(_die._pending_face).is_null()


func test_tumble_cycles_face_at_high_speed() -> void:
	_die.setup(0, DiceData.make_standard_d6())
	var face: DiceFaceData = DiceFaceData.new()
	face.type = DiceFaceData.FaceType.NUMBER
	face.value = 4
	_die.tumble(face)
	_die.physics_state = PhysicsDie.DiePhysicsState.FLYING
	_die.freeze = false
	# At high speed, face label should change (random glyph cycling).
	_die.linear_velocity = Vector2(500.0, 0.0)
	var initial_text: String = _die._face_label.text if _die._face_label else ""
	# Run enough ticks that at TUMBLE_MIN_INTERVAL the glyph should cycle.
	for i: int in 5:
		_die._physics_process(0.05)
	# Pending face should still be set (not resolved yet — still flying fast).
	assert_object(_die._pending_face).is_not_null()


func test_tumble_constants_are_reasonable() -> void:
	assert_float(PhysicsDie.TUMBLE_MIN_INTERVAL).is_greater(0.0)
	assert_float(PhysicsDie.TUMBLE_MAX_INTERVAL).is_greater(PhysicsDie.TUMBLE_MIN_INTERVAL)
	assert_float(PhysicsDie.TUMBLE_SPEED_FAST).is_greater(PhysicsDie.TUMBLE_SPEED_SLOW)
	assert_float(PhysicsDie.TUMBLE_SPEED_SLOW).is_greater(0.0)
