class_name HeatBetOverlay
extends PanelContainer
## Shop sub-overlay: player predicts the exact stop count when banking.
## Fixed wager 15g. Hit the exact stop count → 45g payout (3:1 net).

signal resolved()

const WAGER: int = 15
const PAYOUT: int = 45
const MIN_TARGET: int = 0
const MAX_TARGET: int = 4
const _UITheme := preload("res://Scripts/UITheme.gd")
## Rough % flavor labels per stop target (illustrative, not exact probability).
const TARGET_ODDS_LABEL: Array[String] = [
	"HEAT_ODDS_0",
	"HEAT_ODDS_1",
	"HEAT_ODDS_2",
	"HEAT_ODDS_3",
	"HEAT_ODDS_4",
]

@onready var _modal: PanelContainer = $CenterContainer/Modal
@onready var _title_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/TitleLabel
@onready var _wager_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/WagerLabel
@onready var _target_row: HBoxContainer = $CenterContainer/Modal/MarginContainer/VBoxContainer/TargetRow
@onready var _picked_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/PickedLabel
@onready var _odds_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/OddsLabel
@onready var _confirm_button: Button = $CenterContainer/Modal/MarginContainer/VBoxContainer/ConfirmButton
@onready var _close_button: Button = $CenterContainer/Modal/MarginContainer/VBoxContainer/CloseButton

var _picked_target: int = -1
var _target_buttons: Array[Button] = []


func _ready() -> void:
	_apply_theme_styling()
	visible = false
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_build_target_buttons()


func _apply_theme_styling() -> void:
	add_theme_stylebox_override("panel", _UITheme.make_panel_stylebox(Color(0, 0, 0, 0), 0))
	_modal.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_MODAL, _UITheme.ACTION_CYAN, 2)
	)
	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)

	_wager_label.add_theme_font_override("font", _UITheme.font_body())
	_wager_label.add_theme_font_size_override("font_size", 16)
	_wager_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)

	_picked_label.add_theme_font_override("font", _UITheme.font_stats())
	_picked_label.add_theme_font_size_override("font_size", 20)
	_picked_label.add_theme_color_override("font_color", _UITheme.ACTION_CYAN)

	_odds_label.add_theme_font_override("font", _UITheme.font_body())
	_odds_label.add_theme_font_size_override("font_size", 13)
	_odds_label.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)

	for button: Button in [_confirm_button, _close_button]:
		button.add_theme_font_override("font", _UITheme.font_display())
		button.add_theme_font_size_override("font_size", 14)


func _build_target_buttons() -> void:
	_target_buttons.clear()
	for target: int in range(MIN_TARGET, MAX_TARGET + 1):
		var btn := Button.new()
		btn.text = str(target)
		btn.custom_minimum_size = Vector2(64, 56)
		btn.add_theme_font_override("font", _UITheme.font_stats())
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(func() -> void: _on_target_picked(target))
		_target_row.add_child(btn)
		_target_buttons.append(btn)


func open() -> void:
	var can_afford: bool = GameManager.gold >= WAGER
	_picked_target = -1
	_title_label.text = tr("HEAT_BET_TITLE")
	_close_button.text = tr("NO_THANKS")
	_wager_label.text = tr("HEAT_WAGER_FMT").format({"wager": WAGER, "payout": PAYOUT})
	_picked_label.text = tr("HEAT_PICK_TARGET")
	_odds_label.text = ""
	_confirm_button.disabled = true
	_confirm_button.text = tr("HEAT_CONFIRM_FMT").format({"wager": WAGER})
	if not can_afford:
		_confirm_button.text = tr("NOT_ENOUGH_GOLD_FMT").format({"gold": WAGER})
	for btn: Button in _target_buttons:
		btn.disabled = not can_afford
		btn.modulate = _UITheme.BRIGHT_TEXT
	_close_button.visible = true
	visible = true


func _on_target_picked(target: int) -> void:
	_picked_target = target
	_picked_label.text = tr("HEAT_PICKED_FMT").format({"count": target, "s": "s" if target != 1 else ""})
	if target < TARGET_ODDS_LABEL.size():
		_odds_label.text = tr(TARGET_ODDS_LABEL[target])
	_confirm_button.disabled = false
	_confirm_button.text = tr("HEAT_CONFIRM_FMT").format({"wager": WAGER})
	for i: int in _target_buttons.size():
		_target_buttons[i].modulate = _UITheme.ACTION_CYAN if i == target else _UITheme.MUTED_TEXT


func _on_confirm_pressed() -> void:
	if _picked_target < 0:
		return
	GameManager.set_heat_bet(_picked_target, WAGER, PAYOUT)
	visible = false
	resolved.emit()


func _on_close_pressed() -> void:
	visible = false
	resolved.emit()
