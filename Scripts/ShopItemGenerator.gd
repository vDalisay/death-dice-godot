class_name ShopItemGenerator
extends RefCounted
## Generates the shop's dice, modifier, and bet item offers each time the shop
## opens or refreshes. Pure logic — no UI or scene-tree access.


## Build the full set of shop offers. Returns a Dictionary with keys
## "dice", "modifiers", "bets" — each an Array[ShopItemData].
func generate_offers(bet_state: Dictionary) -> Dictionary:
	var dice_items: Array[ShopItemData] = []
	var modifier_items: Array[ShopItemData] = []
	var bet_items: Array[ShopItemData] = []

	var dice_pool: Array[ShopItemData] = build_dice_offer_pool()
	GameManager.rng_shuffle_in_place("shop", dice_pool)
	var pick_count: int = mini(ShopPanel.DICE_SLOTS, dice_pool.size())
	for i: int in pick_count:
		dice_items.append(dice_pool[i])

	if not GameManager.dice_pool.is_empty():
		dice_items.append(ShopItemData.make_upgrade_die())
	if any_die_has_cursed_stop():
		dice_items.append(ShopItemData.make_cleanse_curse())

	var dd_used: bool = bool(bet_state.get("dd_used", false))
	var ib_used: bool = bool(bet_state.get("ib_used", false))
	var hb_used: bool = bool(bet_state.get("hb_used", false))
	var eo_used: bool = bool(bet_state.get("eo_used", false))

	if GameManager.gold >= ShopPanel.DOUBLE_DOWN_MIN_GOLD and not dd_used:
		bet_items.append(ShopItemData.make_double_down())
	if GameManager.gold >= ShopPanel.INSURANCE_BET_MIN_GOLD and not ib_used:
		bet_items.append(ShopItemData.make_insurance_bet())
	if GameManager.gold >= ShopPanel.HEAT_BET_MIN_GOLD and not hb_used:
		bet_items.append(ShopItemData.make_heat_bet())
	if GameManager.gold >= ShopPanel.EVEN_ODD_BET_MIN_GOLD and not eo_used:
		bet_items.append(ShopItemData.make_even_odd_bet())

	if GameManager.can_add_modifier():
		var mod_factories: Array[Callable] = RunModifier.all_factories()
		var available_mods: Array[Callable] = []
		for factory: Callable in mod_factories:
			var sample: RunModifier = factory.call() as RunModifier
			if not GameManager.has_modifier(sample.modifier_type):
				available_mods.append(factory)
		GameManager.rng_shuffle_in_place("shop", available_mods)
		var mod_count: int = mini(ShopPanel.MODIFIER_SLOTS, available_mods.size())
		for i: int in mod_count:
			var mod: RunModifier = available_mods[i].call() as RunModifier
			modifier_items.append(ShopItemData.make_buy_modifier(mod))

	return {"dice": dice_items, "modifiers": modifier_items, "bets": bet_items}


func build_dice_offer_pool() -> Array[ShopItemData]:
	var dice_pool: Array[ShopItemData] = [
		ShopItemData.make_buy_simple_die(),
		ShopItemData.make_buy_standard_die(),
		ShopItemData.make_buy_blank_canvas_die(),
		ShopItemData.make_buy_lucky_die(),
		ShopItemData.make_buy_heart_die(),
		ShopItemData.make_buy_pink_die(),
		ShopItemData.make_buy_fortune_die(),
		ShopItemData.make_buy_explosive_die(),
		ShopItemData.make_buy_cluster_die(),
	]
	if GameManager.current_loop >= ShopPanel.CHASER_MIN_LOOP or GameManager.prestige_shop_tier_active:
		dice_pool.append(ShopItemData.make_buy_runner_die())
		dice_pool.append(ShopItemData.make_buy_golden_die())
		dice_pool.append(ShopItemData.make_buy_insurance_die())
		dice_pool.append(ShopItemData.make_buy_heavy_die())
	if can_offer_spark_chaser_die():
		dice_pool.append(ShopItemData.make_buy_spark_chaser_die())
	return dice_pool


func can_offer_spark_chaser_die() -> bool:
	var loop_gate: bool = GameManager.current_loop >= ShopPanel.CHASER_MIN_LOOP or GameManager.prestige_shop_tier_active
	return loop_gate and GameManager.luck >= ShopPanel.CHASER_MIN_LUCK


func any_die_has_cursed_stop() -> bool:
	for die: DiceData in GameManager.dice_pool:
		for face: DiceFaceData in die.faces:
			if face.type == DiceFaceData.FaceType.CURSED_STOP:
				return true
	return false
