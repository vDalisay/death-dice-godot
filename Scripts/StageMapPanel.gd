class_name StageMapPanel
extends PanelContainer
## Full-screen branching stage map. Player picks a node in the current row.
## Call open() and listen for node_selected.

signal node_selected(row: int, col: int, node: MapNodeData, used_reroute: bool)

const FlowTransitionScript: GDScript = preload("res://Scripts/FlowTransition.gd")
const _UITheme := preload("res://Scripts/UITheme.gd")

const NODE_SIZE: float = 92.0
const MIN_H_SPACING: float = 116.0
const LINE_WIDTH: float = 3.0
const LINE_WIDTH_ACTIVE: float = 4.5
const LINE_COLOR: Color = Color("#3A3129", 0.55)
const LINE_COLOR_VISITED: Color = Color("#7F6C57", 0.42)
const LINE_COLOR_ACTIVE: Color = Color("#89C6C7", 0.80)
const LINE_COLOR_SELECTED: Color = Color("#D7A769", 0.92)
const LINE_COLOR_FUTURE: Color = Color("#201D22", 0.58)
const VISITED_ALPHA: float = 0.42
const FUTURE_ALPHA: float = 0.34
const UNREACHABLE_ALPHA: float = 0.60
const CURRENT_ROW_GLOW: Color = Color("#89C6C7")
const SELECTED_GLOW: Color = Color("#E1D0A2")
const REROUTE_GLOW: Color = Color("#D7A769")
const ICON_FONT_SIZE: int = 11
const STATE_FONT_SIZE: int = 10
const PANEL_INTRO_DURATION: float = 0.22
const NODE_REVEAL_STAGGER: float = 0.04
const NODE_REVEAL_DURATION: float = 0.16

@onready var _backdrop: ColorRect = $AtmosphereLayer/Backdrop
@onready var _content: VBoxContainer = $MarginContainer/RootVBox
@onready var _header_panel: PanelContainer = $MarginContainer/RootVBox/HeaderPanel
@onready var _title_label: Label = $MarginContainer/RootVBox/HeaderPanel/MarginContainer/HeaderRow/TitleStack/TitleLabel
@onready var _context_label: Label = $MarginContainer/RootVBox/HeaderPanel/MarginContainer/HeaderRow/TitleStack/ContextLabel
@onready var _header_seal: Label = $MarginContainer/RootVBox/HeaderPanel/MarginContainer/HeaderRow/HeaderSeal
@onready var _board_frame: PanelContainer = $MarginContainer/RootVBox/BodyRow/BoardFrame
@onready var _map_area: Control = $MarginContainer/RootVBox/BodyRow/BoardFrame/MarginContainer/BoardVBox/MapArea
@onready var _inspector_panel: PanelContainer = $MarginContainer/RootVBox/BodyRow/InspectorPanel
@onready var _inspector_eyebrow: Label = $MarginContainer/RootVBox/BodyRow/InspectorPanel/MarginContainer/InspectorVBox/InspectorEyebrow
@onready var _selected_node_title: Label = $MarginContainer/RootVBox/BodyRow/InspectorPanel/MarginContainer/InspectorVBox/SelectedNodeTitle
@onready var _selected_node_type: Label = $MarginContainer/RootVBox/BodyRow/InspectorPanel/MarginContainer/InspectorVBox/SelectedNodeType
@onready var _selected_node_flavor: Label = $MarginContainer/RootVBox/BodyRow/InspectorPanel/MarginContainer/InspectorVBox/SelectedNodeFlavor
@onready var _selected_node_summary: Label = $MarginContainer/RootVBox/BodyRow/InspectorPanel/MarginContainer/InspectorVBox/SelectedNodeSummary
@onready var _selected_node_rule: Label = $MarginContainer/RootVBox/BodyRow/InspectorPanel/MarginContainer/InspectorVBox/SelectedNodeRule
@onready var _reroute_button: Button = $MarginContainer/RootVBox/BodyRow/InspectorPanel/MarginContainer/InspectorVBox/RerouteButton
@onready var _footer_panel: PanelContainer = $MarginContainer/RootVBox/FooterPanel
@onready var _hint_label: Label = $MarginContainer/RootVBox/FooterPanel/MarginContainer/FooterRow/HintLabel
@onready var _legend_label: Label = $MarginContainer/RootVBox/FooterPanel/MarginContainer/FooterRow/LegendLabel
@onready var _board_label: Label = $MarginContainer/RootVBox/BodyRow/BoardFrame/MarginContainer/BoardVBox/BoardLabel

var _stage_map: Resource = null
var _current_row: int = 0
var _current_col: int = -1
var _selected_row: int = -1
var _selected_col: int = -1
var _selected_node: MapNodeData = null
var _node_buttons: Array = []
var _connection_lines: Array[Line2D] = []
var _pending_open: bool = false
var _reroute_uses: int = 0
var _reroute_enabled: bool = false
var _transition_tween: Tween = null
var _last_open_used_loop_reveal: bool = false
var _is_closing: bool = false


func _ready() -> void:
    visible = false
    _apply_theme_styling()
    if not _reroute_button.pressed.is_connected(_on_reroute_button_pressed):
        _reroute_button.pressed.connect(_on_reroute_button_pressed)
    _map_area.resized.connect(_on_map_area_resized)


func open(stage_map: Resource, current_row: int, previous_col: int, reroute_uses: int = 0) -> void:
    _stage_map = stage_map
    _current_row = _resolve_open_row(current_row)
    _current_col = _resolve_previous_col(previous_col, _current_row)
    _selected_row = -1
    _selected_col = -1
    _selected_node = null
    _reroute_uses = reroute_uses if _current_row > 0 else 0
    _reroute_enabled = false
    _title_label.text = "ROUTE BOARD"
    modulate.a = 1.0
    _backdrop.modulate.a = 0.0
    visible = true
    _is_closing = false
    _last_open_used_loop_reveal = GameManager.consume_loop_reveal(GameManager.current_loop)
    _refresh_context_label()
    _refresh_hint_label()
    _refresh_reroute_button()
    _refresh_selected_node_panel()
    _pending_open = true
    await get_tree().process_frame
    _pending_open = false
    _rebuild_map()
    _play_intro()


func _resolve_open_row(requested_row: int) -> int:
    if _stage_map == null:
        return maxi(requested_row, 0)
    var row_count: int = _stage_map.get_row_count()
    if row_count <= 0:
        return 0
    var resolved_row: int = clampi(requested_row, 0, row_count - 1)
    while resolved_row < row_count - 1 and _row_has_visited_node(resolved_row):
        resolved_row += 1
    return resolved_row


func _resolve_previous_col(requested_col: int, resolved_row: int) -> int:
    if _stage_map == null or resolved_row <= 0:
        return -1
    var prior_row: Array[MapNodeData] = _stage_map.get_row(resolved_row - 1)
    if requested_col >= 0 and requested_col < prior_row.size():
        var requested_node: MapNodeData = prior_row[requested_col] as MapNodeData
        if requested_node != null and requested_node.visited:
            return requested_col
    for idx: int in prior_row.size():
        var prior_node: MapNodeData = prior_row[idx] as MapNodeData
        if prior_node != null and prior_node.visited:
            return idx
    if requested_col >= 0 and requested_col < prior_row.size():
        return requested_col
    return -1


func _row_has_visited_node(row_index: int) -> bool:
    if _stage_map == null:
        return false
    var row_nodes: Array[MapNodeData] = _stage_map.get_row(row_index)
    for node: MapNodeData in row_nodes:
        if node != null and node.visited:
            return true
    return false


func _on_map_area_resized() -> void:
    if visible and _stage_map != null and not _pending_open:
        _rebuild_map()


func try_consume_reroute_for(row: int, col: int) -> bool:
    if not _reroute_enabled:
        return false
    if _is_reachable_without_reroute(row, col):
        _reroute_enabled = false
        _refresh_hint_label()
        _refresh_reroute_button()
        _refresh_visual_state()
        return false
    if _reroute_uses <= 0:
        return false
    _reroute_uses -= 1
    _reroute_enabled = false
    _refresh_hint_label()
    _refresh_reroute_button()
    _refresh_visual_state()
    return true


func _rebuild_map() -> void:
    _clear_map()
    if _stage_map == null:
        return
    var area_w: float = _map_area.size.x
    var area_h: float = _map_area.size.y
    if area_w < 1.0 or area_h < 1.0:
        return
    var row_count: int = _stage_map.get_row_count()
    var v_padding: float = 34.0
    var usable_h: float = area_h - v_padding * 2.0
    var row_step_y: float = usable_h / float(maxi(row_count - 1, 1))
    for r: int in row_count:
        var row_data: Array = _stage_map.get_row(r)
        var row_btns: Array[Button] = []
        var node_count: int = row_data.size()
        var h_spacing: float = _resolve_row_spacing(area_w, node_count)
        var total_w: float = NODE_SIZE + float(maxi(node_count - 1, 0)) * h_spacing
        var start_x: float = (area_w - total_w) * 0.5
        var y: float = v_padding + float(r) * row_step_y - NODE_SIZE * 0.5
        for c: int in node_count:
            var node: MapNodeData = row_data[c] as MapNodeData
            var x: float = start_x + float(c) * h_spacing
            var btn: Button = _make_node_button(node, r, c)
            btn.position = Vector2(x, y)
            _map_area.add_child(btn)
            row_btns.append(btn)
        _node_buttons.append(row_btns)
    _ensure_selected_node()
    _refresh_visual_state()
    if _last_open_used_loop_reveal:
        _prepare_nodes_for_intro()
    else:
        _show_nodes_immediately()


func _resolve_row_spacing(area_width: float, node_count: int) -> float:
    if node_count <= 1:
        return 0.0
    var max_spacing: float = maxf((area_width - NODE_SIZE) / float(node_count - 1), NODE_SIZE)
    return clampf(area_width * 0.25, MIN_H_SPACING, max_spacing)


func _clear_map() -> void:
    for line: Line2D in _connection_lines:
        if is_instance_valid(line):
            line.queue_free()
    _connection_lines.clear()
    for row_btns_variant: Variant in _node_buttons:
        for btn_variant: Variant in row_btns_variant as Array:
            if is_instance_valid(btn_variant as Node):
                (btn_variant as Node).queue_free()
    _node_buttons.clear()


func _redraw_connections() -> void:
    for line: Line2D in _connection_lines:
        if is_instance_valid(line):
            line.queue_free()
    _connection_lines.clear()
    _draw_connections()


func _draw_connections() -> void:
    if _stage_map == null:
        return
    var row_count: int = _stage_map.get_row_count()
    for r: int in row_count - 1:
        var cur_btns: Array = _node_buttons[r]
        var nxt_btns: Array = _node_buttons[r + 1]
        var row_data: Array = _stage_map.get_row(r)
        for c: int in row_data.size():
            var node: MapNodeData = row_data[c] as MapNodeData
            var from_btn: Button = cur_btns[c] as Button
            var from_pt: Vector2 = from_btn.position + from_btn.size * 0.5
            for conn: int in node.connections:
                if conn < 0 or conn >= nxt_btns.size():
                    continue
                var to_btn: Button = nxt_btns[conn] as Button
                var to_pt: Vector2 = to_btn.position + to_btn.size * 0.5
                var line: Line2D = Line2D.new()
                line.antialiased = true
                line.joint_mode = Line2D.LINE_JOINT_ROUND
                line.begin_cap_mode = Line2D.LINE_CAP_ROUND
                line.end_cap_mode = Line2D.LINE_CAP_ROUND
                var midpoint_y: float = lerpf(from_pt.y, to_pt.y, 0.5)
                var swing: float = clampf((to_pt.x - from_pt.x) * 0.18, -24.0, 24.0)
                line.add_point(from_pt)
                line.add_point(Vector2(from_pt.x + swing, midpoint_y - 10.0))
                line.add_point(Vector2(to_pt.x - swing, midpoint_y + 10.0))
                line.add_point(to_pt)
                _apply_connection_visual(line, r, c, conn, node)
                _map_area.add_child(line)
                _map_area.move_child(line, 0)
                _connection_lines.append(line)


func _apply_connection_visual(line: Line2D, row: int, col: int, next_col: int, node: MapNodeData) -> void:
    var target_row: int = row + 1
    var target_node: MapNodeData = _stage_map.get_node_at(target_row, next_col)
    if node.visited and target_node != null and target_node.visited:
        line.default_color = LINE_COLOR_VISITED
        line.width = LINE_WIDTH
        return
    if row == _current_row - 1 and node.visited and _is_reachable_without_reroute(target_row, next_col):
        line.default_color = LINE_COLOR_SELECTED if _selected_row == target_row and _selected_col == next_col else LINE_COLOR_ACTIVE
        line.width = LINE_WIDTH_ACTIVE
        return
    if row == _current_row and _selected_row == row and _selected_col == col:
        line.default_color = LINE_COLOR_SELECTED
        line.width = LINE_WIDTH_ACTIVE
        return
    if row >= _current_row or target_row > _current_row:
        line.default_color = LINE_COLOR_FUTURE
        line.width = LINE_WIDTH
        return
    line.default_color = LINE_COLOR
    line.width = LINE_WIDTH


func _make_node_button(node: MapNodeData, row: int, col: int) -> Button:
    var btn: Button = Button.new()
    btn.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
    btn.size = Vector2(NODE_SIZE, NODE_SIZE)
    btn.flat = true
    btn.text = ""
    btn.focus_mode = Control.FOCUS_NONE
    btn.mouse_filter = Control.MOUSE_FILTER_STOP
    btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    btn.tooltip_text = node.get_hover_text()
    btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
    btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
    btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
    btn.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
    btn.pressed.connect(_on_node_pressed.bind(row, col))
    btn.mouse_entered.connect(func() -> void: _show_node_hint(row, col, node))
    btn.focus_entered.connect(_on_node_hovered.bind(row, col))
    btn.mouse_exited.connect(_refresh_hint_label)
    var medallion: PanelContainer = PanelContainer.new()
    medallion.name = "Medallion"
    medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
    medallion.custom_minimum_size = _get_medallion_size(node.type)
    medallion.size = medallion.custom_minimum_size
    medallion.position = (btn.size - medallion.size) * 0.5
    btn.add_child(medallion)
    var accent_bar: ColorRect = ColorRect.new()
    accent_bar.name = "AccentBar"
    accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    accent_bar.color = node.get_color()
    accent_bar.position = Vector2(8.0, 8.0)
    accent_bar.custom_minimum_size = Vector2(medallion.size.x - 16.0, 4.0)
    accent_bar.size = accent_bar.custom_minimum_size
    medallion.add_child(accent_bar)
    var stamp_label: Label = Label.new()
    stamp_label.name = "StampLabel"
    stamp_label.text = node.get_map_stamp()
    stamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stamp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    stamp_label.position = Vector2(8.0, 20.0)
    stamp_label.size = Vector2(medallion.size.x - 16.0, medallion.size.y - 42.0)
    medallion.add_child(stamp_label)
    var state_label: Label = Label.new()
    state_label.name = "StateLabel"
    state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    state_label.position = Vector2(8.0, medallion.size.y - 24.0)
    state_label.size = Vector2(medallion.size.x - 16.0, 16.0)
    medallion.add_child(state_label)
    return btn


func _get_medallion_size(node_type: MapNodeData.NodeType) -> Vector2:
    match node_type:
        MapNodeData.NodeType.SHOP:
            return Vector2(80.0, 68.0)
        MapNodeData.NodeType.RANDOM_EVENT:
            return Vector2(70.0, 82.0)
        MapNodeData.NodeType.FORGE:
            return Vector2(82.0, 82.0)
        MapNodeData.NodeType.REST:
            return Vector2(72.0, 72.0)
        MapNodeData.NodeType.SPECIAL_STAGE:
            return Vector2(86.0, 86.0)
        _:
            return Vector2(76.0, 76.0)


func _get_medallion_corner(node_type: MapNodeData.NodeType) -> int:
    match node_type:
        MapNodeData.NodeType.SHOP:
            return 10
        MapNodeData.NodeType.RANDOM_EVENT:
            return 22
        MapNodeData.NodeType.FORGE:
            return 6
        MapNodeData.NodeType.REST:
            return 26
        MapNodeData.NodeType.SPECIAL_STAGE:
            return 14
        _:
            return 12


func _refresh_visual_state() -> void:
    if _stage_map == null:
        return
    for row_index: int in _node_buttons.size():
        var row_btns: Array = _node_buttons[row_index]
        for col_index: int in row_btns.size():
            var btn: Button = row_btns[col_index] as Button
            var node: MapNodeData = _stage_map.get_node_at(row_index, col_index)
            _apply_button_visuals(btn, node, row_index, col_index)
    _redraw_connections()


func _apply_button_visuals(btn: Button, node: MapNodeData, row: int, col: int) -> void:
    if btn == null or node == null:
        return
    var medallion: PanelContainer = btn.get_node("Medallion") as PanelContainer
    var accent_bar: ColorRect = medallion.get_node("AccentBar") as ColorRect
    var stamp_label: Label = medallion.get_node("StampLabel") as Label
    var state_label: Label = medallion.get_node("StateLabel") as Label
    var node_color: Color = node.get_color()
    var is_selected: bool = row == _selected_row and col == _selected_col
    var is_current_row: bool = row == _current_row
    var is_reachable: bool = _is_reachable_without_reroute(row, col)
    var is_reroute_target: bool = is_current_row and _reroute_enabled and not is_reachable
    var is_available_now: bool = is_current_row and _can_reach(row, col)
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.set_corner_radius_all(_get_medallion_corner(node.type))
    style.shadow_size = 0
    var fill_color: Color = Color("#171319")
    var border_color: Color = Color("#43372A")
    var border_width: int = 1
    var accent_color: Color = Color(node_color, 0.55)
    var stamp_color: Color = Color("#E9DEC2")
    var state_text: String = "FUTURE"
    var state_color: Color = Color("#7D756D")
    var button_alpha: float = 1.0
    if node.visited:
        fill_color = Color("#151219")
        border_color = Color("#625446", 0.75)
        accent_color = Color("#6D5D4B", 0.70)
        stamp_color = Color("#938777")
        state_text = "ASH"
        state_color = Color("#8A7868")
        button_alpha = VISITED_ALPHA
    elif row < _current_row:
        fill_color = Color("#121018")
        border_color = Color("#2B262C")
        accent_color = Color("#4A413B", 0.55)
        stamp_color = Color("#7E746A")
        state_text = "SPENT"
        state_color = Color("#685F58")
        button_alpha = 0.32
    elif is_reroute_target:
        fill_color = Color("#241B16")
        border_color = REROUTE_GLOW
        accent_color = REROUTE_GLOW
        stamp_color = Color("#F6E3BC")
        state_text = "BRASS"
        state_color = REROUTE_GLOW
    elif is_available_now:
        fill_color = Color("#162026")
        border_color = CURRENT_ROW_GLOW
        accent_color = CURRENT_ROW_GLOW
        stamp_color = Color("#E8F3F2")
        state_text = "LIVE"
        state_color = CURRENT_ROW_GLOW
    elif is_current_row:
        fill_color = Color("#19161C")
        border_color = Color("#4A3D33")
        accent_color = Color("#6C5845")
        stamp_color = Color("#A59A88")
        state_text = "LOCKED"
        state_color = Color("#8B7051")
        button_alpha = UNREACHABLE_ALPHA
    else:
        fill_color = Color("#131018")
        border_color = Color("#2A252D")
        accent_color = Color(node_color, 0.38)
        stamp_color = Color("#8D8376")
        state_text = "FUTURE"
        state_color = Color("#736A63")
        button_alpha = FUTURE_ALPHA
    if is_selected:
        border_color = SELECTED_GLOW if not is_reroute_target else REROUTE_GLOW
        border_width = 3
        accent_color = SELECTED_GLOW if not is_reroute_target else REROUTE_GLOW
        stamp_color = Color.WHITE
        button_alpha = 1.0
    elif is_available_now or is_reroute_target:
        border_width = 2
    style.bg_color = fill_color
    style.border_color = border_color
    style.set_border_width_all(border_width)
    medallion.add_theme_stylebox_override("panel", style)
    medallion.modulate = Color(1.0, 1.0, 1.0, button_alpha)
    btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
    btn.disabled = false
    accent_bar.color = accent_color
    stamp_label.text = node.get_map_stamp()
    stamp_label.add_theme_font_override("font", _UITheme.font_display())
    stamp_label.add_theme_font_size_override("font_size", ICON_FONT_SIZE)
    stamp_label.add_theme_color_override("font_color", stamp_color)
    state_label.text = state_text
    state_label.add_theme_font_override("font", _UITheme.font_mono())
    state_label.add_theme_font_size_override("font_size", STATE_FONT_SIZE)
    state_label.add_theme_color_override("font_color", state_color)


func _can_reach(row: int, col: int) -> bool:
    if row == _current_row and _reroute_enabled:
        return true
    return _is_reachable_without_reroute(row, col)


func _is_reachable_without_reroute(row: int, col: int) -> bool:
    if row == 0:
        return true
    if _current_col < 0:
        return true
    return _stage_map.is_reachable(row, col, row - 1, _current_col)


func _on_node_pressed(row: int, col: int) -> void:
    _set_selected_node(row, col)
    if _is_closing:
        return
    if row != _current_row or not _can_reach(row, col):
        return
    _is_closing = true
    var node: MapNodeData = _stage_map.get_node_at(row, col)
    var used_reroute: bool = try_consume_reroute_for(row, col)
    if node != null:
        node.visited = true
    await _play_close_transition()
    visible = false
    node_selected.emit(row, col, node, used_reroute)


func _on_node_hovered(row: int, col: int) -> void:
    _set_selected_node(row, col)


func _set_selected_node(row: int, col: int) -> void:
    if _stage_map == null:
        return
    var node: MapNodeData = _stage_map.get_node_at(row, col)
    if node == null:
        return
    if _selected_row == row and _selected_col == col and _selected_node == node:
        return
    _selected_row = row
    _selected_col = col
    _selected_node = node
    _refresh_selected_node_panel()
    _refresh_hint_label()
    _refresh_visual_state()


func _ensure_selected_node() -> void:
    if _stage_map == null:
        _selected_node = null
        _selected_row = -1
        _selected_col = -1
        _refresh_selected_node_panel()
        return
    if _selected_row >= 0 and _selected_col >= 0 and _stage_map.get_node_at(_selected_row, _selected_col) != null:
        _selected_node = _stage_map.get_node_at(_selected_row, _selected_col)
        _refresh_selected_node_panel()
        return
    var row_nodes: Array[MapNodeData] = _stage_map.get_row(_current_row)
    for col_index: int in row_nodes.size():
        if _can_reach(_current_row, col_index):
            _selected_row = _current_row
            _selected_col = col_index
            _selected_node = row_nodes[col_index] as MapNodeData
            _refresh_selected_node_panel()
            return
    if row_nodes.size() > 0:
        _selected_row = _current_row
        _selected_col = 0
        _selected_node = row_nodes[0] as MapNodeData
    else:
        _selected_row = -1
        _selected_col = -1
        _selected_node = null
    _refresh_selected_node_panel()


func _refresh_context_label() -> void:
    _context_label.text = "Loop %d  |  Stage %d / %d" % [GameManager.current_loop, _current_row + 1, StageMapData.ROWS_PER_LOOP]
    _header_seal.text = "BRASS TOKEN ARMED" if _reroute_enabled else "CHOOSE THE NEXT MARK"


func _refresh_selected_node_panel() -> void:
    if _selected_node == null:
        _selected_node_title.text = "No node selected"
        _selected_node_type.text = "Route marker"
        _selected_node_flavor.text = "Hover a marked route to inspect what it offers."
        _selected_node_summary.text = "The map stays clean; the details live here."
        _selected_node_rule.visible = false
        return
    var node_state: String = _get_selected_node_state_text(_selected_row, _selected_col)
    _selected_node_title.text = _selected_node.get_inspector_title()
    _selected_node_type.text = "%s  |  %s" % [_selected_node.get_inspector_type_label(), node_state]
    _selected_node_flavor.text = _selected_node.get_inspector_flavor()
    _selected_node_summary.text = _selected_node.get_inspector_summary()
    var special_preview: String = _selected_node.get_special_rule_preview()
    _selected_node_rule.visible = special_preview != ""
    _selected_node_rule.text = "Rule Preview: %s" % special_preview


func _get_selected_node_state_text(row: int, col: int) -> String:
    if _selected_node == null:
        return "Inspect"
    if _selected_node.visited:
        return "Visited"
    if row < _current_row:
        return "Spent"
    if row == _current_row and _reroute_enabled and not _is_reachable_without_reroute(row, col):
        return "Reroute"
    if row == _current_row and _can_reach(row, col):
        return "Available Now"
    if row == _current_row:
        return "Path Locked"
    return "Future Route"


func _prepare_nodes_for_intro() -> void:
    for row_btns_variant: Variant in _node_buttons:
        for btn: Button in row_btns_variant as Array[Button]:
            btn.modulate.a = 0.0
            btn.position.y += 10.0


func _show_nodes_immediately() -> void:
    for row_btns_variant: Variant in _node_buttons:
        for btn: Button in row_btns_variant as Array[Button]:
            btn.modulate.a = 1.0


func _play_intro() -> void:
    if _transition_tween != null:
        _transition_tween.kill()
    modulate.a = 1.0
    _transition_tween = FlowTransitionScript.play_enter(self, _content, PANEL_INTRO_DURATION, _backdrop)
    if not _last_open_used_loop_reveal:
        return
    var reveal_index: int = 0
    for row_index: int in _node_buttons.size():
        var row_btns: Array = _node_buttons[row_index]
        for col_index: int in row_btns.size():
            _transition_tween.tween_callback(Callable(self, "_reveal_node_button_by_index").bind(row_index, col_index)).set_delay(NODE_REVEAL_STAGGER * reveal_index)
            reveal_index += 1


func _reveal_node_button(btn: Button) -> void:
    var tween: Tween = create_tween()
    var end_y: float = btn.position.y - 10.0
    tween.tween_property(btn, "modulate:a", 1.0, NODE_REVEAL_DURATION)
    tween.parallel().tween_property(btn, "position:y", end_y, NODE_REVEAL_DURATION).set_ease(Tween.EASE_OUT)


func _reveal_node_button_by_index(row_index: int, col_index: int) -> void:
    if row_index < 0 or row_index >= _node_buttons.size():
        return
    var row_btns: Array = _node_buttons[row_index]
    if col_index < 0 or col_index >= row_btns.size():
        return
    var btn: Button = row_btns[col_index] as Button
    if btn == null or not is_instance_valid(btn):
        return
    _reveal_node_button(btn)


func _refresh_hint_label() -> void:
    var base_text: String = "Stage %d / %d  |  Inspect a route, then commit from the lit row." % [_current_row + 1, StageMapData.ROWS_PER_LOOP]
    if _selected_node != null:
        base_text = "Stage %d / %d  |  %s" % [_current_row + 1, StageMapData.ROWS_PER_LOOP, _selected_node.get_hover_description()]
    if _reroute_enabled:
        _hint_label.text = "%s  Reroute preview is live; brass marks spend a token only if chosen." % base_text
    elif _reroute_uses > 0:
        _hint_label.text = "%s  %d reroute token%s ready." % [base_text, _reroute_uses, "" if _reroute_uses == 1 else "s"]
    else:
        _hint_label.text = base_text
    _refresh_context_label()


func _show_node_hint(row: int, col: int, node: MapNodeData) -> void:
    _on_node_hovered(row, col)
    if node == null:
        _refresh_hint_label()
        return
    _hint_label.text = "%s  |  %s" % [_get_route_hint(row, col), node.get_hover_text()]
    _refresh_context_label()


func _get_route_hint(row: int, col: int) -> String:
    if row < _current_row:
        return "Row %d visited" % (row + 1)
    if row > _current_row:
        return "Row %d future path" % (row + 1)
    if _reroute_enabled and not _is_reachable_without_reroute(row, col):
        return "Row %d reroute path" % (row + 1)
    if _is_reachable_without_reroute(row, col):
        return "Row %d reachable now" % (row + 1)
    return "Row %d blocked on this route" % (row + 1)


func _refresh_reroute_button() -> void:
    _reroute_button.visible = _reroute_uses > 0
    _reroute_button.text = "Cancel Reroute Preview" if _reroute_enabled else "Preview Reroute (%d)" % _reroute_uses


func _on_reroute_button_pressed() -> void:
    if _reroute_uses <= 0:
        return
    _reroute_enabled = not _reroute_enabled
    _refresh_hint_label()
    _refresh_reroute_button()
    _refresh_visual_state()


func _play_close_transition() -> void:
    if _transition_tween != null:
        _transition_tween.kill()
    _transition_tween = FlowTransitionScript.play_exit(self, _content, 0.16, _backdrop)
    await _transition_tween.finished


func _apply_theme_styling() -> void:
    add_theme_stylebox_override("panel", _UITheme.make_panel_stylebox(Color.TRANSPARENT, 0))
    _backdrop.color = Color("#090A0F", 0.95)
    _header_panel.add_theme_stylebox_override("panel", _UITheme.make_panel_stylebox(Color("#120F15", 0.94), 14, Color("#564535"), 1))
    _board_frame.add_theme_stylebox_override("panel", _UITheme.make_panel_stylebox(Color("#17131A", 0.96), 18, Color("#5C4A38"), 2))
    _inspector_panel.add_theme_stylebox_override("panel", _UITheme.make_panel_stylebox(Color("#151117", 0.97), 16, Color("#473A2F"), 1))
    _footer_panel.add_theme_stylebox_override("panel", _UITheme.make_panel_stylebox(Color("#100D13", 0.94), 14, Color("#43372C"), 1))
    _title_label.add_theme_font_override("font", _UITheme.font_display())
    _title_label.add_theme_font_size_override("font_size", 18)
    _title_label.add_theme_color_override("font_color", Color("#E5D9B7"))
    _context_label.add_theme_font_override("font", _UITheme.font_mono())
    _context_label.add_theme_font_size_override("font_size", 18)
    _context_label.add_theme_color_override("font_color", Color("#A8A099"))
    _header_seal.add_theme_font_override("font", _UITheme.font_mono())
    _header_seal.add_theme_font_size_override("font_size", 20)
    _header_seal.add_theme_color_override("font_color", Color("#8F7C63"))
    _board_label.add_theme_font_override("font", _UITheme.font_mono())
    _board_label.add_theme_font_size_override("font_size", 20)
    _board_label.add_theme_color_override("font_color", Color("#907A60"))
    _inspector_eyebrow.add_theme_font_override("font", _UITheme.font_mono())
    _inspector_eyebrow.add_theme_font_size_override("font_size", 18)
    _inspector_eyebrow.add_theme_color_override("font_color", Color("#8F7C63"))
    _selected_node_title.add_theme_font_override("font", _UITheme.font_display())
    _selected_node_title.add_theme_font_size_override("font_size", 16)
    _selected_node_title.add_theme_color_override("font_color", Color("#EAE1C8"))
    _selected_node_type.add_theme_font_override("font", _UITheme.font_mono())
    _selected_node_type.add_theme_font_size_override("font_size", 18)
    _selected_node_type.add_theme_color_override("font_color", Color("#B7AB95"))
    _selected_node_flavor.add_theme_font_override("font", _UITheme.font_body())
    _selected_node_flavor.add_theme_font_size_override("font_size", 15)
    _selected_node_flavor.add_theme_color_override("font_color", Color("#C9BEAE"))
    _selected_node_summary.add_theme_font_override("font", _UITheme.font_body())
    _selected_node_summary.add_theme_font_size_override("font_size", 15)
    _selected_node_summary.add_theme_color_override("font_color", Color("#E3D8C4"))
    _selected_node_rule.add_theme_font_override("font", _UITheme.font_body())
    _selected_node_rule.add_theme_font_size_override("font_size", 15)
    _selected_node_rule.add_theme_color_override("font_color", Color("#D7A769"))
    _reroute_button.add_theme_font_override("font", _UITheme.font_display())
    _reroute_button.add_theme_font_size_override("font_size", 12)
    _reroute_button.add_theme_stylebox_override("normal", _UITheme.make_panel_stylebox(Color("#231913"), 12, REROUTE_GLOW, 2))
    _reroute_button.add_theme_stylebox_override("hover", _UITheme.make_panel_stylebox(Color("#2D2018"), 12, REROUTE_GLOW, 2))
    _reroute_button.add_theme_stylebox_override("pressed", _UITheme.make_panel_stylebox(Color("#1A120E"), 12, REROUTE_GLOW, 2))
    _reroute_button.add_theme_color_override("font_color", Color("#F2DFB6"))
    _reroute_button.add_theme_color_override("font_hover_color", Color.WHITE)
    _hint_label.add_theme_font_override("font", _UITheme.font_body())
    _hint_label.add_theme_font_size_override("font_size", 15)
    _hint_label.add_theme_color_override("font_color", Color("#D4C8B7"))
    _legend_label.add_theme_font_override("font", _UITheme.font_mono())
    _legend_label.add_theme_font_size_override("font_size", 16)
    _legend_label.add_theme_color_override("font_color", Color("#8A7F73"))
