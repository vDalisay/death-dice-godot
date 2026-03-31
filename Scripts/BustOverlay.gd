extends ColorRect
## Reusable bust/game-over overlay with centered impact shake + red tilt flash.

signal finished

const _UITheme := preload("res://Scripts/UITheme.gd")

const PRE_FLASH_DELAY: float = 0.35
const TILT_PEAK_DEGREES: float = 20.0
const RED_FLASH_TINT: Color = Color(1.2, 0.5, 0.5, 1.0)

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
	_card.pivot_offset = _card.size * 0.5
	color = Color(0, 0, 0, 0)
	_card.modulate.a = 0.0
	_card.scale = Vector2.ONE
	_card.position = _card_rest_position
	_card.rotation_degrees = 0.0
	_card.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var tween: Tween = create_tween()
	tween.tween_interval(PRE_FLASH_DELAY)
	# Fade in backdrop + card while staying centered.
	tween.tween_property(self, "color:a", 0.75, 0.15)
	tween.parallel().tween_property(_card, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Impact sequence: shake + tilt + red flash on the popup card background.
	tween.tween_callback(_play_card_impact)
	tween.tween_interval(1.0)
	# Fade out and clean up.
	tween.tween_property(self, "color:a", 0.0, 0.35)
	tween.parallel().tween_property(_card, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func() -> void:
		finished.emit()
		queue_free()
	)

func _play_card_impact() -> void:
	var rot_tween: Tween = create_tween()
	rot_tween.tween_property(_card, "rotation_degrees", TILT_PEAK_DEGREES, 0.06).set_ease(Tween.EASE_OUT)
	rot_tween.tween_property(_card, "rotation_degrees", -TILT_PEAK_DEGREES * 0.65, 0.07).set_ease(Tween.EASE_OUT)
	rot_tween.tween_property(_card, "rotation_degrees", TILT_PEAK_DEGREES * 0.4, 0.06).set_ease(Tween.EASE_IN_OUT)
	rot_tween.tween_property(_card, "rotation_degrees", -TILT_PEAK_DEGREES * 0.22, 0.05).set_ease(Tween.EASE_IN_OUT)
	rot_tween.tween_property(_card, "rotation_degrees", 0.0, 0.07).set_ease(Tween.EASE_OUT)

	var scale_tween: Tween = create_tween()
	scale_tween.tween_property(_card, "scale", Vector2(1.05, 1.05), 0.08).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(_card, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_IN)

	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(_card, "modulate", RED_FLASH_TINT, 0.08).set_ease(Tween.EASE_OUT)
	flash_tween.tween_property(_card, "modulate", Color.WHITE, 0.2).set_ease(Tween.EASE_IN)
