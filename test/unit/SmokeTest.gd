extends GdUnitTestSuite
## Smoke test — verifies GDUnit4 is wired up and the project loads.


func test_gdunit4_is_running() -> void:
	assert_bool(true).is_true()


func test_project_has_main_scene() -> void:
	var main_scene_path: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_str(main_scene_path).is_not_empty()
	assert_bool(ResourceLoader.exists(main_scene_path)).is_true()
