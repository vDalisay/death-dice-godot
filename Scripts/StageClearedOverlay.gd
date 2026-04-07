extends ColorRect
## Stage-clear overlay with reveal animation, count-up labels, confetti and pulse CTA.

signal proceed_requested

const _UITheme := preload("res://Scripts/UITheme.gd")

const BACKDROP_ALPHA: float = 0.52
const COUNT_DURATION: float = 0.45
const SPARKLE_DELAY: float = 0.4
const SPARKLE_AMOUNT: int = 50
const SPARKLE_LIFETIME: float = 1.6
const TITLE_GLITCH_DURATION: float = 0.36
const ROW_REVEAL_DURATION: float = 0.18
const ROW_STAGGER_DELAY: float = 0.1
const GLITCH_CHARS: String = "#%&!?/01X*+"

@onready var _confetti: CPUParticles2D = $Confetti
@onready var _card: PanelContainer = $CenterContainer/Card
@onready var _title_label: Label = $CenterContainer/Card/MarginContainer/Content/TitleLabel
@onready var _gold_label: Label = $CenterContainer/Card/MarginContainer/Content/GoldLabel
@onready var _surplus_label: Label = $CenterContainer/Card/MarginContainer/Content/SurplusLabel
@onready var _proceed_button: Button = $CenterContainer/Card/MarginContainer/Content/ProceedButton
@onready var _breakdown_title: Label = $CenterContainer/Card/MarginContainer/Content/BreakdownTitle

var _button_pulse_tween: Tween = null
var _target_title_text: String = ""


func _ready() -> void:
	_apply_theme_styling()
	_proceed_button.pressed.connect(_on_proceed_pressed)


func _apply_theme_styling() -> void:
	_card.add_theme_stylebox_override(
		"panel",
		_UITheme.make_stage_family_panel_style("board", _UITheme.CORNER_RADIUS_MODAL, 2)
	)
	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_TITLE_COLOR)

	_breakdown_title.add_theme_font_override("font", _UITheme.font_display())
	_breakdown_title.add_theme_font_size_override("font_size", 12)
	_breakdown_title.add_theme_color_override("font_color", _UITheme.ACTION_CYAN)

	_gold_label.add_theme_font_override("font", _UITheme.font_stats())
	_gold_label.add_theme_font_size_override("font_size", 30)
	_gold_label.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)

	_surplus_label.add_theme_font_override("font", _UITheme.font_stats())
	_surplus_label.add_theme_font_size_override("font_size", 24)
	_surplus_label.add_theme_color_override("font_color", _UITheme.SUCCESS_GREEN)

	_proceed_button.add_theme_font_override("font", _UITheme.font_display())
	_proceed_button.add_theme_font_size_override("font_size", 14)

	var gradient := Gradient.new()
	gradient.set_color(0, _UITheme.ROSE_ACCENT)
	gradient.add_point(0.25, _UITheme.SUCCESS_GREEN)
	gradient.add_point(0.5, _UITheme.ACTION_CYAN)
	gradient.add_point(0.75, _UITheme.SCORE_GOLD)
	gradient.set_color(1, _UITheme.NEON_PURPLE)
	_confetti.color_ramp = gradient


func setup(bonus_gold: int, surplus: int, is_loop: bool) -> void:
	_target_title_text = tr("LOOP_CLEARED_TITLE") if is_loop else tr("STAGE_CLEARED_TITLE")
	_title_label.text = build_glitch_text(_target_title_text, 0.0)
	_surplus_label.visible = surplus > 0
	if surplus > 0:
		_surplus_label.text = tr("STAGE_CLEARED_SURPLUS_FMT").format({"value": 0})
	_breakdown_title.modulate.a = 0.0
	_gold_label.modulate.a = 0.0
	_surplus_label.modulate.a = 0.0
	_breakdown_title.position.y -= 10.0
	_gold_label.position.y -= 10.0
	_surplus_label.position.y -= 10.0

	color = Color(0, 0, 0, 0)
	_card.modulate.a = 0.0
	_card.scale = Vector2(1.25, 1.25)
	_card.pivot_offset = _card.size * 0.5
	_proceed_button.modulate.a = 0.0
	_proceed_button.disabled = true

	_confetti.emitting = false
	_confetti.emitting = true
	_spawn_sparkle_wave()

	var tween: Tween = create_tween()
	tween.tween_property(self, "color:a", BACKDROP_ALPHA, 0.22)
	tween.parallel().tween_property(_card, "modulate:a", 1.0, 0.22)
	tween.parallel().tween_property(_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_method(_set_title_glitch_progress, 0.0, 1.0, TITLE_GLITCH_DURATION)
	tween.tween_callback(Callable(self, "_reveal_row").bind(_breakdown_title))
	tween.tween_interval(ROW_STAGGER_DELAY)
	tween.tween_callback(Callable(self, "_show_reward_rows").bind(bonus_gold, surplus))
	tween.tween_interval(0.35)
	tween.tween_callback(Callable(self, "_show_proceed_button").bind(is_loop))


func _animate_value(target_label: Label, prefix: String, value: int, suffix: String) -> void:
	var tween: Tween = create_tween()
	var label_path: NodePath = target_label.get_path()
	tween.tween_method(
		Callable(self, "_set_count_label_value").bind(label_path, prefix, suffix),
		0.0,
		float(value),
		COUNT_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _start_button_pulse() -> void:
	if _button_pulse_tween != null and _button_pulse_tween.is_valid():
		return
	_proceed_button.scale = Vector2.ONE
	_button_pulse_tween = create_tween().set_loops()
	_button_pulse_tween.tween_property(_proceed_button, "scale", Vector2(1.045, 1.045), 0.7)
	_button_pulse_tween.tween_property(_proceed_button, "scale", Vector2.ONE, 0.7)


func _on_proceed_pressed() -> void:
	if _button_pulse_tween != null and _button_pulse_tween.is_valid():
		_button_pulse_tween.kill()
	proceed_requested.emit()


func _spawn_sparkle_wave() -> void:
	get_tree().create_timer(SPARKLE_DELAY).timeout.connect(_emit_sparkle_wave, CONNECT_ONE_SHOT)


func _reveal_row(label: Label) -> void:
	var tween: Tween = create_tween()
	var end_y: float = label.position.y + 10.0
	tween.tween_property(label, "modulate:a", 1.0, ROW_REVEAL_DURATION)
	tween.parallel().tween_property(label, "position:y", end_y, ROW_REVEAL_DURATION).set_ease(Tween.EASE_OUT)


func _set_title_glitch_progress(progress: float) -> void:
	_title_label.text = build_glitch_text(_target_title_text, progress)


func _show_reward_rows(bonus_gold: int, surplus: int) -> void:
	_reveal_row(_gold_label)
	_animate_value(_gold_label, tr("STAGE_CLEARED_GOLD_FMT").format({"value": "{value}"}).replace("{value}", ""), bonus_gold, "g")
	if surplus > 0:
		_reveal_row(_surplus_label)
		_animate_value(_surplus_label, tr("STAGE_CLEARED_SURPLUS_FMT").format({"value": "{value}"}).replace("{value}", ""), surplus, "")


func _show_proceed_button(is_loop: bool) -> void:
	_proceed_button.text = tr("STAGE_CLEARED_CONTINUE_LOOP") if is_loop else tr("CONTINUE_ACTION")
	_proceed_button.modulate.a = 1.0
	_proceed_button.disabled = false
	_start_button_pulse()


func _set_count_label_value(value: float, label_path: NodePath, prefix: String, suffix: String) -> void:
	if not has_node(label_path):
		return
	var target_label: Label = get_node(label_path) as Label
	target_label.text = "%s%d%s" % [prefix, int(value), suffix]


func _emit_sparkle_wave() -> void:
	if not is_inside_tree():
		return
	var sparkle := CPUParticles2D.new()
	sparkle.one_shot = true
	sparkle.amount = SPARKLE_AMOUNT
	sparkle.lifetime = SPARKLE_LIFETIME
	sparkle.explosiveness = 0.92
	sparkle.direction = Vector2(0, -1)
	sparkle.spread = 160.0
	sparkle.gravity = Vector2(0, 120)
	sparkle.initial_velocity_min = 100.0
	sparkle.initial_velocity_max = 350.0
	sparkle.scale_amount_min = 1.0
	sparkle.scale_amount_max = 3.0
	sparkle.color = Color(1.0, 1.0, 1.0, 0.7)
	var gradient := Gradient.new()
	gradient.set_color(0, _UITheme.SCORE_GOLD)
	gradient.add_point(0.5, Color(1.0, 1.0, 1.0, 0.8))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	sparkle.color_ramp = gradient
	sparkle.position = Vector2(size.x / 2.0, size.y * 0.3)
	add_child(sparkle)
	sparkle.emitting = true
	var sparkle_path: NodePath = sparkle.get_path()
	get_tree().create_timer(SPARKLE_LIFETIME + 0.5).timeout.connect(
		Callable(self, "_cleanup_sparkle").bind(sparkle_path),
		CONNECT_ONE_SHOT
	)


func _cleanup_sparkle(sparkle_path: NodePath) -> void:
	if not has_node(sparkle_path):
		return
	var sparkle: CPUParticles2D = get_node(sparkle_path) as CPUParticles2D
	sparkle.queue_free()


static func build_glitch_text(target_text: String, progress: float) -> String:
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	if clamped_progress >= 1.0:
		return target_text
	var reveal_count: int = int(floor(float(target_text.length()) * clamped_progress))
	var result: String = ""
	for i: int in target_text.length():
		var ch: String = target_text.substr(i, 1)
		if ch == " ":
			result += " "
		elif i < reveal_count:
			result += ch
		else:
			var glitch_index: int = posmod(i * 5 + int(round(clamped_progress * 29.0)), GLITCH_CHARS.length())
			result += GLITCH_CHARS.substr(glitch_index, 1)
	return result
