extends GdUnitTestSuite
## Unit tests for BustRiskEstimator probability and tooltip helpers.

var _service: RefCounted


func before_test() -> void:
	_service = auto_free(preload("res://Scripts/BustRiskEstimator.gd").new())


func _face(type: DiceFaceData.FaceType, value: int = 0) -> DiceFaceData:
	var face := DiceFaceData.new()
	face.type = type
	face.value = value
	return face


func _die(faces: Array[DiceFaceData]) -> DiceData:
	var die := DiceData.new()
	die.faces = faces
	return die


func test_estimate_next_reroll_bust_chance_is_certain_at_or_above_threshold() -> void:
	var pool: Array[DiceData] = []
	var keep: Array[bool] = []
	var keep_locked: Array[bool] = []
	var chance: float = _service.estimate_next_reroll_bust_chance(3, 3, pool, keep, keep_locked)
	assert_float(chance).is_equal(1.0)


func test_estimate_next_reroll_bust_chance_ignores_kept_dice() -> void:
	var pool: Array[DiceData] = [
		_die([
			_face(DiceFaceData.FaceType.STOP),
			_face(DiceFaceData.FaceType.BLANK),
		]),
	]
	var keep: Array[bool] = [true]
	var keep_locked: Array[bool] = [false]
	var chance: float = _service.estimate_next_reroll_bust_chance(0, 1, pool, keep, keep_locked)
	assert_float(chance).is_equal(0.0)


func test_estimate_next_reroll_bust_chance_accounts_for_cursed_stop_weight() -> void:
	var pool: Array[DiceData] = [
		_die([
			_face(DiceFaceData.FaceType.CURSED_STOP),
			_face(DiceFaceData.FaceType.BLANK),
		]),
	]
	var keep: Array[bool] = [false]
	var keep_locked: Array[bool] = [false]
	var chance: float = _service.estimate_next_reroll_bust_chance(0, 2, pool, keep, keep_locked)
	assert_float(chance).is_equal(0.5)


func test_estimate_next_reroll_bust_chance_combines_multiple_dice_distribution() -> void:
	var pool: Array[DiceData] = [
		_die([
			_face(DiceFaceData.FaceType.STOP),
			_face(DiceFaceData.FaceType.BLANK),
		]),
		_die([
			_face(DiceFaceData.FaceType.STOP),
			_face(DiceFaceData.FaceType.BLANK),
		]),
	]
	var keep: Array[bool] = [false, false]
	var keep_locked: Array[bool] = [false, false]
	var chance: float = _service.estimate_next_reroll_bust_chance(0, 2, pool, keep, keep_locked)
	assert_float(chance).is_equal(0.25)


func test_estimate_projected_bust_odds_grows_with_reroll_horizon() -> void:
	var one_roll: float = _service.estimate_projected_bust_odds(0.25, 0)
	var three_rolls: float = _service.estimate_projected_bust_odds(0.25, 2)
	assert_float(three_rolls).is_greater(one_roll)


func test_build_risk_details_includes_key_fields() -> void:
	var details: String = _service.build_risk_details(2, 1, 4, 0.3, 0.5, 3, 2)
	assert_str(details).contains("Bust odds (next reroll): 30%")
	assert_str(details).contains("Projected odds (current reroll streak): 50%")
	assert_str(details).contains("Stops: 2/4 (shields: 1)")
	assert_str(details).contains("Rerollable dice: 3 | Rerolls taken: 2")
