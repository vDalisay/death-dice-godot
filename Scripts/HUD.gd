class_name HUD
extends VBoxContainer
## Observes GameManager and RollPhase signals. Renders labels only — no game logic.

@onready var score_label: Label      = $ScoreLabel
@onready var turn_score_label: Label = $TurnScoreLabel
@onready var stop_label: Label       = $StopLabel
@onready var status_label: Label     = $StatusLabel

func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	_on_score_changed(GameManager.total_score)

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
