class_name StageMapPanel
extends PanelContainer
## Full-screen branching stage map. Player picks a node in the current row.
## Call open() and listen for node_selected.

signal node_selected(row: int, col: int, node: MapNodeData, used_reroute: bool)

const FlowTransitionScript: GDScript = preload("res://Scripts/FlowTransition.gd")
const _UITheme := preload("res://Scripts/UITheme.gd")
const StageMapDataScript: GDScript = preload("res://Scripts/StageMapData.gd")

# Layout tuning — all spacing is computed dynamically from container size.
const NODE_SIZE: float = 60.0
const NODE_CORNER: int = 10
const MIN_H_SPACING: float = 100.0
const LINE_WIDTH: float = 2.5
const LINE_WIDTH_ACTIVE: float = 3.5
const LINE_COLOR: Color = Color("#3A3A55")
const LINE_COLOR_VISITED: Color = Color("#00E676", 0.45)
const LINE_COLOR_ACTIVE: Color = Color("#00E5FF", 0.7)
const VISITED_ALPHA: float = 0.30
const FUTURE_ALPHA: float = 0.22
const UNREACHABLE_ALPHA: float = 0.35
const CURRENT_ROW_GLOW: Color = Color("#00E5FF")
const REROUTE_GLOW: Color = Color("#FFB347")
const ICON_FONT_SIZE: int = 24
const LABEL_FONT_SIZE: int = 11
const PANEL_INTRO_DURATION: float = 0.22
const NODE_REVEAL_STAGGER: float = 0.04
const NODE_REVEAL_DURATION: float = 0.16

@onready var _backdrop: ColorRect = $Backdrop
@onready var _content: VBoxContainer = $MarginContainer/VBoxContainer
@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _map_area: Control = $MarginContainer/VBoxContainer/MapArea
@onready var _hint_label: Label = $MarginContainer/VBoxContainer/HintLabel

var _stage_map: Resource = null
var _current_row: int = 0
var _current_col: int = -1
var _node_buttons: Array = []  # Array of Array[Button]
var _connection_lines: Array[Line2D] = []
var _pending_open: bool = false
var _reroute_button: Button = null
var _reroute_uses: int = 0
var _reroute_enabled: bool = false
var _transition_tween: Tween = null
var _last_open_used_loop_reveal: bool = false
var _is_closing: bool = false
var _default_hint_text: String = ""


func _ready() -> void:
	visible = false
	_apply_theme_styling()
	_ensure_reroute_button()
	_map_area.resized.connect(_on_map_area_resized)


func open(stage_map: Resource, current_row: int, previous_col: int, reroute_uses: int = 0) -> void:
	_stage_map = stage_map
	_current_row = _resolve_open_row(current_row)
	_current_col = _resolve_previous_col(previous_col, _current_row)
	_reroute_uses = reroute_uses if _current_row > 0 else 0
	_reroute_enabled = false
	_title_label.text = "LOOP %d — Choose Your Path" % GameManager.current_loop
	modulate.a = 1.0
	_backdrop.modulate.a = 0.0
	_refresh_hint_label()
	_refresh_reroute_button()
	visible = true
	_is_closing = false
	_last_open_used_loop_reveal = GameManager.consume_loop_reveal(GameManager.current_loop)
	# Defer rebuild so the layout pass resolves _map_area.size first.
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
		return false
	if _reroute_uses <= 0:
		return false
	_reroute_uses -= 1
	_reroute_enabled = false
	_refresh_hint_label()
	_refresh_reroute_button()
	return true


# ---------------------------------------------------------------------------
# Map rendering
# ---------------------------------------------------------------------------

func _rebuild_map() -> void:
	_clear_map()
	if _stage_map == null:
		return

	var area_w: float = _map_area.size.x
	var area_h: float = _map_area.size.y
	if area_w < 1.0 or area_h < 1.0:
		return

	var row_count: int = _stage_map.get_row_count()
	# Vertical: distribute rows evenly across the full height.
	var v_padding: float = NODE_SIZE * 0.5
	var usable_h: float = area_h - v_padding * 2.0
	var row_step_y: float = usable_h / float(maxi(row_count - 1, 1))

	# Build buttons per row.
	for r: int in row_count:
		var row_data: Array = _stage_map.get_row(r)
		var row_btns: Array[Button] = []
		var n: int = row_data.size()
		var h_spacing: float = maxf(MIN_H_SPACING, area_w * 0.25)
		var total_w: float = float(n - 1) * h_spacing
		var start_x: float = (area_w - total_w) * 0.5
		var y: float = v_padding + float(r) * row_step_y - NODE_SIZE * 0.5

		for c: int in n:
			var node: MapNodeData = row_data[c] as MapNodeData
			var x: float = start_x + float(c) * h_spacing - NODE_SIZE * 0.5
			var btn: Button = _make_node_button(node, r, c)
			btn.position = Vector2(x, y)
			_map_area.add_child(btn)
			row_btns.append(btn)
		_node_buttons.append(row_btns)

	# Connection lines (drawn behind buttons).
	_draw_connections()
	if _last_open_used_loop_reveal:
		_prepare_nodes_for_intro()
	else:
		_show_nodes_immediately()


func _clear_map() -> void:
	for line: Line2D in _connection_lines:
		if is_instance_valid(line):
			line.queue_free()
	_connection_lines.clear()
	for row_btns: Variant in _node_buttons:
		for btn: Variant in row_btns as Array:
			if is_instance_valid(btn as Node):
				(btn as Node).queue_free()
	_node_buttons.clear()


func _draw_connections() -> void:
	var row_count: int = _stage_map.get_row_count()
	for r: int in row_count - 1:
		var cur_btns: Array = _node_buttons[r]
		var nxt_btns: Array = _node_buttons[r + 1]
		var row_data: Array = _stage_map.get_row(r)
		for c: int in row_data.size():
			var node: MapNodeData = row_data[c] as MapNodeData
			var from_btn: Button = cur_btns[c] as Button
			var from_pt: Vector2 = from_btn.position + Vector2(NODE_SIZE * 0.5, NODE_SIZE)
			for conn: int in node.connections:
				if conn < 0 or conn >= nxt_btns.size():
					continue
				var to_btn: Button = nxt_btns[conn] as Button
				var to_pt: Vector2 = to_btn.position + Vector2(NODE_SIZE * 0.5, 0.0)
				var line: Line2D = Line2D.new()
				line.add_point(from_pt)
				line.add_point(to_pt)
				_apply_connection_visual(line, r, c, conn, node)
				_map_area.add_child(line)
				_map_area.move_child(line, 0)
				_connection_lines.append(line)


func _apply_connection_visual(line: Line2D, row: int, _col: int, next_col: int, node: MapNodeData) -> void:
	var target_row: int = row + 1
	var target_node: MapNodeData = _stage_map.get_node_at(target_row, next_col)
	if node.visited and target_node != null and target_node.visited:
		line.default_color = LINE_COLOR_VISITED
		line.width = LINE_WIDTH
		return
	if row == _current_row - 1 and node.visited and _is_reachable_without_reroute(target_row, next_col):
		line.default_color = LINE_COLOR_ACTIVE
		line.width = LINE_WIDTH_ACTIVE
		return
	line.default_color = LINE_COLOR
	line.width = LINE_WIDTH


# ---------------------------------------------------------------------------
# Node buttons
# ---------------------------------------------------------------------------

func _make_node_button(node: MapNodeData, row: int, col: int) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	btn.size = Vector2(NODE_SIZE, NODE_SIZE)
	btn.text = node.get_icon()
	btn.add_theme_font_size_override("font_size", ICON_FONT_SIZE)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP

	var node_color: Color = node.get_color()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.set_corner_radius_all(NODE_CORNER)

	if node.visited:
		_style_visited(style, btn, node_color)
	elif row == _current_row and _reroute_enabled and not _is_reachable_without_reroute(row, col):
		_style_reroute(style, btn, row, col)
	elif row == _current_row and _can_reach(row, col):
		_style_active(style, btn, node_color, row, col)
	elif row == _current_row:
		_style_unreachable(style, btn, node_color)
	elif row > _current_row:
		_style_future(style, btn, node_color)
	else:
		_style_past(style, btn, node_color)

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style.duplicate())
	btn.add_theme_stylebox_override("pressed", style.duplicate())
	btn.add_theme_stylebox_override("disabled", style)
	btn.add_theme_color_override("font_color", node_color)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(node_color, 0.5))
	btn.tooltip_text = node.get_hover_text()
	var hover_row: int = row
	var hover_col: int = col
	var hover_node: MapNodeData = node
	btn.mouse_entered.connect(func() -> void: _show_node_hint(hover_row, hover_col, hover_node))
	btn.mouse_exited.connect(_refresh_hint_label)

	# Type label below the icon.
	var lbl: Label = Label.new()
	lbl.text = node.get_map_label()
	lbl.add_theme_font_override("font", _UITheme.font_mono())
	lbl.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	lbl.add_theme_color_override("font_color", Color(node_color, 0.7))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, NODE_SIZE + 2)
	lbl.size = Vector2(NODE_SIZE, 16)
	btn.add_child(lbl)

	return btn


func _style_visited(style: StyleBoxFlat, btn: Button, color: Color) -> void:
	style.bg_color = _UITheme.PANEL_SURFACE
	style.border_color = Color(color, VISITED_ALPHA)
	style.set_border_width_all(2)
	btn.disabled = true
	btn.modulate = Color(1, 1, 1, VISITED_ALPHA)


func _style_active(style: StyleBoxFlat, btn: Button, _color: Color, row: int, col: int) -> void:
	style.bg_color = _UITheme.ELEVATED
	style.border_color = CURRENT_ROW_GLOW
	style.set_border_width_all(3)
	btn.disabled = false
	var r: int = row
	var c: int = col
	btn.pressed.connect(func() -> void: _on_node_pressed(r, c))
	# Hover variant.
	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = _UITheme.ELEVATED.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hover_style)


func _style_reroute(style: StyleBoxFlat, btn: Button, row: int, col: int) -> void:
	style.bg_color = Color(_UITheme.ELEVATED, 0.9)
	style.border_color = REROUTE_GLOW
	style.set_border_width_all(3)
	btn.disabled = false
	var r: int = row
	var c: int = col
	btn.pressed.connect(func() -> void: _on_node_pressed(r, c))
	btn.add_theme_color_override("font_color", REROUTE_GLOW)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = Color(_UITheme.ELEVATED.lightened(0.16), 0.95)
	btn.add_theme_stylebox_override("hover", hover_style)


func _style_unreachable(style: StyleBoxFlat, btn: Button, _color: Color) -> void:
	style.bg_color = Color(_UITheme.PANEL_SURFACE, 0.6)
	style.border_color = Color("#444455")
	style.set_border_width_all(1)
	btn.disabled = true
	btn.modulate = Color(1, 1, 1, UNREACHABLE_ALPHA)


func _style_future(style: StyleBoxFlat, btn: Button, _color: Color) -> void:
	style.bg_color = Color(_UITheme.PANEL_SURFACE, 0.4)
	style.border_color = Color("#2A2A3E")
	style.set_border_width_all(1)
	btn.disabled = true
	btn.modulate = Color(1, 1, 1, FUTURE_ALPHA)


func _style_past(style: StyleBoxFlat, btn: Button, _color: Color) -> void:
	style.bg_color = _UITheme.PANEL_SURFACE
	style.border_color = Color("#333344")
	style.set_border_width_all(1)
	btn.disabled = true
	btn.modulate = Color(1, 1, 1, 0.2)


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
	if _is_closing:
		return
	_is_closing = true
	var node: MapNodeData = _stage_map.get_node_at(row, col)
	var used_reroute: bool = try_consume_reroute_for(row, col)
	if node:
		node.visited = true
	await _play_close_transition()
	visible = false
	node_selected.emit(row, col, node, used_reroute)


# ---------------------------------------------------------------------------
# Styling
# ---------------------------------------------------------------------------

func _apply_theme_styling() -> void:
	# Transparent root panel — backdrop provides the dark overlay.
	add_theme_stylebox_override("panel", _UITheme.make_panel_stylebox(Color.TRANSPARENT, 0))
	_backdrop.color = Color(_UITheme.BACKGROUND, 0.95)

	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)

	_hint_label.add_theme_font_override("font", _UITheme.font_mono())
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)

func _prepare_nodes_for_intro() -> void:
	for row_btns: Variant in _node_buttons:
		for btn: Button in row_btns as Array[Button]:
			btn.modulate.a = 0.0
			btn.position.y += 10.0


func _show_nodes_immediately() -> void:
	for row_btns: Variant in _node_buttons:
		for btn: Button in row_btns as Array[Button]:
			btn.modulate.a = 1.0
			btn.scale = Vector2.ONE


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


func _ensure_reroute_button() -> void:
	if _reroute_button != null:
		return
	_reroute_button = Button.new()
	_reroute_button.text = "Preview Reroute"
	_reroute_button.custom_minimum_size = Vector2(0, 40)
	_reroute_button.focus_mode = Control.FOCUS_NONE
	_reroute_button.add_theme_font_override("font", _UITheme.font_display())
	_reroute_button.add_theme_font_size_override("font_size", 12)
	_reroute_button.pressed.connect(_on_reroute_button_pressed)
	_content.add_child(_reroute_button)


func _refresh_hint_label() -> void:
	var base_text: String = "Stage %d / %d" % [_current_row + 1, StageMapData.ROWS_PER_LOOP]
	if _reroute_enabled:
		_default_hint_text = "%s  |  Reroute preview active: token spends only if you break path" % base_text
	elif _reroute_uses > 0:
		_default_hint_text = "%s  |  %d reroute token%s ready" % [base_text, _reroute_uses, "" if _reroute_uses == 1 else "s"]
	else:
		_default_hint_text = base_text
	_hint_label.text = _default_hint_text


func _show_node_hint(row: int, col: int, node: MapNodeData) -> void:
	if node == null:
		_refresh_hint_label()
		return
	_hint_label.text = "%s  |  %s" % [_get_route_hint(row, col), node.get_hover_text()]


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
	if _reroute_button == null:
		return
	_reroute_button.visible = _reroute_uses > 0
	_reroute_button.text = "Cancel Reroute Preview" if _reroute_enabled else "Preview Reroute (%d)" % _reroute_uses


func _on_reroute_button_pressed() -> void:
	if _reroute_uses <= 0:
		return
	_reroute_enabled = not _reroute_enabled
	_refresh_hint_label()
	_refresh_reroute_button()
	_rebuild_map()


func _play_close_transition() -> void:
	if _transition_tween != null:
		_transition_tween.kill()
	_transition_tween = FlowTransitionScript.play_exit(self, _content, 0.16, _backdrop)
	await _transition_tween.finished
