extends PanelContainer
## Simple top-right achievement toast.

@onready var _message_label: Label = $MarginContainer/MessageLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
