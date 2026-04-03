extends GdUnitTestSuite
## Unit tests for side-bet state and resolution helpers in GameManager.

var _gm: Node


func before_test() -> void:
	_gm = auto_free(preload("res://Scripts/GameManager.gd").new())
	_gm.gold = 100


func test_set_insurance_bet_deducts_premium_and_pays_on_bust() -> void:
	_gm.set_insurance_bet(10, 25)
	assert_int(_gm.gold).is_equal(90)
	var payout: int = _gm.resolve_insurance_bet()
	assert_int(payout).is_equal(25)
	assert_int(_gm.gold).is_equal(115)
	assert_int(_gm.insurance_payout).is_equal(0)


func test_resolve_insurance_bet_returns_zero_when_none_active() -> void:
	var payout: int = _gm.resolve_insurance_bet()
	assert_int(payout).is_equal(0)
	assert_int(_gm.gold).is_equal(100)


func test_heat_bet_hits_when_stops_match_target() -> void:
	_gm.set_heat_bet(2, 15, 45)
	assert_int(_gm.gold).is_equal(85)
	var payout: int = _gm.resolve_heat_bet(2)
	assert_int(payout).is_equal(45)
	assert_int(_gm.gold).is_equal(130)
	assert_int(_gm.heat_bet_target_stops).is_equal(-1)


func test_heat_bet_miss_returns_zero() -> void:
	_gm.set_heat_bet(3, 15, 45)
	var payout: int = _gm.resolve_heat_bet(1)
	assert_int(payout).is_equal(0)
	assert_int(_gm.gold).is_equal(85)
	assert_int(_gm.heat_bet_target_stops).is_equal(-1)


func test_even_odd_bet_win_push_loss() -> void:
	# Win: bet EVEN, more even values than odd values.
	_gm.set_even_odd_bet(true, 10)
	assert_int(_gm.gold).is_equal(90)
	var win_result: int = _gm.resolve_even_odd_bet(3, 1)
	assert_int(win_result).is_equal(10)
	assert_int(_gm.gold).is_equal(110)

	# Push: tie should refund wager.
	_gm.set_even_odd_bet(true, 10)
	assert_int(_gm.gold).is_equal(100)
	var push_result: int = _gm.resolve_even_odd_bet(2, 2)
	assert_int(push_result).is_equal(0)
	assert_int(_gm.gold).is_equal(110)

	# Loss: bet EVEN, odd majority.
	_gm.set_even_odd_bet(true, 10)
	assert_int(_gm.gold).is_equal(100)
	var loss_result: int = _gm.resolve_even_odd_bet(1, 3)
	assert_int(loss_result).is_equal(-10)
	assert_int(_gm.gold).is_equal(100)


func test_on_shop_entered_clears_all_active_bets() -> void:
	_gm.set_insurance_bet(10, 25)
	_gm.set_heat_bet(2, 15, 45)
	_gm.set_even_odd_bet(false, 5)
	_gm.on_shop_entered()
	assert_int(_gm.insurance_payout).is_equal(0)
	assert_int(_gm.heat_bet_target_stops).is_equal(-1)
	assert_int(_gm.heat_bet_payout).is_equal(0)
	assert_int(_gm.even_odd_bet_wager).is_equal(0)
