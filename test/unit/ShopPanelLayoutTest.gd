extends GdUnitTestSuite
## Layout and interaction tests for the Step 1.4 shop panel redesign.

const ShopPanelScene: PackedScene = preload("res://Scenes/ShopPanel.tscn")


func before_test() -> void:
	GameManager.reset_run()


func after_test() -> void:
	GameManager.reset_run()


func test_shop_uses_grouped_offer_sections_and_details_panel() -> void:
	var panel: ShopPanel = auto_free(ShopPanelScene.instantiate()) as ShopPanel
	add_child(panel)
	await await_idle_frame()
	var dice_grid: GridContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/OfferColumn/DiceSection/DiceGrid") as GridContainer
	var modifiers_grid: GridContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/OfferColumn/ModifiersSection/ModifiersGrid") as GridContainer
	var bets_grid: GridContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/OfferColumn/BetsSection/BetsGrid") as GridContainer
	var details_panel: PanelContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/DetailsPanel") as PanelContainer
	assert_object(dice_grid).is_not_null()
	assert_object(modifiers_grid).is_not_null()
	assert_object(bets_grid).is_not_null()
	assert_object(details_panel).is_not_null()


func test_shop_main_content_is_scrollable_and_modal_fits_viewport() -> void:
	var panel: ShopPanel = auto_free(ShopPanelScene.instantiate()) as ShopPanel
	add_child(panel)
	await await_idle_frame()
	var scroll: ScrollContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll") as ScrollContainer
	var modal: PanelContainer = panel.get_node("CenterContainer/Modal") as PanelContainer
	assert_object(scroll).is_not_null()
	assert_int(scroll.vertical_scroll_mode).is_equal(1)
	assert_float(modal.custom_minimum_size.y).is_less_equal(panel.get_viewport_rect().size.y)


func test_open_shows_stage_title_and_continue_label() -> void:
	GameManager.reset_run()
	GameManager.add_gold(30)
	var panel: ShopPanel = auto_free(ShopPanelScene.instantiate()) as ShopPanel
	add_child(panel)
	await await_idle_frame()
	panel.open(1, false)
	var title_label: Label = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/HeaderRow/TitleLabel") as Label
	var continue_button: Button = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/FooterRow/ContinueButton") as Button
	assert_bool(panel.visible).is_true()
	assert_str(title_label.text).contains("STAGE 1")
	assert_str(continue_button.text).contains("Stage 2")


func test_open_builds_card_nodes_with_buy_button() -> void:
	GameManager.reset_run()
	GameManager.add_gold(100)
	var panel: ShopPanel = auto_free(ShopPanelScene.instantiate()) as ShopPanel
	add_child(panel)
	await await_idle_frame()
	panel.open(1, false)
	var dice_grid: GridContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/OfferColumn/DiceSection/DiceGrid") as GridContainer
	var modifiers_grid: GridContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/OfferColumn/ModifiersSection/ModifiersGrid") as GridContainer
	var bets_grid: GridContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/OfferColumn/BetsSection/BetsGrid") as GridContainer
	var first_card: PanelContainer = null
	for grid: GridContainer in [dice_grid, modifiers_grid, bets_grid]:
		if grid.get_child_count() > 0:
			first_card = grid.get_child(0) as PanelContainer
			break
	assert_object(first_card).is_not_null()
	var buy_button: Button = first_card.get_node("VBoxContainer/MarginContainer/Content/FooterRow/BuyButton") as Button
	assert_object(buy_button).is_not_null()
	var details_title: Label = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/DetailsPanel/MarginContainer/DetailsContent/DetailsTitleLabel") as Label
	assert_str(details_title.text).is_not_empty()


func test_open_separates_bets_from_dice_offers() -> void:
	GameManager.reset_run()
	GameManager.add_gold(100)
	var panel: ShopPanel = auto_free(ShopPanelScene.instantiate()) as ShopPanel
	add_child(panel)
	await await_idle_frame()
	panel.open(1, false)
	var dice_grid: GridContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/OfferColumn/DiceSection/DiceGrid") as GridContainer
	var bets_grid: GridContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/OfferColumn/BetsSection/BetsGrid") as GridContainer
	assert_int(panel._bet_items.size()).is_greater_equal(1)
	assert_int(bets_grid.get_child_count()).is_equal(panel._bet_items.size())
	assert_int(dice_grid.get_child_count()).is_greater_equal(1)


func test_refresh_button_matches_56px_touch_target() -> void:
	var panel: ShopPanel = auto_free(ShopPanelScene.instantiate()) as ShopPanel
	add_child(panel)
	await await_idle_frame()
	var refresh_button: Button = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/FooterRow/RefreshButton") as Button
	assert_int(int(refresh_button.custom_minimum_size.y)).is_equal(56)


func test_refresh_button_disables_at_zero_gold() -> void:
	GameManager.reset_run()
	var panel: ShopPanel = auto_free(ShopPanelScene.instantiate()) as ShopPanel
	add_child(panel)
	await await_idle_frame()
	panel.open(1, false)
	GameManager.gold = 0
	GameManager.gold_changed.emit(0)
	var refresh_button: Button = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/FooterRow/RefreshButton") as Button
	assert_bool(refresh_button.disabled).is_true()


func test_expensive_cards_dim_when_gold_is_zero() -> void:
	GameManager.reset_run()
	GameManager.gold = 0
	var panel: ShopPanel = auto_free(ShopPanelScene.instantiate()) as ShopPanel
	add_child(panel)
	await await_idle_frame()
	panel.open(1, false)
	await await_idle_frame()
	assert_int(panel._card_panels.size()).is_greater_equal(1)
	var first_card: PanelContainer = panel._card_panels[0] as PanelContainer
	assert_float(first_card.self_modulate.a).is_less(1.0)


func test_hover_selection_updates_details_panel() -> void:
	GameManager.reset_run()
	GameManager.add_gold(100)
	var panel: ShopPanel = auto_free(ShopPanelScene.instantiate()) as ShopPanel
	add_child(panel)
	await await_idle_frame()
	panel.open(1, false)
	await await_idle_frame()
	assert_int(panel._card_panels.size()).is_greater_equal(2)
	(panel._card_panels[1] as Control).mouse_entered.emit()
	await await_idle_frame()
	var details_title: Label = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/DetailsPanel/MarginContainer/DetailsContent/DetailsTitleLabel") as Label
	assert_str(details_title.text).is_equal((panel._all_items[1] as ShopItemData).item_name)


func test_spark_chaser_gate_requires_loop_and_luck() -> void:
	GameManager.reset_run()
	var panel: ShopPanel = auto_free(ShopPanelScene.instantiate()) as ShopPanel
	add_child(panel)
	await await_idle_frame()

	GameManager.current_loop = 1
	GameManager.prestige_shop_tier_active = false
	GameManager.luck = ShopPanel.CHASER_MIN_LUCK
	assert_bool(panel._can_offer_spark_chaser_die()).is_false()

	GameManager.current_loop = ShopPanel.CHASER_MIN_LOOP
	GameManager.luck = ShopPanel.CHASER_MIN_LUCK - 1
	assert_bool(panel._can_offer_spark_chaser_die()).is_false()

	GameManager.luck = ShopPanel.CHASER_MIN_LUCK
	assert_bool(panel._can_offer_spark_chaser_die()).is_true()


func test_dice_offer_pool_surfaces_spark_chaser_only_when_gate_passes() -> void:
	GameManager.reset_run()
	var panel: ShopPanel = auto_free(ShopPanelScene.instantiate()) as ShopPanel
	add_child(panel)
	await await_idle_frame()

	GameManager.current_loop = 1
	GameManager.prestige_shop_tier_active = false
	GameManager.luck = 0
	var closed_pool: Array[ShopItemData] = panel._build_dice_offer_pool()
	assert_bool(_pool_has_item_type(closed_pool, ShopItemData.ItemType.BUY_SPARK_CHASER_DIE)).is_false()

	GameManager.current_loop = ShopPanel.CHASER_MIN_LOOP
	GameManager.luck = ShopPanel.CHASER_MIN_LUCK
	var open_pool: Array[ShopItemData] = panel._build_dice_offer_pool()
	assert_bool(_pool_has_item_type(open_pool, ShopItemData.ItemType.BUY_SPARK_CHASER_DIE)).is_true()
	for item: ShopItemData in open_pool:
		if item.item_type == ShopItemData.ItemType.BUY_SPARK_CHASER_DIE:
			assert_str(item.item_name).is_equal("Spark Chaser Die")


func test_buying_spark_chaser_adds_base_tier_and_preserves_evolution_identity() -> void:
	GameManager.reset_run()
	GameManager.add_gold(200)
	var panel: ShopPanel = auto_free(ShopPanelScene.instantiate()) as ShopPanel
	add_child(panel)
	await await_idle_frame()

	var item: ShopItemData = ShopItemData.make_buy_spark_chaser_die()
	var start_gold: int = GameManager.gold
	var start_count: int = GameManager.dice_pool.size()
	panel._on_buy_pressed(item)

	assert_int(GameManager.gold).is_equal(start_gold - item.cost)
	assert_int(GameManager.dice_pool.size()).is_equal(start_count + 1)

	var bought_die: DiceData = GameManager.dice_pool[GameManager.dice_pool.size() - 1]
	assert_str(bought_die.dice_name).is_equal("Spark Chaser D6")
	assert_str(bought_die.reroll_family_id).is_equal("reroll_chaser")
	assert_int(bought_die.reroll_tier).is_equal(0)

	assert_bool(bought_die.apply_reroll_progress(3)).is_true()
	assert_str(bought_die.reroll_family_id).is_equal("reroll_chaser")
	assert_int(bought_die.reroll_tier).is_equal(2)
	assert_str(bought_die.dice_name).is_equal("Tempest Chaser D6")


func _pool_has_item_type(items: Array[ShopItemData], item_type: int) -> bool:
	for item: ShopItemData in items:
		if item.item_type == item_type:
			return true
	return false
