extends GdUnitTestSuite
## Unit tests for prestige currency and unlock purchasing in SaveManager.

var _sm


func before_test() -> void:
	_sm = auto_free(preload("res://Scripts/SaveManager.gd").new())
	_sm.prestige_currency = 0
	_sm.prestige_unlocks = []


func test_calculate_prestige_earnings() -> void:
	assert_int(_sm._calculate_prestige_earnings(0, 1)).is_equal(0)
	assert_int(_sm._calculate_prestige_earnings(1, 0)).is_equal(5)
	assert_int(_sm._calculate_prestige_earnings(3, 2)).is_equal(12)
	assert_int(_sm._calculate_prestige_earnings(5, 0)).is_equal(25)


func test_spend_prestige_currency_success_and_failure() -> void:
	_sm.add_prestige_currency(10)
	assert_int(_sm.prestige_currency).is_equal(10)
	assert_bool(_sm.spend_prestige_currency(7)).is_true()
	assert_int(_sm.prestige_currency).is_equal(3)
	assert_bool(_sm.spend_prestige_currency(4)).is_false()
	assert_int(_sm.prestige_currency).is_equal(3)


func test_purchase_prestige_unlock_idempotent() -> void:
	_sm.prestige_currency = 20
	assert_bool(_sm.purchase_prestige_unlock("starting_gold")).is_true()
	assert_bool(_sm.has_prestige_unlock("starting_gold")).is_true()
	var currency_after_first: int = _sm.prestige_currency
	assert_bool(_sm.purchase_prestige_unlock("starting_gold")).is_false()
	assert_int(_sm.prestige_currency).is_equal(currency_after_first)


func test_purchase_prestige_unlock_fails_when_insufficient() -> void:
	_sm.prestige_currency = 0
	assert_bool(_sm.purchase_prestige_unlock("new_archetype")).is_false()
	assert_bool(_sm.has_prestige_unlock("new_archetype")).is_false()


func test_skull_cosmetic_unlock_is_prestige_gated() -> void:
	assert_bool(_sm.is_cosmetic_unlocked("Standard Die", "skull_shimmer")).is_false()
	var unlocks: Array[String] = ["skull_cosmetic"]
	_sm.prestige_unlocks = unlocks
	assert_bool(_sm.is_cosmetic_unlocked("Standard Die", "skull_shimmer")).is_true()
	assert_bool(_sm.is_cosmetic_purchasable("Standard Die", "skull_shimmer")).is_true()
