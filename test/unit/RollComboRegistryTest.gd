extends GdUnitTestSuite
## Unit tests for named roll combo detection.


func _make_face(type: DiceFaceData.FaceType, value: int = 0) -> DiceFaceData:
	var face: DiceFaceData = DiceFaceData.new()
	face.type = type
	face.value = value
	return face


func _combo_ids(combos: Array[RollCombo]) -> Array[String]:
	var ids: Array[String] = []
	for combo: RollCombo in combos:
		ids.append(combo.combo_id)
	return ids


func test_shield_wall_combo_triggers() -> void:
	var registry = auto_free(preload("res://Scripts/RollComboRegistry.gd").new())
	var results: Array[DiceFaceData] = [
		_make_face(DiceFaceData.FaceType.SHIELD, 1),
		_make_face(DiceFaceData.FaceType.SHIELD, 1),
		_make_face(DiceFaceData.FaceType.NUMBER, 2),
	]
	var stopped: Array[bool] = [false, false, false]
	var combos: Array[RollCombo] = registry.get_triggered_combos(results, stopped)
	assert_bool(_combo_ids(combos).has("shield_wall")).is_true()


func test_chain_reaction_requires_two_explodes() -> void:
	var registry = auto_free(preload("res://Scripts/RollComboRegistry.gd").new())
	var results: Array[DiceFaceData] = [
		_make_face(DiceFaceData.FaceType.EXPLODE, 2),
		_make_face(DiceFaceData.FaceType.NUMBER, 3),
		_make_face(DiceFaceData.FaceType.AUTO_KEEP, 2),
	]
	var stopped: Array[bool] = [false, false, false]
	var combos: Array[RollCombo] = registry.get_triggered_combos(results, stopped)
	assert_bool(_combo_ids(combos).has("chain_reaction")).is_false()


func test_chain_reaction_combo_triggers_with_two_explodes() -> void:
	var registry = auto_free(preload("res://Scripts/RollComboRegistry.gd").new())
	var results: Array[DiceFaceData] = [
		_make_face(DiceFaceData.FaceType.EXPLODE, 2),
		_make_face(DiceFaceData.FaceType.EXPLODE, 2),
		_make_face(DiceFaceData.FaceType.NUMBER, 1),
	]
	var stopped: Array[bool] = [false, false, false]
	var combos: Array[RollCombo] = registry.get_triggered_combos(results, stopped)
	assert_bool(_combo_ids(combos).has("chain_reaction")).is_true()


func test_power_pair_combo_triggers() -> void:
	var registry = auto_free(preload("res://Scripts/RollComboRegistry.gd").new())
	var results: Array[DiceFaceData] = [
		_make_face(DiceFaceData.FaceType.MULTIPLY, 2),
		_make_face(DiceFaceData.FaceType.MULTIPLY_LEFT, 2),
		_make_face(DiceFaceData.FaceType.NUMBER, 4),
	]
	var stopped: Array[bool] = [false, false, false]
	var combos: Array[RollCombo] = registry.get_triggered_combos(results, stopped)
	assert_bool(_combo_ids(combos).has("power_pair")).is_true()


func test_stopped_faces_do_not_count_toward_combo() -> void:
	var registry = auto_free(preload("res://Scripts/RollComboRegistry.gd").new())
	var results: Array[DiceFaceData] = [
		_make_face(DiceFaceData.FaceType.SHIELD, 1),
		_make_face(DiceFaceData.FaceType.SHIELD, 1),
	]
	var stopped: Array[bool] = [true, false]
	var combos: Array[RollCombo] = registry.get_triggered_combos(results, stopped)
	assert_bool(_combo_ids(combos).has("shield_wall")).is_false()
