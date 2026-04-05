extends GdUnitTestSuite


func before_test() -> void:
	GameManager.reset_run()


func test_lucky_floor_first_reroll_grants_luck_once_per_turn() -> void:
	GameManager.enter_special_stage("lucky_floor")
	GameManager.begin_special_stage_turn()
	assert_str(GameManager.apply_special_stage_reroll_bonus(1)).contains("+2 LUCK")
	assert_int(GameManager.luck).is_equal(2)
	assert_str(GameManager.apply_special_stage_reroll_bonus(2)).is_equal("")
	assert_int(GameManager.luck).is_equal(2)


func test_clean_room_preview_and_clear_rewards_stack() -> void:
	GameManager.enter_special_stage("clean_room")
	var preview: Dictionary = GameManager.get_special_stage_bank_preview(1, 0)
	assert_int(int(preview.get("bonus_score", 0))).is_equal(6)
	var clear_rewards: Dictionary = GameManager.get_special_stage_clear_rewards(1, true)
	assert_int(int(clear_rewards.get("bonus_gold", 0))).is_equal(15)


func test_precision_hall_exact_two_stop_rewards() -> void:
	GameManager.enter_special_stage("precision_hall")
	var preview: Dictionary = GameManager.get_special_stage_bank_preview(2, 1)
	assert_int(int(preview.get("bonus_gold", 0))).is_equal(8)
	var clear_rewards: Dictionary = GameManager.get_special_stage_clear_rewards(2, true)
	assert_int(int(clear_rewards.get("bonus_luck", 0))).is_equal(3)