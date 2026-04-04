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
