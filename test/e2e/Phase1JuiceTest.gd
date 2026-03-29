extends GdUnitTestSuite
## Tests for Phase 1 juice features: per-die scoring, status messages,
## and auto-advance behavior.


func before_test() -> void:
	GameManager.skip_archetype_picker = true
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION
	GameManager.active_modifiers.clear()
	GameManager.reset_run()


# ---------------------------------------------------------------------------
# Per-die score breakdown (_get_per_die_scores via scene)
# ---------------------------------------------------------------------------

func _setup_scene(runner: GdUnitSceneRunner) -> RollPhase:
	var root: RollPhase = runner.scene() as RollPhase
	return root


func _make_face(type: DiceFaceData.FaceType, value: int) -> DiceFaceData:
	var face := DiceFaceData.new()
	face.type = type
	face.value = value
	return face


func _force_clean_state(root: RollPhase) -> void:
	var pool_size: int = GameManager.dice_pool.size()
	root.accumulated_stop_count = 0
	for i: int in pool_size:
		root.dice_stopped[i] = false
		root.dice_keep[i] = false
		root.dice_keep_locked[i] = false
		root.current_results[i] = _make_face(DiceFaceData.FaceType.NUMBER, 1)


func test_per_die_scores_simple_numbers() -> void:
	## Each NUMBER die should contribute its value × 1 (no multiplier).
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	_force_clean_state(root)
	root.current_results[0] = _make_face(DiceFaceData.FaceType.NUMBER, 3)
	root.current_results[1] = _make_face(DiceFaceData.FaceType.NUMBER, 5)
	root.current_results[2] = _make_face(DiceFaceData.FaceType.NUMBER, 2)
	root.current_results[3] = _make_face(DiceFaceData.FaceType.BLANK, 0)
	root.current_results[4] = _make_face(DiceFaceData.FaceType.NUMBER, 4)

	var scores: Array[int] = root._get_per_die_scores()
	assert_int(scores[0]).is_equal(3)
	assert_int(scores[1]).is_equal(5)
	assert_int(scores[2]).is_equal(2)
	assert_int(scores[3]).is_equal(0)
	assert_int(scores[4]).is_equal(4)


func test_per_die_scores_with_multiply_left() -> void:
	## MULTIPLY_LEFT should multiply the left neighbor's score.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	_force_clean_state(root)
	root.current_results[0] = _make_face(DiceFaceData.FaceType.NUMBER, 5)
	root.current_results[1] = _make_face(DiceFaceData.FaceType.MULTIPLY_LEFT, 2)
	root.current_results[2] = _make_face(DiceFaceData.FaceType.NUMBER, 3)
	root.current_results[3] = _make_face(DiceFaceData.FaceType.NUMBER, 1)
	root.current_results[4] = _make_face(DiceFaceData.FaceType.NUMBER, 1)
	root.dice_keep_locked[1] = true

	var scores: Array[int] = root._get_per_die_scores()
	# Die 0 = 5 × 2 (MULTIPLY_LEFT from die 1) = 10
	assert_int(scores[0]).is_equal(10)
	# Die 1 = 0 (MULTIPLY_LEFT contributes no base score itself)
	assert_int(scores[1]).is_equal(0)
	assert_int(scores[2]).is_equal(3)


func test_per_die_scores_with_global_multiply() -> void:
	## MULTIPLY face should multiply ALL per-die scores.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	_force_clean_state(root)
	root.current_results[0] = _make_face(DiceFaceData.FaceType.NUMBER, 3)
	root.current_results[1] = _make_face(DiceFaceData.FaceType.MULTIPLY, 2)
	root.current_results[2] = _make_face(DiceFaceData.FaceType.NUMBER, 4)
	root.current_results[3] = _make_face(DiceFaceData.FaceType.NUMBER, 1)
	root.current_results[4] = _make_face(DiceFaceData.FaceType.NUMBER, 2)
	root.dice_keep_locked[1] = true

	var scores: Array[int] = root._get_per_die_scores()
	# All scores doubled by x2 multiplier.
	assert_int(scores[0]).is_equal(6)   # 3 × 2
	assert_int(scores[1]).is_equal(0)   # MULTIPLY itself = 0
	assert_int(scores[2]).is_equal(8)   # 4 × 2
	assert_int(scores[3]).is_equal(2)   # 1 × 2
	assert_int(scores[4]).is_equal(4)   # 2 × 2


func test_per_die_scores_skips_stopped() -> void:
	## Stopped dice should contribute 0.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	_force_clean_state(root)
	root.current_results[0] = _make_face(DiceFaceData.FaceType.NUMBER, 5)
	root.current_results[1] = _make_face(DiceFaceData.FaceType.STOP, 0)
	root.dice_stopped[1] = true

	var scores: Array[int] = root._get_per_die_scores()
	assert_int(scores[0]).is_equal(5)
	assert_int(scores[1]).is_equal(0)


func test_per_die_scores_sum_equals_turn_score() -> void:
	## Sum of per-die scores must always equal _calculate_turn_score().
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	_force_clean_state(root)
	root.current_results[0] = _make_face(DiceFaceData.FaceType.NUMBER, 3)
	root.current_results[1] = _make_face(DiceFaceData.FaceType.MULTIPLY_LEFT, 2)
	root.current_results[2] = _make_face(DiceFaceData.FaceType.MULTIPLY, 3)
	root.current_results[3] = _make_face(DiceFaceData.FaceType.AUTO_KEEP, 4)
	root.current_results[4] = _make_face(DiceFaceData.FaceType.STOP, 0)
	root.dice_stopped[4] = true
	root.dice_keep_locked[1] = true
	root.dice_keep_locked[2] = true
	root.dice_keep_locked[3] = true

	var per_die: Array[int] = root._get_per_die_scores()
	var per_die_sum: int = 0
	for s: int in per_die:
		per_die_sum += s
	var turn_score: int = root._calculate_turn_score()
	assert_int(per_die_sum).is_equal(turn_score)


# ---------------------------------------------------------------------------
# CLOSE CALL / CLEAN ROLL status message conditions
# ---------------------------------------------------------------------------

func test_close_call_at_threshold_minus_one() -> void:
	## One stop away from bust on turn 2+ should show CLOSE CALL.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	# Force to turn 2, threshold = 4. Set 3 stops (threshold - 1).
	_force_clean_state(root)
	root.turn_number = 2
	root.accumulated_stop_count = 0

	var stop_face := _make_face(DiceFaceData.FaceType.STOP, 0)
	root.current_results[0] = stop_face
	root.current_results[1] = stop_face
	root.current_results[2] = stop_face

	var all_indices: Array[int] = []
	for i: int in GameManager.dice_pool.size():
		all_indices.append(i)
	root._process_roll_results(all_indices)
	await runner.simulate_frames(2)

	# Should show CLOSE CALL and remain ACTIVE (not bust).
	assert_int(root.turn_state).is_equal(RollPhase.TurnState.ACTIVE)
	assert_str(root.hud.status_label.text).contains("CLOSE CALL")


func test_close_call_not_on_turn_1() -> void:
	## Turn 1 should show the turn-1 immunity message, not CLOSE CALL.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	_force_clean_state(root)
	root.turn_number = 1
	root.accumulated_stop_count = 0

	# 3 stops on turn 1 (threshold is 4, so 3 = threshold - 1).
	var stop_face := _make_face(DiceFaceData.FaceType.STOP, 0)
	root.current_results[0] = stop_face
	root.current_results[1] = stop_face
	root.current_results[2] = stop_face

	var all_indices: Array[int] = []
	for i: int in GameManager.dice_pool.size():
		all_indices.append(i)
	root._process_roll_results(all_indices)
	await runner.simulate_frames(2)

	# On turn 1, CLOSE CALL should not appear (turn 1 immunity has its own msg).
	assert_str(root.hud.status_label.text).not_contains("CLOSE CALL")


func test_clean_roll_on_zero_stops() -> void:
	## Rolling with zero stops should show CLEAN ROLL.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	_force_clean_state(root)
	root.accumulated_stop_count = 0

	# All dice are NUMBER (no stops).
	var all_indices: Array[int] = []
	for i: int in GameManager.dice_pool.size():
		all_indices.append(i)
	root._process_roll_results(all_indices)
	await runner.simulate_frames(2)

	assert_str(root.hud.status_label.text).contains("CLEAN ROLL")


# ---------------------------------------------------------------------------
# Auto-advance after bank / bust
# ---------------------------------------------------------------------------

func test_auto_advance_after_bank() -> void:
	## After banking, the turn should auto-advance to IDLE without user input.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	_force_clean_state(root)
	root.bank_button.pressed.emit()
	await runner.simulate_frames(2)

	assert_int(root.turn_state).is_equal(RollPhase.TurnState.BANKED)

	# The auto-advance uses get_tree().create_timer(1.5). We poll with
	# simulate_frames(1, delta_milli) which advances the SceneTree clock
	# by delta_milli each tick — enough for the timer to fire.
	for _i: int in 20:
		await runner.simulate_frames(1, 100)
	await runner.simulate_frames(5)

	assert_int(root.turn_state).is_equal(RollPhase.TurnState.IDLE)


func test_auto_advance_after_bust() -> void:
	## After busting, the turn should auto-advance to IDLE without user input.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	# Force bust: turn 4 with 4 stops (Caution archetype immune through turn 3).
	_force_clean_state(root)
	root.turn_number = 4
	root.accumulated_stop_count = 0
	var stop_face := _make_face(DiceFaceData.FaceType.STOP, 0)
	for i: int in mini(4, GameManager.dice_pool.size()):
		root.current_results[i] = stop_face

	var all_indices: Array[int] = []
	for i: int in GameManager.dice_pool.size():
		all_indices.append(i)
	root._process_roll_results(all_indices)
	await runner.simulate_frames(2)

	assert_int(root.turn_state).is_equal(RollPhase.TurnState.BUST)

	# Poll with delta_milli to advance the SceneTree clock past the auto-advance delay.
	for _i: int in 20:
		await runner.simulate_frames(1, 100)
	await runner.simulate_frames(5)

	# Should have auto-advanced (to IDLE if lives remain, or stayed BUST if run ended).
	if GameManager.lives > 0:
		assert_int(root.turn_state).is_equal(RollPhase.TurnState.IDLE)


func test_buttons_disabled_during_banked_state() -> void:
	## Both Roll and Bank buttons should be disabled after banking.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	_force_clean_state(root)
	root.bank_button.pressed.emit()
	await runner.simulate_frames(2)

	assert_bool(root.roll_button.disabled).is_true()
	assert_bool(root.bank_button.disabled).is_true()


func test_insurance_cancels_bust_forfeits_turn_and_burns_face() -> void:
	## INSURANCE prevents life loss on bust, forfeits turn score, then reverts to BLANK.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	_force_clean_state(root)
	root.turn_number = 4
	GameManager.total_score = 0
	GameManager.stage_target_score = 9999

	var insurance_face: DiceFaceData = GameManager.dice_pool[0].faces[0]
	insurance_face.type = DiceFaceData.FaceType.INSURANCE
	insurance_face.value = 0
	root.current_results[0] = insurance_face

	var stop_face: DiceFaceData = _make_face(DiceFaceData.FaceType.STOP, 0)
	for i: int in range(1, mini(5, GameManager.dice_pool.size())):
		root.current_results[i] = stop_face

	var all_indices: Array[int] = []
	for i: int in GameManager.dice_pool.size():
		all_indices.append(i)

	var lives_before: int = GameManager.lives
	root._process_roll_results(all_indices)
	await runner.simulate_frames(2)

	assert_int(root.turn_state).is_equal(RollPhase.TurnState.BANKED)
	assert_int(GameManager.lives).is_equal(lives_before)
	assert_int(GameManager.total_score).is_equal(0)
	assert_int(insurance_face.type).is_equal(DiceFaceData.FaceType.BLANK)
	assert_str(root.hud.status_label.text).contains("INSURANCE")

	for _i: int in 20:
		await runner.simulate_frames(1, 100)
	await runner.simulate_frames(5)
	assert_int(root.turn_state).is_equal(RollPhase.TurnState.IDLE)
