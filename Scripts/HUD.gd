class_name HUD
extends VBoxContainer
## Observes GameManager and RollPhase signals. Renders labels only — no game logic.
## Redesigned as a compact 3-zone dashboard with themed panels and risk pips.

const _UITheme := preload("res://Scripts/UITheme.gd")
const StageMapDataScript: GDScript = preload("res://Scripts/StageMapData.gd")
const _ModifierBadgeScene: PackedScene = preload("res://Scenes/ModifierBadge.tscn")
const LoopContractCatalogScript: GDScript = preload("res://Scripts/LoopContractCatalog.gd")
const ContractProgressServiceScript: GDScript = preload("res://Scripts/ContractProgressService.gd")

const SCORE_COUNT_DURATION: float = 0.5
const SCORE_STEP_DURATION: float = 0.18
const SCORE_TRANSFER_DURATION: float = 0.34
const SCORE_TRANSFER_ARC_HEIGHT: float = 44.0
const GOLD_FLOAT_DURATION: float = 1.0
const GOLD_COUNT_DURATION: float = 0.35
const PROGRESS_LERP_DURATION: float = 0.4
const PROGRESS_LERP_MIN_DURATION: float = 0.12
const PROGRESS_THICKEN_STEP: float = 4.0
const PROGRESS_THICKEN_CAP: float = 18.0
const PROGRESS_THICKEN_GROW_DURATION: float = 0.1
const PROGRESS_THICKEN_DEFLATE_DELAY: float = 0.14
const PROGRESS_THICKEN_DEFLATE_DURATION: float = 0.45
const ALMOST_THERE_THRESHOLD: float = 0.9
const RISK_PIP_COUNT: int = 5
const COMBO_BADGE_HEIGHT: int = 26
const JUICY_DANGER_MIN: float = 0.6
const JUICY_DANGER_MAX: float = 0.85
const JUICY_DANGER_SCORE_FLOOR: int = 12

# -- Top bar labels --
@onready var stage_label: Label      = $TopBar/TopBarMargin/TopBarRow/StageLabel
@onready var lives_label: Label      = $TopBar/TopBarMargin/TopBarRow/LivesLabel
@onready var gold_label: Label       = $TopBar/TopBarMargin/TopBarRow/GoldLabel
@onready var luck_label: Label       = $TopBar/TopBarMargin/TopBarRow/LuckLabel
@onready var momentum_label: Label   = $TopBar/TopBarMargin/TopBarRow/MomentumLabel
@onready var highscore_label: Label  = $TopBar/TopBarMargin/TopBarRow/HighscoreLabel

# -- Modifier row --
@onready var _modifier_title: Label = $ModifierRow/ModifierTitle
@onready var _modifier_bar: HBoxContainer = $ModifierRow/ModifierBar
@onready var _modifier_tooltip: PanelContainer = $ModifierTooltip
@onready var _modifier_tooltip_name_label: Label = $ModifierTooltip/MarginContainer/TooltipVBox/TooltipNameLabel
@onready var _modifier_tooltip_desc_label: Label = $ModifierTooltip/MarginContainer/TooltipVBox/TooltipDescLabel

# -- Score row --
@onready var turn_score_label: Label   = $ScoreRow/TurnScorePanel/TurnScoreMargin/TurnScoreVBox/TurnScoreLabel
@onready var score_label: Label        = $ScoreRow/TurnScorePanel/TurnScoreMargin/TurnScoreVBox/ScoreLabel
@onready var target_label: Label       = $ScoreRow/ProgressPanel/ProgressMargin/ProgressVBox/TargetLabel
@onready var progress_bar: ProgressBar = $ScoreRow/ProgressPanel/ProgressMargin/ProgressVBox/ProgressContentRow/ProgressBar
@onready var progress_hint_label: Label = $ScoreRow/ProgressPanel/ProgressMargin/ProgressVBox/ProgressHintLabel
@onready var _streak_slot: Control = $ScoreRow/ProgressPanel/ProgressMargin/ProgressVBox/ProgressContentRow/StreakSlot

# -- Info row --
@onready var stop_label: Label            = $InfoRow/RiskColumn/StopLabel
@onready var _risk_meta_label: Label = $InfoRow/RiskColumn/RiskMetaLabel
@onready var _contract_label: Label = $InfoRow/RiskColumn/ContractLabel
@onready var _risk_meter: PanelContainer = $InfoRow/RiskColumn/RiskMeter
@onready var _risk_percent_label: Label = $InfoRow/RiskColumn/RiskMeter/RiskMeterMargin/RiskMeterRow/RiskPercentLabel
@onready var _risk_container: HBoxContainer = $InfoRow/RiskColumn/RiskMeter/RiskMeterMargin/RiskMeterRow/RiskContainer
@onready var _risk_tooltip: PanelContainer = $RiskTooltip
@onready var _risk_tooltip_label: Label = $RiskTooltip/MarginContainer/RiskTooltipLabel

# -- Combo row --
@onready var _combo_container: HFlowContainer = $ComboRow/ComboContainer

# -- Status --
@onready var status_label: Label = $StatusLabel

# -- Panel refs for styling --
@onready var _top_bar: PanelContainer        = $TopBar
@onready var _turn_score_panel: PanelContainer = $ScoreRow/TurnScorePanel
@onready var _progress_panel: PanelContainer   = $ScoreRow/ProgressPanel

var _score_tween: Tween = null
var _progress_tween: Tween = null
var _progress_pulse_tween: Tween = null
var _progress_hit_tween: Tween = null
var _progress_thickness_tween: Tween = null
var _combo_flash_tween: Tween = null
var _gold_tween: Tween = null
var _displayed_gold: int = -1
var _risk_pips: Array[Label] = []
var _modifier_badges: Array[PanelContainer] = []
var _last_modifier_types: Array[int] = []
var _combo_badges_by_id: Dictionary = {}
var _risk_tooltip_text: String = ""
var _progress_bar_base_size: Vector2 = Vector2.ZERO
var _progress_bar_thickness_bonus: float = 0.0
var _score_feedback_active: bool = false
var _score_feedback_is_reroll: bool = false
var _score_feedback_display_total: int = 0
var _score_feedback_pending_total: int = -1
var _last_bust_odds: float = 0.0
var _held_stop_count: int = 0
var _near_death_banks: int = 0
var _contract_progress_service: RefCounted = null


func _ready() -> void:
	_create_risk_pips()
	_cache_modifier_badges()
	_apply_theme_styling()
	_contract_progress_service = ContractProgressServiceScript.new()
	_progress_bar_base_size = progress_bar.custom_minimum_size
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.luck_changed.connect(_on_luck_changed)
	GameManager.momentum_changed.connect(_on_momentum_changed)
	GameManager.held_stops_changed.connect(_on_held_stops_changed)
	GameManager.near_death_banked.connect(_on_near_death_banked)
	GameManager.loop_contract_changed.connect(_on_loop_contract_changed)
	GameManager.loop_contract_progress_changed.connect(_on_loop_contract_progress_changed)
	GameManager.run_mode_changed.connect(_on_run_mode_changed)
	GameManager.stage_advanced.connect(_on_stage_advanced)
	GameManager.run_ended.connect(_on_run_ended)
	GameManager.stage_cleared.connect(_on_stage_cleared)
	GameManager.loop_advanced.connect(_on_loop_advanced)
	SaveManager.highscore_changed.connect(_on_highscore_changed)
	_on_score_changed(GameManager.total_score)
	_on_lives_changed(GameManager.lives)
	_on_gold_changed(GameManager.gold)
	_refresh_luck_display()
	_refresh_momentum_display()
	_held_stop_count = GameManager.held_stop_count
	_near_death_banks = GameManager.near_death_banks_this_stage
	_refresh_stage_display()
	_refresh_modifier_display()
	_refresh_contract_display()
	set_active_combos([])
	_refresh_progress_display()
	_risk_meter.mouse_entered.connect(_on_risk_meter_mouse_entered)
	_risk_meter.mouse_exited.connect(_on_risk_meter_mouse_exited)
	highscore_label.text = "HI: %d" % SaveManager.get_mode_highscore(int(GameManager.run_mode))
	_score_feedback_display_total = GameManager.total_score


# ---------------------------------------------------------------------------
# Theme Styling
# ---------------------------------------------------------------------------

func _apply_theme_styling() -> void:
	# Top bar panel
	_top_bar.add_theme_stylebox_override("panel",
		_UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_CARD))
	stage_label.add_theme_font_override("font", _UITheme.font_display())
	stage_label.add_theme_font_size_override("font_size", 12)
	stage_label.add_theme_color_override("font_color", _UITheme.ACTION_CYAN)
	lives_label.add_theme_font_size_override("font_size", 20)
	lives_label.add_theme_color_override("font_color", _UITheme.DANGER_RED)
	gold_label.add_theme_font_override("font", _UITheme.font_stats())
	gold_label.add_theme_font_size_override("font_size", 20)
	gold_label.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)
	highscore_label.add_theme_font_size_override("font_size", 16)
	highscore_label.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)

	# Modifier row + tooltip
	_modifier_title.add_theme_font_override("font", _UITheme.font_display())
	_modifier_title.add_theme_font_size_override("font_size", 10)
	_modifier_title.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)
	_modifier_tooltip.add_theme_stylebox_override("panel",
		_UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_CARD, _UITheme.ACTION_CYAN, 1))
	_modifier_tooltip_name_label.add_theme_font_override("font", _UITheme.font_display())
	_modifier_tooltip_name_label.add_theme_font_size_override("font_size", 10)
	_modifier_tooltip_name_label.add_theme_color_override("font_color", _UITheme.ACTION_CYAN)
	_modifier_tooltip_desc_label.add_theme_font_override("font", _UITheme.font_body())
	_modifier_tooltip_desc_label.add_theme_font_size_override("font_size", 14)
	_modifier_tooltip_desc_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)

	# Turn score panel (HERO element)
	_turn_score_panel.add_theme_stylebox_override("panel",
		_UITheme.make_panel_stylebox(_UITheme.ELEVATED, _UITheme.CORNER_RADIUS_CARD, _UITheme.SCORE_GOLD, 2))
	turn_score_label.add_theme_font_override("font", _UITheme.font_stats())
	turn_score_label.add_theme_font_size_override("font_size", 40)
	turn_score_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)
	score_label.add_theme_font_override("font", _UITheme.font_stats())
	score_label.add_theme_font_size_override("font_size", 18)
	score_label.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)

	# Progress panel
	_progress_panel.add_theme_stylebox_override("panel",
		_UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_CARD))
	target_label.add_theme_font_override("font", _UITheme.font_stats())
	target_label.add_theme_font_size_override("font_size", 18)
	progress_hint_label.add_theme_font_size_override("font_size", 16)
	progress_hint_label.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)

	# Info row
	stop_label.add_theme_font_size_override("font_size", 18)
	_risk_meta_label.add_theme_font_override("font", _UITheme.font_mono())
	_risk_meta_label.add_theme_font_size_override("font_size", 11)
	_risk_meta_label.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)
	_contract_label.add_theme_font_override("font", _UITheme.font_mono())
	_contract_label.add_theme_font_size_override("font_size", 11)
	_contract_label.add_theme_color_override("font_color", _UITheme.ACTION_CYAN)
	_risk_meter.add_theme_stylebox_override("panel",
		_UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_BADGE, _UITheme.PANEL_SURFACE, 0))
	_risk_percent_label.add_theme_font_override("font", _UITheme.font_display())
	_risk_percent_label.add_theme_font_size_override("font_size", 10)
	_risk_percent_label.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)
	_risk_tooltip.add_theme_stylebox_override("panel",
		_UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_CARD, _UITheme.ACTION_CYAN, 1))
	_risk_tooltip_label.add_theme_font_override("font", _UITheme.font_body())
	_risk_tooltip_label.add_theme_font_size_override("font_size", 13)
	_risk_tooltip_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)

	# Status
	status_label.add_theme_font_size_override("font_size", 18)


func _create_risk_pips() -> void:
	for _i: int in RISK_PIP_COUNT:
		var pip := Label.new()
		pip.text = "○"
		pip.add_theme_font_size_override("font_size", 16)
		pip.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)
		_risk_container.add_child(pip)
		_risk_pips.append(pip)


func _cache_modifier_badges() -> void:
	_modifier_badges.clear()
	for child: Node in _modifier_bar.get_children():
		var badge: PanelContainer = child as PanelContainer
		if badge == null or not badge.has_method("setup_modifier"):
			continue
		badge.tooltip_requested.connect(_on_modifier_badge_tooltip_requested)
		badge.tooltip_hidden.connect(_on_modifier_badge_tooltip_hidden)
		_modifier_badges.append(badge)


# ---------------------------------------------------------------------------
# Public API — called by RollPhase to push turn-local info
# ---------------------------------------------------------------------------

func update_turn(
	turn_score: int,
	stop_count: int,
	bust_threshold: int,
	shield_count: int = 0,
	_reroll_count: int = 0,
	bust_odds: float = 0.0,
	risk_details: String = "",
	reroll_ev: float = 0.0
) -> void:
	turn_score_label.text = "+%d" % turn_score
	var stop_text: String = "STOP: %d/%d" % [stop_count, bust_threshold]
	if shield_count > 0:
		stop_text += " [%s×%d]" % [_UITheme.GLYPH_SHIELD, shield_count]
	stop_label.text = stop_text
	stop_label.modulate = _UITheme.DANGER_RED if stop_count > 0 else Color.WHITE
	_last_bust_odds = bust_odds
	var juicy_danger: bool = _is_juicy_danger(stop_count, bust_threshold, bust_odds, turn_score)
	_update_risk_meter(bust_odds, risk_details, juicy_danger)
	_refresh_risk_meta(stop_count, bust_threshold, shield_count, reroll_ev, juicy_danger)
	_refresh_modifier_display()

func show_status(message: String, colour: Color = Color.WHITE) -> void:
	status_label.text     = message
	status_label.modulate = colour


func attach_streak_display(display: Control) -> void:
	if display == null or _streak_slot == null:
		return
	if display.get_parent() != null:
		display.get_parent().remove_child(display)
	_streak_slot.add_child(display)
	if display.has_method("set_embedded_layout"):
		display.call("set_embedded_layout")


func flash_combo(combo_name: String, colour: Color, combo_id: String = "") -> void:
	show_status("COMBO: %s!" % combo_name, colour)
	status_label.pivot_offset = status_label.size * 0.5
	if _combo_flash_tween != null and _combo_flash_tween.is_valid():
		_combo_flash_tween.kill()
	status_label.scale = Vector2.ONE
	_combo_flash_tween = create_tween()
	_combo_flash_tween.tween_property(status_label, "scale", Vector2(1.1, 1.1), 0.12)
	_combo_flash_tween.tween_property(status_label, "scale", Vector2.ONE, 0.18)
	if not combo_id.is_empty():
		_pulse_combo_badge(combo_id)


func set_active_combos(combos: Array[RollCombo]) -> void:
	for child: Node in _combo_container.get_children():
		_combo_container.remove_child(child)
		child.queue_free()
	_combo_badges_by_id.clear()

	for combo: RollCombo in combos:
		if combo == null or combo.combo_id.is_empty():
			continue
		var badge: PanelContainer = _build_combo_badge(combo)
		_combo_container.add_child(badge)
		_combo_badges_by_id[combo.combo_id] = badge


func _build_combo_badge(combo: RollCombo) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(80, COMBO_BADGE_HEIGHT)
	badge.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(
			Color(combo.flash_color.r, combo.flash_color.g, combo.flash_color.b, 0.3),
			_UITheme.CORNER_RADIUS_BADGE,
			combo.flash_color,
			1
		)
	)
	badge.pivot_offset = Vector2(40, COMBO_BADGE_HEIGHT * 0.5)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	badge.add_child(margin)

	var name_label := Label.new()
	name_label.text = combo.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", _UITheme.font_mono())
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)
	margin.add_child(name_label)

	return badge


func _pulse_combo_badge(combo_id: String) -> void:
	if not _combo_badges_by_id.has(combo_id):
		return
	var badge: PanelContainer = _combo_badges_by_id[combo_id] as PanelContainer
	if badge == null:
		return
	badge.scale = Vector2.ONE
	var tween: Tween = create_tween()
	tween.tween_property(badge, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(badge, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func animate_score_count(old_value: int, new_value: int) -> void:
	_animate_score_label_between(old_value, new_value, SCORE_COUNT_DURATION)


func begin_score_feedback(start_total: int, final_total: int, is_reroll_bank: bool) -> void:
	_score_feedback_active = true
	_score_feedback_is_reroll = is_reroll_bank
	_score_feedback_display_total = start_total
	_score_feedback_pending_total = final_total
	_progress_bar_thickness_bonus = 0.0
	_stop_progress_tween()
	_stop_progress_thickness_tween()
	_set_total_score_label(float(start_total))
	_set_progress_bar_value(_score_to_progress_value(start_total))
	_set_progress_bar_thickness(_progress_bar_base_size.y)


func animate_score_transfer(source_global_position: Vector2, score_value: int, old_total: int, new_total: int, popup_color: Color = Color.TRANSPARENT) -> void:
	if not _score_feedback_active:
		begin_score_feedback(old_total, new_total, false)
	if score_value <= 0:
		_apply_score_feedback_step(old_total, new_total, 0)
		return
	var transfer_label := Label.new()
	transfer_label.text = "+%d" % score_value
	transfer_label.top_level = true
	transfer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transfer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	transfer_label.size = Vector2(96, 28)
	transfer_label.pivot_offset = transfer_label.size * 0.5
	transfer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transfer_label.add_theme_font_override("font", _UITheme.font_stats())
	transfer_label.add_theme_font_size_override("font_size", 20)
	var resolved_color: Color = popup_color if popup_color != Color.TRANSPARENT else _UITheme.SCORE_GOLD
	transfer_label.add_theme_color_override("font_color", resolved_color)
	transfer_label.add_theme_color_override("font_outline_color", Color("#05050A"))
	transfer_label.add_theme_constant_override("outline_size", 5)
	add_child(transfer_label)
	var start_position: Vector2 = source_global_position + Vector2(0.0, -42.0)
	var end_position: Vector2 = _get_progress_hit_position(_score_to_progress_value(new_total)) + Vector2(0.0, -8.0)
	var mid_position: Vector2 = start_position.lerp(end_position, 0.55) + Vector2(-18.0, -SCORE_TRANSFER_ARC_HEIGHT)
	transfer_label.global_position = start_position - transfer_label.pivot_offset
	transfer_label.scale = Vector2(0.8, 0.8)
	var tween: Tween = transfer_label.create_tween()
	tween.tween_property(transfer_label, "global_position", mid_position - transfer_label.pivot_offset, SCORE_TRANSFER_DURATION * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(transfer_label, "scale", Vector2(1.0, 1.0), SCORE_TRANSFER_DURATION * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(transfer_label, "global_position", end_position - transfer_label.pivot_offset, SCORE_TRANSFER_DURATION * 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(transfer_label, "scale", Vector2(0.78, 0.78), SCORE_TRANSFER_DURATION * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(transfer_label, "modulate:a", 0.0, SCORE_TRANSFER_DURATION * 0.35).set_delay(SCORE_TRANSFER_DURATION * 0.65)
	tween.tween_callback(_apply_score_feedback_step.bind(old_total, new_total, score_value))
	tween.tween_callback(transfer_label.queue_free)


func finish_score_feedback() -> void:
	if not _score_feedback_active:
		return
	_score_feedback_active = false
	if _score_feedback_pending_total > _score_feedback_display_total:
		_animate_score_label_between(_score_feedback_display_total, _score_feedback_pending_total, SCORE_STEP_DURATION)
		_animate_progress_bar_to(_score_to_progress_value(_score_feedback_pending_total), SCORE_STEP_DURATION)
		_score_feedback_display_total = _score_feedback_pending_total
	_schedule_progress_deflate()
	_score_feedback_is_reroll = false


func reset_score_feedback_visuals(animated: bool = true) -> void:
	_score_feedback_active = false
	_score_feedback_is_reroll = false
	_score_feedback_pending_total = -1
	_stop_progress_tween()
	if animated and progress_bar.custom_minimum_size.y > _progress_bar_base_size.y:
		_schedule_progress_deflate()
	else:
		_stop_progress_thickness_tween()
		_progress_bar_thickness_bonus = 0.0
		_set_progress_bar_thickness(_progress_bar_base_size.y)
		_restore_progress_panel_style()


func get_progress_bar_current_height() -> float:
	return progress_bar.custom_minimum_size.y


func is_score_feedback_active() -> bool:
	return _score_feedback_active


func _animate_score_label_between(old_value: int, new_value: int, duration: float) -> void:
	if _score_tween and _score_tween.is_valid():
		_score_tween.kill()
	_score_tween = create_tween()
	_score_tween.tween_method(
		_set_total_score_label,
		float(old_value), float(new_value), duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _set_total_score_label(value: float) -> void:
	score_label.text = "Total: %d" % int(value)


func show_floating_gold(amount: int) -> void:
	var lbl: Label = Label.new()
	lbl.text = "+%dg" % amount
	lbl.add_theme_font_override("font", _UITheme.font_stats())
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.top_level = true
	var start_pos: Vector2 = score_label.global_position + Vector2(score_label.size.x * 0.5 - 30, 0)
	lbl.global_position = start_pos
	add_child(lbl)
	var tween: Tween = lbl.create_tween()
	tween.tween_property(lbl, "global_position:y", start_pos.y - 50.0, GOLD_FLOAT_DURATION).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, GOLD_FLOAT_DURATION).set_ease(Tween.EASE_IN).set_delay(0.3)
	tween.tween_callback(lbl.queue_free)


# ---------------------------------------------------------------------------
# Risk Pips
# ---------------------------------------------------------------------------

func _update_risk_meter(bust_odds: float, details: String, juicy_danger: bool = false) -> void:
	var ratio: float = clampf(bust_odds, 0.0, 1.0)
	var percent: int = int(round(ratio * 100.0))
	_risk_percent_label.text = "RISK %d%%" % percent
	_risk_tooltip_text = details
	if _risk_tooltip.visible:
		_risk_tooltip_label.text = _risk_tooltip_text
		_position_risk_tooltip()
	_update_risk_pips(ratio)
	var border_color: Color = _UITheme.SUCCESS_GREEN
	var border_width: int = 1
	if juicy_danger:
		border_color = _UITheme.EXPLOSION_ORANGE
		border_width = 2
	if ratio >= 0.66:
		border_color = _UITheme.DANGER_RED
	elif ratio >= 0.33:
		border_color = _UITheme.SCORE_GOLD
	_risk_meter.add_theme_stylebox_override("panel",
		_UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_BADGE, border_color, border_width))


func _refresh_risk_meta(
	stop_count: int,
	bust_threshold: int,
	shield_count: int,
	reroll_ev: float,
	juicy_danger: bool
) -> void:
	var details: Array[String] = []
	if juicy_danger:
		details.append("JUICY")
	if shield_count > 0:
		details.append("Shield %d" % shield_count)
	if _held_stop_count > 0:
		details.append("Held %d" % _held_stop_count)
	if _near_death_banks > 0:
		details.append("Near-Death x%d" % _near_death_banks)
	var ev_prefix: String = "+" if reroll_ev >= 0.0 else ""
	details.append("EV %s%.1f" % [ev_prefix, reroll_ev])
	_risk_meta_label.text = " | ".join(details)
	if juicy_danger:
		_risk_meta_label.modulate = _UITheme.EXPLOSION_ORANGE
	elif stop_count >= bust_threshold - 1:
		_risk_meta_label.modulate = _UITheme.SCORE_GOLD
	else:
		_risk_meta_label.modulate = _UITheme.MUTED_TEXT


func _refresh_contract_display() -> void:
	if GameManager.active_loop_contract_id.is_empty():
		_contract_label.visible = false
		_contract_label.text = ""
		return
	var contract: LoopContractData = LoopContractCatalogScript.get_by_id(GameManager.active_loop_contract_id)
	if contract == null:
		_contract_label.visible = false
		_contract_label.text = ""
		return
	_contract_label.visible = true
	if _contract_progress_service == null:
		_contract_label.text = contract.display_name
		return
	_contract_label.text = _contract_progress_service.format_progress_text(
		GameManager.active_loop_contract_id,
		GameManager.active_loop_contract_progress
	)


func _is_juicy_danger(stop_count: int, bust_threshold: int, bust_odds: float, turn_score: int) -> bool:
	var one_from_bust: bool = bust_threshold > 1 and stop_count == bust_threshold - 1
	return (
		bust_odds >= JUICY_DANGER_MIN and bust_odds <= JUICY_DANGER_MAX
		or (one_from_bust and turn_score >= JUICY_DANGER_SCORE_FLOOR)
	)


func _update_risk_pips(risk_ratio: float) -> void:
	var filled: int = ceili(clampf(risk_ratio, 0.0, 1.0) * float(RISK_PIP_COUNT))

	var pip_color: Color = _UITheme.SUCCESS_GREEN
	if filled >= 4:
		pip_color = _UITheme.DANGER_RED
	elif filled >= 3:
		pip_color = _UITheme.EXPLOSION_ORANGE
	elif filled >= 2:
		pip_color = _UITheme.SCORE_GOLD

	for i: int in RISK_PIP_COUNT:
		_risk_pips[i].text = "●" if i < filled else "○"
		_risk_pips[i].add_theme_color_override("font_color", pip_color if i < filled else _UITheme.MUTED_TEXT)


func _on_risk_meter_mouse_entered() -> void:
	if _risk_tooltip_text.is_empty():
		return
	_risk_tooltip_label.text = _risk_tooltip_text
	_risk_tooltip.visible = true
	_position_risk_tooltip()


func _on_risk_meter_mouse_exited() -> void:
	_risk_tooltip.visible = false


func _position_risk_tooltip() -> void:
	if not _risk_tooltip.visible:
		return
	var tooltip_size: Vector2 = _risk_tooltip.get_combined_minimum_size()
	var viewport_size: Vector2 = get_viewport_rect().size
	var meter_rect: Rect2 = Rect2(_risk_meter.global_position, _risk_meter.size)
	var pad: float = 8.0
	var x: float = clampf(
		meter_rect.position.x + meter_rect.size.x * 0.5 - tooltip_size.x * 0.5,
		pad,
		viewport_size.x - tooltip_size.x - pad
	)
	var above_y: float = meter_rect.position.y - tooltip_size.y - 10.0
	var below_y: float = meter_rect.position.y + meter_rect.size.y + 10.0
	var y: float = above_y
	if y < pad:
		y = minf(below_y, viewport_size.y - tooltip_size.y - pad)
	_risk_tooltip.global_position = Vector2(x, y)


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_score_changed(new_total: int) -> void:
	if _score_feedback_active:
		_score_feedback_pending_total = new_total
		return
	_score_feedback_display_total = new_total
	score_label.text = "Total: %d" % new_total
	_refresh_progress_display()

func _on_lives_changed(new_lives: int) -> void:
	var hearts: String = ""
	for _i: int in new_lives:
		hearts += _UITheme.GLYPH_HEART
	lives_label.text = hearts if new_lives > 0 else _UITheme.GLYPH_STOP

func _on_gold_changed(new_gold: int) -> void:
	if _gold_tween and _gold_tween.is_valid():
		_gold_tween.kill()
	var from_val: int = _displayed_gold
	_displayed_gold = new_gold
	# Skip animation on first call or when value hasn't changed.
	if from_val < 0 or from_val == new_gold:
		gold_label.text = "%s %d" % [_UITheme.GLYPH_GOLD, new_gold]
		return
	_gold_tween = create_tween()
	_gold_tween.tween_method(
		_set_gold_label_value,
		float(from_val), float(new_gold), GOLD_COUNT_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_held_stops_changed(new_total: int) -> void:
	_held_stop_count = new_total


func _on_near_death_banked(_effective_stops: int, _threshold: int) -> void:
	_near_death_banks = GameManager.near_death_banks_this_stage


func _on_loop_contract_changed(_active_contract_id: String) -> void:
	_refresh_contract_display()


func _on_loop_contract_progress_changed(_progress: Dictionary) -> void:
	_refresh_contract_display()


func _set_gold_label_value(value: float) -> void:
	gold_label.text = "%s %d" % [_UITheme.GLYPH_GOLD, int(value)]


func _on_luck_changed(_new_luck: int) -> void:
	_refresh_luck_display()


func _refresh_luck_display() -> void:
	if GameManager.luck > 0:
		luck_label.text = "🍀%d" % GameManager.luck
		luck_label.visible = true
	else:
		luck_label.text = ""
		luck_label.visible = false


func _on_momentum_changed(_new_momentum: int) -> void:
	_refresh_momentum_display()


func _refresh_momentum_display() -> void:
	if GameManager.momentum > 0:
		var mult: float = 1.0 + float(GameManager.momentum) * 0.05
		momentum_label.text = "⚡x%.2f" % mult
		momentum_label.modulate = Color(1.0, 0.9, 0.3)
		momentum_label.visible = true
	else:
		momentum_label.text = ""
		momentum_label.visible = false


func _on_stage_advanced(_new_stage: int) -> void:
	_near_death_banks = GameManager.near_death_banks_this_stage
	_refresh_stage_display()
	_refresh_progress_display()
	_refresh_contract_display()

func _on_run_ended() -> void:
	show_status("RUN OVER — out of lives!", _UITheme.DANGER_RED)

func _on_stage_cleared() -> void:
	show_status("STAGE CLEARED!", _UITheme.SUCCESS_GREEN)

func _on_loop_advanced(_new_loop: int) -> void:
	_near_death_banks = GameManager.near_death_banks_this_stage
	_refresh_stage_display()
	_refresh_progress_display()
	_refresh_contract_display()

func _on_highscore_changed(new_highscore: int) -> void:
	highscore_label.text = "HI: %d" % new_highscore


func _on_run_mode_changed(_new_mode: int) -> void:
	highscore_label.text = "HI: %d" % SaveManager.get_mode_highscore(int(GameManager.run_mode))
	_refresh_stage_display()


func _refresh_stage_display() -> void:
	var loop_text: String = " L%d" % GameManager.current_loop if GameManager.current_loop > 1 else ""
	var row_count: int = StageMapDataScript.ROWS_PER_LOOP if GameManager.stage_map else GameManager.get_stages_in_current_loop()
	var row_display: int = mini(GameManager.current_row + 1, row_count)
	var mode_text: String = " [%s]" % GameManager.get_run_mode_name().to_upper() if GameManager.run_mode == GameManager.RunMode.GAUNTLET else ""
	stage_label.text = "ROW %d/%d%s%s" % [row_display, row_count, loop_text, mode_text]
	target_label.text = "Target: %d" % GameManager.stage_target_score


func _refresh_progress_display() -> void:
	var target_value: float = _score_to_progress_value(_get_progress_source_total())
	if is_equal_approx(progress_bar.value, target_value):
		_set_progress_bar_value(target_value)
		return
	if target_value < progress_bar.value:
		_stop_progress_tween()
		_set_progress_bar_value(target_value)
		return
	_animate_progress_bar_to(target_value)


func _animate_progress_bar_to(target_value: float, duration_override: float = -1.0) -> void:
	_stop_progress_tween()
	var delta: float = absf(target_value - progress_bar.value)
	var duration: float = duration_override if duration_override >= 0.0 else lerpf(PROGRESS_LERP_MIN_DURATION, PROGRESS_LERP_DURATION, delta / 100.0)
	_progress_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_progress_tween.tween_method(_set_progress_bar_value, progress_bar.value, target_value, duration)
	_progress_tween.finished.connect(_clear_progress_tween)


func _clear_progress_tween() -> void:
	_progress_tween = null


func _stop_progress_tween() -> void:
	if _progress_tween != null and _progress_tween.is_valid():
		_progress_tween.kill()
	_progress_tween = null


func _set_progress_bar_value(value: float) -> void:
	progress_bar.value = value
	_update_progress_state(value / 100.0)


func _get_progress_source_total() -> int:
	return _score_feedback_display_total if _score_feedback_active else GameManager.total_score


func _score_to_progress_value(score_total: int) -> float:
	var target: int = maxi(1, GameManager.stage_target_score)
	return clampf(float(score_total) / float(target), 0.0, 1.0) * 100.0


func _get_progress_hit_position(progress_value: float) -> Vector2:
	var ratio: float = clampf(progress_value / 100.0, 0.06, 1.0)
	var fill_width: float = maxf(progress_bar.size.x, progress_bar.custom_minimum_size.x)
	return progress_bar.global_position + Vector2(fill_width * ratio, progress_bar.size.y * 0.5)


func _apply_score_feedback_step(old_total: int, new_total: int, score_value: int) -> void:
	_score_feedback_display_total = new_total
	_score_feedback_pending_total = maxi(_score_feedback_pending_total, new_total)
	_animate_score_label_between(old_total, new_total, SCORE_STEP_DURATION)
	_animate_progress_bar_to(_score_to_progress_value(new_total), SCORE_STEP_DURATION)
	_play_progress_hit(score_value)


func _play_progress_hit(score_value: int) -> void:
	if _progress_hit_tween != null and _progress_hit_tween.is_valid():
		_progress_hit_tween.kill()
	var hit_boost: float = minf(1.0, float(maxi(score_value, 1)) / 18.0)
	progress_bar.modulate = Color.WHITE
	_progress_hit_tween = create_tween()
	_progress_hit_tween.tween_property(progress_bar, "modulate", Color(1.0, 0.92 + hit_boost * 0.04, 0.7 + hit_boost * 0.1), 0.08)
	_progress_hit_tween.tween_property(progress_bar, "modulate", Color.WHITE, 0.16)
	var border_width: int = 1 + int(round(hit_boost * 2.0))
	_progress_panel.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_CARD, _UITheme.SCORE_GOLD, border_width)
	)
	if _score_feedback_is_reroll:
		var growth: float = minf(PROGRESS_THICKEN_STEP + float(score_value) * 0.08, PROGRESS_THICKEN_STEP * 2.0)
		_progress_bar_thickness_bonus = minf(_progress_bar_thickness_bonus + growth, PROGRESS_THICKEN_CAP)
		_animate_progress_bar_thickness(_progress_bar_base_size.y + _progress_bar_thickness_bonus, PROGRESS_THICKEN_GROW_DURATION)


func _animate_progress_bar_thickness(target_height: float, duration: float) -> void:
	_stop_progress_thickness_tween()
	var start_height: float = progress_bar.custom_minimum_size.y
	_progress_thickness_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_progress_thickness_tween.tween_method(_set_progress_bar_thickness, start_height, target_height, duration)


func _set_progress_bar_thickness(height: float) -> void:
	progress_bar.custom_minimum_size = Vector2(_progress_bar_base_size.x, height)


func _schedule_progress_deflate() -> void:
	if progress_bar.custom_minimum_size.y <= _progress_bar_base_size.y:
		_progress_bar_thickness_bonus = 0.0
		_restore_progress_panel_style()
		return
	if not _score_feedback_is_reroll and _progress_bar_thickness_bonus <= 0.0:
		_restore_progress_panel_style()
		return
	_stop_progress_thickness_tween()
	var current_height: float = progress_bar.custom_minimum_size.y
	_progress_thickness_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_progress_thickness_tween.tween_interval(PROGRESS_THICKEN_DEFLATE_DELAY)
	_progress_thickness_tween.tween_method(_set_progress_bar_thickness, current_height, _progress_bar_base_size.y, PROGRESS_THICKEN_DEFLATE_DURATION)
	_progress_thickness_tween.finished.connect(_on_progress_deflate_finished)


func _on_progress_deflate_finished() -> void:
	_progress_bar_thickness_bonus = 0.0
	_restore_progress_panel_style()
	_stop_progress_thickness_tween()


func _restore_progress_panel_style() -> void:
	if _progress_pulse_tween != null and _progress_pulse_tween.is_valid():
		return
	_progress_panel.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_CARD)
	)


func _stop_progress_thickness_tween() -> void:
	if _progress_thickness_tween != null and _progress_thickness_tween.is_valid():
		_progress_thickness_tween.kill()
	_progress_thickness_tween = null


func _update_progress_state(ratio: float) -> void:
	var almost_there: bool = ratio >= ALMOST_THERE_THRESHOLD and ratio < 1.0
	progress_hint_label.text = "ALMOST THERE" if almost_there else ""
	if almost_there:
		_start_progress_pulse()
	else:
		_stop_progress_pulse()


func _start_progress_pulse() -> void:
	if _progress_pulse_tween != null and _progress_pulse_tween.is_valid():
		return
	progress_bar.modulate = Color.WHITE
	_progress_pulse_tween = create_tween().set_loops()
	_progress_pulse_tween.tween_property(progress_bar, "modulate", Color(1.0, 0.88, 0.6), 0.25)
	_progress_pulse_tween.tween_property(progress_bar, "modulate", Color.WHITE, 0.25)
	# Add glow border on progress panel
	var glow_style: StyleBoxFlat = _UITheme.make_panel_stylebox(
		_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_CARD, _UITheme.SCORE_GOLD, 2
	)
	_progress_panel.add_theme_stylebox_override("panel", glow_style)


func _stop_progress_pulse() -> void:
	if _progress_pulse_tween != null and _progress_pulse_tween.is_valid():
		_progress_pulse_tween.kill()
	_progress_pulse_tween = null
	progress_bar.modulate = Color.WHITE
	_restore_progress_panel_style()


func _refresh_modifier_display() -> void:
	var active: Array[RunModifier] = GameManager.active_modifiers
	var current_types: Array[int] = []
	for mod: RunModifier in active:
		current_types.append(int(mod.modifier_type))

	# Ensure we have enough badge slots if max changes in future.
	while _modifier_badges.size() < GameManager.MAX_MODIFIERS:
		var badge := _ModifierBadgeScene.instantiate() as PanelContainer
		_modifier_bar.add_child(badge)
		badge.tooltip_requested.connect(_on_modifier_badge_tooltip_requested)
		badge.tooltip_hidden.connect(_on_modifier_badge_tooltip_hidden)
		_modifier_badges.append(badge)

	for i: int in _modifier_badges.size():
		if i < active.size():
			var modifier: RunModifier = active[i]
			_modifier_badges[i].setup_modifier(modifier)
			if int(modifier.modifier_type) not in _last_modifier_types:
				_animate_badge_acquire(_modifier_badges[i])
		else:
			_modifier_badges[i].setup_empty()

	_last_modifier_types = current_types
	_on_modifier_badge_tooltip_hidden()


func _animate_badge_acquire(badge: PanelContainer) -> void:
	badge.scale = Vector2(1.25, 1.25)
	badge.modulate = Color(1, 1, 1, 0.75)
	var tween: Tween = create_tween()
	tween.tween_property(badge, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(badge, "modulate", Color.WHITE, 0.2)


func _on_modifier_badge_tooltip_requested(modifier: RunModifier, badge_rect: Rect2) -> void:
	_modifier_tooltip_name_label.text = modifier.modifier_name
	_modifier_tooltip_name_label.add_theme_color_override("font_color", modifier.get_badge_color())
	_modifier_tooltip_desc_label.text = modifier.description
	_modifier_tooltip.visible = true
	var tooltip_size: Vector2 = _modifier_tooltip.get_combined_minimum_size()
	var viewport_size: Vector2 = get_viewport_rect().size
	var pad: float = 8.0
	var x: float = clampf(
		badge_rect.position.x + badge_rect.size.x * 0.5 - tooltip_size.x * 0.5,
		pad,
		viewport_size.x - tooltip_size.x - pad
	)
	var above_y: float = badge_rect.position.y - tooltip_size.y - 10.0
	var below_y: float = badge_rect.position.y + badge_rect.size.y + 10.0
	var y: float = above_y
	if y < pad:
		y = minf(below_y, viewport_size.y - tooltip_size.y - pad)
	_modifier_tooltip.global_position = Vector2(x, y)


func _on_modifier_badge_tooltip_hidden() -> void:
	_modifier_tooltip.visible = false
