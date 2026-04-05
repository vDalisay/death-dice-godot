extends GdUnitTestSuite
## Unit tests for run snapshot serialization.


func test_run_mode_defaults_to_classic() -> void:
	var run: RunSaveData = auto_free(preload("res://Scripts/RunSaveData.gd").new())
	assert_int(run.run_mode).is_equal(0)


func test_to_dict_includes_run_mode() -> void:
	var run: RunSaveData = auto_free(preload("res://Scripts/RunSaveData.gd").new())
	run.run_mode = 1
	var data: Dictionary = run.to_dict()
	assert_bool(data.has("run_mode")).is_true()
	assert_int(int(data["run_mode"])).is_equal(1)


func test_to_dict_includes_reroll_incentive_fields() -> void:
	var run: RunSaveData = auto_free(preload("res://Scripts/RunSaveData.gd").new())
	run.exp_earned = 12
	run.stop_shards_earned = 3
	run.held_stops_at_end = 2
	run.active_loop_contract_id = "dead_close"
	var data: Dictionary = run.to_dict()
	assert_int(int(data["exp_earned"])).is_equal(12)
	assert_int(int(data["stop_shards_earned"])).is_equal(3)
	assert_int(int(data["held_stops_at_end"])).is_equal(2)
	assert_str(data["active_loop_contract_id"] as String).is_equal("dead_close")


func test_load_from_dict_restores_reroll_incentive_fields() -> void:
	var run: RunSaveData = auto_free(preload("res://Scripts/RunSaveData.gd").new())
	run.load_from_dict({
		"score": 99,
		"exp_earned": 8,
		"stop_shards_earned": 5,
		"held_stops_at_end": 1,
		"active_loop_contract_id": "one_more_time",
		"final_dice_names": ["Standard Die", "Lucky Die"],
	})
	assert_int(run.score).is_equal(99)
	assert_int(run.exp_earned).is_equal(8)
	assert_int(run.stop_shards_earned).is_equal(5)
	assert_int(run.held_stops_at_end).is_equal(1)
	assert_str(run.active_loop_contract_id).is_equal("one_more_time")
	assert_int(run.final_dice_names.size()).is_equal(2)


func test_to_dict_includes_seeded_run_fields() -> void:
	var run: RunSaveData = auto_free(preload("res://Scripts/RunSaveData.gd").new())
	run.is_seeded_run = true
	run.run_seed_text = "seed-abc"
	run.seed_version = 2
	var data: Dictionary = run.to_dict()
	assert_bool(bool(data.get("is_seeded_run", false))).is_true()
	assert_str(str(data.get("run_seed_text", ""))).is_equal("seed-abc")
	assert_int(int(data.get("seed_version", 0))).is_equal(2)


func test_load_from_dict_restores_seeded_run_fields() -> void:
	var run: RunSaveData = auto_free(preload("res://Scripts/RunSaveData.gd").new())
	run.load_from_dict({
		"is_seeded_run": true,
		"run_seed_text": "seed-xyz",
		"seed_version": 3,
	})
	assert_bool(run.is_seeded_run).is_true()
	assert_str(run.run_seed_text).is_equal("seed-xyz")
	assert_int(run.seed_version).is_equal(3)
