extends GdUnitTestSuite
## Unit tests for the redesigned Bust overlay.

const BustOverlayScene: PackedScene = preload("res://Scenes/BustOverlay.tscn")

var _saved_locale: String = ""


func before_test() -> void:
	_saved_locale = LocalizationManager.get_current_locale()
	LocalizationManager.set_locale("en", false)


func after_test() -> void:
	LocalizationManager.set_locale(_saved_locale, false)


func test_play_shows_bust_text_when_lives_remain() -> void:
	GameManager.lives = 2
	var overlay: ColorRect = auto_free(BustOverlayScene.instantiate()) as ColorRect
	add_child(overlay)
	await await_idle_frame()
	overlay.call("play", 1)
	await await_millis(850)
	var message_label: Label = overlay.get_node("CenterContainer/Card/MarginContainer/Content/MessageLabel") as Label
	assert_str(message_label.text).contains("BUST")


func test_play_shows_game_over_when_out_of_lives() -> void:
	GameManager.lives = 0
	var overlay: ColorRect = auto_free(BustOverlayScene.instantiate()) as ColorRect
	add_child(overlay)
	await await_idle_frame()
	overlay.call("play", 1)
	await await_millis(850)
	var message_label: Label = overlay.get_node("CenterContainer/Card/MarginContainer/Content/MessageLabel") as Label
	assert_str(message_label.text).is_equal(overlay.tr("BUST_GAME_OVER"))


func test_play_sets_drop_from_top_card_state() -> void:
	GameManager.lives = 2
	var overlay: ColorRect = auto_free(BustOverlayScene.instantiate()) as ColorRect
	add_child(overlay)
	# play() awaits one process_frame internally, so we await two to be past it.
	await await_idle_frame()
	overlay.call("play", 1)
	await await_idle_frame()
	var card: PanelContainer = overlay.get_node("CenterContainer/Card") as PanelContainer
	# Card should be positioned above its resting point (negative Y offset).
	var rest_y: float = overlay.get("_card_rest_position").y
	assert_float(card.position.y).is_less(rest_y)


func test_build_glitch_text_returns_target_at_full_progress() -> void:
	var script: GDScript = load("res://Scripts/BustOverlay.gd") as GDScript
	var result: String = script.build_glitch_text("GAME OVER", 1.0)
	assert_str(result).is_equal("GAME OVER")


func test_build_glitch_text_scrambles_unrevealed_characters() -> void:
	var script: GDScript = load("res://Scripts/BustOverlay.gd") as GDScript
	var result: String = script.build_glitch_text("BUST", 0.0)
	assert_str(result).is_not_equal("BUST")
	assert_int(result.length()).is_equal(4)
