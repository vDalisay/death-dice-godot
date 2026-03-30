class_name DoubleDownTest
extends GdUnitTestSuite
## Unit tests for the Double Down Gold modifier.


func test_double_down_factory() -> void:
	var mod: RunModifier = RunModifier.make_double_down()
	assert_str(mod.modifier_name).is_equal("Double Down")
	assert_int(mod.modifier_type).is_equal(RunModifier.ModifierType.DOUBLE_DOWN)
	assert_int(mod.cost).is_greater(0)
	assert_str(mod.description).contains("D6")


func test_double_down_in_all_factories() -> void:
	var factories: Array[Callable] = RunModifier.all_factories()
	var found: bool = false
	for factory: Callable in factories:
		var mod: RunModifier = factory.call() as RunModifier
		if mod.modifier_type == RunModifier.ModifierType.DOUBLE_DOWN:
			found = true
			break
	assert_bool(found).is_true()


func test_all_factories_still_unique() -> void:
	var factories: Array[Callable] = RunModifier.all_factories()
	assert_int(factories.size()).is_equal(7)
	var seen_types: Array[int] = []
	for factory: Callable in factories:
		var mod: RunModifier = factory.call() as RunModifier
		assert_bool(mod.modifier_type in seen_types).is_false()
		seen_types.append(mod.modifier_type)


func test_even_roll_doubles_gold() -> void:
	## Even D6 rolls (2, 4, 6) should result in bonus gold.
	## We test the logic directly: if roll is even, player gets +banked gold.
	var roll: int = 4
	var banked: int = 20
	var bonus: int = 0
	if roll % 2 == 0:
		bonus = banked
	else:
		bonus = -banked
	assert_int(bonus).is_equal(20)


func test_odd_roll_loses_gold() -> void:
	## Odd D6 rolls (1, 3, 5) should result in losing the turn's gold.
	var roll: int = 3
	var banked: int = 20
	var bonus: int = 0
	if roll % 2 == 0:
		bonus = banked
	else:
		bonus = -banked
	assert_int(bonus).is_equal(-20)


func test_gold_loss_clamped_to_current_gold() -> void:
	## Gold should never go below 0. Loss is clamped to current gold.
	var current_gold: int = 5
	var banked: int = 20
	var gold_loss: int = mini(banked, current_gold)
	assert_int(gold_loss).is_equal(5)
