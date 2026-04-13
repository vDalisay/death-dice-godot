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


func _vector_positions(values: Array[Vector2]) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	positions.assign(values)
	return positions


func _bool_flags(values: Array[bool]) -> Array[bool]:
	var flags: Array[bool] = []
	flags.assign(values)
	return flags


func test_calculate_turn_score_applies_number_bonuses() -> void:
	var results: Array[DiceFaceData] = [
		_face(DiceFaceData.FaceType.NUMBER, 4),
		_face(DiceFaceData.FaceType.NUMBER, 2),
	]
	var stopped: Array[bool] = [false, false]
	var positions: Array[Vector2] = _vector_positions([Vector2.ZERO, Vector2(140.0, 0.0)])
	var multiplies_stops_flags: Array[bool] = _bool_flags([false, false])
	var was_displaced: Array[bool] = _bool_flags([false, false])
	var score: int = _service.calculate_turn_score(
		results,
		stopped,
		positions,
		multiplies_stops_flags,
		was_displaced,
		false,
		true,
		true,
		false,
		false
	)
	# Die0: 4 +2 (glass) +3 (high roller), Die1: 2 +2 (glass)
	assert_int(score).is_equal(13)


func test_calculate_turn_score_applies_proximity_multiplier_only_to_neighbors() -> void:
	var results: Array[DiceFaceData] = [
		_face(DiceFaceData.FaceType.NUMBER, 2),
		_face(DiceFaceData.FaceType.MULTIPLY, 3),
		_face(DiceFaceData.FaceType.MULTIPLY, 2),
	]
	var stopped: Array[bool] = [false, false, false]
	var multiplies_stops_flags: Array[bool] = _bool_flags([false, false, false])
	var was_displaced: Array[bool] = _bool_flags([false, false, false])
	var score: int = _service.calculate_turn_score(
		results,
		stopped,
		_vector_positions([Vector2.ZERO, Vector2(60.0, 0.0), Vector2(200.0, 0.0)]),
		multiplies_stops_flags,
		was_displaced,
		false,
		false,
		false,
		false,
		false
	)
	# Die0 is within range of die1 only: 2 * 3 = 6. Die2 is too far from die1 and scores 0 itself.
	assert_int(score).is_equal(6)


func test_calculate_turn_score_applies_overcharge_to_explode() -> void:
	var results: Array[DiceFaceData] = [
		_face(DiceFaceData.FaceType.EXPLODE, 3),
	]
	var stopped: Array[bool] = [false]
	var score: int = _service.calculate_turn_score(
		results,
		stopped,
		_vector_positions([Vector2.ZERO]),
		_bool_flags([false]),
		_bool_flags([false]),
		false,
		false,
		false,
		true,
		false
	)
	assert_int(score).is_equal(6)


func test_calculate_turn_score_applies_chain_lightning_bonus() -> void:
	var results: Array[DiceFaceData] = [
		_face(DiceFaceData.FaceType.NUMBER, 2),
		_face(DiceFaceData.FaceType.NUMBER, 2),
		_face(DiceFaceData.FaceType.NUMBER, 2),
	]
	var stopped: Array[bool] = [false, false, false]
	var score: int = _service.calculate_turn_score(
		results,
		stopped,
		_vector_positions([Vector2.ZERO, Vector2(120.0, 0.0), Vector2(240.0, 0.0)]),
		_bool_flags([false, false, false]),
		_bool_flags([false, false, false]),
		false,
		false,
		false,
		false,
		true
	)
	# Three equal scores => +3 per die => (2+3) * 3
	assert_int(score).is_equal(15)


func test_calculate_per_die_scores_returns_multiplied_values() -> void:
	var results: Array[DiceFaceData] = [
		_face(DiceFaceData.FaceType.NUMBER, 2),
		_face(DiceFaceData.FaceType.AUTO_KEEP, 1),
		_face(DiceFaceData.FaceType.MULTIPLY, 3),
	]
	var stopped: Array[bool] = [false, false, false]
	var positions: Array[Vector2] = _vector_positions([Vector2.ZERO, Vector2(40.0, 0.0), Vector2(80.0, 0.0)])
	var per_die: Array[int] = _service.calculate_per_die_scores(
		results,
		stopped,
		positions,
		_bool_flags([false, false, false]),
		_bool_flags([false, false, false]),
		false,
		false,
		false,
		false
	)
	assert_int(per_die[0]).is_equal(6)
	assert_int(per_die[1]).is_equal(3)
	assert_int(per_die[2]).is_equal(0)


func test_calculate_turn_score_applies_shrapnel_only_to_displaced_number_faces() -> void:
	var results: Array[DiceFaceData] = [
		_face(DiceFaceData.FaceType.NUMBER, 2),
		_face(DiceFaceData.FaceType.NUMBER, 5),
	]
	var stopped: Array[bool] = [false, false]
	var positions: Array[Vector2] = _vector_positions([Vector2.ZERO, Vector2(160.0, 0.0)])
	var multiplies_stops_flags: Array[bool] = _bool_flags([false, false])
	var was_displaced: Array[bool] = _bool_flags([true, false])
	var with_shrapnel: int = _service.calculate_turn_score(
		results,
		stopped,
		positions,
		multiplies_stops_flags,
		was_displaced,
		true,
		false,
		false,
		false,
		false
	)
	var without_shrapnel: int = _service.calculate_turn_score(
		results,
		stopped,
		positions,
		multiplies_stops_flags,
		was_displaced,
		false,
		false,
		false,
		false,
		false
	)
	assert_int(with_shrapnel).is_equal(8)
	assert_int(without_shrapnel).is_equal(7)


func test_calculate_effective_stop_counts_only_multiplies_nearby_stops() -> void:
	var results: Array[DiceFaceData] = [
		_face(DiceFaceData.FaceType.STOP, 0),
		_face(DiceFaceData.FaceType.MULTIPLY, 3),
		_face(DiceFaceData.FaceType.CURSED_STOP, 0),
	]
	var stopped: Array[bool] = [true, false, true]
	var effective_counts: Array[int] = _service.calculate_effective_stop_counts(
		results,
		stopped,
		_vector_positions([Vector2.ZERO, Vector2(60.0, 0.0), Vector2(200.0, 0.0)]),
		_bool_flags([false, true, false])
	)
	assert_int(effective_counts[0]).is_equal(3)
	assert_int(effective_counts[1]).is_equal(0)
	assert_int(effective_counts[2]).is_equal(2)
