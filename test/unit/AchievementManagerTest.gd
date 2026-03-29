extends GdUnitTestSuite
## Unit tests for AchievementManager and persisted unlock flow.

var _saved_unlocks: Dictionary = {}


func before_test() -> void:
	_saved_unlocks = SaveManager.unlocked_achievements.duplicate(true)
	SaveManager.unlocked_achievements.clear()


func after_test() -> void:
	SaveManager.unlocked_achievements = _saved_unlocks.duplicate(true)


func test_total_achievement_count_positive() -> void:
	assert_int(AchievementManager.get_total_achievement_count()).is_greater(0)


func test_on_bank_unlocks_first_bank() -> void:
	AchievementManager.on_bank(10, 1, 1, 5, 1)
	assert_bool(AchievementManager.is_unlocked("first_bank")).is_true()


func test_on_bust_unlocks_first_bust() -> void:
	AchievementManager.on_bust()
	assert_bool(AchievementManager.is_unlocked("first_bust")).is_true()


func test_jackpot_unlock_condition() -> void:
	AchievementManager.on_bank(50, 0, 0, 5, 1)
	assert_bool(AchievementManager.is_unlocked("jackpot")).is_true()
