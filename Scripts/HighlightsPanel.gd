class_name HighlightsPanel
extends PanelContainer
## End-of-run highlights reel — dark modal with card-reveal and counting animations.

signal closed()

const _UITheme := preload("res://Scripts/UITheme.gd")
const PRESTIGE_PANEL_SCENE_PATH: String = "res://Scenes/PrestigePanel.tscn"

const CARD_WIDTH: int = 140
const CARD_HEIGHT: int = 120
const REVEAL_STAGGER: float = 0.18
const COUNT_DURATION: float = 0.4
const CARD_FADE_DURATION: float = 0.2
const CARD_SCALE_DURATION: float = 0.3
const COUNT_START_DELAY: float = 0.15
const TITLE_FONT_SIZE: int = 18
const STAT_NAME_SIZE: int = 10
const STAT_VALUE_SIZE: int = 22
const BEST_BADGE_SIZE: int = 9
const ICON_FONT_SIZE: int = 16
const DELTA_FONT_SIZE: int = 8
const CARD_MARGIN_SIZE: int = 8
const CARD_INITIAL_SCALE: Vector2 = Vector2(0.8, 0.8)
const BEST_BADGE_FADE_IN_DURATION: float = 0.15
const BEST_BADGE_PULSE_ALPHA: float = 0.6
const BEST_BADGE_PULSE_DURATION: float = 0.4

@onready var _card: PanelContainer = $CenterContainer/Card
@onready var _title_label: Label = $CenterContainer/Card/MarginContainer/Content/TitleLabel
@onready var _stat_cards: HFlowContainer = $CenterContainer/Card/MarginContainer/Content/StatCards
@onready var _close_button: Button = $CenterContainer/Card/MarginContainer/Content/CloseButton

var _stat_card_nodes: Array[_StatCardRefs] = []
var _prestige_button: Button = null


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(_on_close_pressed)
	_add_prestige_button()
	_apply_theme()


func show_highlights(run: RunSaveData, prior_bests: Dictionary) -> void:
	_build_stat_cards(run, prior_bests)
	visible = true
	_animate_reveal()


func _format_stat(stat_name: String, value: int, prior_best: int) -> String:
	if value > 0 and value >= prior_best:
		return "%s: %d  (%s NEW BEST!)" % [stat_name, value, _UITheme.GLYPH_STAR]
	if prior_best > 0:
		return "%s: %d (Best: %d)" % [stat_name, value, prior_best]
	return "%s: %d" % [stat_name, value]


func _format_delta(value: int, prior_best: int) -> String:
	if prior_best <= 0:
		return "First record"
	var delta: int = value - prior_best
	if delta > 0:
		return "+%d vs best" % delta
	if delta < 0:
		return "%d vs best" % delta
	return "Tied best"


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _apply_theme() -> void:
	add_theme_stylebox_override("panel", _UITheme.make_panel_stylebox(Color.TRANSPARENT, 0))
	_UITheme.apply_modal_panel_style(_card, _UITheme.SCORE_GOLD)
	_UITheme.apply_label_style(_title_label, _UITheme.font_display(), TITLE_FONT_SIZE, _UITheme.SCORE_GOLD)
	_UITheme.apply_label_style(_close_button, _UITheme.font_display(), 12, _UITheme.BRIGHT_TEXT)
	if _prestige_button != null:
		_UITheme.apply_label_style(_prestige_button, _UITheme.font_display(), 12, _UITheme.BRIGHT_TEXT)


## Data structure for a single stat card.
class _StatDef:
	var label_name: String
	var icon: String
	var value: int
	var is_best: bool
	var accent: Color
	var prior_best: int
	var show_delta: bool

	func _init(
		p_name: String,
		p_icon: String,
		p_value: int,
		p_is_best: bool,
		p_accent: Color,
		p_prior_best: int = 0,
		p_show_delta: bool = false
	) -> void:
		label_name = p_name
		icon = p_icon
		value = p_value
		is_best = p_is_best
		accent = p_accent
		prior_best = p_prior_best
		show_delta = p_show_delta


class _StatCardRefs:
	var card: PanelContainer
	var value_label: Label
	var best_badge: Label

	func _init(p_card: PanelContainer, p_value_label: Label, p_best_badge: Label) -> void:
		card = p_card
		value_label = p_value_label
		best_badge = p_best_badge


func _build_stat_cards(run: RunSaveData, prior_bests: Dictionary) -> void:
	# Clear previous cards.
	for child: Node in _stat_cards.get_children():
		child.queue_free()
	_stat_card_nodes.clear()

	var score_best: int = prior_bests.get("highscore", 0) as int
	var stages_best: int = prior_bests.get("best_stages", 0) as int
	var loop_best: int = prior_bests.get("best_loop", 0) as int
	var turn_best: int = prior_bests.get("best_turn", 0) as int

	var stats: Array[_StatDef] = []
	stats.append(_StatDef.new("Score", _UITheme.GLYPH_STAR, run.score,
		run.score >= score_best and run.score > 0,
		_UITheme.SCORE_GOLD, score_best, true))
	stats.append(_StatDef.new("Stages", _UITheme.GLYPH_CHECK, run.stages_cleared,
		run.stages_cleared >= stages_best and run.stages_cleared > 0,
		_UITheme.SUCCESS_GREEN, stages_best, true))
	stats.append(_StatDef.new("Loops", _UITheme.GLYPH_FIRE, run.loops_completed,
		run.loops_completed >= loop_best and run.loops_completed > 0,
		_UITheme.EXPLOSION_ORANGE, loop_best, true))
	stats.append(_StatDef.new("Best Turn", _UITheme.GLYPH_EXPLODE, run.best_turn_score,
		run.best_turn_score >= turn_best and run.best_turn_score > 0,
		_UITheme.ROSE_ACCENT, turn_best, true))
	stats.append(_StatDef.new("Busts", _UITheme.GLYPH_STOP, run.busts, false, _UITheme.DANGER_RED))
	stats.append(_StatDef.new("Skulls", _UITheme.GLYPH_STAR, run.prestige_skulls_earned, false, _UITheme.ACTION_CYAN))
	stats.append(_StatDef.new("Final Dice", _UITheme.GLYPH_DIE, run.final_dice_names.size(), false, _UITheme.ACTION_CYAN))

	for stat: _StatDef in stats:
		var refs: _StatCardRefs = _create_stat_card(stat)
		refs.card.modulate.a = 0.0
		refs.card.scale = CARD_INITIAL_SCALE
		refs.card.pivot_offset = Vector2(CARD_WIDTH * 0.5, CARD_HEIGHT * 0.5)
		_stat_cards.add_child(refs.card)
		_stat_card_nodes.append(refs)


func _create_stat_card(stat: _StatDef) -> _StatCardRefs:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.ELEVATED, _UITheme.CORNER_RADIUS_CARD, stat.accent, 1)
	)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", _UITheme.SPACE_XS)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", CARD_MARGIN_SIZE)
	margin.add_theme_constant_override("margin_right", CARD_MARGIN_SIZE)
	margin.add_theme_constant_override("margin_top", CARD_MARGIN_SIZE)
	margin.add_theme_constant_override("margin_bottom", CARD_MARGIN_SIZE)
	margin.add_child(vbox)
	card.add_child(margin)

	# Icon
	var icon_label := Label.new()
	icon_label.text = stat.icon
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_UITheme.apply_label_style(icon_label, _UITheme.font_display(), ICON_FONT_SIZE, stat.accent)
	vbox.add_child(icon_label)

	# Name
	var name_label := Label.new()
	name_label.text = stat.label_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_UITheme.apply_label_style(name_label, _UITheme.font_display(), STAT_NAME_SIZE, _UITheme.MUTED_TEXT)
	vbox.add_child(name_label)

	# Value (will be animated via counting)
	var value_label := Label.new()
	value_label.name = "ValueLabel"
	value_label.text = "0"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_UITheme.apply_label_style(value_label, _UITheme.font_stats(), STAT_VALUE_SIZE, _UITheme.BRIGHT_TEXT)
	vbox.add_child(value_label)
	# Store target value as metadata.
	value_label.set_meta("target_value", stat.value)

	if stat.show_delta:
		var delta_label := Label.new()
		delta_label.name = "DeltaLabel"
		delta_label.text = _format_delta(stat.value, stat.prior_best)
		delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_UITheme.apply_label_style(delta_label, _UITheme.font_display(), DELTA_FONT_SIZE, _UITheme.MUTED_TEXT)
		vbox.add_child(delta_label)

	# "NEW BEST!" badge (initially hidden).
	var best_badge: Label = null
	if stat.is_best:
		best_badge = Label.new()
		best_badge.name = "BestBadge"
		best_badge.text = "%s NEW BEST!" % _UITheme.GLYPH_STAR
		best_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_UITheme.apply_label_style(best_badge, _UITheme.font_display(), BEST_BADGE_SIZE, _UITheme.SCORE_GOLD)
		best_badge.modulate.a = 0.0
		vbox.add_child(best_badge)

	return _StatCardRefs.new(card, value_label, best_badge)


func _animate_reveal() -> void:
	var tween: Tween = create_tween()
	for i: int in _stat_card_nodes.size():
		var refs: _StatCardRefs = _stat_card_nodes[i]
		var card: PanelContainer = refs.card
		var delay: float = i * REVEAL_STAGGER
		tween.parallel().tween_property(card, "modulate:a", 1.0, CARD_FADE_DURATION).set_delay(delay)
		tween.parallel().tween_property(card, "scale", Vector2.ONE, CARD_SCALE_DURATION) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		# Count up the value after the card appears.
		tween.parallel().tween_callback(_count_up_card.bind(refs)).set_delay(delay + COUNT_START_DELAY)


func _count_up_card(refs: _StatCardRefs) -> void:
	var value_label: Label = refs.value_label
	if value_label == null:
		return
	var target: int = value_label.get_meta("target_value", 0) as int
	if target <= 0:
		value_label.text = str(target)
		_show_best_badge(refs)
		return
	var count_tween: Tween = create_tween()
	count_tween.tween_method(_set_stat_card_value.bind(value_label), 0.0, float(target), COUNT_DURATION)
	count_tween.tween_callback(_show_best_badge.bind(refs))


func _set_stat_card_value(value_label: Label, value: float) -> void:
	value_label.text = str(int(value))


func _show_best_badge(refs: _StatCardRefs) -> void:
	var badge: Label = refs.best_badge
	if badge == null:
		return
	var badge_tween: Tween = create_tween()
	badge_tween.tween_property(badge, "modulate:a", 1.0, BEST_BADGE_FADE_IN_DURATION)
	# Pulse glow.
	badge_tween.tween_property(badge, "modulate:a", BEST_BADGE_PULSE_ALPHA, BEST_BADGE_PULSE_DURATION)
	badge_tween.tween_property(badge, "modulate:a", 1.0, BEST_BADGE_PULSE_DURATION)


func _add_prestige_button() -> void:
	_prestige_button = Button.new()
	_prestige_button.text = "Visit Prestige Shop"
	_prestige_button.custom_minimum_size = Vector2(240, 40)
	_prestige_button.pressed.connect(_on_prestige_pressed)
	_close_button.get_parent().add_child(_prestige_button)


func _on_prestige_pressed() -> void:
	var panel_scene: PackedScene = load(PRESTIGE_PANEL_SCENE_PATH) as PackedScene
	if panel_scene == null:
		return
	var panel: Node = panel_scene.instantiate()
	add_child(panel)
