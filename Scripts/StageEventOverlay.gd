extends ColorRect
## Random Event overlay — player picks a Blessing or a Curse.
## Instantiated at runtime by RollPhase when visiting a RANDOM_EVENT node.

signal event_resolved(summary: String, status_color: Color)

const _UITheme := preload("res://Scripts/UITheme.gd")

const BACKDROP_ALPHA: float = 0.72
const CARD_WIDTH: int = 280
const CARD_HEIGHT: int = 220
const FACE_GRID_COLUMNS: int = 3
const RESULT_CARD_WIDTH: int = 220
const RESULT_CARD_HEIGHT: int = 260
const RESULT_TRANSITION_DELAY: float = 0.45
const RESULT_CLOSE_DELAY: float = 0.2

# ---------------------------------------------------------------------------
# Event definitions
# ---------------------------------------------------------------------------

enum EffectType {
	BOOST_NUMBERS,       # +1 to all NUMBER faces this loop
	GAIN_RANDOM_DICE,    # Gain 2 random dice
	FREE_BUST,           # Next bust is free (absorb 1)
	BOOST_SHIELDS,       # All SHIELD faces gain +1 value
	GAIN_GOLD,           # +30g immediately
	LOSE_DIE,            # Lose 1 random die
	ADD_CURSED_STOP,     # Random die gets CURSED_STOP face
	BOOST_TARGETS,       # All targets +15% this loop
	LOSE_LIFE,           # Lose 1 life
	LOSE_GOLD,           # -20g (clamped to 0)
	GAIN_LUCK,           # +3 LUCK immediately
	GAIN_REROUTE,        # Gain 1 reroute token
	LOSE_HEAVY_GOLD,     # -35g (clamped to 0)
	DOUBLE_CURSED_STOP,  # Two random dice gain CURSED_STOP
}

const BLESSINGS: Array[Dictionary] = [
	{"type": EffectType.BOOST_NUMBERS, "name": "Empowered Dice", "icon": "✨", "desc": "+1 to all NUMBER faces this loop", "color_key": "SCORE_GOLD"},
	{"type": EffectType.GAIN_RANDOM_DICE, "name": "Lucky Find", "icon": "🎲", "desc": "Gain 2 random dice", "color_key": "SUCCESS_GREEN"},
	{"type": EffectType.FREE_BUST, "name": "Guardian Angel", "icon": "🛡", "desc": "Next bust this loop is free", "color_key": "ACTION_CYAN"},
	{"type": EffectType.BOOST_SHIELDS, "name": "Fortify", "icon": "🛡", "desc": "+1 to all SHIELD faces this loop", "color_key": "ACTION_CYAN"},
	{"type": EffectType.GAIN_GOLD, "name": "Treasure Trove", "icon": "💰", "desc": "+30g immediately", "color_key": "SCORE_GOLD"},
]

const PRESTIGE_BLESSINGS: Array[Dictionary] = [
	{"type": EffectType.GAIN_LUCK, "name": "Loaded Constellation", "icon": "☄", "desc": "+3 LUCK immediately", "color_key": "ACTION_CYAN"},
	{"type": EffectType.GAIN_REROUTE, "name": "Thread the Needle", "icon": "🧭", "desc": "Gain 1 reroute token for this run", "color_key": "SUCCESS_GREEN"},
]

const CURSES: Array[Dictionary] = [
	{"type": EffectType.LOSE_DIE, "name": "Sacrifice", "icon": "💀", "desc": "Lose 1 random die", "color_key": "DANGER_RED"},
	{"type": EffectType.ADD_CURSED_STOP, "name": "Hex", "icon": "☠", "desc": "A random die gains a Cursed Stop", "color_key": "NEON_PURPLE"},
	{"type": EffectType.BOOST_TARGETS, "name": "Harder Stages", "icon": "📈", "desc": "All targets +15% this loop", "color_key": "EXPLOSION_ORANGE"},
	{"type": EffectType.LOSE_LIFE, "name": "Blood Price", "icon": "❤", "desc": "Lose 1 life", "color_key": "DANGER_RED"},
	{"type": EffectType.LOSE_GOLD, "name": "Pickpocket", "icon": "💸", "desc": "-20g", "color_key": "SCORE_GOLD"},
]

const PRESTIGE_CURSES: Array[Dictionary] = [
	{"type": EffectType.LOSE_HEAVY_GOLD, "name": "Skull Tax", "icon": "🪙", "desc": "-35g", "color_key": "SCORE_GOLD"},
	{"type": EffectType.DOUBLE_CURSED_STOP, "name": "Grave Static", "icon": "☠", "desc": "Two random dice gain a Cursed Stop", "color_key": "NEON_PURPLE"},
]

@onready var _title_label: Label = $CenterContainer/Card/MarginContainer/Content/TitleLabel
@onready var _flavor_label: Label = $CenterContainer/Card/MarginContainer/Content/FlavorLabel
@onready var _choice_row: HBoxContainer = $CenterContainer/Card/MarginContainer/Content/ChoiceRow
@onready var _card_panel: PanelContainer = $CenterContainer/Card
@onready var _content: VBoxContainer = $CenterContainer/Card/MarginContainer/Content

var _blessing: Dictionary = {}
var _curse: Dictionary = {}
var _choice_cards: Array[PanelContainer] = []
var _resolved: bool = false
var _continue_button: Button = null
var _pending_summary: String = ""
var _pending_status_color: Color = Color.WHITE


func _ready() -> void:
	_apply_theme_styling()


func _apply_theme_styling() -> void:
	_card_panel.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_MODAL)
	)
	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", _UITheme.NEON_PURPLE)
	_flavor_label.add_theme_font_override("font", _UITheme.font_body())
	_flavor_label.add_theme_font_size_override("font_size", 14)
	_flavor_label.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)


func open() -> void:
	_resolved = false
	_pending_summary = ""
	_pending_status_color = Color.WHITE
	_title_label.text = "RANDOM EVENT"
	_flavor_label.text = "Choose your fate..."
	_prepare_choice_surface()
	var blessing_pool: Array[Dictionary] = _build_blessing_pool()
	var curse_pool: Array[Dictionary] = _build_curse_pool()
	var blessing_index: int = GameManager.rng_pick_index("event", blessing_pool.size())
	var curse_index: int = GameManager.rng_pick_index("event", curse_pool.size())
	if blessing_index < 0:
		blessing_index = 0
	if curse_index < 0:
		curse_index = 0
	_blessing = blessing_pool[blessing_index].duplicate()
	_curse = curse_pool[curse_index].duplicate()
	_build_choice_cards()
	_play_intro_animation()


func open_from_resume(snapshot: Dictionary) -> void:
	_resolved = false
	_pending_summary = ""
	_pending_status_color = Color.WHITE
	_title_label.text = "RANDOM EVENT"
	_flavor_label.text = "Choose your fate..."
	_prepare_choice_surface()
	_blessing = (snapshot.get("blessing", {}) as Dictionary).duplicate(true)
	_curse = (snapshot.get("curse", {}) as Dictionary).duplicate(true)
	if _blessing.is_empty() or _curse.is_empty():
		open()
		return
	_build_choice_cards()
	_play_intro_animation()


func build_resume_snapshot() -> Dictionary:
	return {
		"blessing": _blessing.duplicate(true),
		"curse": _curse.duplicate(true),
	}


func _prepare_choice_surface() -> void:
	_clear_choice_cards()
	_remove_continue_button()


func _build_choice_cards() -> void:
	# Build two choice cards.
	var blessing_card: PanelContainer = _build_choice_card(_blessing, true)
	var curse_card: PanelContainer = _build_choice_card(_curse, false)
	_choice_row.add_child(blessing_card)
	_choice_row.add_child(curse_card)
	_choice_cards.append(blessing_card)
	_choice_cards.append(curse_card)


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

func _build_choice_card(event: Dictionary, is_blessing: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)

	var accent: Color = _get_color(event.get("color_key", "BRIGHT_TEXT") as String)
	var border_color: Color = _UITheme.SUCCESS_GREEN if is_blessing else _UITheme.DANGER_RED
	card.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.ELEVATED, 12, border_color, 3)
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

	# Category label (BLESSING / CURSE).
	var cat_label := Label.new()
	cat_label.text = "BLESSING" if is_blessing else "CURSE"
	cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_label.add_theme_font_override("font", _UITheme.font_display())
	cat_label.add_theme_font_size_override("font_size", 11)
	cat_label.add_theme_color_override("font_color", border_color)
	vbox.add_child(cat_label)

	# Icon.
	var icon_label := Label.new()
	icon_label.text = event.get("icon", "?") as String
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 36)
	vbox.add_child(icon_label)

	# Event name.
	var name_label := Label.new()
	name_label.text = event.get("name", "") as String
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", _UITheme.font_stats())
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", accent)
	vbox.add_child(name_label)

	# Description.
	var desc_label := Label.new()
	desc_label.text = event.get("desc", "") as String
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_override("font", _UITheme.font_body())
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)
	vbox.add_child(desc_label)

	# Choose button.
	var btn := Button.new()
	btn.text = "Choose"
	btn.custom_minimum_size = Vector2(0, 40)
	btn.add_theme_font_override("font", _UITheme.font_display())
	btn.add_theme_font_size_override("font_size", 12)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_choice_made.bind(is_blessing))
	vbox.add_child(btn)

	return card


# ---------------------------------------------------------------------------
# Selection handling
# ---------------------------------------------------------------------------

func _on_choice_made(chose_blessing: bool) -> void:
	if _resolved:
		return
	_resolved = true

	var chosen_event: Dictionary = _blessing if chose_blessing else _curse
	var chosen_idx: int = 0 if chose_blessing else 1
	var effect_result: Dictionary = _apply_effect(chosen_event)
	var summary: String = _build_effect_summary(chosen_event, effect_result)
	var status_color: Color = _UITheme.SUCCESS_GREEN if chose_blessing else _UITheme.DANGER_RED
	_pending_summary = summary
	_pending_status_color = status_color
	_disable_choice_buttons()

	# Animate: chosen card scales up, other fades out.
	for i: int in _choice_cards.size():
		var card: PanelContainer = _choice_cards[i]
		if i == chosen_idx:
			var tw: Tween = create_tween()
			tw.tween_property(card, "scale", Vector2(1.06, 1.06), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			var tw: Tween = create_tween()
			tw.tween_property(card, "modulate:a", 0.0, 0.25)

	if _has_gained_dice_result(effect_result):
		var result_tween: Tween = create_tween()
		result_tween.tween_interval(RESULT_TRANSITION_DELAY)
		result_tween.tween_callback(_show_reward_result.bind(chosen_event, effect_result))
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

func _apply_effect(event: Dictionary) -> Dictionary:
	var effect_type: EffectType = event.get("type", EffectType.GAIN_GOLD) as EffectType
	match effect_type:
		EffectType.BOOST_NUMBERS:
			_boost_number_faces(1)
		EffectType.GAIN_RANDOM_DICE:
			return {"gained_dice": _gain_random_dice(2)}
		EffectType.FREE_BUST:
			GameManager.set_event_free_bust(true)
		EffectType.BOOST_SHIELDS:
			_boost_shield_faces(1)
		EffectType.GAIN_GOLD:
			GameManager.add_gold(30)
		EffectType.GAIN_LUCK:
			GameManager.add_luck(3)
		EffectType.GAIN_REROUTE:
			GameManager.prestige_reroute_uses += 1
		EffectType.LOSE_DIE:
			_lose_random_die()
		EffectType.ADD_CURSED_STOP:
			_add_cursed_stop_to_random_die()
		EffectType.BOOST_TARGETS:
			GameManager.apply_event_target_multiplier(1.15)
		EffectType.LOSE_LIFE:
			GameManager.lose_life()
		EffectType.LOSE_GOLD:
			GameManager.remove_gold(20)
		EffectType.LOSE_HEAVY_GOLD:
			GameManager.remove_gold(35)
		EffectType.DOUBLE_CURSED_STOP:
			_add_cursed_stop_to_random_die()
			_add_cursed_stop_to_random_die()
	return {}


func _build_blessing_pool() -> Array[Dictionary]:
	var blessing_pool: Array[Dictionary] = BLESSINGS.duplicate(true)
	if SaveManager.has_prestige_unlock("new_events"):
		for event: Dictionary in PRESTIGE_BLESSINGS:
			blessing_pool.append(event.duplicate())
	return blessing_pool


func _build_curse_pool() -> Array[Dictionary]:
	var curse_pool: Array[Dictionary] = CURSES.duplicate(true)
	if SaveManager.has_prestige_unlock("new_events"):
		for event: Dictionary in PRESTIGE_CURSES:
			curse_pool.append(event.duplicate())
	return curse_pool


func _build_effect_summary(event: Dictionary, effect_result: Dictionary = {}) -> String:
	var effect_type: EffectType = event.get("type", EffectType.GAIN_GOLD) as EffectType
	match effect_type:
		EffectType.BOOST_NUMBERS:
			return "EVENT: all NUMBER faces gain +1 this loop"
		EffectType.GAIN_RANDOM_DICE:
			var gained_dice: Array[DiceData] = _extract_gained_dice(effect_result)
			if gained_dice.size() >= 2:
				return "EVENT: gained %s and %s" % [gained_dice[0].dice_name, gained_dice[1].dice_name]
			return "EVENT: gained 2 random dice"
		EffectType.FREE_BUST:
			return "EVENT: next bust this loop is free"
		EffectType.BOOST_SHIELDS:
			return "EVENT: all SHIELD faces gain +1 this loop"
		EffectType.GAIN_GOLD:
			return "EVENT: gained 30g"
		EffectType.LOSE_DIE:
			return "EVENT: lost 1 random die"
		EffectType.ADD_CURSED_STOP:
			return "EVENT: a random die gained a Cursed Stop"
		EffectType.BOOST_TARGETS:
			return "EVENT: stage targets increased by 15% this loop"
		EffectType.LOSE_LIFE:
			return "EVENT: lost 1 life"
		EffectType.LOSE_GOLD:
			return "EVENT: lost 20g"
		EffectType.GAIN_LUCK:
			return "EVENT: gained 3 LUCK"
		EffectType.GAIN_REROUTE:
			return "EVENT: gained 1 reroute token"
		EffectType.LOSE_HEAVY_GOLD:
			return "EVENT: paid 35g in Skull Tax"
		EffectType.DOUBLE_CURSED_STOP:
			return "EVENT: two dice gained Cursed Stops"
	return "EVENT: %s" % (event.get("name", "Unknown") as String)


func _boost_number_faces(amount: int) -> void:
	for die: DiceData in GameManager.dice_pool:
		for face: DiceFaceData in die.faces:
			if face.type == DiceFaceData.FaceType.NUMBER:
				face.value += amount


func _boost_shield_faces(amount: int) -> void:
	for die: DiceData in GameManager.dice_pool:
		for face: DiceFaceData in die.faces:
			if face.type == DiceFaceData.FaceType.SHIELD:
				face.value += amount


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
		_UITheme.make_panel_stylebox(_UITheme.ELEVATED, 12, rarity_color, 3)
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
			_UITheme.make_panel_stylebox(Color(0.15, 0.15, 0.2, 1.0), 4)
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
			return Color(1.0, 0.3, 0.3)
		DiceFaceData.FaceType.BLANK:
			return Color(0.5, 0.5, 0.5)
		DiceFaceData.FaceType.SHIELD:
			return Color(0.3, 0.8, 1.0)
		DiceFaceData.FaceType.MULTIPLY, DiceFaceData.FaceType.MULTIPLY_LEFT:
			return Color(1.0, 0.85, 0.0)
		DiceFaceData.FaceType.EXPLODE:
			return Color(1.0, 0.5, 0.0)
		DiceFaceData.FaceType.INSURANCE:
			return Color(0.3, 1.0, 0.6)
		DiceFaceData.FaceType.LUCK:
			return Color(0.4, 0.9, 0.3)
		DiceFaceData.FaceType.HEART:
			return _UITheme.ROSE_ACCENT
	return Color(0.9, 0.9, 0.9)


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
