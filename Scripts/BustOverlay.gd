extends ColorRect
## Reusable bust overlay with a dramatic pause + red flash.

signal finished

const PRE_FLASH_DELAY: float = 0.4

@onready var _message_label: Label = $MessageLabel


func play(life_loss: int) -> void:
	_message_label.text = "BUST! -%d Life" % life_loss
	color.a = 0.0
	_message_label.modulate.a = 0.0
	var tween: Tween = create_tween()
	# Dramatic pause before the red flash.
	tween.tween_interval(PRE_FLASH_DELAY)
	tween.tween_property(self, "color:a", 0.45, 0.15)
	tween.tween_property(_message_label, "modulate:a", 1.0, 0.1)
	tween.tween_interval(1.2)
	tween.tween_property(self, "color:a", 0.0, 0.4)
	tween.parallel().tween_property(_message_label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void:
		finished.emit()
		queue_free()
	)
