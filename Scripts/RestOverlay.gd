extends ColorRect
## Rest result overlay shown after visiting a REST node.

signal continue_requested

const _UITheme := preload("res://Scripts/UITheme.gd")

const BACKDROP_ALPHA: float = 0.52
const INTRO_DURATION: float = 0.22
const CARD_SCALE_START: float = 1.1

@onready var _card: PanelContainer = $CenterContainer/Card
@onready var _title_label: Label = $CenterContainer/Card/MarginContainer/Content/TitleLabel
@onready var _summary_label: Label = $CenterContainer/Card/MarginContainer/Content/SummaryLabel
@onready var _detail_label: Label = $CenterContainer/Card/MarginContainer/Content/DetailLabel
@onready var _continue_button: Button = $CenterContainer/Card/MarginContainer/Content/ContinueButton


func _ready() -> void:
	_apply_theme_styling()
	_continue_button.text = tr("CONTINUE_ACTION")
	_continue_button.pressed.connect(_on_continue_pressed)


func _apply_theme_styling() -> void:
	_card.add_theme_stylebox_override(
		"panel",
		_UITheme.make_stage_family_panel_style("inspector", _UITheme.CORNER_RADIUS_MODAL, 2)
	)
	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_TITLE_COLOR)
	_summary_label.add_theme_font_override("font", _UITheme.font_stats())
	_summary_label.add_theme_font_size_override("font_size", 18)
	_summary_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_BODY_TEXT)
	_detail_label.add_theme_font_override("font", _UITheme.font_body())
	_detail_label.add_theme_font_size_override("font_size", 14)
	_detail_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_CONTEXT_COLOR)
	_continue_button.add_theme_font_override("font", _UITheme.font_display())
	_continue_button.add_theme_font_size_override("font_size", 13)


func open(heal_lives: int, gold_bonus: int, lives_before: int, lives_after: int) -> void:
	var life_gain: int = maxi(0, lives_after - lives_before)
	_title_label.text = tr("REST_STOP_TITLE")
	_summary_label.text = tr("REST_STOP_RECOVERED_FMT").format({"life": life_gain, "gold": gold_bonus})
	if life_gain == 0:
		_summary_label.text = tr("REST_STOP_NO_HEAL_FMT").format({"gold": gold_bonus})
	_detail_label.text = tr("REST_STOP_HANDS_NEXT_FMT").format({"before": lives_before, "after": lives_after})
	if life_gain > 0 and life_gain != heal_lives:
		_detail_label.text = tr("REST_STOP_CAPPED_FMT").format({"before": lives_before, "after": lives_after})
	_continue_button.text = tr("CONTINUE_ACTION")
	color = Color(0, 0, 0, 0)
	_card.modulate.a = 0.0
	_card.scale = Vector2(CARD_SCALE_START, CARD_SCALE_START)
	_card.pivot_offset = _card.size * 0.5
	_continue_button.disabled = true
	_continue_button.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "color:a", BACKDROP_ALPHA, INTRO_DURATION)
	tween.parallel().tween_property(_card, "modulate:a", 1.0, INTRO_DURATION)
	tween.parallel().tween_property(_card, "scale", Vector2.ONE, INTRO_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_enable_continue)


func _enable_continue() -> void:
	_continue_button.disabled = false
	_continue_button.modulate.a = 1.0


func _on_continue_pressed() -> void:
	continue_requested.emit()