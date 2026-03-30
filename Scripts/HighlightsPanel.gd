class_name HighlightsPanel
extends PanelContainer
## End-of-run highlights reel — dark modal with card-reveal and counting animations.

signal closed()

const _UITheme := preload("res://Scripts/UITheme.gd")

const CARD_WIDTH: int = 140
const CARD_HEIGHT: int = 120
const REVEAL_STAGGER: float = 0.18
const COUNT_DURATION: float = 0.4
const TITLE_FONT_SIZE: int = 18
const STAT_NAME_SIZE: int = 10
const STAT_VALUE_SIZE: int = 22
const BEST_BADGE_SIZE: int = 9

@onready var _card: PanelContainer = $CenterContainer/Card
@onready var _title_label: Label = $CenterContainer/Card/MarginContainer/Content/TitleLabel
@onready var _stat_cards: HFlowContainer = $CenterContainer/Card/MarginContainer/Content/StatCards
@onready var _close_button: Button = $CenterContainer/Card/MarginContainer/Content/CloseButton

var _stat_card_nodes: Array[PanelContainer] = []


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(_on_close_pressed)
	_apply_theme()


func show_highlights(run: RunSaveData, prior_bests: Dictionary) -> void:
	_build_stat_cards(run, prior_bests)
	visible = true
	_animate_reveal()


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _apply_theme() -> void:
	add_theme_stylebox_override("panel", _UITheme.make_panel_stylebox(Color.TRANSPARENT, 0))
	_card.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_MODAL, _UITheme.SCORE_GOLD, 2)
	)
	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title_label.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)
	_close_button.add_theme_font_override("font", _UITheme.font_display())
	_close_button.add_theme_font_size_override("font_size", 12)


## Data structure for a single stat card.
class _StatDef:
	var label_name: String
	var icon: String
	var value: int
	var is_best: bool
	var accent: Color

	func _init(p_name: String, p_icon: String, p_value: int, p_is_best: bool, p_accent: Color) -> void:
		label_name = p_name
		icon = p_icon
		value = p_value
		is_best = p_is_best
		accent = p_accent


func _build_stat_cards(run: RunSaveData, prior_bests: Dictionary) -> void:
	# Clear previous cards.
	for child: Node in _stat_cards.get_children():
		child.queue_free()
	_stat_card_nodes.clear()

	var stats: Array[_StatDef] = []
	stats.append(_StatDef.new("Score", _UITheme.GLYPH_STAR, run.score,
		run.score >= (prior_bests.get("highscore", 0) as int) and run.score > 0, _UITheme.SCORE_GOLD))
	stats.append(_StatDef.new("Stages", _UITheme.GLYPH_CHECK, run.stages_cleared,
		run.stages_cleared >= (prior_bests.get("best_stages", 0) as int) and run.stages_cleared > 0, _UITheme.SUCCESS_GREEN))
	stats.append(_StatDef.new("Loops", _UITheme.GLYPH_FIRE, run.loops_completed,
		run.loops_completed >= (prior_bests.get("best_loop", 0) as int) and run.loops_completed > 0, _UITheme.EXPLOSION_ORANGE))
	stats.append(_StatDef.new("Best Turn", _UITheme.GLYPH_EXPLODE, run.best_turn_score,
		run.best_turn_score >= (prior_bests.get("best_turn", 0) as int) and run.best_turn_score > 0, _UITheme.ROSE_ACCENT))
	stats.append(_StatDef.new("Busts", _UITheme.GLYPH_STOP, run.busts, false, _UITheme.DANGER_RED))
	stats.append(_StatDef.new("Final Dice", _UITheme.GLYPH_DIE, run.final_dice_names.size(), false, _UITheme.ACTION_CYAN))

	for stat: _StatDef in stats:
		var card: PanelContainer = _create_stat_card(stat)
		card.modulate.a = 0.0
		card.scale = Vector2(0.8, 0.8)
		card.pivot_offset = Vector2(CARD_WIDTH * 0.5, CARD_HEIGHT * 0.5)
		_stat_cards.add_child(card)
		_stat_card_nodes.append(card)


func _create_stat_card(stat: _StatDef) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.ELEVATED, _UITheme.CORNER_RADIUS_CARD, stat.accent, 1)
	)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.add_child(vbox)
	card.add_child(margin)

	# Icon
	var icon_label := Label.new()
	icon_label.text = stat.icon
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_override("font", _UITheme.font_display())
	icon_label.add_theme_font_size_override("font_size", 16)
	icon_label.add_theme_color_override("font_color", stat.accent)
	vbox.add_child(icon_label)

	# Name
	var name_label := Label.new()
	name_label.text = stat.label_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", _UITheme.font_display())
	name_label.add_theme_font_size_override("font_size", STAT_NAME_SIZE)
	name_label.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)
	vbox.add_child(name_label)

	# Value (will be animated via counting)
	var value_label := Label.new()
	value_label.name = "ValueLabel"
	value_label.text = "0"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_override("font", _UITheme.font_stats())
	value_label.add_theme_font_size_override("font_size", STAT_VALUE_SIZE)
	value_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)
	vbox.add_child(value_label)
	# Store target value as metadata.
	value_label.set_meta("target_value", stat.value)

	# "NEW BEST!" badge (initially hidden).
	if stat.is_best:
		var best_label := Label.new()
		best_label.name = "BestBadge"
		best_label.text = "%s NEW BEST!" % _UITheme.GLYPH_STAR
		best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		best_label.add_theme_font_override("font", _UITheme.font_display())
		best_label.add_theme_font_size_override("font_size", BEST_BADGE_SIZE)
		best_label.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)
		best_label.modulate.a = 0.0
		vbox.add_child(best_label)

	return card


func _animate_reveal() -> void:
	var tween: Tween = create_tween()
	for i: int in _stat_card_nodes.size():
		var card: PanelContainer = _stat_card_nodes[i]
		var delay: float = i * REVEAL_STAGGER
		tween.parallel().tween_property(card, "modulate:a", 1.0, 0.2).set_delay(delay)
		tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		# Count up the value after the card appears.
		tween.parallel().tween_callback(_count_up_card.bind(card)).set_delay(delay + 0.15)


func _count_up_card(card: PanelContainer) -> void:
	var value_label: Label = card.find_child("ValueLabel", true, false) as Label
	if value_label == null:
		return
	var target: int = value_label.get_meta("target_value", 0) as int
	if target <= 0:
		value_label.text = str(target)
		_show_best_badge(card)
		return
	var count_tween: Tween = create_tween()
	count_tween.tween_method(func(val: float) -> void:
		value_label.text = str(int(val))
	, 0.0, float(target), COUNT_DURATION)
	count_tween.tween_callback(_show_best_badge.bind(card))


func _show_best_badge(card: PanelContainer) -> void:
	var badge: Label = card.find_child("BestBadge", true, false) as Label
	if badge == null:
		return
	var badge_tween: Tween = create_tween()
	badge_tween.tween_property(badge, "modulate:a", 1.0, 0.15)
	# Pulse glow.
	badge_tween.tween_property(badge, "modulate:a", 0.6, 0.4)
	badge_tween.tween_property(badge, "modulate:a", 1.0, 0.4)
