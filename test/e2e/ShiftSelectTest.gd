extends GdUnitTestSuite
## E2E tests for Shift+Click dice selection by matching face type+value.


func before_test() -> void:
	GameManager.skip_archetype_picker = true
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION
	GameManager.active_modifiers.clear()
	GameManager.reset_run()


func _get_root(runner: GdUnitSceneRunner) -> RollPhase:
	var root: RollPhase = runner.scene() as RollPhase
	root.dice_arena.instant_mode = true
	return root


func _force_face(root: RollPhase, index: int, face_type: DiceFaceData.FaceType, value: int) -> void:
	var face := DiceFaceData.new()
	face.type = face_type
	face.value = value
	root.current_results[index] = face
	root.dice_stopped[index] = (face_type == DiceFaceData.FaceType.STOP)
	root.dice_keep[index] = false
	root.dice_keep_locked[index] = false


func test_shift_click_selects_all_matching_face_type_and_value() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)

	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	# Setup: dice 0,1 = NUMBER 2; dice 2 = NUMBER 1; dice 3 = NUMBER 2; dice 4 = SHIELD 1
	_force_face(root, 0, DiceFaceData.FaceType.NUMBER, 2)
	_force_face(root, 1, DiceFaceData.FaceType.NUMBER, 2)
	_force_face(root, 2, DiceFaceData.FaceType.NUMBER, 1)
	_force_face(root, 3, DiceFaceData.FaceType.NUMBER, 2)
	if GameManager.dice_pool.size() > 4:
		_force_face(root, 4, DiceFaceData.FaceType.SHIELD, 1)
	root._sync_all_dice()
	root._sync_ui()

	# Shift+click die 0 (NUMBER 2) to keep — should select 0, 1, 3 only.
	root.dice_arena.die_shift_clicked.emit(0, true)
	await runner.simulate_frames(1)

	assert_bool(root.dice_keep[0]).is_true()
	assert_bool(root.dice_keep[1]).is_true()
	assert_bool(root.dice_keep[2]).is_false()  # NUMBER 1 — different value
	assert_bool(root.dice_keep[3]).is_true()
	if GameManager.dice_pool.size() > 4:
		assert_bool(root.dice_keep[4]).is_false()  # SHIELD — different type


func test_shift_click_deselects_all_matching() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)

	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	# All dice = NUMBER 3, all kept.
	for i: int in GameManager.dice_pool.size():
		_force_face(root, i, DiceFaceData.FaceType.NUMBER, 3)
		root.dice_keep[i] = true
	root._sync_all_dice()
	root._sync_ui()

	# Shift+click die 0 to deselect — should deselect ALL.
	root.dice_arena.die_shift_clicked.emit(0, false)
	await runner.simulate_frames(1)

	for i: int in GameManager.dice_pool.size():
		assert_bool(root.dice_keep[i]).is_false()


func test_shift_click_skips_locked_dice() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)

	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	# Die 0 = NUMBER 4; die 1 = NUMBER 4 (locked); die 2 = NUMBER 4.
	_force_face(root, 0, DiceFaceData.FaceType.NUMBER, 4)
	_force_face(root, 1, DiceFaceData.FaceType.NUMBER, 4)
	root.dice_keep_locked[1] = true
	root.dice_keep[1] = true
	_force_face(root, 2, DiceFaceData.FaceType.NUMBER, 4)
	root._sync_all_dice()
	root._sync_ui()

	# Shift+click die 0 to deselect — die 1 should remain kept (locked).
	root.dice_arena.die_shift_clicked.emit(0, false)
	await runner.simulate_frames(1)

	assert_bool(root.dice_keep[0]).is_false()
	assert_bool(root.dice_keep[1]).is_true()  # Locked — untouched
	assert_bool(root.dice_keep[2]).is_false()


func test_shift_click_picks_up_stopped_dice_of_same_face() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)

	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	# Die 0 = STOP 0 (stopped); die 1 = STOP 0 (stopped); die 2 = NUMBER 2.
	_force_face(root, 0, DiceFaceData.FaceType.STOP, 0)
	root.dice_stopped[0] = true
	_force_face(root, 1, DiceFaceData.FaceType.STOP, 0)
	root.dice_stopped[1] = true
	_force_face(root, 2, DiceFaceData.FaceType.NUMBER, 2)
	root._sync_all_dice()
	root._sync_ui()

	# Shift+click die 0 to mark matching stopped dice for reroll while preserving stopped state.
	root.dice_arena.die_shift_clicked.emit(0, true)
	await runner.simulate_frames(1)

	assert_bool(root.dice_stopped[0]).is_true()
	assert_bool(root.dice_stopped[1]).is_true()
	assert_bool(root.dice_keep[0]).is_true()
	assert_bool(root.dice_keep[1]).is_true()
	assert_bool(root.dice_keep[2]).is_false()  # Unaffected — different face


func test_shift_click_does_nothing_outside_active_state() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)

	# Don't roll — stay in IDLE state.
	assert_int(root.turn_state).is_equal(RollPhase.TurnState.IDLE)

	# Shift+click should have no effect.
	root.dice_arena.die_shift_clicked.emit(0, true)
	await runner.simulate_frames(1)

	# All dice_keep should still be false.
	for i: int in root.dice_keep.size():
		assert_bool(root.dice_keep[i]).is_false()
