extends GdUnitTestSuite
## Unit tests for GameManager autoload.

var _gm: Node


func before_test() -> void:
	# Create a fresh GameManager instance for each test to avoid shared state.
	_gm = auto_free(preload("res://Scripts/GameManager.gd").new())


func test_initial_state() -> void:
	assert_int(_gm.total_score).is_equal(0)
	assert_int(_gm.lives).is_equal(3)
	assert_int(_gm.stage_target_score).is_equal(30)
	assert_int(_gm.current_stage).is_equal(1)
	assert_int(_gm.gold).is_equal(0)
	assert_int(_gm.run_mode).is_equal(_gm.RunMode.CLASSIC)


func test_add_score_updates_total() -> void:
	_gm.add_score(10)
	assert_int(_gm.total_score).is_equal(10)
	_gm.add_score(5)
	assert_int(_gm.total_score).is_equal(15)


func test_add_score_awards_gold() -> void:
	_gm.add_score(10)
	assert_int(_gm.gold).is_equal(10)


func test_add_score_emits_score_changed() -> void:
	monitor_signals(_gm, false)
	_gm.add_score(42)
	await assert_signal(_gm).is_emitted("score_changed", [42])


func test_add_score_emits_turn_banked() -> void:
	monitor_signals(_gm, false)
	_gm.add_score(10)
	await assert_signal(_gm).is_emitted("turn_banked", [10, 10])


func test_stage_cleared_when_target_reached() -> void:
	monitor_signals(_gm, false)
	_gm.add_score(30)
	await assert_signal(_gm).is_emitted("stage_cleared")


func test_stage_not_cleared_below_target() -> void:
	monitor_signals(_gm, false)
	_gm.add_score(29)
	await assert_signal(_gm).is_not_emitted("stage_cleared")


func test_lose_life_decrements() -> void:
	_gm.lose_life()
	assert_int(_gm.lives).is_equal(2)
	_gm.lose_life()
	assert_int(_gm.lives).is_equal(1)


func test_lose_life_emits_signal() -> void:
	monitor_signals(_gm, false)
	_gm.lose_life()
	await assert_signal(_gm).is_emitted("lives_changed", [2])


func test_run_ended_on_zero_lives() -> void:
	monitor_signals(_gm, false)
	_gm.lose_life()  # 2
	_gm.lose_life()  # 1
	_gm.lose_life()  # 0
	await assert_signal(_gm).is_emitted("run_ended")


func test_run_not_ended_with_lives_remaining() -> void:
	monitor_signals(_gm, false)
	_gm.lose_life()  # 2
	_gm.lose_life()  # 1
	await assert_signal(_gm).is_not_emitted("run_ended")


func test_reset_run_restores_defaults() -> void:
	_gm.add_score(300)
	_gm.lose_life()
	_gm.current_stage = 3
	_gm.gold = 100
	_gm.reset_run()
	assert_int(_gm.total_score).is_equal(0)
	assert_int(_gm.lives).is_equal(3)
	assert_int(_gm.current_stage).is_equal(1)
	assert_int(_gm.gold).is_equal(0)
	assert_int(_gm.stage_target_score).is_equal(30)
	assert_int(_gm.dice_pool.size()).is_equal(6)


func test_reset_run_emits_signals() -> void:
	_gm.add_score(10)
	_gm.lose_life()
	monitor_signals(_gm, false)
	_gm.reset_run()
	await assert_signal(_gm).is_emitted("score_changed", [0])
	await assert_signal(_gm).is_emitted("lives_changed", [3])
	await assert_signal(_gm).is_emitted("gold_changed", [0])
	await assert_signal(_gm).is_emitted("stage_advanced", [1])


# ---------------------------------------------------------------------------
# Stage progression
# ---------------------------------------------------------------------------

func test_advance_stage_increments() -> void:
	_gm.add_score(10)
	_gm.advance_stage()
	assert_int(_gm.current_stage).is_equal(2)
	assert_int(_gm.total_score).is_equal(0)
	assert_int(_gm.stage_target_score).is_equal(55)


func test_advance_stage_emits_signals() -> void:
	monitor_signals(_gm, false)
	_gm.advance_stage()
	await assert_signal(_gm).is_emitted("stage_advanced", [2])
	await assert_signal(_gm).is_emitted("score_changed", [0])


func test_advance_row_updates_current_row_and_previous_col() -> void:
	assert_int(_gm.current_row).is_equal(0)
	assert_int(_gm.previous_col).is_equal(-1)
	_gm.advance_row(2)
	assert_int(_gm.current_row).is_equal(1)
	assert_int(_gm.previous_col).is_equal(2)


func test_is_final_stage() -> void:
	assert_bool(_gm.is_final_stage()).is_false()
	_gm.current_stage = 5
	assert_bool(_gm.is_final_stage()).is_true()


func test_stage_target_scales() -> void:
	# Stage 1: 30, Stage 2: 55, Stage 3: 80, Stage 4: 105, Stage 5: 130
	assert_int(_gm._calculate_stage_target(1)).is_equal(30)
	assert_int(_gm._calculate_stage_target(2)).is_equal(55)
	assert_int(_gm._calculate_stage_target(5)).is_equal(130)


func test_gauntlet_stage_targets_scale_steeper() -> void:
	_gm.set_run_mode(_gm.RunMode.GAUNTLET)
	assert_int(_gm._calculate_stage_target(1)).is_equal(30)
	assert_int(_gm._calculate_stage_target(2)).is_equal(61)
	assert_int(_gm._calculate_stage_target(5)).is_equal(154)


func test_set_run_mode_emits_signal() -> void:
	monitor_signals(_gm, false)
	_gm.set_run_mode(_gm.RunMode.GAUNTLET)
	await assert_signal(_gm).is_emitted("run_mode_changed", [_gm.RunMode.GAUNTLET])


# ---------------------------------------------------------------------------
# Gold
# ---------------------------------------------------------------------------

func test_add_gold() -> void:
	_gm.add_gold(50)
	assert_int(_gm.gold).is_equal(50)


func test_add_gold_emits_signal() -> void:
	monitor_signals(_gm, false)
	_gm.add_gold(25)
	await assert_signal(_gm).is_emitted("gold_changed", [25])


func test_spend_gold_succeeds() -> void:
	_gm.gold = 100
	var result: bool = _gm.spend_gold(40)
	assert_bool(result).is_true()
	assert_int(_gm.gold).is_equal(60)


func test_spend_gold_fails_when_insufficient() -> void:
	_gm.gold = 10
	var result: bool = _gm.spend_gold(50)
	assert_bool(result).is_false()
	assert_int(_gm.gold).is_equal(10)


# ---------------------------------------------------------------------------
# Shop flow
# ---------------------------------------------------------------------------

func test_on_shop_entered_resets_shop_spend() -> void:
	_gm._shop_gold_spent = 17
	_gm.on_shop_entered()
	assert_int(_gm._shop_gold_spent).is_equal(0)


func test_on_shop_entered_awards_miser_bonus_when_pending() -> void:
	_gm.gold = 0
	_gm._miser_bonus_pending = true
	_gm.on_shop_entered()
	assert_int(_gm.gold).is_equal(_gm.MISER_BONUS_GOLD)
	assert_bool(_gm._miser_bonus_pending).is_false()


func test_on_shop_exited_sets_miser_pending_below_threshold() -> void:
	_gm.active_modifiers.clear()
	_gm.add_modifier(RunModifier.make_miser())
	_gm._shop_gold_spent = _gm.MISER_SPEND_THRESHOLD - 1
	_gm.on_shop_exited()
	assert_bool(_gm._miser_bonus_pending).is_true()


func test_on_shop_exited_clears_miser_pending_without_modifier() -> void:
	_gm.active_modifiers.clear()
	_gm._miser_bonus_pending = true
	_gm._shop_gold_spent = 0
	_gm.on_shop_exited()
	assert_bool(_gm._miser_bonus_pending).is_false()


# ---------------------------------------------------------------------------
# Dice pool
# ---------------------------------------------------------------------------

func test_dice_pool_starts_empty_without_ready() -> void:
	# _ready() not called in unit tests, so pool is empty.
	assert_int(_gm.dice_pool.size()).is_equal(0)


func test_add_dice() -> void:
	_gm.add_dice(DiceData.make_standard_d6())
	assert_int(_gm.dice_pool.size()).is_equal(1)


# ---------------------------------------------------------------------------
# Best turn score
# ---------------------------------------------------------------------------

func test_best_turn_score_starts_at_zero() -> void:
	assert_int(_gm.best_turn_score).is_equal(0)


func test_best_turn_score_resets_on_run_reset() -> void:
	_gm.best_turn_score = 42
	_gm.reset_run()
	assert_int(_gm.best_turn_score).is_equal(0)


# ---------------------------------------------------------------------------
# Momentum
# ---------------------------------------------------------------------------

func test_momentum_starts_at_zero() -> void:
	assert_int(_gm.momentum).is_equal(0)


func test_momentum_resets_on_lose_life() -> void:
	_gm.momentum = 3
	_gm.lose_life()
	assert_int(_gm.momentum).is_equal(0)


func test_momentum_resets_on_advance_stage() -> void:
	_gm.momentum = 5
	_gm.advance_stage()
	assert_int(_gm.momentum).is_equal(0)


func test_momentum_resets_on_advance_loop() -> void:
	_gm.momentum = 4
	_gm.advance_loop()
	assert_int(_gm.momentum).is_equal(0)


func test_momentum_resets_on_run_reset() -> void:
	_gm.momentum = 7
	_gm.reset_run()
	assert_int(_gm.momentum).is_equal(0)


func test_momentum_changed_emitted_on_lose_life() -> void:
	_gm.momentum = 2
	monitor_signals(_gm, false)
	_gm.lose_life()
	await assert_signal(_gm).is_emitted("momentum_changed", [0])


func test_momentum_changed_emitted_on_advance_stage() -> void:
	_gm.momentum = 3
	monitor_signals(_gm, false)
	_gm.advance_stage()
	await assert_signal(_gm).is_emitted("momentum_changed", [0])


func test_momentum_changed_emitted_on_reset_run() -> void:
	_gm.momentum = 5
	monitor_signals(_gm, false)
	_gm.reset_run()
	await assert_signal(_gm).is_emitted("momentum_changed", [0])


func test_add_momentum_increments_and_emits() -> void:
	monitor_signals(_gm, false)
	_gm.add_momentum(2)
	assert_int(_gm.momentum).is_equal(2)
	await assert_signal(_gm).is_emitted("momentum_changed", [2])


func test_reset_momentum_sets_zero_and_emits() -> void:
	_gm.momentum = 3
	monitor_signals(_gm, false)
	_gm.reset_momentum()
	assert_int(_gm.momentum).is_equal(0)
	await assert_signal(_gm).is_emitted("momentum_changed", [0])


# ---------------------------------------------------------------------------
# Encapsulated state mutation helpers
# ---------------------------------------------------------------------------

func test_set_archetype_updates_selected_value() -> void:
	_gm.set_archetype(_gm.Archetype.BLANK_SLATE)
	assert_int(_gm.chosen_archetype).is_equal(_gm.Archetype.BLANK_SLATE)


func test_consume_event_free_bust_true_once() -> void:
	_gm.set_event_free_bust(true)
	assert_bool(_gm.consume_event_free_bust()).is_true()
	assert_bool(_gm.event_free_bust).is_false()
	assert_bool(_gm.consume_event_free_bust()).is_false()


func test_apply_event_target_multiplier_scales_stage_target() -> void:
	_gm.stage_target_score = 100
	_gm.apply_event_target_multiplier(1.15)
	assert_float(_gm.event_target_multiplier).is_equal(1.15)
	assert_int(_gm.stage_target_score).is_equal(115)


func test_remove_gold_clamps_and_emits() -> void:
	_gm.gold = 10
	monitor_signals(_gm, false)
	_gm.remove_gold(25)
	assert_int(_gm.gold).is_equal(0)
	await assert_signal(_gm).is_emitted("gold_changed", [0])


func test_heal_lives_clamps_and_emits() -> void:
	_gm.lives = 2
	monitor_signals(_gm, false)
	_gm.heal_lives(5)
	assert_int(_gm.lives).is_equal(_gm.MAX_LIVES)
	await assert_signal(_gm).is_emitted("lives_changed", [_gm.MAX_LIVES])


func test_begin_stage_from_map_updates_stage_and_score() -> void:
	_gm.current_stage = 1
	_gm.total_stages_cleared = 0
	_gm.total_score = 77
	monitor_signals(_gm, false)
	_gm.begin_stage_from_map()
	assert_int(_gm.current_stage).is_equal(2)
	assert_int(_gm.total_stages_cleared).is_equal(1)
	assert_int(_gm.total_score).is_equal(0)
	await assert_signal(_gm).is_emitted("score_changed", [0])
	await assert_signal(_gm).is_emitted("stage_advanced", [2])


func test_register_turn_score_updates_only_when_higher() -> void:
	_gm.best_turn_score = 12
	assert_bool(_gm.register_turn_score(10)).is_false()
	assert_int(_gm.best_turn_score).is_equal(12)
	assert_bool(_gm.register_turn_score(18)).is_true()
	assert_int(_gm.best_turn_score).is_equal(18)
