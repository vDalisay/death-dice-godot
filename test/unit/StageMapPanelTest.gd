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
