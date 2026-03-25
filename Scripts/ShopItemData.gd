class_name ShopItemData
extends Resource
## Definition of a purchasable shop item. Add new ItemType values and factory
## methods to extend the shop without modifying ShopPanel logic.

enum ItemType {
	BUY_STANDARD_DIE,
	BUY_LUCKY_DIE,
	BUY_RUNNER_DIE,
	BUY_SHIELD_DIE,
	BUY_MULTIPLIER_DIE,
	UPGRADE_DIE,
}

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


static func make_buy_runner_die() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Runner Die"
	item.description = "High risk, high reward. (3, 3, 4, ★4, STOP, STOP)"
	item.cost = 40
	item.item_type = ItemType.BUY_RUNNER_DIE
	return item


static func make_buy_shield_die() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Shield Die"
	item.description = "Shields absorb stops. (1, 1, SH, SH, —, STOP)"
	item.cost = 45
	item.item_type = ItemType.BUY_SHIELD_DIE
	return item


static func make_buy_multiplier_die() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Multiplier Die"
	item.description = "Multiply your turn score! (1, x2, —, —, STOP, STOP)"
	item.cost = 60
	item.item_type = ItemType.BUY_MULTIPLIER_DIE
	return item


static func make_upgrade_die() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Empower Die"
	item.description = "Upgrade the weakest face on a random die."
	item.cost = 30
	item.item_type = ItemType.UPGRADE_DIE
	return item
