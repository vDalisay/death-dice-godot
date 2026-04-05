extends GdUnitTestSuite
## Unit tests for ShopItemData resource.


func test_standard_die_item() -> void:
	var item: ShopItemData = ShopItemData.make_buy_standard_die()
	assert_str(item.item_name).is_equal("Standard Die")
	assert_int(item.cost).is_equal(20)
	assert_int(item.item_type).is_equal(ShopItemData.ItemType.BUY_STANDARD_DIE)


func test_lucky_die_item() -> void:
	var item: ShopItemData = ShopItemData.make_buy_lucky_die()
	assert_str(item.item_name).is_equal("Lucky Die")
	assert_int(item.cost).is_equal(50)
	assert_int(item.item_type).is_equal(ShopItemData.ItemType.BUY_LUCKY_DIE)


func test_insurance_die_item() -> void:
	var item: ShopItemData = ShopItemData.make_buy_insurance_die()
	assert_str(item.item_name).is_equal("Insurance Die")
	assert_int(item.cost).is_equal(55)
	assert_int(item.item_type).is_equal(ShopItemData.ItemType.BUY_INSURANCE_DIE)


func test_upgrade_die_item() -> void:
	var item: ShopItemData = ShopItemData.make_upgrade_die()
	assert_str(item.item_name).is_equal("Empower Die")
	assert_int(item.cost).is_equal(30)
	assert_int(item.item_type).is_equal(ShopItemData.ItemType.UPGRADE_DIE)


func test_heart_die_item() -> void:
	var item: ShopItemData = ShopItemData.make_buy_heart_die()
	assert_str(item.item_name).is_equal("Heart Die")
	assert_int(item.cost).is_equal(30)
	assert_int(item.item_type).is_equal(ShopItemData.ItemType.BUY_HEART_DIE)


func test_spark_chaser_die_item() -> void:
	var item: ShopItemData = ShopItemData.make_buy_spark_chaser_die()
	assert_str(item.item_name).is_equal("Spark Chaser Die")
	assert_int(item.cost).is_equal(40)
	assert_int(item.item_type).is_equal(ShopItemData.ItemType.BUY_SPARK_CHASER_DIE)


func test_all_items_have_descriptions() -> void:
	var items: Array[ShopItemData] = [
		ShopItemData.make_buy_standard_die(),
		ShopItemData.make_buy_lucky_die(),
		ShopItemData.make_buy_heart_die(),
		ShopItemData.make_buy_spark_chaser_die(),
		ShopItemData.make_buy_insurance_die(),
		ShopItemData.make_upgrade_die(),
	]
	for item: ShopItemData in items:
		assert_str(item.description).is_not_empty()


func test_pink_die_description_mentions_any_face() -> void:
	var item: ShopItemData = ShopItemData.make_buy_pink_die()
	assert_str(item.description).contains("ANY")


func test_simple_die_item() -> void:
	var item: ShopItemData = ShopItemData.make_buy_simple_die()
	assert_str(item.item_name).is_equal("Simple Die")
	assert_int(item.cost).is_equal(8)
	assert_int(item.item_type).is_equal(ShopItemData.ItemType.BUY_SIMPLE_DIE)
