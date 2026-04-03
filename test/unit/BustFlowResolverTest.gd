extends GdUnitTestSuite
## Unit tests for BustFlowResolver.

var _resolver: RefCounted


func before_test() -> void:
	_resolver = auto_free(preload("res://Scripts/BustFlowResolver.gd").new())


func test_threshold_lenient_on_turns_1_to_3() -> void:
	assert_int(_resolver.get_bust_threshold(3, 1, false, false, 3)).is_equal(4)
	assert_int(_resolver.get_bust_threshold(3, 3, false, false, 3)).is_equal(4)
	assert_int(_resolver.get_bust_threshold(3, 4, false, false, 3)).is_equal(3)


func test_threshold_glass_cannon_penalty_respects_minimum() -> void:
	assert_int(_resolver.get_bust_threshold(1, 4, true, false, 3)).is_equal(1)
	assert_int(_resolver.get_bust_threshold(3, 4, true, false, 3)).is_equal(2)


func test_threshold_last_stand_bonus_at_one_life() -> void:
	assert_int(_resolver.get_bust_threshold(3, 4, false, true, 1)).is_equal(5)
	assert_int(_resolver.get_bust_threshold(3, 4, false, true, 2)).is_equal(3)


func test_immunity_rules_by_archetype_and_stage() -> void:
	assert_bool(_resolver.is_immune_turn(3, 1, int(GameManager.Archetype.CAUTION))).is_true()
	assert_bool(_resolver.is_immune_turn(4, 1, int(GameManager.Archetype.CAUTION))).is_false()
	assert_bool(_resolver.is_immune_turn(1, 1, int(GameManager.Archetype.RISK_IT))).is_true()
	assert_bool(_resolver.is_immune_turn(2, 1, int(GameManager.Archetype.RISK_IT))).is_false()
	assert_bool(_resolver.is_immune_turn(1, 2, int(GameManager.Archetype.RISK_IT))).is_false()


func test_effective_stops_uses_shields_and_clamps() -> void:
	assert_int(_resolver.effective_stops(5, 2)).is_equal(3)
	assert_int(_resolver.effective_stops(1, 3)).is_equal(0)
