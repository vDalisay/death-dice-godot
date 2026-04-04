extends GdUnitTestSuite
## Tests for Phase 2 — Variable Reward Escalation features:
## Hot Streak, Jackpot, Personal Best, Bust Risk, Shop Refresh, Upgrade Preview.


func before_test() -> void:
	GameManager.skip_archetype_picker = true
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION
	GameManager.active_modifiers.clear()
	GameManager.reset_run()


func _setup_scene(runner: GdUnitSceneRunner) -> RollPhase:
	var root: RollPhase = runner.scene() as RollPhase
	root.dice_arena.instant_mode = true
	return root


func _make_face(type: DiceFaceData.FaceType, value: int) -> DiceFaceData:
	var face := DiceFaceData.new()
	face.type = type
	face.value = value
	return face


func _force_clean_state(root: RollPhase) -> void:
	var pool_size: int = GameManager.dice_pool.size()
	root.accumulated_stop_count = 0
	root.accumulated_shield_count = 0
	root._reroll_count = 0
	for i: int in pool_size:
		root.dice_stopped[i] = false
		root.dice_keep[i] = false
		root.dice_keep_locked[i] = false
		root.current_results[i] = _make_face(DiceFaceData.FaceType.NUMBER, 1)


# ---------------------------------------------------------------------------
# Hot Streak (#10)
# ---------------------------------------------------------------------------

func test_streak_starts_at_zero() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	assert_int(root.bank_streak).is_equal(0)


func test_streak_increments_on_bank() -> void:
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

	assert_int(root.bank_streak).is_equal(1)


func test_streak_resets_on_bust() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)

	# Bank once to get streak = 1.
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return
	_force_clean_state(root)
	root.bank_button.pressed.emit()
	await runner.simulate_frames(2)
	# Wait for auto-advance.
	for _i: int in 20:
		await runner.simulate_frames(1, 100)
	await runner.simulate_frames(5)
	assert_int(root.bank_streak).is_equal(1)

	# Now force a bust.
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return
	_force_clean_state(root)
	# Caution archetype is immune on turns 1-3 at stage 1, so force turn 4.
	root.turn_number = 4
	var stop_face := _make_face(DiceFaceData.FaceType.STOP, 0)
	for i: int in mini(4, GameManager.dice_pool.size()):
		root.current_results[i] = stop_face
	var all_indices: Array[int] = []
	for i: int in GameManager.dice_pool.size():
		all_indices.append(i)
	root._process_roll_results(all_indices)
	await runner.simulate_frames(2)

	assert_int(root.bank_streak).is_equal(0)


func test_streak_multiplier_tier_1() -> void:
	## _get_streak_multiplier returns 1.1 at 3 consecutive banks.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	root.bank_streak = 2  # Will become 3 on next bank.
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return
	_force_clean_state(root)
	# After bank, streak = 3 → multiplier = 1.1.
	assert_float(root._get_streak_multiplier()).is_equal(1.0)
	root.bank_streak = 3
	assert_float(root._get_streak_multiplier()).is_equal(RollPhase.HOT_STREAK_MULT_1)


func test_streak_multiplier_tier_2() -> void:
	## _get_streak_multiplier returns 1.2 at 5 consecutive banks.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	root.bank_streak = 5
	assert_float(root._get_streak_multiplier()).is_equal(RollPhase.HOT_STREAK_MULT_2)


# ---------------------------------------------------------------------------
# Jackpot (#11)
# ---------------------------------------------------------------------------

func test_jackpot_conditions_met() -> void:
	## 0 rerolls, 5+ dice, 0 stops → jackpot gold bonus.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	_force_clean_state(root)
	root._reroll_count = 0
	root.accumulated_stop_count = 0
	for i: int in GameManager.dice_pool.size():
		root.current_results[i] = _make_face(DiceFaceData.FaceType.NUMBER, 1)

	# Prevent stage clear from adding bonus gold.
	GameManager.total_score = 0
	GameManager.stage_target_score = 9999

	var gold_before: int = GameManager.gold
	root.bank_button.pressed.emit()
	await runner.simulate_frames(2)

	# Score = 5 dice × 1 = 5. Jackpot bonus = max(1, int(5 * 0.25)) = 1g.
	# Gold gained = 5 (from score) + 1 (jackpot) = 6.
	var gold_gained: int = GameManager.gold - gold_before
	assert_int(gold_gained).is_greater(5)


func test_no_jackpot_with_rerolls() -> void:
	## Jackpot should NOT fire if rerolls happened.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	_force_clean_state(root)
	root._reroll_count = 1  # Simulates one reroll.
	root.accumulated_stop_count = 0
	for i: int in GameManager.dice_pool.size():
		root.current_results[i] = _make_face(DiceFaceData.FaceType.NUMBER, 1)

	# Ensure we won't trigger stage clear (which adds bonus gold).
	GameManager.total_score = 0
	GameManager.stage_target_score = 9999

	var gold_before: int = GameManager.gold
	root.bank_button.pressed.emit()
	await runner.simulate_frames(2)

	# Without jackpot: gold gained = just the score (pool_size dice × 1).
	var gold_gained: int = GameManager.gold - gold_before
	assert_int(gold_gained).is_equal(GameManager.dice_pool.size())


func test_no_jackpot_with_stops() -> void:
	## Jackpot should NOT fire if any stops accumulated.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	_force_clean_state(root)
	root._reroll_count = 0
	root.accumulated_stop_count = 1  # One stop accumulated.
	for i: int in GameManager.dice_pool.size():
		root.current_results[i] = _make_face(DiceFaceData.FaceType.NUMBER, 1)

	# Prevent stage clear from adding bonus gold.
	GameManager.total_score = 0
	GameManager.stage_target_score = 9999

	var gold_before: int = GameManager.gold
	root.bank_button.pressed.emit()
	await runner.simulate_frames(2)

	var gold_gained: int = GameManager.gold - gold_before
	assert_int(gold_gained).is_equal(GameManager.dice_pool.size())


# ---------------------------------------------------------------------------
# Personal Best (#14)
# ---------------------------------------------------------------------------

func test_personal_best_updates() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	GameManager.best_turn_score = 0
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	_force_clean_state(root)
	for i: int in GameManager.dice_pool.size():
		root.current_results[i] = _make_face(DiceFaceData.FaceType.NUMBER, 5)

	# Prevent stage clear.
	GameManager.total_score = 0
	GameManager.stage_target_score = 9999

	root.bank_button.pressed.emit()
	await runner.simulate_frames(2)

	# Score = pool_size × 5. Should be new best.
	assert_int(GameManager.best_turn_score).is_equal(5 * GameManager.dice_pool.size())


func test_personal_best_not_overwritten_by_lower() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	GameManager.best_turn_score = 100
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	_force_clean_state(root)
	# Prevent stage clear.
	GameManager.total_score = 0
	GameManager.stage_target_score = 9999
	# Score = 5 × 1 = 5. Should NOT beat 100.
	root.bank_button.pressed.emit()
	await runner.simulate_frames(2)

	assert_int(GameManager.best_turn_score).is_equal(100)


# ---------------------------------------------------------------------------
# Bust Risk Indicator (#15)
# ---------------------------------------------------------------------------

func test_bust_odds_increase_with_effective_stops() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	var low: float = root._estimate_bust_odds(0, 4)
	var high: float = root._estimate_bust_odds(2, 4)
	assert_float(high).is_greater(low)


func test_bust_odds_increase_with_reroll_count() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	root._reroll_count = 0
	var initial: float = root._estimate_bust_odds(1, 4)
	root._reroll_count = 3
	var later: float = root._estimate_bust_odds(1, 4)
	assert_float(later).is_greater(initial)


func test_bust_odds_are_zero_when_no_rerollable_dice() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	for i: int in GameManager.dice_pool.size():
		root.dice_keep[i] = true
		root.dice_keep_locked[i] = true
	var odds: float = root._estimate_bust_odds(0, 4)
	assert_float(odds).is_equal(0.0)


func test_bust_odds_are_one_when_threshold_reached() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	var odds: float = root._estimate_bust_odds(4, 4)
	assert_float(odds).is_equal(1.0)


# ---------------------------------------------------------------------------
# Reroll counter tracking (#11 dependency)
# ---------------------------------------------------------------------------

func test_reroll_count_starts_at_zero() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	assert_int(root._reroll_count).is_equal(0)


func test_reroll_count_increments_on_reroll() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	_force_clean_state(root)
	# Wait past the roll animation lock before clicking reroll.
	for _i: int in 10:
		await runner.simulate_frames(1, 100)
	# Reroll (some dice must be un-kept for reroll to proceed).
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)

	assert_int(root._reroll_count).is_equal(1)


# ---------------------------------------------------------------------------
# Shop Refresh (#12)
# ---------------------------------------------------------------------------

func test_shop_refresh_cost() -> void:
	assert_int(ShopPanel.REFRESH_COST).is_equal(5)


# ---------------------------------------------------------------------------
# Streak Display (#10 visual)
# ---------------------------------------------------------------------------

func test_streak_display_hidden_at_zero() -> void:
	## StreakDisplay should be invisible when streak is 0.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	assert_bool(root._streak_display.visible).is_false()


func test_streak_display_visible_after_bank() -> void:
	## StreakDisplay should become visible after banking (streak = 1).
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	_force_clean_state(root)
	GameManager.total_score = 0
	GameManager.stage_target_score = 9999
	root.bank_button.pressed.emit()
	await runner.simulate_frames(2)

	assert_bool(root._streak_display.visible).is_true()


func test_streak_display_hidden_after_bust() -> void:
	## StreakDisplay should hide when streak resets to 0 on bust.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)

	# Bank once to get streak visible.
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return
	_force_clean_state(root)
	GameManager.total_score = 0
	GameManager.stage_target_score = 9999
	root.bank_button.pressed.emit()
	await runner.simulate_frames(2)
	# Wait for auto-advance.
	for _i: int in 20:
		await runner.simulate_frames(1, 100)
	await runner.simulate_frames(5)

	# Now force a bust.
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return
	_force_clean_state(root)
	root.turn_number = 4
	var stop_face := _make_face(DiceFaceData.FaceType.STOP, 0)
	for i: int in mini(4, GameManager.dice_pool.size()):
		root.current_results[i] = stop_face
	var all_indices: Array[int] = []
	for i: int in GameManager.dice_pool.size():
		all_indices.append(i)
	root._process_roll_results(all_indices)
	await runner.simulate_frames(2)

	assert_bool(root._streak_display.visible).is_false()


# ---------------------------------------------------------------------------
# Stage Clear Proceed Button (#16)
# ---------------------------------------------------------------------------

func test_stage_clear_does_not_open_shop_immediately() -> void:
	## After triggering stage clear, the shop should NOT open until the player
	## clicks the proceed button in the stage-clear overlay.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = _setup_scene(runner)

	# Roll and enter ACTIVE state.
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	_force_clean_state(root)
	# Set score high enough to clear the stage.
	GameManager.total_score = 0
	GameManager.stage_target_score = 5
	for i: int in GameManager.dice_pool.size():
		root.current_results[i] = _make_face(DiceFaceData.FaceType.NUMBER, 5)

	root.bank_button.pressed.emit()
	await runner.simulate_frames(5)

	# Shop should NOT be visible yet — overlay with proceed button should be up.
	assert_bool(root.shop_panel.visible).is_false()
