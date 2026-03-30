extends ColorRect
## Reusable bust/game-over overlay with slam reveal and card shake.

signal finished

const _UITheme := preload("res://Scripts/UITheme.gd")

const PRE_FLASH_DELAY: float = 0.35

@onready var _card: PanelContainer = $CenterContainer/Card
@onready var _message_label: Label = $CenterContainer/Card/MarginContainer/Content/MessageLabel
@onready var _sub_label: Label = $CenterContainer/Card/MarginContainer/Content/SubLabel


func _ready() -> void:
	_apply_theme_styling()


func _apply_theme_styling() -> void:
	_card.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_MODAL, _UITheme.DANGER_RED, 2)
	)
	_message_label.add_theme_font_override("font", _UITheme.font_display())
	_message_label.add_theme_font_size_override("font_size", 32)
	_sub_label.add_theme_font_override("font", _UITheme.font_body())
	_sub_label.add_theme_font_size_override("font_size", 18)
	_sub_label.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)


func play(life_loss: int) -> void:
	var game_over: bool = GameManager.lives <= 0
	_message_label.text = "GAME OVER" if game_over else "BUST! -%d LIFE" % life_loss
	_message_label.add_theme_color_override("font_color", _UITheme.NEON_PURPLE if game_over else _UITheme.DANGER_RED)
	_sub_label.text = "Run ended." if game_over else "Your turn score was lost."

	color = Color(0, 0, 0, 0)
	_card.modulate.a = 0.0
	_message_label.modulate.a = 0.0
	_sub_label.modulate.a = 0.0
	_message_label.scale = Vector2(2.0, 2.0)
	_card.position = Vector2.ZERO

	var tween: Tween = create_tween()
	tween.tween_interval(PRE_FLASH_DELAY)
	tween.tween_property(self, "color:a", 0.75, 0.15)
	tween.parallel().tween_property(_card, "modulate:a", 1.0, 0.16)
	tween.parallel().tween_property(_message_label, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(_sub_label, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(_message_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_shake_card)
	tween.tween_interval(1.0)
	tween.tween_property(self, "color:a", 0.0, 0.35)
	tween.parallel().tween_property(_card, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func() -> void:
		finished.emit()
		queue_free()
	)


func _shake_card() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_card, "position", Vector2(-10, 0), 0.04)
	tween.tween_property(_card, "position", Vector2(10, 0), 0.05)
	tween.tween_property(_card, "position", Vector2(-6, 0), 0.04)
	tween.tween_property(_card, "position", Vector2(6, 0), 0.04)
	tween.tween_property(_card, "position", Vector2.ZERO, 0.05)
