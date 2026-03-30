extends GdUnitTestSuite
## Unit tests for the redesigned HighlightsPanel.

const HighlightsPanelScene: PackedScene = preload("res://Scenes/HighlightsPanel.tscn")


func _make_run(score: int, stages: int, loops: int, best_turn: int, busts: int, dice_count: int) -> RunSaveData:
	var run := RunSaveData.new()
	run.score = score
	run.stages_cleared = stages
	run.loops_completed = loops
	run.best_turn_score = best_turn
	run.busts = busts
	for i: int in dice_count:
		run.final_dice_names.append("Standard")
	return run


func test_show_highlights_makes_visible_with_stat_cards() -> void:
	var panel: HighlightsPanel = auto_free(HighlightsPanelScene.instantiate()) as HighlightsPanel
	add_child(panel)
	await await_idle_frame()
	var run: RunSaveData = _make_run(500, 5, 2, 120, 3, 8)
	var bests: Dictionary = {"highscore": 200, "best_stages": 3, "best_loop": 1, "best_turn": 80}
	panel.show_highlights(run, bests)
	assert_bool(panel.visible).is_true()
	# Should have 6 stat cards: Score, Stages, Loops, Best Turn, Busts, Final Dice.
	var stat_container: HFlowContainer = panel.find_child("StatCards", true, false) as HFlowContainer
	# Cards are added via code, wait a frame for them to materialize.
	await await_idle_frame()
	assert_int(stat_container.get_child_count()).is_equal(6)


func test_new_best_badge_exists_when_beating_record() -> void:
	var panel: HighlightsPanel = auto_free(HighlightsPanelScene.instantiate()) as HighlightsPanel
	add_child(panel)
	await await_idle_frame()
	var run: RunSaveData = _make_run(999, 10, 5, 200, 1, 10)
	var bests: Dictionary = {"highscore": 100, "best_stages": 3, "best_loop": 1, "best_turn": 50}
	panel.show_highlights(run, bests)
	await await_idle_frame()
	# First card (Score) should have a BestBadge since 999 > 100.
	var stat_container: HFlowContainer = panel.find_child("StatCards", true, false) as HFlowContainer
	var first_card: PanelContainer = stat_container.get_child(0) as PanelContainer
	var badge: Label = first_card.find_child("BestBadge", true, false) as Label
	assert_object(badge).is_not_null()
	assert_str(badge.text).contains("NEW BEST")


func test_close_button_hides_and_emits() -> void:
	var panel: HighlightsPanel = auto_free(HighlightsPanelScene.instantiate()) as HighlightsPanel
	add_child(panel)
	await await_idle_frame()
	var run: RunSaveData = _make_run(100, 1, 0, 50, 0, 5)
	panel.show_highlights(run, {})
	assert_bool(panel.visible).is_true()
	var close_btn: Button = panel.find_child("CloseButton", true, false) as Button
	close_btn.emit_signal("pressed")
	assert_bool(panel.visible).is_false()


func test_card_has_themed_styling() -> void:
	var panel: HighlightsPanel = auto_free(HighlightsPanelScene.instantiate()) as HighlightsPanel
	add_child(panel)
	await await_idle_frame()
	var card: PanelContainer = panel.find_child("Card", true, false) as PanelContainer
	var sb: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
	assert_object(sb).is_not_null()
	assert_int(sb.corner_radius_top_left).is_greater(0)
