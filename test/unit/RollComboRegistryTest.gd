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
		_make_face(DiceFaceData.FaceType.MULTIPLY, 2),
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


# ---------------------------------------------------------------------------
# New combos
# ---------------------------------------------------------------------------

func test_lucky_streak_triggers() -> void:
	var registry = auto_free(preload("res://Scripts/RollComboRegistry.gd").new())
	var results: Array[DiceFaceData] = [
		_make_face(DiceFaceData.FaceType.LUCK, 1),
		_make_face(DiceFaceData.FaceType.LUCK, 1),
		_make_face(DiceFaceData.FaceType.NUMBER, 3),
	]
	var stopped: Array[bool] = [false, false, false]
	var combos: Array[RollCombo] = registry.get_triggered_combos(results, stopped)
	assert_bool(_combo_ids(combos).has("lucky_streak")).is_true()


func test_full_defense_triggers() -> void:
	var registry = auto_free(preload("res://Scripts/RollComboRegistry.gd").new())
	var results: Array[DiceFaceData] = [
		_make_face(DiceFaceData.FaceType.SHIELD, 1),
		_make_face(DiceFaceData.FaceType.INSURANCE, 0),
		_make_face(DiceFaceData.FaceType.NUMBER, 2),
	]
	var stopped: Array[bool] = [false, false, false]
	var combos: Array[RollCombo] = registry.get_triggered_combos(results, stopped)
	assert_bool(_combo_ids(combos).has("full_defense")).is_true()


func test_all_in_triggers() -> void:
	var registry = auto_free(preload("res://Scripts/RollComboRegistry.gd").new())
	var results: Array[DiceFaceData] = [
		_make_face(DiceFaceData.FaceType.EXPLODE, 3),
		_make_face(DiceFaceData.FaceType.MULTIPLY, 2),
		_make_face(DiceFaceData.FaceType.NUMBER, 1),
	]
	var stopped: Array[bool] = [false, false, false]
	var combos: Array[RollCombo] = registry.get_triggered_combos(results, stopped)
	assert_bool(_combo_ids(combos).has("all_in")).is_true()


func test_registry_has_six_combos() -> void:
	var registry = auto_free(preload("res://Scripts/RollComboRegistry.gd").new())
	var all: Array[RollCombo] = registry.get_all_combos()
	assert_int(all.size()).is_equal(6)


# ---------------------------------------------------------------------------
# Combo bonus calculation
# ---------------------------------------------------------------------------

func test_single_combo_bonus_no_escalation() -> void:
	var combo: RollCombo = RollCombo.make("test", "Test", {}, Color.WHITE, 10)
	var active: Array[RollCombo] = [combo]
	assert_int(RollComboRegistry.calculate_combo_bonus(active)).is_equal(10)


func test_two_combos_apply_escalation() -> void:
	var c1: RollCombo = RollCombo.make("a", "A", {}, Color.WHITE, 5)
	var c2: RollCombo = RollCombo.make("b", "B", {}, Color.WHITE, 5)
	var active: Array[RollCombo] = [c1, c2]
	# (5+5) * 1.15 = 11.5 → 12
	assert_int(RollComboRegistry.calculate_combo_bonus(active)).is_equal(12)


func test_three_plus_combos_apply_higher_escalation() -> void:
	var c1: RollCombo = RollCombo.make("a", "A", {}, Color.WHITE, 5)
	var c2: RollCombo = RollCombo.make("b", "B", {}, Color.WHITE, 5)
	var c3: RollCombo = RollCombo.make("c", "C", {}, Color.WHITE, 5)
	var active: Array[RollCombo] = [c1, c2, c3]
	# (5+5+5) * 1.3 = 19.5 → 20
	assert_int(RollComboRegistry.calculate_combo_bonus(active)).is_equal(20)


func test_zero_combos_zero_bonus() -> void:
	var active: Array[RollCombo] = []
	assert_int(RollComboRegistry.calculate_combo_bonus(active)).is_equal(0)


func test_each_combo_has_bonus_points() -> void:
	var registry = auto_free(preload("res://Scripts/RollComboRegistry.gd").new())
	var all: Array[RollCombo] = registry.get_all_combos()
	for combo: RollCombo in all:
		assert_int(combo.bonus_points).is_greater(0)
