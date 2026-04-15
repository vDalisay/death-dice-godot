class_name ShopSerializer
extends RefCounted
## Handles serialization and deserialization of ShopItemData for save / resume.


func serialize_item_array(items: Array[ShopItemData]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for item: ShopItemData in items:
		serialized.append(serialize_item(item))
	return serialized


func deserialize_item_array(items: Array) -> Array[ShopItemData]:
	var deserialized: Array[ShopItemData] = []
	for item_data: Variant in items:
		if not (item_data is Dictionary):
			continue
		var item: ShopItemData = deserialize_item(item_data as Dictionary)
		if item != null:
			deserialized.append(item)
	return deserialized


func serialize_item(item: ShopItemData) -> Dictionary:
	var modifier_type: int = -1
	if item.modifier != null:
		modifier_type = int(item.modifier.modifier_type)
	return {
		"item_type": int(item.item_type),
		"item_name": item.item_name,
		"description": item.description,
		"cost": item.cost,
		"modifier_type": modifier_type,
	}


func deserialize_item(data: Dictionary) -> ShopItemData:
	var item_type: int = int(data.get("item_type", -1))
	if item_type < 0:
		return null
	var item: ShopItemData = make_item_from_type(item_type)
	if item == null:
		return null
	item.item_name = str(data.get("item_name", item.item_name))
	item.description = str(data.get("description", item.description))
	item.cost = int(data.get("cost", item.cost))
	if item.item_type == ShopItemData.ItemType.BUY_MODIFIER:
		var mod_type: int = int(data.get("modifier_type", -1))
		item.modifier = make_modifier_from_type(mod_type)
	return item


func make_item_from_type(item_type: int) -> ShopItemData:
	match item_type:
		int(ShopItemData.ItemType.BUY_STANDARD_DIE):
			return ShopItemData.make_buy_standard_die()
		int(ShopItemData.ItemType.BUY_LUCKY_DIE):
			return ShopItemData.make_buy_lucky_die()
		int(ShopItemData.ItemType.BUY_GAMBLER_DIE):
			return ShopItemData.make_buy_runner_die()
		int(ShopItemData.ItemType.BUY_GOLDEN_DIE):
			return ShopItemData.make_buy_golden_die()
		int(ShopItemData.ItemType.BUY_INSURANCE_DIE):
			return ShopItemData.make_buy_insurance_die()
		int(ShopItemData.ItemType.BUY_HEAVY_DIE):
			return ShopItemData.make_buy_heavy_die()
		int(ShopItemData.ItemType.BUY_EXPLOSIVE_DIE):
			return ShopItemData.make_buy_explosive_die()
		int(ShopItemData.ItemType.BUY_BLANK_CANVAS_DIE):
			return ShopItemData.make_buy_blank_canvas_die()
		int(ShopItemData.ItemType.BUY_PINK_DIE):
			return ShopItemData.make_buy_pink_die()
		int(ShopItemData.ItemType.BUY_SIMPLE_DIE):
			return ShopItemData.make_buy_simple_die()
		int(ShopItemData.ItemType.UPGRADE_DIE):
			return ShopItemData.make_upgrade_die()
		int(ShopItemData.ItemType.BUY_MODIFIER):
			return ShopItemData.make_buy_modifier(RunModifier.make_gamblers_rush())
		int(ShopItemData.ItemType.CLEANSE_CURSE):
			return ShopItemData.make_cleanse_curse()
		int(ShopItemData.ItemType.DOUBLE_DOWN):
			return ShopItemData.make_double_down()
		int(ShopItemData.ItemType.BUY_FORTUNE_DIE):
			return ShopItemData.make_buy_fortune_die()
		int(ShopItemData.ItemType.BUY_HEART_DIE):
			return ShopItemData.make_buy_heart_die()
		int(ShopItemData.ItemType.INSURANCE_BET):
			return ShopItemData.make_insurance_bet()
		int(ShopItemData.ItemType.HEAT_BET):
			return ShopItemData.make_heat_bet()
		int(ShopItemData.ItemType.EVEN_ODD_BET):
			return ShopItemData.make_even_odd_bet()
		int(ShopItemData.ItemType.BUY_SPARK_CHASER_DIE):
			return ShopItemData.make_buy_spark_chaser_die()
		int(ShopItemData.ItemType.BUY_CLUSTER_DIE):
			return ShopItemData.make_buy_cluster_die()
	return null


func make_modifier_from_type(modifier_type: int) -> RunModifier:
	match modifier_type:
		int(RunModifier.ModifierType.GAMBLERS_RUSH):
			return RunModifier.make_gamblers_rush()
		int(RunModifier.ModifierType.EXPLOSOPHILE):
			return RunModifier.make_explosophile()
		int(RunModifier.ModifierType.IRON_BANK):
			return RunModifier.make_iron_bank()
		int(RunModifier.ModifierType.GLASS_CANNON):
			return RunModifier.make_glass_cannon()
		int(RunModifier.ModifierType.SHIELD_WALL):
			return RunModifier.make_shield_wall()
		int(RunModifier.ModifierType.MISER):
			return RunModifier.make_miser()
		int(RunModifier.ModifierType.DOUBLE_DOWN):
			return RunModifier.make_double_down()
		int(RunModifier.ModifierType.SCAVENGER):
			return RunModifier.make_scavenger()
		int(RunModifier.ModifierType.RECYCLER):
			return RunModifier.make_recycler()
		int(RunModifier.ModifierType.LAST_STAND):
			return RunModifier.make_last_stand()
		int(RunModifier.ModifierType.CHAIN_LIGHTNING):
			return RunModifier.make_chain_lightning()
		int(RunModifier.ModifierType.HIGH_ROLLER):
			return RunModifier.make_high_roller()
		int(RunModifier.ModifierType.OVERCHARGE):
			return RunModifier.make_overcharge()
	return RunModifier.make_gamblers_rush()
