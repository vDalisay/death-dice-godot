extends GdUnitTestSuite
## Unit tests for the redesigned HUD 3-zone dashboard.
## Tests risk pip logic, label formats, and theme styling.

const _UITheme := preload("res://Scripts/UITheme.gd")
const HUDScene: PackedScene = preload("res://Scenes/HUD.tscn")


func before_test() -> void:
	GameManager.active_modifiers.clear()
	GameManager.clear_active_loop_contract()
	GameManager.set_held_stop_count(0)
	GameManager.near_death_banks_this_stage = 0
	GameManager.near_death_banks_this_run = 0


# ---------------------------------------------------------------------------
# Risk pip calculation
# ---------------------------------------------------------------------------

func test_risk_pips_zero_stops_all_empty() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud._update_risk_pips(0.0)
	for pip: Label in hud._risk_pips:
		assert_str(pip.text).is_equal("○")


func test_risk_pips_one_of_three_fills_two() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud._update_risk_pips(0.33)
	# ratio = 0.33, ceil(0.33 * 5) = 2
	var filled: int = 0
	for pip: Label in hud._risk_pips:
		if pip.text == "●":
			filled += 1
	assert_int(filled).is_equal(2)


func test_risk_pips_at_threshold_fills_all() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud._update_risk_pips(1.0)
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
	# Gold odometer animates via tween — wait for it to finish.
	if hud._gold_tween and hud._gold_tween.is_valid():
		await hud._gold_tween.finished
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
	assert_str(hud.stage_label.text).contains("ROW")


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


func test_update_turn_risk_meta_shows_held_stops_and_ev() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud._on_held_stops_changed(2)
	GameManager.near_death_banks_this_stage = 1
	hud._on_near_death_banked(3, 4)
	hud.update_turn(18, 3, 4, 1, 2, 0.72, "details", 4.5)
	var meta_label: Label = hud.get_node("InfoRow/RiskColumn/RiskMetaLabel") as Label
	assert_str(meta_label.text).contains("Held 2")
	assert_str(meta_label.text).contains("Near-Death x1")
	assert_str(meta_label.text).contains("EV +4.5")
	assert_str(meta_label.text).contains("JUICY")


func test_contract_label_reflects_active_contract_progress() -> void:
	GameManager.activate_loop_contract("safe_hands")
	GameManager.update_loop_contract_progress({
		"contract_id": "safe_hands",
		"current": 1,
		"target": 3,
		"completed": false,
	})
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	var contract_label: Label = hud.get_node("InfoRow/RiskColumn/ContractLabel") as Label
	assert_bool(contract_label.visible).is_true()
	assert_str(contract_label.text).is_equal("Safe Hands 1/3")


func test_score_label_total_format() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud._on_score_changed(150)
	assert_str(hud.score_label.text).is_equal("Total: 150")


func test_progress_bar_lerps_when_score_increases() -> void:
	GameManager.total_score = 0
	GameManager.stage_target_score = 100
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud.progress_bar.value = 10.0
	GameManager.total_score = 60
	hud._refresh_progress_display()
	assert_object(hud._progress_tween).is_not_null()
	await get_tree().process_frame
	assert_float(hud.progress_bar.value).is_greater(10.0)
	assert_float(hud.progress_bar.value).is_less(60.0)
	await hud._progress_tween.finished
	assert_float(hud.progress_bar.value).is_equal(60.0)


func test_progress_bar_snaps_when_score_decreases() -> void:
	GameManager.total_score = 0
	GameManager.stage_target_score = 100
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud.progress_bar.value = 80.0
	GameManager.total_score = 20
	hud._refresh_progress_display()
	assert_object(hud._progress_tween).is_null()
	assert_float(hud.progress_bar.value).is_equal(20.0)


func test_score_feedback_defers_score_signal_until_finished() -> void:
	GameManager.total_score = 0
	GameManager.stage_target_score = 100
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud.begin_score_feedback(0, 80, false)
	hud._on_score_changed(80)
	assert_bool(hud.is_score_feedback_active()).is_true()
	assert_str(hud.score_label.text).is_equal("Total: 0")
	assert_float(hud.progress_bar.value).is_equal(0.0)
	hud.finish_score_feedback()
	await get_tree().process_frame
	if hud._score_tween and hud._score_tween.is_valid():
		await hud._score_tween.finished
	if hud._progress_tween and hud._progress_tween.is_valid():
		await hud._progress_tween.finished
	assert_str(hud.score_label.text).is_equal("Total: 80")
	assert_float(hud.progress_bar.value).is_equal(80.0)


func test_reroll_score_feedback_thickens_then_deflates_progress_bar() -> void:
	GameManager.total_score = 0
	GameManager.stage_target_score = 100
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	var base_height: float = hud.get_progress_bar_current_height()
	hud.begin_score_feedback(0, 40, true)
	hud._apply_score_feedback_step(0, 20, 20)
	await get_tree().process_frame
	assert_float(hud.get_progress_bar_current_height()).is_greater(base_height)
	hud.finish_score_feedback()
	if hud._progress_thickness_tween and hud._progress_thickness_tween.is_valid():
		await hud._progress_thickness_tween.finished
	assert_float(hud.get_progress_bar_current_height()).is_equal(base_height)


func test_reset_score_feedback_visuals_deflates_progress_bar_to_base() -> void:
	GameManager.total_score = 0
	GameManager.stage_target_score = 100
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	var base_height: float = hud.get_progress_bar_current_height()
	hud.begin_score_feedback(0, 40, true)
	hud._apply_score_feedback_step(0, 20, 20)
	await get_tree().process_frame
	assert_float(hud.get_progress_bar_current_height()).is_greater(base_height)
	hud.reset_score_feedback_visuals(true)
	if hud._progress_thickness_tween and hud._progress_thickness_tween.is_valid():
		await hud._progress_thickness_tween.finished
	assert_float(hud.get_progress_bar_current_height()).is_equal(base_height)


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


func test_modifier_bar_has_max_slots() -> void:
	GameManager.active_modifiers.clear()
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud._refresh_modifier_display()
	var bar: HBoxContainer = hud.get_node("ModifierRow/ModifierBar") as HBoxContainer
	assert_int(bar.get_child_count()).is_equal(GameManager.MAX_MODIFIERS)


func test_modifier_bar_renders_active_modifier_glyph() -> void:
	GameManager.active_modifiers.clear()
	GameManager.active_modifiers.append(RunModifier.make_iron_bank())
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud._refresh_modifier_display()
	var bar: HBoxContainer = hud.get_node("ModifierRow/ModifierBar") as HBoxContainer
	var first_badge: PanelContainer = bar.get_child(0) as PanelContainer
	assert_object(first_badge).is_not_null()
	var glyph: Label = first_badge.get_node("CenterContainer/BadgeBody/GlyphLabel") as Label
	assert_str(glyph.text).is_equal("Fe")
	GameManager.active_modifiers.clear()


func test_modifier_tooltip_node_exists_and_starts_hidden() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	var tooltip: PanelContainer = hud.get_node("ModifierTooltip") as PanelContainer
	assert_object(tooltip).is_not_null()
	assert_bool(tooltip.visible).is_false()


func test_set_active_combos_renders_combo_badges() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	var combos: Array[RollCombo] = [
		RollCombo.make("shield_wall", "Shield Wall", {}, Color(0.35, 0.75, 1.0)),
		RollCombo.make("chain_reaction", "Chain Reaction", {}, Color(1.0, 0.55, 0.15)),
	]
	hud.set_active_combos(combos)
	var combo_container: HFlowContainer = hud.get_node("ComboRow/ComboContainer") as HFlowContainer
	assert_int(combo_container.get_child_count()).is_equal(2)


func test_hud_has_streak_slot_in_progress_tile() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	var slot: Control = hud.get_node("ScoreRow/ProgressPanel/ProgressMargin/ProgressVBox/ProgressContentRow/StreakSlot") as Control
	assert_object(slot).is_not_null()


func test_update_turn_sets_risk_percent_label() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	hud.update_turn(5, 1, 3, 0, 2, 0.42, "detail")
	assert_str(hud._risk_percent_label.text).contains("42")


func test_flash_combo_updates_status_text() -> void:
	var hud: HUD = auto_free(HUDScene.instantiate()) as HUD
	add_child(hud)
	await await_idle_frame()
	var combo: RollCombo = RollCombo.make("power_pair", "Power Pair", {}, Color(0.95, 0.5, 0.8))
	hud.set_active_combos([combo])
	hud.flash_combo(combo.display_name, combo.flash_color, combo.combo_id)
	assert_str(hud.status_label.text).contains("COMBO")
	assert_str(hud.status_label.text).contains("Power Pair")
