extends GdUnitTestSuite
## Unit tests for RollResolutionService helpers and bust routing order.

var _service: RefCounted

const OUTCOME_SAFE: int = 0
const OUTCOME_IMMUNE_SAVE: int = 1
const OUTCOME_INSURANCE_SAVE: int = 2
const OUTCOME_EVENT_SAVE: int = 3
const OUTCOME_BUST: int = 4


func before_test() -> void:
	_service = auto_free(preload("res://Scripts/RollResolutionService.gd").new())


func _face(type: DiceFaceData.FaceType, value: int = 0) -> DiceFaceData:
	var face := DiceFaceData.new()
	face.type = type
	face.value = value
	return face


func test_stop_weight_counts_cursed_as_two() -> void:
	assert_int(_service.stop_weight(_face(DiceFaceData.FaceType.STOP))).is_equal(1)
	assert_int(_service.stop_weight(_face(DiceFaceData.FaceType.CURSED_STOP))).is_equal(2)
	assert_int(_service.stop_weight(_face(DiceFaceData.FaceType.NUMBER, 2))).is_equal(0)


func test_count_stops_in_uses_stopped_flags_and_face_weights() -> void:
	var indices: Array[int] = [0, 1, 2]
	var stopped: Array[bool] = [true, true, false]
	var results: Array[DiceFaceData] = [
		_face(DiceFaceData.FaceType.STOP),
		_face(DiceFaceData.FaceType.CURSED_STOP),
		_face(DiceFaceData.FaceType.CURSED_STOP),
	]
	var total: int = _service.count_stops_in(indices, stopped, results)
	assert_int(total).is_equal(3)


func test_count_shields_applies_shield_wall_multiplier() -> void:
	var results: Array[DiceFaceData] = [
		_face(DiceFaceData.FaceType.SHIELD, 2),
		_face(DiceFaceData.FaceType.SHIELD, 1),
		_face(DiceFaceData.FaceType.NUMBER, 3),
	]
	assert_int(_service.count_shields(results, false)).is_equal(3)
	assert_int(_service.count_shields(results, true)).is_equal(6)


func test_resolve_bust_outcome_safe_below_threshold() -> void:
	var outcome: int = _service.resolve_bust_outcome(2, 3, false, -1, false)
	assert_int(outcome).is_equal(OUTCOME_SAFE)


func test_resolve_bust_outcome_immune_takes_priority() -> void:
	var outcome: int = _service.resolve_bust_outcome(4, 3, true, 2, true)
	assert_int(outcome).is_equal(OUTCOME_IMMUNE_SAVE)


func test_resolve_bust_outcome_insurance_before_event() -> void:
	var outcome: int = _service.resolve_bust_outcome(4, 3, false, 1, true)
	assert_int(outcome).is_equal(OUTCOME_INSURANCE_SAVE)


func test_resolve_bust_outcome_event_before_bust() -> void:
	var outcome: int = _service.resolve_bust_outcome(4, 3, false, -1, true)
	assert_int(outcome).is_equal(OUTCOME_EVENT_SAVE)


func test_resolve_bust_outcome_bust_when_no_saves() -> void:
	var outcome: int = _service.resolve_bust_outcome(4, 3, false, -1, false)
	assert_int(outcome).is_equal(OUTCOME_BUST)


func test_absorbed_stop_count_clamps_to_roll_stop_count() -> void:
	assert_int(_service.absorbed_stop_count(3, 1)).is_equal(1)
	assert_int(_service.absorbed_stop_count(3, 5)).is_equal(3)
	assert_int(_service.absorbed_stop_count(0, 3)).is_equal(0)


func test_has_cursed_stop_in_detects_only_selected_indices() -> void:
	var results: Array[DiceFaceData] = [
		_face(DiceFaceData.FaceType.NUMBER, 1),
		_face(DiceFaceData.FaceType.CURSED_STOP),
		_face(DiceFaceData.FaceType.STOP),
	]
	var non_cursed_indices: Array[int] = [0, 2]
	var cursed_indices: Array[int] = [1]
	assert_bool(_service.has_cursed_stop_in(non_cursed_indices, results)).is_false()
	assert_bool(_service.has_cursed_stop_in(cursed_indices, results)).is_true()
