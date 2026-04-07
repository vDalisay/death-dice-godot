class_name CareerPanel
extends PanelContainer
## Career stats and achievement progress screen — dark modal with icon-paired stats.

signal closed()

const _UITheme := preload("res://Scripts/UITheme.gd")

const ICON_FONT_SIZE: int = 20
const STAT_FONT_SIZE: int = 18
const TITLE_FONT_SIZE: int = 20
const HEADER_FONT_SIZE: int = 14
const CLOSE_BUTTON_FONT_SIZE: int = 14
const BADGE_SIZE: int = 36
const BADGE_ICON_FONT_SIZE: int = 12
const UNLOCKED_BADGE_BORDER_WIDTH: int = 1
const LOCKED_BADGE_BORDER_WIDTH: int = 0

@onready var _card: PanelContainer = $CenterContainer/Card
@onready var _title_label: Label = $CenterContainer/Card/MarginContainer/Content/TitleLabel
@onready var _loop_icon: Label = $CenterContainer/Card/MarginContainer/Content/StatsGrid/LoopIcon
@onready var _turn_icon: Label = $CenterContainer/Card/MarginContainer/Content/StatsGrid/TurnIcon
@onready var _bust_icon: Label = $CenterContainer/Card/MarginContainer/Content/StatsGrid/BustIcon
@onready var _die_icon: Label = $CenterContainer/Card/MarginContainer/Content/StatsGrid/DieIcon
@onready var _run_icon: Label = $CenterContainer/Card/MarginContainer/Content/StatsGrid/RunIcon
@onready var _stage_icon: Label = $CenterContainer/Card/MarginContainer/Content/StatsGrid/StageIcon
@onready var _best_loop_label: Label = $CenterContainer/Card/MarginContainer/Content/StatsGrid/BestLoopLabel
@onready var _best_turn_label: Label = $CenterContainer/Card/MarginContainer/Content/StatsGrid/BestTurnLabel
@onready var _total_busts_label: Label = $CenterContainer/Card/MarginContainer/Content/StatsGrid/TotalBustsLabel
@onready var _favorite_die_label: Label = $CenterContainer/Card/MarginContainer/Content/StatsGrid/FavoriteDieLabel
@onready var _lifetime_runs_label: Label = $CenterContainer/Card/MarginContainer/Content/StatsGrid/LifetimeRunsLabel
@onready var _stages_cleared_label: Label = $CenterContainer/Card/MarginContainer/Content/StatsGrid/StagesClearedLabel
@onready var _achievements_header: Label = $CenterContainer/Card/MarginContainer/Content/AchievementsHeader
@onready var _achievements_label: Label = $CenterContainer/Card/MarginContainer/Content/AchievementsLabel
@onready var _achievement_grid: HFlowContainer = $CenterContainer/Card/MarginContainer/Content/AchievementGrid
@onready var _close_button: Button = $CenterContainer/Card/MarginContainer/Content/CloseButton


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(_on_close_pressed)
	if LocalizationManager != null:
		LocalizationManager.locale_changed.connect(_on_locale_changed)
	_apply_theme()
	_refresh_localized_labels()


func open_panel() -> void:
	_refresh()
	visible = true


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _apply_theme() -> void:
	# Root panel transparent — backdrop handles dimming.
	add_theme_stylebox_override("panel", _UITheme.make_panel_stylebox(Color.TRANSPARENT, 0))
	_UITheme.apply_modal_panel_style(_card, _UITheme.NEON_PURPLE)
	# Title.
	_UITheme.apply_label_style(_title_label, _UITheme.font_display(), TITLE_FONT_SIZE, _UITheme.NEON_PURPLE)
	# Achievement header.
	_UITheme.apply_label_style(_achievements_header, _UITheme.font_display(), HEADER_FONT_SIZE, _UITheme.SCORE_GOLD)
	_UITheme.apply_label_style(_achievements_label, _UITheme.font_stats(), STAT_FONT_SIZE, _UITheme.MUTED_TEXT)
	# Stat icons and labels.
	var icon_labels: Array[Label] = [
		_loop_icon,
		_turn_icon,
		_bust_icon,
		_die_icon,
		_run_icon,
		_stage_icon,
	]
	var icon_colors: Array[Color] = [
		_UITheme.EXPLOSION_ORANGE,
		_UITheme.SCORE_GOLD,
		_UITheme.DANGER_RED,
		_UITheme.ACTION_CYAN,
		_UITheme.BRIGHT_TEXT,
		_UITheme.SUCCESS_GREEN,
	]
	for i: int in icon_labels.size():
		_UITheme.apply_label_style(icon_labels[i], _UITheme.font_display(), ICON_FONT_SIZE, icon_colors[i])
	for stat_label: Label in [
		_best_loop_label, _best_turn_label, _total_busts_label,
		_favorite_die_label, _lifetime_runs_label, _stages_cleared_label,
	]:
		_UITheme.apply_label_style(stat_label, _UITheme.font_stats(), STAT_FONT_SIZE, _UITheme.BRIGHT_TEXT)
	# Close button.
	_UITheme.apply_label_style(_close_button, _UITheme.font_display(), CLOSE_BUTTON_FONT_SIZE, _UITheme.BRIGHT_TEXT)


func _refresh_localized_labels() -> void:
	_title_label.text = tr("CAREER_STATS_TITLE")
	_achievements_header.text = tr("ACHIEVEMENTS_TITLE")
	_close_button.text = tr("CLOSE_ACTION")
	_refresh()


func _refresh() -> void:
	_best_loop_label.text = tr("BEST_LOOP_FMT").format({"value": SaveManager.career_best_loop})
	_best_turn_label.text = tr("BEST_TURN_SCORE_FMT").format({"value": SaveManager.career_best_turn_score})
	_total_busts_label.text = tr("TOTAL_BUSTS_FMT").format({"value": SaveManager.total_busts})
	var favorite_die: String = SaveManager.get_favorite_die_type()
	if favorite_die == "None":
		favorite_die = tr("NO_FAVORITE_DIE")
	_favorite_die_label.text = tr("FAVORITE_DIE_FMT").format({"value": favorite_die})
	_lifetime_runs_label.text = tr("LIFETIME_RUNS_FMT").format({"value": SaveManager.total_runs})
	_stages_cleared_label.text = tr("TOTAL_STAGES_CLEARED_FMT").format({"value": SaveManager.total_stages_cleared})
	var total_achievements: int = AchievementManager.get_total_achievement_count()
	var unlocked: int = SaveManager.get_unlocked_achievement_count()
	_achievements_label.text = tr("ACHIEVEMENTS_UNLOCKED_FMT").format({
		"unlocked": unlocked,
		"total": total_achievements,
	})
	_build_achievement_badges(unlocked, total_achievements)


func _on_locale_changed(_new_locale: String) -> void:
	_refresh_localized_labels()


func _build_achievement_badges(unlocked: int, total: int) -> void:
	# Clear old badges.
	for child: Node in _achievement_grid.get_children():
		child.queue_free()
	# Build badge for each achievement slot.
	for i: int in total:
		var badge: PanelContainer = PanelContainer.new()
		badge.custom_minimum_size = Vector2(BADGE_SIZE, BADGE_SIZE)
		var is_unlocked: bool = i < unlocked
		var bg_color: Color = _UITheme.NEON_PURPLE if is_unlocked else _UITheme.ELEVATED
		var border_color: Color = _UITheme.SCORE_GOLD if is_unlocked else _UITheme.MUTED_TEXT
		badge.add_theme_stylebox_override(
			"panel",
			_UITheme.make_panel_stylebox(
				bg_color,
				_UITheme.CORNER_RADIUS_BADGE,
				border_color,
				UNLOCKED_BADGE_BORDER_WIDTH if is_unlocked else LOCKED_BADGE_BORDER_WIDTH
			)
		)
		var icon: Label = Label.new()
		icon.text = _UITheme.GLYPH_STAR if is_unlocked else "?"
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_UITheme.apply_label_style(
			icon,
			_UITheme.font_display(),
			BADGE_ICON_FONT_SIZE,
			_UITheme.SCORE_GOLD if is_unlocked else _UITheme.MUTED_TEXT
		)
		badge.add_child(icon)
		_achievement_grid.add_child(badge)
