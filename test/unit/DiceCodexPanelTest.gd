extends GdUnitTestSuite
## Unit tests for DiceCodexPanel modal card rendering.

const CodexScene: PackedScene = preload("res://Scenes/DiceCodexPanel.tscn")


func before_test() -> void:
	SaveManager.discovered_dice.clear()


func test_open_panel_populates_all_known_dice_cards() -> void:
	var panel: DiceCodexPanel = auto_free(CodexScene.instantiate()) as DiceCodexPanel
	add_child(panel)
	await await_idle_frame()
	panel.open_panel()
	await await_idle_frame()
	var grid: HFlowContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/ScrollContainer/CardsGrid") as HFlowContainer
	assert_int(grid.get_child_count()).is_equal(DiceData.get_all_known_dice().size())


func test_locked_card_shows_unknown_labels() -> void:
	var panel: DiceCodexPanel = auto_free(CodexScene.instantiate()) as DiceCodexPanel
	add_child(panel)
	await await_idle_frame()
	panel.open_panel()
	await await_idle_frame()
	var grid: HFlowContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/ScrollContainer/CardsGrid") as HFlowContainer
	var first_card: PanelContainer = grid.get_child(0) as PanelContainer
	var name_label: Label = first_card.find_child("NameLabel", true, false) as Label
	var rarity_label: Label = first_card.find_child("RarityLabel", true, false) as Label
	assert_str(name_label.text).is_equal("???")
	assert_str(rarity_label.text).is_equal("LOCKED")


func test_discovered_card_reveals_die_name_and_faces() -> void:
	SaveManager.discover_die("Standard D6")
	var panel: DiceCodexPanel = auto_free(CodexScene.instantiate()) as DiceCodexPanel
	add_child(panel)
	await await_idle_frame()
	panel.open_panel()
	await await_idle_frame()
	var grid: HFlowContainer = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/ScrollContainer/CardsGrid") as HFlowContainer
	var first_card: PanelContainer = grid.get_child(0) as PanelContainer
	var name_label: Label = first_card.find_child("NameLabel", true, false) as Label
	var rarity_label: Label = first_card.find_child("RarityLabel", true, false) as Label
	var faces_grid: GridContainer = first_card.find_child("FacesGrid", true, false) as GridContainer
	var first_tile: PanelContainer = faces_grid.get_child(0) as PanelContainer
	var first_face_label: Label = first_tile.find_child("FaceLabel", true, false) as Label
	assert_str(name_label.text).is_equal("Standard D6")
	assert_str(rarity_label.text).is_equal("COMMON")
	assert_str(first_face_label.text).contains("#")
	assert_str(first_face_label.text).contains("1")


func test_completion_label_reflects_discovery_progress() -> void:
	SaveManager.discover_die("Standard D6")
	SaveManager.discover_die("Lucky D6")
	var panel: DiceCodexPanel = auto_free(CodexScene.instantiate()) as DiceCodexPanel
	add_child(panel)
	await await_idle_frame()
	panel.open_panel()
	await await_idle_frame()
	var completion_label: Label = panel.get_node("CenterContainer/Modal/MarginContainer/VBoxContainer/HeaderRow/CompletionBadge/CompletionMargin/CompletionLabel") as Label
	assert_str(completion_label.text).contains("2 / 10")
