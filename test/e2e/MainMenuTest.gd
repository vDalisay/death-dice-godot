extends GdUnitTestSuite

var _saved_locale: String = ""


func before_test() -> void:
	_saved_locale = LocalizationManager.get_current_locale()
	LocalizationManager.set_locale("en", false)
	SaveManager.clear_active_run_snapshot()
	GameManager.skip_archetype_picker = true
	GameManager.chosen_archetype = GameManager.Archetype.CAUTION
	GameManager.active_modifiers.clear()
	GameManager.reset_run()


func after_test() -> void:
	LocalizationManager.set_locale(_saved_locale, false)
	SaveManager.clear_active_run_snapshot()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.paused = false


func test_main_menu_shows_requested_buttons() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/MainMenu.tscn")
	await runner.simulate_frames(2)
	var root: Control = runner.scene() as Control
	assert_object(root).is_not_null()
	assert_str(root.get_node("CenterContainer/Card/MarginContainer/Content/ButtonColumn/PlayButton").text).is_equal("Play")
	assert_str(root.get_node("CenterContainer/Card/MarginContainer/Content/ButtonColumn/CodexButton").text).is_equal("Codex")
	assert_str(root.get_node("CenterContainer/Card/MarginContainer/Content/ButtonColumn/CareerButton").text).is_equal("Career")
	assert_str(root.get_node("CenterContainer/Card/MarginContainer/Content/ButtonColumn/SettingsButton").text).is_equal("Settings")


func test_play_button_loads_game_scene() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/MainMenu.tscn")
	await runner.simulate_frames(2)
	var root: Control = runner.scene() as Control
	var tree: SceneTree = root.get_tree()
	var play_button: Button = root.get_node("CenterContainer/Card/MarginContainer/Content/ButtonColumn/PlayButton") as Button
	play_button.pressed.emit()
	await runner.simulate_frames(3)
	assert_str(tree.current_scene.scene_file_path).is_equal("res://Scenes/Main.tscn")