extends ColorRect
## Pick-1-of-3 dice reward overlay shown after every Normal Stage clear.
## Generates 3 random dice at rarity tiers influenced by the player's luck stat.

signal reward_chosen(die: DiceData)

const _UITheme := preload("res://Scripts/UITheme.gd")

const BACKDROP_ALPHA: float = 0.52
const CARD_WIDTH: int = 220
const CARD_HEIGHT: int = 320
const FACE_GRID_COLUMNS: int = 3
const CARD_REVEAL_STAGGER: float = 0.08
const CARD_REVEAL_DURATION: float = 0.22
const PICK_FLASH_DURATION: float = 0.2

# Rarity weights (base, per-luck-point adjustment).
const BASE_GREY: float = 0.50
const BASE_GREEN: float = 0.30
const BASE_BLUE: float = 0.15
const BASE_PURPLE: float = 0.05

const LUCK_GREY_DELTA: float = -0.05
const LUCK_GREEN_DELTA: float = 0.02
const LUCK_BLUE_DELTA: float = 0.02
const LUCK_PURPLE_DELTA: float = 0.01

const MIN_GREY_WEIGHT: float = 0.10

# Dice pools per rarity tier — factory method names.
const GREY_POOL: Array[String] = ["make_simple_d6", "make_standard_d6", "make_blank_canvas_d6"]
const GREEN_POOL: Array[String] = ["make_lucky_d6", "make_heavy_d6", "make_fortune_d6"]
const BLUE_POOL: Array[String] = ["make_gambler_d6", "make_golden_d6", "make_insurance_d6"]
const PURPLE_POOL: Array[String] = ["make_explosive_d6", "make_pink_d6"]

@onready var _title_label: Label = $CenterContainer/Card/MarginContainer/Content/TitleLabel
@onready var _hint_label: Label = $CenterContainer/Card/MarginContainer/Content/HintLabel
@onready var _card_row: HBoxContainer = $CenterContainer/Card/MarginContainer/Content/CardRow
@onready var _card_panel: PanelContainer = $CenterContainer/Card
@onready var _content: VBoxContainer = $CenterContainer/Card/MarginContainer/Content

var _cards: Array[PanelContainer] = []
var _dice_options: Array[DiceData] = []
var _reroll_button: Button = null
var _current_luck: int = 0


func _ready() -> void:
	_apply_theme_styling()
	_build_reroll_button()


func _apply_theme_styling() -> void:
	_card_panel.add_theme_stylebox_override(
		"panel",
		_UITheme.make_stage_family_panel_style("board", _UITheme.CORNER_RADIUS_MODAL, 2)
	)
	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_TITLE_COLOR)
	_hint_label.add_theme_font_override("font", _UITheme.font_body())
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_CONTEXT_COLOR)


func open(luck: int) -> void:
	_current_luck = luck
	_rebuild_reward_cards(luck)
	if _reroll_button != null:
		_reroll_button.visible = GameManager.prestige_reward_reroll_available
		_reroll_button.disabled = not GameManager.prestige_reward_reroll_available

	# Animate entrance.
	color = Color(0, 0, 0, 0)
	_card_panel.modulate.a = 0.0
	_card_panel.scale = Vector2(1.15, 1.15)
	_card_panel.pivot_offset = _card_panel.size * 0.5

	var tween: Tween = create_tween()
	tween.tween_property(self, "color:a", BACKDROP_ALPHA, 0.2)
	tween.parallel().tween_property(_card_panel, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(_card_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _rebuild_reward_cards(luck: int) -> void:
	_dice_options.clear()
	for _card: PanelContainer in _cards:
		_card.queue_free()
	_cards.clear()

	var weights: Array[float] = _calc_weights(luck)
	var rarity_bonus: int = GameManager.consume_next_reward_rarity_bonus()
	for i: int in 3:
		var die: DiceData = null
		if i == 0:
			die = DiceData.make_reroll_chaser_d6(mini(2, maxi(0, GameManager.current_loop - 1)))
		else:
			var rarity: DiceData.Rarity = _roll_rarity(weights)
			rarity = _apply_rarity_bonus(rarity, rarity_bonus)
			die = _pick_die_for_rarity(rarity)
		_dice_options.append(die)
		var card: PanelContainer = _build_card(die, i)
		_card_row.add_child(card)
		_cards.append(card)

	for index: int in _cards.size():
		var card: PanelContainer = _cards[index]
		card.modulate.a = 0.0
		card.position.y += 18.0
		card.scale = Vector2(0.94, 0.94)

	var tween: Tween = create_tween()
	for index: int in _cards.size():
		tween.tween_callback(Callable(self, "_reveal_option_card_by_index").bind(index)).set_delay(CARD_REVEAL_STAGGER * index)

func _build_reroll_button() -> void:
	_reroll_button = Button.new()
	_reroll_button.text = "Reroll Choices"
	_reroll_button.custom_minimum_size = Vector2(220, 38)
	_reroll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reroll_button.visible = false
	_reroll_button.add_theme_font_override("font", _UITheme.font_display())
	_reroll_button.add_theme_font_size_override("font_size", 12)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	_content.add_child(_reroll_button)


func _on_reroll_pressed() -> void:
	if not GameManager.prestige_reward_reroll_available:
		return
	GameManager.apply_prestige_reward_reroll_used()
	_rebuild_reward_cards(_current_luck)
	if _reroll_button != null:
		_reroll_button.visible = false


# ---------------------------------------------------------------------------
# Rarity logic
# ---------------------------------------------------------------------------

static func _calc_weights(luck: int) -> Array[float]:
	var grey: float = maxf(MIN_GREY_WEIGHT, BASE_GREY + luck * LUCK_GREY_DELTA)
	var green: float = maxf(0.0, BASE_GREEN + luck * LUCK_GREEN_DELTA)
	var blue: float = maxf(0.0, BASE_BLUE + luck * LUCK_BLUE_DELTA)
	var purple: float = maxf(0.0, BASE_PURPLE + luck * LUCK_PURPLE_DELTA)
	var total: float = grey + green + blue + purple
	return [grey / total, green / total, blue / total, purple / total]


static func _roll_rarity(weights: Array[float]) -> DiceData.Rarity:
	var roll: float = GameManager.rng_randf("reward")
	var cumulative: float = 0.0
	if roll < weights[0]:
		return DiceData.Rarity.GREY
	cumulative += weights[0]
	if roll < cumulative + weights[1]:
		return DiceData.Rarity.GREEN
	cumulative += weights[1]
	if roll < cumulative + weights[2]:
		return DiceData.Rarity.BLUE
	return DiceData.Rarity.PURPLE


static func _pick_die_for_rarity(rarity: DiceData.Rarity) -> DiceData:
	var pool: Array[String] = []
	match rarity:
		DiceData.Rarity.GREY:
			pool = GREY_POOL
		DiceData.Rarity.GREEN:
			pool = GREEN_POOL
		DiceData.Rarity.BLUE:
			pool = BLUE_POOL
		DiceData.Rarity.PURPLE:
			pool = PURPLE_POOL
	var index: int = GameManager.rng_pick_index("reward", pool.size())
	if index < 0:
		return DiceData.make_standard_d6()
	var method_name: String = pool[index]
	var die: DiceData = Callable(DiceData, method_name).call() as DiceData
	return die


static func _apply_rarity_bonus(rarity: DiceData.Rarity, bonus: int) -> DiceData.Rarity:
	return clampi(int(rarity) + maxi(0, bonus), DiceData.Rarity.GREY, DiceData.Rarity.PURPLE) as DiceData.Rarity


# ---------------------------------------------------------------------------
# Card UI
# ---------------------------------------------------------------------------

func _build_card(die: DiceData, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)

	var rarity_color: Color = DiceData.get_rarity_color(die.rarity)
	card.add_theme_stylebox_override(
		"panel",
		_UITheme.make_semantic_frame_panel(_UITheme.SURFACE_ASH, rarity_color, 12, 3)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Rarity label
	var rarity_label := Label.new()
	rarity_label.text = _rarity_name(die.rarity)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_override("font", _UITheme.font_body())
	rarity_label.add_theme_font_size_override("font_size", 11)
	rarity_label.add_theme_color_override("font_color", rarity_color)
	vbox.add_child(rarity_label)

	# Die name
	var name_label := Label.new()
	name_label.text = die.get_display_name()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", _UITheme.font_stats())
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)
	vbox.add_child(name_label)

	if die.is_reroll_evolving():
		var tier_label := Label.new()
		tier_label.text = "Evolves from rerolls"
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_label.add_theme_font_override("font", _UITheme.font_mono())
		tier_label.add_theme_font_size_override("font_size", 11)
		tier_label.add_theme_color_override("font_color", _UITheme.ACTION_CYAN)
		vbox.add_child(tier_label)

	# Face grid
	var grid := GridContainer.new()
	grid.columns = FACE_GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)

	for face: DiceFaceData in die.faces:
		var face_label := Label.new()
		face_label.text = face.get_display_text()
		face_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		face_label.custom_minimum_size = Vector2(52, 32)
		face_label.add_theme_font_override("font", _UITheme.font_mono())
		face_label.add_theme_font_size_override("font_size", 14)
		face_label.add_theme_color_override("font_color", _face_color(face))
		var face_bg := PanelContainer.new()
		face_bg.add_theme_stylebox_override(
			"panel",
			_UITheme.make_panel_stylebox(_UITheme.FACE_INSET_SURFACE, 4, _UITheme.FRAME_DEFAULT, 1)
		)
		face_bg.add_child(face_label)
		grid.add_child(face_bg)

	# Pick button
	var pick_button := Button.new()
	pick_button.text = "PICK"
	pick_button.custom_minimum_size = Vector2(0, 44)
	pick_button.add_theme_font_override("font", _UITheme.font_display())
	pick_button.add_theme_font_size_override("font_size", 13)
	pick_button.focus_mode = Control.FOCUS_NONE
	pick_button.pressed.connect(_on_card_picked.bind(index))
	vbox.add_child(pick_button)

	return card


func _on_card_picked(index: int) -> void:
	# Animate: selected card scales up, others fade out.
	for i: int in _cards.size():
		var card: PanelContainer = _cards[i]
		if i == index:
			var tween: Tween = create_tween()
			tween.tween_property(card, "scale", Vector2(1.08, 1.08), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(card, "modulate", Color(1.08, 1.08, 1.08, 1.0), PICK_FLASH_DURATION * 0.5)
			tween.tween_property(card, "modulate", Color.WHITE, PICK_FLASH_DURATION * 0.5)
		else:
			var tween: Tween = create_tween()
			tween.tween_property(card, "modulate:a", 0.2, 0.2)

	# Disable all buttons.
	for card: PanelContainer in _cards:
		var btn: Button = _find_button(card)
		if btn != null:
			btn.disabled = true

	# Emit after short delay, then self-destruct.
	var exit_tween: Tween = create_tween()
	exit_tween.tween_interval(0.5)
	exit_tween.tween_callback(Callable(self, "_emit_reward_and_free").bind(index))


func _reveal_option_card(card: PanelContainer) -> void:
	var tween: Tween = create_tween()
	var end_y: float = card.position.y - 18.0
	tween.tween_property(card, "modulate:a", 1.0, CARD_REVEAL_DURATION)
	tween.parallel().tween_property(card, "position:y", end_y, CARD_REVEAL_DURATION).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card, "scale", Vector2.ONE, CARD_REVEAL_DURATION).set_ease(Tween.EASE_OUT)


func _reveal_option_card_by_index(index: int) -> void:
	if index < 0 or index >= _cards.size():
		return
	var card: PanelContainer = _cards[index]
	if not is_instance_valid(card):
		return
	_reveal_option_card(card)


func _emit_reward_and_free(index: int) -> void:
	if index >= 0 and index < _dice_options.size():
		reward_chosen.emit(_dice_options[index])
	queue_free()


func _find_button(node: Node) -> Button:
	if node is Button:
		return node as Button
	for child: Node in node.get_children():
		var btn: Button = _find_button(child)
		if btn != null:
			return btn
	return null


static func _rarity_name(rarity: DiceData.Rarity) -> String:
	match rarity:
		DiceData.Rarity.GREY:
			return "COMMON"
		DiceData.Rarity.GREEN:
			return "UNCOMMON"
		DiceData.Rarity.BLUE:
			return "RARE"
		DiceData.Rarity.PURPLE:
			return "EPIC"
	return "COMMON"


static func _face_color(face: DiceFaceData) -> Color:
	match face.type:
		DiceFaceData.FaceType.STOP, DiceFaceData.FaceType.CURSED_STOP:
			return _UITheme.STATUS_DANGER
		DiceFaceData.FaceType.BLANK:
			return _UITheme.MUTED_TEXT
		DiceFaceData.FaceType.SHIELD:
			return _UITheme.ACTION_CYAN
		DiceFaceData.FaceType.MULTIPLY, DiceFaceData.FaceType.MULTIPLY_LEFT:
			return _UITheme.SCORE_GOLD
		DiceFaceData.FaceType.EXPLODE:
			return _UITheme.EXPLOSION_ORANGE
		DiceFaceData.FaceType.INSURANCE:
			return _UITheme.STATUS_INFO
		DiceFaceData.FaceType.LUCK:
			return _UITheme.SUCCESS_GREEN
		DiceFaceData.FaceType.HEART:
			return _UITheme.ROSE_ACCENT
	return _UITheme.BRIGHT_TEXT
