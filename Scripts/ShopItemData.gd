class_name ShopItemData
extends Resource
## Definition of a purchasable shop item. Add new ItemType values and factory
## methods to extend the shop without modifying ShopPanel logic.

enum ItemType {
	BUY_STANDARD_DIE,
	BUY_LUCKY_DIE,
	BUY_GAMBLER_DIE,
	BUY_GOLDEN_DIE,
	BUY_HEAVY_DIE,
	BUY_EXPLOSIVE_DIE,
	BUY_BLANK_CANVAS_DIE,
	BUY_PINK_DIE,
	BUY_SIMPLE_DIE,
	UPGRADE_DIE,
	BUY_MODIFIER,
	CLEANSE_CURSE,
}

@export var item_name: String = ""
@export var description: String = ""
@export var cost: int = 0
@export var item_type: ItemType = ItemType.BUY_STANDARD_DIE
## For BUY_MODIFIER items, the modifier resource to grant on purchase.
var modifier: RunModifier = null


static func make_buy_standard_die() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Standard Die"
	item.description = "A reliable six-sided die. (1, 1, 2, ★2, —, STOP)"
	item.cost = 20
	item.item_type = ItemType.BUY_STANDARD_DIE
	return item


static func make_buy_lucky_die() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Lucky Die"
	item.description = "Better faces, no blanks. (2, 2, 3, ★3, 1, STOP)"
	item.cost = 50
	item.item_type = ItemType.BUY_LUCKY_DIE
	return item


static func make_buy_runner_die() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Gambler Die"
	item.description = "High risk, high reward. (3, 4, 5, 5, STOP, STOP)"
	item.cost = 40
	item.item_type = ItemType.BUY_GAMBLER_DIE
	return item


static func make_buy_golden_die() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Golden Die"
	item.description = "Auto-keep gold. Punishing stops. (★2, ★2, ★3, —, STOP, STOP)"
	item.cost = 50
	item.item_type = ItemType.BUY_GOLDEN_DIE
	return item


static func make_buy_heavy_die() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Heavy Die"
	item.description = "Big numbers, big risk. (4, 5, 6, —, STOP, STOP)"
	item.cost = 45
	item.item_type = ItemType.BUY_HEAVY_DIE
	return item


static func make_buy_explosive_die() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Explosive Die"
	item.description = "Chain reaction! 💥 re-rolls itself. (💥2, 💥2, 2, STOP×3)"
	item.cost = 60
	item.item_type = ItemType.BUY_EXPLOSIVE_DIE
	return item


static func make_buy_blank_canvas_die() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Blank Canvas Die"
	item.description = "Cheap and upgradeable. (—, —, —, —, —, STOP)"
	item.cost = 10
	item.item_type = ItemType.BUY_BLANK_CANVAS_DIE
	return item


static func make_buy_pink_die() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Pink Die"
	item.description = "Multiplies ANY face on the die to its left. (←×2, ←×2, STOP×3, —)"
	item.cost = 45
	item.item_type = ItemType.BUY_PINK_DIE
	return item


static func make_buy_simple_die() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Simple Die"
	item.description = "Cheap and safe. No stops! (1, 1, 1, —, —, —)"
	item.cost = 8
	item.item_type = ItemType.BUY_SIMPLE_DIE
	return item


static func make_upgrade_die() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Empower Die"
	item.description = "Upgrade the weakest face on a random die."
	item.cost = 30
	item.item_type = ItemType.UPGRADE_DIE
	return item


## Create a shop item for purchasing a passive modifier.
static func make_buy_modifier(mod: RunModifier) -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = mod.modifier_name
	item.description = mod.description
	item.cost = mod.cost
	item.item_type = ItemType.BUY_MODIFIER
	item.modifier = mod
	return item


static func make_cleanse_curse() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Cleanse Curse"
	item.description = "Remove a CURSED STOP face from a random die."
	item.cost = 15
	item.item_type = ItemType.CLEANSE_CURSE
	return item
