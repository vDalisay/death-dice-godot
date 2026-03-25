class_name HUD
extends VBoxContainer
## Observes GameManager and RollPhase signals. Renders labels only — no game logic.

@onready var stage_label: Label      = $StageLabel
@onready var lives_label: Label      = $LivesLabel
@onready var gold_label: Label       = $GoldLabel
@onready var target_label: Label     = $TargetLabel
@onready var score_label: Label      = $ScoreLabel
@onready var turn_score_label: Label = $TurnScoreLabel
@onready var stop_label: Label       = $StopLabel
@onready var status_label: Label     = $StatusLabel
@onready var highscore_label: Label  = $HighscoreLabel

func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.stage_advanced.connect(_on_stage_advanced)
	GameManager.run_ended.connect(_on_run_ended)
	GameManager.stage_cleared.connect(_on_stage_cleared)
	SaveManager.highscore_changed.connect(_on_highscore_changed)
	_on_score_changed(GameManager.total_score)
	_on_lives_changed(GameManager.lives)
	_on_gold_changed(GameManager.gold)
	_refresh_stage_display()
	highscore_label.text = "Highscore: %d" % SaveManager.highscore

# ---------------------------------------------------------------------------
# Public API — called by RollPhase to push turn-local info
# ---------------------------------------------------------------------------

func update_turn(turn_score: int, stop_count: int, bust_threshold: int) -> void:
	turn_score_label.text = "This turn: %d" % turn_score
	stop_label.text       = "Stops: %d / %d" % [stop_count, bust_threshold]
	stop_label.modulate   = Color(0.9, 0.2, 0.2) if stop_count > 0 else Color.WHITE

func show_status(message: String, colour: Color = Color.WHITE) -> void:
	status_label.text     = message
	status_label.modulate = colour

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_score_changed(new_total: int) -> void:
	score_label.text = "Total Score: %d" % new_total

func _on_lives_changed(new_lives: int) -> void:
	lives_label.text = "Lives: %d" % new_lives

func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = "Gold: %d" % new_gold

func _on_stage_advanced(_new_stage: int) -> void:
	_refresh_stage_display()

func _on_run_ended() -> void:
	show_status("RUN OVER — out of lives!", Color(0.9, 0.2, 0.2))

func _on_stage_cleared() -> void:
	show_status("STAGE CLEARED!", Color(0.3, 0.9, 0.3))

func _on_highscore_changed(new_highscore: int) -> void:
	highscore_label.text = "Highscore: %d" % new_highscore

func _refresh_stage_display() -> void:
	stage_label.text = "Stage: %d / %d" % [GameManager.current_stage, GameManager.STAGES_PER_RUN]
	target_label.text = "Target: %d" % GameManager.stage_target_score
