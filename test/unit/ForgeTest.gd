class_name ForgeTest
extends GdUnitTestSuite
## Unit tests for the Dice Forge probability table and helper logic.


func test_same_tier_grey_gives_green() -> void:
	for _i: int in 20:
		var die: DiceData = ForgePanel._roll_forge_result(
			DiceData.Rarity.GREY, DiceData.Rarity.GREY)
		assert_int(die.rarity).is_equal(DiceData.Rarity.GREEN)


func test_same_tier_green_gives_blue() -> void:
	for _i: int in 20:
		var die: DiceData = ForgePanel._roll_forge_result(
			DiceData.Rarity.GREEN, DiceData.Rarity.GREEN)
		assert_int(die.rarity).is_equal(DiceData.Rarity.BLUE)


func test_same_tier_blue_gives_purple() -> void:
	for _i: int in 20:
		var die: DiceData = ForgePanel._roll_forge_result(
			DiceData.Rarity.BLUE, DiceData.Rarity.BLUE)
		assert_int(die.rarity).is_equal(DiceData.Rarity.PURPLE)


func test_cross_tier_returns_valid_rarity() -> void:
	## Cross-tier forges should always return a valid die.
	var pairs: Array = [
		[DiceData.Rarity.GREY, DiceData.Rarity.GREEN],
		[DiceData.Rarity.GREY, DiceData.Rarity.BLUE],
		[DiceData.Rarity.GREY, DiceData.Rarity.PURPLE],
		[DiceData.Rarity.GREEN, DiceData.Rarity.BLUE],
		[DiceData.Rarity.GREEN, DiceData.Rarity.PURPLE],
		[DiceData.Rarity.BLUE, DiceData.Rarity.PURPLE],
	]
	for pair: Array in pairs:
		for _i: int in 10:
			var die: DiceData = ForgePanel._roll_forge_result(
				pair[0] as DiceData.Rarity, pair[1] as DiceData.Rarity)
			assert_object(die).is_not_null()
			assert_str(die.dice_name).is_not_empty()


func test_order_independent() -> void:
	## _roll_forge_result normalizes order, so (GREEN, GREY) == (GREY, GREEN).
	seed(42)
	var die_a: DiceData = ForgePanel._roll_forge_result(
		DiceData.Rarity.GREEN, DiceData.Rarity.GREY)
	seed(42)
	var die_b: DiceData = ForgePanel._roll_forge_result(
		DiceData.Rarity.GREY, DiceData.Rarity.GREEN)
	assert_int(die_a.rarity).is_equal(die_b.rarity)


func test_random_die_of_rarity_returns_correct_tier() -> void:
	## _random_die_of_rarity should always return a die matching the tier.
	for _i: int in 20:
		var die: DiceData = ForgePanel._random_die_of_rarity(DiceData.Rarity.GREEN)
		assert_int(die.rarity).is_equal(DiceData.Rarity.GREEN)


func test_min_dice_constant() -> void:
	assert_int(ForgePanel.MIN_DICE_FOR_FORGE).is_equal(4)


func test_forge_chance_constant() -> void:
	assert_float(ForgePanel.FORGE_CHANCE).is_equal_approx(0.25, 0.001)


func test_pick_result_rarity_grey_green_distribution() -> void:
	## Grey + Green: 55% Green, 30% Blue, 15% Grey.
	## Over many samples the majority should be Green.
	var counts: Dictionary = {DiceData.Rarity.GREY: 0, DiceData.Rarity.GREEN: 0, DiceData.Rarity.BLUE: 0}
	for _i: int in 1000:
		var r: DiceData.Rarity = ForgePanel._pick_result_rarity(
			DiceData.Rarity.GREY, DiceData.Rarity.GREEN)
		counts[r] = counts.get(r, 0) + 1
	# Green should be the most common result.
	assert_bool(counts[DiceData.Rarity.GREEN] > counts[DiceData.Rarity.BLUE]).is_true()
	assert_bool(counts[DiceData.Rarity.GREEN] > counts[DiceData.Rarity.GREY]).is_true()
