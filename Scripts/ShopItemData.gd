class_name ShopItemData
extends Resource
## Definition of a purchasable shop item. Add new ItemType values and factory
## methods to extend the shop without modifying ShopPanel logic.

enum ItemType {
	BUY_STANDARD_DIE,
	BUY_LUCKY_DIE,
	BUY_GAMBLER_DIE,
	BUY_GOLDEN_DIE,
	BUY_INSURANCE_DIE,
	BUY_HEAVY_DIE,
	BUY_EXPLOSIVE_DIE,
	BUY_BLANK_CANVAS_DIE,
	BUY_PINK_DIE,
	BUY_SIMPLE_DIE,
	UPGRADE_DIE,
	BUY_MODIFIER,
	CLEANSE_CURSE,
	DOUBLE_DOWN,
	BUY_FORTUNE_DIE,
	BUY_HEART_DIE,
	INSURANCE_BET,
	HEAT_BET,
	EVEN_ODD_BET,
	BUY_SPARK_CHASER_DIE,
	BUY_CLUSTER_DIE,
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


static func make_buy_insurance_die() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Insurance Die"
	item.description = "Safety net. INS cancels one bust, then burns to —. (INS, 2, 2, —, STOP, STOP)"
	item.cost = 55
	item.item_type = ItemType.BUY_INSURANCE_DIE
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
	item.description = "Chain reaction! ✦ re-rolls itself. (✦2, ✦2, 2, STOP×3)"
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


static func make_buy_fortune_die() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Fortune Die"
	item.description = "Luck faces boost reward rarity. (LK, LK, 2, 2, STOP, STOP)"
	item.cost = 35
	item.item_type = ItemType.BUY_FORTUNE_DIE
	return item


static func make_buy_heart_die() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Heart Die"
	item.description = "Banked hearts soothe your stop counter. (♥, ♥, 1, 1, STOP, —)"
	item.cost = 30
	item.item_type = ItemType.BUY_HEART_DIE
	return item


static func make_buy_spark_chaser_die() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Spark Chaser Die"
	item.description = "Reroll evo starter. Scales into Surge/Tempest as rerolls stack."
	item.cost = 40
	item.item_type = ItemType.BUY_SPARK_CHASER_DIE
	return item


static func make_buy_cluster_die() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Cluster Die"
	item.description = "Fractures into child dice on settle. (2, 2, 2, 4, 4, 6)"
	item.cost = 60
	item.item_type = ItemType.BUY_CLUSTER_DIE
	return item


static func make_upgrade_die() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Empower Die"
	item.description = "Pick one die. All of its faces gain +1 up to their type caps."
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


static func make_blast_shield_mod() -> ShopItemData:
	return make_buy_modifier(RunModifier.make_blast_shield())


static func make_anchored_hearts_mod() -> ShopItemData:
	return make_buy_modifier(RunModifier.make_anchored_hearts())


static func make_heavy_dice_mod() -> ShopItemData:
	return make_buy_modifier(RunModifier.make_heavy_dice())


static func make_aftershock_mod() -> ShopItemData:
	return make_buy_modifier(RunModifier.make_aftershock())


static func make_sympathetic_detonation_mod() -> ShopItemData:
	return make_buy_modifier(RunModifier.make_sympathetic_detonation())


static func make_shrapnel_mod() -> ShopItemData:
	return make_buy_modifier(RunModifier.make_shrapnel())


static func make_gravity_well_mod() -> ShopItemData:
	return make_buy_modifier(RunModifier.make_gravity_well())


static func make_rubber_dice_mod() -> ShopItemData:
	return make_buy_modifier(RunModifier.make_rubber_dice())


static func make_spark_scatter_mod() -> ShopItemData:
	return make_buy_modifier(RunModifier.make_spark_scatter())


static func make_cluster_recursion_mod() -> ShopItemData:
	return make_buy_modifier(RunModifier.make_cluster_recursion())


static func make_empower_die_mod() -> ShopItemData:
	return make_buy_modifier(RunModifier.make_empower_die())


static func make_cleanse_curse() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Cleanse Curse"
	item.description = "Remove a CURSED STOP face from a random die."
	item.cost = 15
	item.item_type = ItemType.CLEANSE_CURSE
	return item


static func make_double_down() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Double Down"
	item.description = "Gamble your gold! Pick even/odd, roll a die."
	item.cost = 0
	item.item_type = ItemType.DOUBLE_DOWN
	return item


static func make_insurance_bet() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Insurance Bet"
	item.description = "Pay 10g now. If you bust this stage, recover 25g. Net +15g on bust."
	item.cost = 10
	item.item_type = ItemType.INSURANCE_BET
	return item


static func make_heat_bet() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Heat Bet"
	item.description = "Wager 15g. Predict your exact stop count when you bank. Hit it: 3:1 payout (45g)."
	item.cost = 15
	item.item_type = ItemType.HEAT_BET
	return item


static func make_even_odd_bet() -> ShopItemData:
	var item := ShopItemData.new()
	item.item_name = "Even/Odd Bet"
	item.description = "Bet on parity of your kept NUMBER dice. ~50/50 — ties push. 2:1 payout."
	item.cost = 0
	item.item_type = ItemType.EVEN_ODD_BET
	return item
