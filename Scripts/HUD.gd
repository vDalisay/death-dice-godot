class_name HUD
extends VBoxContainer
## Observes GameManager and RollPhase signals. Renders labels only — no game logic.
## Redesigned as a compact 3-zone dashboard with themed panels and risk pips.

const _UITheme := preload("res://Scripts/UITheme.gd")
const _ModifierBadgeScene: PackedScene = preload("res://Scenes/ModifierBadge.tscn")

const SCORE_COUNT_DURATION: float = 0.5
const GOLD_FLOAT_DURATION: float = 1.0
const ALMOST_THERE_THRESHOLD: float = 0.9
const RISK_PIP_COUNT: int = 5
const COMBO_BADGE_HEIGHT: int = 26

# -- Top bar labels --
@onready var stage_label: Label      = $TopBar/TopBarMargin/TopBarRow/StageLabel
@onready var lives_label: Label      = $TopBar/TopBarMargin/TopBarRow/LivesLabel
@onready var gold_label: Label       = $TopBar/TopBarMargin/TopBarRow/GoldLabel
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
@onready var progress_bar: ProgressBar = $ScoreRow/ProgressPanel/ProgressMargin/ProgressVBox/ProgressBar
@onready var progress_hint_label: Label = $ScoreRow/ProgressPanel/ProgressMargin/ProgressVBox/ProgressHintLabel

# -- Info row --
@onready var stop_label: Label            = $InfoRow/StopLabel
@onready var _risk_label: Label           = $InfoRow/RiskLabel
@onready var _risk_container: HBoxContainer = $InfoRow/RiskContainer

# -- Combo row --
@onready var _combo_label: Label = $ComboRow/ComboLabel
@onready var _combo_container: HFlowContainer = $ComboRow/ComboContainer

# -- Status --
@onready var status_label: Label = $StatusLabel

# -- Panel refs for styling --
@onready var _top_bar: PanelContainer        = $TopBar
@onready var _turn_score_panel: PanelContainer = $ScoreRow/TurnScorePanel
@onready var _progress_panel: PanelContainer   = $ScoreRow/ProgressPanel

var _score_tween: Tween = null
var _progress_pulse_tween: Tween = null
var _combo_flash_tween: Tween = null
var _risk_pips: Array[Label] = []
var _modifier_badges: Array[PanelContainer] = []
var _last_modifier_types: Array[int] = []
var _combo_badges_by_id: Dictionary = {}


func _ready() -> void:
	_create_risk_pips()
	_cache_modifier_badges()
	_apply_theme_styling()
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.stage_advanced.connect(_on_stage_advanced)
	GameManager.run_ended.connect(_on_run_ended)
	GameManager.stage_cleared.connect(_on_stage_cleared)
	GameManager.loop_advanced.connect(_on_loop_advanced)
	SaveManager.highscore_changed.connect(_on_highscore_changed)
	_on_score_changed(GameManager.total_score)
	_on_lives_changed(GameManager.lives)
	_on_gold_changed(GameManager.gold)
	_refresh_stage_display()
	_refresh_modifier_display()
	set_active_combos([])
	_refresh_progress_display()
	highscore_label.text = "HI: %d" % SaveManager.highscore


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
	_risk_label.add_theme_font_override("font", _UITheme.font_display())
	_risk_label.add_theme_font_size_override("font_size", 10)
	_risk_label.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)
	_combo_label.add_theme_font_override("font", _UITheme.font_display())
	_combo_label.add_theme_font_size_override("font_size", 10)
	_combo_label.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)

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

func update_turn(turn_score: int, stop_count: int, bust_threshold: int, shield_count: int = 0) -> void:
	turn_score_label.text = "+%d" % turn_score
	var stop_text: String = "STOP: %d/%d" % [stop_count, bust_threshold]
	if shield_count > 0:
		stop_text += " [%s×%d]" % [_UITheme.GLYPH_SHIELD, shield_count]
	stop_label.text = stop_text
	stop_label.modulate = _UITheme.DANGER_RED if stop_count > 0 else Color.WHITE
	_update_risk_pips(stop_count, bust_threshold)
	_refresh_modifier_display()

func show_status(message: String, colour: Color = Color.WHITE) -> void:
	status_label.text     = message
	status_label.modulate = colour


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
	badge.custom_minimum_size = Vector2(96, COMBO_BADGE_HEIGHT)
	badge.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(
			Color(combo.flash_color.r, combo.flash_color.g, combo.flash_color.b, 0.3),
			_UITheme.CORNER_RADIUS_BADGE,
			combo.flash_color,
			1
		)
	)
	badge.pivot_offset = Vector2(48, COMBO_BADGE_HEIGHT * 0.5)

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
	name_label.add_theme_font_size_override("font_size", 18)
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
	if _score_tween and _score_tween.is_valid():
		_score_tween.kill()
	_score_tween = create_tween()
	_score_tween.tween_method(
		func(val: float) -> void: score_label.text = "Total: %d" % int(val),
		float(old_value), float(new_value), SCORE_COUNT_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


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

func _update_risk_pips(stop_count: int, bust_threshold: int) -> void:
	var ratio: float = 0.0
	if bust_threshold > 0 and stop_count > 0:
		ratio = clampf(float(stop_count) / float(bust_threshold), 0.0, 1.0)
	var filled: int = ceili(ratio * float(RISK_PIP_COUNT))

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


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_score_changed(new_total: int) -> void:
	score_label.text = "Total: %d" % new_total
	_refresh_progress_display()

func _on_lives_changed(new_lives: int) -> void:
	var hearts: String = ""
	for _i: int in new_lives:
		hearts += _UITheme.GLYPH_HEART
	lives_label.text = hearts if new_lives > 0 else _UITheme.GLYPH_STOP

func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = "%s %d" % [_UITheme.GLYPH_GOLD, new_gold]

func _on_stage_advanced(_new_stage: int) -> void:
	_refresh_stage_display()
	_refresh_progress_display()

func _on_run_ended() -> void:
	show_status("RUN OVER — out of lives!", _UITheme.DANGER_RED)

func _on_stage_cleared() -> void:
	show_status("STAGE CLEARED!", _UITheme.SUCCESS_GREEN)

func _on_loop_advanced(_new_loop: int) -> void:
	_refresh_stage_display()
	_refresh_progress_display()

func _on_highscore_changed(new_highscore: int) -> void:
	highscore_label.text = "HI: %d" % new_highscore


func _refresh_stage_display() -> void:
	var loop_text: String = " L%d" % GameManager.current_loop if GameManager.current_loop > 1 else ""
	stage_label.text = "STAGE %d/%d%s" % [GameManager.current_stage, GameManager.get_stages_in_current_loop(), loop_text]
	target_label.text = "Target: %d" % GameManager.stage_target_score


func _refresh_progress_display() -> void:
	var target: int = maxi(1, GameManager.stage_target_score)
	var ratio: float = clampf(float(GameManager.total_score) / float(target), 0.0, 1.0)
	progress_bar.value = ratio * 100.0
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


func _stop_progress_pulse() -> void:
	if _progress_pulse_tween != null and _progress_pulse_tween.is_valid():
		_progress_pulse_tween.kill()
	_progress_pulse_tween = null
	progress_bar.modulate = Color.WHITE


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
