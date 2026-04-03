extends GdUnitTestSuite

## Tests for SaveManager dice mastery progression system


func test_mastery_level_0_for_undiscovered_dice() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	
	assert_int(manager.get_die_mastery_level("Unknown Die")).is_equal(0)
	assert_int(manager.get_die_total_runs_used("Unknown Die")).is_equal(0)


func test_mastery_milestone_1_reached_at_1_run() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	
	manager.update_die_mastery_on_run_completion("Standard Die")
	
	assert_int(manager.get_die_mastery_level("Standard Die")).is_equal(1)
	assert_int(manager.get_die_total_runs_used("Standard Die")).is_equal(1)


func test_mastery_milestone_2_reached_at_5_runs() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	
	for _i in range(5):
		manager.update_die_mastery_on_run_completion("Standard Die")
	
	assert_int(manager.get_die_mastery_level("Standard Die")).is_equal(2)
	assert_int(manager.get_die_total_runs_used("Standard Die")).is_equal(5)


func test_mastery_milestone_3_reached_at_15_runs() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	
	for _i in range(15):
		manager.update_die_mastery_on_run_completion("Standard Die")
	
	assert_int(manager.get_die_mastery_level("Standard Die")).is_equal(3)
	assert_int(manager.get_die_total_runs_used("Standard Die")).is_equal(15)


func test_mastery_milestone_4_reached_at_40_runs() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	
	for _i in range(40):
		manager.update_die_mastery_on_run_completion("Standard Die")
	
	assert_int(manager.get_die_mastery_level("Standard Die")).is_equal(4)


func test_mastery_milestone_5_reached_at_100_runs() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	
	for _i in range(100):
		manager.update_die_mastery_on_run_completion("Standard Die")
	
	assert_int(manager.get_die_mastery_level("Standard Die")).is_equal(5)


func test_cosmetic_glow_unlocked_at_milestone_2() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	
	for _i in range(5):
		manager.update_die_mastery_on_run_completion("Lucky Die")
	
	assert_bool(manager.is_cosmetic_unlocked("Lucky Die", "glow")).is_true()


func test_cosmetic_color_shift_unlocked_at_milestone_3() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	
	for _i in range(15):
		manager.update_die_mastery_on_run_completion("Golden Die")
	
	assert_bool(manager.is_cosmetic_unlocked("Golden Die", "color_shift")).is_true()


func test_cosmetic_particle_trail_unlocked_at_milestone_4() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	
	for _i in range(40):
		manager.update_die_mastery_on_run_completion("Explosive Die")
	
	assert_bool(manager.is_cosmetic_unlocked("Explosive Die", "particle_trail")).is_true()


func test_cosmetic_legendary_shine_unlocked_at_milestone_5() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	
	for _i in range(100):
		manager.update_die_mastery_on_run_completion("Gambler Die")
	
	assert_bool(manager.is_cosmetic_unlocked("Gambler Die", "legendary_shine")).is_true()


func test_no_cosmetic_unlocked_before_milestone() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	
	manager.update_die_mastery_on_run_completion("Standard Die")
	
	assert_bool(manager.is_cosmetic_unlocked("Standard Die", "glow")).is_false()
	assert_bool(manager.is_cosmetic_unlocked("Standard Die", "color_shift")).is_false()


func test_multiple_cosmetics_accumulate() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	
	for _i in range(40):
		manager.update_die_mastery_on_run_completion("Lucky Die")
	
	# At 40 runs: level 4, should have glow (at 5), color_shift (at 15), particle_trail (at 40)
	assert_bool(manager.is_cosmetic_unlocked("Lucky Die", "glow")).is_true()
	assert_bool(manager.is_cosmetic_unlocked("Lucky Die", "color_shift")).is_true()
	assert_bool(manager.is_cosmetic_unlocked("Lucky Die", "particle_trail")).is_true()
	assert_bool(manager.is_cosmetic_unlocked("Lucky Die", "legendary_shine")).is_false()


func test_mastery_persists_across_save_load() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	
	# Simulate mastery progression
	for _i in range(15):
		manager.update_die_mastery_on_run_completion("Standard Die")
	
	var stored_level: int = manager.get_die_mastery_level("Standard Die")
	assert_int(stored_level).is_equal(3)
	
	# Clear and reload (simulated)
	var saved_mastery: Dictionary = manager.dice_mastery.duplicate(true)
	manager.dice_mastery.clear()
	manager.dice_mastery = saved_mastery
	
	assert_int(manager.get_die_mastery_level("Standard Die")).is_equal(3)


func test_independent_dice_mastery_levels() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	
	# First die at 15 runs (level 3)
	for _i in range(15):
		manager.update_die_mastery_on_run_completion("Die A")
	
	# Second die at 5 runs (level 2)
	for _i in range(5):
		manager.update_die_mastery_on_run_completion("Die B")
	
	assert_int(manager.get_die_mastery_level("Die A")).is_equal(3)
	assert_int(manager.get_die_mastery_level("Die B")).is_equal(2)
