extends GdUnitTestSuite
## Unit tests for GameManager autoload.

var _gm: Node


func before_test() -> void:
	# Create a fresh GameManager instance for each test to avoid shared state.
	_gm = auto_free(preload("res://Scripts/GameManager.gd").new())


func test_initial_state() -> void:
	assert_int(_gm.total_score).is_equal(0)
	assert_int(_gm.lives).is_equal(3)
	assert_int(_gm.stage_target_score).is_equal(500)


func test_add_score_updates_total() -> void:
	_gm.add_score(100)
	assert_int(_gm.total_score).is_equal(100)
	_gm.add_score(50)
	assert_int(_gm.total_score).is_equal(150)


func test_add_score_emits_score_changed() -> void:
	monitor_signals(_gm, false)
	_gm.add_score(42)
	await assert_signal(_gm).is_emitted("score_changed", [42])


func test_add_score_emits_turn_banked() -> void:
	monitor_signals(_gm, false)
	_gm.add_score(100)
	await assert_signal(_gm).is_emitted("turn_banked", [100, 100])


func test_stage_cleared_when_target_reached() -> void:
	monitor_signals(_gm, false)
	_gm.add_score(500)
	await assert_signal(_gm).is_emitted("stage_cleared")


func test_stage_not_cleared_below_target() -> void:
	monitor_signals(_gm, false)
	_gm.add_score(499)
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
	_gm.reset_run()
	assert_int(_gm.total_score).is_equal(0)
	assert_int(_gm.lives).is_equal(3)


func test_reset_run_emits_signals() -> void:
	_gm.add_score(100)
	_gm.lose_life()
	monitor_signals(_gm, false)
	_gm.reset_run()
	await assert_signal(_gm).is_emitted("score_changed", [0])
	await assert_signal(_gm).is_emitted("lives_changed", [3])
