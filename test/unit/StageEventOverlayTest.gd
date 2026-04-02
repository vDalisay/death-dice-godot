extends GdUnitTestSuite
## Unit tests for StageEventOverlay effects and GameManager event flags.

const StageEventScript: GDScript = preload("res://Scripts/StageEventOverlay.gd")

var _gm: Node
var _overlay: Node

## Snapshot of autoload state so we can restore in after_test.
var _orig_dice_pool: Array[DiceData] = []
var _orig_gold: int = 0
var _orig_lives: int = 0
var _orig_stage_target: int = 0


func before_test() -> void:
	# Local GameManager instance for flag-only tests.
	_gm = auto_free(preload("res://Scripts/GameManager.gd").new())
	_overlay = auto_free(StageEventScript.new())
	# Save autoload state before overlay effect tests touch it.
	_orig_dice_pool = GameManager.dice_pool.duplicate()
	_orig_gold = GameManager.gold
	_orig_lives = GameManager.lives
	_orig_stage_target = GameManager.stage_target_score


func after_test() -> void:
	# Restore autoload state to avoid bleeding between tests.
	GameManager.dice_pool = _orig_dice_pool
	GameManager.gold = _orig_gold
	GameManager.lives = _orig_lives
	GameManager.stage_target_score = _orig_stage_target
	GameManager.event_free_bust = false
	GameManager.event_target_multiplier = 1.0


# ---------------------------------------------------------------------------
# Event flag management
# ---------------------------------------------------------------------------

func test_event_flags_default_values() -> void:
	assert_bool(_gm.event_free_bust).is_false()
	assert_float(_gm.event_target_multiplier).is_equal(1.0)


func test_reset_event_flags() -> void:
	_gm.event_free_bust = true
	_gm.event_target_multiplier = 1.15
	_gm._reset_event_flags()
	assert_bool(_gm.event_free_bust).is_false()
	assert_float(_gm.event_target_multiplier).is_equal(1.0)


func test_reset_run_clears_event_flags() -> void:
	_gm.event_free_bust = true
	_gm.event_target_multiplier = 1.15
	_gm.reset_run()
	assert_bool(_gm.event_free_bust).is_false()
	assert_float(_gm.event_target_multiplier).is_equal(1.0)


# ---------------------------------------------------------------------------
# Blessing effects (use real GameManager autoload since overlay references it)
# ---------------------------------------------------------------------------

func test_boost_number_faces() -> void:
	var die: DiceData = DiceData.make_standard_d6()
	GameManager.dice_pool.append(die)
	var original_values: Array[int] = []
	for face: DiceFaceData in die.faces:
		original_values.append(face.value)
	_overlay._boost_number_faces(1)
	for i: int in die.faces.size():
		if die.faces[i].type == DiceFaceData.FaceType.NUMBER:
			assert_int(die.faces[i].value).is_equal(original_values[i] + 1)


func test_boost_shield_faces() -> void:
	var die: DiceData = DiceData.make_standard_d6()
	# Replace first non-stop face with a shield for testing.
	for face: DiceFaceData in die.faces:
		if face.type == DiceFaceData.FaceType.NUMBER:
			face.type = DiceFaceData.FaceType.SHIELD
			face.value = 1
			break
	GameManager.dice_pool.append(die)
	_overlay._boost_shield_faces(1)
	var found_shield: bool = false
	for face: DiceFaceData in die.faces:
		if face.type == DiceFaceData.FaceType.SHIELD:
			assert_int(face.value).is_equal(2)
			found_shield = true
			break
	assert_bool(found_shield).is_true()


func test_gain_random_dice() -> void:
	var before_size: int = GameManager.dice_pool.size()
	_overlay._gain_random_dice(2)
	assert_int(GameManager.dice_pool.size()).is_equal(before_size + 2)


func test_free_bust_sets_flag() -> void:
	_overlay._apply_effect({"type": 2})
	assert_bool(GameManager.event_free_bust).is_true()


func test_gain_gold_adds_30() -> void:
	var before_gold: int = GameManager.gold
	_overlay._apply_effect({"type": 4})
	assert_int(GameManager.gold).is_equal(before_gold + 30)


# ---------------------------------------------------------------------------
# Curse effects (use real GameManager autoload)
# ---------------------------------------------------------------------------

func test_lose_random_die() -> void:
	GameManager.dice_pool.append(DiceData.make_standard_d6())
	GameManager.dice_pool.append(DiceData.make_standard_d6())
	var before_size: int = GameManager.dice_pool.size()
	_overlay._lose_random_die()
	assert_int(GameManager.dice_pool.size()).is_equal(before_size - 1)


func test_lose_die_wont_go_below_one() -> void:
	# Reduce pool to exactly 1 die.
	GameManager.dice_pool.clear()
	GameManager.dice_pool.append(DiceData.make_standard_d6())
	_overlay._lose_random_die()
	assert_int(GameManager.dice_pool.size()).is_equal(1)


func test_add_cursed_stop_to_random_die() -> void:
	var die: DiceData = DiceData.make_standard_d6()
	GameManager.dice_pool.clear()
	GameManager.dice_pool.append(die)
	_overlay._add_cursed_stop_to_random_die()
	var has_cursed: bool = false
	for face: DiceFaceData in die.faces:
		if face.type == DiceFaceData.FaceType.CURSED_STOP:
			has_cursed = true
			break
	assert_bool(has_cursed).is_true()


func test_boost_targets_sets_multiplier() -> void:
	GameManager.stage_target_score = 100
	_overlay._apply_effect({"type": 7})
	assert_float(GameManager.event_target_multiplier).is_equal(1.15)
	assert_int(GameManager.stage_target_score).is_equal(115)


func test_lose_life_decrements() -> void:
	GameManager.lives = 3
	_overlay._apply_effect({"type": 8})
	assert_int(GameManager.lives).is_equal(2)


func test_lose_life_emits_run_ended_at_zero() -> void:
	GameManager.lives = 1
	monitor_signals(GameManager, false)
	_overlay._apply_effect({"type": 8})
	assert_int(GameManager.lives).is_equal(0)
	await assert_signal(GameManager).is_emitted("run_ended")


func test_lose_gold_removes_20() -> void:
	GameManager.gold = 50
	_overlay._apply_effect({"type": 9})
	assert_int(GameManager.gold).is_equal(30)


func test_lose_gold_clamps_to_zero() -> void:
	GameManager.gold = 5
	_overlay._apply_effect({"type": 9})
	assert_int(GameManager.gold).is_equal(0)


# ---------------------------------------------------------------------------
# Overlay data selection
# ---------------------------------------------------------------------------

func test_blessings_and_curses_arrays_non_empty() -> void:
	assert_bool(_overlay.BLESSINGS.size() > 0).is_true()
	assert_bool(_overlay.CURSES.size() > 0).is_true()


func test_each_blessing_has_required_keys() -> void:
	for b: Dictionary in _overlay.BLESSINGS:
		assert_bool(b.has("type")).is_true()
		assert_bool(b.has("name")).is_true()
		assert_bool(b.has("desc")).is_true()
		assert_bool(b.has("icon")).is_true()


func test_each_curse_has_required_keys() -> void:
	for c: Dictionary in _overlay.CURSES:
		assert_bool(c.has("type")).is_true()
		assert_bool(c.has("name")).is_true()
		assert_bool(c.has("desc")).is_true()
		assert_bool(c.has("icon")).is_true()
