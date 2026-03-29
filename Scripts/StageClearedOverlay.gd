extends ColorRect
## Stage-clear overlay with proceed button.

signal proceed_requested

@onready var _content: VBoxContainer = $CenterContainer/Content
@onready var _title_label: Label = $CenterContainer/Content/TitleLabel
@onready var _gold_label: Label = $CenterContainer/Content/GoldLabel
@onready var _surplus_label: Label = $CenterContainer/Content/SurplusLabel
@onready var _proceed_button: Button = $CenterContainer/Content/ProceedButton


func _ready() -> void:
	_proceed_button.pressed.connect(_on_proceed_pressed)


func setup(bonus_gold: int, surplus: int, is_loop: bool) -> void:
	_title_label.text = "LOOP CLEARED!" if is_loop else "STAGE CLEARED!"
	_gold_label.text = "+%dg" % bonus_gold
	_surplus_label.visible = surplus > 0
	if surplus > 0:
		_surplus_label.text = "Surplus: +%d" % surplus
	color.a = 0.0
	_content.modulate.a = 0.0
	_proceed_button.modulate.a = 0.0
	_proceed_button.disabled = true
	var tween: Tween = create_tween()
	tween.tween_property(self, "color:a", 0.35, 0.2)
	tween.parallel().tween_property(_content, "modulate:a", 1.0, 0.2)
	tween.tween_callback(func() -> void:
		_proceed_button.modulate.a = 1.0
		_proceed_button.disabled = false
	)


func _on_proceed_pressed() -> void:
	proceed_requested.emit()
