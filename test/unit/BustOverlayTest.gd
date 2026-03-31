extends GdUnitTestSuite
## Unit tests for the redesigned Bust overlay.

const BustOverlayScene: PackedScene = preload("res://Scenes/BustOverlay.tscn")


func test_play_shows_bust_text_when_lives_remain() -> void:
	GameManager.lives = 2
	var overlay: ColorRect = auto_free(BustOverlayScene.instantiate()) as ColorRect
	add_child(overlay)
	await await_idle_frame()
	overlay.call("play", 1)
	var message_label: Label = overlay.get_node("CenterContainer/Card/MarginContainer/Content/MessageLabel") as Label
	assert_str(message_label.text).contains("BUST")


func test_play_shows_game_over_when_out_of_lives() -> void:
	GameManager.lives = 0
	var overlay: ColorRect = auto_free(BustOverlayScene.instantiate()) as ColorRect
	add_child(overlay)
	await await_idle_frame()
	overlay.call("play", 1)
	var message_label: Label = overlay.get_node("CenterContainer/Card/MarginContainer/Content/MessageLabel") as Label
	assert_str(message_label.text).is_equal("GAME OVER")


func test_play_keeps_card_centered_for_impact_animation() -> void:
	GameManager.lives = 2
	var overlay: ColorRect = auto_free(BustOverlayScene.instantiate()) as ColorRect
	add_child(overlay)
	# play() awaits one process_frame internally, so we await two to be past it.
	await await_idle_frame()
	overlay.call("play", 1)
	await await_idle_frame()
	var card: PanelContainer = overlay.get_node("CenterContainer/Card") as PanelContainer
	# Card should remain at rest position (no drop-from-top movement).
	var rest_y: float = overlay.get("_card_rest_position").y
	assert_float(card.position.y).is_equal(rest_y)
