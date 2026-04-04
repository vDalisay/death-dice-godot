extends GdUnitTestSuite
## Unit tests for StageMapPanel scene structure and open state.

const StageMapScene: PackedScene = preload("res://Scenes/StageMap.tscn")


func test_stage_map_scene_has_required_nodes() -> void:
	var panel: PanelContainer = auto_free(StageMapScene.instantiate()) as PanelContainer
	add_child(panel)
	await await_idle_frame()
	assert_object(panel.get_node("Backdrop")).is_not_null()
	assert_object(panel.get_node("MarginContainer/VBoxContainer/TitleLabel")).is_not_null()
	assert_object(panel.get_node("MarginContainer/VBoxContainer/MapArea")).is_not_null()
	assert_object(panel.get_node("MarginContainer/VBoxContainer/HintLabel")).is_not_null()


func test_open_updates_hint_text() -> void:
	var panel: PanelContainer = auto_free(StageMapScene.instantiate()) as PanelContainer
	add_child(panel)
	await await_idle_frame()
	var map: Resource = StageMapGenerator.generate(1)
	panel.call("open", map, 0, -1)
	await await_idle_frame()
	var hint_label: Label = panel.get_node("MarginContainer/VBoxContainer/HintLabel") as Label
	assert_str(hint_label.text).contains("Stage 1 / 7")


func test_open_consumes_loop_reveal_only_once_per_loop() -> void:
	GameManager.reset_run()
	var panel: PanelContainer = auto_free(StageMapScene.instantiate()) as PanelContainer
	add_child(panel)
	await await_idle_frame()
	var map: Resource = StageMapGenerator.generate(1)
	panel.call("open", map, 0, -1)
	await await_idle_frame()
	assert_bool(panel.get("_last_open_used_loop_reveal")).is_true()
	panel.visible = false
	panel.call("open", map, 0, -1)
	await await_idle_frame()
	assert_bool(panel.get("_last_open_used_loop_reveal")).is_false()


func test_open_reveals_again_when_a_new_loop_is_reached() -> void:
	GameManager.reset_run()
	var panel: PanelContainer = auto_free(StageMapScene.instantiate()) as PanelContainer
	add_child(panel)
	await await_idle_frame()
	var map_loop_one: Resource = StageMapGenerator.generate(1)
	panel.call("open", map_loop_one, 0, -1)
	await await_idle_frame()
	assert_bool(panel.get("_last_open_used_loop_reveal")).is_true()
	GameManager.advance_loop()
	var map_loop_two: Resource = GameManager.stage_map
	panel.visible = false
	panel.call("open", map_loop_two, 0, -1)
	await await_idle_frame()
	assert_bool(panel.get("_last_open_used_loop_reveal")).is_true()
