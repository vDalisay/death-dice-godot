extends GdUnitTestSuite

const ContractProgressServiceScript: GDScript = preload("res://Scripts/ContractProgressService.gd")

var _service: RefCounted = null


func before_test() -> void:
	_service = ContractProgressServiceScript.new()


func test_safe_hands_counts_low_stop_banks() -> void:
	var progress: Dictionary = {}
	progress = _service.on_bank("safe_hands", progress, {"effective_stops": 1})
	progress = _service.on_bank("safe_hands", progress, {"effective_stops": 0})
	assert_int(int(progress.get("current", 0))).is_equal(2)
	assert_bool(bool(progress.get("completed", false))).is_false()


func test_dead_close_completes_on_threshold_minus_one_bank() -> void:
	var progress: Dictionary = _service.on_bank(
		"dead_close",
		{},
		{"effective_stops": 3, "threshold": 4}
	)
	assert_int(int(progress.get("current", 0))).is_equal(1)
	assert_bool(bool(progress.get("completed", false))).is_true()


func test_comeback_only_completes_after_bust_then_stage_clear() -> void:
	var progress: Dictionary = _service.on_bust("comeback", {}, {"stage_had_bust": true})
	progress = _service.on_stage_clear("comeback", progress, {"stage_had_bust": true})
	assert_bool(bool(progress.get("completed", false))).is_true()


func test_format_progress_text_reflects_counter_state() -> void:
	var progress: Dictionary = _service.on_bank("safe_hands", {}, {"effective_stops": 0})
	assert_str(_service.format_progress_text("safe_hands", progress)).is_equal("Safe Hands 1/3")