extends GdUnitTestSuite
## Layout and interaction tests for the Step 1.4 shop panel redesign.

const ShopPanelScene: PackedScene = preload("res://Scenes/ShopPanel.tscn")


func test_shop_uses_offer_grid_and_details_panel() -> void:
	var panel: ShopPanel = auto_free(ShopPanelScene.instantiate()) as ShopPanel
	add_child(panel)
	await await_idle_frame()
	var offer_grid: GridContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/MainContent/OfferColumn/OfferGrid") as GridContainer
	var details_panel: PanelContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/MainContent/DetailsPanel") as PanelContainer
	assert_object(offer_grid).is_not_null()
	assert_object(details_panel).is_not_null()


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
	var offer_grid: GridContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/MainContent/OfferColumn/OfferGrid") as GridContainer
	assert_int(offer_grid.get_child_count()).is_greater_equal(1)
	var card: PanelContainer = offer_grid.get_child(0) as PanelContainer
	assert_object(card).is_not_null()
	var buy_button: Button = card.get_node("VBoxContainer/MarginContainer/Content/FooterRow/BuyButton") as Button
	assert_object(buy_button).is_not_null()
	var details_title: Label = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/MainContent/DetailsPanel/MarginContainer/DetailsContent/DetailsTitleLabel") as Label
	assert_str(details_title.text).is_not_empty()


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
	var details_title: Label = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/MainContent/DetailsPanel/MarginContainer/DetailsContent/DetailsTitleLabel") as Label
	assert_str(details_title.text).is_equal((panel._all_items[1] as ShopItemData).item_name)
