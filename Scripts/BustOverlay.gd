extends ColorRect
## Reusable bust/game-over overlay with drop-from-top slam and impact shake.

signal finished

const _UITheme := preload("res://Scripts/UITheme.gd")

const PRE_FLASH_DELAY: float = 0.35
const DROP_OFFSET_Y: float = -600.0
const DROP_DURATION: float = 0.45
const SHAKE_MAGNITUDE: float = 8.0

@onready var _card: PanelContainer = $CenterContainer/Card
@onready var _message_label: Label = $CenterContainer/Card/MarginContainer/Content/MessageLabel
@onready var _sub_label: Label = $CenterContainer/Card/MarginContainer/Content/SubLabel

var _card_rest_position: Vector2 = Vector2.ZERO


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

	# Let CenterContainer run its layout pass so _card.position is valid.
	await get_tree().process_frame

	_card_rest_position = _card.position
	color = Color(0, 0, 0, 0)
	_card.modulate.a = 0.0
	_card.scale = Vector2.ONE
	_card.position = Vector2(_card_rest_position.x, _card_rest_position.y + DROP_OFFSET_Y)

	var tween: Tween = create_tween()
	tween.tween_interval(PRE_FLASH_DELAY)
	# Fade in backdrop + card, drop card from above to center.
	tween.tween_property(self, "color:a", 0.75, 0.15)
	tween.parallel().tween_property(_card, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(_card, "position", _card_rest_position, DROP_DURATION) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# Impact shake once card lands.
	tween.tween_callback(_shake_card)
	tween.tween_interval(1.0)
	# Fade out and clean up.
	tween.tween_property(self, "color:a", 0.0, 0.35)
	tween.parallel().tween_property(_card, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func() -> void:
		finished.emit()
		queue_free()
	)


func _shake_card() -> void:
	var rest: Vector2 = _card_rest_position
	var mag: float = SHAKE_MAGNITUDE
	var tween: Tween = create_tween()
	tween.tween_property(_card, "position", rest + Vector2(-mag, 0), 0.04)
	tween.tween_property(_card, "position", rest + Vector2(mag, 0), 0.05)
	tween.tween_property(_card, "position", rest + Vector2(-mag * 0.6, 0), 0.04)
	tween.tween_property(_card, "position", rest + Vector2(mag * 0.6, 0), 0.04)
	tween.tween_property(_card, "position", rest, 0.05)
