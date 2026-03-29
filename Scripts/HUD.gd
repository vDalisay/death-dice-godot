class_name HUD
extends VBoxContainer
## Observes GameManager and RollPhase signals. Renders labels only — no game logic.

const SCORE_COUNT_DURATION: float = 0.5
const GOLD_FLOAT_DURATION: float = 1.0
const ALMOST_THERE_THRESHOLD: float = 0.9

@onready var stage_label: Label      = $StageLabel
@onready var lives_label: Label      = $LivesLabel
@onready var gold_label: Label       = $GoldLabel
@onready var target_label: Label     = $TargetLabel
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var progress_hint_label: Label = $ProgressHintLabel
@onready var score_label: Label      = $ScoreLabel
@onready var turn_score_label: Label = $TurnScoreLabel
@onready var stop_label: Label       = $StopLabel
@onready var status_label: Label     = $StatusLabel
@onready var highscore_label: Label  = $HighscoreLabel
@onready var modifier_label: Label   = $ModifierLabel

var _score_tween: Tween = null
var _progress_pulse_tween: Tween = null

func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.stage_advanced.connect(_on_stage_advanced)
	GameManager.run_ended.connect(_on_run_ended)
	GameManager.stage_cleared.connect(_on_stage_cleared)
	GameManager.loop_advanced.connect(_on_loop_advanced)
	SaveManager.highscore_changed.connect(_on_highscore_changed)
	_on_score_changed(GameManager.total_score)
	_on_lives_changed(GameManager.lives)
	_on_gold_changed(GameManager.gold)
	_refresh_stage_display()
	_refresh_modifier_display()
	_refresh_progress_display()
	highscore_label.text = "Highscore: %d" % SaveManager.highscore

# ---------------------------------------------------------------------------
# Public API — called by RollPhase to push turn-local info
# ---------------------------------------------------------------------------

func update_turn(turn_score: int, stop_count: int, bust_threshold: int) -> void:
	turn_score_label.text = "This turn: %d" % turn_score
	stop_label.text       = "Stops: %d / %d" % [stop_count, bust_threshold]
	stop_label.modulate   = Color(0.9, 0.2, 0.2) if stop_count > 0 else Color.WHITE
	_refresh_modifier_display()

func show_status(message: String, colour: Color = Color.WHITE) -> void:
	status_label.text     = message
	status_label.modulate = colour


## Animate the score label counting from old_value to new_value over time.
func animate_score_count(old_value: int, new_value: int) -> void:
	if _score_tween and _score_tween.is_valid():
		_score_tween.kill()
	_score_tween = create_tween()
	_score_tween.tween_method(
		func(val: float) -> void: score_label.text = "Total Score: %d" % int(val),
		float(old_value), float(new_value), SCORE_COUNT_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## Show a floating "+Ng" label that drifts up and fades out above the score label.
func show_floating_gold(amount: int) -> void:
	var lbl: Label = Label.new()
	lbl.text = "+%dg" % amount
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# top_level prevents VBoxContainer from including this label in layout.
	lbl.top_level = true
	var start_pos: Vector2 = score_label.global_position + Vector2(score_label.size.x * 0.5 - 30, 0)
	lbl.global_position = start_pos
	add_child(lbl)
	var tween: Tween = lbl.create_tween()
	tween.tween_property(lbl, "global_position:y", start_pos.y - 50.0, GOLD_FLOAT_DURATION).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, GOLD_FLOAT_DURATION).set_ease(Tween.EASE_IN).set_delay(0.3)
	tween.tween_callback(lbl.queue_free)

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_score_changed(new_total: int) -> void:
	score_label.text = "Total Score: %d" % new_total
	_refresh_progress_display()

func _on_lives_changed(new_lives: int) -> void:
	lives_label.text = "Lives: %d" % new_lives

func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = "Gold: %d" % new_gold

func _on_stage_advanced(_new_stage: int) -> void:
	_refresh_stage_display()
	_refresh_progress_display()

func _on_run_ended() -> void:
	show_status("RUN OVER — out of lives!", Color(0.9, 0.2, 0.2))

func _on_stage_cleared() -> void:
	show_status("STAGE CLEARED!", Color(0.3, 0.9, 0.3))

func _on_loop_advanced(_new_loop: int) -> void:
	_refresh_stage_display()
	_refresh_progress_display()

func _on_highscore_changed(new_highscore: int) -> void:
	highscore_label.text = "Highscore: %d" % new_highscore

func _refresh_stage_display() -> void:
	var loop_text: String = " (Loop %d)" % GameManager.current_loop if GameManager.current_loop > 1 else ""
	stage_label.text = "Stage: %d / %d%s" % [GameManager.current_stage, GameManager.get_stages_in_current_loop(), loop_text]
	target_label.text = "Target: %d" % GameManager.stage_target_score


func _refresh_progress_display() -> void:
	var target: int = maxi(1, GameManager.stage_target_score)
	var ratio: float = clampf(float(GameManager.total_score) / float(target), 0.0, 1.0)
	progress_bar.value = ratio * 100.0
	var almost_there: bool = ratio >= ALMOST_THERE_THRESHOLD and ratio < 1.0
	progress_hint_label.text = "ALMOST THERE" if almost_there else ""
	if almost_there:
		_start_progress_pulse()
	else:
		_stop_progress_pulse()


func _start_progress_pulse() -> void:
	if _progress_pulse_tween != null and _progress_pulse_tween.is_valid():
		return
	progress_bar.modulate = Color.WHITE
	_progress_pulse_tween = create_tween().set_loops()
	_progress_pulse_tween.tween_property(progress_bar, "modulate", Color(1.0, 0.88, 0.6), 0.25)
	_progress_pulse_tween.tween_property(progress_bar, "modulate", Color.WHITE, 0.25)


func _stop_progress_pulse() -> void:
	if _progress_pulse_tween != null and _progress_pulse_tween.is_valid():
		_progress_pulse_tween.kill()
	_progress_pulse_tween = null
	progress_bar.modulate = Color.WHITE


func _refresh_modifier_display() -> void:
	if GameManager.active_modifiers.is_empty():
		modifier_label.text = ""
		return
	var names: Array[String] = []
	for m: RunModifier in GameManager.active_modifiers:
		names.append(m.modifier_name)
	modifier_label.text = "Modifiers: %s" % ", ".join(names)
