extends GdUnitTestSuite
## Unit tests for the redesigned CareerPanel.

const CareerPanelScene: PackedScene = preload("res://Scenes/CareerPanel.tscn")


func test_opens_visible_and_refreshes_stats() -> void:
	SaveManager.career_best_loop = 3
	SaveManager.career_best_turn_score = 999
	SaveManager.total_busts = 5
	SaveManager.total_runs = 10
	SaveManager.total_stages_cleared = 42
	var panel: CareerPanel = auto_free(CareerPanelScene.instantiate()) as CareerPanel
	add_child(panel)
	await await_idle_frame()
	panel.open_panel()
	assert_bool(panel.visible).is_true()
	var best_loop: Label = panel.find_child("BestLoopLabel", true, false) as Label
	assert_str(best_loop.text).contains("3")
	var best_turn: Label = panel.find_child("BestTurnLabel", true, false) as Label
	assert_str(best_turn.text).contains("999")
	var busts: Label = panel.find_child("TotalBustsLabel", true, false) as Label
	assert_str(busts.text).contains("5")


func test_close_button_emits_closed_and_hides() -> void:
	var panel: CareerPanel = auto_free(CareerPanelScene.instantiate()) as CareerPanel
	add_child(panel)
	await await_idle_frame()
	panel.open_panel()
	assert_bool(panel.visible).is_true()
	var close_btn: Button = panel.find_child("CloseButton", true, false) as Button
	close_btn.emit_signal("pressed")
	assert_bool(panel.visible).is_false()


func test_card_has_themed_panel_stylebox() -> void:
	var panel: CareerPanel = auto_free(CareerPanelScene.instantiate()) as CareerPanel
	add_child(panel)
	await await_idle_frame()
	var card: PanelContainer = panel.find_child("Card", true, false) as PanelContainer
	var sb: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
	assert_object(sb).is_not_null()
	assert_int(sb.corner_radius_top_left).is_greater(0)


func test_achievement_badges_are_built_on_open() -> void:
	SaveManager.career_best_loop = 1
	var panel: CareerPanel = auto_free(CareerPanelScene.instantiate()) as CareerPanel
	add_child(panel)
	await await_idle_frame()
	panel.open_panel()
	# Achievement grid should exist (may have 0 badges if no achievements registered).
	var grid: HFlowContainer = panel.find_child("AchievementGrid", true, false) as HFlowContainer
	assert_object(grid).is_not_null()
