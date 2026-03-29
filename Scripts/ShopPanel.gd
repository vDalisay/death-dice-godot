class_name ShopPanel
extends PanelContainer
## Between-stage shop. The player spends gold to buy dice or upgrade faces.
## Emits shop_closed when the player clicks Continue.

signal shop_closed()

const ITEM_FONT_SIZE: int = 18
const REFRESH_COST: int = 5

const DICE_SLOTS: int = 4
const MODIFIER_SLOTS: int = 2

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _gold_label: Label = $MarginContainer/VBoxContainer/GoldLabel
@onready var _dice_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/ScrollContent/DiceContainer
@onready var _modifier_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/ScrollContent/ModifierContainer
@onready var _dice_header: Label = $MarginContainer/VBoxContainer/ScrollContainer/ScrollContent/DiceHeader
@onready var _modifier_header: Label = $MarginContainer/VBoxContainer/ScrollContainer/ScrollContent/ModifierHeader
@onready var _pool_label: Label = $MarginContainer/VBoxContainer/PoolLabel
@onready var _continue_button: Button = $MarginContainer/VBoxContainer/ContinueButton

var _dice_items: Array[ShopItemData] = []
var _modifier_items: Array[ShopItemData] = []
var _buy_buttons: Array[Button] = []
var _refresh_button: Button = null


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	GameManager.gold_changed.connect(_on_gold_changed)
	visible = false


# ---------------------------------------------------------------------------
# Public API — called by RollPhase
# ---------------------------------------------------------------------------

func open(stage_just_cleared: int, is_loop_complete: bool = false) -> void:
	GameManager.on_shop_entered()
	if is_loop_complete:
		_title_label.text = "Loop %d Complete!" % (GameManager.current_loop - 1)
		_continue_button.text = "Start Loop %d" % GameManager.current_loop
	else:
		_title_label.text = "Stage %d Complete!" % stage_just_cleared
		_continue_button.text = "Continue to Stage %d" % (stage_just_cleared + 1)
	_generate_items()
	_refresh_display()
	visible = true


# ---------------------------------------------------------------------------
# Item generation
# ---------------------------------------------------------------------------

func _generate_items() -> void:
	_dice_items.clear()
	_modifier_items.clear()
	# Build the pool of all available dice shop items.
	var dice_pool: Array[ShopItemData] = [
		ShopItemData.make_buy_simple_die(),
		ShopItemData.make_buy_standard_die(),
		ShopItemData.make_buy_blank_canvas_die(),
		ShopItemData.make_buy_lucky_die(),
		ShopItemData.make_buy_pink_die(),
	]
	# Unlock additional dice in loop 2+.
	if GameManager.current_loop >= 2:
		dice_pool.append(ShopItemData.make_buy_runner_die())
		dice_pool.append(ShopItemData.make_buy_golden_die())
		dice_pool.append(ShopItemData.make_buy_insurance_die())
		dice_pool.append(ShopItemData.make_buy_heavy_die())
		dice_pool.append(ShopItemData.make_buy_explosive_die())
	# Shuffle and pick a random subset.
	dice_pool.shuffle()
	var pick_count: int = mini(DICE_SLOTS, dice_pool.size())
	for i: int in pick_count:
		_dice_items.append(dice_pool[i])
	# Empower Die is always available if the player has dice.
	if not GameManager.dice_pool.is_empty():
		_dice_items.append(ShopItemData.make_upgrade_die())
	# Cleanse Curse: available if any die has a CURSED_STOP face (dice section).
	if _any_die_has_cursed_stop():
		_dice_items.append(ShopItemData.make_cleanse_curse())
	# Modifier items: offer 1-2 random modifiers the player doesn't already own.
	if GameManager.can_add_modifier():
		var mod_factories: Array[Callable] = RunModifier.all_factories()
		var available_mods: Array[Callable] = []
		for factory: Callable in mod_factories:
			var sample: RunModifier = factory.call() as RunModifier
			if not GameManager.has_modifier(sample.modifier_type):
				available_mods.append(factory)
		available_mods.shuffle()
		var mod_count: int = mini(MODIFIER_SLOTS, available_mods.size())
		for i: int in mod_count:
			var mod: RunModifier = available_mods[i].call() as RunModifier
			_modifier_items.append(ShopItemData.make_buy_modifier(mod))
	_build_item_rows()


func _build_item_rows() -> void:
	for child: Node in _dice_container.get_children():
		child.queue_free()
	for child: Node in _modifier_container.get_children():
		child.queue_free()
	_buy_buttons.clear()

	# Dice section
	_dice_header.visible = not _dice_items.is_empty()
	for item: ShopItemData in _dice_items:
		_dice_container.add_child(_make_item_row(item))

	# Modifier section
	_modifier_header.visible = not _modifier_items.is_empty()
	for item: ShopItemData in _modifier_items:
		_modifier_container.add_child(_make_item_row(item))

	# Refresh shop button after both sections.
	_refresh_button = Button.new()
	_refresh_button.text = "Refresh Shop (%dg)" % REFRESH_COST
	_refresh_button.custom_minimum_size = Vector2(180, 36)
	_refresh_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_refresh_button.add_theme_font_size_override("font_size", ITEM_FONT_SIZE)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	_modifier_container.add_child(_refresh_button)


func _make_item_row(item: ShopItemData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = item.item_name
	name_label.add_theme_font_size_override("font_size", ITEM_FONT_SIZE)
	info.add_child(name_label)
	var desc_label := Label.new()
	if item.item_type == ShopItemData.ItemType.UPGRADE_DIE:
		desc_label.text = _get_upgrade_preview()
	else:
		desc_label.text = item.description
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.modulate = Color(0.7, 0.7, 0.7)
	info.add_child(desc_label)
	row.add_child(info)

	var buy_btn := Button.new()
	buy_btn.text = "Buy (%dg)" % item.cost
	buy_btn.custom_minimum_size = Vector2(120, 36)
	buy_btn.add_theme_font_size_override("font_size", ITEM_FONT_SIZE)
	buy_btn.pressed.connect(_on_buy_pressed.bind(item))
	row.add_child(buy_btn)
	_buy_buttons.append(buy_btn)

	return row


# ---------------------------------------------------------------------------
# Purchase handling
# ---------------------------------------------------------------------------

func _on_buy_pressed(item: ShopItemData) -> void:
	if not GameManager.spend_gold(item.cost):
		return
	GameManager.track_shop_spend(item.cost)
	SFXManager.play_shop_purchase()
	match item.item_type:
		ShopItemData.ItemType.BUY_STANDARD_DIE:
			GameManager.add_dice(DiceData.make_standard_d6())
		ShopItemData.ItemType.BUY_LUCKY_DIE:
			GameManager.add_dice(DiceData.make_lucky_d6())
		ShopItemData.ItemType.BUY_GAMBLER_DIE:
			GameManager.add_dice(DiceData.make_gambler_d6())
		ShopItemData.ItemType.BUY_GOLDEN_DIE:
			GameManager.add_dice(DiceData.make_golden_d6())
		ShopItemData.ItemType.BUY_INSURANCE_DIE:
			GameManager.add_dice(DiceData.make_insurance_d6())
		ShopItemData.ItemType.BUY_HEAVY_DIE:
			GameManager.add_dice(DiceData.make_heavy_d6())
		ShopItemData.ItemType.BUY_EXPLOSIVE_DIE:
			GameManager.add_dice(DiceData.make_explosive_d6())
		ShopItemData.ItemType.BUY_BLANK_CANVAS_DIE:
			GameManager.add_dice(DiceData.make_blank_canvas_d6())
		ShopItemData.ItemType.BUY_PINK_DIE:
			GameManager.add_dice(DiceData.make_pink_d6())
		ShopItemData.ItemType.BUY_SIMPLE_DIE:
			GameManager.add_dice(DiceData.make_simple_d6())
		ShopItemData.ItemType.UPGRADE_DIE:
			_upgrade_random_die()
		ShopItemData.ItemType.BUY_MODIFIER:
			if item.modifier != null:
				GameManager.add_modifier(item.modifier)
		ShopItemData.ItemType.CLEANSE_CURSE:
			_cleanse_random_cursed_die()
	_refresh_display()


func _upgrade_random_die() -> void:
	if GameManager.dice_pool.is_empty():
		return
	var die: DiceData = GameManager.dice_pool[randi() % GameManager.dice_pool.size()]
	die.upgrade_weakest_face()


# ---------------------------------------------------------------------------
# UI updates
# ---------------------------------------------------------------------------

func _on_continue_pressed() -> void:
	GameManager.on_shop_exited()
	visible = false
	shop_closed.emit()


func _on_gold_changed(_new_gold: int) -> void:
	if visible:
		_refresh_display()


func _refresh_display() -> void:
	_gold_label.text = "Gold: %d" % GameManager.gold
	var mod_text: String = ""
	if not GameManager.active_modifiers.is_empty():
		var names: Array[String] = []
		for m: RunModifier in GameManager.active_modifiers:
			names.append(m.modifier_name)
		mod_text = "  |  Modifiers: %s" % ", ".join(names)
	_pool_label.text = "Your Dice: %d%s" % [GameManager.dice_pool.size(), mod_text]
	_refresh_buy_buttons()


func _refresh_buy_buttons() -> void:
	var all_items: Array[ShopItemData] = []
	all_items.append_array(_dice_items)
	all_items.append_array(_modifier_items)
	for i: int in _buy_buttons.size():
		if i < all_items.size():
			var item: ShopItemData = all_items[i]
			var too_expensive: bool = GameManager.gold < item.cost
			var mod_full: bool = item.item_type == ShopItemData.ItemType.BUY_MODIFIER and not GameManager.can_add_modifier()
			var already_owned: bool = item.item_type == ShopItemData.ItemType.BUY_MODIFIER and item.modifier != null and GameManager.has_modifier(item.modifier.modifier_type)
			_buy_buttons[i].disabled = too_expensive or mod_full or already_owned
	if _refresh_button != null:
		_refresh_button.disabled = GameManager.gold < REFRESH_COST


func _on_refresh_pressed() -> void:
	if not GameManager.spend_gold(REFRESH_COST):
		return
	SFXManager.play_shop_refresh()
	_generate_items()
	_refresh_display()


## Preview which face and die would be upgraded by Empower Die.
func _get_upgrade_preview() -> String:
	if GameManager.dice_pool.is_empty():
		return "No dice to upgrade."
	# Find die with the weakest face (mimics _upgrade_random_die's random pick,
	# but for preview we show ALL eligible dice's weakest face).
	var previews: Array[String] = []
	for die: DiceData in GameManager.dice_pool:
		var worst_index: int = -1
		var worst_power: int = 999
		for i: int in die.faces.size():
			var power: int = die._face_power(die.faces[i])
			if power < worst_power:
				if die.faces[i].type == DiceFaceData.FaceType.STOP and die._count_stop_faces() <= 1:
					continue
				worst_power = power
				worst_index = i
		if worst_index >= 0:
			var face_text: String = die.faces[worst_index].get_display_text()
			var preview: String = "%s [%s]" % [die.dice_name, face_text]
			if preview not in previews:
				previews.append(preview)
	if previews.is_empty():
		return "No upgradeable faces."
	return "Will upgrade a random die. Candidates: %s" % ", ".join(previews)


func _any_die_has_cursed_stop() -> bool:
	for die: DiceData in GameManager.dice_pool:
		for face: DiceFaceData in die.faces:
			if face.type == DiceFaceData.FaceType.CURSED_STOP:
				return true
	return false


func _cleanse_random_cursed_die() -> void:
	var cursed_dice: Array[DiceData] = []
	for die: DiceData in GameManager.dice_pool:
		for face: DiceFaceData in die.faces:
			if face.type == DiceFaceData.FaceType.CURSED_STOP:
				cursed_dice.append(die)
				break
	if cursed_dice.is_empty():
		return
	var die: DiceData = cursed_dice[randi() % cursed_dice.size()]
	for face: DiceFaceData in die.faces:
		if face.type == DiceFaceData.FaceType.CURSED_STOP:
			face.type = DiceFaceData.FaceType.STOP
			break
