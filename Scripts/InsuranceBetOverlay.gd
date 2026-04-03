class_name InsuranceBetOverlay
extends PanelContainer
## Shop sub-overlay: player pays 10g premium to insure against busting this stage.
## If the player busts, they recover 25g (net +15g on bust).

signal resolved()

const PREMIUM: int = 10
const PAYOUT: int = 25
const _UITheme := preload("res://Scripts/UITheme.gd")

@onready var _modal: PanelContainer = $CenterContainer/Modal
@onready var _title_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/TitleLabel
@onready var _info_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/InfoLabel
@onready var _odds_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/OddsLabel
@onready var _confirm_button: Button = $CenterContainer/Modal/MarginContainer/VBoxContainer/ConfirmButton
@onready var _close_button: Button = $CenterContainer/Modal/MarginContainer/VBoxContainer/CloseButton


func _ready() -> void:
	_apply_theme_styling()
	visible = false
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_close_button.pressed.connect(_on_close_pressed)


func _apply_theme_styling() -> void:
	add_theme_stylebox_override("panel", _UITheme.make_panel_stylebox(Color(0, 0, 0, 0), 0))
	_modal.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_MODAL, _UITheme.ACTION_CYAN, 2)
	)
	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)

	_info_label.add_theme_font_override("font", _UITheme.font_body())
	_info_label.add_theme_font_size_override("font_size", 18)
	_info_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)

	_odds_label.add_theme_font_override("font", _UITheme.font_body())
	_odds_label.add_theme_font_size_override("font_size", 14)
	_odds_label.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)

	for button: Button in [_confirm_button, _close_button]:
		button.add_theme_font_override("font", _UITheme.font_display())
		button.add_theme_font_size_override("font_size", 14)


func open() -> void:
	var can_afford: bool = GameManager.gold >= PREMIUM
	_info_label.text = "Pay %dg now.\nIf you bust this stage → recover %dg\n(Net gain on bust: +%dg)" \
		% [PREMIUM, PAYOUT, PAYOUT - PREMIUM]
	_odds_label.text = "One-stage coverage only. Clears on bank or bust."
	_confirm_button.disabled = not can_afford
	_confirm_button.text = "Buy Insurance  (-%dg)" % PREMIUM if can_afford \
		else "Not enough gold (need %dg)" % PREMIUM
	_close_button.visible = true
	visible = true


func _on_confirm_pressed() -> void:
	GameManager.set_insurance_bet(PREMIUM, PAYOUT)
	visible = false
	resolved.emit()


func _on_close_pressed() -> void:
	visible = false
	resolved.emit()
