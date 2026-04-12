extends GdUnitTestSuite
## Unit tests for the Pink Die and MULTIPLY_LEFT face type.

# ---------------------------------------------------------------------------
# DiceFaceData — MULTIPLY_LEFT display
# ---------------------------------------------------------------------------

func test_multiply_left_face_display() -> void:
	var face := DiceFaceData.new()
	face.type = DiceFaceData.FaceType.MULTIPLY_LEFT
	face.value = 2
	## MULTIPLY_LEFT normalizes to MULTIPLY on assignment; display text is now the same as MULTIPLY.
	assert_str(face.get_display_text()).is_equal("x2")


func test_multiply_left_face_display_value_3() -> void:
	var face := DiceFaceData.new()
	face.type = DiceFaceData.FaceType.MULTIPLY_LEFT
	face.value = 3
	assert_str(face.get_display_text()).is_equal("x3")


# ---------------------------------------------------------------------------
# DiceData — Pink D6 factory
# ---------------------------------------------------------------------------

func test_pink_d6_has_six_faces() -> void:
	var die: DiceData = DiceData.make_pink_d6()
	assert_int(die.faces.size()).is_equal(6)


func test_pink_d6_name() -> void:
	var die: DiceData = DiceData.make_pink_d6()
	assert_str(die.dice_name).is_equal("Pink D6")


func test_pink_d6_has_custom_color() -> void:
	var die: DiceData = DiceData.make_pink_d6()
	assert_bool(die.custom_color != Color.TRANSPARENT).is_true()
	assert_float(die.custom_color.r).is_equal_approx(1.0, 0.01)
	assert_float(die.custom_color.g).is_equal_approx(0.4, 0.01)
	assert_float(die.custom_color.b).is_equal_approx(0.7, 0.01)


func test_pink_d6_has_three_stops() -> void:
	var die: DiceData = DiceData.make_pink_d6()
	assert_int(die._count_stop_faces()).is_equal(3)


func test_pink_d6_has_two_multiply_faces() -> void:
	## Phase 3 replaced MULTIPLY_LEFT faces with MULTIPLY on the Pink D6.
	var die: DiceData = DiceData.make_pink_d6()
	var count: int = 0
	for face: DiceFaceData in die.faces:
		if face.type == DiceFaceData.FaceType.MULTIPLY:
			count += 1
	assert_int(count).is_equal(2)


func test_pink_d6_has_one_blank() -> void:
	var die: DiceData = DiceData.make_pink_d6()
	var count: int = 0
	for face: DiceFaceData in die.faces:
		if face.type == DiceFaceData.FaceType.BLANK:
			count += 1
	assert_int(count).is_equal(1)


func test_pink_d6_has_stop_face() -> void:
	var die: DiceData = DiceData.make_pink_d6()
	assert_bool(die.has_stop_face()).is_true()


func test_standard_d6_has_no_custom_color() -> void:
	var die: DiceData = DiceData.make_standard_d6()
	assert_bool(die.custom_color == Color.TRANSPARENT).is_true()


# ---------------------------------------------------------------------------
# DiceData — face power ordering for MULTIPLY_LEFT
# ---------------------------------------------------------------------------

func test_multiply_left_power_equals_multiply_tier() -> void:
	var die := DiceData.new()
	var ml := DiceFaceData.new()
	ml.type = DiceFaceData.FaceType.MULTIPLY_LEFT
	ml.value = 2
	var mult := DiceFaceData.new()
	mult.type = DiceFaceData.FaceType.MULTIPLY
	mult.value = 2
	# Both should be in the same tier (18 + value)
	assert_int(die._face_power(ml)).is_equal(die._face_power(mult))


func test_multiply_left_power_higher_than_auto_keep() -> void:
	var die := DiceData.new()
	var ml := DiceFaceData.new()
	ml.type = DiceFaceData.FaceType.MULTIPLY_LEFT
	ml.value = 2
	var ak := DiceFaceData.new()
	ak.type = DiceFaceData.FaceType.AUTO_KEEP
	ak.value = 2
	assert_int(die._face_power(ml)).is_greater(die._face_power(ak))


# ---------------------------------------------------------------------------
# DiceData — upgrade system with MULTIPLY_LEFT
# ---------------------------------------------------------------------------

func test_upgrade_pink_d6_targets_stop_not_multiply_left() -> void:
	var die: DiceData = DiceData.make_pink_d6()
	var result: bool = die.upgrade_weakest_face()
	assert_bool(result).is_true()
	# Should still have 2 MULTIPLY faces (formerly MULTIPLY_LEFT — Phase 3 migration)
	var ml_count: int = 0
	for face: DiceFaceData in die.faces:
		if face.type == DiceFaceData.FaceType.MULTIPLY:
			ml_count += 1
	assert_int(ml_count).is_equal(2)
	# Should have lost one STOP (upgraded to BLANK)
	assert_int(die._count_stop_faces()).is_equal(2)


func test_upgrade_preserves_last_stop_on_pink_d6() -> void:
	var die: DiceData = DiceData.make_pink_d6()
	# Upgrade 4 times to burn through stops + blank
	for _i: int in 4:
		die.upgrade_weakest_face()
	# Must still have at least 1 STOP (balance invariant)
	assert_bool(die.has_stop_face()).is_true()


# ---------------------------------------------------------------------------
# ShopItemData — Pink Die item
# ---------------------------------------------------------------------------

func test_pink_die_shop_item() -> void:
	var item: ShopItemData = ShopItemData.make_buy_pink_die()
	assert_str(item.item_name).is_equal("Pink Die")
	assert_int(item.cost).is_equal(45)
	assert_int(item.item_type).is_equal(ShopItemData.ItemType.BUY_PINK_DIE)


func test_pink_die_shop_item_has_description() -> void:
	var item: ShopItemData = ShopItemData.make_buy_pink_die()
	assert_str(item.description).is_not_empty()


# ---------------------------------------------------------------------------
# All dice invariant — include Pink D6
# ---------------------------------------------------------------------------

func test_all_dice_including_pink_have_at_least_one_stop() -> void:
	var dice: Array[DiceData] = [
		DiceData.make_standard_d6(),
		DiceData.make_lucky_d6(),
		DiceData.make_gambler_d6(),
		DiceData.make_golden_d6(),
		DiceData.make_heavy_d6(),
		DiceData.make_explosive_d6(),
		DiceData.make_blank_canvas_d6(),
		DiceData.make_pink_d6(),
	]
	for die: DiceData in dice:
		assert_bool(die.has_stop_face()).is_true()
