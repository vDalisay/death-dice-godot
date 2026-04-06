extends GdUnitTestSuite
## Unit tests for StageMapPanel scene structure and open state.

const StageMapScene: PackedScene = preload("res://Scenes/StageMap.tscn")
const SpecialStageCatalog := preload("res://Scripts/SpecialStageCatalog.gd")
const RouteNodeVisualPolicyScript: GDScript = preload("res://Scripts/RouteNodeVisualPolicy.gd")

var _saved_route_restriction: int = 0
var _saved_map_row_reveal: bool = false


func before_test() -> void:
	_saved_route_restriction = int(GameManager.event_next_route_restriction)
	GameManager.event_next_route_restriction = GameManager.NextRouteRestriction.NONE
	_saved_map_row_reveal = GameManager.event_next_map_row_reveal
	GameManager.event_next_map_row_reveal = false


func after_test() -> void:
	GameManager.event_next_route_restriction = _saved_route_restriction as GameManager.NextRouteRestriction
	GameManager.event_next_map_row_reveal = _saved_map_row_reveal


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


func test_standard_only_route_restriction_blocks_nonstandard_nodes() -> void:
	GameManager.event_next_route_restriction = GameManager.NextRouteRestriction.STANDARD_ONLY
	var panel: PanelContainer = auto_free(StageMapScene.instantiate()) as PanelContainer
	add_child(panel)
	await await_idle_frame()
	var map: StageMapData = _build_route_restriction_map()
	panel.call("open", map, 0, -1)
	for _i: int in 4:
		await await_idle_frame()
	assert_bool(panel.call("_can_reach", 0, 0)).is_true()
	assert_bool(panel.call("_can_reach", 0, 1)).is_false()
	assert_bool(panel.call("_can_reach", 0, 2)).is_false()
	var hint_label: Label = panel.get_node("MarginContainer/RootVBox/FooterPanel/MarginContainer/FooterRow/HintLabel") as Label
	assert_str(hint_label.text).contains("standard route required")


func test_no_hard_route_restriction_allows_shop_but_blocks_special_stage() -> void:
	GameManager.event_next_route_restriction = GameManager.NextRouteRestriction.NO_HARD
	var panel: PanelContainer = auto_free(StageMapScene.instantiate()) as PanelContainer
	add_child(panel)
	await await_idle_frame()
	var map: StageMapData = _build_route_restriction_map()
	panel.call("open", map, 0, -1)
	for _i: int in 4:
		await await_idle_frame()
	assert_bool(panel.call("_can_reach", 0, 0)).is_true()
	assert_bool(panel.call("_can_reach", 0, 1)).is_true()
	assert_bool(panel.call("_can_reach", 0, 2)).is_false()


func test_route_restriction_is_waived_if_row_has_no_valid_targets() -> void:
	GameManager.event_next_route_restriction = GameManager.NextRouteRestriction.STANDARD_ONLY
	var panel: PanelContainer = auto_free(StageMapScene.instantiate()) as PanelContainer
	add_child(panel)
	await await_idle_frame()
	var map: StageMapData = _build_no_standard_route_map()
	panel.call("open", map, 0, -1)
	for _i: int in 4:
		await await_idle_frame()
	assert_bool(panel.call("_can_reach", 0, 0)).is_true()
	assert_bool(panel.call("_can_reach", 0, 1)).is_true()


func test_loaded_lantern_reveals_the_next_row_preview() -> void:
	GameManager.event_next_map_row_reveal = true
	var panel: PanelContainer = auto_free(StageMapScene.instantiate()) as PanelContainer
	add_child(panel)
	await await_idle_frame()
	var map: StageMapData = _build_lantern_preview_map()
	panel.call("open", map, 0, -1)
	for _i: int in 4:
		await await_idle_frame()
	assert_bool(panel.get("_next_row_reveal_active")).is_true()
	var board_label: Label = panel.get_node("MarginContainer/RootVBox/BodyRow/BoardFrame/MarginContainer/BoardVBox/BoardLabel") as Label
	var legend_label: Label = panel.get_node("MarginContainer/RootVBox/FooterPanel/MarginContainer/FooterRow/LegendLabel") as Label
	assert_str(board_label.text).contains("LANTERN")
	assert_str(legend_label.text).contains("row 2")
	assert_str(legend_label.text).contains("Shop")
	assert_str(legend_label.text).contains("Lucky Floor")
	var node_buttons: Array = panel.get("_node_buttons") as Array
	var future_row_buttons: Array = node_buttons[1] as Array
	var state_label: Label = (future_row_buttons[0] as Button).get_node("Medallion/StateLabel") as Label
	assert_str(state_label.text).is_equal("SEEN")
	assert_bool(GameManager.event_next_map_row_reveal).is_false()


func test_intro_reveal_blocks_hover_selection_until_reveal_finishes() -> void:
	GameManager.reset_run()
	var panel: PanelContainer = auto_free(StageMapScene.instantiate()) as PanelContainer
	add_child(panel)
	await await_idle_frame()
	var map: StageMapData = _build_intro_gate_map()
	panel.call("open", map, 0, -1)
	await await_idle_frame()
	var selected_title: Label = panel.get_node("MarginContainer/RootVBox/BodyRow/InspectorPanel/MarginContainer/InspectorVBox/SelectedNodeTitle") as Label
	var starting_title: String = selected_title.text
	var node_buttons: Array = panel.get("_node_buttons") as Array
	var current_row_buttons: Array = node_buttons[0] as Array
	(current_row_buttons[1] as Button).emit_signal("mouse_entered")
	await await_idle_frame()
	assert_str(selected_title.text).is_equal(starting_title)
	panel.call("_on_intro_reveal_finished")
	await await_idle_frame()
	(current_row_buttons[1] as Button).emit_signal("mouse_entered")
	await await_idle_frame()
	assert_str(selected_title.text).is_equal("Shop")


func test_hovered_node_shows_red_outline_and_pulse_overlay() -> void:
	GameManager.reset_run()
	var panel: PanelContainer = auto_free(StageMapScene.instantiate()) as PanelContainer
	add_child(panel)
	await await_idle_frame()
	var map: StageMapData = _build_intro_gate_map()
	panel.call("open", map, 0, -1)
	for _i: int in 8:
		await await_idle_frame()
	panel.visible = false
	panel.call("open", map, 0, -1)
	for _j: int in 6:
		await await_idle_frame()
	var node_buttons: Array = panel.get("_node_buttons") as Array
	var node_button: Button = ((node_buttons[0] as Array)[0] as Button)
	var hover_frame: PanelContainer = node_button.get_node("Medallion/HoverFrame") as PanelContainer
	node_button.emit_signal("mouse_entered")
	await await_idle_frame()
	assert_bool(hover_frame.visible).is_true()
	var hover_style: StyleBoxFlat = hover_frame.get_theme_stylebox("panel") as StyleBoxFlat
	assert_object(hover_style).is_not_null()
	assert_bool(hover_style.border_color == RouteNodeVisualPolicyScript.OUTLINE_COLOR).is_true()
	assert_int(hover_style.border_width_left).is_equal(RouteNodeVisualPolicyScript.OUTLINE_WIDTH)
	for _k: int in 12:
		await await_idle_frame()
	assert_float(hover_frame.scale.x).is_greater(1.0)
	node_button.emit_signal("mouse_exited")
	await await_idle_frame()
	assert_bool(hover_frame.visible).is_false()
	assert_float(hover_frame.scale.x).is_equal(1.0)
	node_button.emit_signal("focus_entered")
	await await_idle_frame()
	assert_bool(hover_frame.visible).is_true()


func test_header_seal_uses_selected_stage_rule_name() -> void:
	GameManager.reset_run()
	var panel: PanelContainer = auto_free(StageMapScene.instantiate()) as PanelContainer
	add_child(panel)
	await await_idle_frame()
	var map: StageMapData = _build_single_special_header_map()
	panel.call("open", map, 0, -1)
	await await_idle_frame()
	var header_seal: Label = panel.get_node("MarginContainer/RootVBox/HeaderPanel/MarginContainer/HeaderRow/HeaderSeal") as Label
	assert_str(header_seal.text).is_equal("RULE: LUCKY FLOOR")


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


func _build_route_restriction_map() -> StageMapData:
	var map := StageMapData.new()
	var standard_node: MapNodeData = _make_node([0], false, 0)
	var shop_node: MapNodeData = _make_shop_node([0], 1)
	var hard_node: MapNodeData = _make_node([0], false, 2, SpecialStageCatalog.Variant.HOT_TABLE)
	map.rows = [
		[standard_node, shop_node, hard_node],
		[_make_node([], false, 0)],
	]
	return map


func _build_no_standard_route_map() -> StageMapData:
	var map := StageMapData.new()
	map.rows = [
		[_make_shop_node([0], 0), _make_special_node([0], "lucky_floor", 1)],
		[_make_node([], false, 0)],
	]
	return map


func _build_lantern_preview_map() -> StageMapData:
	var map := StageMapData.new()
	map.rows = [
		[_make_node([0, 1], false, 0), _make_node([0, 1], false, 1)],
		[_make_shop_node([0], 0), _make_node([0], false, 1, SpecialStageCatalog.Variant.LUCKY_FLOOR)],
		[_make_node([], false, 0)],
	]
	return map


func _build_intro_gate_map() -> StageMapData:
	var map := StageMapData.new()
	map.rows = [
		[_make_node([0], false, 0), _make_shop_node([0], 1)],
		[_make_node([], false, 0)],
	]
	return map


func _build_single_special_header_map() -> StageMapData:
	var map := StageMapData.new()
	map.rows = [
		[_make_special_node([0], "lucky_floor", 0)],
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


func _make_shop_node(connections: Array[int], column: int = 0) -> MapNodeData:
	var node := MapNodeData.new()
	node.type = MapNodeData.NodeType.SHOP
	node.connections = connections.duplicate()
	node.column = column
	return node
