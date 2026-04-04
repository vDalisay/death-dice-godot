class_name EvenOddBetOverlay
extends PanelContainer
## Shop sub-overlay: bet on parity of kept NUMBER-face dice when banking.
## EVEN or ODD pick; majority wins at 2:1. Ties push (wager refunded).

signal resolved()

const WAGER_STEPS: Array[int] = [5, 10, 15, 20, 25]
const _UITheme := preload("res://Scripts/UITheme.gd")

@onready var _modal: PanelContainer = $CenterContainer/Modal
@onready var _title_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/TitleLabel
@onready var _info_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/InfoLabel
@onready var _wager_row: HBoxContainer = $CenterContainer/Modal/MarginContainer/VBoxContainer/WagerRow
@onready var _wager_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/WagerLabel
@onready var _pick_row: HBoxContainer = $CenterContainer/Modal/MarginContainer/VBoxContainer/PickRow
@onready var _odds_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/OddsLabel
@onready var _confirm_button: Button = $CenterContainer/Modal/MarginContainer/VBoxContainer/ConfirmButton
@onready var _close_button: Button = $CenterContainer/Modal/MarginContainer/VBoxContainer/CloseButton

var _wager: int = 5
var _pick_even: bool = true
var _pick_confirmed: bool = false
var _wager_buttons: Array[Button] = []
var _even_button: Button = null
var _odd_button: Button = null


func _ready() -> void:
	_apply_theme_styling()
	visible = false
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_build_wager_buttons()
	_build_pick_buttons()


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
	_info_label.add_theme_font_size_override("font_size", 14)
	_info_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)

	_wager_label.add_theme_font_override("font", _UITheme.font_stats())
	_wager_label.add_theme_font_size_override("font_size", 18)
	_wager_label.add_theme_color_override("font_color", _UITheme.ACTION_CYAN)

	_odds_label.add_theme_font_override("font", _UITheme.font_body())
	_odds_label.add_theme_font_size_override("font_size", 13)
	_odds_label.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)

	for button: Button in [_confirm_button, _close_button]:
		button.add_theme_font_override("font", _UITheme.font_display())
		button.add_theme_font_size_override("font_size", 14)


func _build_wager_buttons() -> void:
	_wager_buttons.clear()
	for amount: int in WAGER_STEPS:
		var btn := Button.new()
		btn.text = "%dg" % amount
		btn.custom_minimum_size = Vector2(60, 44)
		btn.add_theme_font_override("font", _UITheme.font_display())
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(func() -> void: _on_wager_selected(amount))
		_wager_row.add_child(btn)
		_wager_buttons.append(btn)


func _build_pick_buttons() -> void:
	_even_button = Button.new()
	_even_button.text = "EVEN"
	_even_button.custom_minimum_size = Vector2(160, 56)
	_even_button.add_theme_font_override("font", _UITheme.font_display())
	_even_button.add_theme_font_size_override("font_size", 18)
	_even_button.pressed.connect(func() -> void: _on_pick_selected(true))
	_pick_row.add_child(_even_button)

	_odd_button = Button.new()
	_odd_button.text = "ODD"
	_odd_button.custom_minimum_size = Vector2(160, 56)
	_odd_button.add_theme_font_override("font", _UITheme.font_display())
	_odd_button.add_theme_font_size_override("font_size", 18)
	_odd_button.pressed.connect(func() -> void: _on_pick_selected(false))
	_pick_row.add_child(_odd_button)


func open() -> void:
	_wager = 5
	_pick_even = true
	_pick_confirmed = false
	_info_label.text = "At bank: count parity of kept NUMBER dice.\nMajority wins 2:1 payout.  Ties push (refund)."
	_odds_label.text = "~50/50 — ties push"
	_confirm_button.disabled = true
	_confirm_button.text = "Confirm Bet"
	_close_button.visible = true
	_refresh_wager_display()
	_refresh_pick_display()
	visible = true


func _on_wager_selected(amount: int) -> void:
	if GameManager.gold < amount:
		return
	_wager = amount
	_refresh_wager_display()
	_update_confirm_state()


func _on_pick_selected(is_even: bool) -> void:
	_pick_even = is_even
	_pick_confirmed = true
	_refresh_pick_display()
	_update_confirm_state()


func _refresh_wager_display() -> void:
	_wager_label.text = "Wager: %dg  →  Win: %dg" % [_wager, _wager * 2]
	for i: int in _wager_buttons.size():
		var amount: int = WAGER_STEPS[i]
		_wager_buttons[i].disabled = GameManager.gold < amount
		_wager_buttons[i].modulate = _UITheme.ACTION_CYAN if amount == _wager else _UITheme.BRIGHT_TEXT


func _refresh_pick_display() -> void:
	_even_button.modulate = _UITheme.ACTION_CYAN if (_pick_confirmed and _pick_even) else _UITheme.BRIGHT_TEXT
	_odd_button.modulate = _UITheme.ACTION_CYAN if (_pick_confirmed and not _pick_even) else _UITheme.BRIGHT_TEXT


func _update_confirm_state() -> void:
	_confirm_button.disabled = not _pick_confirmed or GameManager.gold < _wager
	if _pick_confirmed:
		_confirm_button.text = "Bet %s for %dg" % ["EVEN" if _pick_even else "ODD", _wager]


func _on_confirm_pressed() -> void:
	GameManager.set_even_odd_bet(_pick_even, _wager)
	visible = false
	resolved.emit()


func _on_close_pressed() -> void:
	visible = false
	resolved.emit()
