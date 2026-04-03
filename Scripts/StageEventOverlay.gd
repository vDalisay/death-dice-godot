extends ColorRect
## Random Event overlay — player picks a Blessing or a Curse.
## Instantiated at runtime by RollPhase when visiting a RANDOM_EVENT node.

signal event_resolved(summary: String, status_color: Color)

const _UITheme := preload("res://Scripts/UITheme.gd")

const BACKDROP_ALPHA: float = 0.72
const CARD_WIDTH: int = 280
const CARD_HEIGHT: int = 220

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

var _blessing: Dictionary = {}
var _curse: Dictionary = {}
var _choice_cards: Array[PanelContainer] = []
var _resolved: bool = false


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
	var blessing_pool: Array[Dictionary] = _build_blessing_pool()
	var curse_pool: Array[Dictionary] = _build_curse_pool()
	_blessing = blessing_pool[randi() % blessing_pool.size()].duplicate()
	_curse = curse_pool[randi() % curse_pool.size()].duplicate()

	# Clear old cards.
	for card: PanelContainer in _choice_cards:
		card.queue_free()
	_choice_cards.clear()

	# Build two choice cards.
	var blessing_card: PanelContainer = _build_choice_card(_blessing, true)
	var curse_card: PanelContainer = _build_choice_card(_curse, false)
	_choice_row.add_child(blessing_card)
	_choice_row.add_child(curse_card)
	_choice_cards.append(blessing_card)
	_choice_cards.append(curse_card)

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
	_apply_effect(chosen_event)

	# Animate: chosen card scales up, other fades out.
	for i: int in _choice_cards.size():
		var card: PanelContainer = _choice_cards[i]
		if i == chosen_idx:
			var tw: Tween = create_tween()
			tw.tween_property(card, "scale", Vector2(1.06, 1.06), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			var tw: Tween = create_tween()
			tw.tween_property(card, "modulate:a", 0.0, 0.25)

	# After short delay, close and emit.
	var close_tween: Tween = create_tween()
	close_tween.tween_interval(0.6)
	close_tween.tween_property(self, "color:a", 0.0, 0.2)
	close_tween.parallel().tween_property(_card_panel, "modulate:a", 0.0, 0.2)
	var summary: String = _build_effect_summary(chosen_event)
	var status_color: Color = _UITheme.SUCCESS_GREEN if chose_blessing else _UITheme.DANGER_RED
	close_tween.tween_callback(func() -> void: event_resolved.emit(summary, status_color))


# ---------------------------------------------------------------------------
# Effect application
# ---------------------------------------------------------------------------

func _apply_effect(event: Dictionary) -> void:
	var effect_type: EffectType = event.get("type", EffectType.GAIN_GOLD) as EffectType
	match effect_type:
		EffectType.BOOST_NUMBERS:
			_boost_number_faces(1)
		EffectType.GAIN_RANDOM_DICE:
			_gain_random_dice(2)
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


func _build_effect_summary(event: Dictionary) -> String:
	var effect_type: EffectType = event.get("type", EffectType.GAIN_GOLD) as EffectType
	match effect_type:
		EffectType.BOOST_NUMBERS:
			return "EVENT: all NUMBER faces gain +1 this loop"
		EffectType.GAIN_RANDOM_DICE:
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


func _gain_random_dice(count: int) -> void:
	var factory_methods: Array[String] = [
		"make_simple_d6", "make_standard_d6", "make_lucky_d6", "make_blank_canvas_d6",
	]
	for _i: int in count:
		var method: String = factory_methods[randi() % factory_methods.size()]
		var die: DiceData = Callable(DiceData, method).call() as DiceData
		GameManager.add_dice(die)


func _lose_random_die() -> void:
	if GameManager.dice_pool.size() <= 1:
		return  # Never leave the player with 0 dice.
	var idx: int = randi() % GameManager.dice_pool.size()
	GameManager.dice_pool.remove_at(idx)


func _add_cursed_stop_to_random_die() -> void:
	if GameManager.dice_pool.is_empty():
		return
	var die: DiceData = GameManager.dice_pool[randi() % GameManager.dice_pool.size()]
	var candidates: Array[int] = []
	for i: int in die.faces.size():
		if die.faces[i].type != DiceFaceData.FaceType.CURSED_STOP and die.faces[i].type != DiceFaceData.FaceType.STOP:
			candidates.append(i)
	if candidates.is_empty():
		return
	var target: int = candidates[randi() % candidates.size()]
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
