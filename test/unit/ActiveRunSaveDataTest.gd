extends GdUnitTestSuite
## Unit tests for active run snapshot serialization.


func test_to_dict_and_load_round_trip_preserves_seed_and_surface() -> void:
	var snapshot: Resource = auto_free(preload("res://Scripts/ActiveRunSaveData.gd").new())
	snapshot.run_seed_text = "seed-777"
	snapshot.is_seeded_run = true
	snapshot.seed_version = 2
	snapshot.rng_stream_states = {"roll": 1234}
	snapshot.resume_surface = "shop"
	snapshot.resume_payload = {"stage": 3}
	snapshot.game_manager_state = {"total_score": 45}
	snapshot.roll_phase_state = {"turn_number": 2}
	var data: Dictionary = snapshot.to_dict()
	var restored: Resource = auto_free(preload("res://Scripts/ActiveRunSaveData.gd").from_dict(data))
	assert_str(restored.run_seed_text).is_equal("seed-777")
	assert_bool(restored.is_seeded_run).is_true()
	assert_int(restored.seed_version).is_equal(2)
	assert_int(int(restored.rng_stream_states.get("roll", 0))).is_equal(1234)
	assert_str(restored.resume_surface).is_equal("shop")
	assert_int(int(restored.resume_payload.get("stage", 0))).is_equal(3)
	assert_int(int(restored.game_manager_state.get("total_score", 0))).is_equal(45)
	assert_int(int(restored.roll_phase_state.get("turn_number", 0))).is_equal(2)
