extends GdUnitTestSuite

## Tests for SaveManager cosmetics purchasing and equipping system (Feature #11)


func test_cosmetic_purchasable_when_mastery_unlocked_and_not_owned() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	manager.purchased_cosmetics.clear()
	
	# Set up mastery: die has level 2 (unlocks "glow" cosmetic through Feature #10)
	manager.dice_mastery["Standard Die"] = {"level": 2, "total_runs_used": 5, "unlocked_cosmetics": ["glow"]}
	
	# "glow" should be purchasable
	assert_bool(manager.is_cosmetic_purchasable("Standard Die", "glow")).is_true()


func test_cosmetic_not_purchasable_when_mastery_not_unlocked() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	manager.purchased_cosmetics.clear()
	
	# Set up mastery: die has level 1 (does NOT unlock "glow")
	manager.dice_mastery["Standard Die"] = {"level": 1, "total_runs_used": 1, "unlocked_cosmetics": []}
	
	# "glow" should NOT be purchasable
	assert_bool(manager.is_cosmetic_purchasable("Standard Die", "glow")).is_false()


func test_cosmetic_not_purchasable_when_already_purchased() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	manager.purchased_cosmetics.clear()
	
	# Set up mastery with glow unlocked
	manager.dice_mastery["Standard Die"] = {"level": 2, "total_runs_used": 5, "unlocked_cosmetics": ["glow"]}
	
	# Purchase the cosmetic
	manager.purchase_cosmetic("Standard Die", "glow")
	
	# Should NOT be purchasable again
	assert_bool(manager.is_cosmetic_purchasable("Standard Die", "glow")).is_false()


func test_cosmetic_purchased_successfully() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	manager.purchased_cosmetics.clear()
	
	# Set up mastery
	manager.dice_mastery["Standard Die"] = {"level": 2, "total_runs_used": 5, "unlocked_cosmetics": ["glow"]}
	
	# Purchase
	var result: bool = manager.purchase_cosmetic("Standard Die", "glow")
	
	assert_bool(result).is_true()
	assert_bool(manager.is_cosmetic_purchased("Standard Die", "glow")).is_true()


func test_purchase_cosmetic_returns_false_for_non_purchasable() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	manager.purchased_cosmetics.clear()
	
	# Try to purchase without mastery unlock
	var result: bool = manager.purchase_cosmetic("Standard Die", "glow")
	
	assert_bool(result).is_false()


func test_equip_cosmetic_after_purchase() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	manager.purchased_cosmetics.clear()
	manager.equipped_cosmetics.clear()
	
	# Set up and purchase
	manager.dice_mastery["Lucky Die"] = {"level": 2, "total_runs_used": 5, "unlocked_cosmetics": ["glow"]}
	manager.purchase_cosmetic("Lucky Die", "glow")
	
	# Equip
	var result: bool = manager.equip_cosmetic("Lucky Die", "glow")
	
	assert_bool(result).is_true()
	assert_string(manager.get_equipped_cosmetic("Lucky Die")).is_equal("glow")


func test_equip_cosmetic_fails_if_not_purchased() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	manager.purchased_cosmetics.clear()
	manager.equipped_cosmetics.clear()
	
	var result: bool = manager.equip_cosmetic("Lucky Die", "glow")
	
	assert_bool(result).is_false()


func test_unequip_cosmetic() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	manager.purchased_cosmetics.clear()
	manager.equipped_cosmetics.clear()
	
	# Set up and equip
	manager.dice_mastery["Golden Die"] = {"level": 2, "total_runs_used": 5, "unlocked_cosmetics": ["glow"]}
	manager.purchase_cosmetic("Golden Die", "glow")
	manager.equip_cosmetic("Golden Die", "glow")
	
	# Unequip
	manager.unequip_cosmetic("Golden Die")
	
	assert_string(manager.get_equipped_cosmetic("Golden Die")).is_equal("")


func test_get_equipped_cosmetic_returns_empty_if_none() -> void:
	var manager := SaveManager
	manager.equipped_cosmetics.clear()
	
	var cosmetic: String = manager.get_equipped_cosmetic("Explosive Die")
	
	assert_string(cosmetic).is_equal("")


func test_get_purchased_cosmetics_for_die() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	manager.purchased_cosmetics.clear()
	
	# Set up mastery with multiple cosmetics
	manager.dice_mastery["Heavy Die"] = {
		"level": 4,
		"total_runs_used": 40,
		"unlocked_cosmetics": ["glow", "color_shift", "particle_trail"]
	}
	
	# Purchase multiple
	manager.purchase_cosmetic("Heavy Die", "glow")
	manager.purchase_cosmetic("Heavy Die", "color_shift")
	
	var purchased: Array = manager.get_purchased_cosmetics_for_die("Heavy Die")
	
	assert_int(purchased.size()).is_equal(2)
	assert_bool("glow" in purchased).is_true()
	assert_bool("color_shift" in purchased).is_true()


func test_get_purchased_cosmetics_returns_empty_for_new_die() -> void:
	var manager := SaveManager
	manager.purchased_cosmetics.clear()
	
	var purchased: Array = manager.get_purchased_cosmetics_for_die("Unknown Die")
	
	assert_int(purchased.size()).is_equal(0)


func test_cosmetics_persist_across_save_load() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	manager.purchased_cosmetics.clear()
	manager.equipped_cosmetics.clear()
	
	# Set up and purchase
	manager.dice_mastery["Standard Die"] = {"level": 2, "total_runs_used": 5, "unlocked_cosmetics": ["glow"]}
	manager.purchase_cosmetic("Standard Die", "glow")
	manager.equip_cosmetic("Standard Die", "glow")
	
	# Simulate save/load
	var saved_purchased: Dictionary = manager.purchased_cosmetics.duplicate(true)
	var saved_equipped: Dictionary = manager.equipped_cosmetics.duplicate(true)
	
	manager.purchased_cosmetics.clear()
	manager.equipped_cosmetics.clear()
	
	manager.purchased_cosmetics = saved_purchased
	manager.equipped_cosmetics = saved_equipped
	
	assert_bool(manager.is_cosmetic_purchased("Standard Die", "glow")).is_true()
	assert_string(manager.get_equipped_cosmetic("Standard Die")).is_equal("glow")


func test_multiple_dice_independent_cosmetics() -> void:
	var manager := SaveManager
	manager.dice_mastery.clear()
	manager.purchased_cosmetics.clear()
	manager.equipped_cosmetics.clear()
	
	# Set up two dice
	manager.dice_mastery["Die A"] = {"level": 2, "total_runs_used": 5, "unlocked_cosmetics": ["glow"]}
	manager.dice_mastery["Die B"] = {"level": 3, "total_runs_used": 15, "unlocked_cosmetics": ["glow", "color_shift"]}
	
	# Purchase different cosmetics
	manager.purchase_cosmetic("Die A", "glow")
	manager.purchase_cosmetic("Die B", "color_shift")
	
	# Equip different ones
	manager.equip_cosmetic("Die A", "glow")
	manager.equip_cosmetic("Die B", "color_shift")
	
	assert_string(manager.get_equipped_cosmetic("Die A")).is_equal("glow")
	assert_string(manager.get_equipped_cosmetic("Die B")).is_equal("color_shift")
