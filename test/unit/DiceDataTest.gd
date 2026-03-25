extends GdUnitTestSuite
## Unit tests for DiceData resource.


func test_make_standard_d6_has_six_faces() -> void:
	var die: DiceData = DiceData.make_standard_d6()
	assert_int(die.faces.size()).is_equal(6)


func test_make_standard_d6_name() -> void:
	var die: DiceData = DiceData.make_standard_d6()
	assert_str(die.dice_name).is_equal("Standard D6")


func test_standard_d6_face_composition() -> void:
	var die: DiceData = DiceData.make_standard_d6()
	var type_counts: Dictionary = {}
	for face: DiceFaceData in die.faces:
		var t: int = face.type
		type_counts[t] = type_counts.get(t, 0) + 1
	# Expected: 2× NUMBER, 1× AUTO_KEEP, 1× BLANK, 1× STOP  -- wait, let me recount
	# [NUMBER 1, NUMBER 1, NUMBER 2, AUTO_KEEP 2, BLANK 0, STOP 0]
	assert_int(type_counts.get(DiceFaceData.FaceType.NUMBER, 0)).is_equal(3)
	assert_int(type_counts.get(DiceFaceData.FaceType.AUTO_KEEP, 0)).is_equal(1)
	assert_int(type_counts.get(DiceFaceData.FaceType.BLANK, 0)).is_equal(1)
	assert_int(type_counts.get(DiceFaceData.FaceType.STOP, 0)).is_equal(1)


func test_roll_returns_valid_face() -> void:
	var die: DiceData = DiceData.make_standard_d6()
	for _i: int in 50:
		var face: DiceFaceData = die.roll()
		assert_object(face).is_not_null()
		assert_bool(die.faces.has(face)).is_true()


func test_roll_distribution_has_variety() -> void:
	# Roll many times and confirm we don't always get the same face type.
	var die: DiceData = DiceData.make_standard_d6()
	var seen_types: Dictionary = {}
	for _i: int in 200:
		var face: DiceFaceData = die.roll()
		seen_types[face.type] = true
	# With 200 rolls on a d6 we should hit at least 3 of 4 face types.
	assert_int(seen_types.size()).is_greater_equal(3)


func test_empty_die_has_no_faces() -> void:
	var die := DiceData.new()
	assert_int(die.faces.size()).is_equal(0)


# ---------------------------------------------------------------------------
# Lucky D6
# ---------------------------------------------------------------------------

func test_make_lucky_d6_has_six_faces() -> void:
	var die: DiceData = DiceData.make_lucky_d6()
	assert_int(die.faces.size()).is_equal(6)


func test_lucky_d6_has_no_blank() -> void:
	var die: DiceData = DiceData.make_lucky_d6()
	for face: DiceFaceData in die.faces:
		assert_int(face.type).is_not_equal(DiceFaceData.FaceType.BLANK)


func test_lucky_d6_name() -> void:
	var die: DiceData = DiceData.make_lucky_d6()
	assert_str(die.dice_name).is_equal("Lucky D6")


# ---------------------------------------------------------------------------
# Upgrade system
# ---------------------------------------------------------------------------

func test_upgrade_weakest_face_upgrades_stop() -> void:
	var die: DiceData = DiceData.make_standard_d6()
	# Standard die has a STOP face — that's the weakest.
	var result: bool = die.upgrade_weakest_face()
	assert_bool(result).is_true()
	# After upgrade, the former STOP should now be BLANK.
	var has_stop: bool = false
	for face: DiceFaceData in die.faces:
		if face.type == DiceFaceData.FaceType.STOP:
			has_stop = true
	assert_bool(has_stop).is_false()


func test_upgrade_weakest_face_twice() -> void:
	var die: DiceData = DiceData.make_standard_d6()
	die.upgrade_weakest_face()  # STOP → BLANK
	die.upgrade_weakest_face()  # One of the BLANKs → NUMBER(1)
	var blank_count: int = 0
	for face: DiceFaceData in die.faces:
		if face.type == DiceFaceData.FaceType.BLANK:
			blank_count += 1
	# Started with 1 BLANK + gained 1 from STOP upgrade, then lost 1 = 1 BLANK remaining.
	assert_int(blank_count).is_equal(1)


func test_face_power_ordering() -> void:
	var die := DiceData.new()
	var stop := DiceFaceData.new()
	stop.type = DiceFaceData.FaceType.STOP
	var blank := DiceFaceData.new()
	blank.type = DiceFaceData.FaceType.BLANK
	var num := DiceFaceData.new()
	num.type = DiceFaceData.FaceType.NUMBER
	num.value = 1
	var auto := DiceFaceData.new()
	auto.type = DiceFaceData.FaceType.AUTO_KEEP
	auto.value = 2
	assert_int(die._face_power(stop)).is_less(die._face_power(blank))
	assert_int(die._face_power(blank)).is_less(die._face_power(num))
	assert_int(die._face_power(num)).is_less(die._face_power(auto))
