extends Node
## Global score and run state. Registered as autoload "GameManager".

signal score_changed(new_total: int)
signal turn_banked(points: int, new_total: int)

var total_score: int = 0

func add_score(points: int) -> void:
	total_score += points
	score_changed.emit(total_score)
	turn_banked.emit(points, total_score)

func reset_score() -> void:
	total_score = 0
	score_changed.emit(total_score)
