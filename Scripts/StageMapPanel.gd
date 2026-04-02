class_name StageMapPanel
extends PanelContainer
## Renders the branching stage map. Player picks a node in the current row.
## Self-contained modal panel — call open() and listen for node_selected.

signal node_selected(row: int, col: int, node_type: MapNodeData.NodeType)

const _UITheme := preload("res://Scripts/UITheme.gd")

const NODE_SIZE: float = 56.0
const NODE_SPACING_X: float = 120.0
const NODE_SPACING_Y: float = 72.0
const MAP_TOP_MARGIN: float = 20.0
const LINE_COLOR: Color = Color("#555577")
const LINE_COLOR_VISITED: Color = Color("#00E676", 0.5)
const LINE_WIDTH: float = 2.0
const VISITED_ALPHA: float = 0.35
const CURRENT_ROW_GLOW: Color = Color("#00E5FF")
const ICON_FONT_SIZE: int = 22
const LABEL_FONT_SIZE: int = 12

@onready var _backdrop: ColorRect = $Backdrop
@onready var _title_label: Label = $MarginContainer/VBoxContainer/HeaderRow/TitleLabel
@onready var _map_container: Control = $MarginContainer/VBoxContainer/MapArea
@onready var _hint_label: Label = $MarginContainer/VBoxContainer/HintLabel

var _stage_map: StageMapData = null
var _current_row: int = 0
var _current_col: int = -1  ## Column chosen in previous row (-1 = first row).
var _node_buttons: Array = []  # Array of Array[Button]
var _connection_lines: Array[Line2D] = []


func _ready() -> void:
	visible = false
	_apply_theme_styling()


func open(stage_map: StageMapData, current_row: int, previous_col: int) -> void:
	_stage_map = stage_map
	_current_row = current_row
	_current_col = previous_col
	_title_label.text = "LOOP %d — Choose Your Path" % GameManager.current_loop
	_hint_label.text = "Row %d / %d" % [current_row + 1, StageMapData.ROWS_PER_LOOP]
	_rebuild_map()
	visible = true


# ---------------------------------------------------------------------------
# Map rendering
# ---------------------------------------------------------------------------

func _rebuild_map() -> void:
	# Clear previous.
	for line: Line2D in _connection_lines:
		if is_instance_valid(line):
			line.queue_free()
	_connection_lines.clear()
	for row_buttons: Variant in _node_buttons:
		for btn: Variant in row_buttons as Array:
			if is_instance_valid(btn as Node):
				(btn as Node).queue_free()
	_node_buttons.clear()

	if _stage_map == null:
		return

	var map_width: float = _map_container.size.x
	var row_count: int = _stage_map.get_row_count()

	# Build node buttons row by row.
	for r: int in row_count:
		var row: Array = _stage_map.get_row(r)
		var row_btns: Array[Button] = []
		var node_count: int = row.size()
		var total_width: float = float(node_count - 1) * NODE_SPACING_X
		var start_x: float = (map_width - total_width) * 0.5
		var y: float = MAP_TOP_MARGIN + float(r) * NODE_SPACING_Y

		for c: int in node_count:
			var node: MapNodeData = row[c] as MapNodeData
			var x: float = start_x + float(c) * NODE_SPACING_X
			var btn: Button = _create_node_button(node, r, c, Vector2(x - NODE_SIZE * 0.5, y))
			row_btns.append(btn)
		_node_buttons.append(row_btns)

	# Draw connection lines between rows.
	for r: int in row_count - 1:
		var current_btns: Array = _node_buttons[r]
		var next_btns: Array = _node_buttons[r + 1]
		var row_data: Array = _stage_map.get_row(r)
		for c: int in row_data.size():
			var node: MapNodeData = row_data[c] as MapNodeData
			var from_btn: Button = current_btns[c] as Button
			var from_center: Vector2 = from_btn.position + Vector2(NODE_SIZE * 0.5, NODE_SIZE)
			for conn: int in node.connections:
				if conn >= 0 and conn < next_btns.size():
					var to_btn: Button = next_btns[conn] as Button
					var to_center: Vector2 = to_btn.position + Vector2(NODE_SIZE * 0.5, 0.0)
					var line: Line2D = Line2D.new()
					line.add_point(from_center)
					line.add_point(to_center)
					line.width = LINE_WIDTH
					line.default_color = LINE_COLOR_VISITED if node.visited else LINE_COLOR
					_map_container.add_child(line)
					# Lines behind buttons.
					_map_container.move_child(line, 0)
					_connection_lines.append(line)


func _create_node_button(node: MapNodeData, row: int, col: int, pos: Vector2) -> Button:
	var btn: Button = Button.new()
	btn.position = pos
	btn.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	btn.size = Vector2(NODE_SIZE, NODE_SIZE)
	btn.text = node.get_icon()
	btn.add_theme_font_size_override("font_size", ICON_FONT_SIZE)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.set_corner_radius_all(8)

	if node.visited:
		# Visited — dimmed.
		style.bg_color = _UITheme.PANEL_SURFACE
		style.border_color = node.get_color() * Color(1, 1, 1, VISITED_ALPHA)
		style.set_border_width_all(2)
		btn.disabled = true
		btn.modulate = Color(1, 1, 1, VISITED_ALPHA)
	elif row == _current_row and _can_reach(row, col):
		# Current row + reachable — clickable with glow.
		style.bg_color = _UITheme.ELEVATED
		style.border_color = CURRENT_ROW_GLOW
		style.set_border_width_all(3)
		btn.disabled = false
		var captured_row: int = row
		var captured_col: int = col
		var captured_type: MapNodeData.NodeType = node.type
		btn.pressed.connect(func() -> void: _on_node_pressed(captured_row, captured_col, captured_type))
	elif row == _current_row:
		# Current row but unreachable — dimmed.
		style.bg_color = _UITheme.PANEL_SURFACE
		style.border_color = Color("#555555")
		style.set_border_width_all(1)
		btn.disabled = true
		btn.modulate = Color(1, 1, 1, 0.4)
	elif row > _current_row:
		# Future row — faded.
		style.bg_color = Color(_UITheme.PANEL_SURFACE, 0.5)
		style.border_color = Color("#333344")
		style.set_border_width_all(1)
		btn.disabled = true
		btn.modulate = Color(1, 1, 1, 0.3)
	else:
		# Past row, not visited — skip.
		style.bg_color = _UITheme.PANEL_SURFACE
		style.border_color = Color("#444455")
		style.set_border_width_all(1)
		btn.disabled = true
		btn.modulate = Color(1, 1, 1, 0.25)

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("disabled", style)
	btn.add_theme_color_override("font_color", node.get_color())
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", node.get_color() * Color(1, 1, 1, 0.5))
	btn.mouse_filter = Control.MOUSE_FILTER_STOP

	# Add type label below the button.
	var type_label: Label = Label.new()
	type_label.text = node.get_display_name()
	type_label.add_theme_font_override("font", _UITheme.font_mono())
	type_label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	type_label.add_theme_color_override("font_color", node.get_color() * Color(1, 1, 1, 0.7))
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.position = Vector2(0, NODE_SIZE + 2)
	type_label.size = Vector2(NODE_SIZE, 16)
	btn.add_child(type_label)

	_map_container.add_child(btn)
	return btn


func _can_reach(row: int, col: int) -> bool:
	if row == 0:
		return true  # First row: all nodes reachable.
	if _current_col < 0:
		return true  # No previous column (shouldn't happen after row 0).
	return _stage_map.is_reachable(row, col, row - 1, _current_col)


func _on_node_pressed(row: int, col: int, node_type: MapNodeData.NodeType) -> void:
	# Mark node as visited.
	var node: MapNodeData = _stage_map.get_node_at(row, col)
	if node:
		node.visited = true
	visible = false
	node_selected.emit(row, col, node_type)


# ---------------------------------------------------------------------------
# Styling
# ---------------------------------------------------------------------------

func _apply_theme_styling() -> void:
	add_theme_stylebox_override("panel", _UITheme.make_panel_stylebox(Color(0, 0, 0, 0), 0))
	_backdrop.color = Color(0, 0, 0, 0.92)
	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)
	_hint_label.add_theme_font_override("font", _UITheme.font_mono())
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)
