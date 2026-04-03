extends GdUnitTestSuite
## Unit tests for StageFlowCoordinator map progression helpers.

var _coordinator: RefCounted


func before_test() -> void:
	_coordinator = auto_free(preload("res://Scripts/StageFlowCoordinator.gd").new())
	GameManager.skip_archetype_picker = true
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION
	GameManager.reset_run()


func test_advance_row_updates_game_manager_path_state() -> void:
	assert_int(GameManager.current_row).is_equal(0)
	_coordinator.advance_row(2)
	assert_int(GameManager.current_row).is_equal(1)
	assert_int(GameManager.previous_col).is_equal(2)


func test_begin_stage_from_map_advances_stage_and_resets_score() -> void:
	GameManager.total_score = 50
	var start_stage: int = GameManager.current_stage
	_coordinator.begin_stage_from_map()
	assert_int(GameManager.current_stage).is_equal(start_stage + 1)
	assert_int(GameManager.total_score).is_equal(0)


func test_apply_rest_rewards_heals_and_grants_gold() -> void:
	GameManager.lives = 1
	GameManager.gold = 0
	_coordinator.apply_rest_rewards(1, 10)
	assert_int(GameManager.lives).is_equal(2)
	assert_int(GameManager.gold).is_equal(10)


func test_complete_loop_advances_loop() -> void:
	var start_loop: int = GameManager.current_loop
	_coordinator.complete_loop()
	assert_int(GameManager.current_loop).is_equal(start_loop + 1)
	assert_int(GameManager.current_stage).is_equal(1)
