extends GdUnitTestSuite

const PrestigeScene: PackedScene = preload("res://Scenes/PrestigePanel.tscn")
const PermanentUpgradeData := preload("res://Scripts/PermanentUpgradeData.gd")

var _saved_prestige_currency: int = 0
var _saved_experience_currency: int = 0
var _saved_stop_shard_currency: int = 0
var _saved_permanent_upgrade_unlocks: Array[String] = []


func before_test() -> void:
	_saved_prestige_currency = SaveManager.prestige_currency
	_saved_experience_currency = SaveManager.experience_currency
	_saved_stop_shard_currency = SaveManager.stop_shard_currency
	_saved_permanent_upgrade_unlocks = SaveManager.permanent_upgrade_unlocks.duplicate()
	SaveManager.prestige_currency = 7
	SaveManager.experience_currency = 9
	SaveManager.stop_shard_currency = 3
	SaveManager.permanent_upgrade_unlocks.clear()


func after_test() -> void:
	SaveManager.prestige_currency = _saved_prestige_currency
	SaveManager.experience_currency = _saved_experience_currency
	SaveManager.stop_shard_currency = _saved_stop_shard_currency
	SaveManager.permanent_upgrade_unlocks = _saved_permanent_upgrade_unlocks.duplicate()


func test_panel_shows_meta_currencies_and_upgrade_cards() -> void:
	var panel: PrestigePanel = auto_free(PrestigeScene.instantiate()) as PrestigePanel
	add_child(panel)
	await await_idle_frame()
	var meta_label: Label = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/HeaderRow/MetaCurrencyLabel") as Label
	var upgrades: GridContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/ScrollContainer/SectionsVBox/UpgradeCardsContainer") as GridContainer
	assert_str(meta_label.text).contains("EXP 9")
	assert_str(meta_label.text).contains("Shards 3")
	assert_int(upgrades.get_child_count()).is_equal(PermanentUpgradeData.get_all().size())


func test_owned_upgrade_card_disables_button() -> void:
	SaveManager.permanent_upgrade_unlocks = ["reroll_ledger"]
	var panel: PrestigePanel = auto_free(PrestigeScene.instantiate()) as PrestigePanel
	add_child(panel)
	await await_idle_frame()
	var upgrades: GridContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/ScrollContainer/SectionsVBox/UpgradeCardsContainer") as GridContainer
	var first_card: PanelContainer = upgrades.get_child(0) as PanelContainer
	var button: Button = first_card.find_child("UpgradeBuyButton", true, false) as Button
	assert_str(button.text).is_equal("Owned")
	assert_bool(button.disabled).is_true()