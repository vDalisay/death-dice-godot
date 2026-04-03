extends GdUnitTestSuite
## Verifies GameManager.reset_run() applies prestige unlock effects.

var _saved_unlocks: Array[String]
var _saved_archetype: int


func before_test() -> void:
	_saved_unlocks = SaveManager.prestige_unlocks.duplicate()
	_saved_archetype = int(GameManager.chosen_archetype)


func after_test() -> void:
	SaveManager.prestige_unlocks = _saved_unlocks.duplicate()
	GameManager.set_archetype(_saved_archetype as GameManager.Archetype)
	GameManager.reset_run()


func test_reset_run_applies_starting_gold_prestige_unlock() -> void:
	SaveManager.prestige_unlocks = ["starting_gold"]
	GameManager.set_archetype(GameManager.Archetype.CAUTION)
	GameManager.reset_run()
	assert_int(GameManager.gold).is_equal(20)
	assert_int(GameManager.prestige_starting_gold_bonus).is_equal(20)


func test_reset_run_applies_reward_reroll_and_reroute_flags() -> void:
	SaveManager.prestige_unlocks = ["reward_reroll", "reroute_token"]
	GameManager.reset_run()
	assert_bool(GameManager.prestige_reward_reroll_available).is_true()
	assert_int(GameManager.prestige_reroute_uses).is_equal(1)
	assert_bool(GameManager.use_reroute_token()).is_true()
	assert_int(GameManager.prestige_reroute_uses).is_equal(0)


func test_fortunes_fool_starting_gold_with_prestige_bonus() -> void:
	SaveManager.prestige_unlocks = ["new_archetype", "starting_gold"]
	GameManager.set_archetype(GameManager.Archetype.FORTUNE_FOOL)
	GameManager.reset_run()
	assert_int(GameManager.gold).is_equal(35)
	assert_int(GameManager.dice_pool.size()).is_equal(10)
