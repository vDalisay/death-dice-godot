extends GdUnitTestSuite
## Unit tests for the redesigned HUD 3-zone dashboard.
## Tests risk pip logic, label formats, and theme styling.

const _UITheme := preload("res://Scripts/UITheme.gd")
const HUDScene: PackedScene = preload("res://Scenes/HUD.tscn")


# ---------------------------------------------------------------------------
# Risk pip calculation
# ---------------------------------------------------------------------------

func test_risk_pips_zero_stops_all_empty() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud._update_risk_pips(0, 3)
	for pip: Label in hud._risk_pips:
		assert_str(pip.text).is_equal("○")


func test_risk_pips_one_of_three_fills_two() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud._update_risk_pips(1, 3)
	# ratio = 1/3 ≈ 0.33, ceil(0.33 * 5) = 2
	var filled: int = 0
	for pip: Label in hud._risk_pips:
		if pip.text == "●":
			filled += 1
	assert_int(filled).is_equal(2)


func test_risk_pips_at_threshold_fills_all() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud._update_risk_pips(3, 3)
	# ratio = 1.0, ceil(1.0 * 5) = 5
	var filled: int = 0
	for pip: Label in hud._risk_pips:
		if pip.text == "●":
			filled += 1
	assert_int(filled).is_equal(5)


func test_risk_pips_count_is_five() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	assert_int(hud._risk_pips.size()).is_equal(5)


# ---------------------------------------------------------------------------
# Label formatting
# ---------------------------------------------------------------------------

func test_lives_display_hearts() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud._on_lives_changed(3)
	assert_int(hud.lives_label.text.length()).is_equal(3)
	assert_str(hud.lives_label.text).contains(_UITheme.GLYPH_HEART)


func test_lives_display_zero_shows_stop() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud._on_lives_changed(0)
	assert_str(hud.lives_label.text).is_equal(_UITheme.GLYPH_STOP)


func test_gold_display_format() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud._on_gold_changed(42)
	assert_str(hud.gold_label.text).contains("42")
	assert_str(hud.gold_label.text).contains(_UITheme.GLYPH_GOLD)


func test_highscore_compact_format() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud._on_highscore_changed(999)
	assert_str(hud.highscore_label.text).is_equal("HI: 999")


func test_stage_label_format() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud._refresh_stage_display()
	assert_str(hud.stage_label.text).contains("STAGE")


func test_update_turn_sets_turn_score() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud.update_turn(42, 1, 3)
	assert_str(hud.turn_score_label.text).is_equal("+42")


func test_update_turn_sets_stop_text() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud.update_turn(10, 2, 3)
	assert_str(hud.stop_label.text).contains("2/3")


func test_update_turn_with_shields_shows_diamond() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud.update_turn(10, 1, 3, 2)
	assert_str(hud.stop_label.text).contains(_UITheme.GLYPH_SHIELD)
	assert_str(hud.stop_label.text).contains("2")


func test_score_label_total_format() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud._on_score_changed(150)
	assert_str(hud.score_label.text).is_equal("Total: 150")


# ---------------------------------------------------------------------------
# Theme styling applied
# ---------------------------------------------------------------------------

func test_top_bar_has_panel_stylebox() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	var sb: StyleBox = hud._top_bar.get_theme_stylebox("panel")
	assert_object(sb).is_not_null()


func test_turn_score_panel_has_gold_border() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	var sb: StyleBoxFlat = hud._turn_score_panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_object(sb).is_not_null()
	assert_int(sb.border_width_left).is_greater(0)


func test_stage_label_uses_display_font() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	var font: Font = hud.stage_label.get_theme_font("font")
	assert_object(font).is_not_null()
