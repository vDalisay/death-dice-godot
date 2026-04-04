extends GdUnitTestSuite
## Unit tests for TurnScoreService scoring rules.

var _service: RefCounted


func before_test() -> void:
	_service = auto_free(preload("res://Scripts/TurnScoreService.gd").new())


func _face(type: DiceFaceData.FaceType, value: int) -> DiceFaceData:
	var face := DiceFaceData.new()
	face.type = type
	face.value = value
	return face


func test_calculate_turn_score_applies_number_bonuses() -> void:
	var results: Array[DiceFaceData] = [
		_face(DiceFaceData.FaceType.NUMBER, 4),
		_face(DiceFaceData.FaceType.NUMBER, 2),
	]
	var stopped: Array[bool] = [false, false]
	var score: int = _service.calculate_turn_score(results, stopped, true, true, false, false)
	# Die0: 4 +2 (glass) +3 (high roller), Die1: 2 +2 (glass)
	assert_int(score).is_equal(13)


func test_calculate_turn_score_applies_multiply_and_multiply_left() -> void:
	var results: Array[DiceFaceData] = [
		_face(DiceFaceData.FaceType.NUMBER, 2),
		_face(DiceFaceData.FaceType.MULTIPLY_LEFT, 3),
		_face(DiceFaceData.FaceType.MULTIPLY, 2),
	]
	var stopped: Array[bool] = [false, false, false]
	var score: int = _service.calculate_turn_score(results, stopped, false, false, false, false)
	# Base scores: [2,0,0] -> left multiply => [6,0,0], global multiply x2 => 12
	assert_int(score).is_equal(12)


func test_calculate_turn_score_applies_overcharge_to_explode() -> void:
	var results: Array[DiceFaceData] = [
		_face(DiceFaceData.FaceType.EXPLODE, 3),
	]
	var stopped: Array[bool] = [false]
	var score: int = _service.calculate_turn_score(results, stopped, false, false, true, false)
	assert_int(score).is_equal(6)


func test_calculate_turn_score_applies_chain_lightning_bonus() -> void:
	var results: Array[DiceFaceData] = [
		_face(DiceFaceData.FaceType.NUMBER, 2),
		_face(DiceFaceData.FaceType.NUMBER, 2),
		_face(DiceFaceData.FaceType.NUMBER, 2),
	]
	var stopped: Array[bool] = [false, false, false]
	var score: int = _service.calculate_turn_score(results, stopped, false, false, false, true)
	# Three equal scores => +3 per die => (2+3) * 3
	assert_int(score).is_equal(15)


func test_calculate_per_die_scores_returns_multiplied_values() -> void:
	var results: Array[DiceFaceData] = [
		_face(DiceFaceData.FaceType.NUMBER, 2),
		_face(DiceFaceData.FaceType.AUTO_KEEP, 1),
		_face(DiceFaceData.FaceType.MULTIPLY, 3),
	]
	var stopped: Array[bool] = [false, false, false]
	var per_die: Array[int] = _service.calculate_per_die_scores(results, stopped, false, false, false)
	assert_int(per_die[0]).is_equal(6)
	assert_int(per_die[1]).is_equal(3)
	assert_int(per_die[2]).is_equal(0)
