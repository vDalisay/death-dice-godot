class_name ShopItemData
extends Resource
## Definition of a purchasable shop item. Add new ItemType values and factory
## methods to extend the shop without modifying ShopPanel logic.

enum ItemType { BUY_STANDARD_DIE, BUY_LUCKY_DIE, UPGRADE_DIE }

@export var item_name: String = ""
@export var description: String = ""
@export var cost: int = 0
@export var item_type: ItemType = ItemType.BUY_STANDARD_DIE


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


static func make_upgrade_die() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Empower Die"
	item.description = "Upgrade the weakest face on a random die."
	item.cost = 30
	item.item_type = ItemType.UPGRADE_DIE
	return item
