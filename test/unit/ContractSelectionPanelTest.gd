extends GdUnitTestSuite

const PanelScene: PackedScene = preload("res://Scenes/ContractSelectionPanel.tscn")
const LoopContractCatalogScript: GDScript = preload("res://Scripts/LoopContractCatalog.gd")
const LoopContractData := preload("res://Scripts/LoopContractData.gd")


func test_open_builds_one_card_per_offer() -> void:
	var panel: ColorRect = auto_free(PanelScene.instantiate()) as ColorRect
	add_child(panel)
	await await_idle_frame()
	var offers: Array[LoopContractData] = LoopContractCatalogScript.get_offers_for_loop(1)
	panel.call("open", 1, offers)
	var cards: GridContainer = panel.get_node("CenterContainer/Card/MarginContainer/Content/ScrollContainer/CardsContainer") as GridContainer
	assert_int(cards.get_child_count()).is_equal(3)


func test_select_button_emits_contract_id() -> void:
	var panel: ColorRect = auto_free(PanelScene.instantiate()) as ColorRect
	add_child(panel)
	await await_idle_frame()
	var offers: Array[LoopContractData] = LoopContractCatalogScript.get_offers_for_loop(1)
	panel.call("open", 1, offers)
	monitor_signals(panel, false)
	var cards: GridContainer = panel.get_node("CenterContainer/Card/MarginContainer/Content/ScrollContainer/CardsContainer") as GridContainer
	var first_card: PanelContainer = cards.get_child(0) as PanelContainer
	var margin: MarginContainer = first_card.get_child(0) as MarginContainer
	var content: VBoxContainer = margin.get_child(0) as VBoxContainer
	var select_button: Button = content.get_child(content.get_child_count() - 1) as Button
	select_button.pressed.emit()
	await assert_signal(panel).is_emitted("contract_selected", ["safe_hands"])