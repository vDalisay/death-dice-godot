class_name HighlightsPanel
extends PanelContainer
## End-of-run highlights reel. Compares run stats to career bests.

signal closed()

@onready var _score_label: Label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var _stages_label: Label = $MarginContainer/VBoxContainer/StagesLabel
@onready var _loops_label: Label = $MarginContainer/VBoxContainer/LoopsLabel
@onready var _best_turn_label: Label = $MarginContainer/VBoxContainer/BestTurnLabel
@onready var _busts_label: Label = $MarginContainer/VBoxContainer/BustsLabel
@onready var _dice_label: Label = $MarginContainer/VBoxContainer/DiceLabel
@onready var _close_button: Button = $MarginContainer/VBoxContainer/CloseButton


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(_on_close_pressed)


func show_highlights(run: RunSaveData, prior_bests: Dictionary) -> void:
	_refresh(run, prior_bests)
	visible = true


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _refresh(run: RunSaveData, prior_bests: Dictionary) -> void:
	_score_label.text = _format_stat(
		"Score", run.score, prior_bests.get("highscore", 0) as int)
	_stages_label.text = _format_stat(
		"Stages Cleared", run.stages_cleared, prior_bests.get("best_stages", 0) as int)
	_loops_label.text = _format_stat(
		"Loops Completed", run.loops_completed, prior_bests.get("best_loop", 0) as int)
	_best_turn_label.text = _format_stat(
		"Best Turn", run.best_turn_score, prior_bests.get("best_turn", 0) as int)
	_busts_label.text = "Busts: %d" % run.busts
	_dice_label.text = "Final Dice: %d" % run.final_dice_names.size()


func _format_stat(label: String, run_value: int, career_best: int) -> String:
	var line: String = "%s: %d" % [label, run_value]
	if run_value >= career_best and run_value > 0:
		line += "  ★ NEW BEST!"
	else:
		line += "  (Best: %d)" % career_best
	return line
