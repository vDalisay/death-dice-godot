extends GdUnitTestSuite
## Timing tests for bank score animation pacing.

const MainScene: PackedScene = preload("res://Scenes/Main.tscn")


func test_score_tick_base_interval_speeds_up_for_larger_dice_pools() -> void:
	GameManager.skip_archetype_picker = true
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION
	GameManager.reset_run()
	var root: RollPhase = auto_free(MainScene.instantiate()) as RollPhase
	add_child(root)
	await await_idle_frame()
	var small_pool_interval: float = root._score_tick_base_interval(4, 4)
	var large_pool_interval: float = root._score_tick_base_interval(4, 10)
	assert_float(large_pool_interval).is_less(small_pool_interval)
	assert_float(large_pool_interval).is_greater_equal(RollPhase.SCORE_ANIM_BASE_INTERVAL_FLOOR)