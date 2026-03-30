class_name CareerPanel
extends PanelContainer
## Career stats and achievement progress screen — dark modal with icon-paired stats.

signal closed()

const _UITheme := preload("res://Scripts/UITheme.gd")

const ICON_FONT_SIZE: int = 20
const STAT_FONT_SIZE: int = 18
const TITLE_FONT_SIZE: int = 20
const HEADER_FONT_SIZE: int = 14
const BADGE_SIZE: int = 36

@onready var _card: PanelContainer = $CenterContainer/Card
@onready var _title_label: Label = $CenterContainer/Card/MarginContainer/Content/TitleLabel
@onready var _stats_grid: GridContainer = $CenterContainer/Card/MarginContainer/Content/StatsGrid
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
	_apply_theme()


func open_panel() -> void:
	_refresh()
	visible = true


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _apply_theme() -> void:
	# Root panel transparent — backdrop handles dimming.
	add_theme_stylebox_override("panel", _UITheme.make_panel_stylebox(Color.TRANSPARENT, 0))
	_card.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_MODAL, _UITheme.NEON_PURPLE, 2)
	)
	# Title.
	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title_label.add_theme_color_override("font_color", _UITheme.NEON_PURPLE)
	# Achievement header.
	_achievements_header.add_theme_font_override("font", _UITheme.font_display())
	_achievements_header.add_theme_font_size_override("font_size", HEADER_FONT_SIZE)
	_achievements_header.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)
	_achievements_label.add_theme_font_override("font", _UITheme.font_stats())
	_achievements_label.add_theme_font_size_override("font_size", STAT_FONT_SIZE)
	_achievements_label.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)
	# Stat icons and labels.
	var icon_color_map: Dictionary = {
		"LoopIcon": _UITheme.EXPLOSION_ORANGE,
		"TurnIcon": _UITheme.SCORE_GOLD,
		"BustIcon": _UITheme.DANGER_RED,
		"DieIcon": _UITheme.ACTION_CYAN,
		"RunIcon": _UITheme.BRIGHT_TEXT,
		"StageIcon": _UITheme.SUCCESS_GREEN,
	}
	for icon_name: String in icon_color_map:
		var icon_label: Label = _stats_grid.get_node(icon_name) as Label
		icon_label.add_theme_font_override("font", _UITheme.font_display())
		icon_label.add_theme_font_size_override("font_size", ICON_FONT_SIZE)
		icon_label.add_theme_color_override("font_color", icon_color_map[icon_name] as Color)
	for stat_label: Label in [
		_best_loop_label, _best_turn_label, _total_busts_label,
		_favorite_die_label, _lifetime_runs_label, _stages_cleared_label,
	]:
		stat_label.add_theme_font_override("font", _UITheme.font_stats())
		stat_label.add_theme_font_size_override("font_size", STAT_FONT_SIZE)
		stat_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)
	# Close button.
	_close_button.add_theme_font_override("font", _UITheme.font_display())
	_close_button.add_theme_font_size_override("font_size", 14)


func _refresh() -> void:
	_best_loop_label.text = "Best Loop: %d" % SaveManager.career_best_loop
	_best_turn_label.text = "Best Turn Score: %d" % SaveManager.career_best_turn_score
	_total_busts_label.text = "Total Busts: %d" % SaveManager.total_busts
	_favorite_die_label.text = "Favorite Die: %s" % SaveManager.get_favorite_die_type()
	_lifetime_runs_label.text = "Lifetime Runs: %d" % SaveManager.total_runs
	_stages_cleared_label.text = "Stages Cleared: %d" % SaveManager.total_stages_cleared
	var total_achievements: int = 0
	if has_node("/root/AchievementManager"):
		var achievement_manager: Node = get_node("/root/AchievementManager")
		total_achievements = int(achievement_manager.call("get_total_achievement_count"))
	var unlocked: int = SaveManager.get_unlocked_achievement_count()
	_achievements_label.text = "%d / %d unlocked" % [unlocked, total_achievements]
	_build_achievement_badges(unlocked, total_achievements)


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
			_UITheme.make_panel_stylebox(bg_color, _UITheme.CORNER_RADIUS_BADGE, border_color, 1 if is_unlocked else 0)
		)
		var icon: Label = Label.new()
		icon.text = _UITheme.GLYPH_STAR if is_unlocked else "?"
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.add_theme_font_override("font", _UITheme.font_display())
		icon.add_theme_font_size_override("font_size", 12)
		icon.add_theme_color_override("font_color", _UITheme.SCORE_GOLD if is_unlocked else _UITheme.MUTED_TEXT)
		badge.add_child(icon)
		_achievement_grid.add_child(badge)
