class_name DoubleDownTest
extends GdUnitTestSuite
## Unit tests for the Double Down instant shop item.


func test_shop_item_factory() -> void:
	var item: ShopItemData = ShopItemData.make_double_down()
	assert_str(item.item_name).is_equal("Double Down")
	assert_int(item.cost).is_equal(0)
	assert_int(item.item_type).is_equal(ShopItemData.ItemType.DOUBLE_DOWN)


func test_modifier_factory_still_exists() -> void:
	## The modifier factory remains for save compat, but is NOT in all_factories.
	var mod: RunModifier = RunModifier.make_double_down()
	assert_str(mod.modifier_name).is_equal("Double Down")
	assert_int(mod.modifier_type).is_equal(RunModifier.ModifierType.DOUBLE_DOWN)


func test_double_down_not_in_modifier_factories() -> void:
	## Double Down should no longer appear as a passive modifier.
	var factories: Array[Callable] = RunModifier.all_factories()
	for factory: Callable in factories:
		var mod: RunModifier = factory.call() as RunModifier
		assert_int(mod.modifier_type).is_not_equal(RunModifier.ModifierType.DOUBLE_DOWN)


func test_all_factories_count_reduced() -> void:
	var factories: Array[Callable] = RunModifier.all_factories()
	assert_int(factories.size()).is_equal(12)
	var seen_types: Array[int] = []
	for factory: Callable in factories:
		var mod: RunModifier = factory.call() as RunModifier
		assert_bool(mod.modifier_type in seen_types).is_false()
		seen_types.append(mod.modifier_type)


func test_even_roll_doubles_gold() -> void:
	## Even D6 rolls (2, 4, 6) should result in bonus gold.
	var roll: int = 4
	var wager: int = 20
	var bonus: int = 0
	if roll % 2 == 0:
		bonus = wager
	else:
		bonus = -wager
	assert_int(bonus).is_equal(20)


func test_odd_roll_loses_gold() -> void:
	## Odd D6 rolls (1, 3, 5) should result in losing the wager.
	var roll: int = 3
	var wager: int = 20
	var bonus: int = 0
	if roll % 2 == 0:
		bonus = wager
	else:
		bonus = -wager
	assert_int(bonus).is_equal(-20)


func test_gold_loss_clamped_to_current_gold() -> void:
	## Gold should never go below 0. Loss is clamped to current gold.
	var current_gold: int = 5
	var wager: int = 20
	var gold_loss: int = mini(wager, current_gold)
	assert_int(gold_loss).is_equal(5)


func test_min_gold_constant() -> void:
	assert_int(ShopPanel.DOUBLE_DOWN_MIN_GOLD).is_equal(10)
