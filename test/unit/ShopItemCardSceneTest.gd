extends GdUnitTestSuite
## Scene-structure checks for reusable shop item cards.

const ShopItemCardScene: PackedScene = preload("res://Scenes/ShopItemCard.tscn")


func test_card_has_required_nodes() -> void:
	var card: PanelContainer = auto_free(ShopItemCardScene.instantiate()) as PanelContainer
	add_child(card)
	await await_idle_frame()
	assert_object(card.get_node("VBoxContainer/AccentBar")).is_not_null()
	assert_object(card.get_node("VBoxContainer/MarginContainer/Content/NameLabel")).is_not_null()
	assert_object(card.get_node("VBoxContainer/MarginContainer/Content/DescLabel")).is_not_null()
	assert_object(card.get_node("VBoxContainer/MarginContainer/Content/FooterRow/PriceLabel")).is_not_null()
	assert_object(card.get_node("VBoxContainer/MarginContainer/Content/FooterRow/BuyButton")).is_not_null()


func test_card_buy_button_meets_touch_target() -> void:
	var card: PanelContainer = auto_free(ShopItemCardScene.instantiate()) as PanelContainer
	add_child(card)
	await await_idle_frame()
	var buy_button: Button = card.get_node("VBoxContainer/MarginContainer/Content/FooterRow/BuyButton") as Button
	assert_int(int(buy_button.custom_minimum_size.y)).is_equal(44)
