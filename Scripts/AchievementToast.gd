extends PanelContainer
## Simple top-right achievement toast.

const _UITheme := preload("res://Scripts/UITheme.gd")

@onready var _message_label: Label = $MarginContainer/MessageLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _UITheme.make_stage_family_panel_style("footer", _UITheme.CORNER_RADIUS_CARD, 1))
	_message_label.add_theme_font_override("font", _UITheme.font_body())
	_message_label.add_theme_font_size_override("font_size", 18)
	_message_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_TITLE_COLOR)
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -420
	offset_top = 24
	offset_right = -24
	offset_bottom = 104
	visible = false


func show_unlock(title: String) -> void:
	_message_label.text = "Achievement Unlocked: %s" % title
	visible = true
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.4)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
