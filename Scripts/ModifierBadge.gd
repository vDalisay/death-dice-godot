class_name ModifierBadge
extends PanelContainer
## 44x44 touch target with a centered 36x36 modifier badge body.

signal tooltip_requested(modifier: RunModifier, badge_rect: Rect2)
signal tooltip_hidden()

const _UITheme := preload("res://Scripts/UITheme.gd")

const TARGET_SIZE: int = 44
const BADGE_SIZE: int = 36

@onready var _body: PanelContainer = $CenterContainer/BadgeBody
@onready var _glyph_label: Label = $CenterContainer/BadgeBody/GlyphLabel
@onready var _hover_timer: Timer = $HoverTimer

var _modifier: RunModifier = null
var _pulse_tween: Tween = null
var _is_empty: bool = true


func _ready() -> void:
	custom_minimum_size = Vector2(TARGET_SIZE, TARGET_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Route hover from all inner controls to the 44x44 slot root.
	$CenterContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = ""
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_hover_timer.timeout.connect(_on_hover_delay_elapsed)


func setup_modifier(modifier: RunModifier) -> void:
	_modifier = modifier
	_glyph_label.text = modifier.get_badge_glyph()
	_glyph_label.add_theme_font_override("font", _UITheme.font_display())
	_glyph_label.add_theme_font_size_override("font_size", 12)
	_glyph_label.add_theme_color_override("font_color", modifier.get_badge_color())
	_body.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_BADGE, modifier.get_badge_color(), 1)
	)
	_body.modulate = Color(1, 1, 1, 1)
	_is_empty = false
	_start_pulse()


func setup_empty() -> void:
	_modifier = null
	_glyph_label.text = ""
	_body.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.ELEVATED, _UITheme.CORNER_RADIUS_BADGE, _UITheme.MUTED_TEXT, 1)
	)
	_body.modulate = Color(1, 1, 1, 0.7)
	_is_empty = true
	_stop_pulse()


func _on_mouse_entered() -> void:
	if _is_empty or _modifier == null:
		return
	_hover_timer.start()


func _on_mouse_exited() -> void:
	_hover_timer.stop()
	tooltip_hidden.emit()


func _on_hover_delay_elapsed() -> void:
	if _is_empty or _modifier == null:
		return
	tooltip_requested.emit(_modifier, Rect2(global_position, size))


func _start_pulse() -> void:
	_stop_pulse()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_body, "modulate:a", 0.78, 1.0)
	_pulse_tween.tween_property(_body, "modulate:a", 1.0, 1.0)


func _stop_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
