extends GdUnitTestSuite
## Verifies continue-run resume checkpoints always restore to a fresh pre-roll turn.

const MainScene: PackedScene = preload("res://Scenes/Main.tscn")


func before_test() -> void:
	GameManager.skip_archetype_picker = true
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION
	GameManager.reset_run()


func after_test() -> void:
	GameManager.reset_run()


func test_build_roll_phase_state_for_turn_surface_is_pre_roll_checkpoint() -> void:
	var root: RollPhase = auto_free(MainScene.instantiate()) as RollPhase
	add_child(root)
	await await_idle_frame()

	root._resume_surface = RollPhase.RESUME_SURFACE_TURN
	root.turn_state = RollPhase.TurnState.ACTIVE
	root.accumulated_stop_count = 3
	root.accumulated_shield_count = 1
	root._reroll_count = 2
	GameManager.set_held_stop_count(3)

	var die_count: int = GameManager.dice_pool.size()
	var face := DiceFaceData.new()
	face.type = DiceFaceData.FaceType.NUMBER
	face.value = 2

	root.current_results.resize(die_count)
	root.dice_stopped.resize(die_count)
	root.dice_keep.resize(die_count)
	root.dice_keep_locked.resize(die_count)
	root._die_reroll_counts.resize(die_count)
	for i: int in die_count:
		root.current_results[i] = face
		root.dice_stopped[i] = true
		root.dice_keep[i] = true
		root.dice_keep_locked[i] = true
		root._die_reroll_counts[i] = 2

	var state: Dictionary = root._build_roll_phase_state()
	assert_int(int(state.get("turn_state", -1))).is_equal(RollPhase.TurnState.IDLE)
	assert_int(int(state.get("accumulated_stop_count", -1))).is_equal(0)
	assert_int(int(state.get("accumulated_shield_count", -1))).is_equal(0)
	assert_int(int(state.get("reroll_count", -1))).is_equal(0)

	var saved_results: Array = state.get("current_results", []) as Array
	assert_int(saved_results.size()).is_equal(die_count)
	for saved_face: Variant in saved_results:
		assert_bool(saved_face is Dictionary).is_true()
		assert_int((saved_face as Dictionary).size()).is_equal(0)

	for keep_flag: Variant in (state.get("dice_keep", []) as Array):
		assert_bool(bool(keep_flag)).is_false()
	for stopped_flag: Variant in (state.get("dice_stopped", []) as Array):
		assert_bool(bool(stopped_flag)).is_false()


func test_restore_turn_surface_resets_to_fresh_idle_turn() -> void:
	var root: RollPhase = auto_free(MainScene.instantiate()) as RollPhase
	add_child(root)
	await await_idle_frame()

	root.dice_arena.instant_mode = true
	root.turn_state = RollPhase.TurnState.ACTIVE
	root.accumulated_stop_count = 2
	root.accumulated_shield_count = 1
	root._reroll_count = 1
	GameManager.set_held_stop_count(2)

	var die_count: int = GameManager.dice_pool.size()
	var face := DiceFaceData.new()
	face.type = DiceFaceData.FaceType.NUMBER
	face.value = 3
	root.current_results.resize(die_count)
	root.dice_stopped.resize(die_count)
	root.dice_keep.resize(die_count)
	root.dice_keep_locked.resize(die_count)
	root._die_reroll_counts.resize(die_count)
	for i: int in die_count:
		root.current_results[i] = face
		root.dice_stopped[i] = true
		root.dice_keep[i] = true
		root.dice_keep_locked[i] = true
		root._die_reroll_counts[i] = 1

	if root.dice_arena.all_dice_settled.is_connected(root._on_all_dice_settled):
		root.dice_arena.all_dice_settled.disconnect(root._on_all_dice_settled)
	var typed_pool: Array[DiceData] = []
	for die_entry: Variant in GameManager.dice_pool:
		if die_entry is DiceData:
			typed_pool.append(die_entry as DiceData)
	root.dice_arena.throw_dice(typed_pool)
	assert_int(root.dice_arena.get_die_count()).is_greater(0)

	root._restore_turn_surface()
	await await_idle_frame()

	assert_int(root.turn_state).is_equal(RollPhase.TurnState.IDLE)
	assert_int(root.accumulated_stop_count).is_equal(0)
	assert_int(root.accumulated_shield_count).is_equal(0)
	assert_int(root._reroll_count).is_equal(0)
	assert_int(GameManager.held_stop_count).is_equal(0)
	assert_int(root.dice_arena.get_die_count()).is_equal(0)
	assert_bool(root.roll_button.disabled).is_false()
	assert_bool(root.bank_button.disabled).is_true()
