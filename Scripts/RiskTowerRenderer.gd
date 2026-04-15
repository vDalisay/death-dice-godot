class_name RiskTowerRenderer
extends Node
## Renders the bust-risk tower overlay: vertical LED lights, stop dots,
## percentage label, and hover tooltip.  Pure presentation — no game logic.

const LIGHT_COUNT: int = 10
const STOP_DOT_COUNT: int = 4
const OVERLAY_WIDTH: float = 128.0

const _UITheme := preload("res://Scripts/UITheme.gd")

# ── Node references (injected via setup) ──────────────────────────────────
var _overlay: PanelContainer
var _title_label: Label
var _lights_column: VBoxContainer
var _stop_dots_column: VBoxContainer
var _percent_label: Label

# ── Runtime state ─────────────────────────────────────────────────────────
var _lights: Array[ColorRect] = []
var _stop_dots: Array[Label] = []
var _tooltip_text: String = ""
var _hovered: bool = false

## Reference to the HUD for tooltip display; set via setup().
var _hud: Node = null
## Reference to _roll_content for visibility tracking.
var _roll_content: Control = null


func setup(
	overlay: PanelContainer,
	title_label: Label,
	lights_column: VBoxContainer,
	stop_dots_column: VBoxContainer,
	percent_label: Label,
	hud_node: Node,
	roll_content: Control,
) -> void:
	_overlay = overlay
	_title_label = title_label
	_lights_column = lights_column
	_stop_dots_column = stop_dots_column
	_percent_label = percent_label
	_hud = hud_node
	_roll_content = roll_content

	_build_lights()
	_build_stop_dots()
	_apply_theme()

	_overlay.mouse_entered.connect(_on_mouse_entered)
	_overlay.mouse_exited.connect(_on_mouse_exited)


## Refresh the tower to reflect the current bust probability and stop count.
func refresh(bust_odds: float, effective_stops: int, risk_details: String) -> void:
	if _overlay == null:
		return
	_overlay.visible = _roll_content != null and _roll_content.visible
	if not _overlay.visible:
		_hovered = false
		_hide_tooltip()
		return
	_tooltip_text = risk_details
	var ratio: float = clampf(bust_odds, 0.0, 1.0)
	var filled: int = ceili(ratio * float(LIGHT_COUNT))
	var percent: int = int(round(ratio * 100.0))
	var light_color: Color = _UITheme.SUCCESS_GREEN
	if ratio >= 0.66:
		light_color = _UITheme.DANGER_RED
	elif ratio >= 0.33:
		light_color = _UITheme.SCORE_GOLD
	_percent_label.text = "%03d%%" % percent
	_percent_label.modulate = light_color
	for i: int in LIGHT_COUNT:
		var is_lit: bool = i >= LIGHT_COUNT - filled
		_lights[i].color = light_color if is_lit else Color("#1A2229")
	var lit_stop_dots: int = mini(maxi(effective_stops, 0), STOP_DOT_COUNT)
	for i: int in STOP_DOT_COUNT:
		var dot_lit: bool = i >= STOP_DOT_COUNT - lit_stop_dots
		_stop_dots[i].modulate = _UITheme.DANGER_RED if dot_lit else Color("#40252A")
	if _hovered:
		_show_tooltip()


# ── Private ───────────────────────────────────────────────────────────────

func _build_lights() -> void:
	if _lights_column == null:
		return
	for child: Node in _lights_column.get_children():
		child.queue_free()
	_lights.clear()
	for _i: int in LIGHT_COUNT:
		var light := ColorRect.new()
		light.custom_minimum_size = Vector2(16, 12)
		light.color = Color("#1A2229")
		_lights_column.add_child(light)
		_lights.append(light)


func _build_stop_dots() -> void:
	if _stop_dots_column == null:
		return
	for child: Node in _stop_dots_column.get_children():
		child.queue_free()
	_stop_dots.clear()
	for _i: int in STOP_DOT_COUNT:
		var dot := Label.new()
		dot.text = "●"
		dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dot.add_theme_font_override("font", _UITheme.font_display())
		dot.add_theme_font_size_override("font_size", 18)
		dot.modulate = Color("#40252A")
		_stop_dots_column.add_child(dot)
		_stop_dots.append(dot)


func _apply_theme() -> void:
	if _overlay == null:
		return
	_overlay.custom_minimum_size = Vector2(OVERLAY_WIDTH, 0.0)
	_overlay.size_flags_horizontal = Control.SIZE_SHRINK_END
	_overlay.add_theme_stylebox_override(
		"panel",
		_UITheme.make_stage_family_panel_style("inspector", _UITheme.CORNER_RADIUS_CARD, 1)
	)
	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", 13)
	_title_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_MUTED_TEXT)
	_percent_label.add_theme_font_override("font", _UITheme.font_mono())
	_percent_label.add_theme_font_size_override("font_size", 30)
	_percent_label.add_theme_color_override("font_color", _UITheme.SUCCESS_GREEN)
	refresh(0.0, 0, "")


func _on_mouse_entered() -> void:
	_hovered = true
	_show_tooltip()


func _on_mouse_exited() -> void:
	_hovered = false
	_hide_tooltip()


func _show_tooltip() -> void:
	if _hud != null and _hud.has_method("show_risk_tooltip") and _overlay != null:
		_hud.show_risk_tooltip(_overlay.get_global_rect(), _tooltip_text)


func _hide_tooltip() -> void:
	if _hud != null and _hud.has_method("hide_risk_tooltip"):
		_hud.hide_risk_tooltip()
