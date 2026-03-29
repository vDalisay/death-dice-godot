extends GdUnitTestSuite
## End-to-end tests for the main game scene using GdUnit4 scene runner.
## Tests the full game loop: rolling, banking, busting, and new runs.


func before_test() -> void:
	GameManager.skip_archetype_picker = true
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION
	GameManager.active_modifiers.clear()


func test_scene_loads_with_correct_structure() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase
	assert_object(root).is_not_null()
	# Verify key child nodes exist.
	assert_object(root.hud).is_not_null()
	assert_object(root.dice_tray).is_not_null()
	assert_object(root.roll_button).is_not_null()
	assert_object(root.bank_button).is_not_null()


func test_initial_state_is_idle() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase
	assert_int(root.turn_state).is_equal(RollPhase.TurnState.IDLE)


func test_dice_pool_starts_with_six_dice() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	# Caution archetype starts with 6 Standard dice.
	assert_int(GameManager.dice_pool.size()).is_equal(6)


func test_roll_button_starts_enabled() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase
	assert_bool(root.roll_button.disabled).is_false()
	assert_str(root.roll_button.text).is_equal("Roll All")


func test_bank_button_starts_disabled() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase
	assert_bool(root.bank_button.disabled).is_true()


func test_rolling_transitions_to_active() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase
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
	var root: RollPhase = runner.scene() as RollPhase
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	# Every die should have a result after rolling.
	for i: int in GameManager.dice_pool.size():
		assert_object(root.current_results[i]).is_not_null()


func test_dice_tray_has_buttons_matching_pool() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase
	assert_int(root.dice_tray.get_button_count()).is_equal(GameManager.dice_pool.size())


func test_hud_shows_correct_lives() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase
	assert_str(root.hud.lives_label.text).contains("3")


func test_hud_shows_correct_target() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase
	assert_str(root.hud.target_label.text).contains("30")


func test_banking_adds_score_to_total() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase
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
	var root: RollPhase = runner.scene() as RollPhase
	assert_bool(root.new_run_button.visible).is_false()


func test_shop_panel_hidden_initially() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase
	assert_bool(root.shop_panel.visible).is_false()


func test_hud_shows_stage_label() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase
	assert_str(root.hud.stage_label.text).contains("Stage")
	assert_str(root.hud.stage_label.text).contains("1")
