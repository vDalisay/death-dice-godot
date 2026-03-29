class_name CareerPanel
extends PanelContainer
## Career stats and achievement progress screen.

signal closed()

@onready var _best_loop_label: Label = $MarginContainer/VBoxContainer/BestLoopLabel
@onready var _best_turn_label: Label = $MarginContainer/VBoxContainer/BestTurnLabel
@onready var _total_busts_label: Label = $MarginContainer/VBoxContainer/TotalBustsLabel
@onready var _favorite_die_label: Label = $MarginContainer/VBoxContainer/FavoriteDieLabel
@onready var _lifetime_runs_label: Label = $MarginContainer/VBoxContainer/LifetimeRunsLabel
@onready var _stages_cleared_label: Label = $MarginContainer/VBoxContainer/StagesClearedLabel
@onready var _achievements_label: Label = $MarginContainer/VBoxContainer/AchievementsLabel
@onready var _close_button: Button = $MarginContainer/VBoxContainer/CloseButton


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(_on_close_pressed)


func open_panel() -> void:
	_refresh()
	visible = true


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _refresh() -> void:
	_best_loop_label.text = "Best Loop: %d" % SaveManager.career_best_loop
	_best_turn_label.text = "Best Turn Score: %d" % SaveManager.career_best_turn_score
	_total_busts_label.text = "Total Busts: %d" % SaveManager.total_busts
	_favorite_die_label.text = "Favorite Die Type: %s" % SaveManager.get_favorite_die_type()
	_lifetime_runs_label.text = "Lifetime Runs: %d" % SaveManager.total_runs
	_stages_cleared_label.text = "Total Stages Cleared: %d" % SaveManager.total_stages_cleared
	var total_achievements: int = 0
	if has_node("/root/AchievementManager"):
		var achievement_manager: Node = get_node("/root/AchievementManager")
		total_achievements = int(achievement_manager.call("get_total_achievement_count"))
	_achievements_label.text = "Achievements: %d / %d" % [
		SaveManager.get_unlocked_achievement_count(),
		total_achievements,
	]
