extends GdUnitTestSuite
## Unit tests for DiceRewardOverlay rarity and dice pool logic.

const OverlayScript: GDScript = preload("res://Scripts/DiceRewardOverlay.gd")
const OverlayScene: PackedScene = preload("res://Scenes/DiceRewardOverlay.tscn")


# ---------------------------------------------------------------------------
# Weight calculation
# ---------------------------------------------------------------------------

func test_base_weights_sum_to_one() -> void:
	var weights: Array[float] = OverlayScript._calc_weights(0)
	var total: float = weights[0] + weights[1] + weights[2] + weights[3]
	assert_float(total).is_equal_approx(1.0, 0.001)


func test_base_weights_grey_is_highest() -> void:
	var weights: Array[float] = OverlayScript._calc_weights(0)
	assert_float(weights[0]).is_greater(weights[1])
	assert_float(weights[1]).is_greater(weights[2])
	assert_float(weights[2]).is_greater(weights[3])


func test_high_luck_reduces_grey() -> void:
	var base: Array[float] = OverlayScript._calc_weights(0)
	var lucky: Array[float] = OverlayScript._calc_weights(5)
	assert_float(lucky[0]).is_less(base[0])


func test_high_luck_increases_purple() -> void:
	var base: Array[float] = OverlayScript._calc_weights(0)
	var lucky: Array[float] = OverlayScript._calc_weights(5)
	assert_float(lucky[3]).is_greater(base[3])


func test_grey_weight_has_minimum() -> void:
	# Even with extreme luck, grey should not go below MIN_GREY_WEIGHT.
	var weights: Array[float] = OverlayScript._calc_weights(100)
	# After normalization, the raw grey was clamped to MIN_GREY_WEIGHT (0.10).
	# So the normalized value should be > 0.
	assert_float(weights[0]).is_greater(0.0)


func test_weights_always_sum_to_one() -> void:
	for luck: int in [0, 1, 3, 5, 8, 10, 20]:
		var weights: Array[float] = OverlayScript._calc_weights(luck)
		var total: float = weights[0] + weights[1] + weights[2] + weights[3]
		assert_float(total).is_equal_approx(1.0, 0.001)


# ---------------------------------------------------------------------------
# Rarity rolling
# ---------------------------------------------------------------------------

func test_roll_rarity_returns_valid_rarity() -> void:
	var weights: Array[float] = OverlayScript._calc_weights(0)
	for _i: int in 100:
		var rarity: DiceData.Rarity = OverlayScript._roll_rarity(weights)
		assert_int(rarity).is_greater_equal(DiceData.Rarity.GREY)
		assert_int(rarity).is_less_equal(DiceData.Rarity.PURPLE)


# ---------------------------------------------------------------------------
# Die pool selection
# ---------------------------------------------------------------------------

func test_pick_die_grey_returns_valid_die() -> void:
	for _i: int in 20:
		var die: DiceData = OverlayScript._pick_die_for_rarity(DiceData.Rarity.GREY)
		assert_object(die).is_not_null()
		assert_int(die.rarity).is_equal(DiceData.Rarity.GREY)


func test_pick_die_green_returns_valid_die() -> void:
	for _i: int in 20:
		var die: DiceData = OverlayScript._pick_die_for_rarity(DiceData.Rarity.GREEN)
		assert_object(die).is_not_null()
		assert_int(die.rarity).is_equal(DiceData.Rarity.GREEN)


func test_pick_die_blue_returns_valid_die() -> void:
	for _i: int in 20:
		var die: DiceData = OverlayScript._pick_die_for_rarity(DiceData.Rarity.BLUE)
		assert_object(die).is_not_null()
		assert_int(die.rarity).is_equal(DiceData.Rarity.BLUE)


func test_pick_die_purple_returns_valid_die() -> void:
	for _i: int in 20:
		var die: DiceData = OverlayScript._pick_die_for_rarity(DiceData.Rarity.PURPLE)
		assert_object(die).is_not_null()
		assert_int(die.rarity).is_equal(DiceData.Rarity.PURPLE)


func test_pick_die_has_faces() -> void:
	for rarity: int in [DiceData.Rarity.GREY, DiceData.Rarity.GREEN, DiceData.Rarity.BLUE, DiceData.Rarity.PURPLE]:
		var die: DiceData = OverlayScript._pick_die_for_rarity(rarity as DiceData.Rarity)
		assert_int(die.faces.size()).is_greater(0)


# ---------------------------------------------------------------------------
# Rarity name
# ---------------------------------------------------------------------------

func test_rarity_name_grey() -> void:
	assert_str(OverlayScript._rarity_name(DiceData.Rarity.GREY)).is_equal("COMMON")


func test_rarity_name_purple() -> void:
	assert_str(OverlayScript._rarity_name(DiceData.Rarity.PURPLE)).is_equal("EPIC")


func test_open_builds_three_reward_cards() -> void:
	var overlay: ColorRect = auto_free(OverlayScene.instantiate()) as ColorRect
	add_child(overlay)
	await await_idle_frame()
	overlay.call("open", 0)
	assert_int(overlay.get("_cards").size()).is_equal(3)


func test_open_offers_one_reroll_evolving_die() -> void:
	GameManager.current_loop = 2
	var overlay: ColorRect = auto_free(OverlayScene.instantiate()) as ColorRect
	add_child(overlay)
	await await_idle_frame()
	overlay.call("open", 0)
	var options: Array[DiceData] = overlay.get("_dice_options") as Array[DiceData]
	var evolving_count: int = 0
	for die: DiceData in options:
		if die != null and die.is_reroll_evolving():
			evolving_count += 1
	assert_int(options.size()).is_equal(3)
	assert_int(evolving_count).is_equal(1)
