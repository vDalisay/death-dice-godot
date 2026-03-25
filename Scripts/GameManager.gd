extends Node
## Global score and run state. Registered as autoload "GameManager".

const MAX_LIVES: int = 3
const STARTING_DICE_COUNT: int = 5
const STAGES_PER_RUN: int = 5
const BASE_STAGE_TARGET: int = 30
const STAGE_TARGET_STEP: int = 25
const STAGE_CLEAR_GOLD_BONUS: int = 20

signal score_changed(new_total: int)
signal turn_banked(points: int, new_total: int)
signal lives_changed(new_lives: int)
signal gold_changed(new_gold: int)
signal stage_advanced(new_stage: int)
signal run_ended()
signal stage_cleared()

var total_score: int = 0
var lives: int = MAX_LIVES
var current_stage: int = 1
var gold: int = 0
var stage_target_score: int = BASE_STAGE_TARGET
var dice_pool: Array[DiceData] = []


func _ready() -> void:
	_build_starting_pool()


# ---------------------------------------------------------------------------
# Dice pool
# ---------------------------------------------------------------------------

func _build_starting_pool() -> void:
	dice_pool.clear()
	for i: int in STARTING_DICE_COUNT:
		dice_pool.append(DiceData.make_standard_d6())


func add_dice(die: DiceData) -> void:
	dice_pool.append(die)


# ---------------------------------------------------------------------------
# Score & gold
# ---------------------------------------------------------------------------

func add_score(points: int) -> void:
	total_score += points
	add_gold(points)
	score_changed.emit(total_score)
	turn_banked.emit(points, total_score)
	if total_score >= stage_target_score:
		stage_cleared.emit()


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


# ---------------------------------------------------------------------------
# Stage progression
# ---------------------------------------------------------------------------

func _calculate_stage_target(stage: int) -> int:
	return BASE_STAGE_TARGET + (stage - 1) * STAGE_TARGET_STEP


func advance_stage() -> void:
	current_stage += 1
	total_score = 0
	stage_target_score = _calculate_stage_target(current_stage)
	score_changed.emit(total_score)
	stage_advanced.emit(current_stage)


func is_final_stage() -> bool:
	return current_stage >= STAGES_PER_RUN


# ---------------------------------------------------------------------------
# Lives
# ---------------------------------------------------------------------------

func lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		run_ended.emit()


# ---------------------------------------------------------------------------
# Run reset
# ---------------------------------------------------------------------------

func reset_run() -> void:
	current_stage = 1
	total_score = 0
	lives = MAX_LIVES
	gold = 0
	stage_target_score = _calculate_stage_target(current_stage)
	_build_starting_pool()
	score_changed.emit(total_score)
	lives_changed.emit(lives)
	gold_changed.emit(gold)
	stage_advanced.emit(current_stage)
