extends ColorRect
## Reusable bust/game-over overlay with drop-from-top slam and impact shake.

signal finished

const _UITheme := preload("res://Scripts/UITheme.gd")

const PRE_FLASH_DELAY: float = 0.35
const DROP_OFFSET_Y: float = -600.0
const DROP_DURATION: float = 0.45
const SHAKE_MAGNITUDE: float = 8.0
const GLITCH_REVEAL_DURATION: float = 0.4
const GLITCH_CHARS: String = "#%&!?/\\01X*+"

@onready var _card: PanelContainer = $CenterContainer/Card
@onready var _message_label: Label = $CenterContainer/Card/MarginContainer/Content/MessageLabel
@onready var _sub_label: Label = $CenterContainer/Card/MarginContainer/Content/SubLabel

var _card_rest_position: Vector2 = Vector2.ZERO
var _target_message_text: String = ""


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
	_target_message_text = "GAME OVER" if game_over else "BUST! -%d LIFE" % life_loss
	_message_label.text = build_glitch_text(_target_message_text, 0.0)
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
	tween.parallel().tween_method(_set_glitch_progress, 0.0, 1.0, GLITCH_REVEAL_DURATION)
	# Impact shake once card lands.
	tween.tween_callback(_shake_card)
	tween.tween_interval(1.0)
	# Fade out and clean up.
	tween.tween_property(self, "color:a", 0.0, 0.35)
	tween.parallel().tween_property(_card, "modulate:a", 0.0, 0.35)
	tween.tween_callback(_finish_and_free)


func _shake_card() -> void:
	var rest: Vector2 = _card_rest_position
	var mag: float = SHAKE_MAGNITUDE
	var tween: Tween = create_tween()
	tween.tween_property(_card, "position", rest + Vector2(-mag, 0), 0.04)
	tween.tween_property(_card, "position", rest + Vector2(mag, 0), 0.05)
	tween.tween_property(_card, "position", rest + Vector2(-mag * 0.6, 0), 0.04)
	tween.tween_property(_card, "position", rest + Vector2(mag * 0.6, 0), 0.04)
	tween.tween_property(_card, "position", rest, 0.05)


func _set_glitch_progress(progress: float) -> void:
	_message_label.text = build_glitch_text(_target_message_text, progress)


func _finish_and_free() -> void:
	finished.emit()
	queue_free()


static func build_glitch_text(target_text: String, progress: float) -> String:
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	if clamped_progress >= 1.0:
		return target_text
	var result: String = ""
	var reveal_count: int = int(floor(float(target_text.length()) * clamped_progress))
	for i: int in target_text.length():
		var ch: String = target_text.substr(i, 1)
		if ch == " ":
			result += " "
		elif i < reveal_count:
			result += ch
		else:
			var glitch_index: int = posmod(i * 7 + int(round(clamped_progress * 37.0)), GLITCH_CHARS.length())
			result += GLITCH_CHARS.substr(glitch_index, 1)
	return result
