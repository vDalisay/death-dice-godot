extends Node
## Global score and run state. Registered as autoload "GameManager".

const MAX_LIVES: int = 3
const DEFAULT_STAGE_TARGET: int = 500

signal score_changed(new_total: int)
signal turn_banked(points: int, new_total: int)
signal lives_changed(new_lives: int)
signal run_ended()
signal stage_cleared()

var total_score: int = 0
var lives: int = MAX_LIVES
var stage_target_score: int = DEFAULT_STAGE_TARGET

func add_score(points: int) -> void:
	total_score += points
	score_changed.emit(total_score)
	turn_banked.emit(points, total_score)
	if total_score >= stage_target_score:
		stage_cleared.emit()

func lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		run_ended.emit()

func reset_run() -> void:
	total_score = 0
	lives = MAX_LIVES
	score_changed.emit(total_score)
	lives_changed.emit(lives)
