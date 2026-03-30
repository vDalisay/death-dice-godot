extends GdUnitTestSuite
## Layout and interaction tests for the Step 1.4 shop panel redesign.

const ShopPanelScene: PackedScene = preload("res://Scenes/ShopPanel.tscn")


func test_shop_uses_card_grid_containers() -> void:
	var panel: ShopPanel = auto_free(ShopPanelScene.instantiate()) as ShopPanel
	add_child(panel)
	await await_idle_frame()
	var dice_container: HFlowContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/ScrollContainer/ScrollContent/DiceContainer") as HFlowContainer
	var modifier_container: HFlowContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/ScrollContainer/ScrollContent/ModifierContainer") as HFlowContainer
	assert_object(dice_container).is_not_null()
	assert_object(modifier_container).is_not_null()


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
	var dice_container: HFlowContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/ScrollContainer/ScrollContent/DiceContainer") as HFlowContainer
	assert_int(dice_container.get_child_count()).is_greater_equal(1)
	var card: PanelContainer = dice_container.get_child(0) as PanelContainer
	assert_object(card).is_not_null()
	var buy_button: Button = card.get_node("VBoxContainer/MarginContainer/Content/FooterRow/BuyButton") as Button
	assert_object(buy_button).is_not_null()


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
