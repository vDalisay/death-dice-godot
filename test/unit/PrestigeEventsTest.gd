extends GdUnitTestSuite
## Verifies prestige event pools expand only after the new_events unlock.

var _saved_unlocks: Array[String]
var _overlay: Node


func before_test() -> void:
	_saved_unlocks = SaveManager.prestige_unlocks.duplicate()
	_overlay = auto_free(preload("res://Scripts/StageEventOverlay.gd").new())


func after_test() -> void:
	SaveManager.prestige_unlocks = _saved_unlocks.duplicate()


func test_base_event_pools_do_not_include_prestige_events() -> void:
	SaveManager.prestige_unlocks = []
	var blessings: Array[Dictionary] = _overlay._build_blessing_pool()
	var curses: Array[Dictionary] = _overlay._build_curse_pool()
	assert_int(blessings.size()).is_equal(5)
	assert_int(curses.size()).is_equal(5)


func test_new_events_unlock_expands_both_event_pools() -> void:
	SaveManager.prestige_unlocks = ["new_events"]
	var blessings: Array[Dictionary] = _overlay._build_blessing_pool()
	var curses: Array[Dictionary] = _overlay._build_curse_pool()
	assert_int(blessings.size()).is_equal(7)
	assert_int(curses.size()).is_equal(7)
	assert_bool(_contains_event_name(blessings, "Thread the Needle")).is_true()
	assert_bool(_contains_event_name(curses, "Skull Tax")).is_true()


func _contains_event_name(events: Array[Dictionary], event_name: String) -> bool:
	for event: Dictionary in events:
		if event.get("name", "") as String == event_name:
			return true
	return false