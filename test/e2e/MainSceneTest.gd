extends GdUnitTestSuite
## End-to-end tests for the main game scene using GdUnit4 scene runner.
## Tests the full game loop: rolling, banking, busting, and new runs.


func before_test() -> void:
	GameManager.skip_archetype_picker = true
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION
	GameManager.active_modifiers.clear()
	GameManager.reset_run()


func _get_root(runner: GdUnitSceneRunner) -> RollPhase:
	var root: RollPhase = runner.scene() as RollPhase
	root.dice_arena.instant_mode = true
	return root


func test_scene_loads_with_correct_structure() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)
	assert_object(root).is_not_null()
	# Verify key child nodes exist.
	assert_object(root.hud).is_not_null()
	assert_object(root.dice_arena).is_not_null()
	assert_object(root.roll_button).is_not_null()
	assert_object(root.bank_button).is_not_null()


func test_initial_state_is_idle() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)
	assert_int(root.turn_state).is_equal(RollPhase.TurnState.IDLE)


func test_dice_pool_starts_with_six_dice() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	# Caution archetype starts with 6 Standard dice.
	assert_int(GameManager.dice_pool.size()).is_equal(6)


func test_roll_button_starts_enabled() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)
	assert_bool(root.roll_button.disabled).is_false()
	assert_str(root.roll_button.text).is_equal("Roll All")


func test_bank_button_starts_disabled() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)
	assert_bool(root.bank_button.disabled).is_true()


func test_rolling_transitions_to_active() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)
	# Click the Roll button.
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	# After rolling, state should be ACTIVE (unless auto-bank happened).
	var state: int = root.turn_state
	assert_bool(
		state == RollPhase.TurnState.ACTIVE
		or state == RollPhase.TurnState.BANKED
	).is_true()


func test_rolling_populates_results() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	# Every die should have a result after rolling.
	for i: int in GameManager.dice_pool.size():
		assert_object(root.current_results[i]).is_not_null()


func test_dice_arena_starts_empty() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)
	# Arena starts with no dice — they are created on throw.
	assert_int(root.dice_arena.get_die_count()).is_equal(0)


func test_hud_shows_correct_lives() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)
	assert_int(root.hud.lives_label.text.length()).is_equal(GameManager.lives)


func test_hud_shows_correct_target() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)
	assert_str(root.hud.target_label.text).contains("30")


func test_hud_progress_bar_starts_at_zero() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)
	GameManager.total_score = 0
	GameManager.score_changed.emit(0)
	await runner.simulate_frames(1)
	assert_int(int(root.hud.progress_bar.value)).is_equal(0)
	assert_str(root.hud.progress_hint_label.text).is_equal("")


func test_hud_progress_shows_almost_there_near_target() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)
	var near_target: int = int(float(GameManager.stage_target_score) * 0.9)
	GameManager.total_score = near_target
	GameManager.score_changed.emit(near_target)
	assert_object(root.hud._progress_tween).is_not_null()
	await root.hud._progress_tween.finished
	assert_str(root.hud.progress_hint_label.text).is_equal("ALMOST THERE")
	assert_int(int(root.hud.progress_bar.value)).is_greater_equal(90)


func test_banking_adds_score_to_total() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)
	# Force a known roll result so we can predict the score.
	var scoring_face := DiceFaceData.new()
	scoring_face.type = DiceFaceData.FaceType.NUMBER
	scoring_face.value = 3
	# Set all dice to a known scoring face manually.
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	# If state went to ACTIVE, override results and bank.
	if root.turn_state == RollPhase.TurnState.ACTIVE:
		for i: int in GameManager.dice_pool.size():
			root.current_results[i] = scoring_face
			root.dice_stopped[i] = false
			root.dice_keep[i] = true
		root.bank_button.pressed.emit()
		await runner.simulate_frames(2)
		# Score should be 3 × 5 = 15 (5 dice, each face value 3).
		assert_int(GameManager.total_score).is_greater_equal(15)


func test_new_run_button_hidden_initially() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)
	assert_bool(root.new_run_button.visible).is_false()


func test_shop_panel_hidden_initially() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)
	assert_bool(root.shop_panel.visible).is_false()


func test_hud_shows_stage_label() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)
	assert_str(root.hud.stage_label.text).contains("ROW")
	assert_str(root.hud.stage_label.text).contains("1")


func test_rest_node_requires_continue_before_stage_map_reopens() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)
	root._execute_rest_node()
	await runner.simulate_frames(2)
	var overlay: ColorRect = root.find_child("RestOverlay", true, false) as ColorRect
	assert_object(overlay).is_not_null()
	assert_bool(root.stage_map_panel.visible).is_false()
	await await_millis(260)
	var continue_button: Button = overlay.get_node("CenterContainer/Card/MarginContainer/Content/ContinueButton") as Button
	continue_button.pressed.emit()
	await runner.simulate_frames(3)
	assert_bool(root.stage_map_panel.visible).is_true()


func test_stage_clear_overlay_waits_for_final_bank_count() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _get_root(runner)
	GameManager.stage_target_score = 5
	root.turn_state = RollPhase.TurnState.ACTIVE
	var scoring_face := DiceFaceData.new()
	scoring_face.type = DiceFaceData.FaceType.NUMBER
	scoring_face.value = 2
	for i: int in GameManager.dice_pool.size():
		root.current_results[i] = scoring_face
		root.dice_stopped[i] = false
		root.dice_keep[i] = true
		root.dice_keep_locked[i] = false
	root.bank_button.pressed.emit()
	await runner.simulate_frames(1)
	assert_object(root.find_child("StageClearedOverlay", true, false)).is_null()
	await await_millis(1300)
	await runner.simulate_frames(2)
	assert_object(root.find_child("StageClearedOverlay", true, false)).is_not_null()
