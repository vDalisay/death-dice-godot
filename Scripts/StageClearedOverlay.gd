extends ColorRect
## Stage-clear overlay with reveal animation, count-up labels, confetti and pulse CTA.

signal proceed_requested

const _UITheme := preload("res://Scripts/UITheme.gd")

const BACKDROP_ALPHA: float = 0.72
const COUNT_DURATION: float = 0.45
const SPARKLE_DELAY: float = 0.4
const SPARKLE_AMOUNT: int = 50
const SPARKLE_LIFETIME: float = 1.6

@onready var _confetti: CPUParticles2D = $Confetti
@onready var _card: PanelContainer = $CenterContainer/Card
@onready var _title_label: Label = $CenterContainer/Card/MarginContainer/Content/TitleLabel
@onready var _gold_label: Label = $CenterContainer/Card/MarginContainer/Content/GoldLabel
@onready var _surplus_label: Label = $CenterContainer/Card/MarginContainer/Content/SurplusLabel
@onready var _proceed_button: Button = $CenterContainer/Card/MarginContainer/Content/ProceedButton

var _button_pulse_tween: Tween = null


func _ready() -> void:
	_apply_theme_styling()
	_proceed_button.pressed.connect(_on_proceed_pressed)


func _apply_theme_styling() -> void:
	_card.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_MODAL, _UITheme.SCORE_GOLD, 2)
	)
	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)

	var breakdown_title: Label = $CenterContainer/Card/MarginContainer/Content/BreakdownTitle
	breakdown_title.add_theme_font_override("font", _UITheme.font_display())
	breakdown_title.add_theme_font_size_override("font_size", 12)
	breakdown_title.add_theme_color_override("font_color", _UITheme.ACTION_CYAN)

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
	_title_label.text = "LOOP CLEARED!" if is_loop else "STAGE CLEARED!"
	_surplus_label.visible = surplus > 0
	if surplus > 0:
		_surplus_label.text = "Surplus: +0"

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
	tween.tween_callback(func() -> void:
		_animate_value(_gold_label, "Gold Earned: +", bonus_gold, "g")
		if surplus > 0:
			_animate_value(_surplus_label, "Surplus: +", surplus, "")
	)
	tween.tween_interval(0.35)
	tween.tween_callback(func() -> void:
		_proceed_button.modulate.a = 1.0
		_proceed_button.disabled = false
		_start_button_pulse()
	)


func _animate_value(target_label: Label, prefix: String, value: int, suffix: String) -> void:
	var tween: Tween = create_tween()
	tween.tween_method(
		func(v: float) -> void:
			target_label.text = "%s%d%s" % [prefix, int(v), suffix],
		0.0,
		float(value),
		COUNT_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _start_button_pulse() -> void:
	if _button_pulse_tween != null and _button_pulse_tween.is_valid():
		return
	_proceed_button.scale = Vector2.ONE
	_button_pulse_tween = create_tween().set_loops()
	_button_pulse_tween.tween_property(_proceed_button, "scale", Vector2(1.03, 1.03), 0.9)
	_button_pulse_tween.tween_property(_proceed_button, "scale", Vector2.ONE, 0.9)


func _on_proceed_pressed() -> void:
	if _button_pulse_tween != null and _button_pulse_tween.is_valid():
		_button_pulse_tween.kill()
	proceed_requested.emit()


func _spawn_sparkle_wave() -> void:
	get_tree().create_timer(SPARKLE_DELAY).timeout.connect(func() -> void:
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
		get_tree().create_timer(SPARKLE_LIFETIME + 0.5).timeout.connect(func() -> void:
			if is_instance_valid(sparkle):
				sparkle.queue_free()
		)
	)
