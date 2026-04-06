extends ColorRect
## Random Event overlay — player picks between three bargains.
## Instantiated at runtime by RollPhase when visiting a RANDOM_EVENT node.

signal event_resolved(summary: String, status_color: Color)

const _UITheme := preload("res://Scripts/UITheme.gd")

const BACKDROP_ALPHA: float = 0.72
const CARD_WIDTH: int = 228
const CARD_HEIGHT: int = 248
const FACE_GRID_COLUMNS: int = 3
const RESULT_CARD_WIDTH: int = 220
const RESULT_CARD_HEIGHT: int = 260
const RESULT_TRANSITION_DELAY: float = 0.45
const RESULT_CLOSE_DELAY: float = 0.2

# ---------------------------------------------------------------------------
# Event definitions
# ---------------------------------------------------------------------------

enum EffectType {
	BOOST_NUMBERS,
	GAIN_RANDOM_DICE,
	FREE_BUST,
	BOOST_SHIELDS,
	GAIN_GOLD,
	LOSE_DIE,
	ADD_CURSED_STOP,
	BOOST_TARGETS,
	LOSE_LIFE,
	LOSE_GOLD,
	GAIN_LUCK,
	GAIN_REROUTE,
	LOSE_HEAVY_GOLD,
	DOUBLE_CURSED_STOP,
	RESET_MOMENTUM,
	SET_NEXT_STAGE_TARGET_MULTIPLIER,
	SET_NEXT_STAGE_FIRST_BANK_GOLD_MULTIPLIER,
	SET_NEXT_STAGE_CLEAR_GOLD_MULTIPLIER,
	GAIN_STOP_SHARDS,
	SET_NEXT_STAGE_STARTING_STOP_PRESSURE,
}

const CHOICE_SAFE: String = "SAFE VALUE"
const CHOICE_BARGAIN: String = "BARGAIN"
const CHOICE_PREMIUM: String = "HIGH RISK"

@onready var _title_label: Label = $CenterContainer/Card/MarginContainer/Content/TitleLabel
@onready var _flavor_label: Label = $CenterContainer/Card/MarginContainer/Content/FlavorLabel
@onready var _choice_row: HBoxContainer = $CenterContainer/Card/MarginContainer/Content/ChoiceRow
@onready var _card_panel: PanelContainer = $CenterContainer/Card
@onready var _content: VBoxContainer = $CenterContainer/Card/MarginContainer/Content

var _current_event: Dictionary = {}
var _choice_cards: Array[PanelContainer] = []
var _resolved: bool = false
var _continue_button: Button = null
var _pending_summary: String = ""
var _pending_status_color: Color = _UITheme.STATUS_NEUTRAL


func _ready() -> void:
	_apply_theme_styling()


func _apply_theme_styling() -> void:
	_card_panel.add_theme_stylebox_override(
		"panel",
		_UITheme.make_stage_family_panel_style("board", _UITheme.CORNER_RADIUS_MODAL, 2)
	)
	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_TITLE_COLOR)
	_flavor_label.add_theme_font_override("font", _UITheme.font_body())
	_flavor_label.add_theme_font_size_override("font_size", 14)
	_flavor_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_CONTEXT_COLOR)


func open() -> void:
	_resolved = false
	_pending_summary = ""
	_pending_status_color = _UITheme.STATUS_NEUTRAL
	_prepare_choice_surface()
	_current_event = _pick_event_definition()
	_apply_event_copy(_current_event)
	_build_choice_cards()
	_play_intro_animation()


func open_from_resume(snapshot: Dictionary) -> void:
	_resolved = false
	_pending_summary = ""
	_pending_status_color = _UITheme.STATUS_NEUTRAL
	_prepare_choice_surface()
	_current_event = (snapshot.get("current_event", {}) as Dictionary).duplicate(true)
	if _current_event.is_empty():
		open()
		return
	_apply_event_copy(_current_event)
	_build_choice_cards()
	_play_intro_animation()


func build_resume_snapshot() -> Dictionary:
	return {
		"current_event": _current_event.duplicate(true),
	}


func _apply_event_copy(event_data: Dictionary) -> void:
	_title_label.text = event_data.get("title", "RANDOM EVENT") as String
	_flavor_label.text = event_data.get("flavor", "Choose your bargain.") as String


func _prepare_choice_surface() -> void:
	_clear_choice_cards()
	_remove_continue_button()


func _build_choice_cards() -> void:
	for choice_index: int in (_current_event.get("choices", []) as Array).size():
		var choice: Dictionary = ((_current_event.get("choices", []) as Array)[choice_index] as Dictionary).duplicate(true)
		var choice_card: PanelContainer = _build_choice_card(choice, choice_index)
		_choice_row.add_child(choice_card)
		_choice_cards.append(choice_card)


func _play_intro_animation() -> void:
	# Entrance animation.
	color = Color(0, 0, 0, 0)
	_card_panel.modulate.a = 0.0
	_card_panel.scale = Vector2(1.12, 1.12)
	_card_panel.pivot_offset = _card_panel.size * 0.5

	var tween: Tween = create_tween()
	tween.tween_property(self, "color:a", BACKDROP_ALPHA, 0.2)
	tween.parallel().tween_property(_card_panel, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(_card_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------------------
# Card building
# ---------------------------------------------------------------------------

func _build_choice_card(choice: Dictionary, choice_index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)

	var accent: Color = _get_color(choice.get("color_key", "BRIGHT_TEXT") as String)
	var border_color: Color = _choice_border_color(choice)
	card.add_theme_stylebox_override(
		"panel",
		_UITheme.make_semantic_frame_panel(_UITheme.SURFACE_ASH, border_color, 12, 3)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Category label.
	var cat_label := Label.new()
	cat_label.text = choice.get("category", CHOICE_SAFE) as String
	cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_label.add_theme_font_override("font", _UITheme.font_display())
	cat_label.add_theme_font_size_override("font_size", 11)
	cat_label.add_theme_color_override("font_color", border_color)
	vbox.add_child(cat_label)

	# Icon.
	var icon_label := Label.new()
	icon_label.text = choice.get("icon", "?") as String
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 36)
	vbox.add_child(icon_label)

	# Choice name.
	var name_label := Label.new()
	name_label.text = choice.get("name", "") as String
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", _UITheme.font_stats())
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", accent)
	vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = _build_choice_description(choice)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_override("font", _UITheme.font_body())
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)
	vbox.add_child(desc_label)

	var hint_text: String = _choice_hint(choice)
	if not hint_text.is_empty():
		var hint_label := Label.new()
		hint_label.text = hint_text
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.add_theme_font_override("font", _UITheme.font_mono())
		hint_label.add_theme_font_size_override("font_size", 11)
		hint_label.add_theme_color_override("font_color", border_color)
		vbox.add_child(hint_label)

	# Choose button.
	var btn := Button.new()
	btn.text = "Choose"
	btn.custom_minimum_size = Vector2(0, 40)
	btn.add_theme_font_override("font", _UITheme.font_display())
	btn.add_theme_font_size_override("font_size", 12)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_choice_made.bind(choice_index))
	vbox.add_child(btn)

	return card


# ---------------------------------------------------------------------------
# Selection handling
# ---------------------------------------------------------------------------

func _on_choice_made(choice_index: int) -> void:
	if _resolved:
		return
	_resolved = true

	var choices: Array = _current_event.get("choices", []) as Array
	var chosen_choice: Dictionary = (choices[choice_index] as Dictionary).duplicate(true)
	var effect_result: Dictionary = _apply_choice_effects(chosen_choice)
	var summary: String = _build_effect_summary(chosen_choice, effect_result)
	var status_color: Color = _choice_status_color(chosen_choice)
	_pending_summary = summary
	_pending_status_color = status_color
	_disable_choice_buttons()

	# Animate: chosen card scales up, other fades out.
	for i: int in _choice_cards.size():
		var card: PanelContainer = _choice_cards[i]
		if i == choice_index:
			var tw: Tween = create_tween()
			tw.tween_property(card, "scale", Vector2(1.06, 1.06), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			var tw: Tween = create_tween()
			tw.tween_property(card, "modulate:a", 0.0, 0.25)

	if _has_gained_dice_result(effect_result):
		var result_tween: Tween = create_tween()
		result_tween.tween_interval(RESULT_TRANSITION_DELAY)
		result_tween.tween_callback(_show_reward_result.bind(chosen_choice, effect_result))
		return

	_queue_close(summary, status_color)


func _queue_close(summary: String, status_color: Color) -> void:
	var close_tween: Tween = create_tween()
	close_tween.tween_interval(RESULT_CLOSE_DELAY)
	close_tween.tween_property(self, "color:a", 0.0, 0.2)
	close_tween.parallel().tween_property(_card_panel, "modulate:a", 0.0, 0.2)
	close_tween.tween_callback(_emit_event_resolved.bind(summary, status_color))


func _emit_event_resolved(summary: String, status_color: Color) -> void:
	event_resolved.emit(summary, status_color)


# ---------------------------------------------------------------------------
# Effect application
# ---------------------------------------------------------------------------

func _apply_choice_effects(choice: Dictionary) -> Dictionary:
	var result: Dictionary = {"gained_dice": []}
	for effect_variant: Variant in choice.get("effects", []) as Array:
		if not (effect_variant is Dictionary):
			continue
		var effect_result: Dictionary = _apply_effect(effect_variant as Dictionary)
		for die_variant: Variant in effect_result.get("gained_dice", []):
			(result["gained_dice"] as Array).append(die_variant)
	return result


func _apply_effect(effect: Dictionary) -> Dictionary:
	var effect_type: EffectType = effect.get("type", EffectType.GAIN_GOLD) as EffectType
	match effect_type:
		EffectType.BOOST_NUMBERS:
			_boost_number_faces(int(effect.get("amount", 1)))
		EffectType.GAIN_RANDOM_DICE:
			return {"gained_dice": _gain_random_dice(int(effect.get("count", 1)))}
		EffectType.FREE_BUST:
			GameManager.set_event_free_bust(true)
		EffectType.BOOST_SHIELDS:
			_boost_shield_faces(int(effect.get("amount", 1)))
		EffectType.GAIN_GOLD:
			GameManager.add_gold(int(effect.get("amount", 30)))
		EffectType.GAIN_LUCK:
			GameManager.add_luck(int(effect.get("amount", 3)))
		EffectType.GAIN_REROUTE:
			GameManager.prestige_reroute_uses += int(effect.get("amount", 1))
		EffectType.LOSE_DIE:
			for _count: int in range(int(effect.get("count", 1))):
				_lose_random_die()
		EffectType.ADD_CURSED_STOP:
			for _count: int in range(int(effect.get("count", 1))):
				_add_cursed_stop_to_random_die()
		EffectType.BOOST_TARGETS:
			GameManager.apply_event_target_multiplier(float(effect.get("multiplier", 1.15)))
		EffectType.LOSE_LIFE:
			GameManager.adjust_stage_hand_cap(-int(effect.get("amount", 1)))
		EffectType.LOSE_GOLD:
			GameManager.remove_gold(int(effect.get("amount", 20)))
		EffectType.LOSE_HEAVY_GOLD:
			GameManager.remove_gold(int(effect.get("amount", 35)))
		EffectType.DOUBLE_CURSED_STOP:
			_add_cursed_stop_to_random_die()
			_add_cursed_stop_to_random_die()
		EffectType.RESET_MOMENTUM:
			GameManager.reset_momentum()
		EffectType.SET_NEXT_STAGE_TARGET_MULTIPLIER:
			GameManager.set_next_stage_target_multiplier(float(effect.get("multiplier", 1.15)))
		EffectType.SET_NEXT_STAGE_FIRST_BANK_GOLD_MULTIPLIER:
			GameManager.set_next_stage_first_bank_gold_multiplier(float(effect.get("multiplier", 1.35)))
		EffectType.SET_NEXT_STAGE_CLEAR_GOLD_MULTIPLIER:
			GameManager.set_next_stage_clear_gold_multiplier(float(effect.get("multiplier", 2.0)))
		EffectType.GAIN_STOP_SHARDS:
			GameManager.add_run_stop_shards(int(effect.get("amount", 10)))
		EffectType.SET_NEXT_STAGE_STARTING_STOP_PRESSURE:
			GameManager.set_next_stage_starting_stop_pressure(int(effect.get("amount", 1)))
	return {}


func _pick_event_definition() -> Dictionary:
	var event_pool: Array[Dictionary] = _build_event_pool()
	var event_index: int = GameManager.rng_pick_index("event", event_pool.size())
	if event_index < 0:
		event_index = 0
	return (event_pool[event_index] as Dictionary).duplicate(true)


func _build_event_pool() -> Array[Dictionary]:
	return [
		{
			"title": "THE COLLECTOR",
			"flavor": "A lacquered broker offers clean money, blood money, and one dangerous gift.",
			"choices": [
				{
					"category": CHOICE_SAFE,
					"name": "Take the Cash",
					"icon": "💰",
					"color_key": "SCORE_GOLD",
					"upside": "+20g now",
					"downside": "No extra risk",
					"summary": "EVENT: The Collector paid 20g",
					"hint_type": "low_gold",
					"effects": [{"type": EffectType.GAIN_GOLD, "amount": 20}],
				},
				{
					"category": CHOICE_BARGAIN,
					"name": "Sell a Die",
					"icon": "🗡",
					"color_key": "EXPLOSION_ORANGE",
					"upside": "+55g immediately",
					"downside": "Lose 1 random die",
					"summary": "EVENT: The Collector bought a die for 55g",
					"hint_type": "wide_pool",
					"effects": [
						{"type": EffectType.LOSE_DIE, "count": 1},
						{"type": EffectType.GAIN_GOLD, "amount": 55},
					],
				},
				{
					"category": CHOICE_PREMIUM,
					"name": "Take the Marked Prize",
					"icon": "🎲",
					"color_key": "ACTION_CYAN",
					"upside": "+1 random die",
					"downside": "Next stage target +12%",
					"summary": "EVENT: The Collector marked your next stage for a premium die",
					"hint_type": "thin_pool",
					"effects": [
						{"type": EffectType.GAIN_RANDOM_DICE, "count": 1},
						{"type": EffectType.BOOST_TARGETS, "multiplier": 1.12},
					],
				},
			],
		},
		{
			"title": "BLOOD TOLL",
			"flavor": "The house cashier smiles like a surgeon and slides over three receipts.",
			"choices": [
				{
					"category": CHOICE_SAFE,
					"name": "Hold the Line",
					"icon": "🛡",
					"color_key": "ACTION_CYAN",
					"upside": "Next bust this loop is free",
					"downside": "No extra payout",
					"summary": "EVENT: The house granted a free bust",
					"hint_type": "fragile_run",
					"effects": [{"type": EffectType.FREE_BUST}],
				},
				{
					"category": CHOICE_BARGAIN,
					"name": "Bleed for Safety",
					"icon": "❤",
					"color_key": "DANGER_RED",
					"upside": "+40g and next bust free",
					"downside": "Lose 1 hand",
					"summary": "EVENT: You paid a hand for 40g and a free bust",
					"hint_type": "high_hands",
					"effects": [
						{"type": EffectType.LOSE_LIFE, "amount": 1},
						{"type": EffectType.GAIN_GOLD, "amount": 40},
						{"type": EffectType.FREE_BUST},
					],
				},
				{
					"category": CHOICE_PREMIUM,
					"name": "Cut Deep",
					"icon": "☄",
					"color_key": "NEON_PURPLE",
					"upside": "+2 LUCK and +25g",
					"downside": "Lose 1 hand",
					"summary": "EVENT: Blood Toll traded a hand for LUCK and gold",
					"hint_type": "fortune_build",
					"effects": [
						{"type": EffectType.LOSE_LIFE, "amount": 1},
						{"type": EffectType.GAIN_LUCK, "amount": 2},
						{"type": EffectType.GAIN_GOLD, "amount": 25},
					],
				},
			],
		},
		{
			"title": "CROOKED SHRINE",
			"flavor": "The altar promises luck, provided you stop asking where it came from.",
			"choices": [
				{
					"category": CHOICE_SAFE,
					"name": "Pocket the Charm",
					"icon": "🍀",
					"color_key": "SUCCESS_GREEN",
					"upside": "+1 LUCK",
					"downside": "No added drawback",
					"summary": "EVENT: The shrine granted 1 LUCK",
					"hint_type": "fortune_build",
					"effects": [{"type": EffectType.GAIN_LUCK, "amount": 1}],
				},
				{
					"category": CHOICE_BARGAIN,
					"name": "Feed the Idol",
					"icon": "📈",
					"color_key": "EXPLOSION_ORANGE",
					"upside": "+4 LUCK",
					"downside": "All stage targets this loop +10%",
					"summary": "EVENT: The shrine traded a harder loop for 4 LUCK",
					"hint_type": "fortune_build",
					"effects": [
						{"type": EffectType.BOOST_TARGETS, "multiplier": 1.10},
						{"type": EffectType.GAIN_LUCK, "amount": 4},
					],
				},
				{
					"category": CHOICE_PREMIUM,
					"name": "Take the Hex",
					"icon": "☠",
					"color_key": "NEON_PURPLE",
					"upside": "+5 LUCK and +20g",
					"downside": "A random die gains a Cursed Stop",
					"summary": "EVENT: The shrine cursed a die for luck and gold",
					"hint_type": "fortune_build",
					"effects": [
						{"type": EffectType.ADD_CURSED_STOP, "count": 1},
						{"type": EffectType.GAIN_LUCK, "amount": 5},
						{"type": EffectType.GAIN_GOLD, "amount": 20},
					],
				},
			],
		},
		{
			"title": "SHIELD CHAPEL",
			"flavor": "A candlelit bunker offers sanctuary, but every wall demands a price.",
			"choices": [
				{
					"category": CHOICE_SAFE,
					"name": "Take Cover",
					"icon": "🛡",
					"color_key": "ACTION_CYAN",
					"upside": "+1 to all SHIELD faces this loop",
					"downside": "No bonus beyond defense",
					"summary": "EVENT: The chapel reinforced your SHIELD faces",
					"hint_type": "shield_build",
					"effects": [{"type": EffectType.BOOST_SHIELDS, "amount": 1}],
				},
				{
					"category": CHOICE_BARGAIN,
					"name": "Turtle Up",
					"icon": "⛨",
					"color_key": "ACTION_CYAN",
					"upside": "+2 to all SHIELD faces this loop",
					"downside": "-1 to all NUMBER faces this loop",
					"summary": "EVENT: The chapel traded offense for stronger shields",
					"hint_type": "shield_build",
					"effects": [
						{"type": EffectType.BOOST_NUMBERS, "amount": -1},
						{"type": EffectType.BOOST_SHIELDS, "amount": 2},
					],
				},
				{
					"category": CHOICE_PREMIUM,
					"name": "War Fund",
					"icon": "💰",
					"color_key": "SCORE_GOLD",
					"upside": "+20g and +1 to all SHIELD faces this loop",
					"downside": "Next stage target +12%",
					"summary": "EVENT: The chapel bankrolled a harder stage",
					"hint_type": "shield_build",
					"effects": [
						{"type": EffectType.BOOST_TARGETS, "multiplier": 1.12},
						{"type": EffectType.BOOST_SHIELDS, "amount": 1},
						{"type": EffectType.GAIN_GOLD, "amount": 20},
					],
				},
			],
		},
		{
			"title": "LAST CALL",
			"flavor": "The pit boss offers one clean payout, one reset, and one debt against tomorrow.",
			"choices": [
				{
					"category": CHOICE_SAFE,
					"name": "Cash Out Quietly",
					"icon": "💰",
					"color_key": "SCORE_GOLD",
					"upside": "+25g now",
					"downside": "No extra leverage",
					"summary": "EVENT: Last Call paid out 25g",
					"hint_type": "low_gold",
					"effects": [{"type": EffectType.GAIN_GOLD, "amount": 25}],
				},
				{
					"category": CHOICE_BARGAIN,
					"name": "Reset the Heater",
					"icon": "♻",
					"color_key": "EXPLOSION_ORANGE",
					"upside": "+45g immediately",
					"downside": "Reset momentum",
					"summary": "EVENT: Last Call traded momentum for 45g",
					"hint_type": "momentum_high",
					"effects": [
						{"type": EffectType.RESET_MOMENTUM},
						{"type": EffectType.GAIN_GOLD, "amount": 45},
					],
				},
				{
					"category": CHOICE_PREMIUM,
					"name": "Borrow From Tomorrow",
					"icon": "⚡",
					"color_key": "ACTION_CYAN",
					"upside": "First bank next stage gains +35% gold",
					"downside": "Lose 15g now",
					"summary": "EVENT: Last Call staked your next stage bank for extra gold",
					"hint_type": "momentum_low",
					"effects": [
						{"type": EffectType.LOSE_GOLD, "amount": 15},
						{"type": EffectType.SET_NEXT_STAGE_FIRST_BANK_GOLD_MULTIPLIER, "multiplier": 1.35},
					],
				},
			],
		},
		{
			"title": "HOUSE ADVANTAGE",
			"flavor": "The floor manager offers a little money now or a more expensive table next round.",
			"choices": [
				{
					"category": CHOICE_SAFE,
					"name": "Take the Token",
					"icon": "🪙",
					"color_key": "SCORE_GOLD",
					"upside": "+20g now",
					"downside": "No extra upside",
					"summary": "EVENT: House Advantage paid out 20g",
					"hint_type": "low_gold",
					"effects": [{"type": EffectType.GAIN_GOLD, "amount": 20}],
				},
				{
					"category": CHOICE_BARGAIN,
					"name": "Play Up a Table",
					"icon": "📈",
					"color_key": "EXPLOSION_ORANGE",
					"upside": "+25g immediately",
					"downside": "Next stage target +15%",
					"summary": "EVENT: House Advantage raised the stakes for 25g",
					"effects": [
						{"type": EffectType.GAIN_GOLD, "amount": 25},
						{"type": EffectType.SET_NEXT_STAGE_TARGET_MULTIPLIER, "multiplier": 1.15},
					],
				},
				{
					"category": CHOICE_PREMIUM,
					"name": "Rig the Payout",
					"icon": "🎯",
					"color_key": "NEON_PURPLE",
					"upside": "Next stage clear reward gold is doubled",
					"downside": "Next stage target +15%",
					"summary": "EVENT: House Advantage rigged the next clear reward",
					"effects": [
						{"type": EffectType.SET_NEXT_STAGE_TARGET_MULTIPLIER, "multiplier": 1.15},
						{"type": EffectType.SET_NEXT_STAGE_CLEAR_GOLD_MULTIPLIER, "multiplier": 2.0},
					],
				},
			],
		},
		{
			"title": "STOP BROKER",
			"flavor": "A bookmaker in mirrored shades offers shards on the cheap, then names the catch.",
			"choices": [
				{
					"category": CHOICE_SAFE,
					"name": "Pocket the Chips",
					"icon": "🧩",
					"color_key": "ACTION_CYAN",
					"upside": "+10 stop shards",
					"downside": "No extra payout",
					"summary": "EVENT: Stop Broker paid 10 stop shards",
					"hint_type": "stop_build",
					"effects": [{"type": EffectType.GAIN_STOP_SHARDS, "amount": 10}],
				},
				{
					"category": CHOICE_BARGAIN,
					"name": "Carry the Mark",
					"icon": "☠",
					"color_key": "EXPLOSION_ORANGE",
					"upside": "+25 stop shards and +20g",
					"downside": "A random die gains a Cursed Stop",
					"summary": "EVENT: Stop Broker marked a die for shards and gold",
					"hint_type": "stop_build",
					"effects": [
						{"type": EffectType.ADD_CURSED_STOP, "count": 1},
						{"type": EffectType.GAIN_STOP_SHARDS, "amount": 25},
						{"type": EffectType.GAIN_GOLD, "amount": 20},
					],
				},
				{
					"category": CHOICE_PREMIUM,
					"name": "Open Under Pressure",
					"icon": "🔥",
					"color_key": "NEON_PURPLE",
					"upside": "+40 stop shards",
					"downside": "Next stage starts with +1 stop pressure",
					"summary": "EVENT: Stop Broker front-loaded the next stage for 40 stop shards",
					"hint_type": "shield_build",
					"effects": [
						{"type": EffectType.GAIN_STOP_SHARDS, "amount": 40},
						{"type": EffectType.SET_NEXT_STAGE_STARTING_STOP_PRESSURE, "amount": 1},
					],
				},
			],
		},
	]


func _build_effect_summary(choice: Dictionary, effect_result: Dictionary = {}) -> String:
	var summary: String = choice.get("summary", "EVENT: bargain resolved") as String
	var gained_dice: Array[DiceData] = _extract_gained_dice(effect_result)
	if gained_dice.is_empty():
		return summary
	var die_names: Array[String] = []
	for die: DiceData in gained_dice:
		die_names.append(die.dice_name)
	return "%s [%s]" % [summary, ", ".join(die_names)]


func _boost_number_faces(amount: int) -> void:
	for die: DiceData in GameManager.dice_pool:
		for face: DiceFaceData in die.faces:
			if face.type == DiceFaceData.FaceType.NUMBER:
				face.value = maxi(0, face.value + amount)


func _boost_shield_faces(amount: int) -> void:
	for die: DiceData in GameManager.dice_pool:
		for face: DiceFaceData in die.faces:
			if face.type == DiceFaceData.FaceType.SHIELD:
				face.value += amount


func _build_choice_description(choice: Dictionary) -> String:
	return "UP: %s\nDOWN: %s" % [
		choice.get("upside", "") as String,
		choice.get("downside", "") as String,
	]


func _choice_border_color(choice: Dictionary) -> Color:
	match choice.get("category", CHOICE_SAFE) as String:
		CHOICE_SAFE:
			return _UITheme.SUCCESS_GREEN
		CHOICE_BARGAIN:
			return _UITheme.SCORE_GOLD
		CHOICE_PREMIUM:
			return _UITheme.EXPLOSION_ORANGE
	return _UITheme.FRAME_DEFAULT


func _choice_status_color(choice: Dictionary) -> Color:
	return _choice_border_color(choice)


func _choice_hint(choice: Dictionary) -> String:
	match choice.get("hint_type", "") as String:
		"shield_build":
			if _has_shield_faces():
				return "GOOD WITH SHIELDS"
		"fortune_build":
			if _has_luck_synergy():
				return "GOOD WITH LUCK"
		"low_gold":
			if GameManager.gold <= 20:
				return "GOOD IF LOW GOLD"
		"wide_pool":
			if GameManager.dice_pool.size() >= 7:
				return "GOOD WITH EXTRA DICE"
		"thin_pool":
			if GameManager.dice_pool.size() <= 4:
				return "GOOD IF POOL IS THIN"
		"fragile_run":
			if GameManager.hands <= 2:
				return "GOOD IF YOU'RE HURT"
		"high_hands":
			if GameManager.hands >= 4:
				return "GOOD IF YOU HAVE HANDS TO SPARE"
		"momentum_high":
			if GameManager.momentum >= 2:
				return "GOOD IF MOMENTUM IS LOW VALUE"
		"momentum_low":
			if GameManager.momentum <= 1:
				return "GOOD IF YOU'RE RESETTING"
		"stop_build":
			if GameManager.held_stop_count > 0 or GameManager.chosen_archetype == GameManager.Archetype.STOP_COLLECTOR:
				return "GOOD WITH STOP BUILDS"
	return ""


func _has_shield_faces() -> bool:
	for die: DiceData in GameManager.dice_pool:
		for face: DiceFaceData in die.faces:
			if face.type == DiceFaceData.FaceType.SHIELD:
				return true
	return false


func _has_luck_synergy() -> bool:
	if GameManager.luck > 0:
		return true
	for die: DiceData in GameManager.dice_pool:
		for face: DiceFaceData in die.faces:
			if face.type == DiceFaceData.FaceType.LUCK:
				return true
	return false


func _gain_random_dice(count: int) -> Array[DiceData]:
	var factory_methods: Array[String] = [
		"make_simple_d6", "make_standard_d6", "make_lucky_d6", "make_blank_canvas_d6",
	]
	var gained_dice: Array[DiceData] = []
	for _i: int in count:
		var method_index: int = GameManager.rng_pick_index("event", factory_methods.size())
		if method_index < 0:
			method_index = 0
		var method: String = factory_methods[method_index]
		var die: DiceData = Callable(DiceData, method).call() as DiceData
		GameManager.add_dice(die)
		gained_dice.append(die)
	return gained_dice


func _clear_choice_cards() -> void:
	for card: PanelContainer in _choice_cards:
		if not is_instance_valid(card):
			continue
		if card.get_parent() != null:
			card.get_parent().remove_child(card)
		card.queue_free()
	_choice_cards.clear()


func _disable_choice_buttons() -> void:
	for card: PanelContainer in _choice_cards:
		var button: Button = _find_button(card)
		if button != null:
			button.disabled = true


func _show_reward_result(event: Dictionary, effect_result: Dictionary) -> void:
	var gained_dice: Array[DiceData] = _extract_gained_dice(effect_result)
	if gained_dice.is_empty():
		_queue_close(_pending_summary, _pending_status_color)
		return
	_clear_choice_cards()
	_remove_continue_button()
	_title_label.text = "REWARD GAINED"
	_flavor_label.text = "%s delivered these dice." % (event.get("name", "Your event") as String)
	for die: DiceData in gained_dice:
		var reward_card: PanelContainer = _build_reward_die_card(die)
		reward_card.modulate.a = 0.0
		reward_card.position.y += 14.0
		_choice_row.add_child(reward_card)
		_choice_cards.append(reward_card)
	var continue_button: Button = _build_continue_button()
	_content.add_child(continue_button)
	_continue_button = continue_button
	for index: int in _choice_cards.size():
		var reward_tween: Tween = create_tween()
		reward_tween.tween_interval(0.05 * index)
		reward_tween.tween_property(_choice_cards[index], "modulate:a", 1.0, 0.18)
		reward_tween.parallel().tween_property(_choice_cards[index], "position:y", _choice_cards[index].position.y - 14.0, 0.18).set_ease(Tween.EASE_OUT)


func _build_reward_die_card(die: DiceData) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(RESULT_CARD_WIDTH, RESULT_CARD_HEIGHT)
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

	var rarity_label := Label.new()
	rarity_label.text = _rarity_name(die.rarity)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_override("font", _UITheme.font_body())
	rarity_label.add_theme_font_size_override("font_size", 11)
	rarity_label.add_theme_color_override("font_color", rarity_color)
	vbox.add_child(rarity_label)

	var name_label := Label.new()
	name_label.text = die.dice_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", _UITheme.font_stats())
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)
	vbox.add_child(name_label)

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

	return card


func _build_continue_button() -> Button:
	var button := Button.new()
	button.text = "Continue"
	button.custom_minimum_size = Vector2(220, 40)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", _UITheme.font_display())
	button.add_theme_font_size_override("font_size", 12)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_result_continue_pressed)
	return button


func _on_result_continue_pressed() -> void:
	if _continue_button != null:
		_continue_button.disabled = true
	_queue_close(_pending_summary, _pending_status_color)


func _remove_continue_button() -> void:
	if _continue_button == null or not is_instance_valid(_continue_button):
		_continue_button = null
		return
	if _continue_button.get_parent() != null:
		_continue_button.get_parent().remove_child(_continue_button)
	_continue_button.queue_free()
	_continue_button = null


func _has_gained_dice_result(effect_result: Dictionary) -> bool:
	return not _extract_gained_dice(effect_result).is_empty()


func _extract_gained_dice(effect_result: Dictionary) -> Array[DiceData]:
	var gained_dice: Array[DiceData] = []
	for die_variant: Variant in effect_result.get("gained_dice", []):
		var die: DiceData = die_variant as DiceData
		if die != null:
			gained_dice.append(die)
	return gained_dice


func _find_button(node: Node) -> Button:
	if node is Button:
		return node as Button
	for child: Node in node.get_children():
		var button: Button = _find_button(child)
		if button != null:
			return button
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


func _lose_random_die() -> void:
	if GameManager.dice_pool.size() <= 1:
		return  # Never leave the player with 0 dice.
	var idx: int = GameManager.rng_pick_index("event", GameManager.dice_pool.size())
	if idx < 0:
		return
	GameManager.dice_pool.remove_at(idx)


func _add_cursed_stop_to_random_die() -> void:
	if GameManager.dice_pool.is_empty():
		return
	var die_index: int = GameManager.rng_pick_index("event", GameManager.dice_pool.size())
	if die_index < 0:
		return
	var die: DiceData = GameManager.dice_pool[die_index]
	var candidates: Array[int] = []
	for i: int in die.faces.size():
		if die.faces[i].type != DiceFaceData.FaceType.CURSED_STOP and die.faces[i].type != DiceFaceData.FaceType.STOP:
			candidates.append(i)
	if candidates.is_empty():
		return
	var target_index: int = GameManager.rng_pick_index("event", candidates.size())
	if target_index < 0:
		return
	var target: int = candidates[target_index]
	die.faces[target].type = DiceFaceData.FaceType.CURSED_STOP
	die.faces[target].value = 0


func _get_color(key: String) -> Color:
	match key:
		"SCORE_GOLD":
			return _UITheme.SCORE_GOLD
		"SUCCESS_GREEN":
			return _UITheme.SUCCESS_GREEN
		"ACTION_CYAN":
			return _UITheme.ACTION_CYAN
		"DANGER_RED":
			return _UITheme.DANGER_RED
		"NEON_PURPLE":
			return _UITheme.NEON_PURPLE
		"EXPLOSION_ORANGE":
			return _UITheme.EXPLOSION_ORANGE
	return _UITheme.BRIGHT_TEXT
