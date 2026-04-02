class_name DiceCodexTest
extends GdUnitTestSuite
## Unit tests for the Dice Codex feature: discovery tracking in SaveManager
## and DiceData.get_all_known_dice() enumeration.


func before_test() -> void:
	SaveManager.discovered_dice.clear()


func test_get_all_known_dice_returns_all_types() -> void:
	var all: Array[DiceData] = DiceData.get_all_known_dice()
	assert_int(all.size()).is_equal(11)
	var names: Array[String] = []
	for die: DiceData in all:
		names.append(die.dice_name)
	assert_array(names).contains(["Standard D6", "Blank Canvas D6", "Simple D6",
		"Lucky D6", "Heavy D6", "Gambler D6", "Golden D6",
		"Insurance D6", "Explosive D6", "Pink D6", "Fortune D6"])


func test_discover_die_tracks_new_type() -> void:
	assert_bool(SaveManager.is_die_discovered("Standard D6")).is_false()
	SaveManager.discover_die("Standard D6")
	assert_bool(SaveManager.is_die_discovered("Standard D6")).is_true()
	assert_int(SaveManager.get_discovered_count()).is_equal(1)


func test_discover_die_idempotent() -> void:
	SaveManager.discover_die("Lucky D6")
	SaveManager.discover_die("Lucky D6")
	assert_int(SaveManager.get_discovered_count()).is_equal(1)


func test_record_run_discovers_dice() -> void:
	var RunSaveDataScript: GDScript = preload("res://Scripts/RunSaveData.gd")
	var run: RunSaveData = RunSaveDataScript.new()
	run.score = 100
	run.timestamp = "test"
	run.stages_cleared = 1
	run.loops_completed = 0
	run.busts = 0
	run.best_turn_score = 50
	run.final_dice_names = ["Standard D6", "Lucky D6", "Gambler D6"]
	SaveManager.record_run(run)
	assert_bool(SaveManager.is_die_discovered("Standard D6")).is_true()
	assert_bool(SaveManager.is_die_discovered("Lucky D6")).is_true()
	assert_bool(SaveManager.is_die_discovered("Gambler D6")).is_true()
	assert_int(SaveManager.get_discovered_count()).is_equal(3)


func test_undiscovered_die_returns_false() -> void:
	SaveManager.discover_die("Standard D6")
	assert_bool(SaveManager.is_die_discovered("Explosive D6")).is_false()


func test_all_known_dice_have_unique_names() -> void:
	var all: Array[DiceData] = DiceData.get_all_known_dice()
	var seen: Dictionary = {}
	for die: DiceData in all:
		assert_bool(seen.has(die.dice_name)).is_false()
		seen[die.dice_name] = true


func test_all_known_dice_have_rarity_assigned() -> void:
	var all: Array[DiceData] = DiceData.get_all_known_dice()
	for die: DiceData in all:
		# Just verify rarity resolves to a valid color (doesn't crash)
		var color: Color = die.get_rarity_color_value()
		assert_bool(color != Color.BLACK).is_true()
