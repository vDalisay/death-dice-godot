extends GdUnitTestSuite
## Unit tests for StageMapPanel scene structure and open state.

const StageMapScene: PackedScene = preload("res://Scenes/StageMap.tscn")
const SpecialStageCatalog := preload("res://Scripts/SpecialStageCatalog.gd")


func test_stage_map_scene_has_required_nodes() -> void:
	var panel: PanelContainer = auto_free(StageMapScene.instantiate()) as PanelContainer
	add_child(panel)
	await await_idle_frame()
	assert_object(panel.get_node("AtmosphereLayer/Backdrop")).is_not_null()
	assert_object(panel.get_node("MarginContainer/RootVBox/HeaderPanel")).is_not_null()
	assert_object(panel.get_node("MarginContainer/RootVBox/BodyRow/BoardFrame/MarginContainer/BoardVBox/MapArea")).is_not_null()
	assert_object(panel.get_node("MarginContainer/RootVBox/BodyRow/InspectorPanel/MarginContainer/InspectorVBox/SelectedNodeTitle")).is_not_null()
	assert_object(panel.get_node("MarginContainer/RootVBox/FooterPanel/MarginContainer/FooterRow/HintLabel")).is_not_null()


func test_open_updates_hint_text() -> void:
	var panel: PanelContainer = auto_free(StageMapScene.instantiate()) as PanelContainer
	add_child(panel)
	await await_idle_frame()
	var map: Resource = StageMapGenerator.generate(1)
	panel.call("open", map, 0, -1)
	for _i: int in 16:
		await await_idle_frame()
	var hint_label: Label = panel.get_node("MarginContainer/RootVBox/FooterPanel/MarginContainer/FooterRow/HintLabel") as Label
	var selected_title: Label = panel.get_node("MarginContainer/RootVBox/BodyRow/InspectorPanel/MarginContainer/InspectorVBox/SelectedNodeTitle") as Label
	var selected_type: Label = panel.get_node("MarginContainer/RootVBox/BodyRow/InspectorPanel/MarginContainer/InspectorVBox/SelectedNodeType") as Label
	assert_str(hint_label.text).contains("Stage 1 / 7")
	assert_str(selected_title.text).is_not_empty()
	assert_str(selected_type.text).contains("Available Now")
	var content: VBoxContainer = panel.get_node("MarginContainer/RootVBox") as VBoxContainer
	var map_area: Control = panel.get_node("MarginContainer/RootVBox/BodyRow/BoardFrame/MarginContainer/BoardVBox/MapArea") as Control
	assert_float(panel.modulate.a).is_equal(1.0)
	assert_float(content.modulate.a).is_greater(0.0)
	assert_int(map_area.get_child_count()).is_greater(0)


func test_hovering_node_updates_inspector_and_special_rule_preview() -> void:
	var panel: PanelContainer = auto_free(StageMapScene.instantiate()) as PanelContainer
	add_child(panel)
	await await_idle_frame()
	var map: StageMapData = _build_special_preview_map()
	panel.call("open", map, 1, 0)
	for _i: int in 8:
		await await_idle_frame()
	var node_buttons: Array = panel.get("_node_buttons") as Array
	var current_row_buttons: Array = node_buttons[1] as Array
	(current_row_buttons[1] as Button).emit_signal("mouse_entered")
	await await_idle_frame()
	var selected_title: Label = panel.get_node("MarginContainer/RootVBox/BodyRow/InspectorPanel/MarginContainer/InspectorVBox/SelectedNodeTitle") as Label
	var selected_summary: Label = panel.get_node("MarginContainer/RootVBox/BodyRow/InspectorPanel/MarginContainer/InspectorVBox/SelectedNodeSummary") as Label
	var selected_rule: Label = panel.get_node("MarginContainer/RootVBox/BodyRow/InspectorPanel/MarginContainer/InspectorVBox/SelectedNodeRule") as Label
	assert_str(selected_title.text).is_equal("Lucky Floor")
	assert_str(selected_summary.text).contains("rules modifier")
	assert_bool(selected_rule.visible).is_true()
	assert_str(selected_rule.text).contains("First reroll each turn grants +2 LUCK")


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


func test_open_skips_to_next_unvisited_row_when_requested_row_is_stale() -> void:
	var panel: PanelContainer = auto_free(StageMapScene.instantiate()) as PanelContainer
	add_child(panel)
	await await_idle_frame()
	var map: StageMapData = _build_stale_progression_map()
	panel.call("open", map, 4, 1)
	await await_idle_frame()
	assert_int(panel.get("_current_row")).is_equal(5)
	assert_int(panel.get("_current_col")).is_equal(1)
	assert_bool(panel.call("_can_reach", 5, 0)).is_true()
	assert_bool(panel.call("_can_reach", 5, 1)).is_false()
	assert_bool(panel.call("_can_reach", 5, 2)).is_true()


func test_future_row_connections_stay_dim_until_that_row_is_current() -> void:
	var panel: PanelContainer = auto_free(StageMapScene.instantiate()) as PanelContainer
	add_child(panel)
	await await_idle_frame()
	var map: StageMapData = _build_active_path_map()
	panel.call("open", map, 1, 0)
	await await_idle_frame()
	var lines: Array = panel.get("_connection_lines") as Array
	var node_buttons: Array = panel.get("_node_buttons") as Array
	var row_zero_buttons: Array = node_buttons[0] as Array
	var row_one_buttons: Array = node_buttons[1] as Array
	var active_into_current: int = _count_lines_from_row_with_color(lines, row_zero_buttons, StageMapPanel.LINE_COLOR_ACTIVE)
	var active_from_current: int = _count_lines_from_row_with_color(lines, row_one_buttons, StageMapPanel.LINE_COLOR_ACTIVE)
	assert_int(active_into_current).is_greater(0)
	assert_int(active_from_current).is_equal(0)


func test_special_stage_nodes_show_variant_label_and_hover_copy() -> void:
	var panel: PanelContainer = auto_free(StageMapScene.instantiate()) as PanelContainer
	add_child(panel)
	await await_idle_frame()
	var map: StageMapData = _build_special_variant_map()
	panel.call("open", map, 0, -1)
	for _i: int in 4:
		await await_idle_frame()
	var node_buttons: Array = panel.get("_node_buttons") as Array
	var special_button: Button = ((node_buttons[0] as Array)[0] as Button)
	assert_str(special_button.tooltip_text).contains("Clean Room")
	assert_str(special_button.tooltip_text).contains("target")
	var selected_title: Label = panel.get_node("MarginContainer/RootVBox/BodyRow/InspectorPanel/MarginContainer/InspectorVBox/SelectedNodeTitle") as Label
	var hint_label: Label = panel.get_node("MarginContainer/RootVBox/FooterPanel/MarginContainer/FooterRow/HintLabel") as Label
	special_button.emit_signal("mouse_entered")
	await await_idle_frame()
	assert_str(selected_title.text).is_equal("Clean Room")
	assert_str(hint_label.text).contains("reachable now")
	assert_str(hint_label.text).contains("Clean Room")
	special_button.emit_signal("mouse_exited")
	await await_idle_frame()
	assert_str(hint_label.text).contains("Stage 1 / 7")


func _build_stale_progression_map() -> StageMapData:
	var map := StageMapData.new()
	map.rows = [
		[_make_node([0, 1]), _make_node([1])],
		[_make_node([0]), _make_node([0, 1])],
		[_make_node([0, 1]), _make_node([1])],
		[_make_node([0]), _make_node([0, 1])],
		[_make_node([0], false, 0), _make_node([0, 2], true, 1), _make_node([2], false, 2)],
		[_make_node([0], false, 0), _make_node([0], false, 1), _make_node([0], false, 2)],
		[_make_node([], false, 0)],
	]
	return map


func _build_active_path_map() -> StageMapData:
	var map := StageMapData.new()
	map.rows = [
		[_make_node([0, 1], true, 0)],
		[_make_node([0], false, 0), _make_node([0], false, 1)],
		[_make_node([], false, 0)],
	]
	return map


func _build_special_variant_map() -> StageMapData:
	var map := StageMapData.new()
	map.rows = [
		[_make_node([0], false, 0, SpecialStageCatalog.Variant.CLEAN_ROOM), _make_node([0], false, 1)],
		[_make_node([0], false, 0)],
		[_make_node([], false, 0)],
	]
	return map


func _build_special_preview_map() -> StageMapData:
	var map := StageMapData.new()
	map.rows = [
		[_make_node([0, 1], true, 0)],
		[_make_node([0], false, 0), _make_special_node([0], "lucky_floor", 1)],
		[_make_node([], false, 0)],
	]
	return map


func _count_lines_from_row_with_color(lines: Array, row_buttons: Array, color: Color) -> int:
	var count: int = 0
	var row_start_y: float = ((row_buttons[0] as Button).position.y) + (((row_buttons[0] as Button).size.y) * 0.5)
	for line_variant: Variant in lines:
		var line: Line2D = line_variant as Line2D
		if line == null:
			continue
		if absf(line.get_point_position(0).y - row_start_y) > 0.5:
			continue
		if line.default_color == color:
			count += 1
	return count


func _make_node(connections: Array[int], visited: bool = false, column: int = 0, stage_variant: int = SpecialStageCatalog.Variant.NONE) -> MapNodeData:
	var node := MapNodeData.new()
	node.type = MapNodeData.NodeType.NORMAL_STAGE
	node.connections = connections.duplicate()
	node.visited = visited
	node.column = column
	node.stage_variant = stage_variant
	return node


func _make_special_node(connections: Array[int], special_rule_id: String, column: int = 0) -> MapNodeData:
	var node := MapNodeData.new()
	node.type = MapNodeData.NodeType.SPECIAL_STAGE
	node.connections = connections.duplicate()
	node.special_rule_id = special_rule_id
	node.column = column
	return node
