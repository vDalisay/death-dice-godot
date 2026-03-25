class_name ShopPanel
extends PanelContainer
## Between-stage shop. The player spends gold to buy dice or upgrade faces.
## Emits shop_closed when the player clicks Continue.

signal shop_closed()

const ITEM_FONT_SIZE: int = 18

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _gold_label: Label = $MarginContainer/VBoxContainer/GoldLabel
@onready var _items_container: VBoxContainer = $MarginContainer/VBoxContainer/ItemsContainer
@onready var _pool_label: Label = $MarginContainer/VBoxContainer/PoolLabel
@onready var _continue_button: Button = $MarginContainer/VBoxContainer/ContinueButton

var _items: Array[ShopItemData] = []
var _buy_buttons: Array[Button] = []


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	GameManager.gold_changed.connect(_on_gold_changed)
	visible = false


# ---------------------------------------------------------------------------
# Public API — called by RollPhase
# ---------------------------------------------------------------------------

func open(stage_just_cleared: int) -> void:
	_title_label.text = "Stage %d Complete!" % stage_just_cleared
	_continue_button.text = "Continue to Stage %d" % (stage_just_cleared + 1)
	_generate_items()
	_refresh_display()
	visible = true


# ---------------------------------------------------------------------------
# Item generation
# ---------------------------------------------------------------------------

func _generate_items() -> void:
	_items.clear()
	_items.append(ShopItemData.make_buy_standard_die())
	_items.append(ShopItemData.make_buy_lucky_die())
	if not GameManager.dice_pool.is_empty():
		_items.append(ShopItemData.make_upgrade_die())
	_build_item_rows()


func _build_item_rows() -> void:
	for child: Node in _items_container.get_children():
		child.queue_free()
	_buy_buttons.clear()

	for item: ShopItemData in _items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := Label.new()
		name_label.text = item.item_name
		name_label.add_theme_font_size_override("font_size", ITEM_FONT_SIZE)
		info.add_child(name_label)
		var desc_label := Label.new()
		desc_label.text = item.description
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.modulate = Color(0.7, 0.7, 0.7)
		info.add_child(desc_label)
		row.add_child(info)

		var buy_btn := Button.new()
		buy_btn.text = "Buy (%dg)" % item.cost
		buy_btn.custom_minimum_size = Vector2(120, 40)
		buy_btn.add_theme_font_size_override("font_size", ITEM_FONT_SIZE)
		buy_btn.pressed.connect(_on_buy_pressed.bind(item))
		row.add_child(buy_btn)
		_buy_buttons.append(buy_btn)

		_items_container.add_child(row)


# ---------------------------------------------------------------------------
# Purchase handling
# ---------------------------------------------------------------------------

func _on_buy_pressed(item: ShopItemData) -> void:
	if not GameManager.spend_gold(item.cost):
		return
	match item.item_type:
		ShopItemData.ItemType.BUY_STANDARD_DIE:
			GameManager.add_dice(DiceData.make_standard_d6())
		ShopItemData.ItemType.BUY_LUCKY_DIE:
			GameManager.add_dice(DiceData.make_lucky_d6())
		ShopItemData.ItemType.UPGRADE_DIE:
			_upgrade_random_die()
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
	visible = false
	shop_closed.emit()


func _on_gold_changed(_new_gold: int) -> void:
	if visible:
		_refresh_display()


func _refresh_display() -> void:
	_gold_label.text = "Gold: %d" % GameManager.gold
	_pool_label.text = "Your Dice: %d" % GameManager.dice_pool.size()
	_refresh_buy_buttons()


func _refresh_buy_buttons() -> void:
	for i: int in _buy_buttons.size():
		if i < _items.size():
			_buy_buttons[i].disabled = GameManager.gold < _items[i].cost
