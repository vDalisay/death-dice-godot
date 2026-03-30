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
