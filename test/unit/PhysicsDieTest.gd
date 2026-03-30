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
	for face_type: int in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]:
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
	assert_bool(_die._name_popup.visible).is_false()


func test_motion_polish_methods_do_not_error() -> void:
	_die.setup(0, DiceData.make_standard_d6())
	_die.play_keep_lock_snap()
	_die.play_shield_absorb()
	_die.play_stop_impact(false)
	_die.play_stop_impact(true)
	assert_bool(true).is_true()
